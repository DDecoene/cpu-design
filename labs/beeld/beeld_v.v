// FILE: beeld/beeld_v.v
// CPU en beeld aan elkaar: de W8F met het framebuffer en de VGA-uitgang. Twee klokken: clk voor de CPU, pclk voor het beeld.
module beeld_v #(
  parameter PROG = "prog.hex", parameter DATA = "data.hex", parameter DLOAD = 0,
  parameter DIV = 16, parameter TDIV = 1
) (
  input        clk,          // CPU-klok (op een iCEBreaker: de 12 MHz van het bord)
  input        pclk,         // pixelklok (ongeveer 25 MHz, uit een PLL)
  input        rst_n,
  output       hsync, vsync,
  output [3:0] r, g, b,
  output       txd,
  input        rxd,
  input  [7:0] gpio_in,
  output [7:0] gpio_out
);
  wire rst_cpu, rst_pix;
  reset_sync rs_cpu(.clk(clk),  .rst_n_in(rst_n), .rst_n_out(rst_cpu));
  reset_sync rs_pix(.clk(pclk), .rst_n_in(rst_n), .rst_n_out(rst_pix));

  wire        vblank, fb_we;
  wire [13:0] fb_waddr;
  wire [7:0]  fb_wdata;

  cpu_v #(PROG, 1, DIV, TDIV, DATA, DLOAD) cpu(
    .clk(clk), .rst_n(rst_cpu), .halted(),
    .pc_out(), .r0(), .r1(), .r2(), .r3(), .r4(), .r5(), .r6(), .r7(),
    .flag_z(), .flag_n(), .flag_c(), .flag_v(),
    .txd(txd), .rxd(rxd), .gpio_in(gpio_in), .gpio_out(gpio_out),
    .vblank(vblank), .fb_we(fb_we), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata)
  );

  video_out vid(
    .pclk(pclk), .rst_n(rst_pix),
    .wclk(clk), .we(fb_we), .waddr(fb_waddr), .wdata(fb_wdata),
    .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .vblank(vblank)
  );
endmodule
