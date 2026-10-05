// FILE: beeld/vga_bars.v
// Testbeeld: een witte rand, acht kleurbalken en een grijsverloop.
// De rand laat zien of de hoeken van het beeld goed liggen, de balken of de kleurkanalen kloppen.
module vga_bars(
  input  [10:0] x,
  input  [10:0] y,
  input         active,
  output reg [3:0] r, g, b
);
  // Balknummer 0..7 zonder delen: tel hoeveel grenzen (elke 80 pixels) x al voorbij is.
  wire [2:0] bar = (x >= 80) + (x >= 160) + (x >= 240) + (x >= 320) + (x >= 400) + (x >= 480) + (x >= 560);

  always @* begin
    r = 4'h0; g = 4'h0; b = 4'h0;
    if (active) begin
      if (x == 0 || x == 639 || y == 0 || y == 479) begin
        r = 4'hF; g = 4'hF; b = 4'hF;                  // witte rand van 1 pixel
      end else if (y < 320) begin
        r = {4{bar[2]}}; g = {4{bar[1]}}; b = {4{bar[0]}};   // zwart, blauw, groen, cyaan, rood, magenta, geel, wit
      end else begin
        r = x[7:4]; g = x[7:4]; b = x[7:4];            // 16 grijstinten, elke 16 pixels een stap
      end
    end
  end
endmodule
