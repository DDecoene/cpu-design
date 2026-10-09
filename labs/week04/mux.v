// Een 2:1 mux met instelbare breedte (W bits).
module mux2 #(parameter W = 1) (
  input  [W-1:0] a,
  input  [W-1:0] b,
  input          s,
  output [W-1:0] y
);
  assign y = s ? b : a;
endmodule

// 4:1 mux gebouwd uit drie 2:1 mux'en.
module mux4 #(parameter W = 1) (
  input  [W-1:0] d0, d1, d2, d3,
  input  [1:0]   s,
  output [W-1:0] y
);
  wire [W-1:0] lo, hi;
  mux2 #(W) m0(d0, d1, s[0], lo);
  mux2 #(W) m1(d2, d3, s[0], hi);
  mux2 #(W) m2(lo, hi, s[1], y);
endmodule
