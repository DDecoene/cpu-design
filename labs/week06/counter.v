module counter #(parameter W = 8) (
  input              clk,
  input              rst_n,
  input              en,
  input              load,
  input      [W-1:0] d,
  output reg [W-1:0] q
);
  always @(posedge clk or negedge rst_n)
    if (!rst_n)      q <= {W{1'b0}};
    else if (load)   q <= d;
    else if (en)     q <= q + 1'b1;
endmodule
