// Haalt de velden uit een 16-bit instructie.
module idecode(
  input  [15:0] ir,
  output [3:0]  op,
  output [2:0]  rd,
  output [2:0]  rs1,
  output [2:0]  rs2,
  output [2:0]  fn,
  output [2:0]  cond,
  output [7:0]  imm8,
  output [5:0]  off6
);
  assign op   = ir[15:12];
  assign rd   = ir[11:9];
  assign rs1  = ir[8:6];
  assign rs2  = ir[5:3];
  assign fn   = ir[2:0];
  assign cond = ir[11:9];
  assign imm8 = ir[7:0];
  assign off6 = ir[5:0];
endmodule
