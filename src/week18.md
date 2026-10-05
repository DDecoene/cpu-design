---
title: "Week 18 · Stackmachines en de Forth-taal"
---

<p class="subtitle">Fase 5 · Geavanceerde architecturen · ongeveer 12 uur</p>

# Week 18: Stackmachines en Forth

## Wat je na deze week kunt

- uitleggen hoe een stackmachine rekent en waarom er geen registers in de instructies staan
- Forth lezen en schrijven, met stack-effect-notatie
- een stackmachine (S8) in Verilog bouwen met twee stapels
- een kleine Forth-compiler in Python lezen en gebruiken
- stackmachine en registermachine eerlijk vergelijken op codegrootte en snelheid

## 1. Rekenen zonder registers

Hoe reken je `(3 + 4) × 5` uit? In de gewone notatie heb je haakjes en voorrangsregels nodig. In postfix (omgekeerde Poolse notatie, RPN) schrijf je de operator achteraan: `3 4 + 5 ×`. Er zijn geen haakjes en geen voorrang nodig, en het algoritme is heel eenvoudig:

> Lees van links naar rechts. Is het een getal, zet het dan op een stapel. Is het een operator, haal dan de bovenste twee getallen eraf, reken en zet het resultaat terug.

```text
 3 4 + 5 *
 ─────────────────────────────
 3        → stapel: 3
 4        → stapel: 3 4
 +        → stapel: 7
 5        → stapel: 7 5
 *        → stapel: 35
```

Een CPU die dit doet is een stackmachine. Een instructie als `+` hoeft niet te zeggen welke registers: de operanden zijn altijd de bovenste twee van de stapel. Een instructie is daardoor vaak maar één byte.

Stackmachines zijn niet exotisch:

| Systeem | Wat |
|---------|-----|
| Java Virtual Machine | de bytecode is stackgebaseerd |
| WebAssembly | idem |
| CPython | de bytecode van Python |
| HP-rekenmachines | RPN, de klassieke toetsen |
| Forth-chips | Novix NC4000, Harris RTX2000 (gebruikt in de ruimtevaart), GA144 |

## 2. Forth

Charles Moore bedacht Forth in 1970 om telescopen te besturen met kleine computers. De taal werkt precies zoals een stackmachine.

### Woorden en de stapel

Een Forth-programma is een rij woorden, gescheiden door spaties. Elk woord is een getal (dat op de stapel wordt gezet) of een bewerking. Bij elk woord hoort een stack-effect, tussen haakjes:

```text
( voor -- na )
```

Zo dupliceert `DUP ( a -- a a )` het bovenste getal en telt `+ ( a b -- som )` twee getallen op.

### De woorden van S8

| Woord | Stack-effect | Betekenis |
|-------|-------------|-----------|
| `DUP` | `( a -- a a )` | kopieer de top |
| `DROP` | `( a -- )` | gooi de top weg |
| `SWAP` | `( a b -- b a )` | verwissel de bovenste twee |
| `OVER` | `( a b -- a b a )` | kopieer het tweede element naar boven |
| `ROT` | `( a b c -- b c a )` | draai de bovenste drie |
| `+` `-` | `( a b -- a±b )` | optellen, aftrekken |
| `AND` `OR` `XOR` | `( a b -- r )` | bitsgewijs |
| `INVERT` | `( a -- ~a )` | alle bits omdraaien |
| `2*` `2/` | `( a -- r )` | links of rechts schuiven |
| `=` | `( a b -- vlag )` | gelijk: 255 (waar), anders 0 |
| `<` | `( a b -- vlag )` | kleiner dan, zonder teken |
| `@` | `( adres -- waarde )` | lees uit het geheugen |
| `!` | `( waarde adres -- )` | schrijf naar het geheugen |
| `>R` | `( a -- )` | verplaats de top naar de terugkeerstapel |
| `R>` | `( -- a )` | haal terug van de terugkeerstapel |
| `R@` | `( -- a )` | kopieer de top van de terugkeerstapel |

### Eigen woorden definiëren

Met `:` en `;` maak je een nieuw woord. Dat werkt daarna net zo als de ingebouwde woorden:

```text
: kwadraat ( n -- n*n )  DUP mul ;
```

Je bouwt een programma op door steeds grotere woorden uit kleinere te maken. Het laatste woord is het hele programma.

### Beslissingen en lussen

```text
IF ... ELSE ... THEN        ( vlag -- )   als de vlag niet nul is
BEGIN ... UNTIL             ( vlag -- )   herhaal tot de vlag waar is
BEGIN ... WHILE ... REPEAT  ( vlag -- )   herhaal zolang de vlag waar is
```

### Twee stapels

Naast de datastapel heeft Forth een terugkeerstapel. Daar bewaart `CALL` het terugkeeradres. Je kunt hem ook gebruiken om een getal tijdelijk op te bergen (`>R` en `R>`). Dat is handig, maar je moet hem altijd weer leeg achterlaten voor de volgende `EXIT`.

## 3. De stackmachine S8

S8 is een CPU voor deze taal:

- Het programmageheugen is 256 bytes en het datageheugen ook 256 bytes (Harvard, net als W8).
- De datastapel is 16 bytes en de terugkeerstapel ook 16 bytes.
- Elke instructie is één byte. Sommige hebben een tweede byte als operand.
- Overloop van de stapels wordt niet gecontroleerd. Een slim ontwerp zou dat wel doen, maar hier is het een bewuste vereenvoudiging.

### Instructiecodering

| Byte | Betekenis |
|------|-----------|
| `1xxxxxxx` | literal: zet de 7-bit waarde `xxxxxxx` (0 tot 127) op de stapel |
| `00oooooo` | opcode van 6 bit, zie de tabel hieronder |

| Opcode | Woord | Opcode | Woord |
|:------:|-------|:------:|-------|
| 00 | NOP | 10 | `R>` |
| 01 | DUP | 11 | `R@` |
| 02 | DROP | 12 | LIT8 (de volgende byte is de waarde) |
| 03 | SWAP | 13 | JMP (de volgende byte is het doel) |
| 04 | OVER | 14 | JZ (spring naar de volgende byte als de top 0 is, en haal hem eraf) |
| 05 | `+` | 15 | CALL (zet het terugkeeradres op de terugkeerstapel en spring) |
| 06 | `-` | 16 | EXIT (spring naar het adres bovenop de terugkeerstapel) |
| 07 | AND | 17 | `=` |
| 08 | OR | 18 | `<` |
| 09 | XOR | 19 | ROT |
| 0A | INVERT | 3F | HALT |
| 0B | `2*` | | |
| 0C | `2/` | | |
| 0D | `@` | | |
| 0E | `!` | | |
| 0F | `>R` | | |

Een getal tot 127 kost dus één byte en een groter getal twee (LIT8 plus de waarde).

### De implementatie

```verilog
// FILE: stack/s8.v
// S8: een stackmachine in de geest van Forth.
// Twee stapels (data en terugkeer) van 16 bytes, programmageheugen en datageheugen van 256 bytes.
// Bit 7 = 1: literal (waarde 0..127). Anders is het een opcode van 6 bit.
module s8 #(parameter PROG = "prog.hex", parameter LOAD = 1) (
  input        clk,
  input        rst_n,
  output reg   halted,
  output [7:0] pc_out,
  output [7:0] tos,        // bovenste element van de datastapel (voor debuggen)
  output [3:0] dsp         // aantal elementen op de datastapel
);
  // Opcodes
  localparam NOP = 6'h00, DUP = 6'h01, DROP = 6'h02, SWAP = 6'h03, OVER = 6'h04,
             ADD = 6'h05, SUB = 6'h06, AND_ = 6'h07, OR_ = 6'h08, XOR_ = 6'h09,
             INV = 6'h0A, SHL = 6'h0B, SHR = 6'h0C, LOAD_ = 6'h0D, STORE = 6'h0E,
             TOR = 6'h0F, FROMR = 6'h10, RFETCH = 6'h11, LIT8 = 6'h12, JMP = 6'h13,
             JZ = 6'h14, CALL = 6'h15, EXIT = 6'h16, EQ = 6'h17, LT = 6'h18, ROT = 6'h19,
             HALT = 6'h3F;

  reg [7:0] code [0:255];
  reg [7:0] data [0:255];
  reg [7:0] ds [0:15];       // datastapel
  reg [7:0] rs [0:15];       // terugkeerstapel
  reg [3:0] sp, rsp;         // wijzen naar de eerstvolgende vrije plaats
  reg [7:0] pc;
  reg [5:0] pend;            // opcode die nog een operandbyte nodig heeft
  reg       need_operand;
  integer i;

  wire [3:0] t1 = sp - 4'd1;      // index van het bovenste element
  wire [3:0] t2 = sp - 4'd2;
  wire [3:0] t3 = sp - 4'd3;
  wire [7:0] T = ds[t1];
  wire [7:0] N = ds[t2];
  wire [7:0] R3 = ds[t3];
  wire [7:0] instr = code[pc];

  assign pc_out = pc;
  assign tos = T;
  assign dsp = sp;

  initial begin
    for (i = 0; i < 256; i = i + 1) begin code[i] = 8'h3F; data[i] = 8'h00; end
    if (LOAD) $readmemh(PROG, code);
  end

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      pc <= 0; sp <= 0; rsp <= 0; halted <= 0; need_operand <= 0; pend <= 0;
    end else if (!halted) begin
      if (need_operand) begin
        // Tweede cyclus van een instructie met een operandbyte (code[pc] is die byte).
        need_operand <= 0;
        case (pend)
          LIT8: begin ds[sp] <= instr; sp <= sp + 4'd1; pc <= pc + 8'd1; end
          JMP:  pc <= instr;
          JZ:   begin
                  sp <= sp - 4'd1;
                  pc <= (T == 8'h00) ? instr : pc + 8'd1;
                end
          CALL: begin rs[rsp] <= pc + 8'd1; rsp <= rsp + 4'd1; pc <= instr; end
          default: pc <= pc + 8'd1;
        endcase
      end else if (instr[7]) begin
        // literal 0..127
        ds[sp] <= {1'b0, instr[6:0]}; sp <= sp + 4'd1; pc <= pc + 8'd1;
      end else begin
        pc <= pc + 8'd1;
        case (instr[5:0])
          NOP:    ;
          DUP:    begin ds[sp] <= T; sp <= sp + 4'd1; end
          DROP:   sp <= sp - 4'd1;
          SWAP:   begin ds[t1] <= N; ds[t2] <= T; end
          OVER:   begin ds[sp] <= N; sp <= sp + 4'd1; end
          ROT:    begin ds[t3] <= N; ds[t2] <= T; ds[t1] <= R3; end
          ADD:    begin ds[t2] <= N + T;  sp <= sp - 4'd1; end
          SUB:    begin ds[t2] <= N - T;  sp <= sp - 4'd1; end
          AND_:   begin ds[t2] <= N & T;  sp <= sp - 4'd1; end
          OR_:    begin ds[t2] <= N | T;  sp <= sp - 4'd1; end
          XOR_:   begin ds[t2] <= N ^ T;  sp <= sp - 4'd1; end
          EQ:     begin ds[t2] <= (N == T) ? 8'hFF : 8'h00; sp <= sp - 4'd1; end
          LT:     begin ds[t2] <= (N <  T) ? 8'hFF : 8'h00; sp <= sp - 4'd1; end
          INV:    ds[t1] <= ~T;
          SHL:    ds[t1] <= {T[6:0], 1'b0};
          SHR:    ds[t1] <= {1'b0, T[7:1]};
          LOAD_:  ds[t1] <= data[T];
          STORE:  begin data[T] <= N; sp <= sp - 4'd2; end
          TOR:    begin rs[rsp] <= T; rsp <= rsp + 4'd1; sp <= sp - 4'd1; end
          FROMR:  begin ds[sp] <= rs[rsp - 4'd1]; rsp <= rsp - 4'd1; sp <= sp + 4'd1; end
          RFETCH: begin ds[sp] <= rs[rsp - 4'd1]; sp <= sp + 4'd1; end
          EXIT:   begin pc <= rs[rsp - 4'd1]; rsp <= rsp - 4'd1; end
          LIT8, JMP, JZ, CALL: begin pend <= instr[5:0]; need_operand <= 1; end
          HALT:   begin halted <= 1; pc <= pc; end
          default: ;
        endcase
      end
    end
endmodule
```

Let op een paar dingen. De twee stapels zijn arrays (`ds` en `rs`) met een wijzer (`sp` en `rsp`) die naar de volgende vrije plaats wijst. De top is `ds[sp-1]`. Bij elke klokcyclus voert S8 één stap uit. Instructies met een operandbyte nemen twee cycli, waarbij de tweede de byte op `code[pc]` leest.

Alle werking zit in één groot `case`. Dat maakt een stackmachine zo klein: er zijn geen registeradressen om te decoderen, geen aparte operandvelden en geen opteller voor adressen. In een echte Forth-chip is dit allemaal hardware van een paar honderd poorten.

### Test van de opcodes

De eerste testbench zet bytes met de hand in het geheugen (zonder compiler) en controleert elke opcode:

```verilog
// FILE: stack/tb_s8_basic.v
// Test van de stackmachine met met de hand samengestelde bytes.
module tb_s8_basic;
  reg clk = 0, rst_n = 0;
  wire halted; wire [7:0] pc, tos; wire [3:0] dsp;
  integer fouten = 0, k, cycli;
  s8 #("none", 0) dut(clk, rst_n, halted, pc, tos, dsp);
  always #5 clk = ~clk;

  task run;
    begin
      rst_n = 0; repeat (2) @(negedge clk); rst_n = 1; cycli = 0;
      while (!halted && cycli < 10000) begin @(negedge clk); cycli = cycli + 1; end
      if (!halted) begin fouten = fouten + 1; $display("FAIL: stopte niet"); end
    end
  endtask
  task clear; begin for (k = 0; k < 256; k = k + 1) begin dut.code[k] = 8'h3F; dut.data[k] = 0; end end endtask
  task check(input [7:0] got, input [7:0] want, input [3:0] sp_want, input [255:0] naam);
    if (got !== want || dsp !== sp_want) begin fouten = fouten + 1; $display("FAIL %0s: tos=%0d (verwacht %0d), diepte=%0d (verwacht %0d)", naam, got, want, dsp, sp_want); end
  endtask

  initial begin
    // 3 4 + 5 -   =>  2
    clear;
    dut.code[0] = 8'h83; dut.code[1] = 8'h84; dut.code[2] = 8'h05; dut.code[3] = 8'h85; dut.code[4] = 8'h06; dut.code[5] = 8'h3F;
    run; check(tos, 2, 1, "3 4 + 5 -");

    // 10 DUP *-achtig: 6 DUP +  => 12 ; SWAP/OVER: 1 2 SWAP OVER => 2 1 2 (tos 2, diepte 3)
    clear;
    dut.code[0] = 8'h86; dut.code[1] = 8'h01; dut.code[2] = 8'h05; dut.code[3] = 8'h3F;
    run; check(tos, 12, 1, "6 DUP +");
    clear;
    dut.code[0] = 8'h81; dut.code[1] = 8'h82; dut.code[2] = 8'h03; dut.code[3] = 8'h04; dut.code[4] = 8'h3F;
    run; check(tos, 2, 3, "1 2 SWAP OVER");
    if (dut.ds[0] !== 8'd2 || dut.ds[1] !== 8'd1) begin fouten = fouten + 1; $display("FAIL: SWAP"); end

    // ROT: 1 2 3 ROT => 2 3 1
    clear;
    dut.code[0] = 8'h81; dut.code[1] = 8'h82; dut.code[2] = 8'h83; dut.code[3] = 8'h19; dut.code[4] = 8'h3F;
    run;
    if (dut.ds[0] !== 2 || dut.ds[1] !== 3 || dut.ds[2] !== 1 || dsp !== 3) begin fouten = fouten + 1; $display("FAIL: ROT %0d %0d %0d", dut.ds[0], dut.ds[1], dut.ds[2]); end

    // LIT8, logica, schuiven: 200 (LIT8) 7 AND => 0 ; 200 2/ => 100 ; 5 INV => 250
    clear;
    dut.code[0] = 8'h12; dut.code[1] = 8'd200; dut.code[2] = 8'h87; dut.code[3] = 8'h07; dut.code[4] = 8'h3F;
    run; check(tos, 8'd0, 1, "200 7 AND");
    clear;
    dut.code[0] = 8'h12; dut.code[1] = 8'd200; dut.code[2] = 8'h0C; dut.code[3] = 8'h3F;
    run; check(tos, 8'd100, 1, "200 2/");
    clear;
    dut.code[0] = 8'h85; dut.code[1] = 8'h0A; dut.code[2] = 8'h3F;
    run; check(tos, 8'd250, 1, "5 INV");

    // Geheugen: 42 20 ! 20 @ => 42
    clear;
    dut.code[0] = 8'hAA; dut.code[1] = 8'h94; dut.code[2] = 8'h0E; dut.code[3] = 8'h94; dut.code[4] = 8'h0D; dut.code[5] = 8'h3F;
    run; check(tos, 8'd42, 1, "! en @");
    if (dut.data[20] !== 8'd42) begin fouten = fouten + 1; $display("FAIL: data[20]"); end

    // Terugkeerstapel: 7 >R 9 R> => 9 7
    clear;
    dut.code[0] = 8'h87; dut.code[1] = 8'h0F; dut.code[2] = 8'h89; dut.code[3] = 8'h10; dut.code[4] = 8'h3F;
    run;
    if (dut.ds[0] !== 9 || dut.ds[1] !== 7 || dsp !== 2) begin fouten = fouten + 1; $display("FAIL: >R R>"); end

    // Vergelijkingen: 3 3 = (255), 3 4 = (0), 3 4 < (255), 4 3 < (0)
    clear;
    dut.code[0] = 8'h83; dut.code[1] = 8'h83; dut.code[2] = 8'h17; dut.code[3] = 8'h83; dut.code[4] = 8'h84; dut.code[5] = 8'h17;
    dut.code[6] = 8'h83; dut.code[7] = 8'h84; dut.code[8] = 8'h18; dut.code[9] = 8'h84; dut.code[10] = 8'h83; dut.code[11] = 8'h18; dut.code[12] = 8'h3F;
    run;
    if (dut.ds[0] !== 8'hFF || dut.ds[1] !== 8'h00 || dut.ds[2] !== 8'hFF || dut.ds[3] !== 8'h00) begin fouten = fouten + 1; $display("FAIL: vergelijkingen"); end

    // CALL / EXIT: 5 CALL 10 ... ; routine op 10: DUP + EXIT   (5 -> 10), daarna HALT
    clear;
    dut.code[0] = 8'h85; dut.code[1] = 8'h15; dut.code[2] = 8'd10; dut.code[3] = 8'h3F;
    dut.code[10] = 8'h01; dut.code[11] = 8'h05; dut.code[12] = 8'h16;
    run; check(tos, 8'd10, 1, "CALL/EXIT");

    // JZ en JMP: 0 JZ 6 (springt) 99 ... 6: 7 HALT  => tos 7, diepte 1
    clear;
    dut.code[0] = 8'h80; dut.code[1] = 8'h14; dut.code[2] = 8'd6; dut.code[3] = 8'hE3; dut.code[4] = 8'h3F;
    dut.code[6] = 8'h87; dut.code[7] = 8'h3F;
    run; check(tos, 8'd7, 1, "JZ springt");
    clear;
    dut.code[0] = 8'h81; dut.code[1] = 8'h14; dut.code[2] = 8'd6; dut.code[3] = 8'h88; dut.code[4] = 8'h13; dut.code[5] = 8'd8;
    dut.code[6] = 8'h87; dut.code[7] = 8'h3F; dut.code[8] = 8'h3F;
    run; check(tos, 8'd8, 1, "JZ springt niet, JMP naar HALT");

    if (fouten == 0) $display("PASS: stackmachine S8 voert alle opcodes correct uit");
    $finish;
  end
endmodule
```

## 4. Een Forth-compiler in Python

Bytes met de hand typen wil je niet. De compiler hieronder leest Forth-tekst en schrijft een `.hex`-bestand. Hij werkt in één pas met terugpatchen. Bij `IF` weet hij het sprongdoel nog niet, dus schrijft hij een lege plek en vult die in bij `THEN`. Een stapel van open structuren (`ctrl`) houdt bij welke plekken nog open staan.

```python
# FILE: stack/forth.py
"""Een kleine Forth-compiler voor de stackmachine S8.

Gebruik:  python3 forth.py programma.fs        -> programma.hex
Ondersteund: getallen (10, $FF, 0xFF, -1), : naam ... ;, VARIABLE, CONSTANT,
IF ELSE THEN, BEGIN UNTIL, BEGIN WHILE REPEAT, BEGIN AGAIN, commentaar ( ... ) en \\ ...
"""
import re
import sys

PRIMITIVES = {
    "NOP": 0x00, "DUP": 0x01, "DROP": 0x02, "SWAP": 0x03, "OVER": 0x04,
    "+": 0x05, "-": 0x06, "AND": 0x07, "OR": 0x08, "XOR": 0x09,
    "INVERT": 0x0A, "2*": 0x0B, "2/": 0x0C, "@": 0x0D, "!": 0x0E,
    ">R": 0x0F, "R>": 0x10, "R@": 0x11, "=": 0x17, "<": 0x18, "ROT": 0x19,
    "EXIT": 0x16, "HALT": 0x3F,
}
LIT8, JMP, JZ, CALL, EXIT, HALT = 0x12, 0x13, 0x14, 0x15, 0x16, 0x3F


class ForthError(Exception):
    pass


def tokenize(src):
    src = re.sub(r"\\[^\n]*", " ", src)           # \ commentaar tot einde regel
    src = re.sub(r"\([^)]*\)", " ", src)           # ( commentaar )
    return src.split()


def parse_number(tok):
    try:
        if tok.startswith("$"):
            return int(tok[1:], 16)
        if tok.lower().startswith("0x") or tok.lower().startswith("-0x"):
            return int(tok, 16)
        return int(tok, 10)
    except ValueError:
        return None


def compile_forth(src):
    toks = tokenize(src)
    code = [JMP, 0]                    # adres 0: spring naar het hoofdprogramma (adres wordt later ingevuld)
    words, consts = {}, {}
    next_var = 0
    main_tokens = []

    def emit(*bytes_):
        code.extend(bytes_)
        if len(code) > 256:
            raise ForthError("programma is langer dan 256 bytes")

    def literal(value):
        value &= 0xFF
        if value < 128:
            emit(0x80 | value)
        else:
            emit(LIT8, value)

    def compile_body(tokens):
        ctrl = []
        for tok in tokens:
            up = tok.upper()
            if up == "IF":
                emit(JZ, 0); ctrl.append(("if", len(code) - 1))
            elif up == "ELSE":
                kind, pos = ctrl.pop()
                if kind != "if":
                    raise ForthError("ELSE zonder IF")
                emit(JMP, 0)
                code[pos] = len(code)
                ctrl.append(("else", len(code) - 1))
            elif up == "THEN":
                if not ctrl or ctrl[-1][0] not in ("if", "else"):
                    raise ForthError("THEN zonder IF")
                kind, pos = ctrl.pop()
                code[pos] = len(code)
            elif up == "BEGIN":
                ctrl.append(("begin", len(code)))
            elif up == "UNTIL":
                kind, addr = ctrl.pop()
                if kind != "begin":
                    raise ForthError("UNTIL zonder BEGIN")
                emit(JZ, addr)
            elif up == "AGAIN":
                kind, addr = ctrl.pop()
                if kind != "begin":
                    raise ForthError("AGAIN zonder BEGIN")
                emit(JMP, addr)
            elif up == "WHILE":
                emit(JZ, 0); ctrl.append(("while", len(code) - 1))
            elif up == "REPEAT":
                kind, wpos = ctrl.pop()
                kind2, addr = ctrl.pop()
                if kind != "while" or kind2 != "begin":
                    raise ForthError("REPEAT zonder BEGIN ... WHILE")
                emit(JMP, addr)
                code[wpos] = len(code)
            elif tok in words:
                emit(CALL, words[tok])
            elif tok in consts:
                literal(consts[tok])
            elif up in PRIMITIVES:
                emit(PRIMITIVES[up])
            elif parse_number(tok) is not None:
                literal(parse_number(tok))
            else:
                raise ForthError(f"onbekend woord: {tok}")
        if ctrl:
            raise ForthError(f"onafgesloten structuur: {ctrl[-1][0].upper()}")

    i = 0
    while i < len(toks):
        tok = toks[i]
        if tok == ":":
            if i + 1 >= len(toks):
                raise ForthError("':' zonder naam")
            name = toks[i + 1]
            j = i + 2
            while j < len(toks) and toks[j] != ";":
                j += 1
            if j >= len(toks):
                raise ForthError(f"definitie van {name} eindigt niet met ';'")
            words[name] = len(code)
            compile_body(toks[i + 2:j])
            emit(EXIT)
            i = j + 1
        elif tok.upper() == "VARIABLE":
            consts[toks[i + 1]] = next_var
            next_var += 1
            i += 2
        elif tok.upper() == "CONSTANT":
            if not main_tokens or parse_number(main_tokens[-1]) is None:
                raise ForthError("CONSTANT verwacht een getal ervoor")
            consts[toks[i + 1]] = parse_number(main_tokens.pop()) & 0xFF
            i += 2
        else:
            main_tokens.append(tok)
            i += 1

    code[1] = len(code)
    compile_body(main_tokens)
    emit(HALT)
    return code + [HALT] * (256 - len(code))


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    try:
        code = compile_forth(open(argv[1]).read())
    except ForthError as e:
        print(f"FOUT: {e}", file=sys.stderr)
        return 1
    with open(argv[1].rsplit(".", 1)[0] + ".hex", "w") as f:
        f.write("\n".join(f"{b:02X}" for b in code) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

Zo worden de besturingsstructuren gecompileerd:

| Forth | Gegenereerde code |
|-------|-------------------|
| `IF A ELSE B THEN` | `JZ else` / A / `JMP einde` / `else:` B / `einde:` |
| `BEGIN A UNTIL` | `begin:` A / `JZ begin` |
| `BEGIN A WHILE B REPEAT` | `begin:` A / `JZ einde` / B / `JMP begin` / `einde:` |

Alles wordt teruggebracht tot `JZ` en `JMP`, de enige twee sprongen van de machine.

Ook de compiler heeft een test, net als de assembler:

```python
# FILE: stack/test_forth.py
# Tests voor de Forth-compiler: bytes van kleine programma's, controlestructuren, foutmeldingen.
from forth import compile_forth, ForthError

def moet_falen(bron, deel):
    try:
        compile_forth(bron)
    except ForthError as e:
        assert deel in str(e), f"verkeerde melding: {e}"
        return
    raise AssertionError(f"verwachtte een fout voor {bron!r}")

c = compile_forth("3 4 +")
assert c[:6] == [0x13, 2, 0x83, 0x84, 0x05, 0x3F]           # JMP 2, LIT 3, LIT 4, +, HALT
c = compile_forth("200 7 AND")
assert c[:6] == [0x13, 2, 0x12, 200, 0x87, 0x07]            # 200 past niet in 7 bit: LIT8
c = compile_forth("-1")
assert c[2:4] == [0x12, 255]
c = compile_forth("$FF 0x10")
assert c[2:6] == [0x12, 255, 0x90, 0x3F]                     # $FF past niet in 7 bit, 0x10 = 16 wel

# definitie en aanroep
c = compile_forth(": dubbel DUP + ; 5 dubbel")
assert c[0:2] == [0x13, 5]                                  # springt over de definitie naar adres 5
assert c[2:5] == [0x01, 0x05, 0x16]                         # DUP + EXIT
assert c[5:8] == [0x85, 0x15, 2]                            # 5, CALL 2

# IF ELSE THEN: JZ naar het ELSE-deel, JMP over het ELSE-deel
c = compile_forth("1 IF 2 ELSE 3 THEN")
assert c[2:10] == [0x81, 0x14, 8, 0x82, 0x13, 9, 0x83, 0x3F]   # JZ -> ELSE-deel (8), JMP -> einde (9)

# BEGIN ... UNTIL springt terug naar het begin; WHILE/REPEAT
c = compile_forth("BEGIN 1 UNTIL")
assert c[2:6] == [0x81, 0x14, 2, 0x3F]
c = compile_forth("BEGIN 1 WHILE 2 REPEAT")
assert c[2:9] == [0x81, 0x14, 8, 0x82, 0x13, 2, 0x3F]            # JZ -> einde (8), JMP terug naar BEGIN (2)

# variabelen en constanten
c = compile_forth("VARIABLE a VARIABLE b a b 7 CONSTANT zeven zeven")
assert c[2:5] == [0x80, 0x81, 0x87]

# commentaar
assert compile_forth("( dit is commentaar ) 1 \\ en dit ook\n 2")[2:4] == [0x81, 0x82]

moet_falen("foo", "onbekend woord")
moet_falen("IF 1", "onafgesloten")
moet_falen("1 THEN", "THEN zonder IF")
moet_falen(": x 1", "eindigt niet")
moet_falen(" ".join(["1"] * 300), "langer dan 256")

print("PASS: Forth-compiler (getallen, definities, IF/ELSE/THEN, BEGIN/UNTIL/WHILE/REPEAT, VARIABLE, CONSTANT, fouten) werkt")
```

## 5. Programma's

### Rekenen

```text
\ FILE: stack/arith.fs
\ Rekenen met de stapel: 3 4 + 5 2* +  =  7 + 10  =  17
3 4 + 5 2* +
```

### Faculteit: een recursief woord

S8 heeft geen vermenigvuldiging. We bouwen `mul` daarom zelf, met herhaald optellen en de terugkeerstapel als tijdelijke opslag. Daarna kan `fact` zichzelf aanroepen: de terugkeerstapel groeit bij elke aanroep met één adres.

```text
\ FILE: stack/fact.fs
\ Faculteit met recursie. mul is vermenigvuldigen met herhaald optellen.
: mul ( a b -- a*b )
   0 SWAP                    \ a acc b
   BEGIN DUP WHILE
      1 -  >R                \ b-1 naar de terugkeerstapel
      OVER +                 \ acc = acc + a
      R>
   REPEAT
   DROP SWAP DROP ;

: fact ( n -- n! )
   DUP 1 = IF DROP 1 ELSE DUP 1 - fact mul THEN ;

5 fact
```

### Fibonacci en som

```text
\ FILE: stack/fib.fs
\ Het n-de Fibonacci-getal met een lus.
: fib ( n -- fib )
   0 1 ROT                   \ x y n
   BEGIN DUP WHILE
      1 - >R                 \ x y         R: n-1
      SWAP OVER +            \ y x+y
      R>
   REPEAT
   DROP DROP ;

10 fib
```

```text
\ FILE: stack/sum.fs
\ Som van 1 tot n.
: som ( n -- s )
   0 SWAP                    \ acc n
   BEGIN DUP WHILE
      SWAP OVER +            \ n acc+n
      SWAP 1 -               \ acc' n-1
   REPEAT
   DROP ;

10 som
```

### Een variabele

`VARIABLE teller` reserveert een plek in het datageheugen. Het woord `teller` zet het adres op de stapel, en met `@` en `!` lees en schrijf je.

```text
\ FILE: stack/counter.fs
\ Een variabele in het datageheugen die tot 5 telt.
VARIABLE teller
: ophogen  teller @ 1 + teller ! ;

0 teller !
BEGIN
   ophogen
   teller @ 5 =
UNTIL
teller @
```

### Alles testen op de hardware

Vijf stackmachines tegelijk, elk met een eigen programma:

```verilog
// FILE: stack/tb_forth.v
// Vijf door de Forth-compiler gemaakte programma's, elk op zijn eigen stackmachine.
module tb_forth;
  reg clk = 0, rst_n = 0;
  wire h1, h2, h3, h4, h5;
  wire [7:0] t1, t2, t3, t4, t5, p1, p2, p3, p4, p5;
  wire [3:0] d1, d2, d3, d4, d5;
  integer fouten = 0, cycli;

  s8 #("arith.hex", 1)   a(clk, rst_n, h1, p1, t1, d1);
  s8 #("fact.hex", 1)    f(clk, rst_n, h2, p2, t2, d2);
  s8 #("fib.hex", 1)     g(clk, rst_n, h3, p3, t3, d3);
  s8 #("sum.hex", 1)     s(clk, rst_n, h4, p4, t4, d4);
  s8 #("counter.hex", 1) c(clk, rst_n, h5, p5, t5, d5);
  always #5 clk = ~clk;

  task check(input [7:0] got, input [3:0] depth, input [7:0] want, input [255:0] naam);
    if (got !== want || depth !== 4'd1) begin
      fouten = fouten + 1; $display("FAIL %0s: tos=%0d (verwacht %0d), diepte=%0d", naam, got, want, depth);
    end
  endtask

  initial begin
    #22 rst_n = 1; cycli = 0;
    while (!(h1 && h2 && h3 && h4 && h5) && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end
    if (cycli >= 100000) begin fouten = fouten + 1; $display("FAIL: niet alle programma's stopten"); end
    check(t1, d1, 8'd17,  "3 4 + 5 2* +");
    check(t2, d2, 8'd120, "5 fact");
    check(t3, d3, 8'd55,  "10 fib");
    check(t4, d4, 8'd55,  "10 som");
    check(t5, d5, 8'd5,   "teller");
    if (c.data[0] !== 8'd5) begin fouten = fouten + 1; $display("FAIL: data[0] = %0d", c.data[0]); end
    if (fouten == 0) $display("PASS: vijf Forth-programma's (rekenen, faculteit, Fibonacci, som, variabele) kloppen na %0d cycli", cycli);
    $finish;
  end
endmodule
```

En een script om een eigen programma in één keer te compileren en te draaien:

```verilog
// FILE: stack/tb_s8_run.v
// Draait een met forth.py gemaakt programma en toont de stapel. Gebruik via runfs.sh.
module tb_s8_run;
  reg clk = 0, rst_n = 0;
  wire halted; wire [7:0] pc, tos; wire [3:0] dsp;
  reg [8*64-1:0] pnaam;
  integer cycli = 0, k;
  s8 #("none", 0) dut(clk, rst_n, halted, pc, tos, dsp);
  always #5 clk = ~clk;
  initial begin
    #1;
    if (!$value$plusargs("prog=%s", pnaam)) begin
      $display("PASS: tb_s8_run zonder programma. Gebruik: vvp s8run.vvp +prog=programma.hex");
      $finish;
    end
    $readmemh(pnaam, dut.code);
    #21 rst_n = 1;
    while (!halted && cycli < 1000000) begin @(negedge clk); cycli = cycli + 1; end
    $display("Klaar na %0d cycli. Stapeldiepte %0d.", cycli, dsp);
    for (k = 0; k < dsp; k = k + 1) $display("  stapel[%0d] = %0d", k, dut.ds[k]);
    $finish;
  end
endmodule
```

```bash
# FILE: stack/runfs.sh
#!/bin/bash
# Gebruik: bash runfs.sh programma.fs
# Compileert een Forth-programma en draait het op de stackmachine S8.
python3 forth.py "$1" || exit 1
iverilog -g2012 -o s8run.vvp tb_s8_run.v s8.v || exit 1
vvp s8run.vvp +prog="${1%.fs}.hex" | grep -v finish
```

```text
bash runfs.sh fact.fs
```

## 6. Stackmachine tegen registermachine

Is een stackmachine beter? Dit is wat we in onze eigen programma's meten:

| Programma | W8 (registermachine) | S8 (stackmachine) |
|-----------|---------------------|-------------------|
| Som 1 tot 10 | 12 bytes code, 66 cycli | 21 bytes code, 123 cycli |

Dat is tegen de verwachting in: de registermachine wint hier op beide punten. Hoe kan dat?

- Het S8-programma is een woord met een aanroep en heeft dus overhead: `CALL`, `EXIT`, een hoofdprogramma en veel `SWAP` en `OVER` om waarden op de juiste plek te krijgen.
- W8 bewaart de teller en de som in vaste registers, terwijl S8 ze over de stapel moet schuiven.
- Een slimmere stack-programmeur of compiler had S8 korter gekregen, maar de les blijft: stackmachines besparen bits per instructie, maar hebben meer instructies nodig.

De vergelijking in het algemeen:

| | Registermachine | Stackmachine |
|--|-----------------|--------------|
| Instructielengte | lang (registeradressen) | kort (geen adressen) |
| Aantal instructies | minder | meer (SWAP, OVER, ...) |
| Decoder | groter | zeer klein |
| Parallelle uitvoering | makkelijker | moeilijk (alles loopt via de stapeltop) |
| Compilers | complexe registerallocatie | eenvoudig te genereren |
| Gebruik | vrijwel alle CPU's | virtuele machines, zeer kleine chips |

Moderne snelle processors zijn registermachines, juist omdat parallellisme belangrijk is. Als virtuele machine (JVM, WebAssembly) blijft de stackmachine populair, omdat de code compact is en de compiler eenvoudig.

## 7. Lab

1. Draai `bash runfs.sh` op alle vijf de programma's. Noteer cycli, bytes en eindstapel.
2. Voer een programma met de hand uit op papier: teken de stapel na elk woord voor `3 7 max` (zie oefening 3).
3. Schrijf een Forth-programma dat de som van 1 tot 10 berekent zonder een definitie, alleen met `BEGIN ... UNTIL`. Meet de code in bytes en vergelijk met `sum.fs`.
4. Maak fouten (een onbekend woord, een vergeten `THEN`, 300 getallen achter elkaar). Zijn de meldingen duidelijk?
5. Voeg `NIP`, `2DUP` en `NEGATE` toe aan een eigen woordenlijst.

## 8. Oefeningen

1. Evalueer met de hand en teken de stapel na elk woord: `2 3 4 + mul`, `5 DUP mul` en `1 2 3 ROT`. (`mul` is het woord uit `fact.fs`.)
2. Wat doet `OVER OVER` ( a b -- ? ) en wat is een goede naam ervoor?
3. Schrijf de volgende woorden: `NIP ( a b -- b )`, `2DUP ( a b -- a b a b )`, `NEGATE ( a -- -a )`, `0= ( a -- vlag )` en `MAX ( a b -- max )`.
4. Hoe diep wordt de terugkeerstapel bij `5 fact`? Wat gebeurt er bij `8 fact`?
5. Hoeveel bytes kost het getal 100 in S8-code? En 200?
6. Voeg een opcode `*` (vermenigvuldigen) toe aan `s8.v` en `forth.py`. Hoe verandert dat de codegrootte en de snelheid van `fact`?
7. Waarom is het een probleem dat S8 de overloop van de stapels niet controleert? Hoe zou je dat in hardware oplossen?
8. Uitdaging: voeg `DO ... LOOP` toe aan de compiler. Hint: de lusteller staat op de terugkeerstapel.

## 9. Antwoorden

1. `2 3 4 + mul`: 2 geeft [2], 3 geeft [2 3], 4 geeft [2 3 4], `+` geeft [2 7] en `mul` geeft [14]. `5 DUP mul`: [5] wordt [5 5] en dan [25]. `1 2 3 ROT`: [1 2 3] wordt [2 3 1].
2. `OVER OVER ( a b -- a b a b )` heet in Forth `2DUP`.
3. De uitwerkingen staan hieronder, de testbench controleert ze.
4. Elke recursieve aanroep zet een terugkeeradres op de terugkeerstapel. Bij `5 fact` zijn dat 5 adressen, plus 1 voor de aanroep van `mul` en 1 voor de `>R` daarin: maximaal 7 van de 16 plaatsen. Bij `8 fact` is het maximum 10, dus ook dan loopt de stapel nog niet over. Maar 8! = 40320 past niet in 8 bits: het resultaat is 40320 mod 256 = 128.
5. 100 past in 7 bits, dus 1 byte. 200 niet (maximaal 127), dus 2 bytes (LIT8 plus 200).
6. Je voegt een opcode toe in het `case` van `s8.v` (`ds[t2] <= N * T; sp <= sp - 1`), een regel in `PRIMITIVES` en laat de compiler `*` kennen. De 8×8-vermenigvuldiging kost in hardware meer poorten, maar `fact` wordt veel korter (geen `mul`) en sneller.
7. Een programmafout kan de stapel laten overlopen, waarbij je terugkeeradressen of gegevens overschrijft. Dat is een klassieke bron van onverklaarbare fouten. In hardware voeg je een vergelijker toe tussen de wijzer en de grens (een overflow- en underflowvlag) die de CPU laat stoppen.
8. De aanpak: `DO` zet `limiet start` op de terugkeerstapel (`>R >R`), en `LOOP` verhoogt de teller, vergelijkt hem met de limiet en springt terug naar het begin. Je hebt ook `I ( -- teller )` nodig (dat is `R@`) en een extra sprong.

```text
\ FILE: stack/answers.fs
\ Uitwerkingen van de oefeningen: nuttige stapelwoorden.
: nip    SWAP DROP ;
: 2dup   OVER OVER ;
: negate INVERT 1 + ;
: 0=     0 = ;
: max    2dup < IF nip ELSE DROP THEN ;

3 7 max          \ 7
7 3 max          \ 7
5 negate         \ 251 (= -5 in 8 bit)
1 2 nip          \ 2
0 0=             \ 255 (waar)
```

```verilog
// FILE: stack/tb_answers_fs.v
module tb_answers_fs;
  reg clk = 0, rst_n = 0;
  wire halted; wire [7:0] pc, tos; wire [3:0] dsp;
  integer fouten = 0, cycli = 0;
  s8 #("answers.hex", 1) dut(clk, rst_n, halted, pc, tos, dsp);
  always #5 clk = ~clk;
  initial begin
    #22 rst_n = 1;
    while (!halted && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end
    if (dsp !== 4'd5) begin fouten = fouten + 1; $display("FAIL: diepte %0d", dsp); end
    if (dut.ds[0] !== 8'd7 || dut.ds[1] !== 8'd7 || dut.ds[2] !== 8'd251 || dut.ds[3] !== 8'd2 || dut.ds[4] !== 8'd255) begin
      fouten = fouten + 1; $display("FAIL: stapel = %0d %0d %0d %0d %0d", dut.ds[0], dut.ds[1], dut.ds[2], dut.ds[3], dut.ds[4]);
    end
    if (fouten == 0) $display("PASS: nip, 2dup, negate, 0= en max geven de verwachte stapel");
    $finish;
  end
endmodule
```

## 10. Zelftest

1. Waarom hebben stackmachine-instructies geen registeradressen?
2. Wat betekent `( a b -- c )`?
3. Waar bewaart S8 het terugkeeradres bij `CALL`?
4. Hoe compileert `IF ... THEN` naar machinecode?
5. Wat is de afweging tussen stack- en registermachines?

Antwoorden: (1) De operanden zijn altijd de bovenste elementen van de stapel. (2) Het stack-effect: `a` en `b` worden van de stapel gehaald en `c` komt erop. (3) Op de terugkeerstapel. (4) Als `JZ` met een doeladres dat bij `THEN` wordt ingevuld. (5) Stackmachines hebben kortere instructies en een eenvoudigere decoder, maar meer instructies en minder mogelijkheden voor parallellisme.

## 11. Verder lezen

- Leo Brodie, *Starting Forth* (gratis online): de klassieke inleiding in de taal.
- Charles Moore's verhaal over de Forth-chips en de GA144 (144 kleine Forth-computers op één chip).
- Koopman, *Stack Computers: The New Wave* (online beschikbaar): de beste studie van stackarchitecturen.
- Jonesforth: een Forth-implementatie in assembly met uitleg in de broncode, nog steeds een meesterwerk.

Volgende week: de ongewoonste architectuur uit deze cursus, de transport-triggered architecture, waarin de enige instructie `MOVE` is.
