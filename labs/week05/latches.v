// SR-latch uit twee NOR-poorten.
module sr_latch(input s, input r, output q, output qn);
  nor g1(q,  r, qn);
  nor g2(qn, s, q);
endmodule

// Gated D-latch uit vier NAND-poorten.
module d_latch(input d, input en, output q, output qn);
  wire sn, rn;
  nand g1(sn, d, en);
  nand g2(rn, ~d, en);
  nand g3(q,  sn, qn);
  nand g4(qn, rn, q);
endmodule

// D-flipflop (stijgende flank) uit twee D-latches: master-slave.
module dff_ms(input clk, input d, output q);
  wire qm, qmn, qn;
  d_latch master(d,  ~clk, qm, qmn);
  d_latch slave (qm,  clk, q,  qn);
endmodule
