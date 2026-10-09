// De geheugenkaart met video en SPI: mmio_v met de SPI-poort op 0xFC tot 0xFF erbij.
module mmio_b #(parameter DIV = 16, parameter TDIV = 1, parameter DATA = "data.hex", parameter DLOAD = 0) (
  input        clk,
  input        rst_n,
  input        we,
  input        rd,
  input  [7:0] addr,
  input  [7:0] wdata,
  output [7:0] rdata,
  output       txd,
  input        rxd,
  input  [7:0] gpio_in,
  output [7:0] gpio_out,
  output       irq,
  input        vblank,
  output       fb_we,
  output [13:0] fb_waddr,
  output [7:0]  fb_wdata,
  output       spi_sclk, spi_mosi, spi_cs_n,
  input        spi_miso
);
  wire [7:0] v_rdata, s_comb;
  mmio_v #(DIV, TDIV, DATA, DLOAD) basis(.clk(clk), .rst_n(rst_n), .we(we), .rd(rd), .addr(addr), .wdata(wdata), .rdata(v_rdata),
                                         .txd(txd), .rxd(rxd), .gpio_in(gpio_in), .gpio_out(gpio_out), .irq(irq),
                                         .vblank(vblank), .fb_we(fb_we), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata));

  wire ssel = (addr[7:2] == 6'b111111);                      // 0xFC tot 0xFF
  spi_io sio(.clk(clk), .rst_n(rst_n), .sel(ssel), .we(we), .reg_sel(addr[1:0]), .wdata(wdata), .rdata(s_comb),
             .sclk(spi_sclk), .mosi(spi_mosi), .cs_n(spi_cs_n), .miso(spi_miso));

  reg [7:0] s_q;
  reg       ssel_q;
  always @(posedge clk) begin s_q <= s_comb; ssel_q <= ssel; end
  assign rdata = ssel_q ? s_q : v_rdata;
endmodule
