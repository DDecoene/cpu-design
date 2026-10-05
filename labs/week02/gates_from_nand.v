// FILE: week02/gates_from_nand.v
// Alle andere poorten, uitsluitend gebouwd uit nand2.
module not_n(input a, output y);
  nand2 g(a, a, y);
endmodule

module and_n(input a, input b, output y);
  wire t;
  nand2 g1(a, b, t);
  not_n g2(t, y);
endmodule

module or_n(input a, input b, output y);
  wire na, nb;
  not_n g1(a, na);
  not_n g2(b, nb);
  nand2 g3(na, nb, y);
endmodule

module xor_n(input a, input b, output y);
  wire t, u, v;
  nand2 g1(a, b, t);
  nand2 g2(a, t, u);
  nand2 g3(b, t, v);
  nand2 g4(u, v, y);
endmodule
