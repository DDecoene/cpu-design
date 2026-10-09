// Is het BCD-cijfer (ABCD, alleen 0..9 komt voor) groter of gelijk aan 5?
module bcd_ge5(input a, input b, input c, input d, output y);
  assign y = a | (b & d) | (b & c);
endmodule

// Dezelfde functie, maar uitsluitend NAND-poorten (via De Morgan):
//   A + BD + BC = ((A')·(BD)'·(BC)')'
module bcd_ge5_nand(input a, input b, input c, input d, output y);
  wire na = ~a;
  wire t1 = ~(b & d);
  wire t2 = ~(b & c);
  assign y = ~(na & t1 & t2);
endmodule
