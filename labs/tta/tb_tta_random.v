// FILE: tta/tb_tta_random.v
// Willekeurige TTA-programma's tegen een referentiemodel (integers, geen hardwaretrucs).
module tb_tta_random;
  reg clk = 0, rst_n = 0;
  reg [7:0] in_port = 0;
  wire [7:0] out_port, pc, r0, r1, r2, r3, res;
  wire out_valid, halted, fz, fn, fc;
  integer fouten = 0, prog, k, n, cycli;

  tta #("none", 0, "none", 0) dut(.clk(clk), .rst_n(rst_n), .in_port(in_port), .out_port(out_port),
      .out_valid(out_valid), .halted(halted), .pc_out(pc), .r0(r0), .r1(r1), .r2(r2), .r3(r3),
      .res_out(res), .flag_z(fz), .flag_n(fn), .flag_c(fc));
  always #5 clk = ~clk;

  function [23:0] mv(input [2:0] g, input [4:0] d, input [7:0] s, input [7:0] imm);
    mv = {g, d, s, imm};
  endfunction

  // DUT-uitvoer opvangen
  reg [7:0] dut_out [0:2047];
  integer dut_n;
  always @(posedge clk) if (out_valid) begin dut_out[dut_n] = out_port; dut_n = dut_n + 1; end

  // ---------- Referentiemodel ----------
  reg [23:0] prog_mem [0:255];
  integer m_r [0:3];
  integer m_op, m_res, m_mar, m_pc, m_steps;
  integer m_ram [0:255];
  reg m_z, m_n, m_c, m_halt;
  integer m_out [0:2047];
  integer m_outn;

  task model_step;
    integer w, g, d, s, imm, v, t, next_pc;
    reg go;
    begin
      w = prog_mem[m_pc]; g = (w / 2097152) % 8; d = (w / 65536) % 32; s = (w / 256) % 32; imm = w % 256;
      case (s)
        0: v = imm;
        1: v = m_r[0]; 2: v = m_r[1]; 3: v = m_r[2]; 4: v = m_r[3];
        5: v = m_res;
        6: v = m_res / 2;
        7: v = 255 - m_res;
        8: v = m_ram[m_mar];
        9: v = in_port;
        10: v = (m_pc + 2) % 256;
        11: v = (m_n ? 4 : 0) + (m_c ? 2 : 0) + (m_z ? 1 : 0);
        default: v = 0;
      endcase
      case (g)
        0: go = 1; 1: go = m_z; 2: go = !m_z; 3: go = m_c; 4: go = !m_c; 5: go = m_n; 6: go = !m_n; default: go = 0;
      endcase
      m_steps = m_steps + 1;
      next_pc = (m_pc + 1) % 256;
      if (go) begin
        case (d)
          1: m_r[0] = v;  2: m_r[1] = v;  3: m_r[2] = v;  4: m_r[3] = v;
          5: m_op = v;
          6: begin t = m_op + v;                    m_res = t % 256; m_c = (t > 255); end
          7: begin t = m_op - v;                    m_res = (t + 256) % 256; m_c = (m_op >= v); end
          16: begin t = m_op + v + (m_c ? 1 : 0);   m_res = t % 256; m_c = (t > 255); end
          15: begin t = v * 2;                      m_res = t % 256; m_c = (v >= 128); end
          8:  begin m_res = m_op & v; m_c = 0; end
          9:  begin m_res = m_op | v; m_c = 0; end
          10: begin m_res = m_op ^ v; m_c = 0; end
          12: m_mar = v;
          13: m_ram[m_mar] = v;
          14: begin m_out[m_outn] = v; m_outn = m_outn + 1; end
          31: m_halt = 1;
          default: ;
        endcase
        if (d >= 6 && d <= 10 || d == 15 || d == 16) begin m_z = (m_res == 0); m_n = (m_res >= 128); end
        if (d == 11) next_pc = v;
      end
      m_pc = next_pc;
    end
  endtask

  // ---------- Willekeurige programma's ----------
  integer idx, kind, kk;
  reg [4:0] dsel;
  reg [2:0] gsel;
  task make_program(input integer lengte);
    begin
      for (idx = 0; idx < 256; idx = idx + 1) prog_mem[idx] = mv(0, 31, 0, 0);
      for (idx = 0; idx < lengte; idx = idx + 1) begin
        kind = {$random} % 100;
        gsel = ({$random} % 100 < 40) ? 3'd0 : ({$random} % 8);
        if (kind < 6) begin
          kk = {$random} % 4;                                      // alleen vooruit springen
          prog_mem[idx] = mv(gsel, 11, 0, (idx + 1 + kk > lengte) ? lengte : idx + 1 + kk);
        end else begin
          case ({$random} % 15)
            0: dsel = 0;   1: dsel = 1;   2: dsel = 2;   3: dsel = 3;   4: dsel = 4;   5: dsel = 5;
            6: dsel = 6;   7: dsel = 7;   8: dsel = 8;   9: dsel = 9;   10: dsel = 10;
            11: dsel = 12; 12: dsel = 13; 13: dsel = 14; default: dsel = ({$random} % 2) ? 15 : 16;
          endcase
          prog_mem[idx] = mv(gsel, dsel, {$random} % 12, $random);
        end
      end
      prog_mem[lengte] = mv(0, 31, 0, 0);
    end
  endtask

  initial begin
    for (prog = 0; prog < 300; prog = prog + 1) begin
      make_program(40 + ({$random} % 150));
      in_port = $random;
      for (k = 0; k < 4; k = k + 1) m_r[k] = 0;
      m_op = 0; m_res = 0; m_mar = 0; m_pc = 0; m_steps = 0; m_z = 0; m_n = 0; m_c = 0; m_halt = 0; m_outn = 0;
      for (k = 0; k < 256; k = k + 1) begin
        m_ram[k] = {$random} % 256;
        dut.ram[k] = m_ram[k];
        dut.rom[k] = prog_mem[k];
      end
      while (!m_halt) model_step;

      dut_n = 0;
      rst_n = 0; repeat (2) @(negedge clk);
      rst_n = 1; cycli = 0;
      while (!halted && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end
      @(negedge clk);                                             // laat de laatste uitvoer nog binnenkomen

      if (!halted) begin fouten = fouten + 1; $display("FAIL prog %0d: stopte niet", prog); end
      if (cycli !== m_steps) begin fouten = fouten + 1; $display("FAIL prog %0d: %0d cycli, model %0d stappen", prog, cycli, m_steps); end
      if ({r0, r1, r2, r3} !== {m_r[0][7:0], m_r[1][7:0], m_r[2][7:0], m_r[3][7:0]}) begin fouten = fouten + 1; $display("FAIL prog %0d: registers", prog); end
      if (res !== m_res[7:0] || dut.op !== m_op[7:0] || dut.mar !== m_mar[7:0]) begin fouten = fouten + 1; $display("FAIL prog %0d: res/op/mar", prog); end
      if ({fz, fn, fc} !== {m_z, m_n, m_c}) begin fouten = fouten + 1; $display("FAIL prog %0d: vlaggen", prog); end
      if (dut_n !== m_outn) begin fouten = fouten + 1; $display("FAIL prog %0d: %0d uitvoerwaarden, model %0d", prog, dut_n, m_outn); end
      else for (k = 0; k < m_outn; k = k + 1) if (dut_out[k] !== m_out[k][7:0]) begin fouten = fouten + 1; $display("FAIL prog %0d: uitvoer %0d", prog, k); end
      for (k = 0; k < 256; k = k + 1)
        if (dut.ram[k] !== m_ram[k][7:0]) begin fouten = fouten + 1; if (fouten < 10) $display("FAIL prog %0d: ram[%0d]", prog, k); end
    end
    if (fouten == 0) $display("PASS: 300 willekeurige TTA-programma's geven identiek resultaat in hardware en referentiemodel");
    $finish;
  end
endmodule
