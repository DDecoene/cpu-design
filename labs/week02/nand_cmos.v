// NAND-poort uit 4 transistoren (2 PMOS parallel, 2 NMOS in serie).
module nand_cmos(input a, input b, output y);
  supply1 vdd;        // de plusspanning
  supply0 gnd;        // massa
  wire mid;           // knooppunt tussen de twee NMOS
  pmos p1(y, vdd, a);
  pmos p2(y, vdd, b);
  nmos n1(y, mid, a);
  nmos n2(mid, gnd, b);
endmodule
