// FILE: tta_hw/tb_t8_board_random.v
`timescale 1ns/1ps
`ifndef HALF
  `define HALF 500
`endif
// 300 willekeurige programma's op het 74HC-bord en het gedragsmodel, cyclus voor cyclus vergeleken.
// pair_hw staat in pair_hw.v.
module tb_t8_board_random;
  reg clk = 0, rst_n = 0;
  reg [7:0] inp = 0;
  wire [31:0] bad;
  wire done;
  integer fouten = 0, prog, k, cycli, idx, kind, kk;
  reg [23:0] prog_mem [0:255];
  reg [4:0]  dsel;
  reg [2:0]  gsel;
  reg [7:0]  ssel;

  pair_hw #("none.hex", "none", 0, 0) p(clk, rst_n, inp, bad, done);
  always #(`HALF) clk = ~clk;

  function [23:0] mv(input [2:0] g, input [4:0] d, input [7:0] s, input [7:0] imm);
    mv = {g, d, s, imm};
  endfunction

  task make_program(input integer lengte);
    begin
      for (idx = 0; idx < 256; idx = idx + 1) prog_mem[idx] = mv(0, 31, 0, 0);
      for (idx = 0; idx < lengte; idx = idx + 1) begin
        kind = {$random} % 100;
        gsel = ({$random} % 100 < 40) ? 3'd0 : ({$random} % 8);
        if (kind < 6) begin
          kk = {$random} % 4;
          prog_mem[idx] = mv(gsel, 11, 0, (idx + 1 + kk > lengte) ? lengte : idx + 1 + kk);
        end else begin
          case ({$random} % 15)
            0: dsel = 0;   1: dsel = 1;   2: dsel = 2;   3: dsel = 3;   4: dsel = 4;   5: dsel = 5;
            6: dsel = 6;   7: dsel = 7;   8: dsel = 8;   9: dsel = 9;   10: dsel = 10;
            11: dsel = 12; 12: dsel = 13; 13: dsel = 14; default: dsel = ({$random} % 2) ? 15 : 16;
          endcase
          ssel = {$random} % 12;
          if (ssel == 8 && dsel == 13) ssel = 0;       // MEM -> MEM zou op het bord de bus dubbel aansturen: verboden
          prog_mem[idx] = mv(gsel, dsel, ssel, $random);
        end
      end
      prog_mem[lengte] = mv(0, 31, 0, 0);
    end
  endtask

  initial begin
    #2300;
    for (prog = 0; prog < 300; prog = prog + 1) begin
      make_program(30 + ({$random} % 100));
      inp = $random;
      for (k = 0; k < 256; k = k + 1) begin
        p.b.rom[k] = prog_mem[k];
        p.h.u_rom_hi.words[k] = prog_mem[k]; p.h.u_rom_mid.words[k] = prog_mem[k]; p.h.u_rom_lo.words[k] = prog_mem[k];
        p.b.ram[k] = {$random};  p.h.u_ram.mem[k] = p.b.ram[k];
      end
      // De 74HC574-registers hebben geen resetpin: een echt bord begint na het inschakelen met willekeurige waarden.
      // Om het gedragsmodel eerlijk te vergelijken, "schakelen we de voeding uit en aan" door ze op nul te zetten.
      p.h.u_r0.q = 0; p.h.u_r1.q = 0; p.h.u_r2.q = 0; p.h.u_r3.q = 0;
      p.h.u_op.q = 0; p.h.u_mar.q = 0; p.h.u_out.q = 0; p.h.u_res.q = 0;
      rst_n = 0; repeat (2) @(posedge clk); #(`HALF / 5);
      rst_n = 1; cycli = 0;
      while (!done && cycli < 300) begin @(posedge clk); cycli = cycli + 1; end
      repeat (3) @(posedge clk);
      if (!done) begin fouten = fouten + 1; $display("FAIL prog %0d: niet gestopt", prog); end
      #600;
    end
    if (bad !== 0) begin fouten = fouten + 1; $display("FAIL: %0d afwijkingen", bad); end
    if (fouten == 0) $display("PASS: 300 willekeurige programma's: het 74HC-bord volgt het gedragsmodel cyclus voor cyclus");
    $finish;
  end
endmodule
