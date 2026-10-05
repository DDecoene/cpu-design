// FILE: week12/sext.v
// Tekenuitbreiding van 8 naar 16 bits.
module sext8to16(input [7:0] x, output [15:0] y);
  assign y = {{8{x[7]}}, x};
endmodule
