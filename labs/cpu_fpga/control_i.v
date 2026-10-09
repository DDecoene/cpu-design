// De besturingseenheid: een controlegeheugen (control store) dat voor elke combinatie
// van (opcode, stap) een controlewoord oplevert. Stap 0 = ophalen, stap 1 = uitvoeren.
module control_i(
  input        clk,
  input        rst_n,
  input  [3:0] op,
  input  [2:0] cond,
  input        flag_z, flag_n, flag_c, flag_v,
  input        irq,         // een apparaat vraagt om aandacht
  input        ie,          // interrupts zijn toegestaan
  output       pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7,
  output       ra_sel, rb_sel, alu_ir, flags_we, mem_we,
  output [1:0] wb_sel, b_sel,
  output [2:0] alu_op,
  output       mem_rd,      // leesactie (voor apparaten waarvan lezen iets doet)
  output       int_enter, reti, ei, di,
  output       halted
);
  // Opcodes
  localparam OP_ALU = 4'h0, OP_LDI = 4'h1, OP_ADDI = 4'h2, OP_LD = 4'h3, OP_ST = 4'h4,
             OP_BCC = 4'h5, OP_CMP = 4'h6, OP_CMPI = 4'h7, OP_CALL = 4'h8, OP_JR = 4'h9,
             OP_RETI = 4'hB, OP_EI = 4'hC, OP_DI = 4'hD, OP_HALT = 4'hF;

  // Bitposities in het controlewoord
  localparam [23:0]
    F_PC_INC   = 24'h000001,
    F_PC_LOAD  = 24'h000002,
    F_PC_REG   = 24'h000004,
    F_IR_WE    = 24'h000008,
    F_REG_WE   = 24'h000010,
    F_WA_R7    = 24'h000020,
    F_RA_RD    = 24'h000040,
    F_RB_RD    = 24'h000080,
    F_ALU_IR   = 24'h000100,
    F_FLAGS    = 24'h000200,
    F_MEM_WE   = 24'h000400,
    F_COND     = 24'h000800,          // laad de PC alleen als de voorwaarde klopt
    F_WB_MEM   = 24'h001000,          // wb_sel = 1
    F_WB_IMM   = 24'h002000,          // wb_sel = 2
    F_WB_PC    = 24'h003000,          // wb_sel = 3
    F_B_IMM    = 24'h004000,          // b_sel = 1
    F_B_OFF    = 24'h008000,          // b_sel = 2
    F_ALU_SUB  = 24'h010000,          // alu_op = 1
    F_HALT     = 24'h080000,
    F_RETI     = 24'h100000,
    F_EI       = 24'h200000,
    F_DI       = 24'h400000,
    F_INT      = 24'h800000;

  reg t;                             // 0 = ophalen, 1 = uitvoeren
  reg halt_r;
  reg [23:0] cw;

  // Het controlegeheugen zelf: opcode en stap in, controlewoord uit.
  always_comb begin
    cw = 24'h0;
    if (!halt_r) begin
      if (t == 1'b0) cw = (irq && ie) ? F_INT : (F_PC_INC | F_IR_WE);   // ophalen, of een interrupt nemen
      else case (op)
        OP_ALU:  cw = F_ALU_IR | F_REG_WE | F_FLAGS;             // rd = rs1 <fn> rs2
        OP_LDI:  cw = F_REG_WE | F_WB_IMM;                       // rd = imm8
        OP_ADDI: cw = F_RA_RD | F_B_IMM | F_REG_WE | F_FLAGS;    // rd = rd + imm8
        OP_LD:   cw = F_B_OFF | F_REG_WE | F_WB_MEM;             // rd = mem[rs1 + off6]
        OP_ST:   cw = F_B_OFF | F_RB_RD | F_MEM_WE;              // mem[rs1 + off6] = rd
        OP_BCC:  cw = F_PC_LOAD | F_COND;                        // if cond: PC = imm8
        OP_CMP:  cw = F_ALU_SUB | F_FLAGS;                       // vlaggen van rs1 - rs2
        OP_CMPI: cw = F_RA_RD | F_B_IMM | F_ALU_SUB | F_FLAGS;   // vlaggen van rd - imm8
        OP_CALL: cw = F_PC_LOAD | F_REG_WE | F_WA_R7 | F_WB_PC;  // R7 = PC; PC = imm8
        OP_JR:   cw = F_PC_LOAD | F_PC_REG;                      // PC = rs1
        OP_RETI: cw = F_RETI;                                    // PC = EPC, interrupts weer aan
        OP_EI:   cw = F_EI;
        OP_DI:   cw = F_DI;
        OP_HALT: cw = F_HALT;
        default: cw = 24'h0;                                     // NOP en ongebruikte opcodes
      endcase
    end
  end

  // Voorwaarde-evaluatie
  reg cond_ok;
  always_comb begin
    case (cond)
      3'd0: cond_ok = 1'b1;              // AL  altijd
      3'd1: cond_ok = flag_z;                // EQ
      3'd2: cond_ok = ~flag_z;               // NE
      3'd3: cond_ok = flag_c;                // CS  (A >= B zonder teken na CMP)
      3'd4: cond_ok = ~flag_c;               // CC  (A <  B zonder teken)
      3'd5: cond_ok = flag_n ^ flag_v;           // LT  (met teken)
      3'd6: cond_ok = ~(flag_n ^ flag_v);        // GE  (met teken)
      default: cond_ok = flag_n;             // MI  negatief
    endcase
  end

  // Stap en halt-vlag
  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin t <= 1'b0; halt_r <= 1'b0; end
    else if (!halt_r) begin
      t <= ~t;
      if (cw[19]) halt_r <= 1'b1;
    end

  assign pc_inc   = cw[0];
  assign pc_load  = cw[1] & (~cw[11] | cond_ok);
  assign pc_src   = cw[2];
  assign ir_we    = cw[3];
  assign reg_we   = cw[4];
  assign wa_r7    = cw[5];
  assign ra_sel   = cw[6];
  assign rb_sel   = cw[7];
  assign alu_ir   = cw[8];
  assign flags_we = cw[9];
  assign mem_we   = cw[10];
  assign wb_sel   = cw[13:12];
  assign b_sel    = cw[15:14];
  assign alu_op   = cw[18:16];
  assign int_enter = cw[23];
  assign reti      = cw[20];
  assign ei        = cw[21];
  assign di        = cw[22];
  assign mem_rd    = (t == 1'b1) && !halt_r && (op == OP_LD);
  assign halted    = halt_r;
endmodule
