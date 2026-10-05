// FILE: tta_hw/pair_hw.v
`timescale 1ns/1ps
`ifndef HALF
  `define HALF 500                 // halve klokperiode in ns: 500 = 1 MHz
`endif
// Eén bord naast één gedragsmodel (week 19), beide met hetzelfde programma.
// Na elke klokcyclus vergelijkt dit blok de volledige toestand van beide en telt de afwijkingen.
module pair_hw #(parameter PROG = "x.hex", parameter DATA = "none", parameter HASDATA = 0, parameter LOAD = 1) (
  input             clk,
  input             rst_n,
  input      [7:0]  inp,                   // de waarde op de ingangspoort
  output reg [31:0] bad,
  output            done
);
  wire [7:0] ob, ow, pcb, r0b, r1b, r2b, r3b, resb;
  wire hb, hh, zb, nb, cb;
  tta #(PROG, LOAD, DATA, HASDATA) b(.clk(clk), .rst_n(rst_n), .in_port(inp), .out_port(ob), .halted(hb), .pc_out(pcb),
      .r0(r0b), .r1(r1b), .r2(r2b), .r3(r3b), .res_out(resb), .flag_z(zb), .flag_n(nb), .flag_c(cb));
  t8_board #(PROG, LOAD) h(.clk(clk), .rst_n(rst_n), .in_port(inp), .out_port(ow), .halted(hh));
  assign done = hb & hh;

  initial begin bad = 0; #1; if (HASDATA) $readmemh(DATA, h.u_ram.mem); end

  integer cyc = 0;
  always @(posedge clk) begin
    #(`HALF / 5);                            // laat het bord tot rust komen (de klok-naar-uitgang-vertragingen)
    if (rst_n) begin
      cyc = cyc + 1;
      if (pcb !== h.pc)            begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: pc %0d <> %0d", cyc, pcb, h.pc); end
      if (r0b !== h.u_r0.q)        begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: r0 %0d <> %0d", cyc, r0b, h.u_r0.q); end
      if (r1b !== h.u_r1.q)        begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: r1 %0d <> %0d", cyc, r1b, h.u_r1.q); end
      if (r2b !== h.u_r2.q)        begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: r2 %0d <> %0d", cyc, r2b, h.u_r2.q); end
      if (r3b !== h.u_r3.q)        begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: r3 %0d <> %0d", cyc, r3b, h.u_r3.q); end
      if (b.op !== h.u_op.q)       begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: op %0d <> %0d", cyc, b.op, h.u_op.q); end
      if (b.mar !== h.u_mar.q)     begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: mar %0d <> %0d", cyc, b.mar, h.u_mar.q); end
      if (resb !== h.u_res.q)      begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: res %0d <> %0d", cyc, resb, h.u_res.q); end
      if ({zb, nb, cb} !== {h.zf, h.nf, h.cf}) begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: vlaggen %b <> %b", cyc, {zb, nb, cb}, {h.zf, h.nf, h.cf}); end
      if (ob !== ow)               begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: out %0d <> %0d", cyc, ob, ow); end
      if (hb !== hh)               begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: halted %b <> %b", cyc, hb, hh); end
    end
    #(`HALF * 7 / 10);                       // vlak voor de dalende flank: de bus moet rustig en zonder X zijn
    if (rst_n && !hh && ^h.bus === 1'bx) begin bad = bad + 1; if (bad < 4) $display("%m cyc %0d: X op de bus", cyc); end
  end
endmodule
