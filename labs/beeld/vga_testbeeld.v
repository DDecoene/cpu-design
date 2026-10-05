// FILE: beeld/vga_testbeeld.v
// Het eerste complete beeld: tijdbasis plus testbeeld, met uitgangsregisters.
// Alle uitgangen worden samen een klok vertraagd, dus sync en kleur blijven uitgelijnd en er komen geen glitches op de pinnen.
module vga_testbeeld(
  input        pclk,
  input        rst_n,
  output reg   hsync, vsync,
  output reg [3:0] r, g, b
);
  wire hs, vs, active;
  wire [10:0] x, y;
  wire [3:0] pr, pg, pb;

  vga_sync sync(.pclk(pclk), .rst_n(rst_n), .hsync(hs), .vsync(vs), .active(active), .vblank(), .x(x), .y(y));
  vga_bars bars(.x(x), .y(y), .active(active), .r(pr), .g(pg), .b(pb));

  always @(posedge pclk) begin
    hsync <= hs; vsync <= vs;
    r <= pr; g <= pg; b <= pb;
  end
endmodule
