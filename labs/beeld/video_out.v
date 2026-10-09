// Van framebuffer naar VGA-pinnen. Het scherm is 160 x 120 blokken van 4 x 4 pixels, elk blok met een van 16 kleuren.
// Twee blokken per byte: het linker in de hoge, het rechter in de lage nibble. Een rij is dus 80 bytes.
module video_out(
  input        pclk,
  input        rst_n,                // al gesynchroniseerd met pclk
  input        wclk,                 // schrijfpoort van het framebuffer, in het klokdomein van de CPU
  input        we,
  input [13:0] waddr,
  input [7:0]  wdata,
  output reg   hsync, vsync,
  output reg [3:0] r, g, b,
  output       vblank                // in het pclk-domein; de CPU-kant synchroniseert dit zelf
);
  wire hs, vs, active;
  wire [10:0] x, y;
  vga_sync sync(.pclk(pclk), .rst_n(rst_n), .hsync(hs), .vsync(vs), .active(active), .vblank(vblank), .x(x), .y(y));

  // Adres van het byte dat bij deze pixel hoort: rij * 80 + kolom / 2, met rij = y / 4 en kolom = x / 4.
  wire [7:0]  bx = x[9:2];                                   // 0 tot 159
  wire [6:0]  by = y[8:2];                                   // 0 tot 119 in het zichtbare gebied
  wire [13:0] raddr = {by, 6'b000000} + {by, 4'b0000} + bx[7:1];   // by * 64 + by * 16 + bx / 2

  wire [7:0] word;
  fb_ram ram(.wclk(wclk), .we(we), .waddr(waddr), .wdata(wdata), .rclk(pclk), .raddr(raddr), .rdata(word));

  // Het RAM antwoordt een klok te laat. Alles wat bij de pixel hoort wordt daarom ook een klok vertraagd.
  reg act1, hs1, vs1, odd1;
  always @(posedge pclk) begin act1 <= active; hs1 <= hs; vs1 <= vs; odd1 <= bx[0]; end

  function [11:0] palette(input [3:0] i);                    // 16 kleuren in de stijl van EGA, 4 bit per kleurkanaal
    case (i)
      4'd0:  palette = 12'h000;   // zwart
      4'd1:  palette = 12'h00A;   // blauw
      4'd2:  palette = 12'h0A0;   // groen
      4'd3:  palette = 12'h0AA;   // cyaan
      4'd4:  palette = 12'hA00;   // rood
      4'd5:  palette = 12'hA0A;   // magenta
      4'd6:  palette = 12'hA50;   // bruin
      4'd7:  palette = 12'hAAA;   // lichtgrijs
      4'd8:  palette = 12'h555;   // donkergrijs
      4'd9:  palette = 12'h55F;   // lichtblauw
      4'd10: palette = 12'h5F5;   // lichtgroen
      4'd11: palette = 12'h5FF;   // lichtcyaan
      4'd12: palette = 12'hF55;   // lichtrood
      4'd13: palette = 12'hF5F;   // lichtmagenta
      4'd14: palette = 12'hFF5;   // geel
      default: palette = 12'hFFF; // wit
    endcase
  endfunction

  wire [3:0]  idx = odd1 ? word[3:0] : word[7:4];
  wire [11:0] rgb = act1 ? palette(idx) : 12'h000;           // buiten het beeld moet de uitgang zwart zijn

  always @(posedge pclk) begin                                // uitgangsregisters: schone pinnen
    hsync <= hs1; vsync <= vs1;
    {r, g, b} <= rgb;
  end
endmodule
