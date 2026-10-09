// De complete beeldcomputer: CPU, SPI naar de SD-kaart, framebuffer en VGA-uitgang.
// Het programma staat in boot.hex (instructies) en boot.dat (de commando's voor de kaart in het datageheugen).
module beeld_top #(
  parameter PROG = "boot.hex", parameter DATA = "boot.dat", parameter DLOAD = 1,
  parameter DIV = 104, parameter TDIV = 12000            // 12 MHz: 115 200 baud en een timertik van 1 ms
) (
  input        clk,          // CPU-klok, 12 MHz
  input        pclk,         // pixelklok, ongeveer 25 MHz
  input        rst_n,
  output       hsync, vsync,
  output [3:0] r, g, b,
  output       sd_sclk, sd_mosi, sd_cs_n,
  input        sd_miso,
  output [7:0] led,
  output       txd,
  input        rxd
);
  wire rst_cpu, rst_pix;
  reset_sync rs_cpu(.clk(clk),  .rst_n_in(rst_n), .rst_n_out(rst_cpu));
  reset_sync rs_pix(.clk(pclk), .rst_n_in(rst_n), .rst_n_out(rst_pix));

  wire        vblank, fb_we;
  wire [13:0] fb_waddr;
  wire [7:0]  fb_wdata;

  cpu_b #(PROG, 1, DIV, TDIV, DATA, DLOAD) cpu(
    .clk(clk), .rst_n(rst_cpu), .halted(),
    .pc_out(), .r0(), .r1(), .r2(), .r3(), .r4(), .r5(), .r6(), .r7(),
    .flag_z(), .flag_n(), .flag_c(), .flag_v(),
    .txd(txd), .rxd(rxd), .gpio_in(8'h00), .gpio_out(led),
    .vblank(vblank), .fb_we(fb_we), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata),
    .spi_sclk(sd_sclk), .spi_mosi(sd_mosi), .spi_cs_n(sd_cs_n), .spi_miso(sd_miso)
  );

  video_out vid(
    .pclk(pclk), .rst_n(rst_pix),
    .wclk(clk), .we(fb_we), .waddr(fb_waddr), .wdata(fb_wdata),
    .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .vblank(vblank)
  );
endmodule
