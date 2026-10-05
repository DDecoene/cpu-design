---
title: "Week 19 · Transport-triggered architecture (TTA)"
---

<p class="subtitle">Fase 5 · Geavanceerde architecturen · ongeveer 14 uur</p>

# Week 19: Transport-triggered architecture

## Wat je na deze week kunt

- uitleggen wat een TTA is en waarin ze zich fundamenteel van een gewone CPU onderscheidt
- de instructieset van T8 lezen en programma's schrijven die alleen uit `MOVE` bestaan
- begrijpen waarom bij een TTA de instructie tegelijk het besturingswoord is
- T8 in Verilog bouwen, met een assembler, en grondig testen
- de afweging tussen hardware-eenvoud en programmalengte benoemen

> **Dit is het hart van het project in deel 6.** In week 25 bouw je deze machine met 74HC-chips op een eigen printplaat. Neem de tijd om hem echt te begrijpen.

## 1. Het idee: draai de CPU binnenstebuiten

In een gewone CPU zeg je wat de machine moet doen: `ADD R1, R2, R3`. De processor zoekt zelf uit welke onderdelen daarvoor nodig zijn en verplaatst de gegevens. Die interne verplaatsingen zijn onzichtbaar voor de programmeur.

Een transport-triggered architecture doet het omgekeerd. De programmeur beschrijft alleen de verplaatsingen, en het rekenen is een bijwerking:

```text
 gewone CPU:                        TTA:
   ADD R3, R1, R2                     R1  -> OP         ; zet getal 1 klaar
                                      R2  -> ADD        ; schrijven naar ADD "triggert" de optelling
                                      RES -> R3         ; haal het resultaat op
```

Er is één enkele instructie: MOVE, `bron -> bestemming`. Alles wat de machine doet, volgt uit welke bronnen en bestemmingen er bestaan:

- Schrijf je naar een register, dan onthoudt dat register de waarde.
- Schrijf je naar `ADD`, dan telt de rekeneenheid zijn ene operand op bij de waarde die je schrijft en bewaart hij het resultaat.
- Schrijf je naar `PC`, dan is dat een sprong.

Een sprong is dus gewoon een move naar de programmateller. Een aanroep is een move van de programmateller naar een register. Er is geen opcode-decoder en er zijn geen aparte sprong-instructies: alles is verplaatsen.

TTA's zijn geen curiositeit. De TU Delft (het MOVE-project, jaren negentig) en de Tampere University (TCE, een open-sourcegereedschap voor TTA-processors) hebben ze bestudeerd, en sommige kleine, energiezuinige signaalprocessoren zijn zo ontworpen. In de hobbywereld bestaan er maar weinig werkende TTA-CPU's, dus dit is echt een bijzonder project.

## 2. Waarom is dit zo eenvoudig te bouwen?

Kijk naar W8 uit de vorige weken. De besturingseenheid kijkt naar de opcode en zet 13 signalen aan of uit. In T8 is de instructie zelf het besturingswoord:

```text
                         ┌──────── ROM (instructies) ◄── PC
                         │
              ┌──────────┴──────────────────────┐
              │ guard   bestemming   bron   constante │
              └───┬────────┬──────────┬───────┬──────┘
                  │        │          │       │
         vlaggen ─► mux     ▼          ▼       │
                  │  decoder          decoder   │
                  ▼  (wie schrijft?)  (wie levert?)
               "mag"    │          │            │
                  └────►(EN)       │            │
                         │         ▼            ▼
                         │   ┌─────────────────────────────┐
                         │   │  BUS (8 draden)              │◄── bronnen sturen
                         │   └──────┬──────────────────────┘     (tri-state)
                         ▼          ▼
                   klok van de bestemmingsregisters, data van de bus
```

Het bronveld wordt door een decoder omgezet in "wie mag de bus aansturen" (de output-enable van een tri-state register). Het bestemmingsveld wordt door een decoder omgezet in "wie neemt de waarde over" (de klokpuls van één register). En het guard-veld laat de move wel of niet doorgaan.

Dat is alles. Er is geen besturingseenheid, geen microcode en geen toestandsmachine. Het ROM zelf is de besturing. Het is de gedachte van week 8, "ROM als logica", tot het uiterste doorgevoerd. In hardware betekent dat heel weinig chips, en omdat alle toestand zichtbaar is, is debuggen op een breadboard een plezier.

## 3. De architectuur van T8

### Toestand

| Onderdeel | Beschrijving |
|-----------|-------------|
| R0 ... R3 | vier algemene registers van 8 bit |
| OP | operandregister van de rekeneenheid |
| RES | resultaatregister van de rekeneenheid |
| MAR | geheugenadresregister |
| PC | programmateller, 8 bit |
| Z, N, C | vlaggen, bijgewerkt door elke rekenbewerking |
| Programmageheugen | 256 × 24 bit |
| Datageheugen | 256 × 8 bit |
| `IN` en `OUT` | een ingangs- en een uitgangspoort van 8 bit |

### De instructie: 24 bit

```text
 bit:  23 22 21 | 20 19 18 17 16 | 15 14 13 | 12 11 10 9 8 | 7 ... 0
       guard      bestemming       (leeg)      bron           constante
```

De velden vallen precies op bytegrenzen (op de guard na): drie bytes uit het ROM, in hardware drie 8-bit EEPROM's.

### Bronnen (waar de waarde vandaan komt)

| Nr | Naam | Waarde |
|:--:|------|--------|
| 0 | `#constante` | de constante uit de instructie |
| 1-4 | `R0` ... `R3` | de registers |
| 5 | `RES` | het resultaat van de laatste rekenbewerking |
| 6 | `RESHR` | `RES` één plaats naar rechts geschoven (afgeleide bron) |
| 7 | `RESNOT` | `RES` omgekeerd (afgeleide bron) |
| 8 | `MEM` | `mem[MAR]` |
| 9 | `IN` | de ingangspoort |
| 10 | `PC2` | het adres van de instructie twee na deze, voor terugkeeradressen |
| 11 | `FLAGS` | `00000NCZ`: de vlaggen als getal |

### Bestemmingen (wat er met de waarde gebeurt)

| Nr | Naam | Effect |
|:--:|------|--------|
| 0 | `NOP` | niets |
| 1-4 | `R0` ... `R3` | schrijf het register |
| 5 | `OP` | zet de operand klaar (geen vlaggen) |
| 6 | `ADD` | RES = OP + waarde; C = carry |
| 7 | `SUB` | RES = OP − waarde; C = 1 als er niet geleend is |
| 16 | `ADC` | RES = OP + waarde + C |
| 8 | `AND` | RES = OP & waarde |
| 9 | `OR` | RES = OP \| waarde |
| 10 | `XOR` | RES = OP ^ waarde |
| 15 | `SHL` | RES = waarde << 1; C = uitgeschoven bit |
| 11 | `PC` | sprong |
| 12 | `MAR` | geheugenadres instellen |
| 13 | `MEM` | `mem[MAR]` = waarde |
| 14 | `OUT` | schrijf naar de uitgangspoort |
| 31 | `HALT` | stop |

Eén move is verboden: `MEM -> MEM`. Lezen en schrijven van hetzelfde geheugen in één cyclus is in hardware onmogelijk (week 25), dus de assembler weigert hem.

Elke bestemming van 6 tot en met 10, 15 en 16 heet een trigger: het schrijven zet de berekening in gang. Z en N volgen uit het resultaat en worden bij elke trigger bijgewerkt.

### Guards: voorwaardelijk uitvoeren

In plaats van aparte voorwaardelijke sprongen heeft elke move een guard. Staat er `?Z` voor, dan voert de machine de move alleen uit als de Z-vlag gezet is.

| Code | Guard | De move gaat door als |
|:----:|-------|-----------------------|
| 0 | (geen) | altijd |
| 1 | `?Z` | Z = 1 (resultaat was nul) |
| 2 | `?NZ` | Z = 0 |
| 3 | `?C` | C = 1 |
| 4 | `?NC` | C = 0 |
| 5 | `?N` | N = 1 (negatief) |
| 6 | `?NN` | N = 0 |
| 7 | (nooit) | nooit |

Een voorwaardelijke sprong is dus gewoon een guarded move naar `PC`: `?NZ #lus -> PC`. Maar elke andere move kan ook voorwaardelijk zijn, waardoor je korte `if`-stukjes zonder sprong kunt schrijven. Dat heet predicated execution en komt voor in veel DSP's en in ARM.

### Eén move per klokcyclus

Elke instructie duurt precies één klokcyclus: de instructie lezen, de bron op de bus zetten en de bestemming schrijven. De CPI is 1.

## 4. Programmeren met moves

### Een optelling

`R0 + R1 → R2` kost drie moves:

```text
R0  -> OP         ; operand klaarzetten
R1  -> ADD        ; trigger: RES = OP + R1
RES -> R2         ; resultaat ophalen
```

Het lijkt omslachtig, maar bedenk wat er niet is: de CPU heeft geen idee wat "optellen" is. Het is een bijwerking van een bestemming. Het mooie is dat tussenresultaten direct doorgestuurd kunnen worden: `RES -> OP` zet het resultaat van de ene optelling klaar voor de volgende, zonder register.

### Een constante gebruiken

`#5 -> ADD` triggert `OP + 5`. De constante komt rechtstreeks uit de instructie.

### Sprongen en aanroepen

```text
        #lus -> PC            ; onvoorwaardelijke sprong (macro: JMP lus)
        ?NZ #lus -> PC        ; voorwaardelijk

        PC2 -> R3             ; CALL: bewaar het terugkeeradres
        #sub -> PC            ;       en spring (macro: CALL sub)
        ...
sub:    ...
        R3 -> PC              ; RET
```

Waarom `PC2` en niet `PC`? Op het moment dat de eerste move van `CALL` loopt, wijst de PC naar die move zelf. De volgende instructie is de tweede move (de sprong). De instructie daarna is waar we naartoe terug willen. `PC2` is dus het huidige adres plus 2.

### De assembler-macro's

| Macro | Betekenis |
|-------|-----------|
| `JMP label` | `#label -> PC` |
| `CALL label` | `PC2 -> R3` en `#label -> PC` (R3 is het link register) |
| `RET` | `R3 -> PC` |
| `NOP` | `#0 -> NOP` |
| `HALT` | `#0 -> HALT` |

## 5. T8 in Verilog

Lees dit bestand en vergelijk het met het diagram in paragraaf 2: de bus is een grote `case` over het bronveld en de bestemming een `case` in het klokgestuurde blok.

```verilog
// FILE: tta/tta.v
// T8: een transport-triggered architecture. De enige instructie is MOVE: bron -> bestemming.
// Een instructie van 24 bit:  [23:21] guard | [20:16] bestemming | [15:8] bron | [7:0] constante
// Rekenen gebeurt als bijwerking van schrijven naar een "trigger"-bestemming.
module tta #(parameter PROG = "tta.hex", parameter LOAD = 1,
             parameter DATA = "tta.dat", parameter DLOAD = 0) (
  input        clk,
  input        rst_n,
  input  [7:0] in_port,
  output reg [7:0] out_port,
  output reg   out_valid,        // één klokperiode hoog bij elke schrijfactie naar OUT
  output reg   halted,
  output [7:0] pc_out,
  output [7:0] r0, r1, r2, r3,
  output [7:0] res_out,
  output       flag_z, flag_n, flag_c
);
  // Bestemmingen
  localparam D_NOP = 0, D_R0 = 1, D_R1 = 2, D_R2 = 3, D_R3 = 4, D_OP = 5,
             D_ADD = 6, D_SUB = 7, D_AND = 8, D_OR = 9, D_XOR = 10, D_PC = 11,
             D_MAR = 12, D_MEM = 13, D_OUT = 14, D_SHL = 15, D_ADC = 16, D_HALT = 31;
  // Bronnen
  localparam S_IMM = 0, S_R0 = 1, S_R1 = 2, S_R2 = 3, S_R3 = 4, S_RES = 5, S_RESHR = 6,
             S_RESNOT = 7, S_MEM = 8, S_IN = 9, S_PC2 = 10, S_FLAGS = 11;

  reg [23:0] rom [0:255];
  reg [7:0]  ram [0:255];
  reg [7:0]  pc, op, res, mar;
  reg [7:0]  r [0:3];
  reg        zf, nf, cf;
  integer i;

  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      rom[i] = {3'b000, 5'd31, 16'h0000};     // lege plaatsen zijn een HALT (bestemming 31)
      ram[i] = 8'h00;
    end
    if (LOAD)  $readmemh(PROG, rom);
    if (DLOAD) $readmemh(DATA, ram);
  end

  wire [23:0] instr = rom[pc];
  wire [2:0]  guard = instr[23:21];
  wire [4:0]  dst   = instr[20:16];
  wire [4:0]  src   = instr[12:8];
  wire [7:0]  imm   = instr[7:0];

  wire [7:0] res_shr = {1'b0, res[7:1]};     // afgeleide bron: het resultaat, een plaats naar rechts

  // De bus: het bronveld kiest wie de waarde levert.
  reg [7:0] bus;
  always_comb begin
    case (src)
      S_IMM:    bus = imm;
      S_R0:     bus = r[0];
      S_R1:     bus = r[1];
      S_R2:     bus = r[2];
      S_R3:     bus = r[3];
      S_RES:    bus = res;
      S_RESHR:  bus = res_shr;
      S_RESNOT: bus = ~res;
      S_MEM:    bus = ram[mar];
      S_IN:     bus = in_port;
      S_PC2:    bus = pc + 8'd2;
      S_FLAGS:  bus = {5'b00000, nf, cf, zf};
      default:  bus = 8'h00;
    endcase
  end

  reg go;                       // mag deze move doorgaan? (guard)
  always_comb begin
    case (guard)
      3'd0: go = 1'b1;
      3'd1: go = zf;
      3'd2: go = ~zf;
      3'd3: go = cf;
      3'd4: go = ~cf;
      3'd5: go = nf;
      3'd6: go = ~nf;
      default: go = 1'b0;
    endcase
  end

  // Rekenwerk voor de trigger-bestemmingen
  reg [8:0] sum;
  always_comb begin
    sum = 9'd0;
    case (dst)
      D_ADD: sum = {1'b0, op} + {1'b0, bus};
      D_SUB: sum = {1'b0, op} + {1'b0, ~bus} + 9'd1;     // C = 1 betekent: geen lening
      D_ADC: sum = {1'b0, op} + {1'b0, bus} + {8'b0, cf};
      D_SHL: sum = {bus, 1'b0};
      default: sum = 9'd0;
    endcase
  end

  reg [7:0] lg;                  // uitkomst van de logische bewerkingen
  always_comb begin
    case (dst)
      D_AND:   lg = op & bus;
      D_OR:    lg = op | bus;
      D_XOR:   lg = op ^ bus;
      default: lg = 8'h00;
    endcase
  end

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      pc <= 0; op <= 0; res <= 0; mar <= 0; zf <= 0; nf <= 0; cf <= 0; halted <= 0;
      out_port <= 0; out_valid <= 0;
      for (i = 0; i < 4; i = i + 1) r[i] <= 8'h00;
    end else begin
      out_valid <= 1'b0;
      if (!halted) begin
        pc <= pc + 8'd1;
        if (go) begin
          case (dst)
            D_R0:  r[0] <= bus;
            D_R1:  r[1] <= bus;
            D_R2:  r[2] <= bus;
            D_R3:  r[3] <= bus;
            D_OP:  op <= bus;
            D_ADD, D_SUB, D_ADC, D_SHL: begin
              res <= sum[7:0]; cf <= sum[8]; zf <= (sum[7:0] == 8'h00); nf <= sum[7];
            end
            D_AND, D_OR, D_XOR: begin
              res <= lg; cf <= 1'b0; zf <= (lg == 8'h00); nf <= lg[7];
            end
            D_PC:  pc <= bus;
            D_MAR: mar <= bus;
            D_MEM: ram[mar] <= bus;
            D_OUT: begin out_port <= bus; out_valid <= 1'b1; end
            D_HALT: halted <= 1'b1;
            default: ;
          endcase
        end
      end
    end

  assign pc_out = pc;
  assign r0 = r[0]; assign r1 = r[1]; assign r2 = r[2]; assign r3 = r[3];
  assign res_out = res;
  assign flag_z = zf; assign flag_n = nf; assign flag_c = cf;
endmodule
```

Let op een paar dingen. Er is geen besturingseenheid: het decoderen van `src` en `dst` is alles. Alle toestand wordt in één klokflank bijgewerkt, en een move naar `PC` overschrijft de standaard `pc + 1`. Na `HALT` verandert er niets meer. Lege plaatsen in het ROM zijn zelf een `HALT`, zodat een verdwaalde sprong de machine laat stoppen.

## 6. De assembler

Een TTA-assembler is eenvoudiger dan die van W8. Elke regel is `bron -> bestemming`, met een optionele guard. De structuur is dezelfde (twee passen, symbolentabel). De macro's `JMP`, `CALL` en `RET` breiden zich uit tot één of twee moves.

```python
# FILE: tta/tta_asm.py
"""Assembler voor de transport-triggered architecture T8.

Gebruik:  python3 tta_asm.py programma.tta [--list]     -> programma.hex (en programma.dat)

Een regel is een move:     [?guard] bron -> bestemming
Constanten schrijf je als  #5   #0xFF   #-1   #label   #NAAM
"""
import re
import sys

DEST = {"NOP": 0, "R0": 1, "R1": 2, "R2": 3, "R3": 4, "OP": 5, "ADD": 6, "SUB": 7,
        "AND": 8, "OR": 9, "XOR": 10, "PC": 11, "MAR": 12, "MEM": 13, "OUT": 14,
        "SHL": 15, "ADC": 16, "HALT": 31}
SRC = {"R0": 1, "R1": 2, "R2": 3, "R3": 4, "RES": 5, "RESHR": 6, "RESNOT": 7,
       "MEM": 8, "IN": 9, "PC2": 10, "FLAGS": 11}
GUARD = {"": 0, "Z": 1, "NZ": 2, "C": 3, "NC": 4, "N": 5, "NN": 6, "NEVER": 7}


class AsmError(Exception):
    pass


def number(tok, symbols, n):
    tok = tok.strip()
    if tok in symbols:
        return symbols[tok]
    try:
        if re.fullmatch(r"-?0[xX][0-9a-fA-F]+", tok):
            return int(tok, 16)
        return int(tok, 10)
    except ValueError:
        raise AsmError(f"regel {n}: onbekend getal of label '{tok}'")


def parse_move(text, n):
    """Geeft (guard, bron, bestemming) als tekst."""
    m = re.fullmatch(r"(?:\?(\w+)\s+)?(\S+)\s*->\s*(\S+)", text.strip())
    if not m:
        raise AsmError(f"regel {n}: verwacht 'bron -> bestemming', kreeg '{text}'")
    guard = (m.group(1) or "").upper()
    if guard not in GUARD:
        raise AsmError(f"regel {n}: onbekende guard '?{guard}'")
    return guard, m.group(2), m.group(3).upper()


def encode(guard, src, dst, symbols, n):
    if dst not in DEST:
        raise AsmError(f"regel {n}: onbekende bestemming '{dst}'")
    if dst == "MEM" and src.upper() == "MEM":
        raise AsmError(f"regel {n}: MEM -> MEM is niet toegestaan (op het bord zouden lezen en schrijven de bus tegelijk aansturen)")
    if src.startswith("#"):
        value = number(src[1:], symbols, n)
        if not -128 <= value <= 255:
            raise AsmError(f"regel {n}: constante {value} past niet in 8 bit")
        srcnum, imm = 0, value & 0xFF
    else:
        if src.upper() not in SRC:
            raise AsmError(f"regel {n}: onbekende bron '{src}'")
        srcnum, imm = SRC[src.upper()], 0
    return (GUARD[guard] << 21) | (DEST[dst] << 16) | (srcnum << 8) | imm


def expand(op, rest, n):
    """Macro's omzetten in moves. Geeft een lijst (guard, bron, bestemming)."""
    guard = ""
    m = re.match(r"\?(\w+)\s+(.*)", op + " " + rest)
    if m:
        guard, text = m.group(1).upper(), m.group(2)
        op, _, rest = text.partition(" ")
    op = op.upper()
    if op == "JMP":
        return [(guard, "#" + rest.strip(), "PC")]
    if op == "CALL":
        return [("", "PC2", "R3"), (guard, "#" + rest.strip(), "PC")]
    if op == "RET":
        return [(guard, "R3", "PC")]
    if op == "NOP":
        return [("", "#0", "NOP")]
    if op == "HALT":
        return [(guard, "#0", "HALT")]
    return None


def assemble(source):
    lines = []
    for n, raw in enumerate(source.splitlines(), 1):
        text = raw.split(";")[0].strip()
        if text:
            lines.append((n, text))

    symbols, items, pc = {}, [], 0
    data, uses_data = [0] * 256, False

    for n, text in lines:
        while True:
            m = re.match(r"^([A-Za-z_]\w*)\s*:\s*(.*)$", text)
            if not m:
                break
            if m.group(1) in symbols:
                raise AsmError(f"regel {n}: label '{m.group(1)}' bestaat al")
            symbols[m.group(1)] = pc
            text = m.group(2)
        if not text:
            continue
        head, _, rest = text.partition(" ")
        if head.upper() == ".EQU":
            name, val = [x.strip() for x in rest.split(",", 1)]
            symbols[name] = number(val, symbols, n)
        elif head.upper() == ".ORG":
            pc = number(rest, symbols, n)
        elif head.upper() == ".DATA":
            parts = [x.strip() for x in rest.split(",")]
            addr = number(parts[0], symbols, n)
            for k, v in enumerate(parts[1:]):
                data[addr + k] = number(v, symbols, n) & 0xFF
            uses_data = True
        else:
            moves = expand(head, rest, n)
            if moves is None:
                moves = [parse_move(text, n)]
            for mv in moves:
                items.append((pc, n, mv))
                pc += 1
            if pc > 256:
                raise AsmError(f"regel {n}: programma is langer dan 256 moves")

    prog = [0x1F0000] * 256
    listing = []
    for addr, n, (guard, src, dst) in items:
        word = encode(guard, src, dst, symbols, n)
        prog[addr] = word
        g = f"?{guard} " if guard else ""
        listing.append(f"{addr:02X}: {word:06X}   {g}{src} -> {dst}")
    return prog, data, listing, uses_data


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    try:
        prog, data, listing, uses_data = assemble(open(argv[1]).read())
    except AsmError as e:
        print(f"FOUT: {e}", file=sys.stderr)
        return 1
    base = argv[1].rsplit(".", 1)[0]
    with open(base + ".hex", "w") as f:
        f.write("\n".join(f"{w:06X}" for w in prog) + "\n")
    if uses_data:
        with open(base + ".dat", "w") as f:
            f.write("\n".join(f"{b:02X}" for b in data) + "\n")
    if "--list" in argv:
        print("\n".join(listing))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

En de test, die de velden bit voor bit controleert:

```python
# FILE: tta/test_tta_asm.py
# Tests voor de TTA-assembler.
from tta_asm import assemble, AsmError

def eerste(bron):
    return assemble(bron)[0][0]

def moet_falen(bron, deel):
    try:
        assemble(bron)
    except AsmError as e:
        assert deel in str(e), f"verkeerde melding: {e}"
        return
    raise AssertionError(f"verwachtte een fout voor {bron!r}")

# Veldindeling: guard[23:21] bestemming[20:16] bron[15:8] constante[7:0]
assert eerste("#5 -> R0")         == 0x010005          # bestemming R0 = 1, bron IMM = 0, constante 5
assert eerste("R0 -> OP")         == 0x050100          # OP = 5, bron R0 = 1
assert eerste("R1 -> ADD")        == 0x060200
assert eerste("RES -> R2")        == 0x030500
assert eerste("#-1 -> R3")        == 0x0400FF
assert eerste("#0xAB -> OUT")     == 0x0E00AB
assert eerste("?Z #7 -> PC")      == 0x2B0007          # guard Z = 1 -> bit 21
assert eerste("?NZ #7 -> PC")     == 0x4B0007
assert eerste("?C #7 -> PC")      == 0x6B0007
assert eerste("PC2 -> R3")        == 0x040A00
assert eerste("#0 -> HALT")       == 0x1F0000

# Macro's
prog = assemble("CALL sub\nHALT\nsub: RET")[0]
assert prog[0] == 0x040A00 and prog[1] == 0x0B0003 and prog[2] == 0x1F0000 and prog[3] == 0x0B0400
assert eerste("JMP 9") == 0x0B0009
assert eerste("?Z JMP 9") == 0x2B0009

# Labels, .equ, .data, .org
prog, data, _, uses = assemble(".equ N, 3\nstart: #N -> R0\n?NZ #start -> PC\n.data 4, 9, 8\n.org 10\nNOP")
assert prog[0] == 0x010003 and prog[1] == 0x4B0000 and data[4:6] == [9, 8] and uses and prog[10] == 0x000000

# Fouten
moet_falen("R0 -> NIET", "onbekende bestemming")
moet_falen("NIET -> R0", "onbekende bron")
moet_falen("#300 -> R0", "past niet")
moet_falen("R0 R1", "bron -> bestemming")
moet_falen("?XX #1 -> R0", "onbekende guard")
moet_falen("#nergens -> PC", "onbekend")
moet_falen("a: NOP\na: NOP", "bestaat al")
moet_falen("MEM -> MEM", "niet toegestaan")

print("PASS: TTA-assembler (velden, guards, macro's, labels, .equ, .data, .org, fouten) werkt")
```

## 7. Voorbeeldprogramma's

### Som van 1 tot 10

```text
; FILE: tta/sum.tta
; Som van 1 tot 10 met alleen moves. Uitvoer: 55.
        #0  -> R0           ; som
        #10 -> R1           ; teller
lus:    R0  -> OP
        R1  -> ADD          ; som + teller
        RES -> R0
        R1  -> OP
        #1  -> SUB          ; teller - 1, zet de Z-vlag
        RES -> R1
        ?NZ #lus -> PC      ; terug als het niet nul is
        R0  -> OUT
        HALT
```

Het patroon is een aftellende lus. `#1 -> SUB` zet de Z-vlag, `RES -> R1` verandert de vlaggen niet, en `?NZ` kan dus nog de vlag van de aftrekking gebruiken.

### Fibonacci en vermenigvuldigen

```text
; FILE: tta/fib.tta
; De eerste tien Fibonacci-getallen naar de uitvoer: 0 1 1 2 3 5 8 13 21 34.
        #0  -> R0           ; a
        #1  -> R1           ; b
        #10 -> R2           ; teller
lus:    R0  -> OUT
        R0  -> OP
        R1  -> ADD          ; a + b
        R1  -> R0           ; a = b
        RES -> R1           ; b = a + b
        R2  -> OP
        #1  -> SUB
        RES -> R2
        ?NZ #lus -> PC
        HALT
```

```text
; FILE: tta/mul.tta
; 13 x 11 door herhaald optellen. Uitvoer: 143.
        #0  -> R0           ; resultaat
        #11 -> R1           ; teller
        #13 -> R2           ; vermenigvuldigtal
lus:    R0  -> OP
        R2  -> ADD
        RES -> R0
        R1  -> OP
        #1  -> SUB
        RES -> R1
        ?NZ #lus -> PC
        R0  -> OUT
        HALT
```

### Subroutines

```text
; FILE: tta/call.tta
; Een subroutine die R0 verdubbelt, twee keer aangeroepen. Uitvoer: 28.
        #7 -> R0
        CALL dubbel         ; PC2 -> R3, #dubbel -> PC
        CALL dubbel
        R0 -> OUT
        HALT
dubbel: R0  -> OP
        R0  -> ADD
        RES -> R0
        RET                 ; R3 -> PC
```

### Datageheugen: `MAR` en `MEM`

Het geheugen heeft een adresregister. Je zet het adres in `MAR` en leest of schrijft via `MEM`:

```text
; FILE: tta/array.tta
; Som van een rij van 8 bytes in het datageheugen, daarna een schrijf/lees-test. Uitvoer: 36, 99.
        .data 16, 1, 2, 3, 4, 5, 6, 7, 8
        #0  -> R0           ; som
        #16 -> R1           ; wijzer
        #8  -> R2           ; teller
lus:    R1  -> MAR          ; adresregister = wijzer
        R0  -> OP
        MEM -> ADD          ; som + mem[wijzer]
        RES -> R0
        R1  -> OP
        #1  -> ADD
        RES -> R1
        R2  -> OP
        #1  -> SUB
        RES -> R2
        ?NZ #lus -> PC
        R0  -> OUT          ; 36
        #40 -> MAR
        #99 -> MEM          ; mem[40] = 99
        MEM -> OUT          ; 99
        HALT
```

### 16-bit optellen met ADC

De carry blijft bewaard tot de volgende trigger, dus `ADC` kan hem gebruiken. Zo reken je met getallen van 16 bit op een 8-bit machine:

```text
; FILE: tta/add16.tta
; 16-bit optelling met ADC: 0x01FF + 0x0001 = 0x0200. Uitvoer: 0x00 dan 0x02.
        #0xFF -> R0         ; eerste getal, laag
        #0x01 -> R2         ; eerste getal, hoog
        R0  -> OP
        #1  -> ADD          ; laag + laag, zet de carry
        RES -> OUT          ; 0x00
        R2  -> OP
        #0  -> ADC          ; hoog + 0 + carry
        RES -> OUT          ; 0x02
        HALT
```

### Guards en de ingangspoort

```text
; FILE: tta/guards.tta
; Test van alle guards. Uitvoer: 1 3 6 7 8 9 4.
        #5 -> OP
        #5 -> SUB           ; 5 - 5 = 0: Z=1, C=1 (geen lening), N=0
        ?Z  #1 -> OUT       ; wel
        ?NZ #2 -> OUT       ; niet
        ?C  #3 -> OUT       ; wel
        ?NC #4 -> OUT       ; niet
        ?N  #5 -> OUT       ; niet
        ?NN #6 -> OUT       ; wel
        #3 -> SUB           ; 5 - 3 = 2: Z=0, C=1, N=0
        ?NZ #7 -> OUT       ; wel
        #9 -> SUB           ; 5 - 9 = 0xFC: Z=0, C=0 (lening), N=1
        ?NC #8 -> OUT       ; wel
        ?N  #9 -> OUT       ; wel
        FLAGS -> OUT        ; N C Z = 1 0 0 = 4
        HALT
```

```text
; FILE: tta/io.tta
; Lees de ingangspoort, tel er 1 bij op en schrijf het naar de uitgangspoort.
        IN  -> OP
        #1  -> ADD
        RES -> OUT
        HALT
```

## 8. Verificatie

### Acht programma's tegelijk

```verilog
// FILE: tta/tb_tta.v
// Slaat de uitvoer van een T8 op.
module outlog(input clk, input valid, input [7:0] data);
  reg [7:0] v [0:63];
  integer n = 0;
  always @(posedge clk) if (valid) begin v[n] = data; n = n + 1; end
endmodule

// Acht T8-machines tegelijk, elk met een eigen programma.
module tb_tta;
  reg clk = 0, rst_n = 0;
  wire [7:0] o1, o2, o3, o4, o5, o6, o7, o8;
  wire v1, v2, v3, v4, v5, v6, v7, v8, h1, h2, h3, h4, h5, h6, h7, h8;
  integer fouten = 0, cycli, k;

  tta #("sum.hex",   1)                       m1(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o1), .out_valid(v1), .halted(h1));
  tta #("fib.hex",   1)                       m2(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o2), .out_valid(v2), .halted(h2));
  tta #("mul.hex",   1)                       m3(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o3), .out_valid(v3), .halted(h3));
  tta #("call.hex",  1)                       m4(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o4), .out_valid(v4), .halted(h4));
  tta #("array.hex", 1, "array.dat", 1)       m5(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o5), .out_valid(v5), .halted(h5));
  tta #("add16.hex", 1)                       m6(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o6), .out_valid(v6), .halted(h6));
  tta #("guards.hex",1)                       m7(.clk(clk), .rst_n(rst_n), .in_port(8'd0),  .out_port(o7), .out_valid(v7), .halted(h7));
  tta #("io.hex",    1)                       m8(.clk(clk), .rst_n(rst_n), .in_port(8'd41), .out_port(o8), .out_valid(v8), .halted(h8));
  outlog l1(clk, v1, o1), l2(clk, v2, o2), l3(clk, v3, o3), l4(clk, v4, o4),
         l5(clk, v5, o5), l6(clk, v6, o6), l7(clk, v7, o7), l8(clk, v8, o8);
  always #5 clk = ~clk;

  reg [7:0] fibs [0:9];
  reg [7:0] gd [0:6];

  initial begin
    fibs[0]=0; fibs[1]=1; fibs[2]=1; fibs[3]=2; fibs[4]=3; fibs[5]=5; fibs[6]=8; fibs[7]=13; fibs[8]=21; fibs[9]=34;
    gd[0]=1; gd[1]=3; gd[2]=6; gd[3]=7; gd[4]=8; gd[5]=9; gd[6]=4;
    #22 rst_n = 1; cycli = 0;
    while (!(h1 && h2 && h3 && h4 && h5 && h6 && h7 && h8) && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end
    if (cycli >= 100000) begin fouten = fouten + 1; $display("FAIL: niet alle programma's stopten"); end

    if (l1.n !== 1 || l1.v[0] !== 8'd55)   begin fouten = fouten + 1; $display("FAIL sum: n=%0d v=%0d", l1.n, l1.v[0]); end
    if (l2.n !== 10) begin fouten = fouten + 1; $display("FAIL fib: %0d uitvoerwaarden", l2.n); end
    for (k = 0; k < 10; k = k + 1) if (l2.v[k] !== fibs[k]) begin fouten = fouten + 1; $display("FAIL fib[%0d] = %0d", k, l2.v[k]); end
    if (l3.n !== 1 || l3.v[0] !== 8'd143)  begin fouten = fouten + 1; $display("FAIL mul: %0d", l3.v[0]); end
    if (l4.n !== 1 || l4.v[0] !== 8'd28)   begin fouten = fouten + 1; $display("FAIL call: %0d", l4.v[0]); end
    if (l5.n !== 2 || l5.v[0] !== 8'd36 || l5.v[1] !== 8'd99) begin fouten = fouten + 1; $display("FAIL array: %0d %0d", l5.v[0], l5.v[1]); end
    if (l6.n !== 2 || l6.v[0] !== 8'h00 || l6.v[1] !== 8'h02) begin fouten = fouten + 1; $display("FAIL add16: %h %h", l6.v[0], l6.v[1]); end
    if (l7.n !== 7) begin fouten = fouten + 1; $display("FAIL guards: %0d uitvoerwaarden", l7.n); end
    for (k = 0; k < 7; k = k + 1) if (l7.v[k] !== gd[k]) begin fouten = fouten + 1; $display("FAIL guards[%0d] = %0d i.p.v. %0d", k, l7.v[k], gd[k]); end
    if (l8.n !== 1 || l8.v[0] !== 8'd42)   begin fouten = fouten + 1; $display("FAIL io: %0d", l8.v[0]); end

    if (fouten == 0) $display("PASS: acht TTA-programma's (som, Fibonacci, vermenigvuldigen, subroutine, array, 16-bit, guards, I/O) kloppen na %0d cycli", cycli);
    $finish;
  end
endmodule
```

### Willekeurige programma's tegen een referentiemodel

Net als bij W8 (week 16) doen we een willekeurige test. De testbench bevat een model dat de T8-specificatie uitvoert met gewone gehele getallen. De generator maakt 300 programma's van 40 tot 190 willekeurige moves, met willekeurige guards, alle bronnen en bestemmingen, en voorwaartse sprongen. Daarna vergelijken we registers, OP, RES, MAR, vlaggen, het hele datageheugen, de volledige uitvoerreeks en het aantal cycli.

```verilog
// FILE: tta/tb_tta_random.v
// Willekeurige TTA-programma's tegen een referentiemodel (integers, geen hardwaretrucs).
module tb_tta_random;
  reg clk = 0, rst_n = 0;
  reg [7:0] in_port = 0;
  wire [7:0] out_port, pc, r0, r1, r2, r3, res;
  wire out_valid, halted, fz, fn, fc;
  integer fouten = 0, prog, k, n, cycli;

  tta #("none", 0, "none", 0) dut(.clk(clk), .rst_n(rst_n), .in_port(in_port), .out_port(out_port),
      .out_valid(out_valid), .halted(halted), .pc_out(pc), .r0(r0), .r1(r1), .r2(r2), .r3(r3),
      .res_out(res), .flag_z(fz), .flag_n(fn), .flag_c(fc));
  always #5 clk = ~clk;

  function [23:0] mv(input [2:0] g, input [4:0] d, input [7:0] s, input [7:0] imm);
    mv = {g, d, s, imm};
  endfunction

  // DUT-uitvoer opvangen
  reg [7:0] dut_out [0:2047];
  integer dut_n;
  always @(posedge clk) if (out_valid) begin dut_out[dut_n] = out_port; dut_n = dut_n + 1; end

  // ---------- Referentiemodel ----------
  reg [23:0] prog_mem [0:255];
  integer m_r [0:3];
  integer m_op, m_res, m_mar, m_pc, m_steps;
  integer m_ram [0:255];
  reg m_z, m_n, m_c, m_halt;
  integer m_out [0:2047];
  integer m_outn;

  task model_step;
    integer w, g, d, s, imm, v, t, next_pc;
    reg go;
    begin
      w = prog_mem[m_pc]; g = (w / 2097152) % 8; d = (w / 65536) % 32; s = (w / 256) % 32; imm = w % 256;
      case (s)
        0: v = imm;
        1: v = m_r[0]; 2: v = m_r[1]; 3: v = m_r[2]; 4: v = m_r[3];
        5: v = m_res;
        6: v = m_res / 2;
        7: v = 255 - m_res;
        8: v = m_ram[m_mar];
        9: v = in_port;
        10: v = (m_pc + 2) % 256;
        11: v = (m_n ? 4 : 0) + (m_c ? 2 : 0) + (m_z ? 1 : 0);
        default: v = 0;
      endcase
      case (g)
        0: go = 1; 1: go = m_z; 2: go = !m_z; 3: go = m_c; 4: go = !m_c; 5: go = m_n; 6: go = !m_n; default: go = 0;
      endcase
      m_steps = m_steps + 1;
      next_pc = (m_pc + 1) % 256;
      if (go) begin
        case (d)
          1: m_r[0] = v;  2: m_r[1] = v;  3: m_r[2] = v;  4: m_r[3] = v;
          5: m_op = v;
          6: begin t = m_op + v;                    m_res = t % 256; m_c = (t > 255); end
          7: begin t = m_op - v;                    m_res = (t + 256) % 256; m_c = (m_op >= v); end
          16: begin t = m_op + v + (m_c ? 1 : 0);   m_res = t % 256; m_c = (t > 255); end
          15: begin t = v * 2;                      m_res = t % 256; m_c = (v >= 128); end
          8:  begin m_res = m_op & v; m_c = 0; end
          9:  begin m_res = m_op | v; m_c = 0; end
          10: begin m_res = m_op ^ v; m_c = 0; end
          12: m_mar = v;
          13: m_ram[m_mar] = v;
          14: begin m_out[m_outn] = v; m_outn = m_outn + 1; end
          31: m_halt = 1;
          default: ;
        endcase
        if (d >= 6 && d <= 10 || d == 15 || d == 16) begin m_z = (m_res == 0); m_n = (m_res >= 128); end
        if (d == 11) next_pc = v;
      end
      m_pc = next_pc;
    end
  endtask

  // ---------- Willekeurige programma's ----------
  integer idx, kind, kk;
  reg [4:0] dsel;
  reg [2:0] gsel;
  task make_program(input integer lengte);
    begin
      for (idx = 0; idx < 256; idx = idx + 1) prog_mem[idx] = mv(0, 31, 0, 0);
      for (idx = 0; idx < lengte; idx = idx + 1) begin
        kind = {$random} % 100;
        gsel = ({$random} % 100 < 40) ? 3'd0 : ({$random} % 8);
        if (kind < 6) begin
          kk = {$random} % 4;                                      // alleen vooruit springen
          prog_mem[idx] = mv(gsel, 11, 0, (idx + 1 + kk > lengte) ? lengte : idx + 1 + kk);
        end else begin
          case ({$random} % 15)
            0: dsel = 0;   1: dsel = 1;   2: dsel = 2;   3: dsel = 3;   4: dsel = 4;   5: dsel = 5;
            6: dsel = 6;   7: dsel = 7;   8: dsel = 8;   9: dsel = 9;   10: dsel = 10;
            11: dsel = 12; 12: dsel = 13; 13: dsel = 14; default: dsel = ({$random} % 2) ? 15 : 16;
          endcase
          prog_mem[idx] = mv(gsel, dsel, {$random} % 12, $random);
        end
      end
      prog_mem[lengte] = mv(0, 31, 0, 0);
    end
  endtask

  initial begin
    for (prog = 0; prog < 300; prog = prog + 1) begin
      make_program(40 + ({$random} % 150));
      in_port = $random;
      for (k = 0; k < 4; k = k + 1) m_r[k] = 0;
      m_op = 0; m_res = 0; m_mar = 0; m_pc = 0; m_steps = 0; m_z = 0; m_n = 0; m_c = 0; m_halt = 0; m_outn = 0;
      for (k = 0; k < 256; k = k + 1) begin
        m_ram[k] = {$random} % 256;
        dut.ram[k] = m_ram[k];
        dut.rom[k] = prog_mem[k];
      end
      while (!m_halt) model_step;

      dut_n = 0;
      rst_n = 0; repeat (2) @(negedge clk);
      rst_n = 1; cycli = 0;
      while (!halted && cycli < 100000) begin @(negedge clk); cycli = cycli + 1; end
      @(negedge clk);                                             // laat de laatste uitvoer nog binnenkomen

      if (!halted) begin fouten = fouten + 1; $display("FAIL prog %0d: stopte niet", prog); end
      if (cycli !== m_steps) begin fouten = fouten + 1; $display("FAIL prog %0d: %0d cycli, model %0d stappen", prog, cycli, m_steps); end
      if ({r0, r1, r2, r3} !== {m_r[0][7:0], m_r[1][7:0], m_r[2][7:0], m_r[3][7:0]}) begin fouten = fouten + 1; $display("FAIL prog %0d: registers", prog); end
      if (res !== m_res[7:0] || dut.op !== m_op[7:0] || dut.mar !== m_mar[7:0]) begin fouten = fouten + 1; $display("FAIL prog %0d: res/op/mar", prog); end
      if ({fz, fn, fc} !== {m_z, m_n, m_c}) begin fouten = fouten + 1; $display("FAIL prog %0d: vlaggen", prog); end
      if (dut_n !== m_outn) begin fouten = fouten + 1; $display("FAIL prog %0d: %0d uitvoerwaarden, model %0d", prog, dut_n, m_outn); end
      else for (k = 0; k < m_outn; k = k + 1) if (dut_out[k] !== m_out[k][7:0]) begin fouten = fouten + 1; $display("FAIL prog %0d: uitvoer %0d", prog, k); end
      for (k = 0; k < 256; k = k + 1)
        if (dut.ram[k] !== m_ram[k][7:0]) begin fouten = fouten + 1; if (fouten < 10) $display("FAIL prog %0d: ram[%0d]", prog, k); end
    end
    if (fouten == 0) $display("PASS: 300 willekeurige TTA-programma's geven identiek resultaat in hardware en referentiemodel");
    $finish;
  end
endmodule
```

Draai het en kijk of de test zijn werk doet: verander bij `ADC` de `cf` in `0` in `tta.v` en je ziet fouten verschijnen. Die opzettelijke bug wordt in de 300 programma's meteen gevonden.

## 9. Tools

```verilog
// FILE: tta/tb_tta_run.v
// Draait een geassembleerd TTA-programma en toont uitvoer en eindtoestand. Gebruik via run_tta.sh.
module tb_tta_run;
  reg clk = 0, rst_n = 0;
  reg [7:0] in_port = 0;
  wire [7:0] out_port, pc, r0, r1, r2, r3, res;
  wire out_valid, halted, fz, fn, fc;
  reg [8*64-1:0] pnaam, dnaam;
  integer cycli = 0, plus_in;

  tta #("none", 0, "none", 0) dut(.clk(clk), .rst_n(rst_n), .in_port(in_port), .out_port(out_port),
      .out_valid(out_valid), .halted(halted), .pc_out(pc), .r0(r0), .r1(r1), .r2(r2), .r3(r3),
      .res_out(res), .flag_z(fz), .flag_n(fn), .flag_c(fc));
  always #5 clk = ~clk;

  always @(posedge clk) if (out_valid) $display("  uitvoer: %0d (0x%h)", out_port, out_port);

  initial begin
    #1;
    if (!$value$plusargs("prog=%s", pnaam)) begin
      $display("PASS: tb_tta_run zonder programma. Gebruik: vvp ttarun.vvp +prog=programma.hex [+data=programma.dat] [+in=waarde]");
      $finish;
    end
    $readmemh(pnaam, dut.rom);
    if ($value$plusargs("data=%s", dnaam)) $readmemh(dnaam, dut.ram);
    if ($value$plusargs("in=%d", plus_in)) in_port = plus_in;
    #21 rst_n = 1;
    while (!halted && cycli < 1000000) begin @(negedge clk); cycli = cycli + 1; end
    @(negedge clk);
    $display("Klaar na %0d cycli (= %0d moves)", cycli, cycli);
    $display("R0=%3d R1=%3d R2=%3d R3=%3d RES=%3d  ZNC = %b%b%b", r0, r1, r2, r3, res, fz, fn, fc);
    $finish;
  end
endmodule
```

```bash
# FILE: tta/run_tta.sh
#!/bin/bash
# Gebruik: bash run_tta.sh programma.tta [invoerwaarde]
# Assembleert een TTA-programma en draait het in de simulator.
python3 tta_asm.py "$1" || exit 1
base="${1%.tta}"
iverilog -g2012 -o ttarun.vvp tb_tta_run.v tta.v || exit 1
args="+prog=$base.hex"
[ -f "$base.dat" ] && args="$args +data=$base.dat"
[ -n "$2" ] && args="$args +in=$2"
vvp ttarun.vvp $args | grep -v finish
```

```text
bash run_tta.sh sum.tta
bash run_tta.sh io.tta 41       # met invoerwaarde 41
```

## 10. W8 tegen T8: een eerlijke vergelijking

De som van 1 tot 10:

| | W8 (week 13-17) | T8 |
|--|-----------------|-----|
| Instructies | 6 | 11 moves |
| Programmagrootte | 12 bytes (16 bit per instructie) | 33 bytes (24 bit per move) |
| Cycli | 66 (2 per instructie) | 74 (1 per move) |
| Besturingseenheid | ja (microcode, 20 bit breed) | geen |
| Hardware om te bouwen | ALU + registerbestand + besturing + decoder | registers + ALU + bus + twee decoders |

T8 heeft meer instructies en grotere programma's. Wat het wint is een veel eenvoudiger machine, die sneller kan klokken (elke cyclus bestaat alleen uit "ROM lezen, bus, register laden"). En er is nog een troef: je kunt de machine uitbreiden zonder de ISA te veranderen. Een nieuwe rekeneenheid is gewoon een extra bestemming en bron. Een snelle vermenigvuldiger? Voeg `MUL` toe als trigger en `MULHI` als bron. Klaar.

Het echte voordeel zit in parallellisme. Met één bus is T8 sequentieel, maar met twee of drie bussen kan de machine twee of drie moves per cyclus doen. De moves zijn zichtbaar voor de programmeur (of compiler), die ze dus samen kan plannen. Daarom bestaan TTA's in de professionele DSP-wereld.

## 11. Lab

1. Draai alle tests: `tb_tta.v`, `tb_tta_random.v` en `test_tta_asm.py`.
2. Gebruik `python3 tta_asm.py sum.tta --list` en codeer drie moves met de hand na.
3. Schrijf `a = b + c` voor R0 = R1 + R2 in moves. Hoeveel cycli kost het?
4. Gebruik `run_tta.sh` om een programma te schrijven dat de ingangswaarde verdubbelt.
5. Meting: hoeveel cycli kost de optelling van twee 16-bit getallen (met ADC)? En hoeveel zou het kosten op een W8 (week 17, oefening 2)?

## 12. Oefeningen

1. Schrijf de moves voor `R0 = R1 − R2`.
2. Schrijf een programma dat het maximum van R0 en R1 in R0 zet, met één guarded move.
3. Schrijf de moves voor `R0 = −R0` (twee-complement).
4. Hoe schuif je R2 één plaats naar rechts? Hint: de afgeleide bron.
5. Hoeveel moves heeft `if (x == 0) y = 5` nodig, zonder sprong?
6. Vergelijk het aantal cycli en de codegrootte van de som van 1 tot 10 op W8, S8 (week 18) en T8.
7. Waarom heeft `CALL` twee moves nodig? Wat gebeurt er als de guard van de tweede move onwaar is?
8. Uitdaging: voeg een extra register `R4` toe als bron en bestemming. Welke velden en welke regels in `tta.v` pas je aan? Hoe groot is de uitbreiding van de ISA?
9. Uitdaging: ontwerp een tweede bus, dus twee moves per instructie (48 bit). Wat verandert er aan de hardware? Welke botsingen moet de programmeur vermijden (twee moves naar dezelfde bestemming, of lezen en schrijven van dezelfde trigger)?

## 13. Antwoorden

1. `R1 -> OP`, `R2 -> SUB`, `RES -> R0`.
2. `R0 -> OP`, `R1 -> SUB`, `?NC R1 -> R0`. De `SUB` berekent R0 − R1. C = 0 betekent dat er geleend is, dus R0 < R1, en dan wordt R0 vervangen door R1. De drie moves staan in de uitwerkingen hieronder.
3. `#0 -> OP`, `R0 -> SUB`, `RES -> R0`.
4. `R2 -> OP`, `#0 -> ADD` (RES = R2), `RESHR -> R2`. Dat zijn drie moves.
5. Bijvoorbeeld: `R0 -> OP`, `#0 -> ADD` (zet Z als R0 = 0), `?Z #5 -> R1`. Drie moves, zonder sprong.
6. Som van 1 tot 10: W8 heeft 12 bytes en 66 cycli, S8 21 bytes en 123 cycli, T8 33 bytes en 74 cycli. Geen enkele machine wint op alle punten.
7. Elke move heeft precies één bestemming, en `CALL` moet twee dingen doen: het terugkeeradres bewaren (bestemming `R3`) en springen (bestemming `PC`). Dat zijn dus twee moves. Is de guard van de tweede move onwaar, dan staat het terugkeeradres wel in `R3`, maar springt de machine niet. Dat is onschuldig, want `R3` wordt gewoon overschreven. Een guard op de eerste move zou gevaarlijk zijn: de sprong zou dan met een oud terugkeeradres doorgaan. Daarom zet de assembler de guard alleen op de sprong.
8. Voeg `R4` toe aan de lijst van bronnen en bestemmingen (de nummers zijn vrij), een extra `reg [7:0] r4`, een `case`-regel in de bus-mux en een in het schrijfblok, en laat de assembler-woordenboeken `DEST` en `SRC` het register kennen. De instructiebreedte verandert niet (we hebben 5 bits voor de bron en 5 voor de bestemming).
9. Elke bus krijgt eigen bron- en bestemmingsvelden. De hardware krijgt twee bussen en voor elke bestemming een keuze welke bus hem voedt. De programmeur moet voorkomen dat twee moves tegelijk naar dezelfde bestemming schrijven en dat een move een resultaat leest dat in dezelfde cyclus pas wordt geproduceerd.

De drie uitwerkingen (maximum, negatie en rechtsschuiven) staan in dit programma, en de testbench controleert ze:

```text
; FILE: tta/answers.tta
; Uitwerkingen van de oefeningen. Uitvoer: 200 9 250 91.
        ; maximum van twee getallen met een guard
        #200 -> R0
        #100 -> R1
        R0  -> OP
        R1  -> SUB          ; R0 - R1: C = 1 als R0 >= R1
        ?NC R1 -> R0        ; was R0 kleiner? dan R0 = R1
        R0  -> OUT          ; 200
        #5  -> R0
        #9  -> R1
        R0  -> OP
        R1  -> SUB
        ?NC R1 -> R0
        R0  -> OUT          ; 9
        ; negatie: 0 - 6
        #6  -> R2
        #0  -> OP
        R2  -> SUB
        RES -> OUT          ; 250 (= -6 in 8 bit)
        ; een plaats naar rechts schuiven met de afgeleide bron RESHR
        #0xB6 -> R2
        R2  -> OP
        #0  -> ADD          ; RES = R2
        RESHR -> OUT        ; 0x5B = 91
        HALT
```

```verilog
// FILE: tta/tb_tta_answers.v
module tb_tta_answers;
  reg clk = 0, rst_n = 0;
  wire [7:0] out_port;
  wire out_valid, halted;
  integer fouten = 0, cycli = 0, n = 0;
  reg [7:0] v [0:15];
  tta #("answers.hex", 1) dut(.clk(clk), .rst_n(rst_n), .in_port(8'd0), .out_port(out_port), .out_valid(out_valid), .halted(halted));
  always #5 clk = ~clk;
  always @(posedge clk) if (out_valid) begin v[n] = out_port; n = n + 1; end
  initial begin
    #22 rst_n = 1;
    while (!halted && cycli < 10000) begin @(negedge clk); cycli = cycli + 1; end
    @(negedge clk);
    if (n !== 4 || v[0] !== 8'd200 || v[1] !== 8'd9 || v[2] !== 8'd250 || v[3] !== 8'd91) begin
      fouten = fouten + 1; $display("FAIL: %0d uitvoerwaarden: %0d %0d %0d %0d", n, v[0], v[1], v[2], v[3]);
    end
    if (fouten == 0) $display("PASS: max met guard, negatie en rechtsschuiven met RESHR kloppen");
    $finish;
  end
endmodule
```

## 14. Zelftest

1. Wat is de enige instructie van een TTA?
2. Wat is een trigger?
3. Waarom heeft T8 geen besturingseenheid?
4. Hoe maak je een voorwaardelijke sprong?
5. Wat is `PC2`?

Antwoorden: (1) MOVE, van bron naar bestemming. (2) Een bestemming waarvan het schrijven een berekening in gang zet. (3) De instructie bevat zelf de velden die direct de bron- en bestemmingsdecoders aansturen. (4) Met een guarded move naar `PC`, bijvoorbeeld `?NZ #lus -> PC`. (5) Het adres van de instructie twee verder, gebruikt als terugkeeradres.

## 15. Verder lezen

- Henk Corporaal, *Microprocessor Architectures: from VLIW to TTA* (1997), het standaardwerk.
- De TTA-based Co-design Environment (TCE) van Tampere University: een open-sourceontwerpomgeving. Online te vinden.
- Zoek op "One Instruction Set Computer" en "MOVE machine" voor verwante ideeën, zoals de SUBLEQ-machine.

Volgende week: T8 voert elke instructie in één cyclus uit, maar W8 doet er twee over. Hoe maak je een CPU sneller door instructies te overlappen? Dat heet pipelining.
