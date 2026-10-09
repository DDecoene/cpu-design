// De registers van het beeld, zoals de CPU ze ziet (adressen 0xF8 tot en met 0xFB):
//   0xF8  FB_LO      laag byte van het byteadres in het framebuffer (lezen en schrijven)
//   0xF9  FB_HI      hoog byte (6 bit; lezen en schrijven)
//   0xFA  FB_DATA    schrijven: zet dit byte (twee pixels) op het adres en tel het adres 1 op
//   0xFB  VID_STATUS lezen: bit 0 = de monitor is in de verticale blanking
module video_io(
  input         clk,
  input         rst_n,
  input         sel,                // het adres ligt in 0xF8 tot 0xFB
  input         we,
  input  [1:0]  reg_sel,            // de onderste twee adresbits
  input  [7:0]  wdata,
  output reg [7:0] rdata,
  input         vblank_p,           // komt uit het pixelklokdomein
  output        fb_we,
  output [13:0] fb_waddr,
  output [7:0]  fb_wdata
);
  localparam PIXBYTES = 14'd9600;   // 160 x 120 pixels, 2 per byte
  reg [13:0] ptr;
  reg vb1, vb2;                     // synchronizer: vblank_p is niet gelijk met onze klok (week 6)

  assign fb_we    = we && sel && reg_sel == 2'd2 && ptr < PIXBYTES;   // schrijven voorbij het einde wordt genegeerd
  assign fb_waddr = ptr;
  assign fb_wdata = wdata;

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin ptr <= 14'd0; vb1 <= 1'b0; vb2 <= 1'b0; end
    else begin
      vb1 <= vblank_p; vb2 <= vb1;
      if (we && sel) case (reg_sel)
        2'd0: ptr[7:0]  <= wdata;
        2'd1: ptr[13:8] <= wdata[5:0];
        2'd2: if (ptr < PIXBYTES) ptr <= ptr + 14'd1;
        default: ;
      endcase
    end

  always @* case (reg_sel)
    2'd0:    rdata = ptr[7:0];
    2'd1:    rdata = {2'b00, ptr[13:8]};
    2'd3:    rdata = {7'b0, vb2};
    default: rdata = 8'h00;
  endcase
endmodule
