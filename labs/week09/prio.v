// FILE: week09/prio.v
// Prioriteitsencoder: het nummer van de hoogste ingang die 1 is.
module prio_enc8(input [7:0] in, output reg [2:0] y, output valid);
  assign valid = |in;
  always @* begin
    casez (in)
      8'b1???_????: y = 3'd7;
      8'b01??_????: y = 3'd6;
      8'b001?_????: y = 3'd5;
      8'b0001_????: y = 3'd4;
      8'b0000_1???: y = 3'd3;
      8'b0000_01??: y = 3'd2;
      8'b0000_001?: y = 3'd1;
      default:      y = 3'd0;
    endcase
  end
endmodule
