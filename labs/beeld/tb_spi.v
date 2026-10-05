// FILE: beeld/tb_spi.v
// Test van de SPI-master: bitvolgorde, klok in rust laag, 8 pulsen per byte, snelheid en het negeren van een schrijfactie tijdens een overdracht.
// Een kleine slave in Verilog speelt de kaart: hij onthoudt wat hij ontvangt en antwoordt met vaste bytes.
module spi_slave_sim(input sclk, input mosi, input cs_n, output miso);
  reg [7:0] antw [0:15];
  reg [7:0] kreeg [0:15];
  reg [7:0] in_sh = 0, out_sh = 8'hFF;
  integer nb = 0, bit_n = 0, pulsen = 0;
  assign miso = cs_n ? 1'b1 : out_sh[7];
  always @(negedge cs_n) begin bit_n = 0; out_sh = antw[nb]; end            // het eerste bit staat klaar vóór de eerste stijgende flank
  always @(posedge sclk) if (!cs_n) begin
    pulsen = pulsen + 1;
    in_sh = {in_sh[6:0], mosi};                                             // de slave leest MOSI op de stijgende flank
    bit_n = bit_n + 1;
    if (bit_n == 8) begin kreeg[nb] = in_sh; nb = nb + 1; bit_n = 0; end
  end
  always @(negedge sclk) if (!cs_n) begin                                   // en verandert MISO na de dalende flank
    if (bit_n == 0) out_sh = antw[nb]; else out_sh = {out_sh[6:0], 1'b1};
  end
endmodule

module tb_spi;
  reg clk = 0, rst_n = 0, sel = 0, we = 0, loop = 0;
  reg [1:0] reg_sel = 0;
  reg [7:0] wdata = 0;
  wire [7:0] rdata;
  wire sclk, mosi, cs_n, slave_miso;
  wire miso = loop ? mosi : slave_miso;
  integer fouten = 0, i, t0, t1, rise1, rise2, pulsen_start;
  reg [7:0] v;

  spi_io dut(.clk(clk), .rst_n(rst_n), .sel(sel), .we(we), .reg_sel(reg_sel), .wdata(wdata), .rdata(rdata),
             .sclk(sclk), .mosi(mosi), .cs_n(cs_n), .miso(miso));
  spi_slave_sim slave(.sclk(sclk), .mosi(mosi), .cs_n(cs_n), .miso(slave_miso));
  always #5 clk = ~clk;

  integer klokken = 0;
  always @(posedge clk) klokken = klokken + 1;

  task schrijf(input [1:0] r, input [7:0] d);
    begin @(negedge clk); sel = 1; we = 1; reg_sel = r; wdata = d; @(negedge clk); sel = 0; we = 0; end
  endtask
  task lees(input [1:0] r, output [7:0] d);
    begin @(negedge clk); sel = 1; reg_sel = r; #1 d = rdata; @(negedge clk); sel = 0; end
  endtask
  task wacht_klaar;
    begin lees(2, v); while (v[0]) lees(2, v); end
  endtask
  task zend(input [7:0] d, output [7:0] ontvangen);
    begin schrijf(0, d); wacht_klaar; lees(0, ontvangen); end
  endtask

  initial begin
    slave.antw[0] = 8'h11; slave.antw[1] = 8'hA5; slave.antw[2] = 8'h00; slave.antw[3] = 8'hFF; slave.antw[4] = 8'h5A;
    #22 rst_n = 1;
    if (cs_n !== 1'b1 || sclk !== 1'b0) begin fouten = fouten + 1; $display("FAIL: na reset moet CS hoog en SCLK laag zijn"); end

    // --- langzaam: vier bytes met de slave ---
    schrijf(1, 8'h00);                                       // CS laag, langzaam
    zend(8'hA5, v); if (v !== 8'h11) begin fouten = fouten + 1; $display("FAIL: byte 1 ontvangen %h, verwacht 11", v); end
    zend(8'h3C, v); if (v !== 8'hA5) begin fouten = fouten + 1; $display("FAIL: byte 2 ontvangen %h, verwacht A5", v); end
    zend(8'h00, v); if (v !== 8'h00) begin fouten = fouten + 1; $display("FAIL: byte 3 ontvangen %h, verwacht 00", v); end
    zend(8'hFF, v); if (v !== 8'hFF) begin fouten = fouten + 1; $display("FAIL: byte 4 ontvangen %h, verwacht FF", v); end
    if (slave.kreeg[0] !== 8'hA5 || slave.kreeg[1] !== 8'h3C || slave.kreeg[2] !== 8'h00 || slave.kreeg[3] !== 8'hFF) begin
      fouten = fouten + 1; $display("FAIL: de slave ontving %h %h %h %h", slave.kreeg[0], slave.kreeg[1], slave.kreeg[2], slave.kreeg[3]);
    end
    if (slave.pulsen !== 32) begin fouten = fouten + 1; $display("FAIL: %0d SCLK-pulsen voor 4 bytes, verwacht 32", slave.pulsen); end

    // --- klokperiode meten: langzaam 32 klokken, snel 4 klokken ---
    schrijf(0, 8'h55);
    @(posedge sclk); rise1 = klokken; @(posedge sclk); rise2 = klokken;
    if (rise2 - rise1 !== 32) begin fouten = fouten + 1; $display("FAIL: langzame SCLK-periode is %0d klokken, verwacht 32", rise2 - rise1); end
    wacht_klaar;
    schrijf(1, 8'h02);                                       // CS laag, snel
    schrijf(0, 8'h55);
    @(posedge sclk); rise1 = klokken; @(posedge sclk); rise2 = klokken;
    if (rise2 - rise1 !== 4) begin fouten = fouten + 1; $display("FAIL: snelle SCLK-periode is %0d klokken, verwacht 4", rise2 - rise1); end
    wacht_klaar;

    // --- een schrijfactie tijdens een overdracht wordt genegeerd ---
    pulsen_start = slave.pulsen;
    schrijf(0, 8'h81);
    schrijf(0, 8'hFE);                                       // dit byte mag niet starten
    wacht_klaar; repeat (10) @(negedge clk);
    if (slave.pulsen - pulsen_start !== 8) begin fouten = fouten + 1; $display("FAIL: %0d pulsen, verwacht 8: de tweede schrijfactie had genegeerd moeten worden", slave.pulsen - pulsen_start); end

    // --- willekeurige bytes via een lus (MISO = MOSI) in beide snelheden ---
    loop = 1;
    for (i = 0; i < 100; i = i + 1) begin
      if (i == 50) schrijf(1, 8'h00);                        // vanaf nu langzaam
      zend($random, v);
      if (v !== wdata) begin fouten = fouten + 1; $display("FAIL: lus: verstuurd %h, ontvangen %h", wdata, v); end
    end
    loop = 0;

    // --- CS ---
    schrijf(1, 8'h01);
    if (cs_n !== 1'b1) begin fouten = fouten + 1; $display("FAIL: CS moet hoog zijn"); end
    schrijf(1, 8'h00);
    if (cs_n !== 1'b0) begin fouten = fouten + 1; $display("FAIL: CS moet laag zijn"); end
    if (fouten == 0) $display("PASS: SPI-master: bitvolgorde, modus 0, 8 pulsen per byte, perioden 32 en 4, CS en negeren tijdens een overdracht");
    $finish;
  end
endmodule
