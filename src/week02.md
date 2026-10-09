---
title: "Week 2 · Transistoren en logische poorten"
---

<p class="subtitle">Fase 1 · Elektronica en logica · ongeveer 11 uur</p>

# Week 2: Transistoren en logische poorten

## Wat je na deze week kunt

- uitleggen hoe een transistor als schakelaar werkt
- tekenen hoe een CMOS-inverter en een NAND-poort uit transistoren zijn opgebouwd
- de waarheidstabellen van NOT, AND, OR, NAND, NOR en XOR opschrijven
- uitleggen waarom NAND een universele poort is
- een poort op een breadboard bouwen met een 74HC-chip, met voeding, ontkoppeling en vastgezette ingangen

## 1. De transistor: een schakelaar zonder bewegende delen

Een CPU heeft maar één soort onderdeel nodig, en dat is de transistor. Een moderne processor bevat er tientallen miljarden. Het principe is eenvoudig: een kleine spanning op de ene aansluiting bepaalt of er stroom loopt tussen twee andere. Het is een schakelaar die je met elektriciteit bedient in plaats van met je vinger.

We gebruiken de MOSFET (metal-oxide-semiconductor field-effect transistor), want dat is wat vrijwel alle chips tegenwoordig gebruiken. Hij heeft drie aansluitingen:

| Aansluiting | Naam | Rol |
|-------------|------|-----|
| G | gate | de knop: hier zet je de stuurspanning op |
| D | drain | de ene kant van de schakelaar |
| S | source | de andere kant van de schakelaar |

Er zijn twee soorten. Een NMOS geleidt (de schakelaar is dicht) als de gate hoog is en verbindt een uitgang met massa. Een PMOS geleidt als de gate laag is en verbindt een uitgang met de plusspanning.

```text
      NMOS                    PMOS
   gate hoog → AAN         gate laag → AAN
   gate laag → UIT         gate hoog → UIT
```

De gate is van de rest geïsoleerd door een dun laagje oxide. In rust loopt er daarom geen stroom de gate in, en er gaat alleen een heel klein beetje heen als hij van waarde verandert. Daar komt het lage verbruik van moderne chips vandaan.

## 2. CMOS: de inverter

CMOS staat voor complementary MOS: je zet PMOS en NMOS samen in één schakeling, elk in een eigen netwerk. De inverter (NOT-poort) is het kleinste voorbeeld:

```text
        Vdd (+5 V)
          │
       ┌──┴──┐
  A ───┤ PMOS│        PMOS: aan als A = 0
       └──┬──┘
          ├──────── Y
       ┌──┴──┐
  A ───┤ NMOS│        NMOS: aan als A = 1
       └──┬──┘
          │
         GND
```

| A | PMOS | NMOS | Y |
|---|------|------|---|
| 0 | aan | uit | 1 (naar Vdd getrokken) |
| 1 | uit | aan | 0 (naar GND getrokken) |

Er is nooit een moment waarop beide transistoren tegelijk aan staan. Daardoor loopt er in rust geen stroom van plus naar min, en verbruikt de chip alleen stroom op het moment dat hij omschakelt. Dat is ook waarom een CPU warmer wordt als hij harder werkt: meer omschakelingen per seconde, meer energie.

## 3. De NAND-poort in CMOS

Een NAND met twee ingangen A en B bestaat uit twee netwerken. Het pull-up netwerk (naar Vdd) is twee PMOS parallel: is A of B laag, dan wordt de uitgang hoog getrokken. Het pull-down netwerk (naar GND) is twee NMOS in serie: alleen als A en B allebei hoog zijn, gaat de uitgang laag.

```text
         Vdd
        ┌─┴──┐
     ┌──┤P(A)├──┐      twee PMOS parallel
     │  └────┘  │
     │  ┌────┐  │
     ├──┤P(B)├──┤
     │  └────┘  │
     └─────┬────┘
           ├───────── Y
        ┌──┴──┐
        │N(A) │          twee NMOS in serie
        └──┬──┘
        ┌──┴──┐
        │N(B) │
        └──┬──┘
          GND
```

| A | B | Y = NAND(A,B) |
|---|---|:---:|
| 0 | 0 | 1 |
| 0 | 1 | 1 |
| 1 | 0 | 1 |
| 1 | 1 | 0 |

Een NAND heeft vier transistoren, een AND heeft er zes (een NAND plus een inverter). NAND is dus goedkoper dan AND, en chipontwerpers bouwen daarom liefst alles uit NAND en NOR.

### Een NAND op transistorniveau in Verilog

Verilog heeft ingebouwde primitieven `nmos` en `pmos`. We bouwen hiermee de NAND van hierboven na en testen alle vier de invoerparen:

```{.verilog include="week02/nand_cmos.v"}
```

```{.verilog include="week02/tb_nand_cmos.v"}
```

## 4. De standaardpoorten

| Poort | Symbool | Y = 1 wanneer | Verilog |
|-------|---------|---------------|---------|
| NOT | ¬A | A = 0 | `~a` |
| AND | A·B | A en B allebei 1 zijn | `a & b` |
| OR | A+B | A of B (of beide) 1 is | `a \| b` |
| NAND | ¬(A·B) | niet beide 1 zijn | `~(a & b)` |
| NOR | ¬(A+B) | beide 0 zijn | `~(a \| b)` |
| XOR | A⊕B | A en B verschillen | `a ^ b` |
| XNOR | ¬(A⊕B) | A en B gelijk zijn | `~(a ^ b)` |

De waarheidstabel voor twee ingangen:

| A | B | AND | OR | NAND | NOR | XOR |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 0 | 0 | 0 | 0 | 1 | 1 | 0 |
| 0 | 1 | 0 | 1 | 1 | 0 | 1 |
| 1 | 0 | 0 | 1 | 1 | 0 | 1 |
| 1 | 1 | 1 | 1 | 0 | 0 | 0 |

XOR is de poort van het optellen. In binair is 1 + 1 = 10: de som is 0, precies wat XOR doet, en er is een carry. Volgende week gebruiken we dat.

## 5. NAND is universeel

Met alleen NAND-poorten kun je elke logische functie bouwen. Dat laat je zien door het te doen:

- NOT: verbind beide ingangen van een NAND met elkaar. NAND(A,A) = ¬A.
- AND: een NAND gevolgd door een NOT.
- OR: eerst beide ingangen inverteren, dan een NAND (de wet van De Morgan, volgende week).
- XOR: vier NAND's.

Dit is niet alleen een denkoefening. De Apollo Guidance Computer (1966), die de maanlanding begeleidde, bestond bijna volledig uit NOR-poorten met drie ingangen. Wat je nu leert, is dus echt de basis.

```{.verilog include="week02/nand2.v"}
```

```{.verilog include="week02/gates_from_nand.v"}
```

```{.verilog include="week02/tb_universal.v"}
```

## 6. Echte chips: de 74HC-serie

De 74-serie is een familie standaardchips met logica. Texas Instruments bracht hem in 1964 uit en hij wordt nog steeds gemaakt. HC staat voor high-speed CMOS. De chips werken op 2 tot 6 V en passen in een breadboard (DIP-behuizing).

| Chip | Inhoud |
|------|--------|
| 74HC00 | 4× NAND (2 ingangen) |
| 74HC02 | 4× NOR |
| 74HC04 | 6× NOT (inverters) |
| 74HC08 | 4× AND |
| 74HC32 | 4× OR |
| 74HC86 | 4× XOR |

### Pinout van de 74HC00 (bovenaanzicht, kerf links)

```text
        ┌───╮╭───┐
   1A  1│●  ╰╯  │14 VCC
   1B  2│        │13 4B
   1Y  3│        │12 4A
   2A  4│  7400  │11 4Y
   2B  5│        │10 3B
   2Y  6│        │ 9 3A
  GND  7│        │ 8 3Y
        └────────┘
```

Pin 14 gaat naar +5 V en pin 7 naar GND. Elke poort heeft drie pins: twee ingangen (A en B) en een uitgang (Y).

### Vier regels voor het werken met deze chips

1. Sluit altijd de voeding aan. Een chip zonder voeding doet niets. Soms lijkt het of hij werkt doordat hij stroom lekt via een ingangspin, maar daar moet je niet op rekenen.
2. Zet een condensator van 100 nF tussen VCC en GND, zo dicht mogelijk bij elke chip. Bij het schakelen trekt de chip korte stroompieken en de condensator levert die. Zonder zie je rare storingen.
3. Laat nooit een ingang zweven. Verbind ongebruikte ingangen met GND, met VCC of met een andere ingang.
4. Een uitgang stuurt ingangen aan, geen andere uitgangen. Verbind nooit twee uitgangen met elkaar: als de een 1 wil zijn en de ander 0, krijg je kortsluiting.

### Tijd: de propagatievertraging

Een poort reageert niet meteen. De uitgang volgt de ingang na een korte tijd, bij een 74HC op 5 V ongeveer 10 nanoseconden (tien miljardste seconde). Dat lijkt niets, maar in een CPU staan tientallen poorten achter elkaar en die vertragingen tellen op. Ze bepalen hoe snel de klok mag lopen. Dit komt terug in week 6, 20 en 24.

## 7. Lab A: poorten op het breadboard

Je hebt nodig: een 74HC00, 74HC04 en 74HC86, condensatoren van 100 nF, twee dip-switches of drukknoppen met pull-down, en een LED met 330 Ω.

1. Zet de 74HC00 over de middengoot. Pin 14 naar +5 V, pin 7 naar GND, de 100 nF ertussen.
2. Sluit twee schakelaars aan op ingangen 1A en 1B, met een pull-down van 10 kΩ zoals in week 1.
3. Hang een LED met 330 Ω aan uitgang 1Y (de LED naar GND).
4. Loop de vier combinaties af en vul de waarheidstabel in met wat je ziet. Komt hij overeen met de NAND-tabel?
5. Bouw een inverter door beide ingangen van een tweede NAND-poort aan elkaar te knopen en meet het gedrag.
6. Bouw een AND uit twee NAND-poorten (een NAND gevolgd door een inverter).
7. Vervang de 74HC00 door een 74HC86. De pinout is gelijk (1A, 1B en 1Y op pin 1, 2 en 3). Meet de XOR-tabel.

Vragen voor je logboek: wat meet je met de multimeter op de uitgang als die hoog is? Precies 5,0 V? En wat meet je op een ingang die zweeft?

## 8. Lab B: Verilog

Sla de bestanden uit paragraaf 3 en 5 op in `labs/week02/` en draai:

```text
cd labs/week02
iverilog -g2012 -o nand.vvp tb_nand_cmos.v nand_cmos.v
vvp nand.vvp
iverilog -g2012 -o uni.vvp tb_universal.v nand2.v gates_from_nand.v
vvp uni.vvp
```

Je moet twee keer PASS zien. Breek het ontwerp daarna met opzet: wissel in `nand_cmos.v` de `pmos` en `nmos` om en kijk wat de testbench meldt. Zo zie je hoe een testbench een fout opvangt.

## 9. Oefeningen

1. Teken de CMOS-schakeling van een NOR-poort. Hint: het is het spiegelbeeld van de NAND, met PMOS in serie en NMOS parallel.
2. Hoeveel transistoren heeft een AND-poort met twee ingangen in CMOS? En een OR?
3. Bouw een NOR uit alleen NAND-poorten. Hoeveel NAND's heb je nodig?
4. Waarom verbruikt een CMOS-poort in rust (bijna) geen stroom?
5. Acht poorten staan achter elkaar, elk met 10 ns vertraging. Wat is de hoogst mogelijke klokfrequentie als het signaal de hele keten binnen één klokperiode moet doorlopen? Negeer alle andere effecten.
6. Waarom mag je twee poortuitgangen niet aan elkaar knopen?
7. Uitdaging: bouw in Verilog een majority-functie met drie ingangen (de uitgang is 1 als minstens twee ingangen 1 zijn), uitsluitend met `nand2`. Test alle acht combinaties.

## 10. Antwoorden

1. Pull-up: twee PMOS in serie (A en B). Pull-down: twee NMOS parallel. Y is alleen hoog als A en B allebei laag zijn.
2. AND = NAND + NOT = 4 + 2 = 6 transistoren. OR = NOR + NOT = 4 + 2 = 6.
3. NOR = NOT(OR). Een OR uit NAND's kost 3 poorten (twee inverters en één NAND), plus een inverter eromheen: 4 NAND's.
4. Door de complementaire opbouw staan het PMOS- en het NMOS-netwerk nooit tegelijk aan, dus er is geen pad van Vdd naar GND. Alleen tijdens het schakelen loopt er even stroom, om capaciteiten op te laden.
5. De totale vertraging is 8 × 10 ns = 80 ns. De maximale frequentie is 1 / 80 ns = 12,5 MHz.
6. Wil de ene uitgang hoog zijn (naar Vdd) en de andere laag (naar GND), dan ontstaat kortsluiting. Dat kan de chip beschadigen, en de spanning is bovendien niet gedefinieerd.
7. Majority(A,B,C) = AB + BC + AC. Neem drie NAND's: t1 = NAND(a,b), t2 = NAND(b,c), t3 = NAND(a,c). Dan is Majority = NOT(t1 · t2 · t3) = NAND(AND(t1,t2), t3). Alles uit `nand2`:

```{.verilog include="week02/majority.v"}
```

```{.verilog include="week02/tb_majority.v"}
```

## 11. Zelftest

1. Wanneer geleidt een NMOS? En een PMOS?
2. Hoeveel transistoren heeft een CMOS-NAND met twee ingangen?
3. Welke poort is universeel en wat betekent dat?
4. Waarom hoort er een condensator van 100 nF bij elke chip?
5. Wat is propagatievertraging?

Antwoorden: (1) Een NMOS bij een hoge gate, een PMOS bij een lage gate. (2) Vier. (3) NAND (en ook NOR): je kunt er elke andere logische functie mee bouwen. (4) Hij levert de korte stroompieken bij het schakelen, zodat er geen storing ontstaat. (5) De tijd tussen een verandering op de ingang en de bijbehorende verandering op de uitgang.

## 12. Verder lezen

- Charles Petzold, *Code: The Hidden Language of Computer Hardware and Software*, hoofdstuk 6 tot 11. Het mooiste boek over dit onderwerp.
- De video's van Ben Eater over transistoren en logische poorten op YouTube. Na dit hoofdstuk herken je alles.
- Het datablad van de 74HC00 (Nexperia of Texas Instruments). Zoek de propagatievertraging en de voedingsspanning op.

Volgende week: met poorten kun je rekenen, maar hoe ontwerp je een schakeling voor een willekeurige functie, en hoe houd je hem klein? Dat is Booleaanse algebra.
