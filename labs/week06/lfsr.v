// FILE: week06/lfsr.v
// 8-bit LFSR (linear feedback shift register): een pseudo-willekeurige reeks.
// Taps op bit 8, 6, 5, 4 (positie 7, 5, 4, 3): de reeks doorloopt 255 verschillende waarden.
module lfsr8(input clk, input rst_n, output reg [7:0] q);
  wire fb = q[7] ^ q[5] ^ q[4] ^ q[3];
  always @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 8'h01;           // mag niet 0 zijn
    else        q <= {q[6:0], fb};
endmodule
