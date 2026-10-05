---
title: "Week 25 · Je TTA bouwen uit chips: ontwerp, simulatie en printplaat"
---

<p class="subtitle">Fase 6 · Van code naar chip · ongeveer 16 uur</p>

# Week 25: De T8 uit 74HC-chips

## Wat je na deze week kunt

- een gedragsmodel (week 19) omzetten in een ontwerp op chipniveau: welke chip doet wat en hoe zijn ze verbonden
- de timing van een synchroon bord ontwerpen: wanneer telt de PC, wanneer krijgt een register zijn klokpuls en waarom
- een structureel model van het bord schrijven en cyclus voor cyclus vergelijken met het gedragsmodel, voordat je een print bestelt
- laten zien hoeveel marge het ontwerp heeft (snelle en trage chips, kloksnelheid, houdtijd)
- een onderdelenlijst (BOM) afleiden en een bouwplan maken: breadboard, KiCad-schema, printplaat, opbouw en ingebruikname

> **Wat in deze week getest is.** Het ontwerp, het structurele model, de verificatie en de timinganalyse in dit hoofdstuk zijn uitgevoerd en getest in de simulator, met realistische vertragingen. KiCad draaien, een print laten maken en het bord echt bouwen en inschakelen is niet gedaan. De paragrafen over KiCad, bestellen en solderen zijn daarom een zorgvuldig plan met aandachtspunten en geen bewezen recept. Pinnummers en vertragingen controleer je altijd in de databladen van de chips die je koopt.

## 1. Waarom de TTA zo geschikt is voor chips

Kijk terug naar week 19. De T8 heeft geen besturingseenheid: de instructie is het besturingswoord. In hardware betekent dat een ROM met de instructies, twee rijtjes decoders (wie zet data op de bus en wie neemt hem over), een bus van 8 draden en registers en een rekeneenheid die aan die bus hangen.

Er is geen toestandsmachine, geen microcode en geen opcode-decoder. Daarom is dit project haalbaar zonder een kamer vol logica.

Een eerlijke schatting van de omvang: 59 chips in het schema (plus klok, reset en stapschakeling), samen ruim 1000 pinnen. Dat is groot voor een breadboard en prima voor een printplaat. Een advies:

1. Bouw eerst kleine deelschakelingen op een breadboard (programmateller en ROM, één register aan de bus, de opteller) om de technieken te leren.
2. Teken dan het complete schema in KiCad.
3. Bestel één printplaat, bouw hem in stappen op met voetjes (sockets) voor alle chips en test elk blok voordat je het volgende plaatst.

## 2. Het blokschema

```text
  klok ─► PC (2×161) ─► buffer ─► ROM (3×28C256) ─► instructie van 24 bit
            ▲ laden van de bus                          │
            │                       ┌───────────────────┼─────────────────────┐
            │                       ▼                   ▼                     ▼
            │                 guard + vlaggen     bestemmingsvelden       bronveld
            │                  (151) → "go"       (4× 238, levels)      (2× 138, OE')
            │                       │                   │                     │
            │                       └──► pulsen ◄───────┘                     │
            │                              │ (AND met phi, go, niet gehalt)   │ OE'
            │                              ▼                                  ▼
            └──────────────────────  BUS (8 draden, met pull-down)  ◄─────────┘
                                       ▲  │   ▲  │   ▲  │   ▲  │
                                       │  ▼   │  ▼   │  ▼   │  ▼
                               R0..R3 (4×574)  OP     MAR/RAM     IN / OUT
                                               (574)  (574+62256) (244 / 574)

     rekeneenheid:  OP + bus ─► opteller / AND / OR / XOR / SHL ─► RES (574) en vlaggen (74)
```

## 3. Hoe de hardware de ideeën uit het model uitvoert

### De bus en de bronnen

De bus bestaat uit acht draden, aan één kant met pull-down-weerstanden naar massa (een weerstandsnetwerk van 8 × 10 kΩ). Als niemand de bus aanstuurt, leest iedereen 0. Dat is precies het gedrag van het gedragsmodel voor bronnen die niet bestaan.

Elke bron is een chip met een tri-state uitgang, die alleen aan staat als zijn output-enable (OE', actief laag) laag is:

| Bron | Chip |
|------|------|
| `#constante` | 74HC244 aan de laagste ROM-byte |
| `R0` ... `R3` | de uitgang van het 74HC574-register zelf |
| `RES` | 74HC244 achter het resultaatregister |
| `RESHR` | 74HC244 met de bits één plaats verschoven (puur bedrading) |
| `RESNOT` | 74HC240, een inverterende buffer |
| `MEM` | de datapinnen van het RAM |
| `IN` | 74HC244 aan de ingangspoort |
| `PC2` | twee 74HC283 (PC + 2) met een 74HC244 |
| `FLAGS` | 74HC244 aan de drie vlag-flipflops |

Het bronveld van de instructie loopt naar twee 74HC138-decoders. Eén van de acht uitgangen is laag, en dat is precies de OE' van de gekozen bron.

### De bestemmingen en de timing

Hier zit het lastigste deel van het ontwerp. We willen dat een register precies op het juiste moment zijn waarde overneemt, en dat de data dan nog stabiel is.

```text
 clk      ┌─────────┐         ┌─────────┐
          │         │         │         │
 ─────────┘         └─────────┘         └─────
          ↑ t = 0   ↓ T/2     ↑ T
 PC        verandert                     verandert (telt of laadt)
 ROM        ├── zoeken ──┤
 decoders    ├─ settelen ─┤
 bus                 stabiel ───────────────────┤
 doelregister                  ▲ kort klokpuls: de MOVE gebeurt hier
```

Op de stijgende flank van de klok telt de PC door (of laadt hij een sprongdoel). Het ROM zoekt de nieuwe instructie op en de decoders en de bus settelen in de eerste helft van de cyclus. Op de dalende flank krijgt het doelregister een korte klokpuls en neemt het de waarde van de bus over. De bus is dan al lang stabiel en blijft dat tot na de volgende stijgende flank. Dat geeft een grote houdtijdmarge.

Dit lost een klassiek probleem op. Klok je de bestemmingsregisters op het signaal dat tegelijk de bron selecteert, dan is er een race: de bus kan veranderen op hetzelfde moment als de klokflank. Door in het midden van de cyclus te klokken, ver van elke verandering, verdwijnt het probleem.

De bestemmingsdecoders zijn daarom 74HC238-chips (met actief hoge uitgangen) die niveaus geven, stabiel zodra het ROM gesetteld is. Een AND-poort per register maakt er een puls van:

```text
 puls_register = niveau_van_de_decoder  AND  phi  AND  go  AND  niet_gehalt  AND  niet_in_reset
```

Hierin is `phi` de omgekeerde klok (hoog in de tweede helft) en `go` de uitkomst van de guard.

### De guard

Drie bits van de instructie kiezen met een 74HC151 (8-naar-1 multiplexer) welke vlag meetelt. De ingangen zijn `1`, Z, !Z, C, !C, N, !N en `0`. De omgekeerde vlaggen komen gratis uit de Q'-uitgangen van de flipflops.

### De rekeneenheid

```text
          bus ───┬────────────────────────────┐
                 │                            │
   OP (574) ─────┼─► opteller (2×283) ─┐      │
                 │   (bus ^ SUB: XOR)  │      │
                 ├─► AND  (2×08)  ─────┤      ▼
                 ├─► OR   (2×32)  ─────┼─► resultaatbus (tri-state, 5×244) ─► RES (574)
                 ├─► XOR  (2×86)  ─────┤                    │
                 └─► SHL (bedrading) ──┘                    └─► Z, N, C (74)
```

Elke bewerking heeft een eigen tri-state buffer op de resultaatbus, en de bestemming kiest welke aan staat. Bij `SUB` worden alle bits van de bus omgekeerd (XOR met het SUB-niveau) en gaat de carry-in omhoog: `OP + ~bus + 1`. Bij `ADC` is de carry-in de C-vlag.

De Z-vlag is een NOR met 8 ingangen (74HC4078) over de resultaatbus. De N-vlag is bit 7. De C-vlag komt van de carry-uit van de opteller (bij ADD, SUB en ADC) of van bit 7 van de bus (bij SHL), en wordt nul bij AND, OR en XOR.

## 4. Het schema als code

Eerst de chipmodellen. Elk model heeft de pinnen en de actief-laag-conventies van het datablad, plus een typische vertraging. Die vertragingen zijn schattingen, dus controleer ze in de databladen van de chips die je koopt.

<!-- COPY tta/tta.v tta_hw/tta.v -->
<!-- COPY tta/tta_asm.py tta_hw/tta_asm.py -->
<!-- COPY tta/sum.tta tta_hw/sum.tta -->
<!-- COPY tta/fib.tta tta_hw/fib.tta -->
<!-- COPY tta/mul.tta tta_hw/mul.tta -->
<!-- COPY tta/call.tta tta_hw/call.tta -->
<!-- COPY tta/array.tta tta_hw/array.tta -->
<!-- COPY tta/add16.tta tta_hw/add16.tta -->
<!-- COPY tta/guards.tta tta_hw/guards.tta -->
<!-- COPY tta/io.tta tta_hw/io.tta -->

Kopieer het gedragsmodel (`tta.v`), de assembler (`tta_asm.py`) en de programma's uit `labs/tta/` naar `labs/tta_hw/`.

```verilog
// FILE: tta_hw/hc74xx.v
`timescale 1ns/1ps
`ifndef DSCALE
  `define DSCALE 1.0                // schaalfactor voor alle vertragingen: 0.5 = snelle chips, 2.0 = trage chips
`endif
`define DLY(n) ((n) * `DSCALE)
`ifndef ROMDLY
  `define ROMDLY 70                 // toegangstijd van het ROM in ns (de 28C256 is er in versies van 70 tot 250 ns)
`endif
// Gedragsmodellen van de 74HC-chips en geheugens op de printplaat, met typische vertragingen bij 5 V.
// Elk model volgt het datablad: dezelfde pinnen en dezelfde actief-laag-conventies.
// De vertragingen zijn schattingen (typische waarden, geen garantie): controleer ze in de databladen van jouw chips.

// 74HC574: octal D-register (stijgende flank) met tri-state uitgang (OE_n laag = uitgang aan).
module hc574 #(parameter INIT = 8'h00) (input [7:0] D, input CLK, input OE_n, output [7:0] Q);
  reg [7:0] q = INIT;
  always @(posedge CLK) q <= #(`DLY(15)) D;                 // klok naar uitgang: ca. 15 ns
  assign #(`DLY(10)) Q = OE_n ? 8'bz : q;                   // OE naar uitgang: ca. 10 ns
endmodule

// 74HC244: octal tri-state buffer.
module hc244 (input [7:0] A, input OE_n, output [7:0] Y);
  assign #(`DLY(10)) Y = OE_n ? 8'bz : A;
endmodule

// 74HC240: octal INVERTERENDE tri-state buffer.
module hc240 (input [7:0] A, input OE_n, output [7:0] Y);
  assign #(`DLY(10)) Y = OE_n ? 8'bz : ~A;
endmodule

// 74HC283: 4-bit volledige opteller met carry-in en carry-out.
module hc283 (input [3:0] A, input [3:0] B, input C0, output [3:0] S, output C4);
  assign #(`DLY(20)) {C4, S} = A + B + C0;
endmodule

// 74HC238: 3-naar-8 decoder met drie enables (E1_n, E2_n actief laag, E3 actief hoog). Uitgangen actief HOOG.
module hc238 (input A, input B, input C, input E1_n, input E2_n, input E3, output [7:0] Y);
  wire en = ~E1_n & ~E2_n & E3;
  assign #(`DLY(15)) Y = en ? (8'b00000001 << {C, B, A}) : 8'h00;
endmodule

// 74HC138: zoals de 238, maar de uitgangen zijn actief LAAG.
module hc138 (input A, input B, input C, input E1_n, input E2_n, input E3, output [7:0] Y_n);
  wire en = ~E1_n & ~E2_n & E3;
  assign #(`DLY(15)) Y_n = en ? ~(8'b00000001 << {C, B, A}) : 8'hFF;
endmodule

// 74HC151: 8-naar-1 multiplexer. S0 is het minst significante selectiebit.
module hc151 (input [7:0] D, input S0, input S1, input S2, input E_n, output Y, output W);
  wire [2:0] s = {S2, S1, S0};
  assign #(`DLY(15)) Y = E_n ? 1'b0 : D[s];
  assign #(`DLY(15)) W = ~(E_n ? 1'b0 : D[s]);
endmodule

// 74HC161: 4-bit synchrone teller met asynchrone clear, synchrone load en twee enables.
module hc161 (input CLK, input CLR_n, input LOAD_n, input ENP, input ENT, input [3:0] D, output [3:0] Q, output RCO);
  reg [3:0] q = 4'h0;
  always @(posedge CLK or negedge CLR_n)
    if (!CLR_n)         q <= #(`DLY(18)) 4'h0;
    else if (!LOAD_n)   q <= #(`DLY(18)) D;
    else if (ENP & ENT) q <= #(`DLY(18)) q + 4'd1;
  assign Q = q;
  assign #(`DLY(10)) RCO = ENT & (q == 4'hF);
endmodule

// 74HC74: één D-flipflop met asynchrone set en clear (actief laag), uit de twee in de chip.
module hc74 (input D, input CLK, input CLR_n, input SET_n, output Q, output Qn);
  reg q = 1'b0;
  always @(posedge CLK or negedge CLR_n or negedge SET_n)
    if (!CLR_n)      q <= #(`DLY(15)) 1'b0;
    else if (!SET_n) q <= #(`DLY(15)) 1'b1;
    else             q <= #(`DLY(15)) D;
  assign Q = q;
  assign Qn = ~q;
endmodule

// Gewone poortchips
module hc04 (input [5:0] A, output [5:0] Y);                  assign #(`DLY(8))  Y = ~A;      endmodule   // 6 inverters
module hc08 (input [3:0] A, input [3:0] B, output [3:0] Y);   assign #(`DLY(8))  Y = A & B;   endmodule   // 4 AND-poorten
module hc32 (input [3:0] A, input [3:0] B, output [3:0] Y);   assign #(`DLY(8))  Y = A | B;   endmodule   // 4 OR-poorten
module hc86 (input [3:0] A, input [3:0] B, output [3:0] Y);   assign #(`DLY(10)) Y = A ^ B;   endmodule   // 4 XOR-poorten
module hc11 (input [2:0] A, input [2:0] B, input [2:0] C, output [2:0] Y);   assign #(`DLY(9)) Y = A & B & C;   endmodule   // 3 AND-poorten met 3 ingangen
module hc4078 (input [7:0] A, output Y, output J);            assign #(`DLY(12)) J = |A; assign #(`DLY(12)) Y = ~|A; endmodule   // 8-ingangs OR (J) en NOR (Y)

// 28C256: 32K x 8 EEPROM. Wij gebruiken alleen de eerste 256 adressen; elke chip levert één byte van de 24-bit-instructie.
module eeprom28c256 #(parameter FILE = "tta.hex", parameter BYTE = 0, parameter LOAD = 1) (input [7:0] A, input CE_n, input OE_n, output [7:0] D);
  reg [23:0] words [0:255];
  integer k;
  initial begin
    for (k = 0; k < 256; k = k + 1) words[k] = 24'h1F0000;     // leeg = HALT
    if (LOAD) $readmemh(FILE, words);
  end
  wire [23:0] w = words[A];
  assign #(`ROMDLY) D = (CE_n | OE_n) ? 8'bz : w >> (8 * BYTE);     // toegangstijd: 70 ns (kies een snellere chip voor een snellere klok)
endmodule

// 62256: 32K x 8 statisch RAM. Schrijft bij de stijgende flank van WE_n (de data wordt dan vastgelegd).
module sram62256 (input [7:0] A, input CE_n, input OE_n, input WE_n, inout [7:0] DQ);
  reg [7:0] mem [0:255];
  integer i;
  initial for (i = 0; i < 256; i = i + 1) mem[i] = 8'h00;
  always @(posedge WE_n) if (!CE_n) mem[A] <= DQ;
  assign #(`DLY(40)) DQ = (!CE_n && !OE_n && WE_n) ? mem[A] : 8'bz;
endmodule
```

Dan het bord zelf. Elke `u_...` is één chip en elke `wire` een draad. Als je een schema in KiCad tekent, is dit je tekening in tekst.

```verilog
// FILE: tta_hw/t8_board.v
`timescale 1ns/1ps
// De transport-triggered architecture T8 uit echte 74HC-chips. Dit bestand is het schema in tekstvorm:
// elke 'u_...' is één chip op de printplaat, elke 'wire' een draad.
//
// Timing in één oogopslag (klok 'clk'):
//   - de programmateller (PC) telt of laadt op de STIJGENDE flank van clk;
//   - daarna zoekt het ROM de instructie op en settelen de decoders en de bus (de eerste helft van de cyclus);
//   - op de DALENDE flank van clk gaat phi hoog en krijgt het doelregister een kort klokpuls: de MOVE gebeurt dan;
//   - 'halted' reageert op de volgende stijgende flank.
module t8_board #(parameter PROG = "tta.hex", parameter LOAD = 1) (
  input        clk,
  input        rst_n,
  input  [7:0] in_port,
  output [7:0] out_port,
  output       halted
);
  tri0 [7:0] bus;                 // de gedeelde bus; tri0 = de pull-down-weerstanden op de print
  tri0 [7:0] rbus;                // de resultaatbus van de rekeneenheid

  // ===== Programmateller, adresbuffer en programmageheugen =====
  wire [7:0] pc, pc_addr;
  wire       pc_rco, load_pc_n, halted_n;
  hc161 u_pc_lo (.CLK(clk), .CLR_n(rst_n), .LOAD_n(load_pc_n), .ENP(halted_n), .ENT(halted_n),
                 .D(bus[3:0]), .Q(pc[3:0]), .RCO(pc_rco));
  hc161 u_pc_hi (.CLK(clk), .CLR_n(rst_n), .LOAD_n(load_pc_n), .ENP(halted_n), .ENT(pc_rco),
                 .D(bus[7:4]), .Q(pc[7:4]), .RCO());
  hc244 u_pc_buf (.A(pc), .OE_n(1'b0), .Y(pc_addr));       // buffer: iets extra vertraging op het ROM-adres, voor houdtijd

  wire [7:0] rom_hi, rom_mid, rom_lo;
  eeprom28c256 #(PROG, 2, LOAD) u_rom_hi  (.A(pc_addr), .CE_n(1'b0), .OE_n(1'b0), .D(rom_hi));    // guard + bestemming
  eeprom28c256 #(PROG, 1, LOAD) u_rom_mid (.A(pc_addr), .CE_n(1'b0), .OE_n(1'b0), .D(rom_mid));   // bron
  eeprom28c256 #(PROG, 0, LOAD) u_rom_lo  (.A(pc_addr), .CE_n(1'b0), .OE_n(1'b0), .D(rom_lo));    // constante
  wire [2:0] guard = rom_hi[7:5];
  wire [4:0] dst   = rom_hi[4:0];
  wire [4:0] src   = rom_mid[4:0];

  // ===== Vlaggen en guard =====
  wire zf, zf_n, nf, nf_n, cf, cf_n, res_clk, z_next, n_next, c_next;
  hc74 u_fz (.D(z_next), .CLK(res_clk), .CLR_n(rst_n), .SET_n(1'b1), .Q(zf), .Qn(zf_n));
  hc74 u_fn (.D(n_next), .CLK(res_clk), .CLR_n(rst_n), .SET_n(1'b1), .Q(nf), .Qn(nf_n));
  hc74 u_fc (.D(c_next), .CLK(res_clk), .CLR_n(rst_n), .SET_n(1'b1), .Q(cf), .Qn(cf_n));

  wire go;      // mag deze move doorgaan? De guard kiest welke vlag meetelt.
  hc151 u_guard (.D({1'b0, nf_n, nf, cf_n, cf, zf_n, zf, 1'b1}), .S0(guard[0]), .S1(guard[1]), .S2(guard[2]),
                 .E_n(1'b0), .Y(go), .W());

  // ===== Bestemmingsdecoders (74HC238): LEVELS, stabiel zodra het ROM settled is =====
  wire dst3_n, dst4_n;
  wire [7:0] d0, d1, d2, d3;
  hc238 u_d0 (.A(dst[0]), .B(dst[1]), .C(dst[2]), .E1_n(dst[3]), .E2_n(dst[4]), .E3(1'b1), .Y(d0));   // bestemmingen 0..7
  hc238 u_d1 (.A(dst[0]), .B(dst[1]), .C(dst[2]), .E1_n(dst3_n),  .E2_n(dst[4]), .E3(1'b1), .Y(d1));   //             8..15
  hc238 u_d2 (.A(dst[0]), .B(dst[1]), .C(dst[2]), .E1_n(dst[3]),  .E2_n(dst4_n), .E3(1'b1), .Y(d2));   //            16..23
  hc238 u_d3 (.A(dst[0]), .B(dst[1]), .C(dst[2]), .E1_n(dst3_n),  .E2_n(dst4_n), .E3(1'b1), .Y(d3));   //            24..31
  wire l_r0 = d0[1], l_r1 = d0[2], l_r2 = d0[3], l_r3 = d0[4], l_op = d0[5], l_add = d0[6], l_sub = d0[7];
  wire l_and = d1[0], l_or = d1[1], l_xor = d1[2], l_pc = d1[3], l_mar = d1[4], l_mem = d1[5], l_out = d1[6], l_shl = d1[7];
  wire l_adc = d2[0];
  wire l_halt = d3[7];

  // ===== Bronnen: decoders (74HC138, actief laag) =====
  wire src3_n;
  wire [7:0] s0, s1;
  hc138 u_s0 (.A(src[0]), .B(src[1]), .C(src[2]), .E1_n(src[3]), .E2_n(src[4]), .E3(1'b1), .Y_n(s0));   // bronnen 0..7
  hc138 u_s1 (.A(src[0]), .B(src[1]), .C(src[2]), .E1_n(src3_n),  .E2_n(src[4]), .E3(1'b1), .Y_n(s1));   //         8..15

  // ===== Klok- en schrijfpulsen =====
  // e2 = de move mag doorgaan en de machine is niet gehalt;  e = e2 en de tweede helft van de cyclus (phi)
  wire phi, e2, e, p_r0, p_r1, p_r2, p_r3, p_op, p_mar, p_out, p_mem, p_pc_level, halt_d, is_trig;
  wire adcc, c_term_add, c_term_shl, use_add, use_add_t, we_mem_n, cin, c_mid, c_add;
  // e2 = de move mag doorgaan (guard), de machine is niet gehalt en er is geen reset actief.
  // De reset moet meetellen: terwijl hij loslaat of aanstaat zakken de vlaggen en 'halted' met verschillende vertragingen,
  // wat anders korte valse schrijfpulsen geeft.
  wire e2_unused1, e2_unused2, g1_unused;
  hc11 u_e2 (.A({1'b1, 1'b1, go}), .B({1'b1, 1'b1, halted_n}), .C({1'b1, 1'b1, rst_n}), .Y({e2_unused2, e2_unused1, e2}));
  hc08 u_g1 (.A({l_r1, l_r0, phi, 1'b0}), .B({e, e, e2, 1'b0}), .Y({p_r1, p_r0, e, g1_unused}));

  hc08 u_g2 (.A({l_mar, l_op, l_r3, l_r2}), .B({e, e, e, e}), .Y({p_mar, p_op, p_r3, p_r2}));
  hc08 u_g3 (.A({is_trig, l_pc, l_mem, l_out}), .B({e, e2, e, e}), .Y({res_clk, p_pc_level, p_mem, p_out}));
  hc08 u_g4 (.A({l_shl, use_add, l_adc, l_halt}), .B({bus[7], c_add, cf, e2}), .Y({c_term_shl, c_term_add, adcc, halt_d}));

  // ===== Inverters =====
  wire oe_add_n, oe_and_n, oe_or_n, oe_xor_n, oe_shl_n, inv2_unused;
  hc04 u_inv1 (.A({p_mem, p_pc_level, src[3], dst[4], dst[3], clk}), .Y({we_mem_n, load_pc_n, src3_n, dst4_n, dst3_n, phi}));
  hc04 u_inv2 (.A({l_shl, l_xor, l_or, l_and, use_add, 1'b0}), .Y({oe_shl_n, oe_xor_n, oe_or_n, oe_and_n, oe_add_n, inv2_unused}));

  // ===== Registers op de bus (74HC574) =====
  wire [7:0] op_q, mar_q, res_q, out_q;
  hc574 u_r0  (.D(bus), .CLK(p_r0),  .OE_n(s0[1]), .Q(bus));
  hc574 u_r1  (.D(bus), .CLK(p_r1),  .OE_n(s0[2]), .Q(bus));
  hc574 u_r2  (.D(bus), .CLK(p_r2),  .OE_n(s0[3]), .Q(bus));
  hc574 u_r3  (.D(bus), .CLK(p_r3),  .OE_n(s0[4]), .Q(bus));
  hc574 u_op  (.D(bus), .CLK(p_op),  .OE_n(1'b0),  .Q(op_q));       // operand van de rekeneenheid
  hc574 u_mar (.D(bus), .CLK(p_mar), .OE_n(1'b0),  .Q(mar_q));      // geheugenadres
  hc574 u_out (.D(bus), .CLK(p_out), .OE_n(1'b0),  .Q(out_q));      // uitgangspoort
  hc574 u_res (.D(rbus), .CLK(res_clk), .OE_n(1'b0), .Q(res_q));    // resultaat van de rekeneenheid
  assign out_port = out_q;

  // ===== Overige bronnen op de bus =====
  hc244 u_imm   (.A(rom_lo),                .OE_n(s0[0]), .Y(bus));    // constante uit de instructie
  hc244 u_resb  (.A(res_q),                 .OE_n(s0[5]), .Y(bus));    // RES
  hc244 u_reshr (.A({1'b0, res_q[7:1]}),    .OE_n(s0[6]), .Y(bus));    // RESHR
  hc240 u_resn  (.A(res_q),                 .OE_n(s0[7]), .Y(bus));    // RESNOT (inverterende buffer)
  sram62256 u_ram (.A(mar_q), .CE_n(1'b0), .OE_n(s1[0]), .WE_n(we_mem_n), .DQ(bus));     // MEM (lezen en schrijven)
  hc244 u_in    (.A(in_port),               .OE_n(s1[1]), .Y(bus));    // IN
  wire [7:0] pc2; wire pc2c;
  hc283 u_pc2_lo (.A(pc[3:0]), .B(4'b0010), .C0(1'b0), .S(pc2[3:0]), .C4(pc2c));
  hc283 u_pc2_hi (.A(pc[7:4]), .B(4'b0000), .C0(pc2c), .S(pc2[7:4]), .C4());
  hc244 u_pc2   (.A(pc2),                   .OE_n(s1[2]), .Y(bus));    // PC2 = PC + 2
  hc244 u_flags (.A({5'b00000, nf, cf, zf}), .OE_n(s1[3]), .Y(bus));   // FLAGS

  // ===== De rekeneenheid =====
  wire [7:0] bx, sum, and8, or8, xor8;
  hc32 u_o1 (.A({c_term_add, l_sub, use_add_t, l_add}), .B({c_term_shl, adcc, l_adc, l_sub}), .Y({c_next, cin, use_add, use_add_t}));
  // (use_add_t = l_add | l_sub  — de vierde poort; use_add = use_add_t | l_adc; cin = l_sub | adcc; c_next = c_term_add | c_term_shl)
  hc86 u_bx_lo (.A(bus[3:0]), .B({4{l_sub}}), .Y(bx[3:0]));    // bij aftrekken de bus omkeren
  hc86 u_bx_hi (.A(bus[7:4]), .B({4{l_sub}}), .Y(bx[7:4]));
  hc283 u_add_lo (.A(op_q[3:0]), .B(bx[3:0]), .C0(cin),   .S(sum[3:0]), .C4(c_mid));
  hc283 u_add_hi (.A(op_q[7:4]), .B(bx[7:4]), .C0(c_mid), .S(sum[7:4]), .C4(c_add));
  hc08 u_and_lo (.A(op_q[3:0]), .B(bus[3:0]), .Y(and8[3:0]));
  hc08 u_and_hi (.A(op_q[7:4]), .B(bus[7:4]), .Y(and8[7:4]));
  hc32 u_or_lo  (.A(op_q[3:0]), .B(bus[3:0]), .Y(or8[3:0]));
  hc32 u_or_hi  (.A(op_q[7:4]), .B(bus[7:4]), .Y(or8[7:4]));
  hc86 u_xor_lo (.A(op_q[3:0]), .B(bus[3:0]), .Y(xor8[3:0]));
  hc86 u_xor_hi (.A(op_q[7:4]), .B(bus[7:4]), .Y(xor8[7:4]));
  hc244 u_rb_add (.A(sum),               .OE_n(oe_add_n), .Y(rbus));
  hc244 u_rb_and (.A(and8),              .OE_n(oe_and_n), .Y(rbus));
  hc244 u_rb_or  (.A(or8),               .OE_n(oe_or_n),  .Y(rbus));
  hc244 u_rb_xor (.A(xor8),              .OE_n(oe_xor_n), .Y(rbus));
  hc244 u_rb_shl (.A({bus[6:0], 1'b0}),  .OE_n(oe_shl_n), .Y(rbus));

  // is_trig: is de bestemming een rekentrigger?  z_next: is het resultaat nul?
  hc4078 u_trig (.A({1'b0, l_shl, l_xor, l_or, l_and, l_adc, l_sub, l_add}), .Y(), .J(is_trig));
  hc4078 u_zero (.A(rbus), .Y(z_next), .J());
  assign n_next = rbus[7];

  // ===== Halt: de flipflop neemt de stop-aanvraag over op de stijgende klokflank en houdt hem vast =====
  // Let op de OR met de eigen uitgang: zonder die terugkoppeling zou 'halted' meteen weer 0 worden,
  // want zodra de machine gehalt is, valt 'e2' (en dus halt_d) weg.
  wire halt_hold, o2_u1, o2_u2, o2_u3;
  hc32 u_o2 (.A({3'b000, halt_d}), .B({3'b000, halted}), .Y({o2_u3, o2_u2, o2_u1, halt_hold}));
  hc74 u_halt (.D(halt_hold), .CLK(clk), .CLR_n(rst_n), .SET_n(1'b1), .Q(halted), .Qn(halted_n));
endmodule
```

### Wie is wie op het bord?

| Chip(s) | Rol |
|---------|-----|
| `u_pc_lo`, `u_pc_hi` (74HC161) | programmateller, telt en laadt |
| `u_pc_buf` (244) | buffer op het ROM-adres (extra marge voor de houdtijd) |
| `u_rom_hi/mid/lo` (28C256) | het programmageheugen: drie bytes per instructie |
| `u_ram` (62256) | het datageheugen |
| `u_d0` ... `u_d3` (74HC238) | bestemmingsdecoders (niveaus) |
| `u_s0`, `u_s1` (74HC138) | brondecoders (actief laag) |
| `u_guard` (74HC151) | guardkeuze |
| `u_fz`, `u_fn`, `u_fc`, `u_halt` (74HC74) | vlaggen en de halt-flipflop |
| `u_r0` ... `u_r3` (574) | algemene registers |
| `u_op`, `u_res`, `u_mar`, `u_out` (574) | operand, resultaat, geheugenadres, uitvoer |
| `u_g1` ... `u_g4`, `u_e2` | AND-poorten voor de pulsen |
| `u_inv1`, `u_inv2` | inverters |
| `u_add_*`, `u_bx_*`, `u_and_*`, `u_or_*`, `u_xor_*`, `u_rb_*` | rekeneenheid |
| `u_trig`, `u_zero` (4078) | "is het een trigger" en "is het resultaat nul" |
| `u_imm`, `u_resb`, `u_reshr`, `u_resn`, `u_in`, `u_pc2`, `u_flags` | bronbuffers |

## 5. Wat de simulatie aan het licht bracht

Deze punten zijn op papier makkelijk te missen en op een bord duur. De simulatie vond ze alle drie.

1. De halt-flipflop wiste zichzelf. Bij `HALT` werd `halted` 1. Maar zodra `halted` 1 is, valt `e2` (de "mag-doorgaan"-schakeling) weg, dus `halt_d` wordt 0 en de volgende klokflank zette `halted` weer terug op 0. Een stopvlag moet blijven staan. De oplossing is een OR met de eigen uitgang (`u_o2`).
2. Er ontstonden valse pulsen tijdens een reset. Bij een reset zakken de vlaggen en de halt-flipflop met licht verschillende vertragingen. In die korte tijd kon een schrijfpuls ontstaan die een register vulde (in de test kreeg `OP` zomaar de waarde van een constante). Op een echt bord kan zo'n valse puls ook het uitvoerregister of het RAM raken. De oplossing is dat de reset meetelt in "mag-doorgaan" (`u_e2`, een 74HC11).
3. De registers hebben geen reset. Een 74HC574 heeft geen resetpin en bevat na het inschakelen willekeurige data. Een programma mag dus nooit aannemen dat R0 nul is. In het model begint het bord met nullen en de test "schakelt de voeding uit en aan" door ze tussen de programma's op nul te zetten.

Alle drie volgden uit de manier van testen: het gedragsmodel is de specificatie, het bord is de implementatie en een verschil van één bit in één cyclus was genoeg om de fout te vinden.

## 6. Verificatie: het bord naast het gedragsmodel

`pair_hw` zet één bord naast één gedragsmodel uit week 19 met hetzelfde programma. Na elke klokcyclus vergelijkt het de volledige toestand: PC, R0 tot en met R3, OP, MAR, RES, de vlaggen, de uitvoer en de halt-vlag. Het controleert ook dat er nooit een X (conflict) op de bus staat.

```verilog
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
```

Eerst de acht programma's uit week 19:

```verilog
// FILE: tta_hw/tb_t8_board.v
`timescale 1ns/1ps
`ifndef HALF
  `define HALF 500                 // halve klokperiode in ns: 500 = 1 MHz
`endif
// Acht programma's tegelijk, elk op een eigen bord naast het gedragsmodel (pair_hw.v).
module tb_t8_board;
  reg clk = 0, rst_n = 0;
  wire [7:0] d;
  wire [31:0] b0, b1, b2, b3, b4, b5, b6, b7;
  integer fouten = 0, cycli = 0;
  pair_hw #("sum.hex")                       p0(clk, rst_n, 8'd0, b0, d[0]);
  pair_hw #("fib.hex")                       p1(clk, rst_n, 8'd0, b1, d[1]);
  pair_hw #("mul.hex")                       p2(clk, rst_n, 8'd0, b2, d[2]);
  pair_hw #("call.hex")                      p3(clk, rst_n, 8'd0, b3, d[3]);
  pair_hw #("array.hex", "array.dat", 1)     p4(clk, rst_n, 8'd0, b4, d[4]);
  pair_hw #("add16.hex")                     p5(clk, rst_n, 8'd0, b5, d[5]);
  pair_hw #("guards.hex")                    p6(clk, rst_n, 8'd0, b6, d[6]);
  pair_hw #("io.hex")                        p7(clk, rst_n, 8'd41, b7, d[7]);
  always #(`HALF) clk = ~clk;

  initial begin
    #2300 rst_n = 1;
    while (!(&d) && cycli < 400) begin @(posedge clk); cycli = cycli + 1; end
    repeat (3) @(posedge clk);
    #600;
    if (!(&d)) begin fouten = fouten + 1; $display("FAIL: niet alle borden stopten"); end
    if (b0 + b1 + b2 + b3 + b4 + b5 + b6 + b7 !== 0) begin fouten = fouten + 1; $display("FAIL: afwijkingen %0d %0d %0d %0d %0d %0d %0d %0d", b0, b1, b2, b3, b4, b5, b6, b7); end
    if (fouten == 0) $display("PASS: het 74HC-bord geeft in acht programma's cyclus voor cyclus dezelfde toestand als het gedragsmodel (%0d cycli)", cycli);
    $finish;
  end
endmodule
```

Dan 300 willekeurige programma's, met alle guards, bronnen en bestemmingen, cyclus voor cyclus vergeleken:

```verilog
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
```

Beide slagen.

## 7. Hoeveel marge heeft het ontwerp?

Een logisch correct ontwerp kan toch niet werken als de klok te snel is. Het bord is onder verschillende omstandigheden gesimuleerd. Het script `sweep.py` doet dit na.

```python
# FILE: tta_hw/sweep.py
"""Zoekt hoe snel de klok van het 74HC-bord kan, en of het ontwerp robuust is voor snelle en trage chips.
Gebruik:  python3 sweep.py          (duurt een minuut of twee)"""
import subprocess

BESTANDEN = ["tb_t8_board_random.v", "tb_t8_board.v", "pair_hw.v", "tta.v", "t8_board.v", "hc74xx.v"]


def draai(halve_periode, schaal, rom):
    c = subprocess.run(["iverilog", "-g2012", f"-DHALF={halve_periode}", f"-DDSCALE={schaal}", f"-DROMDLY={rom}",
                        "-s", "tb_t8_board_random", "-o", "sweep.vvp"] + BESTANDEN, capture_output=True, text=True)
    if c.returncode:
        return "compileerfout: " + c.stderr[:100]
    uit = subprocess.run(["vvp", "sweep.vvp"], capture_output=True, text=True, timeout=300).stdout
    regels = [x for x in uit.splitlines() if x.startswith(("PASS", "FAIL:"))]
    return "ok" if regels and regels[-1].startswith("PASS") else "FOUT"


if __name__ == "__main__":
    print("1. Hoe snel kan de klok? (typische chips, ROM 70 ns)")
    for half in (500, 350, 300, 250, 200):
        print(f"   {1000 / (2 * half):5.2f} MHz: {draai(half, 1.0, 70)}")
    print("2. Snelle (x0,5) en trage (x2) chips op 1 MHz")
    for schaal in (0.5, 2.0):
        print(f"   vertragingsschaal {schaal}: {draai(500, schaal, 70)}")
    print("3. Houdtijd: een zeer snel ROM met trage poorten (x2), 1 MHz")
    for rom in (70, 10, 1):
        print(f"   ROM {rom:3d} ns: {draai(500, 2.0, rom)}")
    print("4. Trage chips (x2) met het langzaamste ROM (150 ns)")
    for half in (500, 400):
        print(f"   {1000 / (2 * half):5.2f} MHz: {draai(half, 2.0, 150)}")
```

De resultaten (voor alle 300 willekeurige programma's):

| Omstandigheden | Resultaat |
|----------------|-----------|
| typische chips, ROM 70 ns, 1 MHz | ok |
| typische chips, ROM 70 ns, 2 MHz | ok |
| typische chips, ROM 70 ns, 2,5 MHz | fout |
| snelle chips (×0,5), 1 MHz | ok |
| trage chips (×2), 1 MHz | ok |
| trage poorten (×2) met een zeer snel ROM (1 ns), 1 MHz | ok (houdtijd is geen probleem) |
| trage chips (×2) en het langzaamste ROM (150 ns), 1 MHz | ok |
| trage chips (×2), ROM 150 ns, 1,25 MHz | fout |

Wat hieruit volgt:

- Mik op 1 MHz. Dat werkt in de simulatie met snelle en trage chips en met elk ROM, van 1 tot 150 ns toegangstijd.
- Houdtijd is geen probleem, doordat de klok in het midden van de cyclus wordt gegeven en door de buffer op het ROM-adres.
- De grens ligt bij ongeveer 2 MHz met typische waarden, bepaald door de keten ROM, decoder, bus en opteller binnen een halve klokperiode.
- Gebruik eerst de enkelstapsklok (één puls per druk op een knop). Pas daarna zet je een kristaloscillator in.

Deze simulatie is zo goed als haar modellen. Echte chips hebben minimale en maximale vertragingen, de printbanen voegen vertraging en ruis toe en de voedingen hebben pieken. De marge (een factor 2 in kloksnelheid) is bedoeld om dat op te vangen.

## 8. De onderdelenlijst

Het script telt de chips direct uit het schema, zodat de lijst nooit afwijkt van het ontwerp:

```python
# FILE: tta_hw/bom.py
"""Telt de chips in het schema (t8_board.v) en maakt een onderdelenlijst (BOM) met een prijsindicatie.

De prijzen zijn grove schattingen voor kleine aantallen en veranderen; pas ze aan in de tabel PRIJS."""
import re
import sys
from collections import Counter

# type in Verilog -> (naam op het bord, behuizing, pinnen, omschrijving)
CHIPS = {
    "hc04":   ("74HC04",  "DIP-14", 14, "6 inverters"),
    "hc08":   ("74HC08",  "DIP-14", 14, "4 AND-poorten"),
    "hc11":   ("74HC11",  "DIP-14", 14, "3 AND-poorten met 3 ingangen"),
    "hc32":   ("74HC32",  "DIP-14", 14, "4 OR-poorten"),
    "hc86":   ("74HC86",  "DIP-14", 14, "4 XOR-poorten"),
    "hc74":   ("74HC74",  "DIP-14", 14, "2 D-flipflops"),
    "hc138":  ("74HC138", "DIP-16", 16, "3-naar-8 decoder, uitgangen actief laag"),
    "hc238":  ("74HC238", "DIP-16", 16, "3-naar-8 decoder, uitgangen actief hoog"),
    "hc151":  ("74HC151", "DIP-16", 16, "8-naar-1 multiplexer"),
    "hc161":  ("74HC161", "DIP-16", 16, "4-bit synchrone teller"),
    "hc283":  ("74HC283", "DIP-16", 16, "4-bit opteller"),
    "hc240":  ("74HC240", "DIP-20", 20, "octal inverterende buffer, tri-state"),
    "hc244":  ("74HC244", "DIP-20", 20, "octal buffer, tri-state"),
    "hc574":  ("74HC574", "DIP-20", 20, "octal D-register met tri-state"),
    "hc4078": ("74HC4078", "DIP-14", 14, "8-ingangs OR/NOR"),
    "eeprom28c256": ("28C256", "DIP-28", 28, "32K x 8 EEPROM"),
    "sram62256":    ("62256",  "DIP-28", 28, "32K x 8 statisch RAM"),
}
PRIJS = {"74HC04": 0.5, "74HC08": 0.5, "74HC11": 0.6, "74HC32": 0.5, "74HC86": 0.6, "74HC74": 0.5, "74HC138": 0.6,
         "74HC238": 0.8, "74HC151": 0.7, "74HC161": 0.7, "74HC283": 0.8, "74HC240": 0.7, "74HC244": 0.6, "74HC574": 0.8,
         "74HC4078": 0.7, "28C256": 5.0, "62256": 2.5}      # euro per stuk, grove schatting
SOCKEL = 0.25                                                # euro per IC-voet (DIP-socket), per pin klasse gemiddeld


def tel(pad):
    tekst = open(pad).read()
    c = Counter()
    for m in re.finditer(r"^\s*(\w+)\s+(?:#\([^)]*\)\s*)?u_\w+\s*\(", tekst, re.M):
        if m.group(1) in CHIPS:
            c[m.group(1)] += 1
    # Een 74HC74 bevat twee flipflops: in het schema staat elke flipflop als aparte instantie.
    c["hc74"] = (c["hc74"] + 1) // 2
    return c


def main(pad="t8_board.v"):
    c = tel(pad)
    totaal_chips = sum(c.values())
    print(f"{'chip':10} {'aantal':>6}  {'behuizing':9}  omschrijving")
    sub = 0.0
    for t, n in sorted(c.items(), key=lambda kv: CHIPS[kv[0]][0]):
        naam, beh, pins, omschr = CHIPS[t]
        print(f"{naam:10} {n:6d}  {beh:9}  {omschr}")
        sub += n * PRIJS[naam]
    voeten = totaal_chips * SOCKEL
    print(f"\nTotaal: {totaal_chips} chips, {sum(CHIPS[t][2] * n for t, n in c.items())} pinnen")
    print(f"Indicatie: chips ca. EUR {sub:.0f}, IC-voeten ca. EUR {voeten:.0f} (excl. print, condensatoren, weerstanden, connectoren, klok)")
    return c


if __name__ == "__main__":
    main(*sys.argv[1:])
```

De uitvoer:

```text
28C256          3  DIP-28     32K x 8 EEPROM
62256           1  DIP-28     32K x 8 statisch RAM
74HC04          2  DIP-14     6 inverters
74HC08          6  DIP-14     4 AND-poorten
74HC11          1  DIP-14     3 AND-poorten met 3 ingangen
74HC138         2  DIP-16     3-naar-8 decoder, uitgangen actief laag
74HC151         1  DIP-16     8-naar-1 multiplexer
74HC161         2  DIP-16     4-bit synchrone teller
74HC238         4  DIP-16     3-naar-8 decoder, uitgangen actief hoog
74HC240         1  DIP-20     octal inverterende buffer, tri-state
74HC244        12  DIP-20     octal buffer, tri-state
74HC283         4  DIP-16     4-bit opteller
74HC32          4  DIP-14     4 OR-poorten
74HC4078        2  DIP-14     8-ingangs OR/NOR
74HC574         8  DIP-20     octal D-register met tri-state
74HC74          2  DIP-14     2 D-flipflops
74HC86          4  DIP-14     4 XOR-poorten

Totaal: 59 chips
```

Daarnaast heb je nodig (niet in het schema):

| Onderdeel | Aantal | Waarvoor |
|-----------|-------:|----------|
| IC-voetjes (DIP) | 59 | zodat je chips kunt vervangen |
| Condensator 100 nF | ca. 60 | ontkoppeling, één bij elke chip |
| Elco 100 µF | 2 | buffer voor de voeding |
| Weerstandsnetwerk 8 × 10 kΩ (SIP) | 2 | pull-down van de bus en van de ingangspoort |
| Kristaloscillator 1 MHz | 1 | de klok |
| 74HC00 en 74HC14 (of gelijkwaardig) | 2 | enkelstapsknop met debouncing, reset |
| Drukknoppen, schakelaar | 3 | stap, reset, run/stap |
| LED's met weerstanden | 30 tot 40 | bus, PC, registers, vlaggen, uitvoer (voor debuggen) |
| Connector voor de voeding, ingangspoort en uitgangspoort | | |

De prijsindicatie van het script (ruwweg €50 voor de chips, €15 voor de voetjes, plus print, LED's, condensatoren en connectoren) is een grove schatting voor kleine aantallen. Controleer actuele prijzen. Reken op een totaal van enkele tientallen euro's tot rond de honderd, waarbij de drie EEPROM's het duurste onderdeel zijn.

## 9. De ROM programmeren

Een EEPROM-programmer heeft een binair bestand nodig. Het ROM van de T8 is 24 bit breed en bestaat uit drie 8-bit chips. Dit script splitst het hex-bestand van de assembler in drie bestanden van 256 bytes:

```python
# FILE: tta_hw/split_rom.py
"""Splitst een TTA-programma (tta_asm.py maakt 24-bit-woorden in een .hex-bestand) in drie binaire bestanden van
256 bytes, één per EEPROM: hoog (guard + bestemming), midden (bron) en laag (constante).
Gebruik:  python3 split_rom.py programma.hex        ->  programma_hi.bin, programma_mid.bin, programma_lo.bin"""
import sys


def split(words):
    hi = bytes((w >> 16) & 0xFF for w in words)
    mid = bytes((w >> 8) & 0xFF for w in words)
    lo = bytes(w & 0xFF for w in words)
    return hi, mid, lo


def lees_hex(pad):
    woorden = [int(x, 16) for x in open(pad).read().split()]
    if len(woorden) != 256:
        raise SystemExit(f"verwacht 256 woorden, kreeg {len(woorden)}")
    return woorden


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    base = sys.argv[1].rsplit(".", 1)[0]
    for naam, data in zip(("hi", "mid", "lo"), split(lees_hex(sys.argv[1]))):
        open(f"{base}_{naam}.bin", "wb").write(data)
        print(f"{base}_{naam}.bin: {len(data)} bytes")
```

```python
# FILE: tta_hw/test_split_rom.py
# De drie EEPROM-bestanden moeten samen precies de oorspronkelijke 24-bit-woorden opleveren.
import random
from split_rom import split
from tta_asm import assemble

prog = assemble(open("sum.tta").read())[0]
hi, mid, lo = split(prog)
assert len(hi) == len(mid) == len(lo) == 256
for k, w in enumerate(prog):
    assert (hi[k] << 16 | mid[k] << 8 | lo[k]) == w, k
# De velden die de hardware gebruikt: hi = guard[7:5] + bestemming[4:0], mid = bron[4:0]
assert hi[0] == 0x01 and mid[0] == 0x00 and lo[0] == 0x00     # '#0 -> R0': bestemming R0 = 1
woorden = [random.getrandbits(24) for _ in range(256)]
h, m, l = split(woorden)
assert all(h[i] << 16 | m[i] << 8 | l[i] == woorden[i] for i in range(256))
print("PASS: split_rom splitst 24-bit-woorden in drie bytebestanden zonder verlies")
```

```text
python3 tta_asm.py sum.tta
python3 split_rom.py sum.hex        # maakt sum_hi.bin, sum_mid.bin, sum_lo.bin
```

Programmeer elke chip met een EEPROM-programmer (bijvoorbeeld een goedkope USB-programmer of een Arduino-schakeling zoals Ben Eater beschrijft) met zijn eigen bestand, op adres 0. De rest van de 32 KB mag leeg blijven: de adreslijnen A8 tot en met A14 sluit je aan op massa.

> **`MEM -> MEM` bestaat niet.** Op het bord zouden lezen en schrijven dan tegelijk de bus aansturen. De assembler weigert hem.

## 10. KiCad en de printplaat: het plan

KiCad is een open-source ontwerpprogramma voor schema's en printplaten. Het is een grote installatie. Wil je niets installeren, dan zijn er online alternatieven zoals EasyEDA. De werkwijze is in beide gelijk. Dit deel is niet in de praktijk uitgevoerd, het is een plan.

### Stap voor stap

1. Schema. Teken het schema per blok op aparte bladen (hiërarchische bladen): klok en reset, PC en ROM, decoders en guard, registers en bus, rekeneenheid, en geheugen en I/O. Gebruik de bibliotheek `74xx` voor de chips. Geef de chips dezelfde namen als in `t8_board.v` (`U_PC_LO`, ...), zodat schema en model één op één samenvallen.
2. Bus. Gebruik busnetten (`D[0..7]`) met netlabels. Zet op elk blad dezelfde namen.
3. Voeding. Elke chip krijgt een condensator van 100 nF tussen VCC en GND, zo dicht mogelijk bij de pinnen. Plaats power flags en teken de voedingsnetten expliciet.
4. Ongebruikte ingangen. Elke ingang van een chip moet ergens aan hangen, nooit zwevend (week 2). Ongebruikte poorten leg je vast op massa of VCC.
5. ERC. Laat de elektrische regelcontrole (ERC) draaien tot er geen fouten meer zijn.
6. Footprints. Kies voor elke chip de footprint van een DIP-voetje (DIP-14, 16, 20 of 28).
7. Indeling. Leg de chips in rijen, zodat de bus als een rechte strook langs de registers loopt. Groepeer wat bij elkaar hoort (alle registers aan de bus, de rekeneenheid ernaast).
8. Printbanen. Leg eerst de bus, dan de besturingslijnen en dan de rest. Gebruik brede banen voor voeding en massa. Een massavlak (ground fill) aan beide zijden helpt.
9. DRC. Laat de designregelcontrole draaien met de minimale baanbreedte en afstand van de printfabrikant.
10. Exporteren. Maak Gerber-bestanden en een boorbestand, controleer ze in een viewer en bestel.

### Maat en lagen

Een print van ongeveer 160 × 100 mm met twee lagen is haalbaar. Hij hoeft niet klein te zijn, want DIP-chips zijn groot. Bij 59 chips is het verstandig ruim te plaatsen, dat maakt het routeren makkelijker. Een print met vier lagen en aparte voedingsvlakken is robuuster maar duurder. Voor 1 MHz zijn twee lagen met een goed massavlak genoeg.

### Opbouw en ingebruikname

1. Controleer vóór het solderen met de doorgangstest van je multimeter op kortsluiting: er mag geen verbinding zijn tussen VCC en GND.
2. Soldeer eerst de voetjes en condensatoren, nog geen chips. Test opnieuw op kortsluiting.
3. Zet de voeding aan zonder chips. Controleer de spanning op de VCC-pinnen van alle voetjes.
4. Bouw in stappen. Plaats eerst de klok, de enkelstap en de PC en controleer met LED's dat de PC telt. Plaats dan ROM en buffer en laat de PC door een programma van `NOP`'s lopen. Plaats dan decoders en één register, voer `#5 -> R0` uit en bekijk R0 op de bus. Daarna volgen de rest van de registers, de rekeneenheid, het RAM en de I/O.
5. Test elk blok met een kort programma dat je vooraf met de simulator hebt gecontroleerd.
6. Pas als alles werkt komen de kristaloscillator en een echt programma.

### Debuggen met wat je geleerd hebt

- Heb je een logic analyzer (week 8)? Kijk naar de klok, de bestemmingspuls van een register en de bus tegelijk. Je zou de puls midden in de cyclus moeten zien, in het stabiele deel van de bus.
- Een chip die warm wordt, wijst op een busconflict (twee uitgangen tegelijk aan) of op kortsluiting.
- Vergelijk met de simulator: draai hetzelfde programma en vergelijk de registers per stap.
- Gebruik de enkelstapsklok: één move per druk op de knop, terwijl je naar de LED's kijkt.

## 11. Lab

1. Draai `tb_t8_board.v` en `tb_t8_board_random.v`. Hoe lang duurt de random-test?
2. Draai `python3 sweep.py` en vergelijk met de tabel hierboven.
3. Sabotage-oefening: haal de OR met de eigen uitgang uit de halt-flipflop weg (`halt_hold`), draai `tb_t8_board.v` en kijk wat de test meldt. Doe hetzelfde met de reset in `u_e2`.
4. Draai `bom.py` en pas de prijzen in het script aan naar actuele aanbiedingen. Wat is je totaal?
5. Maak met `tta_asm.py` en `split_rom.py` de drie ROM-bestanden voor `fib.tta`.
6. Teken, op papier of in KiCad, het blad "programmateller en ROM" van het schema.
7. Bouw op een breadboard de kern: twee 74HC161 (PC), een 74HC244 (adresbuffer), een EEPROM met een handgemaakt programma en LED's op de PC. Laat de PC tellen met een knop als klok.

## 12. Oefeningen

1. Waarom krijgen de bestemmingsregisters hun klokpuls in de tweede helft van de cyclus en niet op de stijgende flank?
2. Het ROM heeft een toegangstijd van 150 ns en de rest van de keten (buffer, decoder, poorten, bus, opteller) kost ongeveer 200 ns. Bereken de maximale klokfrequentie als de keten binnen een halve klokperiode klaar moet zijn.
3. De bus heeft een capaciteit van ongeveer 100 pF en de pull-down is 10 kΩ. Wat is de tijdconstante van het zakken van de bus naar nul als niemand hem aanstuurt? Is dat een probleem bij 1 MHz?
4. Waarom hoort in `u_e2` de reset als ingang? Beschrijf het foutscenario in je eigen woorden.
5. Schat de voedingsstroom van het bord (neem aan dat de EEPROM's en het RAM elk ongeveer 30 mA gebruiken en de andere chips samen ongeveer 100 mA bij 1 MHz). Volstaat een USB-voeding van 500 mA?
6. Wat verandert er in het schema als je R4 tot en met R7 toevoegt (vier registers meer)? Tel de chips en noem de aanpassing aan de decoders.
7. Waarom is `MEM -> MEM` op het bord niet toegestaan?
8. Uitdaging: ontwerp een tweede bus, zodat twee moves per cyclus mogelijk zijn. Wat verandert er in het ROM, de decoders en de registers? Welke conflicten moeten de programmeur of de assembler vermijden?

## 13. Antwoorden

1. Klok je een register op de stijgende flank terwijl tegelijk de PC verandert en het ROM een nieuwe instructie levert, dan kan de bus net veranderen als het register zijn data neemt: een race (houdtijd). Door in de tweede helft te klokken zijn de bus en alle besturingssignalen al lang stabiel en blijven ze dat tot na de volgende stijgende flank.
2. Halve periode ≥ 150 + 200 = 350 ns, dus periode ≥ 700 ns, ongeveer 1,4 MHz. Met marge kies je 1 MHz.
3. τ = R·C = 10 kΩ × 100 pF = 1 µs. De bus zakt dus in enkele microseconden, veel langzamer dan de klok bij 1 MHz. Dat is geen probleem, want de bus wordt elke cyclus actief aangestuurd door de gekozen bron en de pull-down is alleen voor ongebruikte bronnen. Het is wel de reden dat de houdtijd van een bus na een uitgang naar Z gunstig is.
4. Tijdens een reset (of vlak erna) zakken de vlaggen en de halt-flipflop met verschillende vertragingen. De guard `go` en `halted_n` kunnen even een waarde geven die een korte schrijfpuls laat ontstaan. Een register, het RAM of de uitvoer krijgt dan een willekeurige waarde. Met de reset als ingang van `e2` blijven alle pulsen uit zolang de reset actief is.
5. Drie EEPROM's en één RAM: 4 × 30 mA = 120 mA. De overige chips samen zijn ongeveer 100 mA, dus ongeveer 220 mA. Dertig LED's van elk 5 mA komen daar nog eens 150 mA bij: samen ongeveer 370 mA. Dat past in de 500 mA van een USB-poort, maar met weinig marge. Gebruik zuinige LED's (1 tot 2 mA) of een aparte voeding.
6. Vier extra 74HC574 (registers) en vier extra bronnen in de decoders. De brondecoder `u_s1` heeft nog vrije uitgangen (bronnen 12 tot 15), en de bestemmingsdecoder `u_d3` ook (24 tot 30). Het gedragsmodel, de assembler en de decodertabellen moeten dezelfde nummers krijgen. Reken op 4 chips voor de registers, plus de AND-poorten voor de pulsen (een extra 74HC08).
7. Een move leest de bron en schrijft de bestemming in dezelfde cyclus. Bij `MEM -> MEM` zou het RAM zijn data op de bus zetten (OE' laag) terwijl hij ook schrijft (WE' laag): de datapinnen zouden tegelijk uitgang en ingang zijn. Het resultaat is ongedefinieerd.
8. Het ROM wordt twee keer zo breed (twee moves, dus twee keer guard, bron, bestemming en constante). Elke bus krijgt eigen brondecoders en een eigen keuze van wie hem aanstuurt, en elk register moet kiezen van welke bus het neemt (een 2:1-multiplexer ervoor). Conflicten zijn twee moves naar dezelfde bestemming in dezelfde cyclus, en het lezen van een resultaat dat een andere move in dezelfde cyclus nog moet produceren. De assembler moet dat controleren.

## 14. Zelftest

1. Hoeveel chips telt het T8-bord ongeveer?
2. Waarom is een pull-down op de bus nodig?
3. Wanneer neemt een doelregister zijn waarde over?
4. Wat bracht de simulatie bij de halt-flipflop aan het licht?
5. Wat is het doel van een buffer op het ROM-adres?

Antwoorden: (1) Ongeveer 59 in het schema. (2) Zodat een bus waar niemand op stuurt 0 leest, zoals in het gedragsmodel. (3) Op de dalende klokflank, in het midden van de cyclus, met een korte puls. (4) Dat hij zichzelf weer uitzette: een stopvlag moet zichzelf vasthouden. (5) Extra vertraging, zodat de bus niet te vroeg verandert.

## 15. Verder lezen

- *The Art of Electronics* (Horowitz en Hill): het hoofdstuk over digitale logica, timing en praktische problemen als ontkoppeling.
- Het datablad van de 74HC574, de 74HC238 en de 28C256. Lees de tabellen met setup- en houdtijden.
- De video's van Ben Eater over de breadboardcomputer en de EEPROM-programmer, vooral de uitleg over de bus en het klokken van registers.
- De KiCad-handleiding "Getting Started": schema, footprints en printontwerp.

Volgende week: het slot van de cursus. Je maakt een eindopdracht en kijkt naar de laatste stap, echt silicium, met het open-source programma Tiny Tapeout.
