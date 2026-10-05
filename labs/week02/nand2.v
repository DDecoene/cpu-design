// FILE: week02/nand2.v
module nand2(input a, input b, output y);
  assign y = ~(a & b);
endmodule
