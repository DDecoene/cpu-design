// FILE: tta/tb_tta_run.v
// Draait een geassembleerd TTA-programma en toont uitvoer en eindtoestand. Gebruik via run_tta.sh.
module tb_tta_run;
  reg clk = 0, rst_n = 0;
  reg [7:0] in_port = 0;
  wire [7:0] out_port, pc, r0, r1, r2, r3, res;
  wire out_valid, halted, fz, fn, fc;
  reg [8*64-1:0] pnaam, dnaam;
  integer cycli = 0, plus_in;

  tta #("none", 0, "none", 0) dut(.clk(clk), .rst_n(rst_n), .in_port(in_port), .out_port(out_port),
      .out_valid(out_valid), .halted(halted), .pc_out(pc), .r0(r0), .r1(r1), .r2(r2), .r3(r3),
      .res_out(res), .flag_z(fz), .flag_n(fn), .flag_c(fc));
  always #5 clk = ~clk;

  always @(posedge clk) if (out_valid) $display("  uitvoer: %0d (0x%h)", out_port, out_port);

  initial begin
    #1;
    if (!$value$plusargs("prog=%s", pnaam)) begin
      $display("PASS: tb_tta_run zonder programma. Gebruik: vvp ttarun.vvp +prog=programma.hex [+data=programma.dat] [+in=waarde]");
      $finish;
    end
    $readmemh(pnaam, dut.rom);
    if ($value$plusargs("data=%s", dnaam)) $readmemh(dnaam, dut.ram);
    if ($value$plusargs("in=%d", plus_in)) in_port = plus_in;
    #21 rst_n = 1;
    while (!halted && cycli < 1000000) begin @(negedge clk); cycli = cycli + 1; end
    @(negedge clk);
    $display("Klaar na %0d cycli (= %0d moves)", cycli, cycli);
    $display("R0=%3d R1=%3d R2=%3d R3=%3d RES=%3d  ZNC = %b%b%b", r0, r1, r2, r3, res, fz, fn, fc);
    $finish;
  end
endmodule
