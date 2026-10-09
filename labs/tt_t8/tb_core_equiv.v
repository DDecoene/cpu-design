// De parametriseerbare kern (met PCW = 8, AW = 8) moet exact de machine uit week 19 zijn.
// 300 willekeurige programma's, na elke klokcyclus vergeleken met tta.v.
module tb_core_equiv;
  reg clk = 0, rst_n = 0;
  reg [7:0] inp = 0;
  wire [7:0] ob, pcb, r0b, r1b, r2b, r3b, resb;
  wire hb, zb, nb, cb;
  wire [7:0] oc, r0c, r1c, r2c, r3c, opc, resc, rom_addr;
  wire hc, zc, nc, cc;
  reg  [23:0] rom [0:255];
  wire [23:0] instr = rom[rom_addr];
  integer fouten = 0, prog, k, idx, kind, kk, cycli, bad = 0;
  reg [4:0] dsel;
  reg [2:0] gsel;
  reg [7:0] ssel;

  tta #("none", 0, "none", 0) b(.clk(clk), .rst_n(rst_n), .in_port(inp), .out_port(ob), .halted(hb), .pc_out(pcb),
      .r0(r0b), .r1(r1b), .r2(r2b), .r3(r3b), .res_out(resb), .flag_z(zb), .flag_n(nb), .flag_c(cb));
  t8_core #(8, 8) c(.clk(clk), .rst_n(rst_n), .in_port(inp), .out_port(oc), .halted(hc), .rom_addr(rom_addr), .instr(instr),
      .r0(r0c), .r1(r1c), .r2(r2c), .r3(r3c), .op_out(opc), .res_out(resc), .flag_z(zc), .flag_n(nc), .flag_c(cc));
  always #5 clk = ~clk;

  function [23:0] mv(input [2:0] g, input [4:0] d, input [7:0] s, input [7:0] imm);
    mv = {g, d, s, imm};
  endfunction

  task make_program(input integer lengte);
    begin
      for (idx = 0; idx < 256; idx = idx + 1) rom[idx] = mv(0, 31, 0, 0);
      for (idx = 0; idx < lengte; idx = idx + 1) begin
        kind = {$random} % 100;
        gsel = ({$random} % 100 < 40) ? 3'd0 : ({$random} % 8);
        if (kind < 6) begin
          kk = {$random} % 4;
          rom[idx] = mv(gsel, 11, 0, (idx + 1 + kk > lengte) ? lengte : idx + 1 + kk);
        end else begin
          case ({$random} % 15)
            0: dsel = 0;   1: dsel = 1;   2: dsel = 2;   3: dsel = 3;   4: dsel = 4;   5: dsel = 5;
            6: dsel = 6;   7: dsel = 7;   8: dsel = 8;   9: dsel = 9;   10: dsel = 10;
            11: dsel = 12; 12: dsel = 13; 13: dsel = 14; default: dsel = ({$random} % 2) ? 15 : 16;
          endcase
          ssel = {$random} % 12;
          rom[idx] = mv(gsel, dsel, ssel, $random);
        end
      end
      rom[lengte] = mv(0, 31, 0, 0);
    end
  endtask

  always @(posedge clk) begin
    #1;
    if (rst_n) begin
      if ({pcb, r0b, r1b, r2b, r3b, resb, ob, hb} !== {rom_addr, r0c, r1c, r2c, r3c, resc, oc, hc} ||
          b.op !== opc || {zb, nb, cb} !== {zc, nc, cc} || b.mar !== c.mar) begin
        bad = bad + 1;
        if (bad < 4) $display("FAIL: verschil bij pc=%0d", pcb);
      end
    end
  end

  initial begin
    #22;
    for (prog = 0; prog < 300; prog = prog + 1) begin
      make_program(30 + ({$random} % 150));
      inp = $random;
      for (k = 0; k < 256; k = k + 1) begin b.rom[k] = rom[k]; b.ram[k] = {$random}; c.ram[k] = b.ram[k]; end
      rst_n = 0; repeat (2) @(posedge clk); #1;
      rst_n = 1; cycli = 0;
      while (!(hb && hc) && cycli < 400) begin @(posedge clk); cycli = cycli + 1; end
      if (!(hb && hc)) begin fouten = fouten + 1; $display("FAIL prog %0d: niet gestopt", prog); end
      for (k = 0; k < 256; k = k + 1) if (b.ram[k] !== c.ram[k]) begin fouten = fouten + 1; if (fouten < 5) $display("FAIL prog %0d: ram[%0d]", prog, k); end
      #20;
    end
    if (bad !== 0) fouten = fouten + 1;
    if (fouten == 0) $display("PASS: t8_core (PCW=8, AW=8) is cyclus voor cyclus gelijk aan de machine uit week 19, in 300 willekeurige programma's");
    $finish;
  end
endmodule
