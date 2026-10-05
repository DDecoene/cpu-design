// FILE: week09/sv_style.v
module counter_sv #(parameter W = 8) (
  input  logic         clk, rst_n, en,
  output logic [W-1:0] q
);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)  q <= '0;
    else if (en) q <= q + 1'b1;
endmodule
