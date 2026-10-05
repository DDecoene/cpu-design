// FILE: cpu/datapath.v
// Het datapath: PC, instructieregister, registerbestand, ALU, vlaggen.
// Alle besturingssignalen komen van buiten (de besturingseenheid).
module datapath(
  input        clk,
  input        rst_n,
  // besturingssignalen
  input        pc_inc,      // PC <= PC + 1
  input        pc_load,     // PC <= doel
  input        pc_src,      // doel: 0 = imm8 uit de instructie, 1 = register A
  input        ir_we,       // instructieregister laden
  input        reg_we,      // naar een register schrijven
  input        wa_r7,       // schrijf naar R7 in plaats van rd
  input        ra_sel,      // leespoort A: 0 = rs1, 1 = rd
  input        rb_sel,      // leespoort B: 0 = rs2, 1 = rd
  input  [1:0] b_sel,       // ALU-ingang B: 0 = register, 1 = imm8, 2 = off6
  input        alu_ir,      // ALU-bewerking uit de instructie (fn) i.p.v. alu_op
  input  [2:0] alu_op,
  input  [1:0] wb_sel,      // terugschrijven: 0 = ALU, 1 = geheugen, 2 = imm8, 3 = PC
  input        flags_we,
  // instructiegeheugen
  output [7:0]  imem_addr,
  input  [15:0] imem_dout,
  // datageheugen
  output [7:0]  dmem_addr,
  output [7:0]  dmem_wdata,
  input  [7:0]  dmem_rdata,
  // naar de besturingseenheid
  output [3:0]  op,
  output [2:0]  cond,
  output        flag_z,
  output        flag_n,
  output        flag_c,
  output        flag_v,
  // voor debuggen
  output [7:0]  pc_out,
  output [7:0]  r0, r1, r2, r3, r4, r5, r6, r7
);
  reg [7:0]  pc;
  reg [15:0] ir;
  reg        fz, fn_, fc, fv;
  reg [7:0]  r [0:7];

  wire [2:0] rd, rs1, rs2, fn;
  wire [7:0] imm8;
  wire [5:0] off6;
  idecode dec(ir, op, rd, rs1, rs2, fn, cond, imm8, off6);

  // leespoorten
  wire [7:0] rega = r[ra_sel ? rd : rs1];
  wire [7:0] regb = r[rb_sel ? rd : rs2];

  // ALU
  wire [7:0] alu_b = (b_sel == 2'd0) ? regb :
                     (b_sel == 2'd1) ? imm8 : {2'b00, off6};
  wire [7:0] y;
  wire       az, an, ac, av;
  alu #(8) u_alu(rega, alu_b, alu_ir ? fn : alu_op, y, az, an, ac, av);

  // terugschrijven
  wire [7:0] wdata = (wb_sel == 2'd0) ? y :
                     (wb_sel == 2'd1) ? dmem_rdata :
                     (wb_sel == 2'd2) ? imm8 : pc;
  wire [2:0] waddr = wa_r7 ? 3'd7 : rd;

  integer i;
  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      pc <= 8'h00; ir <= 16'hA000;
      fz <= 0; fn_ <= 0; fc <= 0; fv <= 0;
      for (i = 0; i < 8; i = i + 1) r[i] <= 8'h00;
    end else begin
      if (ir_we) ir <= imem_dout;
      if (pc_load)     pc <= pc_src ? rega : imm8;
      else if (pc_inc) pc <= pc + 8'd1;
      if (flags_we) begin fz <= az; fn_ <= an; fc <= ac; fv <= av; end
      if (reg_we) r[waddr] <= wdata;
    end

  assign imem_addr  = pc;
  assign dmem_addr  = y;
  assign dmem_wdata = regb;
  assign flag_z = fz;  assign flag_n = fn_;  assign flag_c = fc;  assign flag_v = fv;
  assign pc_out = pc;
  assign r0 = r[0]; assign r1 = r[1]; assign r2 = r[2]; assign r3 = r[3];
  assign r4 = r[4]; assign r5 = r[5]; assign r6 = r[6]; assign r7 = r[7];
endmodule
