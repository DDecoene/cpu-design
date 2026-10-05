// FILE: cpu_pipe/tb_compare.v
// Draait hetzelfde programma op de W8 (twee cycli per instructie) en op de gepijplijnde W8P,
// controleert dat het eindresultaat identiek is en meet de cycli.
module pair #(parameter P = "", parameter D = "none", parameter DL = 0) (
  input         clk,
  input         rst_n,
  output        done,
  output reg [31:0] cyc_w,
  output reg [31:0] cyc_p,
  output reg    same
);
  wire hw, hp, wz, wn, wc, wv, pz, pn, pc_, pv;
  wire [7:0] wpc, w0, w1, w2, w3, w4, w5, w6, w7, ppc, p0, p1, p2, p3, p4, p5, p6, p7;
  cpu   #(P, 1, D, DL) w(clk, rst_n, hw, wpc, w0, w1, w2, w3, w4, w5, w6, w7, wz, wn, wc, wv);
  cpu_p #(P, 1, D, DL) p(clk, rst_n, hp, ppc, p0, p1, p2, p3, p4, p5, p6, p7, pz, pn, pc_, pv);
  assign done = hw & hp;

  initial begin cyc_w = 0; cyc_p = 0; end
  always @(posedge clk) if (rst_n) begin
    if (!hw) cyc_w <= cyc_w + 1;
    if (!hp) cyc_p <= cyc_p + 1;
  end

  integer k;
  always @* begin
    same = ({w0, w1, w2, w3, w4, w5, w6, w7} === {p0, p1, p2, p3, p4, p5, p6, p7})
        && ({wz, wn, wc, wv} === {pz, pn, pc_, pv});
    for (k = 0; k < 256; k = k + 1) if (w.dm.mem[k] !== p.dm.mem[k]) same = 0;
  end
endmodule

module tb_compare;
  reg clk = 0, rst_n = 0;
  wire [5:0] d;
  wire [31:0] cw0, cp0, cw1, cp1, cw2, cp2, cw3, cp3, cw4, cp4, cw5, cp5;
  wire [5:0] s;
  integer fouten = 0;
  pair #("sum.hex")                    a0(clk, rst_n, d[0], cw0, cp0, s[0]);
  pair #("mul.hex")                    a1(clk, rst_n, d[1], cw1, cp1, s[1]);
  pair #("sort.hex", "sort.dat", 1)    a2(clk, rst_n, d[2], cw2, cp2, s[2]);
  pair #("primes.hex")                 a3(clk, rst_n, d[3], cw3, cp3, s[3]);
  pair #("gcd.hex")                    a4(clk, rst_n, d[4], cw4, cp4, s[4]);
  pair #("calls.hex")                  a5(clk, rst_n, d[5], cw5, cp5, s[5]);
  always #5 clk = ~clk;

  task rapport(input [127:0] naam, input [31:0] w, input [31:0] p, input gelijk);
    begin
      $display("%0s  W8: %5d cycli   W8P: %5d cycli   versnelling %0d.%02d x   resultaat %0s",
               naam, w, p, (w * 100 / p) / 100, (w * 100 / p) % 100, gelijk ? "identiek" : "VERSCHILT");
      if (!gelijk) fouten = fouten + 1;
      if (!(p < w)) fouten = fouten + 1;
    end
  endtask

  initial begin
    #22 rst_n = 1;
    wait (&d);
    #20;
    rapport("som      ", cw0, cp0, s[0]);
    rapport("mul 16bit", cw1, cp1, s[1]);
    rapport("sorteren ", cw2, cp2, s[2]);
    rapport("priem    ", cw3, cp3, s[3]);
    rapport("ggd      ", cw4, cp4, s[4]);
    rapport("subroutine", cw5, cp5, s[5]);
    if (fouten == 0) $display("PASS: de gepijplijnde CPU geeft overal hetzelfde resultaat en is overal sneller");
    $finish;
  end
endmodule
