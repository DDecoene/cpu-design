// S8: een stackmachine in de geest van Forth.
// Twee stapels (data en terugkeer) van 16 bytes, programmageheugen en datageheugen van 256 bytes.
// Bit 7 = 1: literal (waarde 0..127). Anders is het een opcode van 6 bit.
module s8 #(parameter PROG = "prog.hex", parameter LOAD = 1) (
  input        clk,
  input        rst_n,
  output reg   halted,
  output [7:0] pc_out,
  output [7:0] tos,        // bovenste element van de datastapel (voor debuggen)
  output [3:0] dsp         // aantal elementen op de datastapel
);
  // Opcodes
  localparam NOP = 6'h00, DUP = 6'h01, DROP = 6'h02, SWAP = 6'h03, OVER = 6'h04,
             ADD = 6'h05, SUB = 6'h06, AND_ = 6'h07, OR_ = 6'h08, XOR_ = 6'h09,
             INV = 6'h0A, SHL = 6'h0B, SHR = 6'h0C, LOAD_ = 6'h0D, STORE = 6'h0E,
             TOR = 6'h0F, FROMR = 6'h10, RFETCH = 6'h11, LIT8 = 6'h12, JMP = 6'h13,
             JZ = 6'h14, CALL = 6'h15, EXIT = 6'h16, EQ = 6'h17, LT = 6'h18, ROT = 6'h19,
             HALT = 6'h3F;

  reg [7:0] code [0:255];
  reg [7:0] data [0:255];
  reg [7:0] ds [0:15];       // datastapel
  reg [7:0] rs [0:15];       // terugkeerstapel
  reg [3:0] sp, rsp;         // wijzen naar de eerstvolgende vrije plaats
  reg [7:0] pc;
  reg [5:0] pend;            // opcode die nog een operandbyte nodig heeft
  reg       need_operand;
  integer i;

  wire [3:0] t1 = sp - 4'd1;      // index van het bovenste element
  wire [3:0] t2 = sp - 4'd2;
  wire [3:0] t3 = sp - 4'd3;
  wire [7:0] T = ds[t1];
  wire [7:0] N = ds[t2];
  wire [7:0] R3 = ds[t3];
  wire [7:0] instr = code[pc];

  assign pc_out = pc;
  assign tos = T;
  assign dsp = sp;

  initial begin
    for (i = 0; i < 256; i = i + 1) begin code[i] = 8'h3F; data[i] = 8'h00; end
    if (LOAD) $readmemh(PROG, code);
  end

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      pc <= 0; sp <= 0; rsp <= 0; halted <= 0; need_operand <= 0; pend <= 0;
    end else if (!halted) begin
      if (need_operand) begin
        // Tweede cyclus van een instructie met een operandbyte (code[pc] is die byte).
        need_operand <= 0;
        case (pend)
          LIT8: begin ds[sp] <= instr; sp <= sp + 4'd1; pc <= pc + 8'd1; end
          JMP:  pc <= instr;
          JZ:   begin
                  sp <= sp - 4'd1;
                  pc <= (T == 8'h00) ? instr : pc + 8'd1;
                end
          CALL: begin rs[rsp] <= pc + 8'd1; rsp <= rsp + 4'd1; pc <= instr; end
          default: pc <= pc + 8'd1;
        endcase
      end else if (instr[7]) begin
        // literal 0..127
        ds[sp] <= {1'b0, instr[6:0]}; sp <= sp + 4'd1; pc <= pc + 8'd1;
      end else begin
        pc <= pc + 8'd1;
        case (instr[5:0])
          NOP:    ;
          DUP:    begin ds[sp] <= T; sp <= sp + 4'd1; end
          DROP:   sp <= sp - 4'd1;
          SWAP:   begin ds[t1] <= N; ds[t2] <= T; end
          OVER:   begin ds[sp] <= N; sp <= sp + 4'd1; end
          ROT:    begin ds[t3] <= N; ds[t2] <= T; ds[t1] <= R3; end
          ADD:    begin ds[t2] <= N + T;  sp <= sp - 4'd1; end
          SUB:    begin ds[t2] <= N - T;  sp <= sp - 4'd1; end
          AND_:   begin ds[t2] <= N & T;  sp <= sp - 4'd1; end
          OR_:    begin ds[t2] <= N | T;  sp <= sp - 4'd1; end
          XOR_:   begin ds[t2] <= N ^ T;  sp <= sp - 4'd1; end
          EQ:     begin ds[t2] <= (N == T) ? 8'hFF : 8'h00; sp <= sp - 4'd1; end
          LT:     begin ds[t2] <= (N <  T) ? 8'hFF : 8'h00; sp <= sp - 4'd1; end
          INV:    ds[t1] <= ~T;
          SHL:    ds[t1] <= {T[6:0], 1'b0};
          SHR:    ds[t1] <= {1'b0, T[7:1]};
          LOAD_:  ds[t1] <= data[T];
          STORE:  begin data[T] <= N; sp <= sp - 4'd2; end
          TOR:    begin rs[rsp] <= T; rsp <= rsp + 4'd1; sp <= sp - 4'd1; end
          FROMR:  begin ds[sp] <= rs[rsp - 4'd1]; rsp <= rsp - 4'd1; sp <= sp + 4'd1; end
          RFETCH: begin ds[sp] <= rs[rsp - 4'd1]; sp <= sp + 4'd1; end
          EXIT:   begin pc <= rs[rsp - 4'd1]; rsp <= rsp - 4'd1; end
          LIT8, JMP, JZ, CALL: begin pend <= instr[5:0]; need_operand <= 1; end
          HALT:   begin halted <= 1; pc <= pc; end
          default: ;
        endcase
      end
    end
endmodule
