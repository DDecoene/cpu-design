// FILE: cpu/tb_isa.v
`include "asm_funcs.vh"
module tb_isa;
  reg  [15:0] ir;
  wire [3:0]  op;
  wire [2:0]  rd, rs1, rs2, fn, cond;
  wire [7:0]  imm8;
  wire [5:0]  off6;
  integer i, fouten = 0;

  idecode dec(ir, op, rd, rs1, rs2, fn, cond, imm8, off6);

  task check_word(input [15:0] gemaakt, input [15:0] met_de_hand, input [255:0] naam);
    if (gemaakt !== met_de_hand) begin
      fouten = fouten + 1;
      $display("FAIL %0s: functie geeft %h, handwerk %h", naam, gemaakt, met_de_hand);
    end
  endtask

  initial begin
    // Met de hand gecodeerde instructies (zie de tabel in de cursus).
    check_word(I_LDI(1, 5),            16'h1205, "LDI R1,5");
    check_word(I_LDI(2, 7),            16'h1407, "LDI R2,7");
    check_word(I_ALU(F_ADD, 3, 1, 2),  16'h0650, "ADD R3,R1,R2");
    check_word(I_ST(3, 0, 9),          16'h4609, "ST R3,[R0+9]");
    check_word(I_LD(4, 0, 9),          16'h3809, "LD R4,[R0+9]");
    check_word(I_CMP(3, 4),            16'h60E0, "CMP R3,R4");
    check_word(I_BCC(C_EQ, 0),         16'h5200, "BEQ 0");
    check_word(I_HALT,                 16'hF000, "HALT");
    check_word(I_NOP,                  16'hA000, "NOP");
    check_word(I_CALL(8'h2A),          16'h802A, "CALL 0x2A");
    check_word(I_JR(7),                16'h91C0, "JR R7");
    check_word(I_ADDI(5, 8'hFF),       16'h2AFF, "ADDI R5,-1");
    check_word(I_CMPI(2, 10),          16'h740A, "CMPI R2,10");

    // De decoder moet bij willekeurige woorden elk veld op de juiste plek vinden.
    for (i = 0; i < 5000; i = i + 1) begin
      ir = $random; #1;
      if (op   !== ((ir >> 12) & 4'hF))  begin fouten = fouten + 1; $display("FAIL op"); end
      if (rd   !== ((ir >> 9)  & 3'h7))  begin fouten = fouten + 1; $display("FAIL rd"); end
      if (rs1  !== ((ir >> 6)  & 3'h7))  begin fouten = fouten + 1; $display("FAIL rs1"); end
      if (rs2  !== ((ir >> 3)  & 3'h7))  begin fouten = fouten + 1; $display("FAIL rs2"); end
      if (fn   !== (ir & 3'h7))          begin fouten = fouten + 1; $display("FAIL fn"); end
      if (cond !== ((ir >> 9)  & 3'h7))  begin fouten = fouten + 1; $display("FAIL cond"); end
      if (imm8 !== (ir & 8'hFF))         begin fouten = fouten + 1; $display("FAIL imm8"); end
      if (off6 !== (ir & 6'h3F))         begin fouten = fouten + 1; $display("FAIL off6"); end
    end
    if (fouten == 0) $display("PASS: instructiecodering en decoder kloppen");
    $finish;
  end
endmodule
