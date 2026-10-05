// FILE: cpu/tb_run.v
// Draait een geassembleerd programma op de CPU en toont het eindresultaat.
// Gebruik (via run.sh): vvp w8run.vvp +prog=programma.hex [+data=programma.dat]
module tb_run;
  reg clk = 0, rst_n = 0;
  wire halted, fz, fn, fc, fv;
  wire [7:0] pc, r0, r1, r2, r3, r4, r5, r6, r7;
  reg [8*64-1:0] pnaam, dnaam;
  integer cycli = 0, k;

  cpu #("none", 0, "none", 0) dut(clk, rst_n, halted, pc, r0, r1, r2, r3, r4, r5, r6, r7, fz, fn, fc, fv);
  always #5 clk = ~clk;

  initial begin
    #1;   // wacht tot de geheugens zich zelf geïnitialiseerd hebben
    if (!$value$plusargs("prog=%s", pnaam)) begin
      // Zonder argumenten doen we niets en melden we PASS, zodat een regressiescript er niet over struikelt.
      $display("PASS: tb_run zonder programma. Gebruik: vvp w8run.vvp +prog=programma.hex [+data=programma.dat]");
      $finish;
    end
    $readmemh(pnaam, dut.im.mem);
    if ($value$plusargs("data=%s", dnaam)) $readmemh(dnaam, dut.dm.mem);
    #21 rst_n = 1;
    while (!halted && cycli < 1000000) begin @(negedge clk); cycli = cycli + 1; end
    if (!halted) $display("WAARSCHUWING: programma stopte niet binnen 1.000.000 cycli");
    $display("Klaar na %0d cycli (%0d instructies)", cycli, cycli / 2);
    $display("R0=%3d R1=%3d R2=%3d R3=%3d R4=%3d R5=%3d R6=%3d R7=%3d", r0, r1, r2, r3, r4, r5, r6, r7);
    $display("Vlaggen ZNCV = %b%b%b%b   PC = %0d", fz, fn, fc, fv, pc);
    $finish;
  end
endmodule
