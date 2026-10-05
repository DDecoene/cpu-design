// FILE: beeld/vga_sync.v
// De tijdbasis van een VGA-beeld: twee tellers die pixels en lijnen tellen.
// Standaard: 640x480 bij 60 Hz, pixelklok ongeveer 25 MHz, negatieve syncpulsen.
module vga_sync #(
  parameter H_VIS = 640, H_FP = 16, H_SYNC = 96, H_BP = 48,   // horizontaal, in pixels
  parameter V_VIS = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33,   // verticaal, in lijnen
  parameter SYNC_NEG = 1                                       // 1: de syncpulsen zijn laag
) (
  input         pclk,
  input         rst_n,
  output        hsync,     // het niveau dat naar de monitor gaat
  output        vsync,
  output        active,    // 1 in het zichtbare gebied
  output        vblank,    // 1 buiten het zichtbare gebied, onder en boven
  output [10:0] x,         // pixelpositie in de lijn
  output [10:0] y          // lijnnummer
);
  localparam H_TOT = H_VIS + H_FP + H_SYNC + H_BP;
  localparam V_TOT = V_VIS + V_FP + V_SYNC + V_BP;

  reg [10:0] hc, vc;
  always @(posedge pclk or negedge rst_n)
    if (!rst_n) begin hc <= 0; vc <= 0; end
    else if (hc == H_TOT - 1) begin
      hc <= 0;
      vc <= (vc == V_TOT - 1) ? 11'd0 : vc + 1'b1;
    end else hc <= hc + 1'b1;

  wire hs = (hc >= H_VIS + H_FP) && (hc < H_VIS + H_FP + H_SYNC);
  wire vs = (vc >= V_VIS + V_FP) && (vc < V_VIS + V_FP + V_SYNC);

  assign hsync  = SYNC_NEG ? ~hs : hs;
  assign vsync  = SYNC_NEG ? ~vs : vs;
  assign active = (hc < H_VIS) && (vc < V_VIS);
  assign vblank = (vc >= V_VIS);
  assign x = hc;
  assign y = vc;
endmodule
