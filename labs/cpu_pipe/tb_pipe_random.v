`include "asm_funcs.vh"
// Test met willekeurige programma's. Een "instructieset-simulator" (ISS) in de testbench
// voert hetzelfde programma uit met gewone gehele getallen. Daarna vergelijken we
// registers, vlaggen, geheugen en het aantal cycli.
module tb_pipe_random;
  reg clk = 0, rst_n = 0;
  wire halted, fz, fn, fc, fv;
  wire [7:0] pc, r0, r1, r2, r3, r4, r5, r6, r7;
  integer fouten = 0, prog, k, n, cycli;

  cpu_p #("prog.hex", 0) dut(clk, rst_n, halted, pc, r0, r1, r2, r3, r4, r5, r6, r7, fz, fn, fc, fv);
  always #5 clk = ~clk;

  // ---------- Het referentiemodel (ISS) ----------
  integer m_r [0:7];
  integer m_mem [0:255];
  integer m_pc, m_exec, m_taken;
  reg     m_z, m_n, m_c, m_v, m_halt;
  reg [15:0] prog_mem [0:255];

  function integer sgn(input integer x);
    sgn = (x >= 128) ? x - 256 : x;
  endfunction

  // Rekent y en de vlaggen uit. Bewust op een andere manier dan alu.v, met gewone integers.
  integer a_y;
  reg a_z, a_n, a_c, a_v;
  task alu_ref(input integer fn, input integer a, input integer b);
    integer s, sv;
    begin
      a_c = 0; a_v = 0;
      case (fn)
        0: begin s = a + b; a_y = s % 256; a_c = (s > 255);
                 sv = sgn(a) + sgn(b); a_v = (sv > 127 || sv < -128); end
        1: begin s = a - b; a_y = (s + 256) % 256; a_c = (a >= b);
                 sv = sgn(a) - sgn(b); a_v = (sv > 127 || sv < -128); end
        2: a_y = a & b;
        3: a_y = a | b;
        4: a_y = a ^ b;
        5: a_y = 255 - a;
        6: begin a_y = (a * 2) % 256; a_c = (a >= 128); end
        7: begin a_y = a / 2; a_c = (a % 2); end
      endcase
      a_z = (a_y == 0);
      a_n = (a_y >= 128);
    end
  endtask

  function cond_ref(input integer c);
    case (c)
      0: cond_ref = 1;
      1: cond_ref = m_z;
      2: cond_ref = !m_z;
      3: cond_ref = m_c;
      4: cond_ref = !m_c;
      5: cond_ref = (m_n != m_v);
      6: cond_ref = (m_n == m_v);
      default: cond_ref = m_n;
    endcase
  endfunction

  task iss_step;
    reg [15:0] w;
    integer op, rd, rs1, rs2, fnn, imm, off, cnd, addr;
    begin
      w = prog_mem[m_pc]; m_pc = (m_pc + 1) % 256; m_exec = m_exec + 1;
      op = w[15:12]; rd = w[11:9]; rs1 = w[8:6]; rs2 = w[5:3]; fnn = w[2:0];
      imm = w[7:0]; off = w[5:0]; cnd = w[11:9]; addr = w[7:0];
      case (op)
        0: begin alu_ref(fnn, m_r[rs1], m_r[rs2]); m_r[rd] = a_y; m_z = a_z; m_n = a_n; m_c = a_c; m_v = a_v; end
        1: m_r[rd] = imm;
        2: begin alu_ref(0, m_r[rd], imm); m_r[rd] = a_y; m_z = a_z; m_n = a_n; m_c = a_c; m_v = a_v; end
        3: m_r[rd] = m_mem[(m_r[rs1] + off) % 256];
        4: m_mem[(m_r[rs1] + off) % 256] = m_r[rd];
        5: if (cond_ref(cnd)) begin m_pc = addr; m_taken = m_taken + 1; end
        6: begin alu_ref(1, m_r[rs1], m_r[rs2]); m_z = a_z; m_n = a_n; m_c = a_c; m_v = a_v; end
        7: begin alu_ref(1, m_r[rd], imm); m_z = a_z; m_n = a_n; m_c = a_c; m_v = a_v; end
        8: begin m_r[7] = m_pc; m_pc = addr; m_taken = m_taken + 1; end
        9: begin m_pc = m_r[rs1]; m_taken = m_taken + 1; end
        15: m_halt = 1;
        default: ;
      endcase
    end
  endtask

  // ---------- Willekeurige programma's maken ----------
  integer idx, kind, kk;
  task make_program(input integer lengte);   // programma: instructies 0..lengte-1, HALT op index lengte
    begin
      for (idx = 0; idx < 256; idx = idx + 1) prog_mem[idx] = I_NOP;
      for (idx = 0; idx < lengte; idx = idx + 1) begin
        kind = {$random} % 100;
        if      (kind < 35) prog_mem[idx] = I_ALU({$random} % 8, {$random} % 8, {$random} % 8, {$random} % 8);
        else if (kind < 45) prog_mem[idx] = I_LDI({$random} % 8, $random);
        else if (kind < 55) prog_mem[idx] = I_ADDI({$random} % 8, $random);
        else if (kind < 65) prog_mem[idx] = I_LD({$random} % 8, {$random} % 8, {$random} % 64);
        else if (kind < 75) prog_mem[idx] = I_ST({$random} % 8, {$random} % 8, {$random} % 64);
        else if (kind < 80) prog_mem[idx] = I_CMP({$random} % 8, {$random} % 8);
        else if (kind < 85) prog_mem[idx] = I_CMPI({$random} % 8, $random);
        else if (kind < 93) begin
          kk = {$random} % 4;                                  // alleen vooruit springen: het programma eindigt altijd
          prog_mem[idx] = I_BCC({$random} % 8, (idx + 1 + kk > lengte) ? lengte : idx + 1 + kk);
        end
        else if (kind < 96) begin
          kk = {$random} % 3;
          prog_mem[idx] = I_CALL((idx + 1 + kk > lengte) ? lengte : idx + 1 + kk);
        end
        else prog_mem[idx] = I_NOP;
      end
      prog_mem[lengte] = I_HALT;
    end
  endtask

  initial begin
    for (prog = 0; prog < 300; prog = prog + 1) begin
      make_program(40 + ({$random} % 160));
      // Beginsituatie: modelregisters nul, geheugen willekeurig maar gelijk in model en CPU.
      for (k = 0; k < 8; k = k + 1) m_r[k] = 0;
      for (k = 0; k < 256; k = k + 1) begin
        m_mem[k] = {$random} % 256;
        dut.dm.mem[k] = m_mem[k];
        dut.im.mem[k] = prog_mem[k];
      end
      m_pc = 0; m_exec = 0; m_taken = 0; m_halt = 0; m_z = 0; m_n = 0; m_c = 0; m_v = 0;
      while (!m_halt) iss_step;

      // De CPU draait hetzelfde programma.
      rst_n = 0; repeat (2) @(negedge clk);
      rst_n = 1; cycli = 0;
      while (!halted && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end

      if (!halted) begin fouten = fouten + 1; $display("FAIL prog %0d: CPU stopte niet", prog); end
      // 1 cyclus om de trap te vullen + 1 per instructie + 1 verloren cyclus per genomen sprong
      if (cycli !== 1 + m_exec + m_taken) begin fouten = fouten + 1; $display("FAIL prog %0d: %0d cycli, verwacht %0d", prog, cycli, 1 + m_exec + m_taken); end
      if ({r0, r1, r2, r3, r4, r5, r6, r7} !== {m_r[0][7:0], m_r[1][7:0], m_r[2][7:0], m_r[3][7:0],
                                                 m_r[4][7:0], m_r[5][7:0], m_r[6][7:0], m_r[7][7:0]}) begin
        fouten = fouten + 1; $display("FAIL prog %0d: registers wijken af", prog);
      end
      if ({fz, fn, fc, fv} !== {m_z, m_n, m_c, m_v}) begin
        fouten = fouten + 1; $display("FAIL prog %0d: vlaggen CPU %b%b%b%b model %b%b%b%b", prog, fz, fn, fc, fv, m_z, m_n, m_c, m_v);
      end
      for (k = 0; k < 256; k = k + 1)
        if (dut.dm.mem[k] !== m_mem[k][7:0]) begin
          fouten = fouten + 1; if (fouten < 10) $display("FAIL prog %0d: mem[%0d] = %0d i.p.v. %0d", prog, k, dut.dm.mem[k], m_mem[k]);
        end
    end
    if (fouten == 0) $display("PASS: 300 willekeurige programma's geven op de gepijplijnde CPU hetzelfde resultaat als het referentiemodel");
    $finish;
  end
endmodule
