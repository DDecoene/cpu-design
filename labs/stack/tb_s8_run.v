// Draait een met forth.py gemaakt programma en toont de stapel. Gebruik via runfs.sh.
module tb_s8_run;
  reg clk = 0, rst_n = 0;
  wire halted; wire [7:0] pc, tos; wire [3:0] dsp;
  reg [8*64-1:0] pnaam;
  integer cycli = 0, k;
  s8 #("none", 0) dut(clk, rst_n, halted, pc, tos, dsp);
  always #5 clk = ~clk;
  initial begin
    #1;
    if (!$value$plusargs("prog=%s", pnaam)) begin
      $display("PASS: tb_s8_run zonder programma. Gebruik: vvp s8run.vvp +prog=programma.hex");
      $finish;
    end
    $readmemh(pnaam, dut.code);
    #21 rst_n = 1;
    while (!halted && cycli < 1000000) begin @(negedge clk); cycli = cycli + 1; end
    $display("Klaar na %0d cycli. Stapeldiepte %0d.", cycli, dsp);
    for (k = 0; k < dsp; k = k + 1) $display("  stapel[%0d] = %0d", k, dut.ds[k]);
    $finish;
  end
endmodule
