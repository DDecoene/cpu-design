// Twee-flipflop-synchronizer voor asynchrone ingangen.
module sync2(input clk, input async_in, output reg out);
  reg meta;
  always @(posedge clk) begin
    meta <= async_in;
    out  <= meta;
  end
endmodule
