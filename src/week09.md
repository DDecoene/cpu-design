---
title: "Week 9 · Verilog: hardware beschrijven in plaats van programmeren"
---

<p class="subtitle">Fase 3 · Verilog en de ALU · ongeveer 11 uur</p>

# Week 9: Verilog, hardware beschrijven

## Wat je na deze week kunt

- uitleggen waarom Verilog geen programmeertaal is in de gewone zin
- `wire` en `reg`, `assign`, `always @*` en `always @(posedge clk)` goed gebruiken
- het verschil tussen blokkerende (`=`) en niet-blokkerende (`<=`) toekenningen uitleggen en laten zien
- parameters, `generate`, `function` en `casez` gebruiken
- de gangbare beginnersfouten herkennen (latches, meerdere drivers, verkeerde breedtes)

## 1. Hardware is geen programma

In een programmeertaal als Python of C voert de computer je regels na elkaar uit. In Verilog beschrijf je een schakeling. Alles wat je opschrijft bestaat tegelijk en werkt parallel. Twee `assign`-regels onder elkaar vormen dus geen volgorde: het zijn twee stukjes hardware die allebei de hele tijd actief zijn.

```verilog
assign y = a & b;     // een AND-poort, altijd actief
assign z = a | b;     // een OR-poort, ook altijd actief; volgorde maakt niet uit
```

Je kunt Verilog voor twee doelen gebruiken. Bij synthese vertaalt de tool je code naar echte poorten en flipflops (voor een FPGA of chip). Daar is maar een deel van de taal voor geschikt, de synthetiseerbare subset. Bij simulatie test je het gedrag met een testbench, en daar mag alles, ook vertragingen als `#10` en `$display`.

We maken steeds duidelijk welke van de twee het is. Code in een CPU-module is synthetiseerbaar, code in een `tb_*.v` is alleen voor simulatie.

## 2. De bouwstenen

### Module

Elk stukje hardware is een module met poorten (ingangen en uitgangen):

```verilog
module naam (
  input  wire        clk,
  input  wire [7:0]  a,
  output wire [7:0]  y
);
  // inhoud
endmodule
```

### `wire` en `reg`

| Type | Betekenis | Wordt aangestuurd door |
|------|-----------|------------------------|
| `wire` | een draad | `assign`, of de uitgang van een module |
| `reg` | een variabele binnen een `always`-blok | `=` of `<=` in een `always`-blok |

`reg` betekent niet "register". Een `reg` kan een draad worden of een flipflop, afhankelijk van het soort `always`-blok. Het is de verwarrendste naam in de taal. SystemVerilog heeft er een beter alternatief voor, `logic`, waar we zo naar kijken.

### De twee soorten `always`

```verilog
// Combinatorisch: herberekent bij elke wijziging. Geen klok, geen geheugen.
always @* begin
  y = a & b;
end

// Sequentieel: voert uit op de klokflank. Dit zijn flipflops.
always @(posedge clk) begin
  q <= d;
end
```

## 3. Blokkerend en niet-blokkerend

Dit is de belangrijkste regel van de week.

| | Operator | Gebruik in |
|--|----------|------------|
| Blokkerend | `=` | combinatorische `always @*` |
| Niet-blokkerend | `<=` | sequentiële `always @(posedge clk)` |

Bij `<=` worden eerst alle rechterkanten gelezen en daarna alle linkerkanten tegelijk bijgewerkt, precies wat flipflops doen. Bij `=` gebeurt het regel voor regel.

Probeer het zelf:

```verilog
// FILE: week09/blocking.v
// Drie keer hetzelfde idee: een 3-staps vertraging voor een bit.
module pipe_nb(input clk, input d, output reg q1, q2, q3);
  always @(posedge clk) begin
    q1 <= d;      // alle drie lezen de OUDE waarden
    q2 <= q1;
    q3 <= q2;
  end
endmodule

// FOUT: met blokkerende toekenningen valt het hele ding in elkaar.
module pipe_bad(input clk, input d, output reg q1, q2, q3);
  always @(posedge clk) begin
    q1 = d;       // q1 is meteen d
    q2 = q1;      // dus q2 ook, meteen
    q3 = q2;      // en q3 ook: er is geen vertraging meer
  end
endmodule
```

```verilog
// FILE: week09/tb_blocking.v
module tb_blocking;
  reg clk = 0, d = 0;
  wire a1, a2, a3, b1, b2, b3;
  integer fouten = 0;
  pipe_nb  good(clk, d, a1, a2, a3);
  pipe_bad bad (clk, d, b1, b2, b3);
  always #5 clk = ~clk;

  initial begin
    // Beginwaarden: alles op 0 laten lopen.
    repeat (4) @(posedge clk);
    @(negedge clk); d = 1;
    @(posedge clk); #1;
    // Na ÉÉN klokflank moet de goede versie nog maar q1 = 1 hebben.
    if ({a1, a2, a3} !== 3'b100) begin fouten = fouten + 1; $display("FAIL: nb na 1 flank = %b%b%b", a1, a2, a3); end
    // De foute versie heeft meteen alle drie op 1.
    if ({b1, b2, b3} !== 3'b111) begin fouten = fouten + 1; $display("FAIL: bad na 1 flank = %b%b%b", b1, b2, b3); end
    @(posedge clk); #1;
    if ({a1, a2, a3} !== 3'b110) begin fouten = fouten + 1; $display("FAIL: nb na 2 flanken"); end
    @(posedge clk); #1;
    if ({a1, a2, a3} !== 3'b111) begin fouten = fouten + 1; $display("FAIL: nb na 3 flanken"); end
    if (fouten == 0) $display("PASS: <= geeft drie vertraagde bits; = laat ze in één keer doorschieten");
    $finish;
  end
endmodule
```

> **Drie regels om te onthouden.**
> 1. Klokgestuurd (`@(posedge clk)`): altijd `<=`.
> 2. Combinatorisch (`@*`): altijd `=`.
> 3. Meng ze nooit in één blok, en stuur één variabele nooit aan vanuit twee `always`-blokken.

## 4. Handige taalonderdelen

### Operatoren

| Soort | Operatoren | Opmerking |
|-------|-----------|-----------|
| Bitsgewijs | `~  &  \|  ^  ~^` | werkt per bit op vectoren |
| Reductie | `&a  \|a  ^a` | AND, OR of XOR over alle bits van `a` tot één bit; `^a` is de pariteit |
| Logisch | `!  &&  \|\|` | op waar/onwaar |
| Rekenkundig | `+  -  *  /  %` | `/` en `%` zijn zwaar; vermijd ze in hardware |
| Vergelijken | `== != < > <= >=` | |
| Shift | `<<  >>  >>>` | `>>>` is een aritmetische shift (behoudt het teken) |
| Voorwaarde | `s ? a : b` | de mux |
| Samenvoegen | `{a, b}` | concatenatie |
| Herhalen | `{4{a}}` | `a` vier keer achter elkaar |

### `parameter` en `localparam`

```verilog
module teller #(parameter W = 8) (...);   // W kan bij het gebruik worden gewijzigd
  localparam MAX = (1 << W) - 1;          // alleen binnen deze module
```

### `generate`: hardware herhalen

Een `for`-lus in een `generate`-blok maakt meerdere exemplaren van hardware. Het is geen herhaling zoals in software. Zo bouw je een N-bit opteller uit N volledige optellers:

```verilog
// FILE: week09/addn.v
module fa(input a, input b, input cin, output s, output cout);
  assign s    = a ^ b ^ cin;
  assign cout = (a & b) | (cin & (a ^ b));
endmodule

module addn #(parameter N = 8) (
  input  [N-1:0] a,
  input  [N-1:0] b,
  input          cin,
  output [N-1:0] s,
  output         cout
);
  wire [N:0] c;
  assign c[0] = cin;
  assign cout = c[N];

  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : gen_bit
      fa f(a[i], b[i], c[i], s[i], c[i+1]);
    end
  endgenerate
endmodule
```

### `function`

Een functie berekent combinatorisch een waarde:

```verilog
// FILE: week09/funcs.v
module parity_demo(input [7:0] x, output y_even, output y_odd);
  function automatic parity(input [7:0] v);
    parity = ^v;                         // 1 als het aantal enen oneven is
  endfunction
  assign y_odd  = parity(x);
  assign y_even = ~parity(x);
endmodule
```

### `case`, `casez` en voorrang

`casez` behandelt `?` als "maakt niet uit". Daarmee schrijf je een prioriteitsschakeling: de eerste regel die past wint.

```verilog
// FILE: week09/prio.v
// Prioriteitsencoder: het nummer van de hoogste ingang die 1 is.
module prio_enc8(input [7:0] in, output reg [2:0] y, output valid);
  assign valid = |in;
  always @* begin
    casez (in)
      8'b1???_????: y = 3'd7;
      8'b01??_????: y = 3'd6;
      8'b001?_????: y = 3'd5;
      8'b0001_????: y = 3'd4;
      8'b0000_1???: y = 3'd3;
      8'b0000_01??: y = 3'd2;
      8'b0000_001?: y = 3'd1;
      default:      y = 3'd0;
    endcase
  end
endmodule
```

## 5. SystemVerilog: de verbeterde variant

SystemVerilog is de moderne opvolger van Verilog (2005 en later). Alles uit Verilog werkt erin. Drie verbeteringen gebruik je meteen:

| Verilog | SystemVerilog | Voordeel |
|---------|---------------|----------|
| `reg` / `wire` | `logic` | één type voor alles |
| `always @(posedge clk)` | `always_ff @(posedge clk)` | de compiler controleert dat het echt flipflops zijn |
| `always @*` | `always_comb` | de compiler controleert dat het echt combinatorisch is (geen latch) |

Alle voorbeelden in de rest van de cursus werken met `iverilog -g2012`, dus je mag beide stijlen door elkaar gebruiken. Voor nieuw werk is de SystemVerilog-stijl aan te raden:

```verilog
// FILE: week09/sv_style.v
module counter_sv #(parameter W = 8) (
  input  logic         clk, rst_n, en,
  output logic [W-1:0] q
);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n)  q <= '0;
    else if (en) q <= q + 1'b1;
endmodule
```

## 6. Veelgemaakte fouten

| Fout | Gevolg | Hoe voorkom je het |
|------|--------|--------------------|
| In `always @*` niet alle takken een waarde geven | een ongewilde latch | geef eerst een standaardwaarde, of schrijf `default:` |
| `=` in een klokgestuurd blok | races en onverwachte vertraging | bij een klok altijd `<=` |
| Twee `always`-blokken sturen dezelfde `reg` aan | meerdere drivers, X in simulatie | één bron per signaal |
| De breedte vergeten: `wire [3:0] x = 5'd20;` | stilletjes afgekapt | geef de breedte expliciet op: `4'd5` |
| `if (a = b)` | een toekenning in plaats van een vergelijking | vergelijk met `==` |
| Een gereserveerd woord als naam gebruiken (`bit`, `int`, `logic`, `byte`) | rare syntaxfouten | kies namen als `gen_bit`, `cnt` of `wd` |
| `begin ... end` weglaten bij meerdere regels | alleen de eerste regel hoort bij de `if` | gebruik altijd `begin/end` |
| Impliciete wires: een typfout in een signaalnaam | Verilog maakt stilletjes een nieuwe 1-bit draad | zet bovenaan `` `default_nettype none `` |

Over dat laatste punt: zet in elk bestand bovenaan `` `default_nettype none `` en onderaan `` `default_nettype wire ``. Een typfout geeft dan een foutmelding in plaats van een bug die je uren zoekwerk kost.

## 7. Lab: een testbench voor de bouwstenen

```verilog
// FILE: week09/tb_bouwstenen.v
module tb_bouwstenen;
  reg  [7:0] a, b;
  reg        cin;
  wire [7:0] s;
  wire       cout;
  reg  [7:0] p_in;
  wire [2:0] p_y;
  wire       p_valid;
  wire       y_even, y_odd;
  integer i, j, k, fouten = 0;
  reg [8:0] verwacht;
  reg [2:0] ref_y;

  addn #(8) adder(a, b, cin, s, cout);
  prio_enc8 enc(p_in, p_y, p_valid);
  parity_demo par(a, y_even, y_odd);

  initial begin
    // 8-bit opteller: 2000 willekeurige gevallen plus de hoeken.
    for (i = 0; i < 2000; i = i + 1) begin
      a = $random; b = $random; cin = $random; #1;
      verwacht = a + b + cin;
      if ({cout, s} !== verwacht) begin fouten = fouten + 1; $display("FAIL add: %0d+%0d+%0d", a, b, cin); end
    end
    a = 8'hFF; b = 8'h01; cin = 0; #1;
    if ({cout, s} !== 9'h100) begin fouten = fouten + 1; $display("FAIL add: 255+1"); end

    // Prioriteitsencoder: alle 256 invoeren tegen een referentie.
    for (j = 0; j < 256; j = j + 1) begin
      p_in = j[7:0]; #1;
      ref_y = 0;
      for (k = 0; k < 8; k = k + 1) if (p_in[k]) ref_y = k[2:0];
      if (p_y !== ref_y || p_valid !== (j != 0)) begin
        fouten = fouten + 1; $display("FAIL prio bij %b: y=%0d valid=%b", p_in, p_y, p_valid);
      end
    end

    // Pariteit
    a = 8'b0000_0111; #1; if (y_odd !== 1'b1) begin fouten = fouten + 1; $display("FAIL pariteit 7"); end
    a = 8'b0000_0011; #1; if (y_odd !== 1'b0) begin fouten = fouten + 1; $display("FAIL pariteit 3"); end

    if (fouten == 0) $display("PASS: addn, prio_enc8 en parity_demo kloppen");
    $finish;
  end
endmodule
```

```verilog
// FILE: week09/tb_sv.v
module tb_sv;
  logic clk = 0, rst_n = 0, en = 0;
  logic [7:0] q;
  int fouten = 0;
  counter_sv #(8) dut(.*);
  always #5 clk = ~clk;
  initial begin
    #12 rst_n = 1; en = 1;
    repeat (300) @(posedge clk);
    #1;
    // 300 klokflanken geteld met een 8-bit teller: 300 mod 256 = 44.
    if (q !== 8'd44) begin fouten++; $display("FAIL: q = %0d", q); end
    if (fouten == 0) $display("PASS: SystemVerilog-teller (always_ff, logic) werkt");
    $finish;
  end
endmodule
```

Draai alles:

```text
cd labs/week09
iverilog -g2012 -o a.vvp tb_blocking.v blocking.v && vvp a.vvp
iverilog -g2012 -o b.vvp tb_bouwstenen.v addn.v funcs.v prio.v && vvp b.vvp
iverilog -g2012 -o c.vvp tb_sv.v sv_style.v && vvp c.vvp
```

## 8. Oefeningen

1. Welke van deze regels maakt een latch, en waarom? `always @* if (en) y = d;` Hoe repareer je het?
2. Wat is de waarde van `4'b1010 & 4'b0110`, van `&4'b1111` en van `{2{2'b10}}`?
3. Schrijf een `generate`-lus die een N-bit register uit N D-flipflops bouwt, zonder vectornotatie.
4. Herschrijf de `mux4` uit week 4 met één `case`-statement.
5. Waarom gebruik je `<=` in `always @(posedge clk)`? Neem als voorbeeld een swap: `a <= b; b <= a;`. Wat gebeurt er met `=`?
6. Schrijf een module `gray_counter` die een N-bit teller omzet naar Gray-code (`g = b ^ (b >> 1)`).
7. Uitdaging: schrijf een parametrische `popcount`-module die telt hoeveel bits van de ingang 1 zijn. Gebruik een `function` en een `for`-lus in een `always @*`.

## 9. Antwoorden

1. De regel maakt een latch: bij `en = 0` is er geen toekenning aan `y`, dus `y` houdt zijn oude waarde. De oplossing is `always @* begin y = 1'b0; if (en) y = d; end`, of een `else`-tak toevoegen.
2. `4'b1010 & 4'b0110` is 4'b0010. `&4'b1111` is 1'b1 (alle bits zijn 1). `{2{2'b10}}` is 4'b1010.
3. `genvar i; generate for (i=0;i<N;i=i+1) begin : r always @(posedge clk) q[i] <= d[i]; end endgenerate`
4. `always @* case (s) 2'd0: y = d0; 2'd1: y = d1; 2'd2: y = d2; default: y = d3; endcase`
5. Met `<=` worden `a` en `b` tegelijk gewisseld, een echte swap met twee flipflops die elkaars oude waarde overnemen. Met `=` wordt `a` eerst `b`, en daarna `b` weer `a` (die nu al gelijk is). Beide worden dus `b` en er is geen wissel.
6. `assign g = b ^ (b >> 1);` In Gray-code verschillen opeenvolgende getallen in één bit. Handig voor tellers die tussen klokdomeinen reizen.
7. `function automatic [$clog2(W):0] popcount(input [W-1:0] v); integer i; begin popcount = 0; for (i=0;i<W;i=i+1) popcount = popcount + v[i]; end endfunction`. Bij synthese wordt de lus uitgerold tot een boom van optellers.

## 10. Zelftest

1. Waarom is Verilog geen programmeertaal in de gewone zin?
2. Wanneer gebruik je `<=` en wanneer `=`?
3. Wat doet `` `default_nettype none ``?
4. Wat is de reductie-operator `^a`?
5. Hoe merk je dat je per ongeluk een latch hebt gemaakt?

Antwoorden: (1) Het beschrijft schakelingen die tegelijk bestaan, geen opeenvolgende stappen. (2) `<=` bij klokgestuurde logica en `=` bij combinatorische. (3) Een typfout in een naam geeft een fout in plaats van een nieuwe, onzichtbare draad. (4) De XOR van alle bits, dus de pariteit. (5) Een synthesistool waarschuwt, of de uitgang verandert onder bepaalde voorwaarden niet als de ingang verandert (niet alle takken kennen een waarde).

## 11. Verder lezen

- Harris en Harris, hoofdstuk 4 (hardware description languages). Een heldere uitleg.
- Cliff Cummings, "Nonblocking Assignments in Verilog Synthesis, Coding Styles That Kill!" (Sunburst Design). Een klassieker, online te vinden.
- HDLBits (hdlbits.01xz.net): honderden Verilog-oefeningen die je in de browser maakt en laat nakijken. Aan te raden voor extra oefening.

Volgende week: hoe weet je dat je ontwerp werkt? Testen is minstens de helft van het vak.
