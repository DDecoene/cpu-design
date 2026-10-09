// Een D-flipflop, zoals je hem in echte ontwerpen schrijft.
module dff(input clk, input d, output reg q);
  always @(posedge clk)
    q <= d;
endmodule

// Met asynchrone reset (actief laag): werkt direct, zonder op de klok te wachten.
module dff_ar(input clk, input rst_n, input d, output reg q);
  always @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 1'b0;
    else        q <= d;
endmodule
