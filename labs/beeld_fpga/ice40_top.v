// FILE: beeld_fpga/ice40_top.v
// Het toplevel voor een iCE40 UP5K-bord met een klok van 12 MHz (bijvoorbeeld de iCEBreaker), een VGA-module met 4 bit per kleur
// en een microSD-module. De CPU draait op de 12 MHz van het bord, het beeld op de 25,125 MHz van de PLL.
module ice40_top(
  input        clk12,
  input        btn_n,                 // resetknop (0 = ingedrukt)
  output [3:0] vga_r, vga_g, vga_b,
  output       vga_hs, vga_vs,
  output       sd_sck, sd_mosi, sd_cs,
  input        sd_miso,
  output [7:0] led,                   // statusstappen van het bootprogramma; sluit aan wat je bord heeft
  output       uart_tx,
  input        uart_rx
);
  wire pclk, locked;
  pll_ice40 pll(.clk_in(clk12), .clk_out(pclk), .locked(locked));

  // Zolang de PLL niet vergrendeld is, houden we alles in reset. De knop werkt zoals altijd actief laag.
  wire rst_n = btn_n & locked;

  beeld_top #(.DIV(104), .TDIV(12000)) top(          // 12 MHz: 115 200 baud en een timertik van 1 ms
    .clk(clk12), .pclk(pclk), .rst_n(rst_n),
    .hsync(vga_hs), .vsync(vga_vs), .r(vga_r), .g(vga_g), .b(vga_b),
    .sd_sclk(sd_sck), .sd_mosi(sd_mosi), .sd_cs_n(sd_cs), .sd_miso(sd_miso),
    .led(led), .txd(uart_tx), .rxd(uart_rx)
  );
endmodule
