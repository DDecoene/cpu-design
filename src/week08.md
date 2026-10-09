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

```{.verilog include="week08/memory.v"}
```

`reg [7:0] mem [0:255]` is een array van 256 registers van 8 bits. In een FPGA wordt dit automatisch omgezet in ingebouwd blok-RAM. `$readmemh` laadt een hex-bestand met één waarde per woord en `//` voor commentaar.

```{.text include="week08/prog.hex"}
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

```{.verilog include="week08/regfile.v"}
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

```{.verilog include="week08/bus.v"}
```

Meerdere `assign`-regels op dezelfde `wire` zijn toegestaan: de simulator lost ze op. Z gecombineerd met een waarde geeft die waarde, en twee verschillende waarden geven X (conflict).

## 6. Tests

```{.verilog include="week08/tb_mem.v"}
```

```{.verilog include="week08/tb_regfile_bus.v"}
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
