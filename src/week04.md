---
title: "Week 4 · Combinatorische bouwblokken: mux, decoder en opteller"
---

<p class="subtitle">Fase 1 · Elektronica en logica · ongeveer 11 uur</p>

# Week 4: Combinatorische bouwblokken

## Wat je na deze week kunt

- uitleggen wat combinatorische logica is en waarin het verschilt van geheugen
- een multiplexer, decoder en opteller ontwerpen en zeggen waar ze in een CPU zitten
- een 4-bit opteller bouwen uit volledige optellers (ripple-carry) en de vertraging schatten
- een zevensegment-decoder maken
- vectoren en `parameter` gebruiken in Verilog

## 1. Combinatorische logica

Een schakeling is combinatorisch als de uitgang op elk moment alleen afhangt van de ingangen van dat moment. Er is geen geheugen, geen klok en geen geschiedenis. Dezelfde ingangen geven altijd dezelfde uitgang.

Alles uit week 2 en 3 was combinatorisch. Vanaf week 5 komt er geheugen bij. Een CPU combineert die twee: combinatorische blokken rekenen, geheugenelementen onthouden.

## 2. Vectoren in Verilog

Eén draad is één bit. Een bus (vector) is een bundel draden die samen een getal vormen:

```verilog
wire [7:0] data;      // 8 bits: data[7] is de hoogste, data[0] de laagste
data[3]               // één bit
data[5:2]             // vier bits (een "slice")
{a, b}                // samenvoegen (concatenatie)
8'b1010_0101          // een getal van 8 bits, binair; underscores mogen
8'hA5                 // hetzelfde, hexadecimaal
```

## 3. De multiplexer (mux)

Een mux kiest één van meerdere ingangen en geeft die door aan de uitgang. Een selectsignaal `s` bepaalt welke.

```text
   a ──┐
       ├──[MUX 2:1]── y        als s=0:  y = a
   b ──┘     ↑                 als s=1:  y = b
             s
```

De formule is y = s'·a + s·b. Voor vier ingangen heb je twee selectbits nodig, voor acht drie.

In een CPU zitten overal muxen. Gaat er een register of een constante de ALU in? Schrijf je het ALU-resultaat of data uit het geheugen terug in een register? Elk van die keuzes is een mux, en een CPU heeft er tientallen.

```{.verilog include="week04/mux.v"}
```

Met `#(parameter W = 1)` is de module herbruikbaar: `mux2 #(8)` is een 8-bit mux en `mux2 #(16)` een 16-bit mux. Je schrijft de module één keer en gebruikt hem overal.

## 4. De decoder

Een decoder zet een binair getal om in een one-hot signaal: precies één uitgang is hoog.

```text
 a[2:0] = 101 (=5)  →  y = 0010_0000     (alleen y[5] is 1)
```

Een 3→8 decoder heeft 3 ingangen en 8 uitgangen. Met een enable (`en`) zet je alle uitgangen uit.

Een CPU gebruikt dit om één register uit acht te kiezen waarin geschreven wordt, of om een geheugenchip te kiezen op basis van het adres. De decoder maakt van "nummer 5" een draad die aan gaat.

```{.verilog include="week04/decoder.v"}
```

De chip hiervoor is de 74HC138. Bij die chip zijn de uitgangen actief laag: de gekozen uitgang is 0 en de rest 1. Dat zie je vaak in 74-chips. In het datablad herken je zulke signalen aan een streep boven de naam of aan een `n` of `#` erachter.

## 5. De opteller

Binair optellen gaat net als op papier: kolom voor kolom, met een carry (overdracht) naar de volgende kolom.

```text
    0 1 1 0   (6)
  + 0 1 1 1   (7)
  ---------
    1 1 0 1   (13)
```

### De halve opteller (half adder)

Hij telt twee bits op:

| A | B | som (S) | carry (C) |
|---|---|:---:|:---:|
| 0 | 0 | 0 | 0 |
| 0 | 1 | 1 | 0 |
| 1 | 0 | 1 | 0 |
| 1 | 1 | 0 | 1 |

De som is A ⊕ B (XOR) en de carry is A·B (AND). Twee poorten.

### De volledige opteller (full adder)

In alle kolommen behalve de eerste moet je ook de carry van de vorige kolom meetellen. Een full adder heeft daarom drie ingangen: A, B en `Cin`.

```text
S    = A ⊕ B ⊕ Cin
Cout = A·B + Cin·(A ⊕ B)
```

Je bouwt hem uit twee halve optellers en een OR-poort.

```{.verilog include="week04/adder.v"}
```

### Waarom ripple-carry traag is

Bit 3 wacht op de carry van bit 2, die wacht op bit 1, enzovoort. Bij een 64-bit opteller loopt de carry door 64 trappen. Rekenen we met twee poortvertragingen per trap (een AND en een OR), dan is de slechtste vertraging bij n bits ongeveer 2n poortvertragingen.

Echte CPU's gebruiken daarom carry-lookahead of een andere snelle opteller, die vooraf berekent welke kolommen een carry doorgeven. Het is een goed voorbeeld van ruimte ruilen tegen snelheid, en dat thema komt terug in week 20 en 24. Voor onze eerste CPU is ripple-carry prima.

### De 74HC283

De 74HC283 is een 4-bit volledige opteller in één chip, met carry-lookahead erin. Op A1 tot A4 en B1 tot B4 sluit je twee getallen aan, op C0 de carry-in, en je leest S1 tot S4 en C4 af. Twee van deze chips achter elkaar vormen een 8-bit opteller. Ben Eater gebruikt ze ook in zijn 8-bit computer.

## 6. Zevensegment-decoder

Een zevensegmentdisplay heeft zeven LED-streepjes (a tot en met g). Een decoder zet een cijfer van 4 bits om in de juiste combinatie.

```text
   ─a─
  f   b
   ─g─
  e   c
   ─d─
```

```{.verilog include="week04/seg7.v"}
```

`always @*` betekent: dit is combinatorische logica, herbereken het bij elke verandering van een ingang. Een `case` is een tabel, dus een waarheidstabel in code. In week 9 gaan we dieper op deze constructies in.

## 7. Tests

```{.verilog include="week04/tb_adder4.v"}
```

```{.verilog include="week04/tb_mux_dec_seg.v"}
```

Draai alles:

```text
cd labs/week04
iverilog -g2012 -o a.vvp tb_adder4.v adder.v && vvp a.vvp
iverilog -g2012 -o b.vvp tb_mux_dec_seg.v mux.v decoder.v seg7.v && vvp b.vvp
```

## 8. Lab op het breadboard

Je hebt nodig: een 74HC283, 4 + 4 dip-switches (of 8 drukknoppen met pull-downs), 5 LED's met 330 Ω en een condensator van 100 nF.

1. Sluit voeding en ontkoppelcondensator aan op de 74HC283. Zoek in het datablad op welke pins VCC en GND zijn.
2. Zet de 8 schakelaars op A1 tot A4 en B1 tot B4. Leg C0 aan massa (pull-down of rechtstreeks aan GND).
3. Sluit LED's aan op S1 tot S4 en op C4.
4. Tel met de schakelaars 3 + 5, 7 + 9, 15 + 1 en 15 + 15 op en controleer het antwoord in binair.
5. Wat gebeurt er met C4 bij 9 + 8, en waarom?

Extra: bouw met een 74HC138 een decoder. Drie schakelaars op A0 tot A2, de enable-ingangen vast aangesloten volgens het datablad en LED's op de uitgangen. De uitgangen zijn actief laag, dus een LED brandt als de uitgang 0 is: zet hem met een weerstand tussen VCC en de uitgang.

## 9. Oefeningen

1. Teken de waarheidstabel van een full adder en controleer dat S = A ⊕ B ⊕ Cin en Cout = A·B + Cin·(A⊕B).
2. Hoeveel 2:1 muxen heb je nodig voor een 8:1 mux? En voor een 16:1?
3. Maak f(A,B,C) = Σm(1,2,4,7) met een 4:1 mux waarbij alleen A en B als select dienen. Wat zet je op de vier data-ingangen? Hint: kijk per combinatie van A en B wat C doet.
4. Maak f(A,B,C) = Σm(0,3,5) met een 3→8 decoder met actief-hoge uitgangen en één OR-poort.
5. Schat de slechtste vertraging van een 8-bit ripple-carry opteller als een full adder 20 ns nodig heeft voor de carry. Hoe snel kun je dan maximaal optellen?
6. Schrijf in Verilog een 8-bit opteller met `adder4` als bouwsteen (twee exemplaren) en test hem.
7. Uitdaging: schrijf een module `prio_enc8` (priority encoder) die het nummer geeft van de hoogste ingang die 1 is, plus een signaal `valid` als er minstens één 1 is. Waar gebruikt een CPU dit? Denk aan interrupts.

## 10. Antwoorden

1. Rijen (A,B,Cin) → (S,Cout): 000→00, 001→10, 010→10, 011→01, 100→10, 101→01, 110→01, 111→11. S is 1 bij een oneven aantal enen (dat is de XOR van drie bits) en Cout is 1 bij minstens twee enen (de majority-functie).
2. Een 8:1 mux heeft 7 muxen nodig (4 + 2 + 1), een 16:1 heeft er 15 (8 + 4 + 2 + 1). In het algemeen n−1 voor n ingangen.
3. Per (A,B): bij AB=00 is m0=0 en m1=1, dus f = C. Bij AB=01 is m2=1 en m3=0, dus f = C'. Bij AB=10 is m4=1 en m5=0, dus f = C'. Bij AB=11 is m6=0 en m7=1, dus f = C. Dus d0 = C, d1 = C', d2 = C', d3 = C. Je hebt een inverter voor C' nodig.
4. De OR van de decoderuitgangen y0, y3 en y5: f = y0 + y3 + y5.
5. De vertraging is 8 × 20 ns = 160 ns, dus de maximale frequentie is 1 / 160 ns ≈ 6,25 MHz (een grove schatting).
6. Bijvoorbeeld: `adder4 lo(a[3:0], b[3:0], cin, s[3:0], c4); adder4 hi(a[7:4], b[7:4], c4, s[7:4], cout);`
7. Een priority encoder maak je met `casez` waarbij de bovenste regel voorrang heeft, zoals `8'b1???_????: y = 7; 8'b01??_????: y = 6;` enzovoort. In een CPU bepaalt hij welke interrupt het eerst wordt bediend als er meerdere tegelijk binnenkomen.

## 11. Zelftest

1. Wat betekent combinatorisch?
2. Waarvoor gebruikt een CPU multiplexers?
3. Wat is one-hot?
4. Wat is het verschil tussen een half adder en een full adder?
5. Waarom is ripple-carry bij veel bits traag?

Antwoorden: (1) De uitgang hangt alleen van de huidige ingangen af, zonder geheugen. (2) Om te kiezen tussen bronnen: welk register of welke constante naar de ALU gaat, welk resultaat terug wordt geschreven. (3) Een code waarin precies één bit 1 is. (4) De full adder heeft een extra ingang voor de carry-in. (5) De carry moet door alle bits na elkaar, dus de vertraging groeit met het aantal bits.

## 12. Verder lezen

- Harris en Harris, hoofdstuk 5.2 (rekenkundige bouwblokken).
- Ben Eater, de video's over het bouwen van een 8-bit register en een opteller. Je ziet nu waarom het zo in elkaar zit.
- Het datablad van de 74HC283 en de 74HC151. Probeer de pinout en het blokschema te lezen.

Volgende week verlaten we de combinatorische wereld. Hoe onthoudt een schakeling een bit? Met een lus: een uitgang die terugloopt naar zijn eigen ingang.

---

> **Fase 1 is af.** Je kunt nu een transistor, een poort, een opteller en een multiplexer uitleggen en bouwen. Dat is de ene helft van een computer: het rekenen. Volgende week begint de andere helft, het geheugen.
