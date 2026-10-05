---
title: "Week 16 · Je eerste CPU draait: verificatie en prestaties"
---

<p class="subtitle">Fase 4 · Je eerste CPU · ongeveer 12 uur</p>

# Week 16: Je eerste CPU draait

## Wat je na deze week kunt

- programma's op je CPU laten draaien en het resultaat controleren
- een instructietrace gebruiken om een programma te volgen
- een CPU verifiëren met een instructieset-simulator (referentiemodel) en willekeurige programma's
- de prestaties van je CPU meten en uitdrukken in CPI
- een bug in de CPU opsporen met je testbenches

## 1. Het moment van de waarheid

Je hebt alle onderdelen: ALU, datapath, besturing en geheugens. Samen vormen ze de CPU. Deze week maken we dat hard. We draaien er programma's op, controleren of de uitkomst klopt en bewijzen zo goed mogelijk dat hij altijd klopt.

Controleer dat je map `labs/cpu/` deze bestanden bevat: `alu.v`, `idecode.v`, `memories.v`, `datapath.v`, `control.v`, `cpu.v` en `asm_funcs.vh`.

## 2. Gerichte programma's

In week 13 hadden we een mini-assembler in Verilog-functies (`I_LDI`, `I_ALU`, ...). Daarmee zetten we vijf programma's in het instructiegeheugen:

1. Som van 1 tot 10: een lus met een teller. Verwacht R1 = 55 en precies 66 klokcycli (33 instructies × 2).
2. Fibonacci: de eerste 12 getallen in het datageheugen.
3. Subroutine: `CALL` en `JR R7`, twee keer aangeroepen.
4. Voorwaarden: een vergelijking met teken (`BLT`) en een zonder teken (`BCS`). Met R1 = 253 is dat zonder teken groter dan 5 en met teken kleiner dan 5. Beide takken moeten kloppen.
5. Geheugen en ALU: `ST` en `LD` met een offset, plus alle bitoperaties.

```verilog
// FILE: cpu/tb_programs.v
`include "asm_funcs.vh"
module tb_programs;
  reg clk = 0, rst_n = 0;
  wire halted, fz, fn, fc, fv;
  wire [7:0] pc, r0, r1, r2, r3, r4, r5, r6, r7;
  integer fouten = 0, cycli, k;

  cpu #("prog.hex", 0) dut(clk, rst_n, halted, pc, r0, r1, r2, r3, r4, r5, r6, r7, fz, fn, fc, fv);
  always #5 clk = ~clk;

  // Zet een programma klaar, reset de CPU en draai tot HALT (of tot een limiet).
  task run;
    begin
      rst_n = 0; repeat (2) @(negedge clk);
      rst_n = 1; cycli = 0;
      while (!halted && cycli < 20000) begin @(negedge clk); cycli = cycli + 1; end
      if (!halted) begin fouten = fouten + 1; $display("FAIL: CPU stopte niet"); end
    end
  endtask

  task clear_all;
    begin
      for (k = 0; k < 256; k = k + 1) begin dut.im.mem[k] = I_NOP; dut.dm.mem[k] = 8'h00; end
    end
  endtask

  task expect8(input [7:0] actual, input [7:0] verwacht, input [255:0] naam);
    if (actual !== verwacht) begin
      fouten = fouten + 1; $display("FAIL %0s: %0d i.p.v. %0d", naam, actual, verwacht);
    end
  endtask

  initial begin
    // ---- Programma 1: som van 1 tot 10 ----
    clear_all;
    dut.im.mem[0] = I_LDI(1, 0);                 // R1 = 0 (som)
    dut.im.mem[1] = I_LDI(2, 10);                // R2 = 10 (teller)
    dut.im.mem[2] = I_ALU(F_ADD, 1, 1, 2);       // lus: R1 = R1 + R2
    dut.im.mem[3] = I_ADDI(2, 8'hFF);            // R2 = R2 - 1  (zet Z als R2 nul wordt)
    dut.im.mem[4] = I_BCC(C_NE, 8'd2);           // terug naar de lus zolang R2 != 0
    dut.im.mem[5] = I_HALT;
    run;
    expect8(r1, 8'd55, "som 1..10");
    expect8(r2, 8'd0,  "teller na lus");
    // Tel: 2 LDI + 10 * (ADD, ADDI, BNE) + HALT = 33 instructies, 2 cycli elk = 66 cycli.
    if (cycli !== 66) begin fouten = fouten + 1; $display("FAIL: cycli = %0d", cycli); end

    // ---- Programma 2: Fibonacci in het geheugen ----
    clear_all;
    dut.im.mem[0]  = I_LDI(0, 0);                // R0 = a = 0
    dut.im.mem[1]  = I_LDI(1, 1);                // R1 = b = 1
    dut.im.mem[2]  = I_LDI(2, 0);                // R2 = wijzer
    dut.im.mem[3]  = I_LDI(3, 12);               // R3 = aantal
    dut.im.mem[4]  = I_ST(0, 2, 0);              // lus: mem[R2] = a
    dut.im.mem[5]  = I_ALU(F_ADD, 4, 0, 1);      // R4 = a + b
    dut.im.mem[6]  = I_ALU(F_OR,  0, 1, 1);      // a = b   (MOV)
    dut.im.mem[7]  = I_ALU(F_OR,  1, 4, 4);      // b = R4  (MOV)
    dut.im.mem[8]  = I_ADDI(2, 8'd1);            // wijzer++
    dut.im.mem[9]  = I_ADDI(3, 8'hFF);           // aantal--
    dut.im.mem[10] = I_BCC(C_NE, 8'd4);
    dut.im.mem[11] = I_HALT;
    run;
    begin : fibcheck
      reg [7:0] f [0:11];
      f[0]=0; f[1]=1; f[2]=1; f[3]=2; f[4]=3; f[5]=5; f[6]=8; f[7]=13; f[8]=21; f[9]=34; f[10]=55; f[11]=89;
      for (k = 0; k < 12; k = k + 1)
        if (dut.dm.mem[k] !== f[k]) begin fouten = fouten + 1; $display("FAIL fib[%0d] = %0d", k, dut.dm.mem[k]); end
    end

    // ---- Programma 3: subroutine met CALL en JR ----
    clear_all;
    dut.im.mem[0] = I_LDI(1, 7);                 // R1 = 7
    dut.im.mem[1] = I_CALL(8'd10);               // roep 'verdubbel' aan
    dut.im.mem[2] = I_CALL(8'd10);               // en nog een keer: R1 = 28
    dut.im.mem[3] = I_HALT;
    dut.im.mem[10] = I_ALU(F_ADD, 1, 1, 1);      // verdubbel: R1 = R1 + R1
    dut.im.mem[11] = I_JR(7);                    // terug (R7 bevat het terugkeeradres)
    run;
    expect8(r1, 8'd28, "verdubbel twee keer");
    expect8(r7, 8'd3,  "R7 = terugkeeradres van tweede CALL");

    // ---- Programma 4: voorwaarden: signed en unsigned vergelijken ----
    clear_all;
    dut.im.mem[0]  = I_LDI(1, 8'hFD);            // R1 = -3 (met teken), 253 (zonder)
    dut.im.mem[1]  = I_LDI(2, 5);                // R2 = 5
    dut.im.mem[2]  = I_CMP(1, 2);                // R1 - R2
    dut.im.mem[3]  = I_BCC(C_LT, 8'd6);          // met teken: -3 < 5, dus springen
    dut.im.mem[4]  = I_LDI(3, 1);                // overgeslagen
    dut.im.mem[5]  = I_HALT;                     // overgeslagen
    dut.im.mem[6]  = I_LDI(3, 2);                // R3 = 2 (signed vergelijking klopte)
    dut.im.mem[7]  = I_BCC(C_CS, 8'd10);         // zonder teken: 253 >= 5, dus springen
    dut.im.mem[8]  = I_LDI(4, 1);                // overgeslagen
    dut.im.mem[9]  = I_HALT;                     // overgeslagen
    dut.im.mem[10] = I_LDI(4, 2);                // R4 = 2 (unsigned vergelijking klopte)
    dut.im.mem[11] = I_CMPI(2, 5);               // R2 - 5 = 0
    dut.im.mem[12] = I_BCC(C_EQ, 8'd14);
    dut.im.mem[13] = I_HALT;
    dut.im.mem[14] = I_LDI(5, 3);                // R5 = 3
    dut.im.mem[15] = I_HALT;
    run;
    expect8(r3, 8'd2, "signed LT"); expect8(r4, 8'd2, "unsigned CS"); expect8(r5, 8'd3, "EQ na CMPI");

    // ---- Programma 5: lees/schrijf met offset en ALU-bewerkingen ----
    clear_all;
    dut.im.mem[0] = I_LDI(1, 100);               // basisadres
    dut.im.mem[1] = I_LDI(2, 8'h5A);
    dut.im.mem[2] = I_ST(2, 1, 6'd3);            // mem[103] = 0x5A
    dut.im.mem[3] = I_LD(3, 1, 6'd3);            // R3 = mem[103]
    dut.im.mem[4] = I_ALU(F_NOT, 4, 3, 0);       // R4 = ~R3 = 0xA5
    dut.im.mem[5] = I_ALU(F_SHL, 5, 3, 0);       // R5 = 0xB4
    dut.im.mem[6] = I_ALU(F_SHR, 6, 3, 0);       // R6 = 0x2D
    dut.im.mem[7] = I_ALU(F_XOR, 0, 3, 4);       // R0 = 0x5A ^ 0xA5 = 0xFF
    dut.im.mem[8] = I_HALT;
    run;
    expect8(dut.dm.mem[103], 8'h5A, "mem[103]"); expect8(r3, 8'h5A, "LD");
    expect8(r4, 8'hA5, "NOT"); expect8(r5, 8'hB4, "SHL"); expect8(r6, 8'h2D, "SHR"); expect8(r0, 8'hFF, "XOR");

    if (fouten == 0) $display("PASS: CPU draait som, Fibonacci, subroutines, voorwaarden en geheugen correct");
    $finish;
  end
endmodule
```

Draai:

```text
cd labs/cpu
iverilog -g2012 -o prog.vvp tb_programs.v alu.v idecode.v memories.v datapath.v control.v cpu.v
vvp prog.vvp
```

Je ziet PASS. Je CPU draait programma's.

## 3. Een trace: zien wat je CPU doet

Als iets niet werkt, wil je zien wat de CPU doet. Een trace schrijft bij elke uitgevoerde instructie een regel: waar de PC stond, welke instructie het was en de toestand van de registers en vlaggen. In Verilog lees je interne signalen rechtstreeks met een hiërarchische naam (`dut.dp.ir`, `dut.ctl.t`).

```verilog
// FILE: cpu/tb_trace.v
`include "asm_funcs.vh"
// Een "trace": bij elke uitgevoerde instructie een regel met PC, instructie en registers.
module tb_trace;
  reg clk = 0, rst_n = 0;
  wire halted;
  wire [7:0] r1, r2;
  integer k, aantal = 0, fouten = 0;
  reg [15:0] eerste [0:2];

  cpu #("none", 0) dut(.clk(clk), .rst_n(rst_n), .halted(halted), .r1(r1), .r2(r2));
  always #5 clk = ~clk;

  function [47:0] naam(input [3:0] op);
    case (op)
      4'h0: naam = "ALU  "; 4'h1: naam = "LDI  "; 4'h2: naam = "ADDI "; 4'h3: naam = "LD   ";
      4'h4: naam = "ST   "; 4'h5: naam = "Bcc  "; 4'h6: naam = "CMP  "; 4'h7: naam = "CMPI ";
      4'h8: naam = "CALL "; 4'h9: naam = "JR   "; 4'hF: naam = "HALT "; default: naam = "NOP  ";
    endcase
  endfunction

  // Elke keer dat een uitvoerstap (t = 1) wordt afgerond, leggen we de instructie vast.
  always @(posedge clk)
    if (rst_n && dut.ctl.t && !halted) begin
      if (aantal < 3) eerste[aantal] = dut.dp.ir;
      aantal = aantal + 1;
      $display("%4d  pc=%3d  ir=%h  %0s  R1=%3d R2=%3d  ZNCV=%b%b%b%b",
               aantal, dut.dp.pc - 8'd1, dut.dp.ir, naam(dut.dp.ir[15:12]), dut.dp.r[1], dut.dp.r[2],
               dut.flag_z, dut.flag_n, dut.flag_c, dut.flag_v);
    end

  initial begin
    for (k = 0; k < 256; k = k + 1) dut.im.mem[k] = I_NOP;
    dut.im.mem[0] = I_LDI(1, 0);
    dut.im.mem[1] = I_LDI(2, 4);
    dut.im.mem[2] = I_ALU(F_ADD, 1, 1, 2);
    dut.im.mem[3] = I_ADDI(2, 8'hFF);
    dut.im.mem[4] = I_BCC(C_NE, 8'd2);
    dut.im.mem[5] = I_HALT;
    #22 rst_n = 1;
    while (!halted) @(negedge clk);
    // 2 LDI + 4 x (ADD, ADDI, BNE) + HALT = 15 instructies
    if (aantal !== 15) begin fouten = fouten + 1; $display("FAIL: %0d instructies i.p.v. 15", aantal); end
    if (eerste[0] !== I_LDI(1, 0) || eerste[2] !== I_ALU(F_ADD, 1, 1, 2)) begin fouten = fouten + 1; $display("FAIL: volgorde"); end
    if (r1 !== 8'd10) begin fouten = fouten + 1; $display("FAIL: R1 = %0d", r1); end
    if (fouten == 0) $display("PASS: trace toont %0d instructies, som 4+3+2+1 = %0d", aantal, r1);
    $finish;
  end
endmodule
```

Een deel van de uitvoer:

```text
   3  pc=  2  ir=0250  ALU    R1=  0 R2=  4  ZNCV=0000
   4  pc=  3  ir=24ff  ADDI   R1=  4 R2=  4  ZNCV=0000
   5  pc=  4  ir=5402  Bcc    R1=  4 R2=  3  ZNCV=0010
   6  pc=  2  ir=0250  ALU    R1=  4 R2=  3  ZNCV=0010
```

Let op twee dingen. De registers die je ziet zijn de toestand voordat de effecten van die regel zijn verwerkt, en de volgende regel toont het resultaat (R1 is 4 na de `ALU`-regel). En na `ADDI R2, -1` staat C op 1. Reken maar na: 4 + 255 = 259, dat is meer dan 255, dus er is een carry-uit. Bij `ADDI` met `0xFF` betekent C = 1 dus dat er niet geleend is, net als bij aftrekken. Handig om te weten als je lussen schrijft.

## 4. De CPU verifiëren met een referentiemodel

Gerichte programma's bewijzen dat je CPU doet wat jij bedacht hebt. Maar fouten zitten waar je niet keek. Daarom doen we wat de chipindustrie ook doet (week 10): willekeurige tests tegen een referentiemodel.

### De instructieset-simulator (ISS)

Het referentiemodel is een eenvoudig programma dat de W8-ISA uitvoert zoals de specificatie het beschrijft: één instructie per stap, met gewone gehele getallen en zonder klokken, flipflops of multiplexers. Verschillen model en hardware, dan zit er een bug in de een of de ander. Het model rekent bewust anders dan de hardware (met `integer` en vergelijkingen in plaats van bit-trucs), zodat dezelfde denkfout niet in beide kan zitten.

### Willekeurige programma's

De testbench maakt 300 keer een willekeurig programma van 40 tot 200 instructies met alle soorten: ALU-instructies, `LDI`, `ADDI`, `LD`, `ST`, `CMP`, `CMPI`, voorwaardelijke sprongen en `CALL`. Sprongen gaan altijd vooruit (maximaal drie instructies), zodat elk programma gegarandeerd eindigt. Het geheugen begint met willekeurige inhoud. Na afloop vergelijken we de acht registers, de vier vlaggen, alle 256 bytes van het datageheugen en het aantal klokcycli (precies 2 per instructie).

```verilog
// FILE: cpu/tb_random.v
`include "asm_funcs.vh"
// Test met willekeurige programma's. Een "instructieset-simulator" (ISS) in de testbench
// voert hetzelfde programma uit met gewone gehele getallen. Daarna vergelijken we
// registers, vlaggen, geheugen en het aantal cycli.
module tb_random;
  reg clk = 0, rst_n = 0;
  wire halted, fz, fn, fc, fv;
  wire [7:0] pc, r0, r1, r2, r3, r4, r5, r6, r7;
  integer fouten = 0, prog, k, n, cycli;

  cpu #("prog.hex", 0) dut(clk, rst_n, halted, pc, r0, r1, r2, r3, r4, r5, r6, r7, fz, fn, fc, fv);
  always #5 clk = ~clk;

  // ---------- Het referentiemodel (ISS) ----------
  integer m_r [0:7];
  integer m_mem [0:255];
  integer m_pc, m_exec;
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
        5: if (cond_ref(cnd)) m_pc = addr;
        6: begin alu_ref(1, m_r[rs1], m_r[rs2]); m_z = a_z; m_n = a_n; m_c = a_c; m_v = a_v; end
        7: begin alu_ref(1, m_r[rd], imm); m_z = a_z; m_n = a_n; m_c = a_c; m_v = a_v; end
        8: begin m_r[7] = m_pc; m_pc = addr; end
        9: m_pc = m_r[rs1];
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
      m_pc = 0; m_exec = 0; m_halt = 0; m_z = 0; m_n = 0; m_c = 0; m_v = 0;
      while (!m_halt) iss_step;

      // De CPU draait hetzelfde programma.
      rst_n = 0; repeat (2) @(negedge clk);
      rst_n = 1; cycli = 0;
      while (!halted && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end

      if (!halted) begin fouten = fouten + 1; $display("FAIL prog %0d: CPU stopte niet", prog); end
      if (cycli !== 2 * m_exec) begin fouten = fouten + 1; $display("FAIL prog %0d: %0d cycli, verwacht %0d", prog, cycli, 2 * m_exec); end
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
    if (fouten == 0) $display("PASS: 300 willekeurige programma's geven identiek resultaat in CPU en referentiemodel");
    $finish;
  end
endmodule
```

Draai:

```text
iverilog -g2012 -o rnd.vvp tb_random.v alu.v idecode.v memories.v datapath.v control.v cpu.v
vvp rnd.vvp
```

Je ziet `PASS: 300 willekeurige programma's ...`. Dat zijn tienduizenden uitgevoerde instructies zonder één afwijking.

### Test de test

Een test die nooit faalt, bewijst niets. Maak daarom met opzet een bug en kijk of de test hem vindt. Open `control.v` en verander de voorwaarde `LT` (`3'd5`) van `flag_n ^ flag_v` in `flag_n`. Draai `tb_random.v` opnieuw. Programma's wijken dan af, bijvoorbeeld zo:

```text
FAIL prog 253: vlaggen CPU 0100 model 0000
FAIL prog 289: 332 cycli, verwacht 336
```

Eén regel fout, gevonden door honderden programma's. Zet de fout daarna terug.

## 5. Prestaties

Hoe snel is je CPU? Er zijn drie kengetallen:

| Kengetal | Betekenis | Voor W8 |
|----------|-----------|---------|
| CPI | cycli per instructie | precies 2 |
| Klokfrequentie | bepaald door het langste pad (week 14) | enkele MHz op 74HC, tientallen tot honderden MHz op een FPGA |
| MIPS | miljoenen instructies per seconde = f / CPI | bij 4 MHz: 2 MIPS |

De uitvoeringstijd van een programma is:

```text
tijd = (aantal instructies) × CPI / klokfrequentie
```

Dit is de vergelijking van computerarchitectuur. Je kunt drie dingen verbeteren: het aantal instructies (een betere ISA of compiler), de CPI (pipelining, week 20) of de klokfrequentie (snellere logica). Het meeste werk in CPU-ontwerp gaat over het afwegen van deze drie.

Een voorbeeld uit onze test: de som van 1 tot 10 gebruikt 33 instructies × 2 = 66 cycli. Bij 4 MHz is dat 16,5 microseconde.

## 6. Debuggen: een werkwijze

Als een test faalt, doe je dit:

1. Reproduceer klein. Zoek het kleinste programma dat de fout geeft. Bij de willekeurige test druk je het programmanummer af en draai je alleen dat programma.
2. Gebruik de trace. Zoek de eerste instructie waarvan het effect afwijkt van wat het model zegt.
3. Kijk in de golfvorm. Zet `clk`, `t`, `ir`, de besturingssignalen en de registers erin en zoek wat in die cyclus anders is dan je verwachtte.
4. Zoek de oorzaak, niet het symptoom. Pas het testmodel niet aan tot het klopt. Het model is de specificatie.
5. Voeg een gerichte test toe voor de fout die je vond, zodat hij niet terugkomt.

## 7. Lab

1. Draai alle drie de testbenches (`tb_programs`, `tb_trace` en `tb_random`) en bewaar de uitvoer.
2. Maak de opzettelijke bug uit paragraaf 4 en laat hem falen. Probeer er nog twee: laat `BGE` hetzelfde doen als `BLT`, en laat `CALL` R6 in plaats van R7 beschrijven. Welke test vangt welke fout het eerst?
3. Schrijf met de `I_...`-functies een eigen programma dat de grootste waarde in een array van 8 bytes zoekt. Laat de testbench het controleren.
4. Maak een golfvorm (`$dumpfile`) van het somprogramma en zoek in een viewer het moment waarop `R1` verandert. Meet hoeveel klokperioden er tussen de vorige en de volgende verandering zitten.
5. Meet het aantal cycli van het Fibonacci-programma en vergelijk dat met een berekening op papier.

## 8. Oefeningen

1. Het somprogramma heeft 33 instructies. Reken zelf na welke instructies hoe vaak worden uitgevoerd.
2. Een programma voert 10 000 instructies uit op een W8 van 5 MHz. Hoe lang duurt dat?
3. Wat is de MIPS-waarde van W8 bij 8 MHz? Vergelijk met een Pentium uit 1995 (ongeveer 100 MIPS) en een moderne telefoon (tienduizenden MIPS).
4. De willekeurige test gebruikt alleen vooruitsprongen. Welke soort fouten kan hij daardoor missen, en hoe vul je dat aan?
5. Het referentiemodel is geschreven door dezelfde persoon als de hardware. Welk risico geeft dat, en hoe beperk je het?
6. Voeg aan `tb_random.v` een controle toe die telt hoe vaak elke voorwaarde (EQ, NE, CS, ...) tijdens de test is genomen. Waarom is dat nuttig?
7. Uitdaging: breid de willekeurige generator uit met achterwaartse sprongen, maar zorg dat het programma toch eindigt. Hint: gebruik een tellerregister dat andere instructies nooit veranderen.

## 9. Antwoorden

1. 2 × `LDI` = 2, de lus (`ADD`, `ADDI`, `BNE`) loopt 10 keer = 30 en `HALT` = 1. Samen 33.
2. 10 000 × 2 / 5 MHz = 20 000 / 5 000 000 = 4 ms.
3. 8 MHz / 2 = 4 MIPS. De Pentium was 25 keer sneller en een moderne telefoon duizenden keren.
4. Lussen: fouten die pas zichtbaar worden bij herhaald uitvoeren, zoals een vlag die van de vorige ronde blijft hangen. Vul het aan met gerichte lusprogramma's (zoals de som en Fibonacci) en een generator voor beperkte lussen.
5. Een misverstand van de ontwerper zit dan zowel in het model als in de hardware, en de test slaagt toch. Je beperkt dat door iemand anders het model te laten schrijven, de ISA-specificatie nogmaals heel precies te lezen of te vergelijken met een tweede, onafhankelijke implementatie (bijvoorbeeld een simulator in Python).
6. Zo zie je of de test alle voorwaarden echt heeft geraakt. Een voorwaarde die nooit genomen is, is niet getest, ook al slaagt de test (coverage, week 10).
7. Reserveer bijvoorbeeld R6 als lusteller en laat de generator R6 nooit als bestemming kiezen. Voeg lussen toe in de vorm `LDI R6,n; ... ADDI R6,-1; BNE terug`. Het model voert dezelfde lus uit en hij eindigt omdat R6 nul wordt.

## 10. Zelftest

1. Wat is een instructietrace?
2. Waarom vergelijken we de CPU met een referentiemodel?
3. Wat is CPI?
4. Waarom maak je met opzet een bug in je ontwerp?
5. Wat zegt `tijd = instructies × CPI / klokfrequentie`?

Antwoorden: (1) Een regel per uitgevoerde instructie met de toestand van de CPU. (2) Het model definieert wat goed is en vindt fouten die je zelf niet bedacht. (3) Het aantal klokcycli per instructie. (4) Om te controleren dat je test hem echt vindt. (5) Dat de uitvoeringstijd afhangt van het aantal instructies, het aantal cycli per instructie en de snelheid van de klok.

## 11. Verder lezen

- Patterson en Hennessy, *Computer Organization and Design*, hoofdstuk 1 (prestaties en de "iron law").
- Wikipedia: "Instruction set simulator". ISS'en worden gebruikt om CPU's te verifiëren en om software te schrijven voor hardware die nog niet bestaat.
- Ben Eater: de video's over het programmeren van zijn computer. Je herkent nu alle onderdelen.

---

> **Een mijlpaal.** Je hebt een eigen CPU ontworpen, gebouwd en grondig getest. Dat doen de meeste mensen die over processors praten nooit. De rest van de cursus bouwt hierop voort.

Volgende week: we hebben een CPU, maar nog geen gemakkelijke manier om hem te programmeren. We schrijven een assembler in Python.
