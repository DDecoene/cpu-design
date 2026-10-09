// Serieel-in, parallel-uit schuifregister.
module shift_reg #(parameter W = 8) (
  input          clk,
  input          rst_n,
  input          en,
  input          sin,
  output reg [W-1:0] q
);
  always @(posedge clk or negedge rst_n)
    if (!rst_n)  q <= {W{1'b0}};
    else if (en) q <= {q[W-2:0], sin};   // schuif naar links, sin komt rechts binnen
endmodule
