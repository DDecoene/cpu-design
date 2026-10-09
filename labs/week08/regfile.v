module regfile #(parameter DW = 8) (
  input           clk,
  input           we,
  input  [2:0]    wa,
  input  [DW-1:0] wd,
  input  [2:0]    ra1,
  input  [2:0]    ra2,
  output [DW-1:0] rd1,
  output [DW-1:0] rd2
);
  reg [DW-1:0] r [0:7];
  integer i;
  initial for (i = 0; i < 8; i = i + 1) r[i] = {DW{1'b0}};

  assign rd1 = r[ra1];
  assign rd2 = r[ra2];

  always @(posedge clk)
    if (we) r[wa] <= wd;
endmodule
