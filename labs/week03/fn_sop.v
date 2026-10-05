// FILE: week03/fn_sop.v
// f = Σm(0,1,2,5,8,9,10) rechtstreeks uit de tabel.
module fn_sop(input a, input b, input c, input d, output y);
  assign y = (~a & ~b & ~c & ~d)   // m0
           | (~a & ~b & ~c &  d)   // m1
           | (~a & ~b &  c & ~d)   // m2
           | (~a &  b & ~c &  d)   // m5
           | ( a & ~b & ~c & ~d)   // m8
           | ( a & ~b & ~c &  d)   // m9
           | ( a & ~b &  c & ~d);  // m10
endmodule

// Vereenvoudigd met de K-map: f = B'D' + B'C' + A'C'D
module fn_min(input a, input b, input c, input d, output y);
  assign y = (~b & ~d) | (~b & ~c) | (~a & ~c & d);
endmodule
