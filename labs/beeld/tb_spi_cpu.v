// De CPU stuurt de SPI-poort aan (MISO verbonden met MOSI) en meldt via de GPIO hoeveel bytes goed terugkwamen.
module tb_spi_cpu;
  reg clk = 0, rst_n = 0;
  wire halted, txd, sclk, mosi, cs_n, fb_we;
  wire [7:0] gpio;
  wire [13:0] fb_waddr;
  wire [7:0] fb_wdata;
  integer fouten = 0, pulsen = 0, cs_laag = 0;

  cpu_b #("spi_test.hex", 1, 16) dut(.clk(clk), .rst_n(rst_n), .halted(halted), .txd(txd), .rxd(1'b1), .gpio_in(8'h00), .gpio_out(gpio),
                                     .vblank(1'b0), .fb_we(fb_we), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata),
                                     .spi_sclk(sclk), .spi_mosi(mosi), .spi_cs_n(cs_n), .spi_miso(mosi));
  always #5 clk = ~clk;
  always @(posedge sclk) pulsen = pulsen + 1;
  always @(posedge clk) if (!cs_n) cs_laag = cs_laag + 1;

  initial begin
    #22 rst_n = 1;
    wait (halted);
    if (gpio !== 8'd8) begin fouten = fouten + 1; $display("FAIL: %0d van 8 bytes kwamen goed terug", gpio); end
    if (pulsen !== 64) begin fouten = fouten + 1; $display("FAIL: %0d SCLK-pulsen, verwacht 64", pulsen); end
    if (cs_n !== 1'b1) begin fouten = fouten + 1; $display("FAIL: CS moet aan het eind weer hoog zijn"); end
    if (fb_we) begin fouten = fouten + 1; $display("FAIL: er mag niets naar het framebuffer gaan"); end
    if (fouten == 0) $display("PASS: de CPU verstuurt 8 bytes via SPI en ontvangt ze terug (%0d klokken met CS laag)", cs_laag);
    $finish;
  end
endmodule
