---
title: "Week 5 · Geheugen met poorten: latches en flipflops"
---

<p class="subtitle">Fase 2 · Geheugen en tijd · ongeveer 11 uur</p>

# Week 5: Geheugen met poorten

## Wat je na deze week kunt

- uitleggen hoe een lus van twee poorten één bit kan onthouden
- het verschil tussen een latch en een flipflop uitleggen
- een D-flipflop (master-slave) uit poorten bouwen
- uitleggen wat setup time en hold time zijn en waarom schendingen gevaarlijk zijn
- een schakelaar debouncen
- gedrag beschrijven met Verilog's `always @(posedge clk)`

## 1. Het probleem: onthouden

Tot nu toe was elke uitgang een functie van de huidige ingangen. Een computer moet ook kunnen onthouden: een getal, een toestand, een programmateller. De oplossing is verrassend eenvoudig. Je laat een uitgang terugvoeren naar een ingang. Dat heet terugkoppeling (feedback).

## 2. De SR-latch

Neem twee NOR-poorten en verbind de uitgang van elk met een ingang van de ander, kruiselings:

```text
Q  = NOR(R, Q')        ← de uitgang van de onderste poort loopt terug naar de bovenste
Q' = NOR(S, Q)         ← en de uitgang van de bovenste loopt naar de onderste
```

Teken dit na op papier: twee NOR-poorten boven elkaar, S onderaan, R bovenaan en twee draden die elkaar kruisen. Die kruising is het hele geheim.

Het gedrag:

| S | R | Q (volgende) | Betekenis |
|---|---|:---:|-----------|
| 0 | 0 | vorige Q | onthoudt |
| 1 | 0 | 1 | Set |
| 0 | 1 | 0 | Reset |
| 1 | 1 | ? | verboden: beide uitgangen worden 0 en na loslaten is het resultaat onvoorspelbaar |

De truc zit in S = R = 0: elke poort houdt de uitgang van de andere vast. Zo onthouden twee poorten samen één bit.

> **Let op.** Bij het aanzetten weet de latch niet in welke toestand hij begint. Een eerste Set of Reset moet hem in een bekende toestand brengen. Dit komt in elke CPU terug als reset-signaal.

Er is ook een versie met NAND-poorten. Die heeft actief-lage ingangen (S' en R'), waarbij 0 "doe het" betekent. De NAND-latch wordt het meest gebruikt om een schakelaar te debouncen, zie paragraaf 7.

## 3. De gated D-latch

De SR-latch heeft twee nadelen: de verboden toestand, en hij reageert altijd. We willen één data-ingang `D` en een enable `E`:

- Bij E = 1 is de latch transparant: Q volgt D.
- Bij E = 0 houdt de latch vast wat hij had.

```text
S' = NAND(D, E)
R' = NAND(D', E)
Q  = NAND(S', Q')
Q' = NAND(R', Q)
```

S' en R' zijn nooit tegelijk laag, want D en D' zijn elkaars tegendeel. De verboden toestand komt dus niet meer voor.

Er blijft een nadeel. Zolang E = 1 loopt elke verandering van D meteen door naar Q. Komt Q via andere logica terug bij D terwijl E aan staat, dan krijg je een lus die blijft oscilleren. Voor een computer met een klok willen we iets strengers.

## 4. De D-flipflop: alleen kijken op de klokflank

Een flipflop neemt D over op één moment: de klokflank, meestal de stijgende flank (van 0 naar 1). Daarna negeert hij D tot de volgende flank. Zo wordt een computer met een klok voorspelbaar, omdat alles op hetzelfde moment verandert.

### Master-slave

Twee D-latches achter elkaar, met tegengestelde enable:

```text
              master                  slave
   D ───── D-latch ─── Qm ───── D-latch ───── Q
           E = CLK'               E = CLK
```

Is de klok laag, dan is de master transparant en volgt hij D, terwijl de slave dicht is en Q vasthoudt. Gaat de klok omhoog, dan sluit de master (hij bewaart de D van dat moment) en opent de slave, die het bewaarde bit doorgeeft. Is de klok hoog, dan is de master dicht, en wat D ook doet, Q verandert niet.

Q verandert dus alleen bij de stijgende flank. Echte chips gebruiken slimmere varianten, maar het principe is dit.

```verilog
// FILE: week05/latches.v
// SR-latch uit twee NOR-poorten.
module sr_latch(input s, input r, output q, output qn);
  nor g1(q,  r, qn);
  nor g2(qn, s, q);
endmodule

// Gated D-latch uit vier NAND-poorten.
module d_latch(input d, input en, output q, output qn);
  wire sn, rn;
  nand g1(sn, d, en);
  nand g2(rn, ~d, en);
  nand g3(q,  sn, qn);
  nand g4(qn, rn, q);
endmodule

// D-flipflop (stijgende flank) uit twee D-latches: master-slave.
module dff_ms(input clk, input d, output q);
  wire qm, qmn, qn;
  d_latch master(d,  ~clk, qm, qmn);
  d_latch slave (qm,  clk, q,  qn);
endmodule
```

### Het gedragsmodel in Verilog

Een ontwerper beschrijft een flipflop niet poort voor poort maar via zijn gedrag:

```verilog
// FILE: week05/dff.v
// Een D-flipflop, zoals je hem in echte ontwerpen schrijft.
module dff(input clk, input d, output reg q);
  always @(posedge clk)
    q <= d;
endmodule

// Met asynchrone reset (actief laag): werkt direct, zonder op de klok te wachten.
module dff_ar(input clk, input rst_n, input d, output reg q);
  always @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 1'b0;
    else        q <= d;
endmodule
```

`always @(posedge clk)` betekent: voer dit blok uit bij elke stijgende flank van `clk`. De `<=` is de niet-blokkerende toekenning (non-blocking). In klokgestuurde logica gebruik je altijd `<=`, in combinatorische `always @*`-blokken gebruik je `=`. Met die ene regel voorkom je de meest gemaakte beginnersfout. In week 9 leggen we hem helemaal uit.

## 5. Setup en hold

Een flipflop is een fysiek onderdeel. Om D betrouwbaar te pakken op de klokflank moet D stabiel zijn. Dat geldt voor een korte tijd voor de flank (de setup time, t_su) en voor een korte tijd erna (de hold time, t_h).

```text
 CLK  ______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
              ↑ flank
 D    ═══╳══════════════╳═══ 
          ├─ t_su ─┤├ t_h ┤
          D moet hier stabiel zijn
```

Als D dit venster schendt, kan de flipflop metastabiel worden. De uitgang blijft dan een tijdje tussen 0 en 1 hangen en kiest daarna willekeurig. Voor een 74HC74 liggen setup en hold bij 5 V in de orde van tientallen nanoseconden. Kijk in het datablad voor de precieze waarden.

Daarom moeten alle signalen in een CPU door hun logica heen zijn voordat de volgende klokflank komt. De langste route tussen twee flipflops bepaalt de maximale klokfrequentie:

```text
T_klok  ≥  t_clk→Q  +  t_logica(max)  +  t_su
```

Dit is de belangrijkste formule van digitaal ontwerp. In week 20 en 24 komen we er uitgebreid op terug.

## 6. De 74HC74

De 74HC74 bevat twee D-flipflops. Elk heeft `D` en `CLK` (stijgende flank), `Q` en `Q'`, en `SET'` (preset) en `CLR'` (clear). SET' en CLR' werken asynchroon en zijn actief laag. Ongebruikte SET' en CLR' moeten op VCC.

### De flipflop als frequentiedeler

Verbind `Q'` met `D`. Bij elke klokflank neemt de flipflop de tegengestelde waarde aan van wat hij nu heeft: hij toggelt. De uitgang wisselt dus half zo vaak als de klok:

```text
 CLK  _/‾\_/‾\_/‾\_/‾\_/‾\_
 Q    __/‾‾‾‾\_____/‾‾‾‾\__    ← frequentie = klok / 2
```

Vier van deze flipflops achter elkaar delen door 16. Dat is een ripple-teller, de basis van week 6.

## 7. Schakelaars debouncen

Een mechanische schakelaar stuitert. Bij het indrukken maakt en verbreekt hij het contact tientallen keren in een paar milliseconden. Voor jou is dat één klik, voor een digitale schakeling een reeks klokpulsen.

### Oplossing 1: een SR-latch met een wisselcontact

```text
 +5 V ─[10k]─┬─ naar S' van de NAND-latch
             └─ contact A ┐
                          ├─ gemeenschappelijke pin van de schakelaar → GND
             ┌─ contact B ┘
 +5 V ─[10k]─┴─ naar R' van de NAND-latch
```

Een SPDT-schakelaar (wisselcontact) schakelt tussen S' en R' van een NAND-SR-latch. Zodra het contact voor het eerst aankomt, flipt de latch. Daarna kan het stuiteren niets meer veranderen, want de latch zit al in de nieuwe toestand. Dit is ideaal voor een handbediende klok: één klik geeft één klokpuls.

### Oplossing 2: een RC-filter met een Schmitt-trigger

Een weerstand en een condensator laten het signaal langzaam verlopen en een 74HC14 (Schmitt-trigger-inverter) maakt er weer een scherpe flank van. Dat is eenvoudig en werkt met een gewone schakelaar zonder wisselcontact, maar het is iets minder betrouwbaar.

### Oplossing 3: in code

In FPGA-ontwerpen tel je hoeveel klokcycli de ingang stabiel is voordat je hem accepteert. Dat doen we in week 23.

## 8. Lab A: SR-latch en debouncing

Je hebt nodig: een 74HC00, een SPDT-schakelaar of twee drukknoppen, 2 × 10 kΩ en LED's met 330 Ω.

1. Bouw twee kruiselings gekoppelde NAND-poorten. Zet S' en R' met pull-ups aan +5 V. Een knop trekt S' of R' naar GND.
2. Maak S' laag: Q wordt 1 en blijft 1 nadat je loslaat. Maak R' laag: Q wordt 0. Zet LED's op Q en Q'.
3. Probeer S' en R' tegelijk laag te maken. Wat zie je, en wat gebeurt er na het loslaten?
4. Debouncetest: gebruik de latch-uitgang als klok voor een 74HC74 die toggelt (Q' naar D). Bij elke druk moet de LED precies één keer wisselen. Probeer hetzelfde met de knop zonder filter rechtstreeks op de klok. Wat gebeurt er dan?

## 9. Lab B: Verilog

Eerst de latches op poortniveau, daarna het gedrag:

```verilog
// FILE: week05/tb_latches.v
module tb_latches;
  reg s, r, d, en, clk;
  wire q_sr, qn_sr, q_dl, qn_dl, q_ff;
  integer fouten = 0;

  sr_latch sr(s, r, q_sr, qn_sr);
  d_latch  dl(d, en, q_dl, qn_dl);
  dff_ms   ff(clk, d, q_ff);

  task check(input expected, input actual, input [127:0] naam);
    if (actual !== expected) begin
      fouten = fouten + 1;
      $display("FAIL %0s: verwacht %b, kreeg %b", naam, expected, actual);
    end
  endtask

  initial begin
    // SR-latch: eerst zetten we hem in een bekende toestand.
    s = 1; r = 0; #1; check(1, q_sr, "sr set");
    s = 0; r = 0; #1; check(1, q_sr, "sr hold 1");
    s = 0; r = 1; #1; check(0, q_sr, "sr reset");
    s = 0; r = 0; #1; check(0, q_sr, "sr hold 0");

    // D-latch: transparant bij en=1, houdt vast bij en=0.
    en = 1; d = 1; #1; check(1, q_dl, "dlatch transparant 1");
    en = 0; #1; d = 0; #1; check(1, q_dl, "dlatch houdt 1 vast");
    en = 1; #1; check(0, q_dl, "dlatch transparant 0");

    // Master-slave flipflop: Q verandert alleen op de stijgende flank.
    // Eerst een klokpuls met d=0, zodat de flipflop een bekende toestand heeft (zoals een reset).
    clk = 0; d = 0; #5;   // master neemt d=0 over
    clk = 1; #5;          // slave neemt dat over
    clk = 0; #5;
    d = 1; #5;           check(0, q_ff, "ff voor flank");
    clk = 1; #5;         check(1, q_ff, "ff na flank");
    d = 0; #5;           check(1, q_ff, "ff negeert d bij klok hoog");
    clk = 0; #5;         check(1, q_ff, "ff negeert dalende flank");
    clk = 1; #5;         check(0, q_ff, "ff neemt d=0 over");

    if (fouten == 0) $display("PASS: latches en master-slave flipflop werken");
  end
endmodule
```

```verilog
// FILE: week05/tb_dff.v
module tb_dff;
  reg clk = 0, rst_n = 1, d = 0;
  wire q1, q2;
  integer fouten = 0;
  dff    u1(clk, d, q1);
  dff_ar u2(clk, rst_n, d, q2);

  always #5 clk = ~clk;

  initial begin
    d = 1; @(posedge clk); #1;
    if (q1 !== 1 || q2 !== 1) begin fouten = fouten + 1; $display("FAIL: d=1 niet overgenomen"); end
    rst_n = 0; #1;   // asynchroon: werkt zonder klokflank
    if (q2 !== 0) begin fouten = fouten + 1; $display("FAIL: async reset werkt niet"); end
    if (q1 !== 1) begin fouten = fouten + 1; $display("FAIL: dff zonder reset veranderde"); end
    rst_n = 1;
    @(posedge clk); #1;
    if (q2 !== 1) begin fouten = fouten + 1; $display("FAIL: dff_ar herstelt niet"); end
    if (fouten == 0) $display("PASS: dff en dff_ar werken");
    $finish;
  end
endmodule
```

Draai ze:

```text
cd labs/week05
iverilog -g2012 -o a.vvp tb_latches.v latches.v && vvp a.vvp
iverilog -g2012 -o b.vvp tb_dff.v dff.v && vvp b.vvp
```

Experiment: zet in de SR-latch-simulatie S en R tegelijk op 1 en daarna allebei op 0. Wat doet de simulator? Dit is een geval waarin simulatie en werkelijkheid uiteenlopen. In echte hardware hangt de uitkomst ervan af welke poort net iets sneller is.

## 10. Oefeningen

1. Teken de toestandstabel van een SR-latch met NAND-poorten. Welke combinatie is daar verboden?
2. Waarom is een D-latch in een klokcircuit van een CPU minder geschikt dan een flipflop? Noem een concreet probleem.
3. De klok is 4 MHz. Een flipflop heeft t_clk→Q = 15 ns en t_su = 10 ns. Tussen twee flipflops zit logica met 50 ns vertraging. Haalt de schakeling de klok? Wat is de maximale frequentie?
4. Vier toggle-flipflops (Q' naar D) staan in serie, elke flipflop klokt op de uitgang van de vorige. De ingangsklok is 8 MHz. Wat zijn de frequenties van de vier uitgangen?
5. Een knop stuitert 3 ms en geeft in die tijd ongeveer 10 stijgende flanken voordat hij stabiel is. Een teller telt de stijgende flanken van de knop. Hoeveel telt hij per druk? Een digitaal debounce-filter wacht tot het signaal stabiel is: hoeveel cycli van een klok van 100 kHz zijn 3 ms?
6. Schrijf in Verilog een T-flipflop (toggle) met enable `t`: bij een stijgende flank wisselt Q als `t = 1`, anders niet.
7. Uitdaging: bouw op poortniveau een D-flipflop met asynchrone reset en test hem.

## 11. Antwoorden

1. NAND-latch: S' = 0, R' = 1 geeft Q = 1. S' = 1, R' = 0 geeft Q = 0. S' = R' = 1 onthoudt. S' = R' = 0 is verboden (beide uitgangen worden 1).
2. Een transparante latch laat een verandering van D meteen door naar Q zolang E = 1. Komt Q via logica terug naar D, zoals in een teller, dan loopt het signaal rond zolang E = 1: een race of een oscillatie. Een flipflop lost dat op door maar op één moment te kijken.
3. De minimale periode is 15 + 50 + 10 = 75 ns, dus de maximale frequentie is 1 / 75 ns ≈ 13,3 MHz. De klok van 4 MHz (250 ns) haalt dat ruim.
4. 4 MHz, 2 MHz, 1 MHz en 500 kHz.
5. Ongeveer 10 tellingen per druk in plaats van 1, en dat is dus fout. 3 ms × 100 kHz = 300 klokcycli. In de praktijk wacht je 5 tot 20 ms om zeker te zijn, dus 500 tot 2000 cycli.
6. `always @(posedge clk) if (t) q <= ~q;` met `output reg q`. Geef q een beginwaarde of een reset, anders blijft hij X.
7. Gebruik twee d_latches (master-slave) en voeg een extra ingang aan de NAND's toe voor de reset. Controleer met een testbench die reset aanzet terwijl de klok stilstaat.

## 12. Zelftest

1. Hoe onthoudt een SR-latch een bit?
2. Wat is het verschil tussen een latch en een flipflop?
3. Wat is setup time?
4. Waarom debounce je een schakelaar?
5. Welke toekenning gebruik je in klokgestuurde Verilog?

Antwoorden: (1) Twee kruiselings gekoppelde poorten houden elkaars uitgang vast. (2) Een latch is transparant zolang de enable aan staat, een flipflop neemt alleen op de klokflank iets over. (3) De tijd voor de klokflank waarin de data stabiel moet zijn. (4) Omdat het contact stuitert en één klik meerdere flanken geeft. (5) De niet-blokkerende toekenning `<=`.

## 13. Verder lezen

- Ben Eater: de video's over een SR-latch, de D-flipflop en het debouncen van een schakelaar.
- Harris en Harris, hoofdstuk 3.2 (latches en flipflops).
- Het datablad van de 74HC74: zoek t_su, t_h en t_pd op.

Volgende week: één flipflop onthoudt één bit. Wat gebeurt er als we er acht naast elkaar zetten en ze ook nog laten tellen?
