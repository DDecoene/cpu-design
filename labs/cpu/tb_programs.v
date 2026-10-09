`include "asm_funcs.vh"
module tb_programs;
  reg clk = 0, rst_n = 0;
  wire halted, fz, fn, fc, fv;
  wire [7:0] pc, r0, r1, r2, r3, r4, r5, r6, r7;
  integer fouten = 0, cycli, k;

  cpu #("prog.hex", 0) dut(clk, rst_n, halted, pc, r0, r1, r2, r3, r4, r5, r6, r7, fz, fn, fc, fv);
  always #5 clk = ~clk;

  // Zet een programma klaar, reset de CPU en draai tot HALT (of tot een limiet).
  task run;
    begin
      rst_n = 0; repeat (2) @(negedge clk);
      rst_n = 1; cycli = 0;
      while (!halted && cycli < 20000) begin @(negedge clk); cycli = cycli + 1; end
      if (!halted) begin fouten = fouten + 1; $display("FAIL: CPU stopte niet"); end
    end
  endtask

  task clear_all;
    begin
      for (k = 0; k < 256; k = k + 1) begin dut.im.mem[k] = I_NOP; dut.dm.mem[k] = 8'h00; end
    end
  endtask

  task expect8(input [7:0] actual, input [7:0] verwacht, input [255:0] naam);
    if (actual !== verwacht) begin
      fouten = fouten + 1; $display("FAIL %0s: %0d i.p.v. %0d", naam, actual, verwacht);
    end
  endtask

  initial begin
    // ---- Programma 1: som van 1 tot 10 ----
    clear_all;
    dut.im.mem[0] = I_LDI(1, 0);                 // R1 = 0 (som)
    dut.im.mem[1] = I_LDI(2, 10);                // R2 = 10 (teller)
    dut.im.mem[2] = I_ALU(F_ADD, 1, 1, 2);       // lus: R1 = R1 + R2
    dut.im.mem[3] = I_ADDI(2, 8'hFF);            // R2 = R2 - 1  (zet Z als R2 nul wordt)
    dut.im.mem[4] = I_BCC(C_NE, 8'd2);           // terug naar de lus zolang R2 != 0
    dut.im.mem[5] = I_HALT;
    run;
    expect8(r1, 8'd55, "som 1..10");
    expect8(r2, 8'd0,  "teller na lus");
    // Tel: 2 LDI + 10 * (ADD, ADDI, BNE) + HALT = 33 instructies, 2 cycli elk = 66 cycli.
    if (cycli !== 66) begin fouten = fouten + 1; $display("FAIL: cycli = %0d", cycli); end

    // ---- Programma 2: Fibonacci in het geheugen ----
    clear_all;
    dut.im.mem[0]  = I_LDI(0, 0);                // R0 = a = 0
    dut.im.mem[1]  = I_LDI(1, 1);                // R1 = b = 1
    dut.im.mem[2]  = I_LDI(2, 0);                // R2 = wijzer
    dut.im.mem[3]  = I_LDI(3, 12);               // R3 = aantal
    dut.im.mem[4]  = I_ST(0, 2, 0);              // lus: mem[R2] = a
    dut.im.mem[5]  = I_ALU(F_ADD, 4, 0, 1);      // R4 = a + b
    dut.im.mem[6]  = I_ALU(F_OR,  0, 1, 1);      // a = b   (MOV)
    dut.im.mem[7]  = I_ALU(F_OR,  1, 4, 4);      // b = R4  (MOV)
    dut.im.mem[8]  = I_ADDI(2, 8'd1);            // wijzer++
    dut.im.mem[9]  = I_ADDI(3, 8'hFF);           // aantal--
    dut.im.mem[10] = I_BCC(C_NE, 8'd4);
    dut.im.mem[11] = I_HALT;
    run;
    begin : fibcheck
      reg [7:0] f [0:11];
      f[0]=0; f[1]=1; f[2]=1; f[3]=2; f[4]=3; f[5]=5; f[6]=8; f[7]=13; f[8]=21; f[9]=34; f[10]=55; f[11]=89;
      for (k = 0; k < 12; k = k + 1)
        if (dut.dm.mem[k] !== f[k]) begin fouten = fouten + 1; $display("FAIL fib[%0d] = %0d", k, dut.dm.mem[k]); end
    end

    // ---- Programma 3: subroutine met CALL en JR ----
    clear_all;
    dut.im.mem[0] = I_LDI(1, 7);                 // R1 = 7
    dut.im.mem[1] = I_CALL(8'd10);               // roep 'verdubbel' aan
    dut.im.mem[2] = I_CALL(8'd10);               // en nog een keer: R1 = 28
    dut.im.mem[3] = I_HALT;
    dut.im.mem[10] = I_ALU(F_ADD, 1, 1, 1);      // verdubbel: R1 = R1 + R1
    dut.im.mem[11] = I_JR(7);                    // terug (R7 bevat het terugkeeradres)
    run;
    expect8(r1, 8'd28, "verdubbel twee keer");
    expect8(r7, 8'd3,  "R7 = terugkeeradres van tweede CALL");

    // ---- Programma 4: voorwaarden: signed en unsigned vergelijken ----
    clear_all;
    dut.im.mem[0]  = I_LDI(1, 8'hFD);            // R1 = -3 (met teken), 253 (zonder)
    dut.im.mem[1]  = I_LDI(2, 5);                // R2 = 5
    dut.im.mem[2]  = I_CMP(1, 2);                // R1 - R2
    dut.im.mem[3]  = I_BCC(C_LT, 8'd6);          // met teken: -3 < 5, dus springen
    dut.im.mem[4]  = I_LDI(3, 1);                // overgeslagen
    dut.im.mem[5]  = I_HALT;                     // overgeslagen
    dut.im.mem[6]  = I_LDI(3, 2);                // R3 = 2 (signed vergelijking klopte)
    dut.im.mem[7]  = I_BCC(C_CS, 8'd10);         // zonder teken: 253 >= 5, dus springen
    dut.im.mem[8]  = I_LDI(4, 1);                // overgeslagen
    dut.im.mem[9]  = I_HALT;                     // overgeslagen
    dut.im.mem[10] = I_LDI(4, 2);                // R4 = 2 (unsigned vergelijking klopte)
    dut.im.mem[11] = I_CMPI(2, 5);               // R2 - 5 = 0
    dut.im.mem[12] = I_BCC(C_EQ, 8'd14);
    dut.im.mem[13] = I_HALT;
    dut.im.mem[14] = I_LDI(5, 3);                // R5 = 3
    dut.im.mem[15] = I_HALT;
    run;
    expect8(r3, 8'd2, "signed LT"); expect8(r4, 8'd2, "unsigned CS"); expect8(r5, 8'd3, "EQ na CMPI");

    // ---- Programma 5: lees/schrijf met offset en ALU-bewerkingen ----
    clear_all;
    dut.im.mem[0] = I_LDI(1, 100);               // basisadres
    dut.im.mem[1] = I_LDI(2, 8'h5A);
    dut.im.mem[2] = I_ST(2, 1, 6'd3);            // mem[103] = 0x5A
    dut.im.mem[3] = I_LD(3, 1, 6'd3);            // R3 = mem[103]
    dut.im.mem[4] = I_ALU(F_NOT, 4, 3, 0);       // R4 = ~R3 = 0xA5
    dut.im.mem[5] = I_ALU(F_SHL, 5, 3, 0);       // R5 = 0xB4
    dut.im.mem[6] = I_ALU(F_SHR, 6, 3, 0);       // R6 = 0x2D
    dut.im.mem[7] = I_ALU(F_XOR, 0, 3, 4);       // R0 = 0x5A ^ 0xA5 = 0xFF
    dut.im.mem[8] = I_HALT;
    run;
    expect8(dut.dm.mem[103], 8'h5A, "mem[103]"); expect8(r3, 8'h5A, "LD");
    expect8(r4, 8'hA5, "NOT"); expect8(r5, 8'hB4, "SHL"); expect8(r6, 8'h2D, "SHR"); expect8(r0, 8'hFF, "XOR");

    if (fouten == 0) $display("PASS: CPU draait som, Fibonacci, subroutines, voorwaarden en geheugen correct");
    $finish;
  end
endmodule
