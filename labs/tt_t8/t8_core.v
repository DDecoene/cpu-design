// FILE: tt_t8/t8_core.v
// De kern van de T8, met instelbare breedte van de programmateller (PCW) en van het geheugenadres (AW).
// Het programmageheugen zit er niet in: de instructie komt van buiten (rom_addr -> instr).
// Met PCW = 8 en AW = 8 is dit exact de machine uit week 19; kleinere waarden maken hem geschikt voor een kleine chip.
module t8_core #(parameter PCW = 8, parameter AW = 8) (
  input                clk,
  input                rst_n,
  input  [7:0]         in_port,
  output reg [7:0]     out_port,
  output reg           halted,
  output [PCW-1:0]     rom_addr,
  input  [23:0]        instr,
  output [7:0]         r0, r1, r2, r3, op_out, res_out,
  output               flag_z, flag_n, flag_c
);
  localparam D_NOP = 0, D_R0 = 1, D_R1 = 2, D_R2 = 3, D_R3 = 4, D_OP = 5, D_ADD = 6, D_SUB = 7,
             D_AND = 8, D_OR = 9, D_XOR = 10, D_PC = 11, D_MAR = 12, D_MEM = 13, D_OUT = 14, D_SHL = 15,
             D_ADC = 16, D_HALT = 31;
  localparam S_IMM = 0, S_R0 = 1, S_R1 = 2, S_R2 = 3, S_R3 = 4, S_RES = 5, S_RESHR = 6, S_RESNOT = 7,
             S_MEM = 8, S_IN = 9, S_PC2 = 10, S_FLAGS = 11;

  reg [PCW-1:0] pc;
  reg [7:0]     op, res;
  reg [AW-1:0]  mar;
  reg [7:0]     r [0:3];
  reg [7:0]     ram [0:(1<<AW)-1];
  reg           zf, nf, cf;
  integer i;

  assign rom_addr = pc;
  wire [2:0] guard = instr[23:21];
  wire [4:0] dst   = instr[20:16];
  wire [4:0] src   = instr[12:8];
  wire [7:0] imm   = instr[7:0];

  wire [7:0] res_shr = {1'b0, res[7:1]};
  wire [7:0] pc2     = {{(8-PCW){1'b0}}, pc} + 8'd2;
  reg  [7:0] bus;
  always_comb begin
    case (src)
      S_IMM:    bus = imm;
      S_R0:     bus = r[0];
      S_R1:     bus = r[1];
      S_R2:     bus = r[2];
      S_R3:     bus = r[3];
      S_RES:    bus = res;
      S_RESHR:  bus = res_shr;
      S_RESNOT: bus = ~res;
      S_MEM:    bus = ram[mar];
      S_IN:     bus = in_port;
      S_PC2:    bus = pc2;
      S_FLAGS:  bus = {5'b00000, nf, cf, zf};
      default:  bus = 8'h00;
    endcase
  end

  reg go;
  always_comb begin
    case (guard)
      3'd0: go = 1'b1;
      3'd1: go = zf;
      3'd2: go = ~zf;
      3'd3: go = cf;
      3'd4: go = ~cf;
      3'd5: go = nf;
      3'd6: go = ~nf;
      default: go = 1'b0;
    endcase
  end

  reg [8:0] sum;
  reg [7:0] lg;
  always_comb begin
    sum = 9'd0; lg = 8'h00;
    case (dst)
      D_ADD: sum = {1'b0, op} + {1'b0, bus};
      D_SUB: sum = {1'b0, op} + {1'b0, ~bus} + 9'd1;
      D_ADC: sum = {1'b0, op} + {1'b0, bus} + {8'b0, cf};
      D_SHL: sum = {bus, 1'b0};
      D_AND: lg = op & bus;
      D_OR:  lg = op | bus;
      D_XOR: lg = op ^ bus;
      default: ;
    endcase
  end

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      pc <= 0; op <= 0; res <= 0; mar <= 0; zf <= 0; nf <= 0; cf <= 0; halted <= 0; out_port <= 0;
      for (i = 0; i < 4; i = i + 1) r[i] <= 8'h00;
    end else if (!halted) begin
      pc <= pc + 1'b1;
      if (go) begin
        case (dst)
          D_R0: r[0] <= bus;
          D_R1: r[1] <= bus;
          D_R2: r[2] <= bus;
          D_R3: r[3] <= bus;
          D_OP: op <= bus;
          D_ADD, D_SUB, D_ADC, D_SHL: begin res <= sum[7:0]; cf <= sum[8]; zf <= (sum[7:0] == 8'h00); nf <= sum[7]; end
          D_AND, D_OR, D_XOR:         begin res <= lg; cf <= 1'b0; zf <= (lg == 8'h00); nf <= lg[7]; end
          D_PC:   pc <= bus[PCW-1:0];
          D_MAR:  mar <= bus[AW-1:0];
          D_MEM:  ram[mar] <= bus;
          D_OUT:  out_port <= bus;
          D_HALT: halted <= 1'b1;
          default: ;
        endcase
      end
    end

  assign r0 = r[0]; assign r1 = r[1]; assign r2 = r[2]; assign r3 = r[3];
  assign op_out = op; assign res_out = res;
  assign flag_z = zf; assign flag_n = nf; assign flag_c = cf;
endmodule
