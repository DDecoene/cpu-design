`include "asm_funcs.vh"
// Een "trace": bij elke uitgevoerde instructie een regel met PC, instructie en registers.
module tb_trace;
  reg clk = 0, rst_n = 0;
  wire halted;
  wire [7:0] r1, r2;
  integer k, aantal = 0, fouten = 0;
  reg [15:0] eerste [0:2];

  cpu #("none", 0) dut(.clk(clk), .rst_n(rst_n), .halted(halted), .r1(r1), .r2(r2));
  always #5 clk = ~clk;

  function [47:0] naam(input [3:0] op);
    case (op)
      4'h0: naam = "ALU  "; 4'h1: naam = "LDI  "; 4'h2: naam = "ADDI "; 4'h3: naam = "LD   ";
      4'h4: naam = "ST   "; 4'h5: naam = "Bcc  "; 4'h6: naam = "CMP  "; 4'h7: naam = "CMPI ";
      4'h8: naam = "CALL "; 4'h9: naam = "JR   "; 4'hF: naam = "HALT "; default: naam = "NOP  ";
    endcase
  endfunction

  // Elke keer dat een uitvoerstap (t = 1) wordt afgerond, leggen we de instructie vast.
  always @(posedge clk)
    if (rst_n && dut.ctl.t && !halted) begin
      if (aantal < 3) eerste[aantal] = dut.dp.ir;
      aantal = aantal + 1;
      $display("%4d  pc=%3d  ir=%h  %0s  R1=%3d R2=%3d  ZNCV=%b%b%b%b",
               aantal, dut.dp.pc - 8'd1, dut.dp.ir, naam(dut.dp.ir[15:12]), dut.dp.r[1], dut.dp.r[2],
               dut.flag_z, dut.flag_n, dut.flag_c, dut.flag_v);
    end

  initial begin
    for (k = 0; k < 256; k = k + 1) dut.im.mem[k] = I_NOP;
    dut.im.mem[0] = I_LDI(1, 0);
    dut.im.mem[1] = I_LDI(2, 4);
    dut.im.mem[2] = I_ALU(F_ADD, 1, 1, 2);
    dut.im.mem[3] = I_ADDI(2, 8'hFF);
    dut.im.mem[4] = I_BCC(C_NE, 8'd2);
    dut.im.mem[5] = I_HALT;
    #22 rst_n = 1;
    while (!halted) @(negedge clk);
    // 2 LDI + 4 x (ADD, ADDI, BNE) + HALT = 15 instructies
    if (aantal !== 15) begin fouten = fouten + 1; $display("FAIL: %0d instructies i.p.v. 15", aantal); end
    if (eerste[0] !== I_LDI(1, 0) || eerste[2] !== I_ALU(F_ADD, 1, 1, 2)) begin fouten = fouten + 1; $display("FAIL: volgorde"); end
    if (r1 !== 8'd10) begin fouten = fouten + 1; $display("FAIL: R1 = %0d", r1); end
    if (fouten == 0) $display("PASS: trace toont %0d instructies, som 4+3+2+1 = %0d", aantal, r1);
    $finish;
  end
endmodule
