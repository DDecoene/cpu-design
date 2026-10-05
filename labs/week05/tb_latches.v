// FILE: week05/tb_latches.v
module tb_latches;
  reg s, r, d, en, clk;
  wire q_sr, qn_sr, q_dl, qn_dl, q_ff;
  integer fouten = 0;

  sr_latch sr(s, r, q_sr, qn_sr);
  d_latch  dl(d, en, q_dl, qn_dl);
  dff_ms   ff(clk, d, q_ff);

  task check(input expected, input actual, input [127:0] naam);
    if (actual !== expected) begin
      fouten = fouten + 1;
      $display("FAIL %0s: verwacht %b, kreeg %b", naam, expected, actual);
    end
  endtask

  initial begin
    // SR-latch: eerst zetten we hem in een bekende toestand.
    s = 1; r = 0; #1; check(1, q_sr, "sr set");
    s = 0; r = 0; #1; check(1, q_sr, "sr hold 1");
    s = 0; r = 1; #1; check(0, q_sr, "sr reset");
    s = 0; r = 0; #1; check(0, q_sr, "sr hold 0");

    // D-latch: transparant bij en=1, houdt vast bij en=0.
    en = 1; d = 1; #1; check(1, q_dl, "dlatch transparant 1");
    en = 0; #1; d = 0; #1; check(1, q_dl, "dlatch houdt 1 vast");
    en = 1; #1; check(0, q_dl, "dlatch transparant 0");

    // Master-slave flipflop: Q verandert alleen op de stijgende flank.
    // Eerst een klokpuls met d=0, zodat de flipflop een bekende toestand heeft (zoals een reset).
    clk = 0; d = 0; #5;   // master neemt d=0 over
    clk = 1; #5;          // slave neemt dat over
    clk = 0; #5;
    d = 1; #5;           check(0, q_ff, "ff voor flank");
    clk = 1; #5;         check(1, q_ff, "ff na flank");
    d = 0; #5;           check(1, q_ff, "ff negeert d bij klok hoog");
    clk = 0; #5;         check(1, q_ff, "ff negeert dalende flank");
    clk = 1; #5;         check(0, q_ff, "ff neemt d=0 over");

    if (fouten == 0) $display("PASS: latches en master-slave flipflop werken");
  end
endmodule
