// FILE: beeld/cpu_v.v
// W8F: de FPGA-vriendelijke W8I. Datageheugen in blok-RAM, LD kost 3 cycli.
module cpu_v #(
  parameter PROG = "prog.hex", parameter LOAD = 1, parameter DIV = 16, parameter TDIV = 1,
  parameter DATA = "data.hex", parameter DLOAD = 0
) (
  input         clk,
  input         rst_n,
  output        halted,
  output [7:0]  pc_out,
  output [7:0]  r0, r1, r2, r3, r4, r5, r6, r7,
  output        flag_z, flag_n, flag_c, flag_v,
  output        txd,
  input         rxd,
  input  [7:0]  gpio_in,
  output [7:0]  gpio_out,
  input         vblank,
  output        fb_we,
  output [13:0] fb_waddr,
  output [7:0]  fb_wdata
);
  wire pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel, alu_ir, flags_we, mem_we, mem_rd;
  wire int_enter, reti, ei, di, ie, irq;
  wire [1:0] wb_sel, b_sel;
  wire [2:0] alu_op, cond;
  wire [3:0] op;
  wire [7:0] imem_addr, dmem_addr, dmem_wdata, dmem_rdata;
  wire [15:0] imem_dout;

  datapath_i dp(
    .clk(clk), .rst_n(rst_n),
    .pc_inc(pc_inc), .pc_load(pc_load), .pc_src(pc_src), .ir_we(ir_we),
    .reg_we(reg_we), .wa_r7(wa_r7), .ra_sel(ra_sel), .rb_sel(rb_sel),
    .b_sel(b_sel), .alu_ir(alu_ir), .alu_op(alu_op), .wb_sel(wb_sel), .flags_we(flags_we),
    .int_enter(int_enter), .reti(reti), .ei(ei), .di(di), .ie_out(ie),
    .imem_addr(imem_addr), .imem_dout(imem_dout),
    .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata),
    .op(op), .cond(cond),
    .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v),
    .pc_out(pc_out), .r0(r0), .r1(r1), .r2(r2), .r3(r3), .r4(r4), .r5(r5), .r6(r6), .r7(r7)
  );

  control_f ctl(
    .clk(clk), .rst_n(rst_n), .op(op), .cond(cond),
    .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v), .irq(irq), .ie(ie),
    .pc_inc(pc_inc), .pc_load(pc_load), .pc_src(pc_src), .ir_we(ir_we),
    .reg_we(reg_we), .wa_r7(wa_r7), .ra_sel(ra_sel), .rb_sel(rb_sel),
    .alu_ir(alu_ir), .flags_we(flags_we), .mem_we(mem_we),
    .wb_sel(wb_sel), .b_sel(b_sel), .alu_op(alu_op), .mem_rd(mem_rd),
    .int_enter(int_enter), .reti(reti), .ei(ei), .di(di), .halted(halted)
  );

  imem #(PROG, LOAD) im(imem_addr, imem_dout);
  mmio_v #(DIV, TDIV, DATA, DLOAD) io(clk, rst_n, mem_we, mem_rd, dmem_addr, dmem_wdata, dmem_rdata,
                 txd, rxd, gpio_in, gpio_out, irq, vblank, fb_we, fb_waddr, fb_wdata);
endmodule
