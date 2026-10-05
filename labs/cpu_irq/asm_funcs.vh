// FILE: cpu/asm_funcs.vh
// Mini-assembler in Verilog-functies: bouw een instructiewoord uit zijn velden.
function [15:0] I_ALU(input [2:0] fn, input [2:0] rd, input [2:0] rs1, input [2:0] rs2);
  I_ALU = {4'h0, rd, rs1, rs2, fn};
endfunction
function [15:0] I_LDI(input [2:0] rd, input [7:0] imm);   I_LDI  = {4'h1, rd, 1'b0, imm}; endfunction
function [15:0] I_ADDI(input [2:0] rd, input [7:0] imm);  I_ADDI = {4'h2, rd, 1'b0, imm}; endfunction
function [15:0] I_LD(input [2:0] rd, input [2:0] rs, input [5:0] off);  I_LD = {4'h3, rd, rs, off}; endfunction
function [15:0] I_ST(input [2:0] rd, input [2:0] rs, input [5:0] off);  I_ST = {4'h4, rd, rs, off}; endfunction
function [15:0] I_BCC(input [2:0] cond, input [7:0] addr); I_BCC = {4'h5, cond, 1'b0, addr}; endfunction
function [15:0] I_CMP(input [2:0] rs1, input [2:0] rs2);  I_CMP = {4'h6, 3'b000, rs1, rs2, 3'b000}; endfunction
function [15:0] I_CMPI(input [2:0] rd, input [7:0] imm);  I_CMPI = {4'h7, rd, 1'b0, imm}; endfunction
function [15:0] I_CALL(input [7:0] addr);                 I_CALL = {4'h8, 4'b0000, addr}; endfunction
function [15:0] I_JR(input [2:0] rs);                     I_JR = {4'h9, 3'b000, rs, 6'b000000}; endfunction
localparam [15:0] I_NOP = 16'hA000, I_HALT = 16'hF000;
localparam [2:0] F_ADD = 0, F_SUB = 1, F_AND = 2, F_OR = 3, F_XOR = 4, F_NOT = 5, F_SHL = 6, F_SHR = 7;
localparam [2:0] C_AL = 0, C_EQ = 1, C_NE = 2, C_CS = 3, C_CC = 4, C_LT = 5, C_GE = 6, C_MI = 7;
