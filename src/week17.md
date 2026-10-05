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

Hieronder staat het hele programma, ongeveer 190 regels. Lees het van boven naar beneden. `assemble(source)` is de kern: pas 1 en pas 2. `parse_number`, `reg`, `imm8` en `mem_operand` zijn kleine hulpfuncties met nette foutmeldingen. `main` leest een bestand en schrijft `.hex` (instructies) en `.dat` (data).

```python
# FILE: cpu/asm.py
#!/usr/bin/env python3
"""Assembler voor de 8-bit CPU van deze cursus.

Gebruik:  python3 asm.py programma.asm            -> programma.hex (en programma.dat bij .data)
          python3 asm.py programma.asm --list     -> met listing op het scherm
"""
import re
import sys

REGS = {f"R{i}": i for i in range(8)} | {"LR": 7}
ALU3 = {"ADD": 0, "SUB": 1, "AND": 2, "OR": 3, "XOR": 4}
ALU2 = {"NOT": 5, "SHL": 6, "SHR": 7}
CONDS = {"B": 0, "BEQ": 1, "BZ": 1, "BNE": 2, "BNZ": 2, "BCS": 3, "BHS": 3,
         "BCC": 4, "BLO": 4, "BLT": 5, "BGE": 6, "BMI": 7}


class AsmError(Exception):
    pass


def parse_number(tok, symbols, line_no):
    tok = tok.strip()
    try:
        if tok in symbols:
            return symbols[tok]
        if re.fullmatch(r"-?0[xX][0-9a-fA-F]+", tok):
            return int(tok, 16)
        if re.fullmatch(r"-?0[bB][01]+", tok):
            return int(tok, 2)
        return int(tok, 10)
    except ValueError:
        raise AsmError(f"regel {line_no}: onbekend getal of label '{tok}'")


def reg(tok, line_no):
    r = tok.strip().upper()
    if r not in REGS:
        raise AsmError(f"regel {line_no}: '{tok.strip()}' is geen register (R0..R7)")
    return REGS[r]


def imm8(value, line_no):
    if not -128 <= value <= 255:
        raise AsmError(f"regel {line_no}: waarde {value} past niet in 8 bit (-128..255)")
    return value & 0xFF


def split_operands(text):
    # splitst op komma's maar niet binnen [ ]
    parts, depth, cur = [], 0, ""
    for ch in text:
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur.strip())
    return parts


def mem_operand(tok, symbols, line_no):
    m = re.fullmatch(r"\[\s*(\w+)\s*(?:\+\s*([\w\-x]+))?\s*\]", tok.strip())
    if not m:
        raise AsmError(f"regel {line_no}: verwacht [Rn] of [Rn+offset], kreeg '{tok}'")
    base = reg(m.group(1), line_no)
    off = parse_number(m.group(2), symbols, line_no) if m.group(2) else 0
    if not 0 <= off <= 63:
        raise AsmError(f"regel {line_no}: offset {off} moet tussen 0 en 63 liggen")
    return base, off


def assemble(source):
    """Geeft (programma: lijst van 256 woorden, data: lijst van 256 bytes, listing)."""
    lines = []
    for n, raw in enumerate(source.splitlines(), 1):
        text = raw.split(";")[0].strip()
        if text:
            lines.append((n, text))

    symbols, items, pc = {}, [], 0
    data = [0] * 256
    uses_data = False

    # Eerste ronde: adressen van labels bepalen, .equ en .data verwerken.
    for n, text in lines:
        while True:
            m = re.match(r"^([A-Za-z_]\w*)\s*:\s*(.*)$", text)
            if not m:
                break
            label, text = m.group(1), m.group(2)
            if label in symbols:
                raise AsmError(f"regel {n}: label '{label}' bestaat al")
            symbols[label] = pc
        if not text:
            continue
        head, _, rest = text.partition(" ")
        head = head.upper()
        if head == ".EQU":
            name, val = [x.strip() for x in rest.split(",", 1)]
            symbols[name] = parse_number(val, symbols, n)
        elif head == ".ORG":
            pc = parse_number(rest, symbols, n)
        elif head == ".DATA":
            parts = split_operands(rest)
            addr = parse_number(parts[0], symbols, n)
            for k, v in enumerate(parts[1:]):
                if addr + k > 255:
                    raise AsmError(f"regel {n}: data voorbij adres 255")
                data[addr + k] = parse_number(v, symbols, n) & 0xFF
            uses_data = True
        else:
            items.append((pc, n, head, rest))
            pc += 1
            if pc > 256:
                raise AsmError(f"regel {n}: programma is langer dan 256 instructies")

    # Tweede ronde: instructies coderen.
    prog = [0xA000] * 256
    listing = []
    for addr, n, op, rest in items:
        ops = split_operands(rest)

        def need(k):
            if len(ops) != k:
                raise AsmError(f"regel {n}: {op} verwacht {k} operand(en), kreeg {len(ops)}")

        if op in ALU3:
            need(3)
            word = (0 << 12) | (reg(ops[0], n) << 9) | (reg(ops[1], n) << 6) | (reg(ops[2], n) << 3) | ALU3[op]
        elif op in ALU2:
            need(2)
            word = (reg(ops[0], n) << 9) | (reg(ops[1], n) << 6) | ALU2[op]
        elif op == "MOV":
            need(2)
            rs = reg(ops[1], n)
            word = (reg(ops[0], n) << 9) | (rs << 6) | (rs << 3) | ALU3["OR"]
        elif op in ("LDI", "ADDI", "CMPI"):
            need(2)
            code = {"LDI": 1, "ADDI": 2, "CMPI": 7}[op]
            word = (code << 12) | (reg(ops[0], n) << 9) | imm8(parse_number(ops[1], symbols, n), n)
        elif op in ("LD", "ST"):
            need(2)
            base, off = mem_operand(ops[1], symbols, n)
            code = 3 if op == "LD" else 4
            word = (code << 12) | (reg(ops[0], n) << 9) | (base << 6) | off
        elif op == "CMP":
            need(2)
            word = (6 << 12) | (reg(ops[0], n) << 6) | (reg(ops[1], n) << 3)
        elif op in CONDS:
            need(1)
            target = parse_number(ops[0], symbols, n)
            if not 0 <= target <= 255:
                raise AsmError(f"regel {n}: sprongdoel {target} ligt buiten 0..255")
            word = (5 << 12) | (CONDS[op] << 9) | target
        elif op == "CALL":
            need(1)
            word = (8 << 12) | parse_number(ops[0], symbols, n)
        elif op == "JR":
            need(1)
            word = (9 << 12) | (reg(ops[0], n) << 6)
        elif op == "RET":
            need(0)
            word = (9 << 12) | (7 << 6)
        elif op == "NOP":
            need(0)
            word = 0xA000
        elif op in ("RETI", "EI", "DI"):          # interrupts: zie week 22
            need(0)
            word = {"RETI": 0xB000, "EI": 0xC000, "DI": 0xD000}[op]
        elif op == "HALT":
            need(0)
            word = 0xF000
        else:
            raise AsmError(f"regel {n}: onbekende instructie '{op}'")
        prog[addr] = word
        listing.append(f"{addr:02X}: {word:04X}   {op} {rest}".rstrip())
    return prog, data, listing, uses_data


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    path = argv[1]
    try:
        prog, data, listing, uses_data = assemble(open(path).read())
    except AsmError as e:
        print(f"FOUT: {e}", file=sys.stderr)
        return 1
    base = path.rsplit(".", 1)[0]
    with open(base + ".hex", "w") as f:
        f.write("\n".join(f"{w:04X}" for w in prog) + "\n")
    if uses_data:
        with open(base + ".dat", "w") as f:
            f.write("\n".join(f"{b:02X}" for b in data) + "\n")
    if "--list" in argv:
        print("\n".join(listing))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

Een paar dingen om op te letten. Het programma geeft fouten met een regelnummer (`AsmError`) en geen kale Python-fout. Dat maakt het verschil tussen een tool die je wilt gebruiken en een die je laat liggen. `MOV rd, rs` is geen echte instructie: de assembler maakt er `OR rd, rs, rs` van. Zo'n verkorting heet een pseudo-instructie. Negatieve getallen in `ADDI` worden met `& 0xFF` omgezet naar twee-complement. En ongebruikte plaatsen in het geheugen worden gevuld met `NOP` (0xA000).

### De test van de assembler

Een assembler die één bit verkeerd codeert, veroorzaakt mysterieuze bugs in elk programma. Test hem daarom grondig. De test bevat dezelfde woorden die je in week 13 met de hand hebt berekend, plus labels, `.equ`, `.data`, `.org` en alle foutmeldingen.

```python
# FILE: cpu/test_asm.py
# Tests voor de assembler: bekende codes, fouten, labels en negatieve getallen.
from asm import assemble, AsmError


def code(regel):
    prog, _, _, _ = assemble(regel)
    return prog[0]


def moet_falen(bron, deel_van_melding):
    try:
        assemble(bron)
    except AsmError as e:
        assert deel_van_melding in str(e), f"verkeerde melding: {e}"
        return
    raise AssertionError(f"verwachtte een fout voor: {bron!r}")


# Dezelfde woorden als met de hand gecodeerd in week 13.
assert code("LDI R1, 5") == 0x1205
assert code("LDI R2, 7") == 0x1407
assert code("ADD R3, R1, R2") == 0x0650
assert code("ST R3, [R0+9]") == 0x4609
assert code("LD R4, [R0+9]") == 0x3809
assert code("CMP R3, R4") == 0x60E0
assert code("BEQ 0") == 0x5200
assert code("CALL 0x2A") == 0x802A
assert code("RET") == 0x91C0
assert code("JR R7") == 0x91C0
assert code("ADDI R5, -1") == 0x2AFF
assert code("CMPI R2, 10") == 0x740A
assert code("HALT") == 0xF000
assert code("NOP") == 0xA000
assert code("RETI") == 0xB000 and code("EI") == 0xC000 and code("DI") == 0xD000
assert code("MOV R2, R5") == (2 << 9) | (5 << 6) | (5 << 3) | 3   # MOV = OR rd, rs, rs
assert code("LD R1, [R2]") == code("LD R1, [R2+0]")

# Labels (vooruit en achteruit) en .equ
prog, _, _, _ = assemble("""
        .equ AANTAL, 3
start:  LDI R1, AANTAL
        B   einde
        B   start
einde:  HALT
""")
assert prog[0] == 0x1203 and prog[1] == 0x5003 and prog[2] == 0x5000 and prog[3] == 0xF000

# Meerdere labels op één regel, labelnaam op een eigen regel
prog, _, _, _ = assemble("a:\nb: NOP\n   B a\n   B b")
assert prog[1] == 0x5000 and prog[2] == 0x5000

# .data en .org
prog, data, _, uses = assemble(".data 10, 1, 2, 3\n.org 5\nHALT")
assert uses and data[10:13] == [1, 2, 3] and prog[5] == 0xF000

# Fouten
moet_falen("FOO R1", "onbekende instructie")
moet_falen("LDI R9, 1", "geen register")
moet_falen("LDI R1, 300", "past niet")
moet_falen("LD R1, [R2+64]", "offset")
moet_falen("B nergens", "onbekend")
moet_falen("x: NOP\nx: NOP", "bestaat al")
moet_falen("ADD R1, R2", "verwacht 3")

print("PASS: assembler (codering, labels, .equ, .data, .org, foutmeldingen) werkt")
```

Draai:

```text
cd labs/cpu
python3 test_asm.py
```

## 4. Draaien met één commando

We hebben twee hulpmiddelen: een Verilog-programma dat een `.hex`-bestand in de CPU laadt en het resultaat toont, en een script dat alles in één keer doet.

```verilog
// FILE: cpu/tb_run.v
// Draait een geassembleerd programma op de CPU en toont het eindresultaat.
// Gebruik (via run.sh): vvp w8run.vvp +prog=programma.hex [+data=programma.dat]
module tb_run;
  reg clk = 0, rst_n = 0;
  wire halted, fz, fn, fc, fv;
  wire [7:0] pc, r0, r1, r2, r3, r4, r5, r6, r7;
  reg [8*64-1:0] pnaam, dnaam;
  integer cycli = 0, k;

  cpu #("none", 0, "none", 0) dut(clk, rst_n, halted, pc, r0, r1, r2, r3, r4, r5, r6, r7, fz, fn, fc, fv);
  always #5 clk = ~clk;

  initial begin
    #1;   // wacht tot de geheugens zich zelf geïnitialiseerd hebben
    if (!$value$plusargs("prog=%s", pnaam)) begin
      // Zonder argumenten doen we niets en melden we PASS, zodat een regressiescript er niet over struikelt.
      $display("PASS: tb_run zonder programma. Gebruik: vvp w8run.vvp +prog=programma.hex [+data=programma.dat]");
      $finish;
    end
    $readmemh(pnaam, dut.im.mem);
    if ($value$plusargs("data=%s", dnaam)) $readmemh(dnaam, dut.dm.mem);
    #21 rst_n = 1;
    while (!halted && cycli < 1000000) begin @(negedge clk); cycli = cycli + 1; end
    if (!halted) $display("WAARSCHUWING: programma stopte niet binnen 1.000.000 cycli");
    $display("Klaar na %0d cycli (%0d instructies)", cycli, cycli / 2);
    $display("R0=%3d R1=%3d R2=%3d R3=%3d R4=%3d R5=%3d R6=%3d R7=%3d", r0, r1, r2, r3, r4, r5, r6, r7);
    $display("Vlaggen ZNCV = %b%b%b%b   PC = %0d", fz, fn, fc, fv, pc);
    $finish;
  end
endmodule
```

```bash
# FILE: cpu/run.sh
#!/bin/bash
# Gebruik: bash run.sh programma.asm
# Assembleert het programma en draait het op de W8-CPU in de simulator.
python3 asm.py "$1" || exit 1
base="${1%.asm}"
iverilog -g2012 -o w8run.vvp tb_run.v alu.v idecode.v memories.v datapath.v control.v cpu.v || exit 1
if [ -f "$base.dat" ]; then
  vvp w8run.vvp +prog="$base.hex" +data="$base.dat"
else
  vvp w8run.vvp +prog="$base.hex"
fi
```

Gebruik:

```text
bash run.sh sum.asm
```

Je krijgt de eindtoestand: registers, vlaggen en aantal cycli.

## 5. Voorbeeldprogramma's

Bestudeer elk programma. Ze laten patronen zien die je steeds weer tegenkomt.

### Som van 1 tot 10

```text
; FILE: cpu/sum.asm
; Som van 1 tot 10. Resultaat in R1 (55).
        LDI  R1, 0          ; som
        LDI  R2, 10         ; teller
loop:   ADD  R1, R1, R2
        ADDI R2, -1         ; zet de Z-vlag als R2 nul wordt
        BNE  loop
        HALT
```

Het patroon is een aftellende lus. `ADDI R2, -1` zet de Z-vlag als het nul wordt en `BNE` gebruikt die direct. Een aparte `CMP` is niet nodig.

### Euclides (ggd)

```text
; FILE: cpu/gcd.asm
; Grootste gemene deler van 252 en 105 (Euclides met aftrekken). Resultaat in R1 (21).
        LDI  R1, 252
        LDI  R2, 105
loop:   CMP  R1, R2
        BEQ  done
        BCC  less           ; R1 < R2
        SUB  R1, R1, R2
        B    loop
less:   SUB  R2, R2, R1
        B    loop
done:   HALT
```

Het patroon is vergelijken en vertakken. Na één `CMP` kun je twee sprongen achter elkaar gebruiken, eerst `BEQ` en dan `BCC`. Beide kijken naar dezelfde vlaggen.

### Subroutines

```text
; FILE: cpu/calls.asm
; Subroutines met CALL en RET. R7 bevat het terugkeeradres, dus een geneste aanroep moet het bewaren.
        LDI  R1, 3
        CALL kwadraat       ; R2 = R1 * R1 via herhaald optellen
        MOV  R3, R2         ; bewaar het resultaat
        LDI  R1, 12
        CALL kwadraat
        HALT                ; R3 = 9, R2 = 144
kwadraat:
        LDI  R2, 0
        MOV  R4, R1         ; teller
kloop:  ADD  R2, R2, R1
        ADDI R4, -1
        BNE  kloop
        RET
```

Het patroon is het link register. `CALL` zet het terugkeeradres in R7 en `RET` springt erheen. Een subroutine die zelf een andere subroutine aanroept, moet R7 eerst bewaren (bijvoorbeeld in een ander register), anders raakt ze haar eigen terugweg kwijt.

### 16-bit vermenigvuldigen

```text
; FILE: cpu/mul.asm
; 16-bit product van 200 x 150 met shift-and-add. Resultaat in R5:R4 (0x7530 = 30000).
        LDI  R1, 200        ; vermenigvuldigtal, laag
        LDI  R2, 0          ; vermenigvuldigtal, hoog
        LDI  R3, 150        ; vermenigvuldiger
        LDI  R4, 0          ; product, laag
        LDI  R5, 0          ; product, hoog
        LDI  R6, 8          ; aantal bits
loop:   LDI  R0, 1
        AND  R0, R3, R0     ; is bit 0 van de vermenigvuldiger 1?
        BEQ  skip
        ADD  R4, R4, R1     ; product(laag) += vermenigvuldigtal(laag)
        BCC  nocar
        ADDI R5, 1          ; carry naar het hoge byte
nocar:  ADD  R5, R5, R2     ; product(hoog) += vermenigvuldigtal(hoog)
skip:   SHL  R2, R2         ; vermenigvuldigtal 16 bit naar links
        SHL  R1, R1         ; carry = bit dat uit R1 viel
        BCC  nc2
        ADDI R2, 1
nc2:    SHR  R3, R3         ; volgende bit van de vermenigvuldiger
        ADDI R6, -1
        BNE  loop
        HALT
```

Het patroon is meerdere bytes als één getal. De CPU is 8 bit, maar het product van 200 × 150 = 30 000 past niet in een byte. We gebruiken twee registers (R5:R4) en geven de carry door met `BCC` en `ADDI`. Het algoritme is hetzelfde shift-and-add als in week 12, nu in software.

### Sorteren

```text
; FILE: cpu/sort.asm
; Bubble sort van 8 bytes op adres 16..23 (zonder teken, oplopend).
        .data 16, 90, 3, 200, 17, 55, 1, 128, 77
        LDI  R1, 7          ; aantal doorlopen
outer:  LDI  R2, 0          ; index i
        LDI  R3, 16         ; basisadres
inner:  ADD  R4, R3, R2     ; adres = basis + i
        LD   R5, [R4]       ; a
        LD   R6, [R4+1]     ; b
        CMP  R5, R6
        BCC  noswap         ; a < b: in orde
        ST   R6, [R4]       ; verwissel
        ST   R5, [R4+1]
noswap: ADDI R2, 1
        CMP  R2, R1
        BCC  inner          ; zolang i < R1
        ADDI R1, -1
        BNE  outer
        HALT
```

Het patroon is een wijzer met een offset. `ADD R4, R3, R2` berekent een adres en `LD R6, [R4+1]` leest het volgende element. De `.data`-regel zet de beginwaarden in het datageheugen.

### Priemgetallen

```text
; FILE: cpu/primes.asm
; Zeef van Eratosthenes voor 2..99. Vlaggen op adres 100+n. R3 = aantal priemgetallen (25).
        LDI  R6, 100        ; basisadres van de vlaggen
        LDI  R3, 0          ; aantal priemgetallen
        LDI  R1, 2          ; p = 2
ploop:  ADD  R4, R6, R1
        LD   R5, [R4]       ; vlag van p
        CMPI R5, 0
        BNE  next           ; al doorgestreept: geen priemgetal
        ADDI R3, 1          ; p is priem
        ADD  R2, R1, R1     ; m = 2p
mloop:  CMPI R2, 100
        BCS  next           ; m >= 100: klaar met doorstrepen
        ADD  R4, R6, R2
        LDI  R5, 1
        ST   R5, [R4]       ; streep m door
        ADD  R2, R2, R1     ; m += p
        B    mloop
next:   ADDI R1, 1
        CMPI R1, 100
        BCC  ploop          ; p < 100
        HALT
```

Het patroon is geneste lussen met een tabel in het geheugen. Dit is een eerste echt programma: de zeef van Eratosthenes vindt alle 25 priemgetallen onder 100.

### De test voor alle zes

Zes CPU's tegelijk in één simulatie, elk met een eigen programma. Elk resultaat wordt gecontroleerd.

```verilog
// FILE: cpu/tb_asm.v
// Draait zes door de assembler gemaakte programma's tegelijk, elk op zijn eigen CPU.
module tb_asm;
  reg clk = 0, rst_n = 0;
  wire h_sum, h_mul, h_sort, h_primes, h_gcd, h_calls;
  integer fouten = 0, cycli, k, vorige;

  cpu #("sum.hex", 1)                       c_sum   (.clk(clk), .rst_n(rst_n), .halted(h_sum));
  cpu #("mul.hex", 1)                       c_mul   (.clk(clk), .rst_n(rst_n), .halted(h_mul));
  cpu #("sort.hex", 1, "sort.dat", 1)       c_sort  (.clk(clk), .rst_n(rst_n), .halted(h_sort));
  cpu #("primes.hex", 1)                    c_primes(.clk(clk), .rst_n(rst_n), .halted(h_primes));
  cpu #("gcd.hex", 1)                       c_gcd   (.clk(clk), .rst_n(rst_n), .halted(h_gcd));
  cpu #("calls.hex", 1)                     c_calls (.clk(clk), .rst_n(rst_n), .halted(h_calls));
  always #5 clk = ~clk;

  reg [7:0] verwacht_sort [0:7];

  initial begin
    verwacht_sort[0] = 1;   verwacht_sort[1] = 3;   verwacht_sort[2] = 17;  verwacht_sort[3] = 55;
    verwacht_sort[4] = 77;  verwacht_sort[5] = 90;  verwacht_sort[6] = 128; verwacht_sort[7] = 200;

    #22 rst_n = 1; cycli = 0;
    while (!(h_sum && h_mul && h_sort && h_primes && h_gcd && h_calls) && cycli < 200000) begin
      @(negedge clk); cycli = cycli + 1;
    end
    if (cycli >= 200000) begin fouten = fouten + 1; $display("FAIL: niet alle programma's stopten"); end

    if (c_sum.dp.r[1] !== 8'd55) begin fouten = fouten + 1; $display("FAIL sum: R1 = %0d", c_sum.dp.r[1]); end
    if ({c_mul.dp.r[5], c_mul.dp.r[4]} !== 16'd30000) begin fouten = fouten + 1; $display("FAIL mul: %0d", {c_mul.dp.r[5], c_mul.dp.r[4]}); end
    for (k = 0; k < 8; k = k + 1)
      if (c_sort.dm.mem[16 + k] !== verwacht_sort[k]) begin fouten = fouten + 1; $display("FAIL sort: mem[%0d] = %0d", 16 + k, c_sort.dm.mem[16 + k]); end
    if (c_primes.dp.r[3] !== 8'd25) begin fouten = fouten + 1; $display("FAIL primes: %0d priemgetallen", c_primes.dp.r[3]); end
    if (c_primes.dm.mem[100 + 97] !== 8'd0 || c_primes.dm.mem[100 + 91] !== 8'd1) begin fouten = fouten + 1; $display("FAIL primes: 97 en 91"); end
    if (c_gcd.dp.r[1] !== 8'd21) begin fouten = fouten + 1; $display("FAIL gcd: %0d", c_gcd.dp.r[1]); end
    if (c_calls.dp.r[3] !== 8'd9 || c_calls.dp.r[2] !== 8'd144) begin fouten = fouten + 1; $display("FAIL calls: R3=%0d R2=%0d", c_calls.dp.r[3], c_calls.dp.r[2]); end

    if (fouten == 0) $display("PASS: zes assembly-programma's (som, vermenigvuldigen, sorteren, priemgetallen, ggd, subroutines) kloppen na %0d cycli", cycli);
    $finish;
  end
endmodule
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

```text
; FILE: cpu/popcount.asm
; Telt de bits die 1 zijn in R1 (0xB7 heeft er 6). Resultaat in R2.
        LDI  R1, 0xB7
        LDI  R2, 0
        LDI  R3, 8          ; 8 bits
lus:    SHR  R1, R1         ; carry = het uitgeschoven bit
        BCC  nul
        ADDI R2, 1
nul:    ADDI R3, -1
        BNE  lus
        HALT
```

```text
; FILE: cpu/add16.asm
; 16-bit optelling: (R2:R1) + (R4:R3) = (R6:R5). Hier 0x01FF + 0x0001 = 0x0200.
        LDI  R1, 0xFF       ; eerste getal, laag
        LDI  R2, 0x01       ; eerste getal, hoog
        LDI  R3, 0x01       ; tweede getal, laag
        LDI  R4, 0x00       ; tweede getal, hoog
        ADD  R6, R2, R4     ; hoge bytes eerst (de carry uit het lage byte komt erna)
        ADD  R5, R1, R3     ; lage bytes: zet de carry-vlag
        BCC  klaar
        ADDI R6, 1          ; carry doorgeven
klaar:  HALT
```

```text
; FILE: cpu/strlen.asm
; Lengte van een tekst met 0 als einde. De tekst "HELLO" staat op adres 32.
        .data 32, 72, 69, 76, 76, 79, 0
        LDI  R1, 32         ; wijzer
        LDI  R2, 0          ; lengte
lus:    LD   R3, [R1]
        CMPI R3, 0
        BEQ  klaar
        ADDI R1, 1
        ADDI R2, 1
        B    lus
klaar:  HALT
```

```text
; FILE: cpu/reverse.asm
; Keert de bits van R1 om (0xB4 -> 0x2D). Resultaat in R2.
        LDI  R1, 0xB4
        LDI  R2, 0
        LDI  R3, 8
lus:    SHL  R2, R2         ; ruimte maken
        SHR  R1, R1         ; carry = laagste bit van R1
        BCC  nul
        ADDI R2, 1
nul:    ADDI R3, -1
        BNE  lus
        HALT
```

```text
; FILE: cpu/memcpy.asm
; Kopieert 8 bytes van adres 16 naar adres 48.
        .data 16, 11, 22, 33, 44, 55, 66, 77, 88
        LDI  R1, 16         ; bron
        LDI  R2, 48         ; doel
        LDI  R3, 8          ; aantal
lus:    LD   R4, [R1]
        ST   R4, [R2]
        ADDI R1, 1
        ADDI R2, 1
        ADDI R3, -1
        BNE  lus
        HALT
```

```verilog
// FILE: cpu/tb_answers.v
// Controleert de uitwerkingen van de oefeningen van week 17.
module tb_answers;
  reg clk = 0, rst_n = 0;
  wire h1, h2, h3, h4, h5;
  integer fouten = 0, cycli, k;

  cpu #("popcount.hex", 1)                 c_pop (.clk(clk), .rst_n(rst_n), .halted(h1));
  cpu #("add16.hex", 1)                    c_add (.clk(clk), .rst_n(rst_n), .halted(h2));
  cpu #("strlen.hex", 1, "strlen.dat", 1)  c_len (.clk(clk), .rst_n(rst_n), .halted(h3));
  cpu #("reverse.hex", 1)                  c_rev (.clk(clk), .rst_n(rst_n), .halted(h4));
  cpu #("memcpy.hex", 1, "memcpy.dat", 1)  c_cpy (.clk(clk), .rst_n(rst_n), .halted(h5));
  always #5 clk = ~clk;

  initial begin
    #22 rst_n = 1; cycli = 0;
    while (!(h1 && h2 && h3 && h4 && h5) && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end
    if (c_pop.dp.r[2] !== 8'd6)                         begin fouten = fouten + 1; $display("FAIL popcount: %0d", c_pop.dp.r[2]); end
    if ({c_add.dp.r[6], c_add.dp.r[5]} !== 16'h0200)    begin fouten = fouten + 1; $display("FAIL add16: %h", {c_add.dp.r[6], c_add.dp.r[5]}); end
    if (c_len.dp.r[2] !== 8'd5)                         begin fouten = fouten + 1; $display("FAIL strlen: %0d", c_len.dp.r[2]); end
    if (c_rev.dp.r[2] !== 8'h2D)                        begin fouten = fouten + 1; $display("FAIL reverse: %h", c_rev.dp.r[2]); end
    for (k = 0; k < 8; k = k + 1)
      if (c_cpy.dm.mem[48 + k] !== c_cpy.dm.mem[16 + k] || c_cpy.dm.mem[48 + k] === 8'h00) begin
        fouten = fouten + 1; $display("FAIL memcpy: byte %0d", k);
      end
    if (fouten == 0) $display("PASS: uitwerkingen (bits tellen, 16-bit optellen, strlen, bits omkeren, memcpy) kloppen");
    $finish;
  end
endmodule
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
