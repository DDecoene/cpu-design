---
title: "Week 15 · De besturingseenheid en microcode"
---

<p class="subtitle">Fase 4 · Je eerste CPU · ongeveer 12 uur</p>

# Week 15: De besturingseenheid en microcode

## Wat je na deze week kunt

- uitleggen hoe de besturing een instructie in twee stappen uitvoert
- een controlewoord en een controlegeheugen (control store) ontwerpen
- het verschil uitleggen tussen hardwired en microgeprogrammeerde besturing
- de logica voor voorwaardelijke sprongen bouwen
- een nieuwe instructie toevoegen door één regel in het controlegeheugen te schrijven
- de complete W8-CPU samenvoegen en testen

## 1. De cyclus: ophalen en uitvoeren

Elke instructie van W8 duurt twee klokcycli. De besturing is een toestandsmachine (week 7) met één bit toestand, `t`:

| Stap | `t` | Wat gebeurt er |
|------|:---:|----------------|
| T0, ophalen | 0 | het instructieregister laadt de instructie op adres PC en de PC gaat 1 omhoog |
| T1, uitvoeren | 1 | het datapath doet wat de opcode vraagt |

```text
 klok:   ─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─
          └─┘ └─┘ └─┘ └─┘ └─┘ └─┘
 stap:   | T0 | T1 | T0 | T1 | T0 | T1 |
 instr.: |  instructie 1  |  instructie 2  | ...
```

De PC gaat al in T0 omhoog. Daardoor staat tijdens T1 in de PC het adres van de volgende instructie. Dat is precies wat `CALL` als terugkeeradres nodig heeft, en een sprong overschrijft die waarde gewoon.

De uitgangen van deze toestandsmachine zijn de 13 besturingssignalen van het datapath. De vraag is hoe we ze berekenen.

## 2. Het controlewoord

Voor elke combinatie van (opcode, stap) moet je kiezen welke signalen aan staan. Dat is een tabel, en tabellen kennen we: een ROM (week 8). We bundelen alle signalen in één controlewoord van 20 bit:

| Bit | Signaal | Bit | Signaal |
|:---:|---------|:---:|---------|
| 0 | `pc_inc` | 10 | `mem_we` |
| 1 | `pc_load` | 11 | `cc` (laden alleen als de voorwaarde klopt) |
| 2 | `pc_src` | 12-13 | `wb_sel` |
| 3 | `ir_we` | 14-15 | `b_sel` |
| 4 | `reg_we` | 16-18 | `alu_op` |
| 5 | `wa_r7` | 19 | `halt` |
| 6 | `ra_sel` | | |
| 7 | `rb_sel` | | |
| 8 | `alu_ir` | | |
| 9 | `flags_we` | | |

Het controlegeheugen:

| Opcode | Stap T0 | Stap T1 (uitvoeren) |
|--------|---------|---------------------|
| ALU | `pc_inc`, `ir_we` | `alu_ir`, `reg_we`, `flags_we` |
| LDI | idem | `reg_we`, `wb_sel`=imm |
| ADDI | idem | `ra_sel`, `b_sel`=imm, `reg_we`, `flags_we` |
| LD | idem | `b_sel`=off, `reg_we`, `wb_sel`=mem |
| ST | idem | `b_sel`=off, `rb_sel`, `mem_we` |
| Bcc | idem | `pc_load`, `cc` |
| CMP | idem | `alu_op`=SUB, `flags_we` |
| CMPI | idem | `ra_sel`, `b_sel`=imm, `alu_op`=SUB, `flags_we` |
| CALL | idem | `pc_load`, `reg_we`, `wa_r7`, `wb_sel`=PC |
| JR | idem | `pc_load`, `pc_src` |
| HALT | idem | `halt` |
| NOP, vrij | idem | (niets) |

Dit is het hele brein van de CPU. Het past op één pagina.

## 3. Hardwired of microcode?

| | Hardwired | Microgeprogrammeerd |
|--|-----------|---------------------|
| Hoe | poorten en een toestandsmachine, met de hand geoptimaliseerd | een ROM met controlewoorden, plus een teller |
| Snelheid | sneller | iets trager (ROM-toegang) |
| Aanpassen | de hardware wijzigen | de ROM-inhoud wijzigen |
| Complexe instructies | moeilijk | eenvoudig: meerdere microstappen |
| Typisch voor | RISC-chips | CISC-chips, zoals x86 en de IBM System/360 |

IBM voerde in de jaren zestig microcode in om één ISA op veel verschillende machines te kunnen aanbieden. Intel gebruikt het nog steeds. Moderne Intel-chips krijgen microcode-updates die bugs in de CPU repareren zonder nieuwe hardware. Dat is de kracht van het idee: de besturing is data.

De W8-besturing is een klein controlegeheugen. In Verilog schrijven we het als een `case`, die de synthesetool op eigen wijze uitrolt (als ROM of als poorten). Op een breadboard zou je er een echte EEPROM voor gebruiken, zoals Ben Eater.

## 4. De besturingseenheid in Verilog

```verilog
// FILE: cpu/control.v
// De besturingseenheid: een controlegeheugen (control store) dat voor elke combinatie
// van (opcode, stap) een controlewoord oplevert. Stap 0 = ophalen, stap 1 = uitvoeren.
module control(
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
  // Opcodes
  localparam OP_ALU = 4'h0, OP_LDI = 4'h1, OP_ADDI = 4'h2, OP_LD = 4'h3, OP_ST = 4'h4,
             OP_BCC = 4'h5, OP_CMP = 4'h6, OP_CMPI = 4'h7, OP_CALL = 4'h8, OP_JR = 4'h9,
             OP_HALT = 4'hF;

  // Bitposities in het controlewoord
  localparam [19:0]
    F_PC_INC   = 20'h00001,
    F_PC_LOAD  = 20'h00002,
    F_PC_REG   = 20'h00004,
    F_IR_WE    = 20'h00008,
    F_REG_WE   = 20'h00010,
    F_WA_R7    = 20'h00020,
    F_RA_RD    = 20'h00040,
    F_RB_RD    = 20'h00080,
    F_ALU_IR   = 20'h00100,
    F_FLAGS    = 20'h00200,
    F_MEM_WE   = 20'h00400,
    F_COND     = 20'h00800,          // laad de PC alleen als de voorwaarde klopt
    F_WB_MEM   = 20'h01000,          // wb_sel = 1
    F_WB_IMM   = 20'h02000,          // wb_sel = 2
    F_WB_PC    = 20'h03000,          // wb_sel = 3
    F_B_IMM    = 20'h04000,          // b_sel = 1
    F_B_OFF    = 20'h08000,          // b_sel = 2
    F_ALU_SUB  = 20'h10000,          // alu_op = 1
    F_HALT     = 20'h80000;

  reg t;                             // 0 = ophalen, 1 = uitvoeren
  reg halt_r;
  reg [19:0] cw;

  // Het controlegeheugen zelf: opcode en stap in, controlewoord uit.
  always_comb begin
    cw = 20'h0;
    if (!halt_r) begin
      if (t == 1'b0) cw = F_PC_INC | F_IR_WE;                    // ophalen: voor alle instructies gelijk
      else case (op)
        OP_ALU:  cw = F_ALU_IR | F_REG_WE | F_FLAGS;             // rd = rs1 <fn> rs2
        OP_LDI:  cw = F_REG_WE | F_WB_IMM;                       // rd = imm8
        OP_ADDI: cw = F_RA_RD | F_B_IMM | F_REG_WE | F_FLAGS;    // rd = rd + imm8
        OP_LD:   cw = F_B_OFF | F_REG_WE | F_WB_MEM;             // rd = mem[rs1 + off6]
        OP_ST:   cw = F_B_OFF | F_RB_RD | F_MEM_WE;              // mem[rs1 + off6] = rd
        OP_BCC:  cw = F_PC_LOAD | F_COND;                        // if cond: PC = imm8
        OP_CMP:  cw = F_ALU_SUB | F_FLAGS;                       // vlaggen van rs1 - rs2
        OP_CMPI: cw = F_RA_RD | F_B_IMM | F_ALU_SUB | F_FLAGS;   // vlaggen van rd - imm8
        OP_CALL: cw = F_PC_LOAD | F_REG_WE | F_WA_R7 | F_WB_PC;  // R7 = PC; PC = imm8
        OP_JR:   cw = F_PC_LOAD | F_PC_REG;                      // PC = rs1
        OP_HALT: cw = F_HALT;
        default: cw = 20'h0;                                     // NOP en ongebruikte opcodes
      endcase
    end
  end

  // Voorwaarde-evaluatie
  reg cond_ok;
  always_comb begin
    case (cond)
      3'd0: cond_ok = 1'b1;              // AL  altijd
      3'd1: cond_ok = flag_z;                // EQ
      3'd2: cond_ok = ~flag_z;               // NE
      3'd3: cond_ok = flag_c;                // CS  (A >= B zonder teken na CMP)
      3'd4: cond_ok = ~flag_c;               // CC  (A <  B zonder teken)
      3'd5: cond_ok = flag_n ^ flag_v;           // LT  (met teken)
      3'd6: cond_ok = ~(flag_n ^ flag_v);        // GE  (met teken)
      default: cond_ok = flag_n;             // MI  negatief
    endcase
  end

  // Stap en halt-vlag
  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin t <= 1'b0; halt_r <= 1'b0; end
    else if (!halt_r) begin
      t <= ~t;
      if (cw[19]) halt_r <= 1'b1;
    end

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

Lees het rustig door. De localparams `F_...` geven elke bit een naam, dus een controlewoord als `F_REG_WE | F_WB_IMM` leest als gewoon Nederlands. De `case` is het controlegeheugen: het ontwerp van de CPU staat in die tien regels. `cond_ok` evalueert de acht voorwaarden uit de tabel van week 13 tegen de vlaggen. In `pc_load = cw[1] & (~cw[11] | cond_ok)` gaat een sprong door als hij onvoorwaardelijk is (`cw[11] = 0`) of als de voorwaarde klopt. En `halt_r` zorgt dat de toestandsmachine na `HALT` stopt en het controlewoord 0 wordt, zodat er niets meer verandert.

> **Een valkuil in simulatie: `always_comb` of `always @*`?** Een `always @*`-blok draait alleen als een van zijn ingangen verandert. Hebben `cond` en de vlaggen vanaf tijd nul al hun beginwaarde en veranderen ze nooit, dan draait het blok nooit en blijft de uitgang (hier `cond_ok`) op X staan, ook al is het ontwerp correct. `always_comb` (SystemVerilog) draait één keer bij tijd nul. Echte hardware heeft dit probleem niet, het is een eigenaardigheid van de simulatie. Als je het niet kent, kost het je uren. Gebruik daarom `always_comb` voor combinatorische logica.

## 5. De CPU: alles samen

Het toplevel verbindt datapath, besturing en geheugens:

```verilog
// FILE: cpu/cpu.v
// De complete CPU: datapath + besturing + geheugens.
module cpu #(
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

  datapath dp(
    .clk(clk), .rst_n(rst_n),
    .pc_inc(pc_inc), .pc_load(pc_load), .pc_src(pc_src), .ir_we(ir_we),
    .reg_we(reg_we), .wa_r7(wa_r7), .ra_sel(ra_sel), .rb_sel(rb_sel),
    .b_sel(b_sel), .alu_ir(alu_ir), .alu_op(alu_op), .wb_sel(wb_sel), .flags_we(flags_we),
    .imem_addr(imem_addr), .imem_dout(imem_dout),
    .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata),
    .op(op), .cond(cond),
    .flag_z(flag_z), .flag_n(flag_n), .flag_c(flag_c), .flag_v(flag_v),
    .pc_out(pc_out), .r0(r0), .r1(r1), .r2(r2), .r3(r3), .r4(r4), .r5(r5), .r6(r6), .r7(r7)
  );

  control ctl(
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

Dit is de hele machine. Er zijn vijf modules: `alu`, `idecode`, `datapath`, `control` en de geheugens `imem` en `dmem`. De ingewikkelde dingen zitten in de details van elk onderdeel, het geheel is overzichtelijk.

## 6. De test van de besturing

De testbench controleert voor elke opcode de uitvoerstap tegen de tabel van paragraaf 2, de ophaalstap voor alle opcodes, alle 128 combinaties van voorwaarde en vlaggen en het gedrag van `HALT`.

```verilog
// FILE: cpu/tb_control.v
module tb_control;
  reg clk = 0, rst_n = 1;          // begint hoog; elke test geeft zelf een resetpuls (dalende flank)
  reg [3:0] op = 0;
  reg [2:0] cond = 0;
  reg fz = 0, fn = 0, fc = 0, fv = 0;
  wire pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel, alu_ir, flags_we, mem_we, halted;
  wire [1:0] wb_sel, b_sel;
  wire [2:0] alu_op;
  integer fouten = 0, i, f;

  control dut(clk, rst_n, op, cond, fz, fn, fc, fv,
              pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel, alu_ir, flags_we, mem_we,
              wb_sel, b_sel, alu_op, halted);
  always #5 clk = ~clk;

  // Alle besturingssignalen als één vector, in vaste volgorde.
  wire [18:0] signalen = {pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel,
                          alu_ir, flags_we, mem_we, wb_sel, b_sel, alu_op};

  function [18:0] w(input pi, pl, ps, iw, rw, w7, ras, rbs, ai, fw, mw,
                    input [1:0] wb, bs, input [2:0] ao);
    w = {pi, pl, ps, iw, rw, w7, ras, rbs, ai, fw, mw, wb, bs, ao};
  endfunction

  // Verwachte uitvoerstap per opcode (uit de tabel in de cursus).
  task check_op(input [3:0] o, input [18:0] verwacht, input [255:0] naam);
    begin
      rst_n = 0; #1; rst_n = 1;
      op = o; cond = 3'd0;             // voorwaarde 'altijd'
      #1;
      if (signalen !== w(1,0,0,1,0,0,0,0,0,0,0,0,0,0)) begin fouten = fouten + 1; $display("FAIL %0s: ophaalstap = %b", naam, signalen); end
      @(posedge clk); #1;              // naar stap 1: uitvoeren
      if (signalen !== verwacht) begin fouten = fouten + 1; $display("FAIL %0s: uitvoerstap = %b, verwacht %b", naam, signalen, verwacht); end
    end
  endtask

  function cond_ref(input [2:0] c, input z, n, cy, v);
    case (c)
      0: cond_ref = 1;      1: cond_ref = z;        2: cond_ref = !z;      3: cond_ref = cy;
      4: cond_ref = !cy;    5: cond_ref = n ^ v;    6: cond_ref = !(n ^ v); default: cond_ref = n;
    endcase
  endfunction

  initial begin
    //                 pi pl ps iw rw w7 ra rb ai fw mw wb  bs  alu_op
    check_op(4'h0, w(0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0), "ALU");
    check_op(4'h1, w(0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 0, 0), "LDI");
    check_op(4'h2, w(0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0), "ADDI");
    check_op(4'h3, w(0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 2, 0), "LD");
    check_op(4'h4, w(0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 2, 0), "ST");
    check_op(4'h6, w(0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1), "CMP");
    check_op(4'h7, w(0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1), "CMPI");
    check_op(4'h8, w(0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 3, 0, 0), "CALL");
    check_op(4'h9, w(0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), "JR");
    check_op(4'hA, w(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), "NOP");
    check_op(4'hC, w(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), "ongebruikt");

    // Voorwaardelijke sprong: alle 8 voorwaarden x alle 16 vlaggencombinaties.
    for (i = 0; i < 8; i = i + 1)
      for (f = 0; f < 16; f = f + 1) begin
        rst_n = 0; #1; rst_n = 1;
        op = 4'h5; cond = i; {fz, fn, fc, fv} = f; @(posedge clk); #1;
        if (pc_load !== cond_ref(i, fz, fn, fc, fv)) begin
          fouten = fouten + 1; $display("FAIL Bcc cond=%0d vlaggen=%b: pc_load=%b", i, f[3:0], pc_load);
        end
      end

    // HALT: na de uitvoerstap staat halted aan en doet de besturing niets meer.
    rst_n = 0; #1; rst_n = 1; op = 4'hF;
    @(posedge clk); #1;
    @(posedge clk); #1;
    if (halted !== 1'b1) begin fouten = fouten + 1; $display("FAIL: halted niet gezet"); end
    if (signalen !== 19'b0) begin fouten = fouten + 1; $display("FAIL: besturing blijft actief na HALT"); end
    @(posedge clk); #1;
    if (signalen !== 19'b0 || !halted) begin fouten = fouten + 1; $display("FAIL: HALT niet blijvend"); end

    if (fouten == 0) $display("PASS: besturingseenheid levert voor elke opcode de juiste signalen");
    $finish;
  end
endmodule
```

Draai:

```text
cd labs/cpu
iverilog -g2012 -o ctl.vvp tb_control.v control.v
vvp ctl.vvp
```

## 7. Lab: voeg een instructie toe

Dit is het mooie van microcode: een nieuwe instructie is vaak maar één regel. Voeg `SKIP` toe, een instructie die de eerstvolgende instructie overslaat (handig voor korte voorwaardelijke stukjes).

1. Kies een vrije opcode: 0xE. (De opcodes B, C en D worden in week 22 gebruikt voor interrupts.)
2. Voeg in `control.v` `OP_SKIP = 4'hE` toe aan de localparams en in de `case` een regel:
   ```text
   OP_SKIP: cw = F_PC_INC;      // de PC gaat nog een keer omhoog
   ```
3. Test met een programma: `LDI R1,1` / `SKIP` / `LDI R1,2` / `HALT`. R1 moet daarna 1 zijn.

Meer is het niet. Je hebt geen nieuwe hardware nodig, alleen een nieuwe regel in het controlegeheugen. Schrijf de testbench zelf met de `I_...`-functies uit week 13 (het woord voor `SKIP` is `16'hE000`).

## 8. Oefeningen

1. Bereken het controlewoord voor de uitvoerstap van `ADDI` als hexadecimaal getal, met de waarden van de `F_...`-constanten uit `control.v`.
2. Hoeveel bits is het controlegeheugen als ROM (16 opcodes × 2 stappen × 20 bits)? Hoeveel 8-bit EEPROM's heb je nodig voor een breadboardversie?
3. Voeg `SKIP` toe en test het. Schrijf de testbench.
4. Waarom wordt de PC al in T0 verhoogd en niet in T1?
5. Waarom heeft `HALT` een eigen register `halt_r` nodig? Kon het niet gewoon met `t`?
6. Stel dat het instructiegeheugen synchroon leest (zoals blok-RAM in een FPGA): de uitvoer verschijnt een klokflank na het adres. Wat moet je aan de besturing veranderen?
7. Wat gebeurt er als een programma een van de nog ongebruikte opcodes (B tot en met E) tegenkomt? Is dat gewenst? Hoe vang je het af?
8. Uitdaging: maak de besturing driecyclisch voor `LD` (ophalen, adres berekenen, geheugen lezen en naar het register schrijven), met een tussenregister voor het adres. Wat moet je aan het datapath toevoegen?

## 9. Antwoorden

1. `F_RA_RD` (0x00040) + `F_B_IMM` (0x04000) + `F_REG_WE` (0x00010) + `F_FLAGS` (0x00200) = 0x04250.
2. 32 woorden × 20 bit = 640 bit (80 byte). Met 8-bit EEPROM's heb je er 3 nodig (24 bit, waarvan 20 gebruikt). Veel ontwerpers gebruiken een EEPROM met een grotere adresruimte en spreiden de woorden, maar het aantal chips blijft 3 voor de breedte.
3. Zie paragraaf 7. Controle: R1 is 1 na afloop.
4. Dan is de PC al goed (de volgende instructie) tijdens T1. Een sprong overschrijft hem, en `CALL` kan hem direct als terugkeeradres bewaren. Er is ook geen aparte "PC+1"-opteller nodig tijdens T1.
5. Omdat `t` altijd blijft wisselen. `HALT` moet de machine blijvend stoppen, en daarvoor is een eigen geheugen (`halt_r`) nodig.
6. De instructie is dan niet meer in dezelfde cyclus beschikbaar. Je kunt een extra ophaalcyclus toevoegen (drie stappen per instructie), of het instructieregister zelf het uitgangsregister van het geheugen laten zijn. In beide gevallen verschuift de stap waarop het IR geldig is.
7. Ze gedragen zich als `NOP`. Dat is veilig, maar kan fouten maskeren. Beter is een signaal "illegale instructie" dat de CPU laat stoppen of een foutvlag zet, zodat een bug zichtbaar wordt.
8. Een adresregister (MAR) dat het ALU-resultaat bewaart tussen stap 2 en 3. Stap 3 gebruikt dat register als geheugenadres. De besturing krijgt een extra toestand en het controlegeheugen een derde kolom.

## 10. Zelftest

1. Wat doet de besturing in stap T0?
2. Wat is een controlewoord?
3. Wat is het voordeel van microcode?
4. Waarom is `HALT` blijvend?
5. Waarom verhogen we de PC in T0?

Antwoorden: (1) Het instructieregister laden en de PC ophogen. (2) Een bitvector die voor één klokcyclus alle besturingssignalen vastlegt. (3) Je past gedrag aan door data te veranderen, niet hardware, en complexe instructies zijn eenvoudig. (4) Zijn eigen register `halt_r` houdt de stop vast. (5) Dan staat het adres van de volgende instructie klaar voor `CALL`, en sprongen hoeven niets bijzonders te doen.

## 11. Verder lezen

- Harris en Harris, 7.4 (multicyclusprocessor) en 7.7 (microprogrammering).
- Ben Eater: de video's over microcode en over het bouwen van een EEPROM-programmer. Zo programmeer je een controlegeheugen echt.
- Het verhaal van Maurice Wilkes, die microprogrammering in 1951 bedacht.

Volgende week hebben we alle onderdelen. Tijd om de CPU echte programma's te laten draaien en zijn gedrag grondig te controleren.
