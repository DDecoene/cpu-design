---
title: "Bijlagen: naslag bij de cursus"
---

<p class="subtitle">Verilog-spiekbrief · instructiesets · 74HC-chips · gereedschap · woordenlijst</p>

# Bijlage A: Verilog-spiekbrief

## Structuur

```verilog
module naam #(parameter W = 8) (
  input  wire        clk, rst_n,
  input  wire [W-1:0] a,
  output reg  [W-1:0] y
);
  // inhoud
endmodule
```

## Combinatorisch en sequentieel

```verilog
assign y = a & b;                         // een draad aansturen
always_comb begin y = 0; if (s) y = a; end        // combinatorisch: begin met een standaardwaarde
always @(posedge clk or negedge rst_n)           // sequentieel: flipflops
  if (!rst_n) q <= 0; else if (en) q <= d;       // altijd <= in klokgestuurde blokken
```

## Operatoren

| Soort | Operatoren |
|-------|-----------|
| Bitsgewijs | `~ & \| ^` |
| Reductie | `&a \|a ^a` (over alle bits) |
| Logisch | `! && \|\|` |
| Rekenen | `+ - * / %` (vermijd `/` en `%`) |
| Vergelijken | `== != < > <= >=`, `===` voor X/Z |
| Schuiven | `<< >> >>>` (`>>>` houdt het teken) |
| Voorwaarde | `s ? a : b` |
| Samenvoegen | `{a, b}`, `{4{a}}` |
| Getallen | `8'b1010_0101`, `8'hA5`, `4'd9` |

## Handige constructies

```verilog
generate for (i = 0; i < N; i = i + 1) begin : g ... end endgenerate   // hardware herhalen
function automatic [7:0] f(input [7:0] x); f = ~x; endfunction
casez (x) 4'b1???: ...; 4'b01??: ...; default: ...; endcase            // prioriteit
reg [7:0] mem [0:255];            $readmemh("bestand.hex", mem);       // geheugen
```

## Testbench

```verilog
reg clk = 0; always #5 clk = ~clk;                 // klok
initial begin $dumpfile("w.vcd"); $dumpvars(0, tb); ... $finish; end
$display("x=%0d y=%h", x, y);   $random;   @(posedge clk);   #1;
```

## Simulator

```text
iverilog -g2012 -o x.vvp tb.v ontwerp.v        vvp x.vvp
```

## Valkuilen

| Fout | Gevolg |
|------|--------|
| `=` in klokgestuurd blok | races, geen echte flipflops |
| geen standaardwaarde in `always_comb` | ongewilde latch |
| gereserveerd woord als naam (`bit`, `int`) | syntaxfout |
| `always @*` zonder verandering van ingangen | blijft X (gebruik `always_comb`) |
| `initial`-vulling met tegenstrijdige beginwaarden | synthese maakt een ander geheugen (week 23) |
| asynchroon lezend geheugen op een FPGA | alles in flipflops en LUT's (week 24) |

# Bijlage B: de drie instructiesets op één pagina

## W8 (register, 16 bit, week 13 en 22)

| Opcode | Mnemonic | Gedrag |
|:------:|----------|--------|
| 0 | `ADD/SUB/AND/OR/XOR rd,rs1,rs2`, `NOT/SHL/SHR rd,rs1` | ALU, zet ZNCV |
| 1 | `LDI rd,imm8` | rd = imm8 |
| 2 | `ADDI rd,imm8` | rd += imm8, zet ZNCV |
| 3 | `LD rd,[rs1+off6]` | lezen |
| 4 | `ST rd,[rs1+off6]` | schrijven |
| 5 | `B/BEQ/BNE/BCS/BCC/BLT/BGE/BMI adres` | sprong op vlaggen |
| 6 | `CMP rs1,rs2` | vlaggen van rs1 − rs2 |
| 7 | `CMPI rd,imm8` | vlaggen van rd − imm8 |
| 8 | `CALL adres` | R7 = terugkeeradres |
| 9 | `JR rs1` (`RET` = `JR R7`) | PC = rs1 |
| A | `NOP` | |
| B, C, D | `RETI`, `EI`, `DI` | interrupts (W8I) |
| F | `HALT` | |

Formaat: `op(4) | rd(3) | rs1(3) | rs2(3) | fn(3)` en varianten. Voorwaarden: AL, EQ, NE, CS, CC, LT, GE, MI. Geheugenkaart W8I: RAM `00-EF`; `F0` UART data; `F1` UART status; `F2` timer herlaadwaarde; `F3` timer status; `F5` GPIO uit; `F6` GPIO in; `F7` interrupt-aan. R6 is voor interruptroutines gereserveerd; R7 is het link-register.

## S8 (stack, week 18)

Byte `1xxxxxxx` = literal 0..127. Opcodes: `00` NOP, `01` DUP, `02` DROP, `03` SWAP, `04` OVER, `05` +, `06` −, `07` AND, `08` OR, `09` XOR, `0A` INVERT, `0B` 2*, `0C` 2/, `0D` @, `0E` !, `0F` >R, `10` R>, `11` R@, `12` LIT8, `13` JMP, `14` JZ, `15` CALL, `16` EXIT, `17` =, `18` <, `19` ROT, `3F` HALT.

## T8 (transport-triggered, week 19)

Instructie van 24 bit: `guard(3) | bestemming(5) | leeg(3) | bron(5) | constante(8)`.

| Bronnen | | Bestemmingen | |
|---------|--|--------------|--|
| 0 `#const` | 6 `RESHR` | 0 NOP | 10 XOR |
| 1-4 `R0-R3` | 7 `RESNOT` | 1-4 R0-R3 | 11 PC |
| 5 `RES` | 8 `MEM` | 5 OP | 12 MAR |
| 9 `IN` | 10 `PC2` | 6 ADD, 7 SUB | 13 MEM, 14 OUT |
| 11 `FLAGS` | | 8 AND, 9 OR | 15 SHL, 16 ADC, 31 HALT |

Guards: `?Z ?NZ ?C ?NC ?N ?NN`. Verboden: `MEM -> MEM`. Macro's: `JMP`, `CALL` (R3 = link), `RET`.

# Bijlage C: 74HC-chips uit de cursus

| Chip | Wat | Opmerking |
|------|-----|-----------|
| 74HC00/02/04/08/32/86 | NAND, NOR, NOT, AND, OR, XOR | pin 7 = GND, pin 14 = VCC |
| 74HC74 | 2 D-flipflops met set/clear | ongebruikte set/clear naar VCC |
| 74HC138 / 238 | 3-naar-8 decoder (actief laag / hoog) | drie enables |
| 74HC151 | 8-naar-1 multiplexer | |
| 74HC161 | 4-bit synchrone teller met load | RCO voor koppelen |
| 74HC240 / 244 | octal tri-state buffer (inverterend / niet) | |
| 74HC283 | 4-bit opteller | carry-in en carry-uit |
| 74HC574 | octal D-register met tri-state | OE' laag = uitgang aan |
| 28C256 / 62256 | 32K x 8 EEPROM / SRAM | CE', OE', WE' actief laag |

Controleer altijd de pinout en de timing in het datablad van de fabrikant die je koopt. Regels: voeding op elke chip, 100 nF ontkoppeling, geen zwevende ingangen, nooit twee uitgangen samen.

# Bijlage D: de belangrijkste formules

| Wat | Formule |
|-----|---------|
| Ohm | V = I·R |
| Vermogen | P = V·I |
| LED-weerstand | R = (V_voeding − V_led) / I |
| Spanningsdeler | V_uit = V_in · R2 / (R1 + R2) |
| Klokperiode | T ≥ t_clk→Q + t_logica + t_routering + t_setup |
| Uitvoeringstijd | t = instructies × CPI / f |
| Prestatie | MIPS = f / CPI |
| AMAT | hit-tijd + miss-ratio × miss-straf |
| CPI met sprongen | 1 + (sprongen per instructie) × (kans op misser) × straf |
| UART-deler | DIV = f_klok / baudrate |
| Twee-complement | −x = ~x + 1; bereik −2ⁿ⁻¹ ... 2ⁿ⁻¹ − 1 |
| CMOS-vermogen | P ≈ α · C · V² · f |
| 555 astabiel | f ≈ 1,44 / ((R1 + 2·R2)·C) |

# Bijlage E: gereedschap en commando's

| Doel | Commando |
|------|----------|
| Verilog simuleren | `iverilog -g2012 -o x.vvp tb.v ontwerp.v && vvp x.vvp` |
| Alle labs controleren | `python3 extract_labs.py` (in de cursusmap) |
| W8-programma | `python3 asm.py p.asm` en `bash run.sh p.asm` |
| Forth voor S8 | `python3 forth.py p.fs` en `bash runfs.sh p.fs` |
| T8-programma | `python3 tta_asm.py p.tta` en `bash run_tta.sh p.tta` |
| FPGA-stroom | `bash fpga_flow.sh hx8k` |
| Gate-level simulatie | `bash gatesim.sh` |
| Onderdelenlijst | `python3 bom.py` |
| Chipgrootte | `python3 core_size.py`, `bash chip_size.sh` |
| PDF's opnieuw bouwen | `./build.sh` |

# Bijlage F: woordenlijst

| Term | Betekenis |
|------|-----------|
| ALU | arithmetic logic unit: rekent en doet logica |
| ASIC | voor één doel gemaakte chip |
| Bitstream | het bestand dat een FPGA configureert |
| Bus | gedeelde draden waarop één bron tegelijk schrijft |
| CISC / RISC | veel complexe / weinig eenvoudige instructies |
| CPI | cycli per instructie |
| Datapath | registers, ALU en verbindingen |
| FIFO | wachtrij: eerst erin, eerst eruit |
| Flipflop | onthoudt een bit, neemt over op de klokflank |
| FPGA | programmeerbare chip van LUT's en flipflops |
| FSM | toestandsmachine |
| Gate-level simulatie | simulatie van de netlijst na synthese |
| Guard | voorwaarde waaronder een move doorgaat (T8) |
| Hazard | situatie die een pipeline kan verstoren |
| Houdtijd (hold) | hoe lang data stabiel moet blijven na de klokflank |
| ISA | instructieset-architectuur: het contract hardware-software |
| Latch | transparant geheugenelement |
| LUT | lookup table: een functie van 4 ingangen als tabel |
| Metastabiliteit | onbepaalde toestand door schending van setup/hold |
| Microcode | besturing als tabel |
| Moore / Mealy | uitgang hangt van toestand / van toestand en ingang |
| Netlijst | lijst van cellen en hun verbindingen |
| Pipeline | instructies overlappen in opeenvolgende trappen |
| RTL | register-transfer level: beschrijving in Verilog |
| Setup | hoe lang data stabiel moet zijn voor de klokflank |
| Slack | marge tussen beschikbare tijd en padvertraging |
| Synchronizer | twee flipflops voor een asynchroon signaal |
| Synthese | RTL omzetten naar poorten en flipflops |
| TTA | transport-triggered architecture: alleen MOVE |
| Tri-state | uitgang die 0, 1 of losgekoppeld (Z) kan zijn |
| UART | seriële poort |
| VCD | bestand met golfvormen |
