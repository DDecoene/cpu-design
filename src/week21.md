---
title: "Week 21 · Hazards, sprongvoorspelling en caches"
---

<p class="subtitle">Fase 5 · Geavanceerde architecturen · ongeveer 13 uur</p>

# Week 21: Hazards, sprongvoorspelling en caches

## Wat je na deze week kunt

- data-hazards herkennen en oplossen met stalls en forwarding
- de kosten van sprongen berekenen en sprongvoorspellers (1-bit en 2-bit) vergelijken
- uitleggen waarom caches bestaan en hoe een direct-mapped cache werkt (tag, index, offset)
- de gemiddelde geheugentoegangstijd (AMAT) en de effectieve CPI berekenen
- een cache in Verilog bouwen en met meetbare patronen testen

## 1. Data-hazards in een diepere pipeline

Vorige week zagen we dat W8P geen data-hazards heeft. In de klassieke vijftrapspipeline zijn die er wel:

```text
 cyclus:           1    2    3    4    5    6
 ADD R1,R2,R3     IF   ID   EX   MEM  WB
 SUB R4,R1,R5          IF   ID   EX   MEM  WB
                            ↑
                    leest R1, maar ADD schrijft pas in cyclus 5
```

`SUB` leest R1 in cyclus 3, maar `ADD` heeft zijn resultaat al na EX (einde cyclus 3) beschikbaar en schrijft het in cyclus 5. Er zijn drie oplossingen:

| Oplossing | Idee | Kosten |
|-----------|------|--------|
| Stall | vertraag `SUB` tot R1 geschreven is | 2 verloren cycli |
| Software | de compiler zet onafhankelijke instructies ertussen of voegt NOP's in | langere code |
| Forwarding | stuur het resultaat uit het EX/MEM-register rechtstreeks naar de ALU-ingang | wat multiplexers en vergelijkers |

Bij forwarding vergelijkt de hardware de bronregisters van de instructie in EX met de bestemmingsregisters van de instructies in MEM en WB. Is er een overeenkomst, dan kiest een multiplexer aan de ALU-ingang het doorgestuurde resultaat in plaats van de registerwaarde.

```text
                     ┌──────────────── resultaat uit EX/MEM ──┐
 registerbestand ──► [MUX] ──► ALU                              │
                        ▲                                       │
                        └── kies doorgestuurd als bron = bestemming van de vorige
```

### Het load-gebruikprobleem

Een `LD` levert zijn waarde pas na de MEM-trap. De instructie erachter heeft die waarde aan het begin van EX nodig:

```text
 LD  R1,[R2]      IF   ID   EX   MEM  WB
 ADD R4,R1,R5          IF   ID   EX   ...    ← R1 pas na MEM van de LD beschikbaar
```

Zelfs met forwarding moet je één cyclus wachten: de load-use stall. Het is een bekend ontwerpprobleem en de reden dat compilers laadinstructies zo vroeg mogelijk plaatsen.

### Controlehazards

Een sprong is pas na EX (of ID) beslist. De instructies die ondertussen zijn opgehaald, zijn fout als de sprong genomen wordt. Er zijn vier strategieën:

| Strategie | Idee |
|-----------|------|
| Stall | wacht tot de sprong beslist is (kost altijd tijd) |
| Flush | haal door en gooi weg als de sprong genomen wordt (W8P) |
| Delay slot | de instructie na de sprong wordt altijd uitgevoerd (MIPS, oude RISC's), de compiler vult hem |
| Voorspellen | raad de uitkomst en herstel alleen bij een misser |

De kosten van sprongen zijn:

```text
  extra CPI  =  (sprongen per instructie) × (kans op misvoorspelling) × (straf in cycli)
```

Bij diepe pipelines is de straf groot (10 tot 20 cycli bij moderne CPU's). Dan telt elk procent voorspelnauwkeurigheid.

## 2. Sprongvoorspelling

We vergelijken vijf voorspellers.

| Voorspeller | Regel |
|-------------|-------|
| Altijd niet genomen | de eenvoudigste: gewoon doorlopen (zoals W8P) |
| Altijd genomen | het tegenovergestelde |
| BTFN (backward taken, forward not taken) | een sprong naar achteren is waarschijnlijk een lus, dus neem hem. Naar voren niet |
| 1 bit per sprong | onthoud wat deze sprong de vorige keer deed en voorspel hetzelfde |
| 2-bit teller | een verzadigende teller van 0 tot 3 per sprong. Pas na twee missers achter elkaar verander je van voorspelling |

Waarom 2 bits? Neem een lus van 10 iteraties: negen keer genomen, één keer niet, en dan weer van voren af aan. De 1-bit voorspeller mist bij het verlaten van de lus en bij de eerste ronde van de volgende keer, dus twee missers per lus. De 2-bit teller laat zich door één afwijking niet uit het veld slaan en heeft één misser per lus.

### Een simulator in Python

Eerst een instructieset-simulator voor W8, geschreven in Python, die ook een spoor bijhoudt van alle voorwaardelijke sprongen. Hij is gevalideerd tegen de Verilog-CPU: dezelfde eindresultaten en hetzelfde aantal instructies (2 cycli per instructie).

```python
# FILE: memhier/w8iss.py
"""Instructieset-simulator (ISS) voor W8 in Python. Voert een programma uit en bewaart een spoor van alle
voorwaardelijke sprongen (adres, doel, genomen of niet), zodat we sprongvoorspellers kunnen vergelijken."""

COND = {0: lambda f: True, 1: lambda f: f["z"], 2: lambda f: not f["z"], 3: lambda f: f["c"],
        4: lambda f: not f["c"], 5: lambda f: f["n"] != f["v"], 6: lambda f: f["n"] == f["v"], 7: lambda f: f["n"]}


def sgn(x):
    return x - 256 if x >= 128 else x


def alu(fn, a, b):
    c = v = False
    if fn == 0:
        s = a + b; y = s & 255; c = s > 255
        v = not -128 <= sgn(a) + sgn(b) <= 127
    elif fn == 1:
        y = (a - b) & 255; c = a >= b
        v = not -128 <= sgn(a) - sgn(b) <= 127
    elif fn == 2: y = a & b
    elif fn == 3: y = a | b
    elif fn == 4: y = a ^ b
    elif fn == 5: y = 255 - a
    elif fn == 6: y = (a << 1) & 255; c = a >= 128
    else: y = a >> 1; c = bool(a & 1)
    return y, {"z": y == 0, "n": y >= 128, "c": c, "v": v}


def run(prog, data=None, max_steps=2_000_000):
    """Geeft (registers, vlaggen, geheugen, aantal instructies, sprongspoor)."""
    r = [0] * 8
    mem = list(data) if data else [0] * 256
    f = {"z": False, "n": False, "c": False, "v": False}
    pc, steps, branches = 0, 0, []
    while steps < max_steps:
        w = prog[pc]
        op, rd, rs1, rs2, fn = w >> 12, (w >> 9) & 7, (w >> 6) & 7, (w >> 3) & 7, w & 7
        imm, off, cnd = w & 255, w & 63, (w >> 9) & 7
        here, pc = pc, (pc + 1) & 255
        steps += 1
        if op == 0:
            r[rd], f = alu(fn, r[rs1], r[rs2])
        elif op == 1:
            r[rd] = imm
        elif op == 2:
            r[rd], f = alu(0, r[rd], imm)
        elif op == 3:
            r[rd] = mem[(r[rs1] + off) & 255]
        elif op == 4:
            mem[(r[rs1] + off) & 255] = r[rd]
        elif op == 5:
            taken = COND[cnd](f)
            if cnd != 0:                                   # alleen echte voorwaardelijke sprongen tellen mee
                branches.append((here, imm, taken))
            if taken:
                pc = imm
        elif op == 6:
            _, f = alu(1, r[rs1], r[rs2])
        elif op == 7:
            _, f = alu(1, r[rd], imm)
        elif op == 8:
            r[7] = pc; pc = imm
        elif op == 9:
            pc = r[rs1]
        elif op == 15:
            break
    return r, f, mem, steps, branches
```

Daarna de voorspellers en een functie die de nauwkeurigheid over een spoor meet:

```python
# FILE: memhier/predict.py
"""Sprongvoorspellers vergelijken op sporen van echte W8-programma's."""
from asm import assemble
from w8iss import run


class AlwaysNotTaken:
    naam = "altijd niet genomen"
    kort = "nooit"
    def predict(self, pc, target): return False
    def update(self, pc, taken): pass


class AlwaysTaken:
    naam = "altijd genomen"
    kort = "altijd"
    def predict(self, pc, target): return True
    def update(self, pc, taken): pass


class BackwardTaken:
    naam = "achteruit genomen (BTFN)"
    kort = "BTFN"
    def predict(self, pc, target): return target < pc      # lussen springen terug: voorspel 'genomen'
    def update(self, pc, taken): pass


class OneBit:
    naam = "1 bit per sprong"
    kort = "1-bit"
    def __init__(self): self.t = {}
    def predict(self, pc, target): return self.t.get(pc, False)
    def update(self, pc, taken): self.t[pc] = taken


class TwoBit:
    """Verzadigende teller 0..3: 0-1 voorspelt 'niet genomen', 2-3 'genomen'."""
    naam = "2 bit teller per sprong"
    kort = "2-bit"
    def __init__(self): self.t = {}
    def predict(self, pc, target): return self.t.get(pc, 1) >= 2
    def update(self, pc, taken):
        c = self.t.get(pc, 1)
        self.t[pc] = min(3, c + 1) if taken else max(0, c - 1)


PREDICTORS = [AlwaysNotTaken, AlwaysTaken, BackwardTaken, OneBit, TwoBit]


def accuracy(trace, predictor):
    """Fractie goed voorspelde sprongen in een spoor van (adres, doel, genomen)."""
    if not trace:
        return 1.0
    goed = 0
    for pc, target, taken in trace:
        if predictor.predict(pc, target) == taken:
            goed += 1
        predictor.update(pc, taken)
    return goed / len(trace)


def spoor(naam):
    prog, data, _, _ = assemble(open(naam + ".asm").read())
    _, _, _, steps, branches = run(prog, data)
    return steps, branches


if __name__ == "__main__":
    programmas = ["sum", "mul", "sort", "primes", "gcd", "calls"]
    print(f"{'programma':10} {'sprongen':>8} " + " ".join(f"{p.kort:>8}" for p in PREDICTORS))
    for naam in programmas:
        steps, tr = spoor(naam)
        cijfers = [accuracy(tr, P()) for P in PREDICTORS]
        print(f"{naam:10} {len(tr):8d} " + " ".join(f"{100 * c:7.1f}%" for c in cijfers))
```

De test controleert eerst dat de ISS dezelfde uitkomsten geeft als de Verilog-CPU, en daarna het gedrag van de voorspellers op een synthetisch lusspoor:

```python
# FILE: memhier/test_predict.py
# Test van de ISS (tegen de resultaten van de Verilog-CPU) en van de voorspellers.
from asm import assemble
from w8iss import run
from predict import AlwaysNotTaken, AlwaysTaken, BackwardTaken, OneBit, TwoBit, accuracy, spoor

def uitvoeren(naam):
    prog, data, _, _ = assemble(open(naam + ".asm").read())
    return run(prog, data)

# Dezelfde uitkomsten en instructieaantallen als de Verilog-testbenches (2 cycli per instructie)
r, f, mem, steps, _ = uitvoeren("sum");     assert r[1] == 55 and steps * 2 == 66
r, f, mem, steps, _ = uitvoeren("mul");     assert (r[5] << 8 | r[4]) == 30000 and steps * 2 == 190
r, f, mem, steps, _ = uitvoeren("sort");    assert mem[16:24] == [1, 3, 17, 55, 77, 90, 128, 200] and steps * 2 == 564
r, f, mem, steps, _ = uitvoeren("primes");  assert r[3] == 25 and steps * 2 == 3596
r, f, mem, steps, _ = uitvoeren("gcd");     assert r[1] == 21 and steps * 2 == 60
r, f, mem, steps, _ = uitvoeren("calls");   assert r[3] == 9 and r[2] == 144 and steps * 2 == 114

# Een lus van 10 iteraties: negen keer genomen, één keer niet; 100 keer herhaald.
lus = ([(10, 4, True)] * 9 + [(10, 4, False)]) * 100
assert abs(accuracy(lus, AlwaysNotTaken()) - 0.10) < 1e-9
assert abs(accuracy(lus, AlwaysTaken()) - 0.90) < 1e-9
assert abs(accuracy(lus, BackwardTaken()) - 0.90) < 1e-9
een = accuracy(lus, OneBit())
twee = accuracy(lus, TwoBit())
assert 0.79 <= een <= 0.81, een           # twee missers per lusronde
assert 0.89 <= twee <= 0.91, twee         # één misser per lusronde
assert twee > een

# Een afwisselende sprong (T N T N ...) is de grote vijand van de 1-bit voorspeller
wissel = [(5, 1, bool(i % 2)) for i in range(1000)]
assert accuracy(wissel, OneBit()) < 0.01

print("PASS: ISS komt overeen met de Verilog-CPU en de voorspellers gedragen zich zoals verwacht")
```

De bestanden `asm.py` en de zes `.asm`-programma's staan al in `labs/cpu/`. Kopieer ze naar `labs/memhier/`.

<!-- COPY cpu/asm.py memhier/asm.py -->
<!-- COPY cpu/sum.asm memhier/sum.asm -->
<!-- COPY cpu/mul.asm memhier/mul.asm -->
<!-- COPY cpu/sort.asm memhier/sort.asm -->
<!-- COPY cpu/primes.asm memhier/primes.asm -->
<!-- COPY cpu/gcd.asm memhier/gcd.asm -->
<!-- COPY cpu/calls.asm memhier/calls.asm -->

### De resultaten op echte programma's

`python3 predict.py` geeft (percentage goed voorspelde sprongen):

| Programma | Sprongen | Nooit | Altijd | BTFN | 1-bit | 2-bit |
|-----------|:--------:|:-----:|:------:|:----:|:-----:|:-----:|
| som | 10 | 10,0 % | 90,0 % | 90,0 % | 80,0 % | 80,0 % |
| mul | 28 | 32,1 % | 67,9 % | 53,6 % | 50,0 % | 50,0 % |
| sort | 63 | 34,9 % | 65,1 % | 65,1 % | 54,0 % | 65,1 % |
| priem | 365 | 46,6 % | 53,4 % | 72,9 % | 78,6 % | 88,2 % |
| ggd | 11 | 72,7 % | 27,3 % | 72,7 % | 72,7 % | 63,6 % |
| subroutines | 15 | 13,3 % | 86,7 % | 86,7 % | 73,3 % | 80,0 % |

Wat leren we hiervan?

1. Er is geen winnaar op alle programma's. De 2-bit teller wint bij `priem` (88 %), maar verliest van "altijd genomen" bij de som en van BTFN bij `ggd`.
2. Korte programma's leren de voorspeller niet snel genoeg. De 11 sprongen van `ggd` zijn te weinig om patronen te leren.
3. Datagestuurde sprongen (`mul` en `sort`) zijn moeilijk. Of een bit 1 is of het ene element groter is dan het andere, lijkt op een muntworp, en dan helpt geen voorspeller veel.
4. Bij grote programma's met veel herhaling (`priem`) werken dynamische voorspellers het best. Daarom gebruiken echte CPU's ze: miljoenen sprongen en patronen die terugkomen.

## 3. Waarom caches?

De kloof tussen processor en geheugen is groot en wordt nog steeds groter. Een moderne CPU voert instructies uit in minder dan een nanoseconde, terwijl een DRAM-toegang tientallen nanoseconden duurt, dus honderden cycli. Zonder tegenmaatregel zou de CPU het grootste deel van de tijd wachten.

De oplossing is een geheugenhiërarchie: een klein, supersnel geheugen (de cache) dicht bij de CPU dat kopieën bewaart van wat je recent gebruikte.

| Niveau | Typische grootte | Typische snelheid |
|--------|-----------------|-------------------|
| Registers | tientallen bytes | minder dan 1 ns |
| L1-cache | tientallen KB | ~1 ns |
| L2/L3-cache | MB's | 3 tot 15 ns |
| Hoofdgeheugen (DRAM) | GB's | ~50 tot 100 ns |
| Opslag (SSD) | honderden GB | tienduizenden ns |

Het werkt dankzij locality: programma's gebruiken opnieuw wat ze eerder gebruikten. Bij temporele locality gebruik je wat je net gebruikte waarschijnlijk zo weer (een lusteller). Bij spatiale locality gebruik je wat dicht bij het gebruikte staat waarschijnlijk straks (het volgende element van een rij).

Daarom haalt een cache bij een miss niet één byte op maar een hele regel (line) van meerdere bytes.

### Hoe zoekt een cache?

Een direct-mapped cache verdeelt het adres in drie delen. Hier is dat in onze 8-bit voorbeeldcache met 16 regels van 4 bytes:

```text
 adres (8 bit):   [ tag: 2 bit ][ index: 4 bit ][ offset: 2 bit ]
                      │             │               └─ welke byte in de regel
                      │             └─ welke regel in de cache (16 regels)
                      └─ welk blok uit het geheugen zit er nu in?
```

Bij een toegang kijkt de cache in regel `index`. Staat daar een geldige regel (`valid`) met dezelfde `tag`, dan is het een hit. Anders is het een miss: de cache haalt de regel uit het geheugen, zet hem op die plek (de oude gaat eruit) en levert de byte.

### Soorten caches

| Soort | Idee | Voordeel en nadeel |
|-------|------|-------------------|
| Direct-mapped | elk blok kan op precies één plek | eenvoudig en snel, maar blokken botsen |
| Set-associatief (n-weg) | elk blok kan op n plekken in een set | minder botsingen, wat meer hardware |
| Volledig associatief | elk blok op elke plek | geen botsingen, maar veel vergelijkers |

### Schrijfbeleid

Bij write-through gaat elke schrijfactie meteen ook naar het hoofdgeheugen. Dat is eenvoudig, maar elke schrijfactie is langzaam. Bij write-back schrijf je alleen in de cache, markeer je de regel als "vuil" (`dirty`) en schrijf je pas terug als de regel wordt verwijderd. Dat is sneller, maar ingewikkelder. Daarnaast is er de keuze tussen write-allocate en no-write-allocate: haal je bij een schrijfmiss de regel in de cache of niet?

Onze cache is write-through met no-write-allocate, want dat is het eenvoudigst.

### De drie C's van missers

| Soort | Oorzaak |
|-------|---------|
| Compulsory | de eerste toegang tot een blok moet altijd missen |
| Capacity | de werkset past niet in de cache |
| Conflict | twee blokken concurreren om dezelfde plek (alleen bij niet-volledig associatieve caches) |

### Gemiddelde geheugentoegangstijd

```text
 AMAT  =  hit-tijd  +  miss-ratio × miss-straf
```

En voor de CPI van een processor met veel geheugenacties:

```text
 CPI  =  CPI_basis  +  (geheugenacties per instructie) × miss-ratio × miss-straf
```

## 4. Een cache in Verilog

De cache zit tussen de CPU en een langzaam hoofdgeheugen (`slowmem`, met instelbare vertraging LAT). We bouwen de cache als toestandsmachine met drie toestanden: `IDLE`, `WAIT_R` (wachten op een regel uit het geheugen) en `WAIT_W` (wachten op een schrijfactie).

```verilog
// FILE: memhier/cache.v
// Een direct-mapped cache voor 8-bit adressen: 16 regels van 4 bytes (64 bytes in totaal).
// Adres: [7:6] tag, [5:2] index (regel), [1:0] plaats in de regel. Write-through, geen allocatie bij schrijven.

// Langzaam hoofdgeheugen: elke bewerking duurt LAT klokcycli.
module slowmem #(parameter LAT = 4) (
  input             clk,
  input             start,
  input             we,
  input      [7:0]  addr,
  input      [7:0]  wdata,
  output reg        done,
  output reg [31:0] line      // 4 bytes vanaf het (op 4 uitgelijnde) adres
);
  reg [7:0] mem [0:255];
  reg       busy, we_l;
  reg [7:0] a_l, w_l;
  integer   cnt;
  initial begin busy = 0; done = 0; cnt = 0; end

  always @(posedge clk) begin
    done <= 1'b0;
    if (start) begin
      busy <= 1'b1; cnt <= LAT; we_l <= we; a_l <= addr; w_l <= wdata;
    end else if (busy) begin
      cnt <= cnt - 1;
      if (cnt == 1) begin
        busy <= 1'b0; done <= 1'b1;
        if (we_l) mem[a_l] <= w_l;
        else      line <= {mem[{a_l[7:2], 2'd3}], mem[{a_l[7:2], 2'd2}], mem[{a_l[7:2], 2'd1}], mem[{a_l[7:2], 2'd0}]};
      end
    end
  end
endmodule

module cache #(parameter LAT = 4) (
  input            clk,
  input            rst_n,
  input            req,         // houd req vast tot ready verschijnt
  input            we,
  input      [7:0] addr,
  input      [7:0] wdata,
  output reg [7:0] rdata,
  output reg       ready,       // één klokperiode hoog als de aanvraag klaar is
  output reg [31:0] hits,
  output reg [31:0] misses
);
  localparam IDLE = 2'd0, WAIT_R = 2'd1, WAIT_W = 2'd2;

  reg [31:0] data  [0:15];      // elke regel: 4 bytes
  reg [1:0]  tag   [0:15];
  reg [15:0] valid;
  reg [1:0]  state;
  reg [7:0]  a_l, w_l;          // vastgelegde aanvraag tijdens het wachten
  reg        bm_start, bm_we;
  reg [7:0]  bm_addr, bm_wdata;
  wire       bm_done;
  wire [31:0] bm_line;

  slowmem #(LAT) backing(clk, bm_start, bm_we, bm_addr, bm_wdata, bm_done, bm_line);

  wire [3:0] idx = addr[5:2];
  wire [1:0] off = addr[1:0];
  wire [1:0] tg  = addr[7:6];
  wire       hit = valid[idx] && (tag[idx] == tg);

  function [7:0] pick(input [31:0] l, input [1:0] o);
    pick = l >> (8 * o);
  endfunction

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      state <= IDLE; valid <= 16'h0000; ready <= 0; bm_start <= 0; hits <= 0; misses <= 0; rdata <= 0;
    end else begin
      ready <= 1'b0;
      bm_start <= 1'b0;
      case (state)
        IDLE: if (req && !ready) begin
          a_l <= addr; w_l <= wdata;
          if (we) begin
            // write-through: altijd naar het hoofdgeheugen schrijven
            bm_start <= 1; bm_we <= 1; bm_addr <= addr; bm_wdata <= wdata;
            state <= WAIT_W;
          end else if (hit) begin
            hits <= hits + 1;
            rdata <= pick(data[idx], off);
            ready <= 1'b1;
          end else begin
            misses <= misses + 1;
            bm_start <= 1; bm_we <= 0; bm_addr <= {addr[7:2], 2'b00};
            state <= WAIT_R;
          end
        end
        WAIT_R: if (bm_done) begin
          data[a_l[5:2]] <= bm_line;
          tag[a_l[5:2]]  <= a_l[7:6];
          valid[a_l[5:2]] <= 1'b1;
          rdata <= pick(bm_line, a_l[1:0]);
          ready <= 1'b1;
          state <= IDLE;
        end
        WAIT_W: if (bm_done) begin
          // bij een treffer ook de regel in de cache bijwerken
          if (valid[a_l[5:2]] && tag[a_l[5:2]] == a_l[7:6]) begin
            case (a_l[1:0])
              2'd0: data[a_l[5:2]][7:0]   <= w_l;
              2'd1: data[a_l[5:2]][15:8]  <= w_l;
              2'd2: data[a_l[5:2]][23:16] <= w_l;
              2'd3: data[a_l[5:2]][31:24] <= w_l;
            endcase
          end
          ready <= 1'b1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
endmodule
```

### Test: correct en meetbaar

De testbench doet twee dingen.

1. Correctheid. Hij voert 20 000 willekeurige lees- en schrijfacties uit, terwijl een referentiemodel (een gewone array) bijhoudt wat er hoort te staan. Elke gelezen waarde moet kloppen en na afloop moet het hoofdgeheugen overeenkomen met het model (write-through).
2. Voorspelbaar gedrag. Hij test drie patronen waarvan we precies weten wat er moet gebeuren:

| Patroon | Verwachting | Waarom |
|---------|-------------|--------|
| 64 opeenvolgende bytes, 10 keer | 16 missers, 624 hits | 16 regels worden eenmalig gevuld en daarna is alles raak |
| Adressen 0, 64, 128, 192 afwisselend, 100 keer | 400 missers, 0 hits | alle vier hebben dezelfde index, dus ze verdringen elkaar (conflictmissers) |
| 16 bytes, 100 keer | 4 missers, 1596 hits | de werkset van 4 regels past ruim |

```verilog
// FILE: memhier/tb_cache.v
module tb_cache;
  reg clk = 0, rst_n = 0, req = 0, we = 0;
  reg  [7:0] addr = 0, wdata = 0;
  wire [7:0] rdata;
  wire ready;
  wire [31:0] hits, misses;
  integer fouten = 0, i, p, k, cyc, t0, totaal, hits_start, miss_start;
  reg [7:0] model [0:255];
  reg [7:0] want;

  cache #(4) dut(clk, rst_n, req, we, addr, wdata, rdata, ready, hits, misses);
  always #5 clk = ~clk;
  always @(posedge clk) cyc = cyc + 1;

  // Eén aanvraag: stuur en wacht tot ready. Geeft de gelezen waarde in 'want_out' via rdata.
  task access(input is_write, input [7:0] a, input [7:0] w);
    begin
      @(negedge clk);
      req = 1; we = is_write; addr = a; wdata = w;
      @(posedge clk);
      while (!ready) @(posedge clk);
      @(negedge clk);
      req = 0; we = 0;
    end
  endtask

  task nulmeting; begin hits_start = hits; miss_start = misses; t0 = cyc; end endtask

  initial begin
    cyc = 0;
    #22 rst_n = 1;
    // Beginwaarden in het hoofdgeheugen en in het model.
    for (i = 0; i < 256; i = i + 1) begin model[i] = $random; dut.backing.mem[i] = model[i]; end

    // ---- 1. Functioneel: 20000 willekeurige lees- en schrijfacties tegen een referentiemodel ----
    for (i = 0; i < 20000; i = i + 1) begin
      k = {$random} % 256;
      if ({$random} % 2) begin
        want = $random; access(1, k[7:0], want); model[k] = want;
      end else begin
        access(0, k[7:0], 8'h00);
        if (rdata !== model[k]) begin fouten = fouten + 1; if (fouten < 10) $display("FAIL: lees %0d gaf %0d i.p.v. %0d", k, rdata, model[k]); end
      end
    end
    // Alles wat in het hoofdgeheugen staat moet het model zijn (write-through).
    for (i = 0; i < 256; i = i + 1)
      if (dut.backing.mem[i] !== model[i]) begin fouten = fouten + 1; $display("FAIL: hoofdgeheugen[%0d]", i); end
    $display("willekeurig: %0d treffers, %0d missers", hits, misses);

    // ---- 2. Prestaties met gerichte toegangspatronen ----
    // Koude cache: ongeldig maken door reset.
    rst_n = 0; #1; rst_n = 1; @(negedge clk);

    // a) Scan van 64 bytes (past precies in de cache), 10 keer: 16 missers, de rest treffers.
    nulmeting;
    for (p = 0; p < 10; p = p + 1) for (i = 0; i < 64; i = i + 1) access(0, i[7:0], 8'h00);
    totaal = (hits - hits_start) + (misses - miss_start);
    $display("scan 0..63 x10: %0d toegangen, %0d treffers, %0d missers, %0d cycli", totaal, hits - hits_start, misses - miss_start, cyc - t0);
    if (misses - miss_start !== 16 || hits - hits_start !== 624) begin fouten = fouten + 1; $display("FAIL: scan-telling"); end

    // b) Stap van 64 (0, 64, 128, 192): alle vier botsen op dezelfde regel: nooit een treffer.
    rst_n = 0; #1; rst_n = 1; @(negedge clk);
    nulmeting;
    for (p = 0; p < 100; p = p + 1) for (i = 0; i < 4; i = i + 1) access(0, (i * 64), 8'h00);
    $display("stap 64 x100: %0d treffers, %0d missers", hits - hits_start, misses - miss_start);
    if (hits - hits_start !== 0 || misses - miss_start !== 400) begin fouten = fouten + 1; $display("FAIL: botsingen"); end

    // c) Een werkset van 4 regels (16 bytes) 100 keer: alleen de eerste ronde mist.
    rst_n = 0; #1; rst_n = 1; @(negedge clk);
    nulmeting;
    for (p = 0; p < 100; p = p + 1) for (i = 0; i < 16; i = i + 1) access(0, i[7:0], 8'h00);
    $display("werkset 16 bytes x100: %0d treffers, %0d missers", hits - hits_start, misses - miss_start);
    if (misses - miss_start !== 4 || hits - hits_start !== 1596) begin fouten = fouten + 1; $display("FAIL: werkset"); end

    if (fouten == 0) $display("PASS: de cache geeft altijd de juiste data en gedraagt zich zoals de theorie voorspelt");
    $finish;
  end
endmodule
```

Dat tweede patroon is leerzaam. De cache is 64 bytes groot en toch levert dit patroon van vier adressen geen enkele hit op. De vier adressen verschillen in de tagbits, maar hebben dezelfde index. Een set-associatieve cache met 2 wegen lost dit precies op.

## 5. Lab

1. Draai `python3 test_predict.py` en `python3 predict.py`. Vergelijk de uitkomst met de tabel.
2. Schrijf een eigen W8-programma met een lus die 3 keer genomen wordt en dan 1 keer niet (steeds opnieuw). Verwacht welke voorspeller wint en test dat met `predict.py`.
3. Draai `tb_cache.v`. Verander `LAT` van 4 naar 20 in de instantie. Welke tellingen blijven gelijk (hits en missers) en welke veranderen (cycli)? Waarom?
4. Verander de cache zodat een regel 8 bytes is (offset 3 bits, index 3 bits). Welke patronen worden beter en welke slechter?
5. Experiment: pas het testpatroon aan en zoek een patroon waarbij een direct-mapped cache van 64 bytes minder dan 10 % hits haalt, ook al is de werkset veel kleiner dan de cache.

## 6. Oefeningen

1. Een CPU heeft CPI 1 zonder geheugenproblemen. 30 % van de instructies is een load of store. De cache mist in 4 % van de gevallen en de straf is 30 cycli. Wat is de effectieve CPI?
2. Een cache heeft een hit-tijd van 1 cyclus, een miss-ratio van 5 % en een miss-straf van 20 cycli. Wat is de AMAT? Wat wordt het als de miss-ratio met een grotere cache naar 3 % gaat maar de hit-tijd naar 2 cycli?
3. Splits het adres `0xB7` in tag, index en offset voor onze cache (16 regels van 4 bytes). En hoeveel bits zijn tag, index en offset bij een cache van 64 regels van 16 bytes met 16-bit adressen?
4. Een lus doorloopt 8 keer de sprongen T T T N (drie genomen, één niet). Hoeveel missers heeft de 1-bit voorspeller per ronde? En de 2-bit teller (in de stationaire toestand)?
5. Een pipeline heeft 20 % sprongen, de voorspelnauwkeurigheid is 90 % en de misvoorspellingsstraf is 3 cycli. Wat is de CPI? En bij 70 % nauwkeurigheid?
6. Waarom helpt een grotere regelgrootte bij sequentiële toegang, en wanneer kan hij schaden?
7. Leg uit waarom write-through bij schrijfintensieve programma's langzaam is en wat write-back verandert.
8. Uitdaging: maak van `cache.v` een 2-weg set-associatieve cache met LRU-vervanging. Test hem met dezelfde patronen: het conflictpatroon moet nu bijna alleen hits geven.

## 7. Antwoorden

1. CPI = 1 + 0,30 × 0,04 × 30 = 1 + 0,36 = 1,36.
2. AMAT = 1 + 0,05 × 20 = 2,0 cycli. Met de grotere cache: 2 + 0,03 × 20 = 2,6 cycli. De grotere cache is hier slechter, want de lagere miss-ratio compenseert de tragere hit niet.
3. `0xB7` = `1011 0111`: tag = `10`, index = `1101` (= 13), offset = `11` (= 3). Bij 64 regels van 16 bytes is de offset 4 bits, de index 6 bits en de tag 16 − 6 − 4 = 6 bits.
4. 1-bit: twee missers per ronde van vier (de N en de eerste T erna), dus 50 % goed. 2-bit: één misser per ronde (de N), dus 75 % goed.
5. Extra CPI = 0,2 × 0,1 × 3 = 0,06, dus CPI 1,06. Bij 70 %: 0,2 × 0,3 × 3 = 0,18, dus CPI 1,18.
6. Bij sequentiële toegang levert één miss een regel op met meerdere buren die allemaal een hit worden. Maar bij een grote regel passen er minder regels in de cache en kost een miss meer tijd (meer bytes ophalen). Bij willekeurige toegang haal je dan veel bytes op die je niet gebruikt.
7. Bij write-through wacht elke schrijfactie op het trage geheugen (of op een schrijfbuffer). Write-back schrijft naar de cache en schrijft pas terug als de regel wordt verwijderd (alleen als hij vuil is). Herhaalde schrijfacties naar dezelfde regel kosten dan één terugschrijfactie.
8. Zet twee regels per set, een tagvergelijker per weg en een LRU-bit per set. Bij een miss vervang je de minst recent gebruikte weg.

## 8. Zelftest

1. Wat is forwarding?
2. Wat is het load-gebruikprobleem?
3. Waarom is een 2-bit voorspeller bij lussen beter dan een 1-bit?
4. Wat zijn tag, index en offset?
5. Wat is AMAT?

Antwoorden: (1) Een resultaat rechtstreeks naar een volgende trap sturen zonder te wachten op het registerbestand. (2) Een instructie die een net geladen waarde meteen gebruikt, moet ook met forwarding één cyclus wachten. (3) Eén afwijking (het einde van de lus) verandert de voorspelling niet, dus er is één misser per lus in plaats van twee. (4) De tag identificeert het blok, de index kiest de regel en de offset kiest de byte in de regel. (5) De gemiddelde toegangstijd: hit-tijd + miss-ratio × miss-straf.

## 9. Verder lezen

- Hennessy en Patterson, *Computer Architecture: A Quantitative Approach*, hoofdstuk 2 (geheugenhiërarchie) en 3 (parallellisme op instructieniveau, sprongvoorspelling).
- Ulrich Drepper, *What Every Programmer Should Know About Memory* (online): hoe caches in de praktijk werken.
- Zoek "TAGE predictor" op: de voorspellers in moderne CPU's halen meer dan 95 % nauwkeurigheid.

Volgende week: een CPU die alleen rekent is niet erg nuttig. We voegen invoer en uitvoer toe, met een seriële poort (UART), een timer en interrupts.
