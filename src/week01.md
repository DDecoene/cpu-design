---
title: "Week 1 · Elektriciteit, het breadboard en je eerste schakeling"
---

<p class="subtitle">Fase 1 · Elektronica en logica · ongeveer 10 uur</p>

# Week 1: Elektriciteit, het breadboard en je eerste schakeling

## Wat je na deze week kunt

- uitleggen wat spanning, stroom en weerstand zijn
- met de wet van Ohm de weerstand voor een LED uitrekenen
- een schakeling op een breadboard bouwen en narekenen met een multimeter
- zeggen waarom digitale schakelingen met maar twee niveaus werken
- controleren of je Verilog-toolchain draait

## 1. Waar beginnen we?

Een CPU lijkt magie, maar het zijn miljarden kleine schakelaars die elkaar aan- en uitzetten. Voordat we daar een processor van kunnen maken, moeten we weten wat er in een draad gebeurt. Dat is minder dan je denkt: drie begrippen en één formule.

## 2. Spanning, stroom en weerstand

De vergelijking met water in buizen is oud en klopt maar half, maar ze helpt wel om te beginnen.

| Begrip | Symbool | Eenheid | In de wateranalogie |
|--------|---------|---------|---------------------|
| Spanning | V (of U) | volt (V) | het drukverschil dat het water duwt |
| Stroom | I | ampère (A) | hoeveel water per seconde door de buis gaat |
| Weerstand | R | ohm (Ω) | hoe smal de buis is |

Spanning bestaat altijd tussen twee punten. Een batterij van 5 V heeft 5 volt verschil tussen plus en min. Het punt dat we nul volt noemen heet massa, of ground, of GND.

Stroom is lading die door een draad beweegt. Bij de chips in deze cursus is dat weinig, meestal een paar milliampère (mA, een duizendste ampère).

Weerstand remt de stroom. Een draad heeft er bijna geen, een weerstandje (resistor) heeft er met opzet wat.

### De wet van Ohm

Dit is de enige formule die je echt moet kennen:

```text
V = I × R        →   I = V / R        →   R = V / I
```

Zet je 5 V over 1000 Ω (1 kΩ), dan loopt er 5 / 1000 = 0,005 A, dus 5 mA.

### Vermogen

Een weerstand wordt warm als er stroom doorheen gaat. Het vermogen in watt is:

```text
P = V × I
```

Bij 5 V en 5 mA is dat 25 mW. Gewone weerstandjes kunnen 250 mW (¼ W) hebben, dus daar zitten we ver onder.

> **Veiligheid.** Alles in deze cursus draait op 5 V of minder, uit een USB-poort. Dat is ongevaarlijk. Sluit zelfgebouwde schakelingen nooit aan op het stopcontact (230 V). Dat kan dodelijk zijn.

## 3. Onderdelen

### De weerstand

Een kleine cilinder met gekleurde ringen die de waarde coderen. Die code hoef je niet te leren: meet de waarde met je multimeter of zoek hem op. We gebruiken vooral 330 Ω, 1 kΩ en 10 kΩ.

### De LED

Een LED (light-emitting diode) geeft licht als er stroom doorheen loopt. Er zijn twee regels:

1. Een LED heeft een richting. De lange poot is de plus (anode), de korte de min (kathode).
2. Een LED begrenst zijn eigen stroom niet. Zonder weerstand loopt er te veel stroom en gaat hij stuk. Zet er dus altijd een weerstand bij.

Over een rode LED staat ongeveer 2 V. Dat is een typische waarde; de precieze staat in het datablad.

### De weerstand voor een LED uitrekenen

We voeden met 5 V en willen ongeveer 10 mA door de LED.

```text
Spanning over de weerstand = 5 V − 2 V = 3 V
R = V / I = 3 V / 0,010 A = 300 Ω
```

300 Ω is geen standaardwaarde, dus pakken we de dichtstbijzijnde, 330 Ω. De stroom wordt dan 3 / 330 ≈ 9,1 mA. Dat is prima.

### Drukknop en schakelaar

Een drukknop maakt verbinding zolang je hem indrukt. Een dip-switch is een rijtje schakelaartjes dat blijft staan waar je ze zet. Wij gebruiken ze als ingangen voor onze logica.

## 4. Het breadboard

Op een breadboard bouw je schakelingen zonder te solderen. Binnenin lopen metalen strips die gaatjes met elkaar verbinden.

```text
   + rail  ○ ○ ○ ○ ○ ○ ○ ○ ○ ○   ← alle gaatjes in deze rij zijn verbonden
   − rail  ○ ○ ○ ○ ○ ○ ○ ○ ○ ○   ← idem

           a b c d e   f g h i j
   rij 1   ● ● ● ● ●   ● ● ● ● ●   ← a t/m e zijn verbonden (één stukje)
   rij 2   ● ● ● ● ●   ● ● ● ● ●      f t/m j zijn verbonden (ander stukje)
   rij 3   ...
```

De twee buitenste rijen, de rails, lopen over de hele lengte. Die gebruik je voor plus en min. In het midden zijn steeds vijf gaatjes van een rij met elkaar verbonden, maar de linker- en rechterhelft niet. Daarom passen chips over de middengoot: elke pin komt in zijn eigen groep van vijf.

Voor de voeding is een USB-voedingsmodule voor breadboards het makkelijkst (zo'n €3). Zet de jumper op 5 V.

## 5. De multimeter

Zet de draaiknop op DC-spanning (V met een streepje erboven). Dan kun je drie dingen meten.

Spanning meet je parallel aan het onderdeel: de zwarte probe op massa, de rode op het punt dat je wilt weten. Weerstand meet je met het onderdeel uit de schakeling, of in elk geval met de voeding uit. En in de piepstand hoor je of twee punten verbonden zijn, handig als er iets niet werkt.

Stroom meten kan ook, maar dan moet je het circuit openknippen en de meter ertussen zetten. Meet voorlopig liever de spanning en reken de stroom uit.

## 6. Serie en parallel

Onderdelen in serie staan achter elkaar en delen dezelfde stroom. Hun weerstanden tellen op: R = R1 + R2. Onderdelen in parallel staan naast elkaar en delen dezelfde spanning. De stroom verdeelt zich.

### De spanningsdeler

Twee weerstanden in serie tussen Vin en massa. Op het punt ertussen staat een deel van de spanning:

```text
Vin ──[ R1 ]──┬──[ R2 ]── GND
              │
             Vout

Vout = Vin × R2 / (R1 + R2)
```

Met Vin = 5 V en R1 = R2 = 10 kΩ krijg je 2,5 V. Het lijkt een kleinigheid, maar dit zit in bijna elke sensorschakeling.

## 7. Van analoog naar digitaal

Spanningen in de natuur lopen vloeiend. Een digitale schakeling kiest twee niveaus:

| Niveau | Spanning (bij 5 V voeding) | Betekenis |
|--------|----------------------------|-----------|
| laag | dicht bij 0 V | 0 of onwaar |
| hoog | dicht bij 5 V | 1 of waar |

Waarom maar twee? Omdat ruis dan niets uitmaakt. Komt er 4,7 V binnen, dan weet de chip dat er een 1 bedoeld wordt. Met tien niveaus zou een kleine storing al een andere waarde opleveren. Dat binaire systeem is saai en robuust, en daarom werken computers zoals ze werken.

Een 74HC-chip leest alles boven ongeveer 70% van de voedingsspanning als hoog en alles onder ongeveer 30% als laag (de exacte getallen staan in het datablad). Ertussen ligt een verboden gebied. Wat de chip daar doet, is niet te voorspellen.

### De pull-down weerstand

Welke spanning staat er op een ingang als je de knop niet indrukt? Als de ingang nergens aan hangt, zweeft hij en pikt hij ruis op. De oplossing:

```text
 5 V ──[ knop ]──┬── naar chip-ingang
                 │
               [10 kΩ]
                 │
                GND
```

Knop open: de weerstand trekt de ingang naar 0 V, dus laag. Knop dicht: de ingang gaat naar 5 V, dus hoog. Met 10 kΩ gaat er bij een gesloten knop maar 5 V / 10 kΩ = 0,5 mA verloren.

## 8. Lab A: de eerste LED

Je hebt nodig: een 5 V-voeding, breadboard, rode LED, 330 Ω weerstand, drukknop en twee jumperdraden.

1. Steek de voedingsmodule op de rails, nog zonder hem aan te zetten.
2. Zet de LED en de 330 Ω in serie met de knop tussen de plus- en de min-rail.
3. Zet de voeding aan en druk op de knop. De LED brandt.
4. Meet de spanning over de weerstand (ongeveer 3 V) en over de LED (ongeveer 2 V). Komt de som op 5 V uit?
5. Reken de stroom uit: de spanning over de weerstand gedeeld door 330 Ω.
6. Vervang de 330 Ω door 1 kΩ. Wat doet de helderheid? Reken de nieuwe stroom uit.

Vraag voor je logboek: wat gebeurt er als je de LED zonder weerstand aansluit? Probeer het niet uit met een LED die je wilt houden.

## 9. Lab B: werkt je Verilog-toolchain?

We schrijven nu alvast een piepklein Verilog-programma. Je hoeft het nog niet te snappen, we willen alleen weten of alles werkt. Maak een map `labs/week01/` en sla deze twee bestanden op.

```verilog
// FILE: week01/inverter.v
// Een inverter: de uitgang is het omgekeerde van de ingang.
module inverter(input a, output y);
  assign y = ~a;
endmodule
```

```verilog
// FILE: week01/tb_inverter.v
// Een testbench: een "virtuele proefopstelling" die onze inverter test.
module tb_inverter;
  reg  a;
  wire y;
  inverter dut(.a(a), .y(y));

  initial begin
    a = 0; #1;
    if (y !== 1) $display("FAIL: a=0 geeft y=%b", y);
    a = 1; #1;
    if (y !== 0) $display("FAIL: a=1 geeft y=%b", y);
    $display("PASS: inverter werkt");
  end
endmodule
```

Draai in de Terminal:

```text
cd labs/week01
iverilog -g2012 -o inv.vvp tb_inverter.v inverter.v
vvp inv.vvp
```

Je moet `PASS: inverter werkt` zien. Lukt dat, dan kun je door.

## 10. Oefeningen

1. Een weerstand van 470 Ω hangt aan 5 V. Hoeveel stroom loopt er, en hoeveel vermogen wordt er omgezet?
2. Een groene LED (ongeveer 2,2 V) moet op 5 V branden met 15 mA. Welke weerstand reken je uit en welke standaardwaarde kies je?
3. Een weerstand van 1 kΩ en een van 2 kΩ staan in serie tussen 6 V en massa. Hoeveel volt staat er tussen de twee?
4. Waarom werkt een digitale schakeling met twee spanningsniveaus en niet met tien?
5. Een chip-ingang heeft geen pull-down en hangt nergens aan. Wat gebeurt er en waarom is dat een probleem?
6. Uitdaging: je hebt een 9 V-batterij en wilt een LED (2 V, 10 mA) voeden. Welke weerstand heb je nodig, hoeveel vermogen verstookt die en is ¼ W genoeg?

## 11. Antwoorden

1. I = 5 / 470 ≈ 10,6 mA. P = 5 × 0,0106 ≈ 53 mW.
2. Over de weerstand staat 5 − 2,2 = 2,8 V. R = 2,8 / 0,015 ≈ 187 Ω. Kies 180 Ω (stroom ≈ 15,6 mA) of 220 Ω (≈ 12,7 mA).
3. Vout = 6 × 2000 / (1000 + 2000) = 4 V, gemeten over de onderste weerstand van 2 kΩ tegenover massa.
4. Ruis en toleranties doen er dan veel minder toe. Bij twee niveaus is de marge groot, dus kleine storingen veranderen niets. Bovendien zijn schakelaars met twee standen (transistoren) eenvoudig en betrouwbaar te maken.
5. De ingang zweeft. Hij vangt ruis op en de chip leest willekeurig een 0 of een 1, soms ook steeds heen en weer. Het gedrag is onvoorspelbaar.
6. Over de weerstand staat 9 − 2 = 7 V. R = 7 / 0,010 = 700 Ω, dus 680 Ω of 750 Ω. Vermogen: P = 7 × 0,010 = 70 mW, ruim binnen de 250 mW van een ¼-W weerstand.

## 12. Zelftest

Beantwoord deze vragen zonder terug te bladeren. Heb je er minder dan 4 van de 5 goed, lees dan paragraaf 2 en 7 nog eens.

1. Wat is de wet van Ohm?
2. Wat gebeurt er met de stroom als je bij gelijke spanning de weerstand verdubbelt?
3. Waarom heeft een LED een weerstand nodig?
4. Hoe zie je welke kant van een LED de plus is?
5. Wat is een zwevende ingang?

Antwoorden: (1) V = I × R. (2) De stroom halveert. (3) Een LED begrenst zijn stroom niet zelf en gaat zonder weerstand stuk. (4) De langste poot is de plus, de anode. (5) Een ingang die nergens mee verbonden is en daardoor ruis opvangt.

## 13. Verder lezen

- *Make: Electronics* van Charles Platt, hoofdstuk 1 tot 3. Toegankelijk en vol proefjes.
- De uitleg over de wet van Ohm bij Khan Academy (zoek op "Ohm's law").
- Zoek het datablad van de 74HC04 op en kijk waar "VIH" en "VIL" staan. Volgende week komen we erop terug.

Volgende week bouwen we de logische poort, en daarvoor kijken we eerst naar de transistor.
