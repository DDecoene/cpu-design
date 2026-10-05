---
title: "Week 8 · Geheugen (RAM/ROM) en de bus"
---

<p class="subtitle">Fase 2 · Geheugen en tijd · ongeveer 12 uur</p>

# Week 8: Geheugen en de bus

## Wat je na deze week kunt

- uitleggen hoe een geheugenchip is opgebouwd (adres, data, besturing)
- RAM, ROM en EEPROM uit elkaar houden
- een registerbestand (register file) ontwerpen
- uitleggen hoe een bus met tri-state uitgangen werkt en wat een busconflict is
- geheugen en bus modelleren en testen in Verilog
- uitleggen waarom een ROM ook als logica kan dienen

## 1. Het geheugenmodel

Een geheugen is een grote tabel met genummerde vakjes. Je geeft een adres en je leest of schrijft een woord (hier meestal 8 bits).

```text
 adres   inhoud
 0x00    0xA1
 0x01    0x4F
 0x02    0x00
 ...
 0xFF    0x3C
```

Een geheugen met n adresbits heeft 2ⁿ woorden. Met 8 adresbits zijn dat er 256, met 16 bits 65 536 (64 KiB) en met 15 bits 32 768 (32 KiB).

Een geheugenchip heeft altijd drie groepen pinnen:

| Groep | Wat | Richting |
|-------|-----|----------|
| Adres (A0...An) | welk woord | in |
| Data (D0...D7) | de inhoud | in en uit (bidirectioneel) |
| Besturing | CE', OE', WE' | in |

`CE'` (chip enable) zet de chip aan. De apostrof betekent actief laag. `OE'` (output enable) zet de data-uitgangen op de bus. `WE'` (write enable) schrijft wat er op de databus staat.

### Soorten

| Type | Bewaart bij uitzetten? | Schrijfbaar? | Gebruik |
|------|----------------------|--------------|---------|
| SRAM | nee | snel en vrij | werkgeheugen (62256: 32 K × 8) |
| DRAM | nee | snel, moet periodiek ververst worden | groot werkgeheugen in pc's (komt in deze cursus niet voor) |
| ROM | ja | alleen bij productie | vaste code |
| EEPROM / Flash | ja | traag, met een programmer | programma's en tabellen (28C256: 32 K × 8) |

Een SRAM-cel is in wezen twee kruiselings gekoppelde inverters (weet je nog van week 5?) met twee toegangstransistoren. Dat zijn zes transistoren per bit.

### Timing

Een geheugen reageert niet direct. Na een adresverandering duurt het even voordat de data klopt. Dat heet de toegangstijd (access time). Voor een SRAM liggen de waarden meestal tussen 10 en 100 ns, voor een EEPROM vaak tussen 100 en 250 ns. Kijk in het datablad van jouw exemplaar. De toegangstijd bepaalt hoe snel de klok van je CPU mag zijn als die het geheugen in één cyclus moet lezen.

## 2. Geheugen in Verilog

```verilog
// FILE: week08/memory.v
// Synchroon schrijven, asynchroon (combinatorisch) lezen. Net zoals een eenvoudig SRAM.
module ram #(parameter AW = 8, parameter DW = 8) (
  input               clk,
  input               we,
  input      [AW-1:0] addr,
  input      [DW-1:0] din,
  output     [DW-1:0] dout
);
  reg [DW-1:0] mem [0:(1<<AW)-1];

  assign dout = mem[addr];

  always @(posedge clk)
    if (we) mem[addr] <= din;
endmodule

// ROM, gevuld vanuit een hex-bestand.
module rom #(parameter AW = 4, parameter DW = 8, parameter FILE = "prog.hex") (
  input  [AW-1:0] addr,
  output [DW-1:0] dout
);
  reg [DW-1:0] mem [0:(1<<AW)-1];
  integer i;
  initial begin
    for (i = 0; i < (1<<AW); i = i + 1) mem[i] = {DW{1'b0}};
    $readmemh(FILE, mem);
  end
  assign dout = mem[addr];
endmodule
```

`reg [7:0] mem [0:255]` is een array van 256 registers van 8 bits. In een FPGA wordt dit automatisch omgezet in ingebouwd blok-RAM. `$readmemh` laadt een hex-bestand met één waarde per woord en `//` voor commentaar.

```text
// FILE: week08/prog.hex
// Een ROM-inhoud: de eerste 8 woorden (adres 0..7).
A1
4F
00
3C
FF
10
20
5A
```

## 3. Het registerbestand

Een CPU heeft in de chip zelf een klein, supersnel geheugen: de registers (R0...R7). Een registerbestand kan meestal twee registers tegelijk lezen en één schrijven, want een instructie als `ADD R1, R2, R3` leest R2 en R3 en schrijft R1.

```text
        ┌───────────────────────┐
 ra1 ──►│  lees poort 1  ──► rd1│
 ra2 ──►│  lees poort 2  ──► rd2│
 wa  ──►│  schrijf adres        │
 wd  ──►│  schrijf data    (we) │
        └───────────────────────┘
```

Wij houden register 0 hier niet vast op nul. Sommige ontwerpen doen dat wel (RISC-V bijvoorbeeld), en dat bekijken we in week 13.

```verilog
// FILE: week08/regfile.v
module regfile #(parameter DW = 8) (
  input           clk,
  input           we,
  input  [2:0]    wa,
  input  [DW-1:0] wd,
  input  [2:0]    ra1,
  input  [2:0]    ra2,
  output [DW-1:0] rd1,
  output [DW-1:0] rd2
);
  reg [DW-1:0] r [0:7];
  integer i;
  initial for (i = 0; i < 8; i = i + 1) r[i] = {DW{1'b0}};

  assign rd1 = r[ra1];
  assign rd2 = r[ra2];

  always @(posedge clk)
    if (we) r[wa] <= wd;
endmodule
```

## 4. De bus

In een computer praten tientallen onderdelen met elkaar. Voor elke verbinding een eigen draad wordt snel onbeheersbaar. Daarom gebruiken we een bus: een gedeelde bundel draden waarop maar één onderdeel tegelijk mag schrijven en iedereen mag meekijken.

```text
        ┌──────┐   ┌──────┐   ┌──────┐
        │ Reg A│   │ Reg B│   │  ALU │
        └──┬───┘   └──┬───┘   └──┬───┘
           │ (OE_A)   │ (OE_B)   │ (OE_ALU)
   ════════╧══════════╧══════════╧══════════ bus (8 draden)
           │                     │
        ┌──┴───┐              ┌──┴───┐
        │ Reg C│              │  RAM │
        └──────┘              └──────┘
```

### Tri-state

Gewone uitgangen zijn 0 of 1. Een tri-state uitgang heeft een derde toestand: Z (hoge impedantie), alsof hij losgekoppeld is. Alleen onderdelen waarvan de OE (output enable) aan staat zetten data op de bus. De rest laat los.

| OE | Uitgang |
|----|---------|
| 1 | drijft 0 of 1 |
| 0 | Z (losgekoppeld) |

De eerste regel van bussen is dat nooit twee onderdelen tegelijk de bus aansturen. Zet de een een 1 en de ander een 0, dan ontstaat een busconflict: een kortsluiting tussen plus en min via de uitgangstransistoren. Dat kan chips beschadigen. In een simulatie zie je X.

Stuurt niemand de bus aan, dan zweeft hij (Z). Dat is geen conflict, maar de lezers krijgen onzin binnen. Een CPU zorgt er daarom voor dat er altijd precies één bron actief is.

### Echte chips

- 74HC245: bidirectionele bustransceiver van 8 bits met richtingspin (DIR) en OE'.
- 74HC244: buffer van 8 bits met tri-state, in één richting.
- 74HC574: register met tri-state uitgang (OE'), de standaardbouwsteen.

## 5. Bus in Verilog

```verilog
// FILE: week08/bus.v
// Drie bronnen op één bus. Elk zet zijn data alleen op de bus als zijn oe aan staat.
module bus3(
  input  [7:0] a, b, c,
  input        oe_a, oe_b, oe_c,
  output [7:0] bus
);
  assign bus = oe_a ? a : 8'bz;
  assign bus = oe_b ? b : 8'bz;
  assign bus = oe_c ? c : 8'bz;
endmodule
```

Meerdere `assign`-regels op dezelfde `wire` zijn toegestaan: de simulator lost ze op. Z gecombineerd met een waarde geeft die waarde, en twee verschillende waarden geven X (conflict).

## 6. Tests

```verilog
// FILE: week08/tb_mem.v
module tb_mem;
  reg clk = 0, we = 0;
  reg  [7:0] addr = 0, din = 0;
  wire [7:0] dout;
  wire [7:0] rom_out;
  reg  [3:0] rom_addr = 0;
  integer i, fouten = 0;

  ram #(8, 8) r(clk, we, addr, din, dout);
  rom #(4, 8, "prog.hex") m(rom_addr, rom_out);

  always #5 clk = ~clk;

  initial begin
    // Schrijf 16 waarden in het RAM en lees ze terug.
    for (i = 0; i < 16; i = i + 1) begin
      @(negedge clk); addr = i[7:0]; din = i[7:0] * 8'd3 + 8'd7; we = 1;
      @(negedge clk); we = 0;
    end
    for (i = 0; i < 16; i = i + 1) begin
      addr = i[7:0]; #1;
      if (dout !== (i[7:0] * 8'd3 + 8'd7)) begin fouten = fouten + 1; $display("FAIL ram %0d", i); end
    end
    // Zonder we verandert er niets.
    @(negedge clk); addr = 8'd2; din = 8'hEE; we = 0;
    @(negedge clk); if (dout !== 8'd13) begin fouten = fouten + 1; $display("FAIL: schreef zonder we"); end

    // ROM: de bestandsinhoud komt terug.
    rom_addr = 0; #1; if (rom_out !== 8'hA1) begin fouten = fouten + 1; $display("FAIL rom 0: %h", rom_out); end
    rom_addr = 3; #1; if (rom_out !== 8'h3C) begin fouten = fouten + 1; $display("FAIL rom 3: %h", rom_out); end
    rom_addr = 7; #1; if (rom_out !== 8'h5A) begin fouten = fouten + 1; $display("FAIL rom 7: %h", rom_out); end
    rom_addr = 12; #1; if (rom_out !== 8'h00) begin fouten = fouten + 1; $display("FAIL rom leeg: %h", rom_out); end

    if (fouten == 0) $display("PASS: RAM en ROM werken");
    $finish;
  end
endmodule
```

```verilog
// FILE: week08/tb_regfile_bus.v
module tb_regfile_bus;
  reg clk = 0, we = 0;
  reg  [2:0] wa = 0, ra1 = 0, ra2 = 0;
  reg  [7:0] wd = 0;
  wire [7:0] rd1, rd2;
  reg  [7:0] a = 8'h11, b = 8'h22, c = 8'h33;
  reg        oe_a = 0, oe_b = 0, oe_c = 0;
  wire [7:0] bus;
  integer i, fouten = 0;

  regfile #(8) rf(clk, we, wa, wd, ra1, ra2, rd1, rd2);
  bus3 bs(a, b, c, oe_a, oe_b, oe_c, bus);
  always #5 clk = ~clk;

  initial begin
    // Registerbestand: schrijf alle acht, lees er twee tegelijk.
    for (i = 0; i < 8; i = i + 1) begin
      @(negedge clk); wa = i[2:0]; wd = 8'h10 + i[7:0]; we = 1;
    end
    @(negedge clk); we = 0;
    ra1 = 3; ra2 = 6; #1;
    if (rd1 !== 8'h13 || rd2 !== 8'h16) begin fouten = fouten + 1; $display("FAIL regfile: %h %h", rd1, rd2); end

    // Bus: niemand = Z, één = zijn data, twee verschillende = X (conflict).
    #1; if (bus !== 8'bzzzzzzzz) begin fouten = fouten + 1; $display("FAIL: bus niet Z"); end
    oe_b = 1; #1; if (bus !== 8'h22) begin fouten = fouten + 1; $display("FAIL: bus b"); end
    oe_b = 0; oe_c = 1; #1; if (bus !== 8'h33) begin fouten = fouten + 1; $display("FAIL: bus c"); end
    oe_a = 1; #1; if (^bus !== 1'bx) begin fouten = fouten + 1; $display("FAIL: conflict niet zichtbaar: %b", bus); end

    if (fouten == 0) $display("PASS: registerbestand en bus kloppen, conflict wordt X");
    $finish;
  end
endmodule
```

Draai ze:

```text
cd labs/week08
iverilog -g2012 -o a.vvp tb_mem.v memory.v && vvp a.vvp
iverilog -g2012 -o b.vvp tb_regfile_bus.v regfile.v bus.v && vvp b.vvp
```

## 7. Een ROM als logica

Een ROM met n adresbits en m databits kan elke functie van n bits naar m bits uitvoeren, zonder poorten. Je schrijft de waarheidstabel gewoon in het ROM. De zevensegment-decoder van week 4 is zo'n ROM met 4 adresbits en 7 databits: 16 woorden. De hele tabel past op één regel hex.

Dit idee komt in CPU's voortdurend terug. De microcode-besturing van week 15 is een ROM: de ingangen zijn de instructie en de stap in de cyclus, de uitgangen zijn de besturingssignalen. In plaats van K-maps te tekenen schrijf je een tabel. Ben Eater doet het zo, en veel grote CPU's uit de jaren 70 en 80 ook.

## 8. Lab op het breadboard: je eerste bus

Je hebt nodig: 3 × 74HC574, 8 dip-switches, 8 LED's met weerstand (of een LED-bar), 2 gedebouncete drukknoppen en een condensator van 100 nF.

1. Zet drie 74HC574 naast elkaar. Verbind alle uitgangen (Q) met dezelfde 8 draden: dat is de bus. Zet 8 LED's op de bus.
2. Verbind de D-ingangen van register A en B met de 8 dip-switches. Verbind D van register C met de bus.
3. Geef elk register een eigen klokknop en een eigen OE'-schakelaar. OE' = 0 laat het register de bus aansturen. Gebruik je het register niet, zet OE' dan op 1.
4. Zet een waarde op de dip-switches en druk op klok A. Zet een andere waarde en druk op klok B. Zet OE'_A = 0 en klok C: C kopieert A. Doe hetzelfde met B.
5. Zet nu met opzet OE'_A en OE'_B tegelijk aan, met verschillende waarden. Je ziet misschien zwakke LED's of voelt een warme chip. Doe dit hooguit een paar seconden en haal daarna de voeding eraf. Dit is een busconflict. Je hoeft het niet te herhalen.

Bonus: haal je 8-kanaals USB-logic-analyzer erbij. Installeer PulseView (onderdeel van sigrok) en bekijk de bus terwijl je klokt. Voor het eerst zie je echt wat de data doet.

## 9. Oefeningen

1. Een geheugenchip heeft 13 adreslijnen en 8 datalijnen. Wat is de capaciteit in bytes? En bij 16 adreslijnen?
2. Een SRAM heeft een toegangstijd van 70 ns. Welke maximale klokfrequentie kan een CPU hebben als hij het geheugen in één klokperiode leest? Tel alleen de toegangstijd mee.
3. Hoeveel bits ROM heb je nodig voor een zevensegment-decoder (4 naar 7)? Schrijf de inhoud op voor de cijfers 0 tot 3, met de tabel uit week 4.
4. Waarom heeft een registerbestand twee leespoorten maar meestal één schrijfpoort?
5. Op een bus zitten vijf onderdelen. Hoeveel verschillende bronsituaties zijn toegestaan zonder conflict?
6. Je schrijft `assign bus = oe_a ? a : 8'bz;` voor drie bronnen en alle `oe` zijn 0. Wat is dan de waarde op de bus en welk probleem geeft dat in echte hardware?
7. Uitdaging: schrijf een module `ram_bus` met een bidirectionele databus (`inout [7:0] data`), `we` en `oe`, die zich gedraagt als een echte SRAM-chip. Bij `oe` zet hij data op de bus, bij `we` leest hij die. Test hem.

## 10. Antwoorden

1. 2¹³ = 8192 woorden × 1 byte = 8 KiB. 2¹⁶ = 65 536 woorden = 64 KiB.
2. T ≥ 70 ns, dus f ≤ 1 / 70 ns ≈ 14,3 MHz. In werkelijkheid komen er nog setup-tijd en flipflopvertraging bij, dus het wordt lager.
3. 16 woorden × 7 bits = 112 bits. De inhoud (a b c d e f g): 0 is `1111110` (hex 7E), 1 is `0110000` (hex 30), 2 is `1101101` (hex 6D) en 3 is `1111001` (hex 79).
4. Een instructie als `ADD R1, R2, R3` leest twee operanden tegelijk (twee leespoorten) maar maakt één resultaat (één schrijfpoort).
5. Zes: één van de vijf onderdelen is de bron, of niemand stuurt de bus aan. Nooit twee tegelijk.
6. De bus is Z (zwevend). In hardware pikt hij ruis op en krijgen de lezers willekeurige waarden. De oplossing is een pull-up of pull-down, of een standaardbron (bijvoorbeeld een register dat 0 zet).
7. De kern is `assign data = (oe && !we) ? mem[addr] : 8'bz;` en `always @(posedge clk) if (we) mem[addr] <= data;`. Voor de test schrijf je met `we=1` terwijl de testbench zelf de bus aanstuurt. Daarna lees je met `oe=1` en laat de testbench de bus los (`8'bz`).

## 11. Zelftest

1. Wat betekent actief laag?
2. Wat is een toegangstijd?
3. Wat doet een tri-state uitgang als zijn OE uit staat?
4. Wat is een busconflict?
5. Waarom is een ROM ook een logica-element?

Antwoorden: (1) Het signaal doet zijn werk als het 0 is (bijvoorbeeld CE'). (2) De tijd tussen een adresverandering en geldige data. (3) Hij wordt Z, hoogohmig: losgekoppeld. (4) Twee onderdelen sturen tegelijk de bus aan met verschillende waarden. (5) Een ROM kan elke tabel van n invoerbits naar m uitvoerbits opslaan, dus elke logische functie.

## 12. Verder lezen

- Ben Eater: de video's over het bouwen van een 8-bit register, de RAM-module en de bus.
- Harris en Harris, 5.5 (geheugenarrays).
- Het datablad van de 62256 (SRAM) of 28C256 (EEPROM): zoek de timing van de leescyclus op.

---

> **Fase 2 is af.** Je beheerst nu logica, geheugen, tijd, toestandsmachines en bussen, en dat zijn alle bouwstenen van een computer. In fase 3 leer je de taal waarmee professionals ze beschrijven, Verilog, en bouw je de ALU, het hart van de rekenkracht.

Volgende week leren we Verilog goed, want tot nu toe leende je vooral patronen.
