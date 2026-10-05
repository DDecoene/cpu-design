// FILE: stack/tb_s8_basic.v
// Test van de stackmachine met met de hand samengestelde bytes.
module tb_s8_basic;
  reg clk = 0, rst_n = 0;
  wire halted; wire [7:0] pc, tos; wire [3:0] dsp;
  integer fouten = 0, k, cycli;
  s8 #("none", 0) dut(clk, rst_n, halted, pc, tos, dsp);
  always #5 clk = ~clk;

  task run;
    begin
      rst_n = 0; repeat (2) @(negedge clk); rst_n = 1; cycli = 0;
      while (!halted && cycli < 10000) begin @(negedge clk); cycli = cycli + 1; end
      if (!halted) begin fouten = fouten + 1; $display("FAIL: stopte niet"); end
    end
  endtask
  task clear; begin for (k = 0; k < 256; k = k + 1) begin dut.code[k] = 8'h3F; dut.data[k] = 0; end end endtask
  task check(input [7:0] got, input [7:0] want, input [3:0] sp_want, input [255:0] naam);
    if (got !== want || dsp !== sp_want) begin fouten = fouten + 1; $display("FAIL %0s: tos=%0d (verwacht %0d), diepte=%0d (verwacht %0d)", naam, got, want, dsp, sp_want); end
  endtask

  initial begin
    // 3 4 + 5 -   =>  2
    clear;
    dut.code[0] = 8'h83; dut.code[1] = 8'h84; dut.code[2] = 8'h05; dut.code[3] = 8'h85; dut.code[4] = 8'h06; dut.code[5] = 8'h3F;
    run; check(tos, 2, 1, "3 4 + 5 -");

    // 10 DUP *-achtig: 6 DUP +  => 12 ; SWAP/OVER: 1 2 SWAP OVER => 2 1 2 (tos 2, diepte 3)
    clear;
    dut.code[0] = 8'h86; dut.code[1] = 8'h01; dut.code[2] = 8'h05; dut.code[3] = 8'h3F;
    run; check(tos, 12, 1, "6 DUP +");
    clear;
    dut.code[0] = 8'h81; dut.code[1] = 8'h82; dut.code[2] = 8'h03; dut.code[3] = 8'h04; dut.code[4] = 8'h3F;
    run; check(tos, 2, 3, "1 2 SWAP OVER");
    if (dut.ds[0] !== 8'd2 || dut.ds[1] !== 8'd1) begin fouten = fouten + 1; $display("FAIL: SWAP"); end

    // ROT: 1 2 3 ROT => 2 3 1
    clear;
    dut.code[0] = 8'h81; dut.code[1] = 8'h82; dut.code[2] = 8'h83; dut.code[3] = 8'h19; dut.code[4] = 8'h3F;
    run;
    if (dut.ds[0] !== 2 || dut.ds[1] !== 3 || dut.ds[2] !== 1 || dsp !== 3) begin fouten = fouten + 1; $display("FAIL: ROT %0d %0d %0d", dut.ds[0], dut.ds[1], dut.ds[2]); end

    // LIT8, logica, schuiven: 200 (LIT8) 7 AND => 0 ; 200 2/ => 100 ; 5 INV => 250
    clear;
    dut.code[0] = 8'h12; dut.code[1] = 8'd200; dut.code[2] = 8'h87; dut.code[3] = 8'h07; dut.code[4] = 8'h3F;
    run; check(tos, 8'd0, 1, "200 7 AND");
    clear;
    dut.code[0] = 8'h12; dut.code[1] = 8'd200; dut.code[2] = 8'h0C; dut.code[3] = 8'h3F;
    run; check(tos, 8'd100, 1, "200 2/");
    clear;
    dut.code[0] = 8'h85; dut.code[1] = 8'h0A; dut.code[2] = 8'h3F;
    run; check(tos, 8'd250, 1, "5 INV");

    // Geheugen: 42 20 ! 20 @ => 42
    clear;
    dut.code[0] = 8'hAA; dut.code[1] = 8'h94; dut.code[2] = 8'h0E; dut.code[3] = 8'h94; dut.code[4] = 8'h0D; dut.code[5] = 8'h3F;
    run; check(tos, 8'd42, 1, "! en @");
    if (dut.data[20] !== 8'd42) begin fouten = fouten + 1; $display("FAIL: data[20]"); end

    // Terugkeerstapel: 7 >R 9 R> => 9 7
    clear;
    dut.code[0] = 8'h87; dut.code[1] = 8'h0F; dut.code[2] = 8'h89; dut.code[3] = 8'h10; dut.code[4] = 8'h3F;
    run;
    if (dut.ds[0] !== 9 || dut.ds[1] !== 7 || dsp !== 2) begin fouten = fouten + 1; $display("FAIL: >R R>"); end

    // Vergelijkingen: 3 3 = (255), 3 4 = (0), 3 4 < (255), 4 3 < (0)
    clear;
    dut.code[0] = 8'h83; dut.code[1] = 8'h83; dut.code[2] = 8'h17; dut.code[3] = 8'h83; dut.code[4] = 8'h84; dut.code[5] = 8'h17;
    dut.code[6] = 8'h83; dut.code[7] = 8'h84; dut.code[8] = 8'h18; dut.code[9] = 8'h84; dut.code[10] = 8'h83; dut.code[11] = 8'h18; dut.code[12] = 8'h3F;
    run;
    if (dut.ds[0] !== 8'hFF || dut.ds[1] !== 8'h00 || dut.ds[2] !== 8'hFF || dut.ds[3] !== 8'h00) begin fouten = fouten + 1; $display("FAIL: vergelijkingen"); end

    // CALL / EXIT: 5 CALL 10 ... ; routine op 10: DUP + EXIT   (5 -> 10), daarna HALT
    clear;
    dut.code[0] = 8'h85; dut.code[1] = 8'h15; dut.code[2] = 8'd10; dut.code[3] = 8'h3F;
    dut.code[10] = 8'h01; dut.code[11] = 8'h05; dut.code[12] = 8'h16;
    run; check(tos, 8'd10, 1, "CALL/EXIT");

    // JZ en JMP: 0 JZ 6 (springt) 99 ... 6: 7 HALT  => tos 7, diepte 1
    clear;
    dut.code[0] = 8'h80; dut.code[1] = 8'h14; dut.code[2] = 8'd6; dut.code[3] = 8'hE3; dut.code[4] = 8'h3F;
    dut.code[6] = 8'h87; dut.code[7] = 8'h3F;
    run; check(tos, 8'd7, 1, "JZ springt");
    clear;
    dut.code[0] = 8'h81; dut.code[1] = 8'h14; dut.code[2] = 8'd6; dut.code[3] = 8'h88; dut.code[4] = 8'h13; dut.code[5] = 8'd8;
    dut.code[6] = 8'h87; dut.code[7] = 8'h3F; dut.code[8] = 8'h3F;
    run; check(tos, 8'd8, 1, "JZ springt niet, JMP naar HALT");

    if (fouten == 0) $display("PASS: stackmachine S8 voert alle opcodes correct uit");
    $finish;
  end
endmodule
