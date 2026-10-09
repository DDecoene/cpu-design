`include "asm_funcs.vh"
// We spelen zelf "besturingseenheid": we zetten de besturingssignalen per klokcyclus.
module tb_datapath;
  reg clk = 0, rst_n = 0;
  reg pc_inc = 0, pc_load = 0, pc_src = 0, ir_we = 0, reg_we = 0, wa_r7 = 0;
  reg ra_sel = 0, rb_sel = 0, alu_ir = 0, flags_we = 0, mem_we = 0;
  reg [1:0] b_sel = 0, wb_sel = 0;
  reg [2:0] alu_op = 0;

  wire [7:0]  imem_addr, dmem_addr, dmem_wdata, dmem_rdata, pc;
  wire [15:0] imem_dout;
  wire [3:0]  op;
  wire [2:0]  cond;
  wire        fz, fn, fc, fv;
  wire [7:0]  r0, r1, r2, r3, r4, r5, r6, r7;
  integer fouten = 0, k;

  imem #("none", 0) im(imem_addr, imem_dout);
  dmem dm(clk, mem_we, dmem_addr, dmem_wdata, dmem_rdata);
  datapath dp(clk, rst_n, pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel,
              b_sel, alu_ir, alu_op, wb_sel, flags_we,
              imem_addr, imem_dout, dmem_addr, dmem_wdata, dmem_rdata,
              op, cond, fz, fn, fc, fv, pc, r0, r1, r2, r3, r4, r5, r6, r7);
  always #5 clk = ~clk;

  // Eén klokcyclus met de huidige besturingssignalen; daarna alles weer uit.
  task tick;
    begin
      @(posedge clk); #1;
      pc_inc = 0; pc_load = 0; pc_src = 0; ir_we = 0; reg_we = 0; wa_r7 = 0;
      ra_sel = 0; rb_sel = 0; alu_ir = 0; flags_we = 0; mem_we = 0;
      b_sel = 0; wb_sel = 0; alu_op = 0;
    end
  endtask

  task fetch;                      // stap 0: haal de instructie op
    begin @(negedge clk); pc_inc = 1; ir_we = 1; tick; end
  endtask

  task expect8(input [7:0] actual, input [7:0] verwacht, input [255:0] naam);
    if (actual !== verwacht) begin fouten = fouten + 1; $display("FAIL %0s: %0d i.p.v. %0d", naam, actual, verwacht); end
  endtask

  initial begin
    for (k = 0; k < 256; k = k + 1) begin im.mem[k] = I_NOP; dm.mem[k] = 0; end
    im.mem[0] = I_LDI(1, 5);
    im.mem[1] = I_LDI(2, 7);
    im.mem[2] = I_ALU(F_ADD, 3, 1, 2);
    im.mem[3] = I_ST(3, 0, 9);
    im.mem[4] = I_LD(4, 0, 9);
    im.mem[5] = I_CMP(3, 4);
    im.mem[6] = I_CALL(8'd20);
    im.mem[20] = I_JR(7);

    #12 rst_n = 1;

    // LDI R1,5: ophalen, dan uitvoeren (wb = imm8)
    fetch; @(negedge clk); reg_we = 1; wb_sel = 2; tick;
    expect8(r1, 5, "LDI R1");
    // LDI R2,7
    fetch; @(negedge clk); reg_we = 1; wb_sel = 2; tick;
    expect8(r2, 7, "LDI R2");
    // ADD R3,R1,R2: alu_op komt uit de instructie, vlaggen bijwerken
    fetch; @(negedge clk); alu_ir = 1; reg_we = 1; flags_we = 1; tick;
    expect8(r3, 12, "ADD R3");
    if ({fz, fn, fc, fv} !== 4'b0000) begin fouten = fouten + 1; $display("FAIL vlaggen na ADD: %b%b%b%b", fz, fn, fc, fv); end
    // ST R3,[R0+9]: adres = R0 + off6 (ALU optelt), data uit rd (poort B)
    fetch; @(negedge clk); b_sel = 2; rb_sel = 1; mem_we = 1; tick;
    expect8(dm.mem[9], 12, "ST naar mem[9]");
    // LD R4,[R0+9]
    fetch; @(negedge clk); b_sel = 2; reg_we = 1; wb_sel = 1; tick;
    expect8(r4, 12, "LD R4");
    // CMP R3,R4: aftrekken, alleen vlaggen
    fetch; @(negedge clk); alu_op = 1; flags_we = 1; tick;
    if ({fz, fn, fc, fv} !== 4'b1010) begin fouten = fouten + 1; $display("FAIL vlaggen na CMP: %b%b%b%b", fz, fn, fc, fv); end
    // CALL 20: R7 = PC (het adres van de volgende instructie), PC = 20
    fetch; @(negedge clk); pc_load = 1; reg_we = 1; wa_r7 = 1; wb_sel = 3; tick;
    expect8(r7, 7, "CALL zet R7");
    expect8(pc, 20, "CALL springt");
    // JR R7: PC = register A (rs1 = 7)
    fetch; @(negedge clk); pc_load = 1; pc_src = 1; tick;
    expect8(pc, 7, "JR R7 keert terug");

    if (fouten == 0) $display("PASS: datapath voert LDI, ADD, ST, LD, CMP, CALL en JR correct uit");
    $finish;
  end
endmodule
