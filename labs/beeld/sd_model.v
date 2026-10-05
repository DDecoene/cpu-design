// FILE: beeld/sd_model.v
// Een SD-kaart in SPI-modus, alleen voor simulatie. Hij kent precies de commando's die ons bootprogramma nodig heeft:
//   CMD0  (reset)               -> R1 = 0x01 (idle)         vereist de CRC 0x95
//   CMD8  (spanning/versie)     -> R1 = 0x01 + 4 bytes      vereist argument 0x1AA en CRC 0x87
//   CMD55 + ACMD41 (opstarten)  -> R1 = 0x01 enkele keren, dan 0x00 (klaar)
//   CMD17 (lees een blok)       -> R1 = 0x00, enkele 0xFF, token 0xFE, 512 bytes, 2 CRC-bytes   (SDHC: adres is een bloknummer)
// Net als een echte kaart antwoordt hij pas na een of meer 0xFF-bytes, en alleen terwijl CS laag is. De inhoud komt uit een hex-bestand.
module sd_model #(
  parameter FILE = "sd.hex",
  parameter BYTES = 9728,          // grootte van de inhoud in het bestand (19 blokken); daarachter geeft de kaart 0xFF
  parameter ACMD41_TRIES = 3,      // zoveel keer meldt de kaart nog 'idle'
  parameter NCR = 2,               // aantal 0xFF-bytes voor het antwoord (een echte kaart: 0 tot 8)
  parameter NAC = 3                // aantal 0xFF-bytes tussen R1 en het datatoken van CMD17
) (
  input  sclk,
  input  mosi,
  input  cs_n,
  output miso
);
  reg [7:0] flash [0:BYTES-1];     // de inhoud van de kaart
  reg [7:0] cmd [0:5];
  reg [7:0] uit [0:2047];          // wachtrij met bytes die de kaart nog gaat sturen
  integer q_w = 0, q_r = 0;
  integer cmd_n = 0, sclk_cs_hoog = 0, bit_n = 0, acmd41_n = 0, i, blok;
  reg [7:0] in_sh = 0, out_sh = 8'hFF;
  reg app = 0;
  // Wat de testbench controleert:
  reg idle = 1;                    // 1 tot ACMD41 geslaagd is
  reg gereset = 0, v2 = 0;
  integer fout_init = 0, fout_crc = 0, fout_volgorde = 0, blokken = 0;
  integer blok_log [0:63];

  assign miso = cs_n ? 1'b1 : out_sh[7];

  initial begin
    $readmemh(FILE, flash);
  end

  task zet(input [7:0] b); begin uit[q_w % 2048] = b; q_w = q_w + 1; end endtask
  task antwoord(input [7:0] r1); begin repeat (NCR) zet(8'hFF); zet(r1); end endtask

  task commando;
    reg [31:0] arg; reg [5:0] nr;
    begin
      nr = cmd[0][5:0]; arg = {cmd[1], cmd[2], cmd[3], cmd[4]};
      if (nr != 0 && !gereset) begin fout_volgorde = fout_volgorde + 1; antwoord(8'h05); end
      else case (nr)
        0: begin
             if (sclk_cs_hoog < 74) fout_init = fout_init + 1;       // eerst minstens 74 klokpulsen met CS hoog
             if (cmd[5] !== 8'h95) begin fout_crc = fout_crc + 1; antwoord(8'h09); end
             else begin gereset = 1; idle = 1; antwoord(8'h01); end
           end
        8: begin
             if (cmd[5] !== 8'h87 || arg !== 32'h1AA) begin fout_crc = fout_crc + 1; antwoord(8'h05); end
             else begin v2 = 1; antwoord(8'h01); zet(8'h00); zet(8'h00); zet(8'h01); zet(8'hAA); end
           end
        55: begin app = 1; antwoord(idle ? 8'h01 : 8'h00); end
        41: begin
              if (!app) antwoord(8'h05);
              else if (!v2 || arg[30] !== 1'b1) antwoord(8'h01);                   // zonder HCS-bit wordt de kaart nooit klaar
              else begin
                acmd41_n = acmd41_n + 1;
                if (acmd41_n > ACMD41_TRIES) begin idle = 0; antwoord(8'h00); end
                else antwoord(8'h01);
              end
            end
        17: begin
              if (idle) begin fout_volgorde = fout_volgorde + 1; antwoord(8'h05); end
              else begin
                blok = arg;
                if (blokken < 64) blok_log[blokken] = blok;
                blokken = blokken + 1;
                antwoord(8'h00);
                repeat (NAC) zet(8'hFF);
                zet(8'hFE);
                for (i = 0; i < 512; i = i + 1) zet(blok * 512 + i < BYTES ? flash[blok * 512 + i] : 8'hFF);
                zet(8'hDE); zet(8'hAD);                                            // de CRC wordt niet gecontroleerd
              end
            end
        default: antwoord(8'h05);
      endcase
      if (nr != 55) app = 0;
    end
  endtask

  task byte_klaar(input [7:0] b);
    begin
      if (cmd_n > 0) begin
        cmd[cmd_n] = b; cmd_n = cmd_n + 1;
        if (cmd_n == 6) begin cmd_n = 0; commando; end
      end else if (b[7:6] == 2'b01) begin cmd[0] = b; cmd_n = 1; end        // 01xxxxxx begint een commando; 0xFF is een leeg byte
    end
  endtask

  task volgende_uit;
    begin
      if (q_r < q_w) begin out_sh = uit[q_r % 2048]; q_r = q_r + 1; end
      else out_sh = 8'hFF;
    end
  endtask

  always @(posedge sclk) begin
    if (cs_n) sclk_cs_hoog = sclk_cs_hoog + 1;
    else begin
      in_sh = {in_sh[6:0], mosi};                       // de kaart leest MOSI op de stijgende flank
      bit_n = bit_n + 1;
      if (bit_n == 8) begin bit_n = 0; byte_klaar(in_sh); end
    end
  end
  always @(negedge sclk) if (!cs_n) begin               // en zet MISO na de dalende flank
    if (bit_n == 0) volgende_uit; else out_sh = {out_sh[6:0], 1'b1};
  end
  always @(negedge cs_n) begin bit_n = 0; volgende_uit; end
  always @(posedge cs_n) begin cmd_n = 0; q_r = q_w; end       // CS hoog: een lopend antwoord of lopende datablok vervalt
endmodule
