// Drie bronnen op één bus. Elk zet zijn data alleen op de bus als zijn oe aan staat.
module bus3(
  input  [7:0] a, b, c,
  input        oe_a, oe_b, oe_c,
  output [7:0] bus
);
  assign bus = oe_a ? a : 8'bz;
  assign bus = oe_b ? b : 8'bz;
  assign bus = oe_c ? c : 8'bz;
endmodule
