---
title: "Week 13 · Instructieset-architectuur (ISA) ontwerpen"
---

<p class="subtitle">Fase 4 · Je eerste CPU · ongeveer 11 uur</p>

# Week 13: De instructieset-architectuur

## Wat je na deze week kunt

- uitleggen wat een ISA is en waarom het het contract tussen hardware en software heet
- de belangrijkste ontwerpkeuzes benoemen: registers, instructielengte, adresseringsmodi en voorwaarden
- RISC en CISC, en Harvard en von Neumann, uit elkaar houden
- de W8-instructieset lezen, met de hand assembleren en decoderen
- een instructiedecoder in Verilog schrijven en testen

> **Vanaf deze week bouwen we één CPU, stap voor stap.** In week 13 tot 17 maak je een volledige 8-bit processor met een eigen assembler. Alle bestanden komen in dezelfde map: `labs/cpu/`. Maak die map nu aan.

## 1. Wat is een ISA?

De instructieset-architectuur is de beschrijving van de CPU zoals een programmeur hem ziet: welke registers er zijn, welke instructies, hoe die in bits gecodeerd zijn en wat ze precies doen. Over hoe de hardware dat doet, zegt een ISA niets.

Daar zit de kracht van het idee. Twee verschillende chips kunnen dezelfde ISA hebben. Een programma dat voor x86 is gecompileerd, draait op een Intel-chip uit 1995 en op een AMD-chip van nu, ook al is de binnenkant totaal anders. De ISA is het contract: de hardware belooft zich zo te gedragen en de software rekent erop.

| ISA | Jaar | Stijl | Opmerking |
|-----|------|-------|-----------|
| 6502 | 1975 | 8 bit, accumulator | Apple II, Commodore 64, NES |
| Z80 | 1976 | 8 bit | ZX Spectrum, Game Boy (verwant) |
| x86 | 1978 | CISC, variabele lengte | pc's en servers |
| ARM | 1985 | RISC | vrijwel elke telefoon |
| AVR | 1996 | 8 bit RISC | Arduino |
| RISC-V | 2010 | RISC, open standaard | groeiend, vrij te gebruiken |

## 2. De ontwerpvragen

Elke ISA beantwoordt dezelfde vragen. Hieronder staan ze met de keuze die we voor onze CPU maken. Die heet W8: de 8 staat voor 8 bit, en de W is gewoon een naam.

### De architectuurstijl

| Stijl | Idee | Voorbeeld |
|-------|------|-----------|
| Accumulator | één vast register waar elke instructie mee werkt | 6502 (deels), Ben Eaters SAP-1 |
| Stack | operanden staan op een stapel, registeradressen zijn niet nodig | Forth-machines (week 18) |
| Register-register (load/store) | veel registers, alleen LD en ST raken het geheugen | ARM, RISC-V, W8 |
| Geheugen-geheugen | instructies werken direct op geheugenplaatsen | VAX, deels x86 |

W8 is een load/store-machine met drie operanden. `ADD R3, R1, R2` leest twee registers en schrijft een derde. Rekenen gebeurt alleen op registers, naar het geheugen ga je met `LD` en `ST`.

### Hoe lang is een instructie?

Bij vaste lengte (RISC) is een instructie eenvoudig op te halen en te decoderen, maar het kost wat geheugen. Bij variabele lengte (CISC) is de code compact, maar het decoderen is ingewikkeld. x86 heeft instructies van 1 tot 15 bytes.

W8 gebruikt altijd 16 bit. Eén klok, één woord, één instructie.

### Waar staan de operanden? Adresseringsmodi

| Modus | Betekenis | W8-voorbeeld |
|-------|-----------|--------------|
| Direct in de instructie (immediate) | een constante | `LDI R1, 5` |
| Register | de waarde staat in een register | `ADD R3, R1, R2` |
| Register + offset | adres = register + vaste verschuiving | `LD R4, [R1+3]` |
| Absoluut | het adres staat in de instructie | `B 20`, `CALL 40` |
| Register-indirect | het adres staat in een register | `JR R7` |

### Hoe sla je af? Voorwaarden

Een CPU kan een vergelijking op twee manieren met een sprong combineren. Bij vlaggen (condition codes) zet een eerdere instructie de vlaggen Z, N, C en V en kijkt een sprong ernaar. Zo werkt W8, en ook ARM, x86 en de 6502. De andere manier is vergelijken en springen in één instructie (RISC-V): `BEQ rs1, rs2, doel`. Dan is geen vlaggenregister nodig.

### Hoe roep je een subroutine aan?

Met een stack zet `CALL` het terugkeeradres op de stapel en haalt `RET` het eraf. Dat kan diep genest. Met een link register zet `CALL` het terugkeeradres in een register (ARM: LR, RISC-V: ra). De hardware is dan eenvoudiger, maar de nesting moet je zelf regelen.

W8 heeft R7 als link register. `CALL` schrijft het terugkeeradres naar R7 en `RET` is `JR R7`.

### Eén geheugen of twee?

Bij von Neumann delen programma en data één geheugen. Dat is flexibel (programma's kunnen zichzelf wijzigen of laden), maar instructie en data kunnen niet tegelijk gelezen worden. Bij Harvard zijn er aparte geheugens. Instructie en data zijn tegelijk beschikbaar en er zijn geen conflicten, maar code laden als data kan dan niet.

W8 is Harvard. Het instructiegeheugen heeft 256 woorden van 16 bit en het datageheugen 256 bytes. De meeste kleine microcontrollers (AVR, PIC) zijn ook Harvard.

### RISC en CISC

| | RISC | CISC |
|--|------|------|
| Filosofie | weinig, eenvoudige instructies | veel, krachtige instructies |
| Lengte | meestal vast | variabel |
| Geheugen | alleen load/store | instructies mogen het geheugen gebruiken |
| Compiler | doet meer werk | de hardware doet meer werk |
| Voorbeeld | ARM, RISC-V, W8 | x86 |

Het verschil is tegenwoordig vager. Een moderne x86-chip vertaalt zijn CISC-instructies intern naar RISC-achtige microoperaties.

## 3. De W8-instructieset

### Registers en toestand

| Onderdeel | Beschrijving |
|-----------|-------------|
| R0 ... R7 | acht algemene registers van 8 bit. Alleen R7 heeft een bijzondere rol: `CALL` schrijft het terugkeeradres erin |
| PC | programmateller van 8 bit, kan 256 instructies adresseren |
| Z N C V | vlaggen: nul, negatief, carry, overflow (week 11 en 12) |
| Instructiegeheugen | 256 × 16 bit |
| Datageheugen | 256 × 8 bit |

### Instructieformaten

Elke instructie is 16 bit. De bovenste 4 bits zijn altijd de opcode.

```text
 bit:  15 14 13 12 | 11 10 9 | 8  7  6 | 5  4  3 | 2  1  0
 ALU :   0  0  0  0 |   rd    |   rs1   |   rs2   |   fn
 imm :   op          |   rd    |  0 |        imm8
 mem :   op          |   rd    |   rs1   |      off6
 bcc :   0101        |  cond   |  0 |        adres8
 call:   1000        |  000    |  0 |        adres8
 jr  :   1001        |  000    |   rs1   |   000000
 cmp :   0110        |  000    |   rs1   |   rs2   | 000
```

### Instructietabel

| Opcode | Mnemonic | Gedrag | Vlaggen |
|:------:|----------|--------|:-------:|
| 0 | `ADD rd, rs1, rs2` | rd = rs1 + rs2 | ZNCV |
| 0 | `SUB rd, rs1, rs2` | rd = rs1 − rs2 | ZNCV |
| 0 | `AND` / `OR` / `XOR rd, rs1, rs2` | bitsgewijs | ZNCV (C = V = 0) |
| 0 | `NOT rd, rs1` | rd = ~rs1 | ZNCV (C = V = 0) |
| 0 | `SHL rd, rs1` / `SHR rd, rs1` | schuif 1 plaats; C = uitgeschoven bit | ZNCV (V = 0) |
| 1 | `LDI rd, imm8` | rd = imm8 | geen |
| 2 | `ADDI rd, imm8` | rd = rd + imm8 | ZNCV |
| 3 | `LD rd, [rs1 + off6]` | rd = data[rs1 + off6] | geen |
| 4 | `ST rd, [rs1 + off6]` | data[rs1 + off6] = rd | geen |
| 5 | `Bcc adres` | als voorwaarde: PC = adres | geen |
| 6 | `CMP rs1, rs2` | alleen vlaggen van rs1 − rs2 | ZNCV |
| 7 | `CMPI rd, imm8` | alleen vlaggen van rd − imm8 | ZNCV |
| 8 | `CALL adres` | R7 = adres van de volgende instructie; PC = adres | geen |
| 9 | `JR rs1` | PC = rs1 (`RET` is `JR R7`) | geen |
| A | `NOP` | niets | geen |
| F | `HALT` | de CPU stopt | geen |
| B | `RETI` | *week 22*: terug uit een interrupt | geen |
| C | `EI` | *week 22*: interrupts aan | geen |
| D | `DI` | *week 22*: interrupts uit | geen |
| E | *vrij* | gedraagt zich als NOP | geen |

De fn-codes van opcode 0 zijn precies die van de ALU uit week 11: ADD 0, SUB 1, AND 2, OR 3, XOR 4, NOT 5, SHL 6 en SHR 7.

De assembler kent een paar afkortingen: `MOV rd, rs` is `OR rd, rs, rs`, `RET` is `JR R7` en `B adres` is `Bcc` met de voorwaarde "altijd".

### Voorwaardecodes

| cond | Mnemonic | Voorwaarde | Betekent na `CMP A, B` |
|:----:|----------|-----------|-------------------------|
| 0 | `B` | altijd | |
| 1 | `BEQ` (`BZ`) | Z = 1 | A = B |
| 2 | `BNE` (`BNZ`) | Z = 0 | A ≠ B |
| 3 | `BCS` (`BHS`) | C = 1 | A ≥ B zonder teken |
| 4 | `BCC` (`BLO`) | C = 0 | A < B zonder teken |
| 5 | `BLT` | N ≠ V | A < B met teken |
| 6 | `BGE` | N = V | A ≥ B met teken |
| 7 | `BMI` | N = 1 | resultaat negatief |

### Details die ertoe doen

Een sprongadres is absoluut (0 tot 255). Het adres bij `LD` en `ST` is `(rs1 + off6) mod 256`, en de offset loopt van 0 tot 63, zonder teken. `ADDI` met `0xFF` telt 255 op, wat in 8 bits hetzelfde is als 1 aftrekken. De assembler accepteert daarom `ADDI R2, -1`.

Vlaggen worden alleen veranderd door ALU-instructies, `ADDI`, `CMP` en `CMPI`. `LDI`, `LD`, `ST` en sprongen laten ze met rust. Elke instructie kost 2 klokcycli, ophalen en uitvoeren. Dat bouwen we in week 15.

## 4. Handassembleren

Handassembleren is mnemonics omzetten in bits. Doe dit minstens één keer met pen en papier. Daarna begrijp je de rest van de cursus veel beter.

Neem `ADD R3, R1, R2`:

```text
 opcode  rd   rs1  rs2  fn
 0000    011  001  010  000    →  0000 0110 0101 0000  =  0x0650
```

Een kort programma:

| Adres | Assembly | Binair (op rd rs1 rs2 fn) | Hex |
|:----:|----------|---------------------------|:---:|
| 0 | `LDI R1, 5` | 0001 001 0 00000101 | 1205 |
| 1 | `LDI R2, 7` | 0001 010 0 00000111 | 1407 |
| 2 | `ADD R3, R1, R2` | 0000 011 001 010 000 | 0650 |
| 3 | `ST R3, [R0+9]` | 0100 011 000 001001 | 4609 |
| 4 | `LD R4, [R0+9]` | 0011 100 000 001001 | 3809 |
| 5 | `CMP R3, R4` | 0110 000 011 100 000 | 60E0 |
| 6 | `BEQ 0` | 0101 001 0 00000000 | 5200 |
| 7 | `HALT` | 1111 000 000 000 000 | F000 |

## 5. Lab: de instructiedecoder en een mini-assembler in Verilog

Tot de echte Python-assembler van week 17 gebruiken we iets eenvoudigers: Verilog-functies die een instructiewoord uit zijn velden bouwen. Zo kunnen testbenches programma's laden zonder dat je hex hoeft te typen. Maak `labs/cpu/` aan en sla deze bestanden op.

```{.verilog include="cpu/asm_funcs.vh"}
```

De decoder haalt de velden uit een instructiewoord. In hardware zijn dat alleen draden: een deel van een bus. Een decoder kost dus geen poorten en geen tijd.

```{.verilog include="cpu/idecode.v"}
```

De test controleert twee dingen. Komen de met de hand berekende hex-waarden uit de tabel overeen met wat de functies maken? En vindt de decoder bij 5000 willekeurige woorden elk veld op de juiste plek?

```{.verilog include="cpu/tb_isa.v"}
```

Draai:

```text
cd labs/cpu
iverilog -g2012 -o isa.vvp tb_isa.v idecode.v
vvp isa.vvp
```

Je ziet `PASS`. Een test is pas nuttig als je hem ook ziet falen. Verander in `idecode.v` een bitnummer (bijvoorbeeld `rs2 = ir[5:3]` naar `ir[6:4]`) en kijk wat de testbench meldt.

## 6. Oefeningen

1. Decodeer `0x0A5B`: welke instructie is dit?
2. Codeer `SUB R6, R2, R4` met de hand, in binair en in hex.
3. Decodeer `0x5A14`.
4. Decodeer `0x3C85`, `0x4E41` en `0x7F80`.
5. Hoeveel verschillende 16-bit woorden zijn een geldige ALU-instructie (opcode 0)? En hoeveel daarvan zijn `ADD`?
6. Schrijf een programma dat in R3 het maximum van R1 en R2 zet (zonder teken). Codeer het met de hand.
7. Schrijf een programma dat telt hoeveel bits van R1 gelijk zijn aan 1 en het aantal in R2 zet. Hint: schuif R1 naar rechts en kijk naar de carry.
8. Het instructiegeheugen heeft 256 woorden. Wat moet je veranderen om 4096 instructies te kunnen adresseren, en wat gaat er dan stuk in het huidige formaat?
9. Uitdaging: ontwerp op papier twee instructies `PUSH rd` en `POP rd` voor een stack in het datageheugen. Welke hardware heb je erbij nodig, en welke opcodes gebruik je?

## 7. Antwoorden

1. `0x0A5B` = `0000 101 001 011 011`: opcode 0, rd = 5, rs1 = 1, rs2 = 3, fn = 3 (OR). Het is dus `OR R5, R1, R3`.
2. Opcode 0000, rd = 6 (110), rs1 = 2 (010), rs2 = 4 (100), fn = 1 (001): `0000 110 010 100 001` = 0x0CA1.
3. `0x5A14` = `0101 101 0 00010100`: opcode 5 (Bcc), cond = 5 (BLT), adres = 0x14 = 20. Het is dus `BLT 20`.
4. `0x3C85` is `LD R6, [R2+5]`. `0x4E41` is `ST R7, [R1+1]`. `0x7F80` is `CMPI R7, 0x80`.
5. De opcode ligt vast op 0 en de overige 12 bits zijn vrij: 2¹² = 4096 woorden (sommige gedragen zich gelijk, bijvoorbeeld NOT negeert rs2). Daarvan zijn er voor `ADD` (fn = 0) 8 × 8 × 8 = 512.
6. Een mogelijke oplossing (adres, assembly, hex): `0: CMP R1,R2` (6050), `1: BCS 4` (5604), `2: MOV R3,R2` (0693), `3: B 5` (5005), `4: MOV R3,R1` (064B), `5: HALT` (F000). `BCS` springt als R1 ≥ R2 (zonder teken).
7. Het idee: zet R2 op 0 en herhaal 8 keer: `SHR R1, R1` (de carry bevat het uitgeschoven bit), en als C = 1 dan `ADDI R2, 1`. Gebruik een teller in een ander register voor de 8 herhalingen. In week 17 schrijf je dit met de assembler.
8. Je hebt 12 bits voor de programmateller nodig. In `Bcc` en `CALL` is maar plaats voor 8 bits adres. Je kunt het formaat verbreden (instructies van 20 of 24 bit), relatieve sprongen gebruiken (PC + offset) of een register gebruiken voor het hoge deel van het adres. Dit is precies de afweging die ontwerpers van echte ISA's maken.
9. Je hebt een stackpointer nodig (een register, bijvoorbeeld R6 als afspraak). `PUSH` schrijft `rd` naar `data[SP]` en verlaagt SP. `POP` verhoogt SP en leest. Je gebruikt twee vrije opcodes (B en C) en hebt hardware nodig om SP in dezelfde instructie bij te werken (een extra schrijfpoort of een tweede cyclus). Het kan ook in software met `ST` en `ADDI` als twee aparte instructies.

## 8. Zelftest

1. Wat is een ISA?
2. Wat is het verschil tussen Harvard en von Neumann?
3. Wat betekent load/store-architectuur?
4. Hoeveel bits heeft een W8-instructie en hoe ziet het opcodeveld eruit?
5. Wat doet `CALL`?

Antwoorden: (1) Het contract tussen hardware en software: registers, instructies en hun codering. (2) Harvard heeft aparte geheugens voor programma en data, von Neumann één gedeeld geheugen. (3) Alleen laad- en opslaginstructies raken het geheugen, rekenen gebeurt op registers. (4) 16 bits, waarvan de bovenste vier de opcode zijn. (5) Het schrijft het adres van de volgende instructie naar R7 en springt naar het opgegeven adres.

## 9. Verder lezen

- Harris en Harris, hoofdstuk 6 (architectuur). De MIPS-instructieset die zij gebruiken is verwant aan W8.
- De RISC-V *unprivileged specification*, hoofdstuk 2 (RV32I): een moderne, vrij beschikbare ISA. Je herkent veel ideeën.
- Het datasheet van de AVR ATmega328 (Arduino): bekijk de instructiesettabel en vergelijk met W8.

Volgende week: de ISA is een belofte. Nu bouwen we de machine die haar waarmaakt, te beginnen met het datapath: de registers, de ALU en de wegen ertussen.
