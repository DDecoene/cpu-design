// fase8/prototype/tta_mm.v (prototype, nog niet in src/)
// De T8 van week 19 met één wijziging: MAR in F0-FF gaat naar de apparaten (io_*) in plaats van naar het RAM.
// Gemaakt met sed uit labs/tta/tta.v; zie fase8/AGENTS.md.
// T8: een transport-triggered architecture. De enige instructie is MOVE: bron -> bestemming.
// Een instructie van 24 bit:  [23:21] guard | [20:16] bestemming | [15:8] bron | [7:0] constante
// Rekenen gebeurt als bijwerking van schrijven naar een "trigger"-bestemming.
module tta_mm #(parameter PROG = "tta.hex", parameter LOAD = 1,
             parameter DATA = "tta.dat", parameter DLOAD = 0) (
  input        clk,
  input        rst_n,
  input  [7:0] in_port,
  output reg [7:0] out_port,
  output reg   out_valid,        // één klokperiode hoog bij elke schrijfactie naar OUT
  output reg   halted,
  output       io_we,
  output [7:0] io_addr, io_wdata,
  input  [7:0] io_rdata,
  output [7:0] pc_out,
  output [7:0] r0, r1, r2, r3,
  output [7:0] res_out,
  output       flag_z, flag_n, flag_c
);
  // Bestemmingen
  localparam D_NOP = 0, D_R0 = 1, D_R1 = 2, D_R2 = 3, D_R3 = 4, D_OP = 5,
             D_ADD = 6, D_SUB = 7, D_AND = 8, D_OR = 9, D_XOR = 10, D_PC = 11,
             D_MAR = 12, D_MEM = 13, D_OUT = 14, D_SHL = 15, D_ADC = 16, D_HALT = 31;
  // Bronnen
  localparam S_IMM = 0, S_R0 = 1, S_R1 = 2, S_R2 = 3, S_R3 = 4, S_RES = 5, S_RESHR = 6,
             S_RESNOT = 7, S_MEM = 8, S_IN = 9, S_PC2 = 10, S_FLAGS = 11;

  reg [23:0] rom [0:255];
  reg [7:0]  ram [0:255];
  reg [7:0]  pc, op, res, mar;
  reg [7:0]  r [0:3];
  reg        zf, nf, cf;
  integer i;

  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      rom[i] = {3'b000, 5'd31, 16'h0000};     // lege plaatsen zijn een HALT (bestemming 31)
      ram[i] = 8'h00;
    end
    if (LOAD)  $readmemh(PROG, rom);
    if (DLOAD) $readmemh(DATA, ram);
  end

  wire [23:0] instr = rom[pc];
  wire [2:0]  guard = instr[23:21];
  wire [4:0]  dst   = instr[20:16];
  wire [4:0]  src   = instr[12:8];
  wire [7:0]  imm   = instr[7:0];

  wire io_sel = (mar[7:4] == 4'hF);          // F0-FF: apparaten
  wire [7:0] res_shr = {1'b0, res[7:1]};     // afgeleide bron: het resultaat, een plaats naar rechts

  // De bus: het bronveld kiest wie de waarde levert.
  reg [7:0] bus;
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
      S_MEM:    bus = io_sel ? io_rdata : ram[mar];
      S_IN:     bus = in_port;
      S_PC2:    bus = pc + 8'd2;
      S_FLAGS:  bus = {5'b00000, nf, cf, zf};
      default:  bus = 8'h00;
    endcase
  end

  reg go;                       // mag deze move doorgaan? (guard)
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

  // Rekenwerk voor de trigger-bestemmingen
  reg [8:0] sum;
  always_comb begin
    sum = 9'd0;
    case (dst)
      D_ADD: sum = {1'b0, op} + {1'b0, bus};
      D_SUB: sum = {1'b0, op} + {1'b0, ~bus} + 9'd1;     // C = 1 betekent: geen lening
      D_ADC: sum = {1'b0, op} + {1'b0, bus} + {8'b0, cf};
      D_SHL: sum = {bus, 1'b0};
      default: sum = 9'd0;
    endcase
  end

  reg [7:0] lg;                  // uitkomst van de logische bewerkingen
  always_comb begin
    case (dst)
      D_AND:   lg = op & bus;
      D_OR:    lg = op | bus;
      D_XOR:   lg = op ^ bus;
      default: lg = 8'h00;
    endcase
  end

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      pc <= 0; op <= 0; res <= 0; mar <= 0; zf <= 0; nf <= 0; cf <= 0; halted <= 0;
      out_port <= 0; out_valid <= 0;
      for (i = 0; i < 4; i = i + 1) r[i] <= 8'h00;
    end else begin
      out_valid <= 1'b0;
      if (!halted) begin
        pc <= pc + 8'd1;
        if (go) begin
          case (dst)
            D_R0:  r[0] <= bus;
            D_R1:  r[1] <= bus;
            D_R2:  r[2] <= bus;
            D_R3:  r[3] <= bus;
            D_OP:  op <= bus;
            D_ADD, D_SUB, D_ADC, D_SHL: begin
              res <= sum[7:0]; cf <= sum[8]; zf <= (sum[7:0] == 8'h00); nf <= sum[7];
            end
            D_AND, D_OR, D_XOR: begin
              res <= lg; cf <= 1'b0; zf <= (lg == 8'h00); nf <= lg[7];
            end
            D_PC:  pc <= bus;
            D_MAR: mar <= bus;
            D_MEM: if (!io_sel) ram[mar] <= bus;
            D_OUT: begin out_port <= bus; out_valid <= 1'b1; end
            D_HALT: halted <= 1'b1;
            default: ;
          endcase
        end
      end
    end

  assign pc_out = pc;
  assign r0 = r[0]; assign r1 = r[1]; assign r2 = r[2]; assign r3 = r[3];
  assign res_out = res;
  assign flag_z = zf; assign flag_n = nf; assign flag_c = cf;
  assign io_addr = mar; assign io_wdata = bus;
  assign io_we = io_sel && go && dst == D_MEM && !halted;
endmodule
