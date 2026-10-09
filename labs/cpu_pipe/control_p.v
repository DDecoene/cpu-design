// Besturing voor de gepijplijnde W8: geen stappen meer. In elke cyclus wordt tegelijk
// de volgende instructie opgehaald (pc_inc, ir_we) en de huidige uitgevoerd.
module control_p(
  input        clk,
  input        rst_n,
  input  [3:0] op,
  input  [2:0] cond,
  input        flag_z, flag_n, flag_c, flag_v,
  output       pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7,
  output       ra_sel, rb_sel, alu_ir, flags_we, mem_we,
  output [1:0] wb_sel, b_sel,
  output [2:0] alu_op,
  output       halted
);
  localparam OP_ALU = 4'h0, OP_LDI = 4'h1, OP_ADDI = 4'h2, OP_LD = 4'h3, OP_ST = 4'h4,
             OP_BCC = 4'h5, OP_CMP = 4'h6, OP_CMPI = 4'h7, OP_CALL = 4'h8, OP_JR = 4'h9,
             OP_HALT = 4'hF;

  localparam [19:0]
    F_PC_INC = 20'h00001, F_PC_LOAD = 20'h00002, F_PC_REG = 20'h00004, F_IR_WE = 20'h00008,
    F_REG_WE = 20'h00010, F_WA_R7 = 20'h00020, F_RA_RD = 20'h00040, F_RB_RD = 20'h00080,
    F_ALU_IR = 20'h00100, F_FLAGS = 20'h00200, F_MEM_WE = 20'h00400, F_COND = 20'h00800,
    F_WB_MEM = 20'h01000, F_WB_IMM = 20'h02000, F_WB_PC = 20'h03000,
    F_B_IMM = 20'h04000, F_B_OFF = 20'h08000, F_ALU_SUB = 20'h10000, F_HALT = 20'h80000;

  reg halt_r;
  reg [19:0] cw;

  always_comb begin
    cw = 20'h0;
    if (!halt_r) begin
      cw = F_PC_INC | F_IR_WE;                                     // ophalen gebeurt in elke cyclus
      case (op)
        OP_ALU:  cw = cw | F_ALU_IR | F_REG_WE | F_FLAGS;
        OP_LDI:  cw = cw | F_REG_WE | F_WB_IMM;
        OP_ADDI: cw = cw | F_RA_RD | F_B_IMM | F_REG_WE | F_FLAGS;
        OP_LD:   cw = cw | F_B_OFF | F_REG_WE | F_WB_MEM;
        OP_ST:   cw = cw | F_B_OFF | F_RB_RD | F_MEM_WE;
        OP_BCC:  cw = cw | F_PC_LOAD | F_COND;
        OP_CMP:  cw = cw | F_ALU_SUB | F_FLAGS;
        OP_CMPI: cw = cw | F_RA_RD | F_B_IMM | F_ALU_SUB | F_FLAGS;
        OP_CALL: cw = cw | F_PC_LOAD | F_REG_WE | F_WA_R7 | F_WB_PC;
        OP_JR:   cw = cw | F_PC_LOAD | F_PC_REG;
        OP_HALT: cw = cw | F_HALT;
        default: ;
      endcase
    end
  end

  reg cond_ok;
  always_comb begin
    case (cond)
      3'd0: cond_ok = 1'b1;
      3'd1: cond_ok = flag_z;
      3'd2: cond_ok = ~flag_z;
      3'd3: cond_ok = flag_c;
      3'd4: cond_ok = ~flag_c;
      3'd5: cond_ok = flag_n ^ flag_v;
      3'd6: cond_ok = ~(flag_n ^ flag_v);
      default: cond_ok = flag_n;
    endcase
  end

  always @(posedge clk or negedge rst_n)
    if (!rst_n) halt_r <= 1'b0;
    else if (cw[19]) halt_r <= 1'b1;

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
  assign halted   = halt_r;
endmodule
