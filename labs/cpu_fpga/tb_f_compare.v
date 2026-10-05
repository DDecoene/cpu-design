// FILE: cpu_fpga/tb_f_compare.v
// Dezelfde programma's op W8I (asynchroon RAM) en W8F (blok-RAM, LD in 3 cycli):
// het resultaat moet identiek zijn, en W8F mag precies één cyclus per uitgevoerde LD langer doen.
module pair_f #(parameter P = "", parameter D = "none", parameter DL = 0) (
  input clk, input rst_n,
  output done,
  output reg [31:0] cyc_i, cyc_f, loads,
  output reg same
);
  wire hi, hf;
  wire [7:0] ipc, i0, i1, i2, i3, i4, i5, i6, i7, fpc, f0, f1, f2, f3, f4, f5, f6, f7;
  wire iz, in_, ic, iv, fz, fn, fc, fv;
  cpu_i #(P, 1, 16, 1, D, DL) a(.clk(clk), .rst_n(rst_n), .halted(hi), .pc_out(ipc), .r0(i0), .r1(i1), .r2(i2), .r3(i3),
      .r4(i4), .r5(i5), .r6(i6), .r7(i7), .flag_z(iz), .flag_n(in_), .flag_c(ic), .flag_v(iv), .rxd(1'b1), .gpio_in(8'd0));
  cpu_f #(P, 1, 16, 1, D, DL) b(.clk(clk), .rst_n(rst_n), .halted(hf), .pc_out(fpc), .r0(f0), .r1(f1), .r2(f2), .r3(f3),
      .r4(f4), .r5(f5), .r6(f6), .r7(f7), .flag_z(fz), .flag_n(fn), .flag_c(fc), .flag_v(fv), .rxd(1'b1), .gpio_in(8'd0));
  assign done = hi & hf;
  initial begin cyc_i = 0; cyc_f = 0; loads = 0; end
  always @(posedge clk) if (rst_n) begin
    if (!hi) cyc_i <= cyc_i + 1;
    if (!hf) begin cyc_f <= cyc_f + 1; if (b.mem_rd) loads <= loads + 1; end
  end
  integer k;
  always @* begin
    same = ({i0, i1, i2, i3, i4, i5, i6, i7} === {f0, f1, f2, f3, f4, f5, f6, f7}) && ({iz, in_, ic, iv} === {fz, fn, fc, fv});
    for (k = 0; k < 240; k = k + 1) if (a.io.ram.mem[k] !== b.io.ram.mem[k]) same = 0;
  end
endmodule

module tb_f_compare;
  reg clk = 0, rst_n = 0;
  wire [5:0] d, s;
  wire [31:0] ci0, cf0, l0, ci1, cf1, l1, ci2, cf2, l2, ci3, cf3, l3, ci4, cf4, l4, ci5, cf5, l5;
  integer fouten = 0;
  pair_f #("sum.hex")                  p0(clk, rst_n, d[0], ci0, cf0, l0, s[0]);
  pair_f #("mul.hex")                  p1(clk, rst_n, d[1], ci1, cf1, l1, s[1]);
  pair_f #("sort.hex", "sort.dat", 1)  p2(clk, rst_n, d[2], ci2, cf2, l2, s[2]);
  pair_f #("primes.hex")               p3(clk, rst_n, d[3], ci3, cf3, l3, s[3]);
  pair_f #("gcd.hex")                  p4(clk, rst_n, d[4], ci4, cf4, l4, s[4]);
  pair_f #("calls.hex")                p5(clk, rst_n, d[5], ci5, cf5, l5, s[5]);
  always #5 clk = ~clk;

  task rapport(input [127:0] naam, input [31:0] ci, input [31:0] cf, input [31:0] l, input gelijk);
    begin
      $display("%0s  W8I: %5d cycli   W8F: %5d cycli   (%0d LD's)   resultaat %0s", naam, ci, cf, l, gelijk ? "identiek" : "VERSCHILT");
      if (!gelijk) fouten = fouten + 1;
      if (cf !== ci + l) begin fouten = fouten + 1; $display("  FAIL: verwacht %0d cycli", ci + l); end
    end
  endtask

  initial begin
    #22 rst_n = 1;
    wait (&d);
    #20;
    rapport("som       ", ci0, cf0, l0, s[0]);
    rapport("mul 16bit ", ci1, cf1, l1, s[1]);
    rapport("sorteren  ", ci2, cf2, l2, s[2]);
    rapport("priem     ", ci3, cf3, l3, s[3]);
    rapport("ggd       ", ci4, cf4, l4, s[4]);
    rapport("subroutine", ci5, cf5, l5, s[5]);
    if (fouten == 0) $display("PASS: W8F geeft overal hetzelfde resultaat als W8I en kost precies één extra cyclus per LD");
    $finish;
  end
endmodule
