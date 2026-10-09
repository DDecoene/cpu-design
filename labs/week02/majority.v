module majority(input a, input b, input c, output y);
  wire t1, t2, t3, t12;
  nand2 g1(a, b, t1);
  nand2 g2(b, c, t2);
  nand2 g3(a, c, t3);
  and_n g4(t1, t2, t12);
  nand2 g5(t12, t3, y);
endmodule
