---
title: "Week 14 · Het datapath"
---

<p class="subtitle">Fase 4 · Je eerste CPU · ongeveer 12 uur</p>

# Week 14: Het datapath

## Wat je na deze week kunt

- het verschil uitleggen tussen datapath en besturing
- uit een ISA afleiden welke hardware en welke verbindingen een CPU nodig heeft
- een datapath in Verilog bouwen met PC, instructieregister, registerbestand, ALU en vlaggen
- het datapath testen door zelf de besturing te spelen
- het kritieke pad en daarmee de maximale kloksnelheid schatten

## 1. Twee helften: datapath en besturing

Elke CPU bestaat uit twee delen:

| Deel | Taak | Bestaat uit |
|------|------|-------------|
| Datapath | de spieren: slaat gegevens op, verplaatst en bewerkt ze | registers, ALU, multiplexers, geheugens |
| Besturing | het brein: zegt per klokcyclus wat het datapath moet doen | een toestandsmachine met een controlegeheugen |

Het datapath heeft besturingssignalen als ingang (bijvoorbeeld "schrijf naar een register" of "kies de bron voor de ALU") en statussignalen als uitgang (de opcode en de vlaggen). De besturing leest die status en berekent de signalen. Deze week bouwen we het datapath en volgende week de besturing.

## 2. Wat heeft W8 nodig? Van ISA naar hardware

Loop de instructies langs en schrijf op welke middelen ze gebruiken:

| Instructie | Leest | Rekent | Schrijft |
|------------|-------|--------|----------|
| `ADD rd, rs1, rs2` | 2 registers | ALU (fn uit de instructie) | register + vlaggen |
| `LDI rd, imm` | de instructie zelf | niets | register |
| `ADDI rd, imm` | register rd + imm | ALU: optellen | register + vlaggen |
| `LD rd, [rs1+off]` | register rs1 + off, geheugen | ALU: optellen (adres) | register |
| `ST rd, [rs1+off]` | register rs1 + off, register rd | ALU: optellen (adres) | geheugen |
| `Bcc adres` | vlaggen, imm | niets | PC |
| `CMP rs1, rs2` | 2 registers | ALU: aftrekken | alleen vlaggen |
| `CMPI rd, imm` | register rd + imm | ALU: aftrekken | alleen vlaggen |
| `CALL adres` | PC, imm | niets | R7 en PC |
| `JR rs1` | register rs1 | niets | PC |

Hieruit volgt wat het datapath moet bevatten:

- een registerbestand met twee leespoorten (A en B) en één schrijfpoort
- één ALU
- een programmateller (PC) die kan ophogen of laden, en een instructieregister (IR)
- een vlaggenregister
- multiplexers voor: welk register wordt gelezen, wat gaat de ALU in en wat wordt teruggeschreven

Elke instructie gebruikt dezelfde onderdelen op een andere manier. Dat maakt een datapath wat het is: gemeenschappelijke hardware, aangestuurd door signalen.

## 3. Het blokschema

```text
 OPHALEN
          ┌────────── PC + 1 (pc_inc)  of doeladres (pc_load) ──────────┐
          ▼                                                             │
    ┌──────────┐  adres   ┌────────┐  16 bit   ┌────────────┐           │
    │    PC    ├─────────►│  IMEM  ├──────────►│     IR     │           │
    └──────────┘          └────────┘  (ir_we)  └─────┬──────┘           │
                                                     │                  │
                    velden uit het IR: op, rd, rs1, rs2, fn, imm8, off6 │
                                                                        │
 UITVOEREN                                                              │
    rs1 of rd (ra_sel) ─►┌──────────────────┐                           │
                         │   REGISTER-      ├──► A ─────────────────────┘  (doeladres bij JR)
    rs2 of rd (rb_sel) ─►│   BESTAND 8 × 8  ├──► B ─────┐
                         └────────▲─────────┘           ▼
                      reg_we,     │            ┌────────────────┐
                      wa_r7       │            │ MUX (b_sel):   │◄── imm8 of off6
                                  │            │ B / imm8 / off6│
                                  │            └───────┬────────┘
                                  │      A ───►┌───────▼────────┐
                                  │            │      ALU       ├──► vlaggen Z N C V
                                  │            └───────┬────────┘
                                  │                    │ Y
                                  │                    ├──────────► DMEM-adres
                                  │                    ▼
                                  │            ┌────────────────┐
                                  │            │      DMEM      │◄── B (data bij ST), mem_we
                                  │            └───────┬────────┘
                                  │                    │ lees
                                  │   wb_sel           ▼
                                  └───◄── terugschrijven: Y / DMEM / imm8 / PC
```

Lees het zo: bovenin haalt de CPU de instructie op en onderin voert hij hem uit. De instructie in het IR bepaalt via de velden welke registers en constanten de onderste helft gebruikt.

## 4. De besturingssignalen

Het datapath heeft 13 besturingssignalen (17 bits in totaal, want sommige zijn breder dan één bit). Elk heeft één taak:

| Signaal | Bits | Betekenis |
|---------|:----:|-----------|
| `pc_inc` | 1 | PC <= PC + 1 |
| `pc_load` | 1 | PC <= doeladres |
| `pc_src` | 1 | doeladres: 0 = imm8 uit de instructie, 1 = register A (voor `JR`) |
| `ir_we` | 1 | laad het instructieregister met de instructie uit het geheugen |
| `reg_we` | 1 | schrijf naar het registerbestand |
| `wa_r7` | 1 | schrijfadres: 0 = rd, 1 = vast R7 (voor `CALL`) |
| `ra_sel` | 1 | leespoort A: 0 = rs1, 1 = rd |
| `rb_sel` | 1 | leespoort B: 0 = rs2, 1 = rd |
| `b_sel` | 2 | ALU-ingang B: 0 = register B, 1 = imm8, 2 = off6 |
| `alu_ir` | 1 | ALU-bewerking uit het `fn`-veld (1) of uit `alu_op` (0) |
| `alu_op` | 3 | de ALU-bewerking als `alu_ir` = 0 |
| `wb_sel` | 2 | terugschrijven: 0 = ALU-uitkomst, 1 = geheugen, 2 = imm8, 3 = PC |
| `flags_we` | 1 | vlaggenregister bijwerken |

Het geheugen heeft een eigen schrijfsignaal, `mem_we`, dat de besturing rechtstreeks aan het datageheugen koppelt.

### Waarom al die multiplexers?

Ze lossen conflicten tussen instructies op:

- `ST rd, [rs1+off]` moet het register `rd` als data lezen, maar poort B leest normaal `rs2`, en die bits zijn bij `ST` een deel van de offset. Daarom is er `rb_sel`.
- `ADDI rd, imm` moet `rd` als eerste operand lezen in plaats van `rs1`. Daarom is er `ra_sel`.
- `LDI` wil geen ALU-resultaat terugschrijven maar de constante zelf. Daarom heeft `wb_sel` een imm8-ingang.
- `CALL` schrijft naar een vast register. Daarom is er `wa_r7`.

Een goed ISA-ontwerp probeert het aantal van zulke uitzonderingen klein te houden, want elke multiplexer kost poorten en vertraging.

## 5. De geheugens

We hergebruiken de ALU uit week 11 (kopieer hem) en voegen twee kleine geheugenmodules toe: het instructiegeheugen en het datageheugen.

<!-- COPY week11/alu.v cpu/alu.v -->

Kopieer `labs/week11/alu.v` naar `labs/cpu/alu.v`. Het is dezelfde ALU, onveranderd. Dat is het voordeel van een goed ontworpen en grondig geteste module: je kunt hem gewoon hergebruiken.

```verilog
// FILE: cpu/memories.v
// Instructiegeheugen: 256 woorden van 16 bit, asynchroon lezen, gevuld uit een hex-bestand.
module imem #(parameter FILE = "prog.hex", parameter LOAD = 1) (
  input  [7:0]  addr,
  output [15:0] dout
);
  reg [15:0] mem [0:255];
  integer i;
  initial begin
    if (LOAD) $readmemh(FILE, mem);                       // het bestand moet alle 256 woorden bevatten
    else for (i = 0; i < 256; i = i + 1) mem[i] = 16'hA000;   // anders alles NOP
  end
  assign dout = mem[addr];
endmodule

// Datageheugen: 256 bytes, synchroon schrijven, asynchroon lezen.
module dmem #(parameter FILE = "data.hex", parameter LOAD = 0) (
  input        clk,
  input        we,
  input  [7:0] addr,
  input  [7:0] din,
  output [7:0] dout
);
  reg [7:0] mem [0:255];
  integer i;
  initial begin
    if (LOAD) $readmemh(FILE, mem);
    else for (i = 0; i < 256; i = i + 1) mem[i] = 8'h00;
  end
  assign dout = mem[addr];
  always @(posedge clk)
    if (we) mem[addr] <= din;
endmodule
```

Let op twee dingen. `imem` is een ROM met een hex-bestand (`LOAD` bepaalt of het bestand geladen wordt, want testbenches schrijven soms liever rechtstreeks). Leeg geheugen is gevuld met `NOP` (`0xA000`), zodat een verdwaalde PC niets kwaads doet. En `dmem` leest asynchroon (zodra het adres verandert, verandert de uitgang) en schrijft synchroon op de klokflank. Zo kan een `LD` binnen één cyclus een waarde teruggeven.

## 6. Het datapath in Verilog

```verilog
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
```

Neem de tijd om dit stuk voor stuk door te lezen. Het is de eerste module in de cursus waarin alle onderdelen samenkomen.

- De regel `wire [7:0] rega = r[ra_sel ? rd : rs1]` is een 8:1 multiplexer (het registerbestand) achter een 2:1 multiplexer (die het adres kiest). Twee regels, twee multiplexers.
- De `wdata`-mux kiest tussen vier bronnen.
- Het `always`-blok is het enige klokgestuurde deel. Alles wat onthouden wordt (PC, IR, vlaggen en registers) verandert alleen op de stijgende flank, en alleen als zijn schrijfsignaal aan staat.
- `pc_load` heeft voorrang boven `pc_inc`. Bij het ophalen staat `pc_inc` aan en bij een sprong tijdens het uitvoeren `pc_load`.
- De uitgangen `r0 ... r7` zijn alleen voor het debuggen. In hardware kosten ze niets.

## 7. De test: wij spelen de besturing

Voordat we de echte besturing bouwen, testen we het datapath zelf. De testbench zet per klokcyclus de besturingssignalen, precies zoals de besturing straks zal doen. Zo test je het datapath los van de besturing en leer je meteen wat die laatste moet doen.

```verilog
// FILE: cpu/tb_datapath.v
`include "asm_funcs.vh"
// We spelen zelf "besturingseenheid": we zetten de besturingssignalen per klokcyclus.
module tb_datapath;
  reg clk = 0, rst_n = 0;
  reg pc_inc = 0, pc_load = 0, pc_src = 0, ir_we = 0, reg_we = 0, wa_r7 = 0;
  reg ra_sel = 0, rb_sel = 0, alu_ir = 0, flags_we = 0, mem_we = 0;
  reg [1:0] b_sel = 0, wb_sel = 0;
  reg [2:0] alu_op = 0;

  wire [7:0]  imem_addr, dmem_addr, dmem_wdata, dmem_rdata, pc;
  wire [15:0] imem_dout;
  wire [3:0]  op;
  wire [2:0]  cond;
  wire        fz, fn, fc, fv;
  wire [7:0]  r0, r1, r2, r3, r4, r5, r6, r7;
  integer fouten = 0, k;

  imem #("none", 0) im(imem_addr, imem_dout);
  dmem dm(clk, mem_we, dmem_addr, dmem_wdata, dmem_rdata);
  datapath dp(clk, rst_n, pc_inc, pc_load, pc_src, ir_we, reg_we, wa_r7, ra_sel, rb_sel,
              b_sel, alu_ir, alu_op, wb_sel, flags_we,
              imem_addr, imem_dout, dmem_addr, dmem_wdata, dmem_rdata,
              op, cond, fz, fn, fc, fv, pc, r0, r1, r2, r3, r4, r5, r6, r7);
  always #5 clk = ~clk;

  // Eén klokcyclus met de huidige besturingssignalen; daarna alles weer uit.
  task tick;
    begin
      @(posedge clk); #1;
      pc_inc = 0; pc_load = 0; pc_src = 0; ir_we = 0; reg_we = 0; wa_r7 = 0;
      ra_sel = 0; rb_sel = 0; alu_ir = 0; flags_we = 0; mem_we = 0;
      b_sel = 0; wb_sel = 0; alu_op = 0;
    end
  endtask

  task fetch;                      // stap 0: haal de instructie op
    begin @(negedge clk); pc_inc = 1; ir_we = 1; tick; end
  endtask

  task expect8(input [7:0] actual, input [7:0] verwacht, input [255:0] naam);
    if (actual !== verwacht) begin fouten = fouten + 1; $display("FAIL %0s: %0d i.p.v. %0d", naam, actual, verwacht); end
  endtask

  initial begin
    for (k = 0; k < 256; k = k + 1) begin im.mem[k] = I_NOP; dm.mem[k] = 0; end
    im.mem[0] = I_LDI(1, 5);
    im.mem[1] = I_LDI(2, 7);
    im.mem[2] = I_ALU(F_ADD, 3, 1, 2);
    im.mem[3] = I_ST(3, 0, 9);
    im.mem[4] = I_LD(4, 0, 9);
    im.mem[5] = I_CMP(3, 4);
    im.mem[6] = I_CALL(8'd20);
    im.mem[20] = I_JR(7);

    #12 rst_n = 1;

    // LDI R1,5: ophalen, dan uitvoeren (wb = imm8)
    fetch; @(negedge clk); reg_we = 1; wb_sel = 2; tick;
    expect8(r1, 5, "LDI R1");
    // LDI R2,7
    fetch; @(negedge clk); reg_we = 1; wb_sel = 2; tick;
    expect8(r2, 7, "LDI R2");
    // ADD R3,R1,R2: alu_op komt uit de instructie, vlaggen bijwerken
    fetch; @(negedge clk); alu_ir = 1; reg_we = 1; flags_we = 1; tick;
    expect8(r3, 12, "ADD R3");
    if ({fz, fn, fc, fv} !== 4'b0000) begin fouten = fouten + 1; $display("FAIL vlaggen na ADD: %b%b%b%b", fz, fn, fc, fv); end
    // ST R3,[R0+9]: adres = R0 + off6 (ALU optelt), data uit rd (poort B)
    fetch; @(negedge clk); b_sel = 2; rb_sel = 1; mem_we = 1; tick;
    expect8(dm.mem[9], 12, "ST naar mem[9]");
    // LD R4,[R0+9]
    fetch; @(negedge clk); b_sel = 2; reg_we = 1; wb_sel = 1; tick;
    expect8(r4, 12, "LD R4");
    // CMP R3,R4: aftrekken, alleen vlaggen
    fetch; @(negedge clk); alu_op = 1; flags_we = 1; tick;
    if ({fz, fn, fc, fv} !== 4'b1010) begin fouten = fouten + 1; $display("FAIL vlaggen na CMP: %b%b%b%b", fz, fn, fc, fv); end
    // CALL 20: R7 = PC (het adres van de volgende instructie), PC = 20
    fetch; @(negedge clk); pc_load = 1; reg_we = 1; wa_r7 = 1; wb_sel = 3; tick;
    expect8(r7, 7, "CALL zet R7");
    expect8(pc, 20, "CALL springt");
    // JR R7: PC = register A (rs1 = 7)
    fetch; @(negedge clk); pc_load = 1; pc_src = 1; tick;
    expect8(pc, 7, "JR R7 keert terug");

    if (fouten == 0) $display("PASS: datapath voert LDI, ADD, ST, LD, CMP, CALL en JR correct uit");
    $finish;
  end
endmodule
```

Elke instructie loopt in twee stappen: eerst `fetch` (laad het instructieregister en verhoog de PC), dan een uitvoerstap met de juiste combinatie van signalen. Vergelijk die signalen met de tabel in paragraaf 4:

| Instructie | Uitvoerstap |
|------------|-------------|
| `LDI` | `reg_we`, `wb_sel = 2` |
| `ADD` | `alu_ir`, `reg_we`, `flags_we` |
| `ST` | `b_sel = 2`, `rb_sel = 1`, `mem_we` |
| `LD` | `b_sel = 2`, `reg_we`, `wb_sel = 1` |
| `CMP` | `alu_op = 1` (aftrekken), `flags_we` |
| `CALL` | `pc_load`, `reg_we`, `wa_r7`, `wb_sel = 3` |
| `JR` | `pc_load`, `pc_src = 1` |

Draai:

```text
cd labs/cpu
iverilog -g2012 -o dp.vvp tb_datapath.v alu.v idecode.v memories.v datapath.v
vvp dp.vvp
```

## 8. Het kritieke pad

De klok mag niet sneller zijn dan het langzaamste signaalpad tussen twee flipflops (week 5 en 6):

```text
T_klok  ≥  t_clk→Q  +  t_logica  +  t_setup
```

In ons datapath is de langste weg die van `LD`: het instructieregister levert `rs1`, het registerbestand leest, de B-multiplexer geeft de offset, de ALU berekent het adres, het datageheugen leest, de `wb`-multiplexer kiest en het registerbestand schrijft.

```text
IR ─► regbestand lezen ─► mux ─► ALU (optellen) ─► DMEM lezen ─► wb-mux ─► regbestand (setup)
```

Een schatting met vertragingen van 74HC-chips: clk→Q 15 ns, registerbestand lezen 25 ns, B-mux 10 ns, ALU 120 ns (de opteller met uitgangsmux), geheugen 70 ns, wb-mux 10 ns en setup 10 ns. Samen is dat 260 ns, dus ongeveer 3,8 MHz. Een FPGA is een orde van grootte sneller, maar de redenering blijft dezelfde. De ALU is de grootste post, en daarom steken ontwerpers veel werk in snellere optellers.

Zie je het nadeel van deze opzet? Elke instructie gebruikt dezelfde klokperiode, ook de simpele `LDI`. In week 20 lossen we dat op met pipelining.

## 9. Oefeningen

1. Welke besturingssignalen staan aan in de uitvoerstap van `ADDI R2, 5`? En van `CMPI R1, 10`? En van `ST R2, [R3+4]`?
2. Waarom heeft `ST` de multiplexer `rb_sel` nodig? Wat gebeurt er zonder?
3. Waarom bestaat `ra_sel`? Welke twee instructies gebruiken hem?
4. Het registerbestand heeft twee leespoorten. Wat zou je moeten doen als het er maar één had, en wat kost dat?
5. Pas het datapath aan zodat R0 altijd 0 is (zoals in RISC-V). Welke regels verander je, en welke voordelen zie je voor assemblyprogramma's?
6. Bereken de maximale klokfrequentie als de ALU 80 ns kost en het datageheugen 40 ns, met de overige vertragingen uit paragraaf 8. Welke instructie bepaalt de klok nu?
7. Het `always`-blok in het datapath zet `pc_load` voor `pc_inc`. Is dat nodig als de besturing nooit beide tegelijk aanzet?
8. Uitdaging: voeg een signaal `alu_a_zero` toe dat ingang A van de ALU op 0 zet. Welke nieuwe instructies worden dan mogelijk? Denk aan `NEG` en `MOV`.

## 10. Antwoorden

1. `ADDI R2, 5`: `ra_sel = 1`, `b_sel = 1`, `reg_we`, `flags_we` (`alu_op` = ADD = 0, `wb_sel` = 0). `CMPI R1, 10`: `ra_sel = 1`, `b_sel = 1`, `alu_op = 1`, `flags_we`. `ST R2, [R3+4]`: `b_sel = 2`, `rb_sel = 1`, `mem_we`.
2. Poort B leest normaal `rs2`, de bits 5..3 van de instructie. Bij `ST` zijn dat bits van de offset. Zonder `rb_sel` zou je dus een willekeurig register opslaan in plaats van `rd`.
3. Bij `ADDI` en `CMPI` is de eerste operand het register `rd`. Er is geen `rs1`-veld, want die bits maken deel uit van `imm8`.
4. Dan kunnen twee operanden niet in één cyclus gelezen worden. Je voegt een extra stap toe waarin de eerste operand in een tijdelijk register (A) wordt gezet. Dat kost een register, een cyclus per ALU-instructie en extra besturing, en de CPU wordt er trager van.
5. Verander `rega` en `regb` in `ra == 0 ? 8'h00 : r[ra]` (en hetzelfde voor `regb`) en blokkeer het schrijven: `if (reg_we && waddr != 0)`. Het voordeel is dat `MOV rd, rs` wordt `ADD rd, rs, R0` en dat een vergelijking met nul `CMP rs, R0` gebruikt. Het nadeel is dat je een register kwijt bent.
6. De padlengte voor `LD` is 15 + 25 + 10 + 80 + 40 + 10 + 10 = 190 ns, dus 5,3 MHz. Het langste pad is nog steeds `LD` (via de ALU en het geheugen). Zonder geheugen (alleen ALU) is het 150 ns.
7. Voor de huidige besturing niet, maar het is wel een goede verdediging: staan er per ongeluk toch beide aan, dan is het gedrag voorspelbaar. Zulke defensieve keuzes helpen bij het debuggen.
8. Met `alu_a_zero` kun je `NEG rd, rs` (0 − rs), `MOV rd, rs` (0 + rs) en `LDI`-achtig gedrag direct met de ALU doen. Het kost één AND-poort per bit op ingang A (8 poorten) en een besturingssignaal.

## 11. Zelftest

1. Wat is het verschil tussen datapath en besturing?
2. Hoeveel leespoorten heeft het registerbestand en waarom?
3. Wat doet `wb_sel`?
4. Wat bepaalt de maximale kloksnelheid?
5. Waarom wordt de ALU ook gebruikt om adressen te berekenen bij `LD` en `ST`?

Antwoorden: (1) Het datapath bewaart en bewerkt gegevens, de besturing zegt het datapath wat het moet doen. (2) Twee, omdat veel instructies twee operanden tegelijk nodig hebben. (3) Het kiest welke waarde in een register wordt teruggeschreven: ALU, geheugen, constante of PC. (4) De langste signaalweg tussen twee flipflops. (5) Dan is geen aparte opteller nodig: adres = register + offset is gewoon een optelling.

## 12. Verder lezen

- Harris en Harris, 7.3 (het eencyclus-datapath van de MIPS) en 7.4 (de multicyclusversie).
- Ben Eater: de video's over het instructieregister, de program counter en de control logic. Het zijn dezelfde onderdelen met 74LS-chips.

Volgende week: het datapath wacht op signalen. We bouwen de besturingseenheid, het brein van W8, met een controlegeheugen (microcode).
