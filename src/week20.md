---
title: "Week 20 · Pipelining"
---

<p class="subtitle">Fase 5 · Geavanceerde architecturen · ongeveer 12 uur</p>

# Week 20: Pipelining

## Wat je na deze week kunt

- uitleggen wat pipelining is en waarom het de doorvoer (throughput) verhoogt zonder de latentie te verkorten
- de drie soorten hazards (structureel, data en controle) benoemen
- een CPU met minimale wijzigingen omzetten naar een gepijplijnde variant
- de prestatiewinst berekenen en meten (CPI, aantal verloren cycli)
- begrijpen waarom een tweetrapspipeline weinig problemen heeft en een vijftrapspipeline veel meer

## 1. De wasmachine-vergelijking

Stel dat je wasgoed drie stappen doorloopt: wassen (30 min), drogen (40 min) en vouwen (20 min). Zonder planning doe je één lading in 90 minuten en begin je dan pas aan de volgende. Met overlap begin je meteen aan de tweede lading als de eerste in de droger gaat. Na de eerste lading komt er dan om de 40 minuten (de langzaamste stap) een lading klaar.

```text
 geen overlap:   [was1 droog1 vouw1][was2 droog2 vouw2][was3 ...
 met overlap:    [was1 droog1 vouw1]
                      [was2 droog2 vouw2]
                           [was3 droog3 vouw3]
```

Onthoud twee dingen. De latentie van één lading (de tijd van begin tot eind) wordt niet korter, eerder iets langer. De doorvoer (ladingen per uur) wordt wel veel groter: om de 40 minuten klaar in plaats van om de 90.

Een CPU-instructie doorloopt ook stappen: ophalen, decoderen, uitvoeren, geheugen en terugschrijven. Als je die laat overlappen, kan er elke klokcyclus een instructie klaarkomen.

### De formules

Voor een pipeline met n trappen, waarvan de langzaamste trap T kost:

```text
  klokperiode  ≈  T_langzaamste_trap + overhead van de pipelineregisters
  ideale CPI   =  1 (één instructie per cyclus)
  ideale versnelling t.o.v. een machine met één lange trap  ≈  n
```

Er staat niet voor niets "ideaal": in de praktijk verliezen we cycli aan hazards.

## 2. De drie hazards

Een hazard is een situatie waarin de volgende instructie niet meteen kan beginnen zonder fouten te veroorzaken.

| Soort | Probleem | Voorbeeld |
|-------|----------|-----------|
| Structureel | twee instructies willen tegelijk dezelfde hardware gebruiken | één geheugen voor instructies en data |
| Data | een instructie heeft een resultaat nodig dat nog niet geschreven is | `ADD R1,R2,R3` gevolgd door `SUB R4,R1,R5` |
| Controle | je weet pas laat welke instructie de volgende is | een sprong |

Hoe los je ze op? Bij een stall (wachten) voeg je een lege cyclus ("bubbel") in. Dat is simpel, maar het kost tijd. Bij forwarding (doorsturen) geef je het resultaat direct van het einde van de ene trap door aan de ingang van een andere, zonder te wachten tot het in het registerbestand is geschreven. Met een flush gooi je de instructies weg die je ten onrechte hebt opgehaald. En je kunt voorspellen: raden wat de sprong gaat doen (week 21).

## 3. De klassieke vijftrapspipeline

Veel leerboeken gebruiken deze opbouw:

| Trap | Naam | Taak |
|------|------|------|
| IF | Instruction Fetch | instructie ophalen |
| ID | Instruction Decode | decoderen, registers lezen |
| EX | Execute | ALU, adres berekenen |
| MEM | Memory | geheugen lezen of schrijven |
| WB | Write Back | resultaat in een register zetten |

```text
 cyclus:    1    2    3    4    5    6    7
 instr 1:  IF   ID   EX   MEM  WB
 instr 2:       IF   ID   EX   MEM  WB
 instr 3:            IF   ID   EX   MEM  WB
```

Bij elke grens zit een pipelineregister dat de tussenresultaten vasthoudt. Het ontwerp heeft drie sleutelproblemen, waar we de komende week op ingaan.

- Lees-na-schrijf: instructie 2 leest in ID een register dat instructie 1 pas in WB schrijft, twee cycli later. De oplossing is forwarding.
- Load-gebruik: `LD R1,...` wordt gevolgd door een instructie die R1 meteen gebruikt, maar de waarde bestaat pas na MEM. Zelfs met forwarding moet je één cyclus wachten.
- Sprongen: pas in EX weet je of een sprong genomen wordt. Intussen zijn er al twee instructies opgehaald.

## 4. Onze W8 pipelinen

W8 heeft al twee fasen, ophalen (T0) en uitvoeren (T1), maar die volgen elkaar op, waardoor je twee cycli per instructie nodig hebt. Wat als ze overlappen?

```text
 cyclus:         1     2     3     4     5     6
 instructie 1:  IF    EX
 instructie 2:        IF    EX
 instructie 3:              IF    EX
```

In cyclus 2 voert de CPU instructie 1 uit terwijl hij instructie 2 ophaalt. Dat is één instructie per cyclus, dus CPI 1 in plaats van 2.

### Moet het datapath veranderen?

Bijna niets. Dat is het mooie van een goed ontwerp: het datapath kon al in dezelfde cyclus uitvoeren en de PC ophogen. Er zijn maar twee wijzigingen.

1. De besturing hoeft niet meer te wisselen tussen T0 en T1. In elke cyclus staan `pc_inc` en `ir_we` aan, plus de signalen voor de instructie in het IR.
2. Een genomen sprong gooit de zojuist opgehaalde instructie weg. Die is van de verkeerde plek gehaald. Het IR krijgt een `NOP` in plaats van de gelezen instructie.

### Waarom geen datahazards?

De registers worden aan het einde van de uitvoertrap geschreven. De volgende instructie leest haar registers in haar eigen uitvoertrap, een cyclus later, en dan zijn de nieuwe waarden er al. Dus:

```text
 ADD R1,R2,R3     :  IF  EX(schrijft R1 aan het einde van deze cyclus)
 SUB R4,R1,R5     :      IF  EX(leest R1: nieuwe waarde is er)
```

Hetzelfde geldt voor de vlaggen (een `BNE` direct na een `ADDI` ziet de nieuwe Z-vlag) en voor het geheugen (een `LD` direct na een `ST` naar hetzelfde adres leest de nieuwe waarde). Een tweetrapspipeline met dit ontwerp heeft dus alleen een controlehazard: elke genomen sprong kost één cyclus.

### Wat doen `CALL` en `HALT`?

`CALL` bewaart de PC in R7 en springt. Tijdens de uitvoer van een instructie op adres a staat de PC op a + 1 (de volgende instructie wordt al opgehaald), net als in de niet-gepijplijnde W8. Het terugkeeradres klopt dus zonder wijziging. `CALL` is een genomen sprong en kost dus een flush. `HALT` zet het halt-register, en de instructie die intussen is opgehaald wordt nooit uitgevoerd.

## 5. De implementatie

Je hebt maar twee nieuwe bestanden nodig. Kopieer eerst de bestanden die niet veranderen (`alu.v`, `idecode.v`, `memories.v`, `datapath.v`, `asm_funcs.vh`, `asm.py`, de programma's en de oude `control.v` en `cpu.v` voor de vergelijking) naar de nieuwe map `labs/cpu_pipe/`.

<!-- COPY cpu/alu.v cpu_pipe/alu.v -->
<!-- COPY cpu/idecode.v cpu_pipe/idecode.v -->
<!-- COPY cpu/memories.v cpu_pipe/memories.v -->
<!-- COPY cpu/datapath.v cpu_pipe/datapath.v -->
<!-- COPY cpu/control.v cpu_pipe/control.v -->
<!-- COPY cpu/cpu.v cpu_pipe/cpu.v -->
<!-- COPY cpu/asm_funcs.vh cpu_pipe/asm_funcs.vh -->
<!-- COPY cpu/asm.py cpu_pipe/asm.py -->
<!-- COPY cpu/sum.asm cpu_pipe/sum.asm -->
<!-- COPY cpu/mul.asm cpu_pipe/mul.asm -->
<!-- COPY cpu/sort.asm cpu_pipe/sort.asm -->
<!-- COPY cpu/primes.asm cpu_pipe/primes.asm -->
<!-- COPY cpu/gcd.asm cpu_pipe/gcd.asm -->
<!-- COPY cpu/calls.asm cpu_pipe/calls.asm -->

### De besturing: één trap in plaats van twee

Vergelijk dit met `control.v` van week 15. De stapteller `t` is weg en het ophalen (`F_PC_INC | F_IR_WE`) staat bij elke instructie tegelijk met de uitvoering aan.

```verilog
// FILE: cpu_pipe/control_p.v
// Besturing voor de gepijplijnde W8: geen stappen meer. In elke cyclus wordt tegelijk
// de volgende instructie opgehaald (pc_inc, ir_we) en de huidige uitgevoerd.
module control_p(
  input        clk,
  input        rst_n,
  input  [3:0] op,
  input  [2:0] cond,
  input        flag_z, flag_n, flag_c, flag_v,
  output       pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7,
  output       ra_sel, rb_sel, alu_ir, flags_we, mem_we,
  output [1:0] wb_sel, b_sel,
  output [2:0] alu_op,
  output       halted
);
  localparam OP_ALU = 4'h0, OP_LDI = 4'h1, OP_ADDI = 4'h2, OP_LD = 4'h3, OP_ST = 4'h4,
             OP_BCC = 4'h5, OP_CMP = 4'h6, OP_CMPI = 4'h7, OP_CALL = 4'h8, OP_JR = 4'h9,
             OP_HALT = 4'hF;

  localparam [19:0]
    F_PC_INC = 20'h00001, F_PC_LOAD = 20'h00002, F_PC_REG = 20'h00004, F_IR_WE = 20'h00008,
    F_REG_WE = 20'h00010, F_WA_R7 = 20'h00020, F_RA_RD = 20'h00040, F_RB_RD = 20'h00080,
    F_ALU_IR = 20'h00100, F_FLAGS = 20'h00200, F_MEM_WE = 20'h00400, F_COND = 20'h00800,
    F_WB_MEM = 20'h01000, F_WB_IMM = 20'h02000, F_WB_PC = 20'h03000,
    F_B_IMM = 20'h04000, F_B_OFF = 20'h08000, F_ALU_SUB = 20'h10000, F_HALT = 20'h80000;

  reg halt_r;
  reg [19:0] cw;

  always_comb begin
    cw = 20'h0;
    if (!halt_r) begin
      cw = F_PC_INC | F_IR_WE;                                     // ophalen gebeurt in elke cyclus
      case (op)
        OP_ALU:  cw = cw | F_ALU_IR | F_REG_WE | F_FLAGS;
        OP_LDI:  cw = cw | F_REG_WE | F_WB_IMM;
        OP_ADDI: cw = cw | F_RA_RD | F_B_IMM | F_REG_WE | F_FLAGS;
        OP_LD:   cw = cw | F_B_OFF | F_REG_WE | F_WB_MEM;
        OP_ST:   cw = cw | F_B_OFF | F_RB_RD | F_MEM_WE;
        OP_BCC:  cw = cw | F_PC_LOAD | F_COND;
        OP_CMP:  cw = cw | F_ALU_SUB | F_FLAGS;
        OP_CMPI: cw = cw | F_RA_RD | F_B_IMM | F_ALU_SUB | F_FLAGS;
        OP_CALL: cw = cw | F_PC_LOAD | F_REG_WE | F_WA_R7 | F_WB_PC;
        OP_JR:   cw = cw | F_PC_LOAD | F_PC_REG;
        OP_HALT: cw = cw | F_HALT;
        default: ;
      endcase
    end
  end

  reg cond_ok;
  always_comb begin
    case (cond)
      3'd0: cond_ok = 1'b1;
      3'd1: cond_ok = flag_z;
      3'd2: cond_ok = ~flag_z;
      3'd3: cond_ok = flag_c;
      3'd4: cond_ok = ~flag_c;
      3'd5: cond_ok = flag_n ^ flag_v;
      3'd6: cond_ok = ~(flag_n ^ flag_v);
      default: cond_ok = flag_n;
    endcase
  end

  always @(posedge clk or negedge rst_n)
    if (!rst_n) halt_r <= 1'b0;
    else if (cw[19]) halt_r <= 1'b1;

  assign pc_inc   = cw[0];
  assign pc_load  = cw[1] & (~cw[11] | cond_ok);
  assign pc_src   = cw[2];
  assign ir_we    = cw[3];
  assign reg_we   = cw[4];
  assign wa_r7    = cw[5];
  assign ra_sel   = cw[6];
  assign rb_sel   = cw[7];
  assign alu_ir   = cw[8];
  assign flags_we = cw[9];
  assign mem_we   = cw[10];
  assign wb_sel   = cw[13:12];
  assign b_sel    = cw[15:14];
  assign alu_op   = cw[18:16];
  assign halted   = halt_r;
endmodule
```

### Het toplevel met de flush

Hier staat de enige echt nieuwe regel: `ir_in = pc_load ? NOP : imem_dout`. Laat de besturing een sprong doorgaan, dan wordt de instructie die tegelijk uit het geheugen komt vervangen door een `NOP`.

```verilog
// FILE: cpu_pipe/cpu_p.v
// De gepijplijnde W8 (twee trappen: ophalen en uitvoeren). Hergebruikt het datapath ongewijzigd.
// Bij een genomen sprong is de instructie die intussen is opgehaald fout: die vervangen we door een NOP (flush).
module cpu_p #(
  parameter PROG = "prog.hex", parameter LOAD = 1,
  parameter DATA = "data.hex", parameter DLOAD = 0
) (
  input         clk,
  input         rst_n,
  output        halted,
  output [7:0]  pc_out,
  output [7:0]  r0, r1, r2, r3, r4, r5, r6, r7,
  output        flag_z, flag_n, flag_c, flag_v
);
  wire pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel, alu_ir, flags_we, mem_we;
  wire [1:0] wb_sel, b_sel;
  wire [2:0] alu_op, cond;
  wire [3:0] op;
  wire [7:0] imem_addr, dmem_addr, dmem_wdata, dmem_rdata;
  wire [15:0] imem_dout;

  // De flush: als de sprong doorgaat, wordt de zojuist opgehaalde instructie een NOP.
  wire [15:0] ir_in = pc_load ? 16'hA000 : imem_dout;

  datapath dp(
    .clk(clk), .rst_n(rst_n),
    .pc_inc(pc_inc), .pc_load(pc_load), .pc_src(pc_src), .ir_we(ir_we),
    .reg_we(reg_we), .wa_r7(wa_r7), .ra_sel(ra_sel), .rb_sel(rb_sel),
    .b_sel(b_sel), .alu_ir(alu_ir), .alu_op(alu_op), .wb_sel(wb_sel), .flags_we(flags_we),
    .imem_addr(imem_addr), .imem_dout(ir_in),
    .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata),
    .op(op), .cond(cond),
    .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v),
    .pc_out(pc_out), .r0(r0), .r1(r1), .r2(r2), .r3(r3), .r4(r4), .r5(r5), .r6(r6), .r7(r7)
  );

  control_p ctl(
    .clk(clk), .rst_n(rst_n), .op(op), .cond(cond),
    .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v),
    .pc_inc(pc_inc), .pc_load(pc_load), .pc_src(pc_src), .ir_we(ir_we),
    .reg_we(reg_we), .wa_r7(wa_r7), .ra_sel(ra_sel), .rb_sel(rb_sel),
    .alu_ir(alu_ir), .flags_we(flags_we), .mem_we(mem_we),
    .wb_sel(wb_sel), .b_sel(b_sel), .alu_op(alu_op), .halted(halted)
  );

  imem #(PROG, LOAD) im(imem_addr, imem_dout);
  dmem #(DATA, DLOAD) dm(clk, mem_we, dmem_addr, dmem_wdata, dmem_rdata);
endmodule
```

Dat is alles. Het datapath is niet aangeraakt.

## 6. Verificatie

### Dezelfde willekeurige test, met een aangepaste cyclusformule

We hergebruiken de willekeurige test uit week 16 met het referentiemodel. Registers, vlaggen en geheugen moeten identiek zijn aan wat het model voorspelt. Alleen de cyclustelling verandert:

```text
cycli = 1 (pipeline vullen) + aantal instructies + aantal genomen sprongen
```

Elke genomen `Bcc`, `CALL` en `JR` kost één verloren cyclus. De test controleert deze formule voor alle 300 programma's exact. Dat is een sterke controle, want het betekent dat het gedrag van de flush precies begrepen is.

```verilog
// FILE: cpu_pipe/tb_pipe_random.v
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
```

### De vergelijking op echte programma's

Dezelfde zes programma's uit week 17 draaien op beide CPU's, tegelijk, met een controle dat het resultaat identiek is:

```verilog
// FILE: cpu_pipe/tb_compare.v
// Draait hetzelfde programma op de W8 (twee cycli per instructie) en op de gepijplijnde W8P,
// controleert dat het eindresultaat identiek is en meet de cycli.
module pair #(parameter P = "", parameter D = "none", parameter DL = 0) (
  input         clk,
  input         rst_n,
  output        done,
  output reg [31:0] cyc_w,
  output reg [31:0] cyc_p,
  output reg    same
);
  wire hw, hp, wz, wn, wc, wv, pz, pn, pc_, pv;
  wire [7:0] wpc, w0, w1, w2, w3, w4, w5, w6, w7, ppc, p0, p1, p2, p3, p4, p5, p6, p7;
  cpu   #(P, 1, D, DL) w(clk, rst_n, hw, wpc, w0, w1, w2, w3, w4, w5, w6, w7, wz, wn, wc, wv);
  cpu_p #(P, 1, D, DL) p(clk, rst_n, hp, ppc, p0, p1, p2, p3, p4, p5, p6, p7, pz, pn, pc_, pv);
  assign done = hw & hp;

  initial begin cyc_w = 0; cyc_p = 0; end
  always @(posedge clk) if (rst_n) begin
    if (!hw) cyc_w <= cyc_w + 1;
    if (!hp) cyc_p <= cyc_p + 1;
  end

  integer k;
  always @* begin
    same = ({w0, w1, w2, w3, w4, w5, w6, w7} === {p0, p1, p2, p3, p4, p5, p6, p7})
        && ({wz, wn, wc, wv} === {pz, pn, pc_, pv});
    for (k = 0; k < 256; k = k + 1) if (w.dm.mem[k] !== p.dm.mem[k]) same = 0;
  end
endmodule

module tb_compare;
  reg clk = 0, rst_n = 0;
  wire [5:0] d;
  wire [31:0] cw0, cp0, cw1, cp1, cw2, cp2, cw3, cp3, cw4, cp4, cw5, cp5;
  wire [5:0] s;
  integer fouten = 0;
  pair #("sum.hex")                    a0(clk, rst_n, d[0], cw0, cp0, s[0]);
  pair #("mul.hex")                    a1(clk, rst_n, d[1], cw1, cp1, s[1]);
  pair #("sort.hex", "sort.dat", 1)    a2(clk, rst_n, d[2], cw2, cp2, s[2]);
  pair #("primes.hex")                 a3(clk, rst_n, d[3], cw3, cp3, s[3]);
  pair #("gcd.hex")                    a4(clk, rst_n, d[4], cw4, cp4, s[4]);
  pair #("calls.hex")                  a5(clk, rst_n, d[5], cw5, cp5, s[5]);
  always #5 clk = ~clk;

  task rapport(input [127:0] naam, input [31:0] w, input [31:0] p, input gelijk);
    begin
      $display("%0s  W8: %5d cycli   W8P: %5d cycli   versnelling %0d.%02d x   resultaat %0s",
               naam, w, p, (w * 100 / p) / 100, (w * 100 / p) % 100, gelijk ? "identiek" : "VERSCHILT");
      if (!gelijk) fouten = fouten + 1;
      if (!(p < w)) fouten = fouten + 1;
    end
  endtask

  initial begin
    #22 rst_n = 1;
    wait (&d);
    #20;
    rapport("som      ", cw0, cp0, s[0]);
    rapport("mul 16bit", cw1, cp1, s[1]);
    rapport("sorteren ", cw2, cp2, s[2]);
    rapport("priem    ", cw3, cp3, s[3]);
    rapport("ggd      ", cw4, cp4, s[4]);
    rapport("subroutine", cw5, cp5, s[5]);
    if (fouten == 0) $display("PASS: de gepijplijnde CPU geeft overal hetzelfde resultaat en is overal sneller");
    $finish;
  end
endmodule
```

De meting:

| Programma | W8 (cycli) | W8P (cycli) | Versnelling |
|-----------|-----------:|------------:|:-----------:|
| Som 1..10 | 66 | 43 | 1,53 × |
| 16-bit vermenigvuldigen | 190 | 115 | 1,65 × |
| Bubble sort | 564 | 324 | 1,74 × |
| Priemgetallen | 3596 | 2138 | 1,68 × |
| ggd | 60 | 39 | 1,53 × |
| Subroutines | 114 | 75 | 1,52 × |

De ideale versnelling zou 2,0 zijn. Waar zit het verschil? Neem de som van 1 tot 10: 33 instructies, waarvan 9 genomen sprongen, dus 1 + 33 + 9 = 43 cycli. Programma's met veel lussen en sprongen verliezen meer. De sorteerlus heeft relatief meer rekenwerk per sprong en haalt daarom een hogere versnelling.

## 7. Wat het niet oplost

Let op wat niet is veranderd: de klokperiode. De uitvoertrap van W8P bevat nog steeds het hele pad uit week 14: registers lezen, ALU, geheugen en terugschrijven. De klok kan dus niet sneller dan bij W8. We hebben de CPI verbeterd van 2 naar ongeveer 1,3, maar niet de frequentie.

Een echte snelle processor snijdt dat lange pad in stukken:

```text
 IF  |  ID + registers lezen  |  EX (ALU)  |  MEM  |  WB
```

Elke trap is dan veel korter en de klok kan veel sneller. De prijs is dat er data-hazards verschijnen (week 21).

```text
 tijd = instructies × CPI / frequentie
```

Pipelining kan aan beide kanten van de breuk helpen: de CPI omlaag (zoals hier) of de frequentie omhoog (met meer trappen). Moderne CPU's doen allebei.

## 8. Lab

1. Draai `tb_pipe_random.v` en `tb_compare.v`.
2. Open een golfvorm van het somprogramma op W8P en zoek het moment van de flush. Tel hoeveel cycli er verloren gaan.
3. Verander `cpu_p.v` zodat de flush niet plaatsvindt (`ir_in = imem_dout`). Welke test faalt en hoe?
4. Teken met de hand een tijdschema (cyclus × trap) voor de eerste vijf instructies van `gcd.asm`, met de flush bij elke genomen sprong.
5. Schrijf zelf een programma waar W8P weinig van profiteert (veel genomen sprongen) en een programma waarmee hij bijna een factor 2 haalt (bijna geen sprongen). Meet het met `tb_compare`.

## 9. Oefeningen

1. Een programma voert 1000 instructies uit, waarvan 150 genomen sprongen. Hoeveel cycli kost dat op W8 en op W8P? Wat is de versnelling?
2. Wat is de CPI van W8P bij een sprongfrequentie (genomen sprongen per instructie) van b? Leid een formule af.
3. Een programma is een rechte reeks van 100 instructies zonder sprongen. Wat is de versnelling van W8P?
4. Een vijftrapspipeline heeft de trappen IF 200 ps, ID 150 ps, EX 250 ps, MEM 300 ps en WB 100 ps (pipelineregisters kosten 20 ps). Wat is de klokperiode en wat is de ideale versnelling ten opzichte van één lange trap?
5. Waarom haalt de pipeline uit oefening 4 geen versnelling van 5? Welke trap splits je als eerste en wat wordt dan de klokperiode?
6. Op een vijftrapspipeline staan `ADD R1,R2,R3` en direct daarna `SUB R4,R1,R5`. Teken wanneer R1 beschikbaar is en welke forwarding nodig is.
7. Waarom werkt de pipeline van W8P niet meer als de leesactie van het datageheugen in een aparte trap zit, zonder extra maatregelen?
8. Uitdaging: voeg een derde trap toe aan W8P. De ALU-uitvoer wordt vastgelegd in een register en het terugschrijven en het geheugen gebeuren een cyclus later. Welke hazards ontstaan en hoe lost forwarding ze op?

## 10. Antwoorden

1. W8: 1000 × 2 = 2000 cycli. W8P: 1 + 1000 + 150 = 1151 cycli. De versnelling is 2000 / 1151 ≈ 1,74.
2. CPI(W8P) ≈ (instructies + genomen sprongen) / instructies = 1 + b, waarbij je de enkele vulcyclus verwaarloost. Bij b = 0,2 is de CPI 1,2 en de versnelling 2 / 1,2 ≈ 1,67.
3. W8: 200 cycli. W8P: 1 + 100 = 101 cycli. De versnelling is ongeveer 1,98, praktisch 2.
4. De klokperiode is de langzaamste trap plus de overhead: 300 + 20 = 320 ps. Zonder pipeline (alles in één cyclus) kost een instructie 200 + 150 + 250 + 300 + 100 = 1000 ps. De ideale versnelling is 1000 / 320 ≈ 3,1, en dus geen 5, omdat de trappen ongelijk lang zijn en de pipelineregisters tijd kosten.
5. De klok volgt de langzaamste trap (MEM, 300 ps). Splits je MEM in twee trappen van elk 150 ps, dan is EX de langzaamste trap (250 ps) en wordt de klokperiode 270 ps. Daarna is EX de volgende kandidaat om te splitsen.
6. De som is aan het einde van EX klaar (cyclus 3 voor `ADD`). `SUB` heeft R1 nodig aan het begin van zijn EX (cyclus 4). Forwarding stuurt de ALU-uitvoer van de vorige instructie in cyclus 4 rechtstreeks naar de ingang van de ALU, zonder te wachten op WB (cyclus 5).
7. Een `LD` gevolgd door een instructie die het geladen register meteen gebruikt, krijgt de waarde pas een trap later. Dan moet je één cyclus wachten (stall), ook met forwarding. Dit heet het load-gebruikprobleem.
8. Er ontstaat een data-hazard: de instructie na `ADD` ziet het resultaat nog niet in het registerbestand. De oplossing is forwarding van het ALU-uitgangsregister naar de ALU-ingangen, met vergelijkers die controleren of de bronregisters gelijk zijn aan de bestemming van de instructie ervoor. Na een `LD` blijft één stall nodig.

## 11. Zelftest

1. Wat doet pipelining met latentie en doorvoer?
2. Welke drie soorten hazards zijn er?
3. Waarom heeft de tweetraps W8P geen data-hazards?
4. Wat kost een genomen sprong in W8P?
5. Wat is forwarding?

Antwoorden: (1) De latentie van één instructie blijft gelijk of wordt iets langer, de doorvoer neemt toe. (2) Structureel, data en controle. (3) Registers worden aan het einde van EX geschreven en de volgende instructie leest pas in haar eigen EX. (4) Eén verloren cyclus (de flush). (5) Een resultaat direct van de ene trap naar de ingang van een andere sturen, zonder te wachten op het registerbestand.

## 12. Verder lezen

- Patterson en Hennessy, *Computer Organization and Design*, hoofdstuk 4 (de vijftrapspipeline).
- Harris en Harris, hoofdstuk 7.5 (de pipelineprocessor).
- Hennessy en Patterson, *Computer Architecture: A Quantitative Approach*, bijlage C (pipelining).

Volgende week: we bekijken de hazards in detail, bouwen een branch-predictorsimulator in Python en ontwerpen een cache in Verilog.
