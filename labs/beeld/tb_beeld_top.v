// FILE: beeld/tb_beeld_top.v
`timescale 1ns/1ps
// De hele beeldcomputer: een SD-kaartmodel met het demobeeld, het bootprogramma op de CPU, en de virtuele monitor.
// Gecontroleerd wordt het gedrag naar de kaart toe (volgorde, klokpulsen, snelheid, blokken) en het beeld dat op het scherm komt.
module tb_beeld_top;
  reg clk = 0, pclk = 0, rst_n = 0;
  wire hsync, vsync, sd_sclk, sd_mosi, sd_cs_n, sd_miso, txd, frame_done;
  wire [3:0] r, g, b;
  wire [7:0] led;
  wire [31:0] frames;
  integer fouten = 0, x, y, i, bx, klokken = 0, vorige = 0, korst = 1000000;
  reg [7:0] kaart [0:9727];
  reg [7:0] byte_i;
  reg [11:0] pal [0:15], verwacht;
  reg [31:0] f0;
  realtime t_lezen = 0, t_klaar = 0;

  beeld_top dut(.clk(clk), .pclk(pclk), .rst_n(rst_n), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b),
                .sd_sclk(sd_sclk), .sd_mosi(sd_mosi), .sd_cs_n(sd_cs_n), .sd_miso(sd_miso), .led(led), .txd(txd), .rxd(1'b1));
  sd_model card(.sclk(sd_sclk), .mosi(sd_mosi), .cs_n(sd_cs_n), .miso(sd_miso));
  vga_mon mon(.pclk(pclk), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .frame_done(frame_done), .frames(frames));
  always #41.667 clk = ~clk;
  always #19.9 pclk = ~pclk;
  always @(posedge clk) klokken = klokken + 1;
  always @(led) if (led === 8'h05) t_lezen = $realtime;       // stap 5: het lezen van de blokken begint

  // De SD-specificatie vraagt tijdens het opstarten een klok van hoogstens 400 kHz: minstens 30 klokken van 12 MHz tussen twee flanken.
  always @(posedge sd_sclk) begin
    if (card.idle && vorige != 0 && klokken - vorige < 30) begin
      fouten = fouten + 1; $display("FAIL: SCLK te snel tijdens het opstarten: periode %0d klokken", klokken - vorige);
    end
    vorige = klokken;
  end

  initial begin
    $readmemh("sd.hex", kaart);
    pal[0]=12'h000; pal[1]=12'h00A; pal[2]=12'h0A0; pal[3]=12'h0AA; pal[4]=12'hA00; pal[5]=12'hA0A; pal[6]=12'hA50; pal[7]=12'hAAA;
    pal[8]=12'h555; pal[9]=12'h55F; pal[10]=12'h5F5; pal[11]=12'h5FF; pal[12]=12'hF55; pal[13]=12'hF5F; pal[14]=12'hFF5; pal[15]=12'hFFF;
    #200 rst_n = 1;
    wait (led[4] === 1'b1 || led[7] === 1'b1);                // klaar of fout
    t_klaar = $realtime;
    $display("LED's = %b; opstarten van de kaart: %0.1f ms, de 19 blokken lezen: %0.1f ms", led, t_lezen / 1.0e6, (t_klaar - t_lezen) / 1.0e6);
    if (led !== 8'h10) begin fouten = fouten + 1; $display("FAIL: LED's %b, verwacht 00010000 (klaar)", led); end

    // wat de kaart zag
    if (card.fout_init  !== 0) begin fouten = fouten + 1; $display("FAIL: CMD0 kwam voor minstens 74 klokpulsen met CS hoog"); end
    if (card.fout_crc   !== 0) begin fouten = fouten + 1; $display("FAIL: een commando had een verkeerde CRC"); end
    if (card.fout_volgorde !== 0) begin fouten = fouten + 1; $display("FAIL: een commando kwam in de verkeerde volgorde"); end
    if (card.blokken !== 19) begin fouten = fouten + 1; $display("FAIL: %0d blokken gelezen, verwacht 19", card.blokken); end
    if (card.blokken === 19) for (i = 0; i < 19; i = i + 1)
      if (card.blok_log[i] !== i) begin fouten = fouten + 1; $display("FAIL: leesactie %0d vroeg blok %0d", i, card.blok_log[i]); end
    if (sd_cs_n !== 1'b1) begin fouten = fouten + 1; $display("FAIL: CS moet aan het eind hoog zijn"); end

    // wat er op het scherm staat: het eerste volledige beeld erna is nieuw genoeg, we nemen het tweede
    f0 = frames;
    wait (frames == f0 + 2);
    #1;
    if (mon.painted_last !== 640 * 480) begin fouten = fouten + 1; $display("FAIL: %0d pixels geschilderd", mon.painted_last); end
    for (y = 0; y < 480; y = y + 1)
      for (x = 0; x < 640; x = x + 1) begin
        bx = x / 4;
        byte_i = kaart[(y / 4) * 80 + bx / 2];
        verwacht = pal[(bx % 2 == 0) ? byte_i[7:4] : byte_i[3:0]];
        if (mon.img[y*640 + x] !== verwacht && fouten < 10) begin
          fouten = fouten + 1; $display("FAIL: pixel (%0d,%0d) is %h, verwacht %h", x, y, mon.img[y*640 + x], verwacht);
        end
      end
    mon.write_ppm("../../build/beeld.ppm");
    if (fouten == 0) $display("PASS: de computer start de kaart op, leest 19 blokken en toont het beeld");
    $finish;
  end

  initial begin #200_000_000 $display("FAIL: time-out, LED's = %b", led); $finish; end
endmodule
