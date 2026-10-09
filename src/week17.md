---
title: "Week 17 · Een assembler in Python en echte programma's"
---

<p class="subtitle">Fase 4 · Je eerste CPU · ongeveer 12 uur</p>

# Week 17: Een assembler en echte programma's

## Wat je na deze week kunt

- uitleggen wat een assembler doet en hoe een assembler met twee passen werkt
- een assembler in Python lezen, testen en uitbreiden
- assembly voor W8 schrijven met labels, constanten en data
- typische patronen (lussen, 16-bit rekenen, subroutines, wijzers) toepassen
- een programma assembleren en in één stap op je CPU draaien

## 1. Waarom een assembler?

Tot nu toe schreef je programma's met functies als `I_LDI(1, 5)`. Dat is prima voor een testbench, maar een echt programma van 100 regels wil je met namen kunnen schrijven:

```text
        LDI  R1, 10
lus:    ADDI R1, -1
        BNE  lus
```

Een assembler is een programma dat zulke tekst omzet in machinecode. Hij doet drie dingen. Hij vertaalt mnemonics naar opcodes en velden (`ADDI` wordt `0010...`). Hij lost labels op, dus `lus` wordt het adres van die regel. En hij meldt fouten met een regelnummer, zodat jij ze kunt herstellen.

Je schrijft hem in Python. Het is de eerste softwaretool voor je eigen CPU. Elke nieuwe processor krijgt zo'n assembler, vaak als eerste.

### Waarom twee passen?

Een sprong naar een label dat later in het programma staat, is lastig: op het moment dat je de sprong tegenkomt, weet je het adres nog niet. De oplossing:

| Pas | Wat gebeurt er |
|-----|----------------|
| Pas 1 | Loop door het programma, tel adressen en zet elk label in een symbolentabel (`lus` → 2). Verwerk ook `.equ`-constanten en `.data`. |
| Pas 2 | Loop opnieuw en codeer nu elke instructie. Alle labels zijn bekend. |

## 2. De syntax

| Element | Voorbeeld | Betekenis |
|---------|-----------|-----------|
| Commentaar | `; tekst` | wordt genegeerd |
| Label | `lus:` | naam voor dit adres; mag op een eigen regel staan |
| Registers | `R0` ... `R7`, `LR` (= R7) | |
| Getallen | `10`, `-1`, `0xFF`, `0b1010` | decimaal, negatief, hex, binair |
| ALU | `ADD rd, rs1, rs2` (ook `SUB`, `AND`, `OR`, `XOR`) | |
| ALU met één bron | `NOT rd, rs`, `SHL rd, rs`, `SHR rd, rs` | |
| Verplaatsen | `MOV rd, rs` | wordt `OR rd, rs, rs` |
| Constanten | `LDI rd, imm`, `ADDI rd, imm` | imm tussen −128 en 255 |
| Geheugen | `LD rd, [rs+off]`, `ST rd, [rs+off]` | off tussen 0 en 63; `[rs]` mag |
| Vergelijken | `CMP rs1, rs2`, `CMPI rd, imm` | |
| Springen | `B`, `BEQ`, `BNE`, `BCS`, `BCC`, `BLT`, `BGE`, `BMI` + label | |
| Subroutines | `CALL label`, `RET`, `JR rs` | |
| Diversen | `NOP`, `HALT` | |
| Interrupts | `RETI`, `EI`, `DI` | pas bruikbaar vanaf week 22 (de CPU van week 15 behandelt ze als `NOP`) |
| `.equ NAAM, waarde` | `.equ AANTAL, 8` | naam voor een constante |
| `.org adres` | `.org 16` | volgende instructie op dit adres |
| `.data adres, b1, b2, ...` | `.data 32, 72, 69` | beginwaarden voor het datageheugen |

## 3. De assembler

Hieronder staat het hele programma, ongeveer 200 regels. Lees het van boven naar beneden. `assemble(source)` is de kern: pas 1 en pas 2. `parse_number`, `reg`, `imm8` en `mem_operand` zijn kleine hulpfuncties met nette foutmeldingen. `main` leest een bestand en schrijft `.hex` (instructies) en `.dat` (data).

```{.python include="cpu/asm.py"}
```

Een paar dingen om op te letten. Het programma geeft fouten met een regelnummer (`AsmError`) en geen kale Python-fout. Dat maakt het verschil tussen een tool die je wilt gebruiken en een die je laat liggen. `MOV rd, rs` is geen echte instructie: de assembler maakt er `OR rd, rs, rs` van. Zo'n verkorting heet een pseudo-instructie. Negatieve getallen in `ADDI` worden met `& 0xFF` omgezet naar twee-complement. En ongebruikte plaatsen in het geheugen worden gevuld met `NOP` (0xA000).

### De test van de assembler

Een assembler die één bit verkeerd codeert, veroorzaakt mysterieuze bugs in elk programma. Test hem daarom grondig. De test bevat dezelfde woorden die je in week 13 met de hand hebt berekend, plus labels, `.equ`, `.data`, `.org` en alle foutmeldingen.

```{.python include="cpu/test_asm.py"}
```

Draai:

```text
cd labs/cpu
python3 test_asm.py
```

## 4. Draaien met één commando

We hebben twee hulpmiddelen: een Verilog-programma dat een `.hex`-bestand in de CPU laadt en het resultaat toont, en een script dat alles in één keer doet.

```{.verilog include="cpu/tb_run.v"}
```

```{.bash include="cpu/run.sh"}
```

Gebruik:

```text
bash run.sh sum.asm
```

Je krijgt de eindtoestand: registers, vlaggen en aantal cycli.

## 5. Voorbeeldprogramma's

Bestudeer elk programma. Ze laten patronen zien die je steeds weer tegenkomt.

### Som van 1 tot 10

```{.text include="cpu/sum.asm"}
```

Het patroon is een aftellende lus. `ADDI R2, -1` zet de Z-vlag als het nul wordt en `BNE` gebruikt die direct. Een aparte `CMP` is niet nodig.

### Euclides (ggd)

```{.text include="cpu/gcd.asm"}
```

Het patroon is vergelijken en vertakken. Na één `CMP` kun je twee sprongen achter elkaar gebruiken, eerst `BEQ` en dan `BCC`. Beide kijken naar dezelfde vlaggen.

### Subroutines

```{.text include="cpu/calls.asm"}
```

Het patroon is het link register. `CALL` zet het terugkeeradres in R7 en `RET` springt erheen. Een subroutine die zelf een andere subroutine aanroept, moet R7 eerst bewaren (bijvoorbeeld in een ander register), anders raakt ze haar eigen terugweg kwijt.

### 16-bit vermenigvuldigen

```{.text include="cpu/mul.asm"}
```

Het patroon is meerdere bytes als één getal. De CPU is 8 bit, maar het product van 200 × 150 = 30 000 past niet in een byte. We gebruiken twee registers (R5:R4) en geven de carry door met `BCC` en `ADDI`. Het algoritme is hetzelfde shift-and-add als in week 12, nu in software.

### Sorteren

```{.text include="cpu/sort.asm"}
```

Het patroon is een wijzer met een offset. `ADD R4, R3, R2` berekent een adres en `LD R6, [R4+1]` leest het volgende element. De `.data`-regel zet de beginwaarden in het datageheugen.

### Priemgetallen

```{.text include="cpu/primes.asm"}
```

Het patroon is geneste lussen met een tabel in het geheugen. Dit is een eerste echt programma: de zeef van Eratosthenes vindt alle 25 priemgetallen onder 100.

### De test voor alle zes

Zes CPU's tegelijk in één simulatie, elk met een eigen programma. Elk resultaat wordt gecontroleerd.

```{.verilog include="cpu/tb_asm.v"}
```

## 6. Tips voor assemblyprogrammeurs

| Wil je ... | Schrijf ... |
|-----------|-------------|
| een register op nul zetten | `LDI R1, 0` |
| een register kopiëren | `MOV R1, R2` |
| 1 aftrekken | `ADDI R1, -1` |
| testen of R1 nul is | `CMPI R1, 0` + `BEQ` |
| negeren (R1 = −R1) | `NOT R1, R1` en `ADDI R1, 1` |
| vermenigvuldigen met 2 | `SHL R1, R1` |
| door 2 delen | `SHR R1, R1` (zonder teken) |
| een lus N keer doorlopen | teller in een register, `ADDI R, -1`, `BNE` |
| een 16-bit optelling doen | lage bytes optellen, `BCC`, `ADDI` op het hoge byte (zie oefening 2) |

Er zijn een paar valkuilen. Vlaggen worden overschreven: `ADD`, `ADDI`, `CMP` en ook `MOV` (dat is een `OR`) veranderen ze, terwijl `LDI`, `LD`, `ST` en sprongen ze met rust laten. Zet een sprong dus direct na de instructie die de vlaggen bepaalt. Offsets lopen van 0 tot 63, dus voor grotere afstanden bereken je het adres eerst in een register. En alle adressen zijn 8 bit, dus wijzers lopen na 255 rond naar 0.

## 7. Lab

1. Draai `bash run.sh` op alle zes de programma's en noteer cycli en eindtoestand.
2. Gebruik `--list`: `python3 asm.py sort.asm --list`. Controleer de codering van drie instructies met de hand.
3. Maak fouten in een `.asm`-bestand (een onbekend label, register R9, offset 70, een te groot getal). Zijn de meldingen duidelijk?
4. Draai `tb_asm.v` en kijk hoeveel cycli de langzaamste (priemgetallen) nodig heeft. Reken uit hoe lang dat op 4 MHz duurt.
5. Schrijf de vijf programma's uit de oefeningen hieronder.

## 8. Oefeningen

1. Schrijf een programma dat telt hoeveel bits van R1 (= 0xB7) 1 zijn. Het resultaat komt in R2 (6).
2. Schrijf een 16-bit optelling: (R2:R1) + (R4:R3) = (R6:R5). Test met 0x01FF + 0x0001 = 0x0200.
3. Schrijf een programma dat de lengte van een tekst bepaalt (de tekst "HELLO" met een 0 erachter, op adres 32).
4. Schrijf een programma dat de bits van R1 omkeert (0xB4 wordt 0x2D).
5. Schrijf een programma dat 8 bytes van adres 16 naar adres 48 kopieert.
6. Breid de assembler uit met de pseudo-instructie `INC rd` (is `ADDI rd, 1`) en `DEC rd`. Voeg een test toe aan `test_asm.py`.
7. Breid de assembler uit met `.byte`-regels binnen de code (die een woord in het instructiegeheugen schrijven). Waar zou je dat voor gebruiken?
8. Uitdaging: schrijf een programma dat de ASCII-tekst "W8" omzet naar hoofdletters of kleine letters, of een eenvoudige 8-bit PRNG (week 6: LFSR) in assembly die 20 waarden naar het geheugen schrijft.

## 9. Antwoorden

De oplossingen voor 1 tot en met 5 staan hieronder. De testbench aan het eind controleert ze allemaal.

```{.text include="cpu/popcount.asm"}
```

```{.text include="cpu/add16.asm"}
```

```{.text include="cpu/strlen.asm"}
```

```{.text include="cpu/reverse.asm"}
```

```{.text include="cpu/memcpy.asm"}
```

```{.verilog include="cpu/tb_answers.v"}
```

6. Voeg in de tweede ronde van `assemble` een tak `elif op in ("INC", "DEC"):` toe, met `need(1)` en een code gelijk aan `(2 << 12) | (reg(ops[0], n) << 9) | (1 if op == "INC" else 0xFF)`. Test het met `assert code("INC R1") == code("ADDI R1, 1")` en `assert code("DEC R1") == code("ADDI R1, -1")`.
7. Parse `.byte waarde` in pas 1 als een item dat een woord in `prog` plaatst. Je gebruikt het voor tabellen met constanten in het programmageheugen, bijvoorbeeld de zevensegmentpatronen. Een Harvard-machine kan die niet direct met `LD` lezen, dus daarvoor heb je een speciale instructie nodig, of je kopieert ze naar het datageheugen.
8. Dit is een open opdracht. De aanpak lijkt op de LFSR van week 6: schuiven, de tapbits XOR'en en met `ST` naar het geheugen schrijven.

## 10. Zelftest

1. Waarom heeft een assembler twee passen?
2. Wat is een pseudo-instructie? Geef een voorbeeld.
3. Wat doet `.equ`?
4. Hoe codeert de assembler `ADDI R1, -1`?
5. Waarom moet je een sprong direct na de instructie zetten die de vlaggen bepaalt?

Antwoorden: (1) Om labels op te lossen die later in het programma staan: pas 1 verzamelt de adressen en pas 2 codeert. (2) Een handig mnemonic dat de assembler vertaalt naar bestaande instructies, zoals `MOV` naar `OR rd, rs, rs`. (3) Het geeft een naam aan een constante. (4) Als `0x2000 | (1 << 9) | 0xFF`: opcode 2, rd = 1, imm8 = 0xFF (het twee-complement van −1). (5) Elke volgende ALU-instructie overschrijft de vlaggen.

## 11. Verder lezen

- Wikipedia: "Assembly language" en "Symbol table".
- *Writing Compilers and Interpreters* van Ronald Mak, hoofdstuk 1, voor het idee achter parsers.
- Kijk eens naar echte assemblers als `ca65` (6502) en GNU `as`, en hoe die macro's en secties aanpakken.

---

> **Fase 4 is af.** Je hebt een instructieset ontworpen, een CPU in Verilog gebouwd met een datapath en microgeprogrammeerde besturing, die geverifieerd tegen een referentiemodel en een assembler geschreven waarmee je echte programma's draait. In fase 5 verruimen we de blik: andere architecturen (stack, TTA), pipelining, geheugenhiërarchie, interrupts en I/O.

Volgende week: een heel andere manier om een computer te bouwen, de stackmachine en de taal Forth.
