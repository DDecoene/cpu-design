// FILE: beeld/vga_mon.v
// Een virtuele monitor, alleen voor simulatie. Hij kijkt, net als een echte monitor, alleen naar de syncpulsen en bepaalt daaruit
// waar de pixels liggen: het beeld begint 144 pixels na het begin van de horizontale sync (96 sync + 48 back porch)
// en 35 lijnen na het begin van de verticale sync (2 sync + 33 back porch).
// Elk volledig beeld komt in img[y*640 + x] met 12 bit per pixel ({r,g,b}); write_ppm schrijft het weg om te bekijken.
module vga_mon #(parameter W = 640, parameter H = 480, parameter H_START = 144, parameter V_START = 35) (
  input        pclk,
  input        hsync, vsync,
  input  [3:0] r, g, b,
  output reg   frame_done,                 // een klok lang 1 als een volledig beeld binnen is
  output reg [31:0] frames
);
  reg [11:0] img [0:W*H-1];
  integer hx = 0, k = 0, x, y;
  integer painted = 0, unknown = 0;        // lopende tellers
  integer painted_last = 0, unknown_last = 0;   // tellers van het laatste volledige beeld
  reg tracking = 1'b0, hs_p = 1'b1, vs_p = 1'b1;
  initial frames = 0;

  always @(posedge pclk) begin
    frame_done <= 1'b0;
    if (vs_p === 1'b1 && vsync === 1'b0) begin           // vsync begint: het vorige beeld is af
      if (tracking) begin
        frame_done <= 1'b1; frames <= frames + 1;
        painted_last = painted; unknown_last = unknown;
      end
      tracking = 1'b1; k = 0; painted = 0; unknown = 0;
    end
    if (hs_p === 1'b1 && hsync === 1'b0) begin hx = 0; k = k + 1; end
    else hx = hx + 1;
    x = hx - H_START;
    y = k - V_START;
    if (tracking && x >= 0 && x < W && y >= 0 && y < H) begin
      img[y*W + x] = {r, g, b};
      painted = painted + 1;
      if (^{r, g, b} === 1'bx) unknown = unknown + 1;
    end
    hs_p = hsync; vs_p = vsync;
  end

  task write_ppm(input [8*80-1:0] name);   // binaire PPM (P6), 8 bit per kleur: de 4 bit worden met 17 vermenigvuldigd
    integer fd, i;
    reg [11:0] p;
    begin
      fd = $fopen(name, "wb");
      if (fd == 0) $display("let op: kan %0s niet schrijven (bestaat de map?)", name);
      else begin
        $fwrite(fd, "P6\n%0d %0d\n255\n", W, H);
        for (i = 0; i < W*H; i = i + 1) begin
          p = img[i];
          $fwrite(fd, "%c%c%c", p[11:8] * 17, p[7:4] * 17, p[3:0] * 17);
        end
        $fclose(fd);
      end
    end
  endtask
endmodule
