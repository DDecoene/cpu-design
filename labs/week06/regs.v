// Register met asynchrone reset en load-enable.
module reg_en #(parameter W = 8) (
  input              clk,
  input              rst_n,
  input              en,
  input      [W-1:0] d,
  output reg [W-1:0] q
);
  always @(posedge clk or negedge rst_n)
    if (!rst_n)  q <= {W{1'b0}};
    else if (en) q <= d;
endmodule
