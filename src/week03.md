---
title: "Week 3 · Booleaanse algebra en het vereenvoudigen van logica"
---

<p class="subtitle">Fase 1 · Elektronica en logica · ongeveer 10 uur</p>

# Week 3: Booleaanse algebra en het vereenvoudigen van logica

## Wat je na deze week kunt

- een logische functie uit een waarheidstabel halen en als formule opschrijven
- de wetten van de Booleaanse algebra toepassen, waaronder De Morgan
- een Karnaugh-kaart (K-map) tekenen en daarmee een schakeling vereenvoudigen
- don't cares gebruiken om een schakeling nog kleiner te krijgen
- in Verilog laten zien dat twee schakelingen exact hetzelfde doen

## 1. Waarom vereenvoudigen?

Elke poort kost ruimte, stroom en vertraging. Een schakeling die hetzelfde doet met minder poorten is kleiner, zuiniger en sneller. In een CPU komt dat duizenden keren voor, bij elke besturingsregel en elke truc in de ALU. Moderne ontwerptools doen het meeste werk zelf, maar wie het handwerk kent, schrijft betere code en ziet sneller wanneer de tool iets raars doet.

## 2. Booleaanse algebra

George Boole beschreef in 1854 logica als een soort algebra. Voor ons komt het hierop neer: variabelen zijn 0 of 1 en we hebben drie bewerkingen.

| Bewerking | Schrijfwijze hier | Verilog |
|-----------|-------------------|---------|
| NOT | A' | `~a` |
| AND (vermenigvuldigen) | A·B of AB | `a & b` |
| OR (optellen) | A + B | `a \| b` |

AND gedraagt zich als vermenigvuldigen (0·1 = 0), OR als optellen, met als verschil dat 1 + 1 = 1.

### De wetten

| Wet | AND-vorm | OR-vorm |
|-----|----------|---------|
| Identiteit | A·1 = A | A + 0 = A |
| Nul en één | A·0 = 0 | A + 1 = 1 |
| Idempotent | A·A = A | A + A = A |
| Complement | A·A' = 0 | A + A' = 1 |
| Dubbele negatie | (A')' = A | |
| Commutatief | AB = BA | A+B = B+A |
| Associatief | (AB)C = A(BC) | (A+B)+C = A+(B+C) |
| Distributief | A(B+C) = AB + AC | A + BC = (A+B)(A+C) |
| Absorptie | A(A+B) = A | A + AB = A |

De tweede distributieve wet (A + BC = (A+B)(A+C)) bestaat in gewone algebra niet. In Booleaanse algebra wel, en je zult hem vaak nodig hebben.

### De Morgan

Voor hardware is dit de nuttigste wet:

```text
(A·B)'  =  A' + B'          NAND  =  OR van de inversen
(A+B)'  =  A' · B'          NOR   =  AND van de inversen
```

Een inversie over een AND wordt een OR van inversen, en andersom. Zo maakte je vorige week een OR uit NAND-poorten: A + B = (A'·B')'.

### Een voorbeeld

Vereenvoudig Y = A·B + A·B'.

```text
Y = A·B + A·B'
  = A·(B + B')       distributief
  = A·1              complement
  = A                identiteit
```

De hele schakeling blijkt niet van B af te hangen.

## 3. Van waarheidstabel naar formule

Stel dat je met een tabel opschrijft wat een schakeling moet doen:

| A | B | C | Y |
|---|---|---|---|
| 0 | 0 | 0 | 0 |
| 0 | 0 | 1 | 1 |
| 0 | 1 | 0 | 0 |
| 0 | 1 | 1 | 1 |
| 1 | 0 | 0 | 0 |
| 1 | 0 | 1 | 1 |
| 1 | 1 | 0 | 1 |
| 1 | 1 | 1 | 0 |

De methode heet som van producten (SOP). Voor elke rij met Y = 1 schrijf je een term op die alleen op die rij 1 is: de variabele zelf als hij 1 is, de inverse als hij 0 is. Daarna tel je de termen op.

```text
Y = A'B'C + A'BC + AB'C + ABC'
```

Zo'n term heet een minterm. Korter schrijf je dit als Y = Σm(1, 3, 5, 6), waarbij het getal het rijnummer is (ABC gelezen als binair getal).

Het werkt voor elke tabel, maar de schakeling wordt vaak groter dan nodig. Daarvoor is de K-map.

## 4. De Karnaugh-kaart

Een K-map is een waarheidstabel in een raster, zo geordend dat buurcellen precies in één variabele verschillen. Daardoor kun je termen met het oog samenvoegen.

### Twee variabelen

```text
        B=0  B=1
  A=0 │  m0   m1
  A=1 │  m2   m3
```

### Drie variabelen

De kolommen volgen de Gray-code: 00, 01, 11, 10, dus niet 00, 01, 10, 11. Zo verschilt elke buur in één bit.

```text
         BC=00  01   11   10
  A=0  │  m0   m1   m3   m2
  A=1  │  m4   m5   m7   m6
```

### Vier variabelen

```text
          CD=00  01   11   10
  AB=00 │  m0    m1   m3   m2
  AB=01 │  m4    m5   m7   m6
  AB=11 │  m12   m13  m15  m14
  AB=10 │  m8    m9   m11  m10
```

De rand is cyclisch: links grenst aan rechts en boven aan onder. De vier hoeken zijn dus buren van elkaar.

### Zo gebruik je een K-map

1. Zet een 1 in elke cel waar de functie 1 is.
2. Omcirkel groepen van 1'en. Een groep is een rechthoek van 1, 2, 4, 8 of 16 cellen (machten van twee) zonder 0 erin.
3. Maak de groepen zo groot mogelijk en gebruik er zo weinig mogelijk. Elke 1 hoort in minstens één groep, overlap mag.
4. Elke groep is één term. Variabelen die binnen de groep van waarde wisselen, vallen weg. Variabelen die constant blijven, houd je: gewoon als ze 1 zijn, met accent als ze 0 zijn.
5. Tel de termen op.

### Voorbeeld met drie variabelen

De tabel uit paragraaf 3 had Y = Σm(1, 3, 5, 6):

```text
         BC=00  01   11   10
  A=0  │  0     1    1    0
  A=1  │  0     1    0    1
```

De 1'en in kolom BC=01 (m1 en m5) vormen een groep van 2. A wisselt, B=0 en C=1 blijven, dus B'C. Dan m3 (A'BC): die kan met m1 (A'B'C), want alleen B wisselt. Dat geeft A'C. Tot slot staat m6 (ABC') alleen, dus ABC'.

Samen: Y = B'C + A'C + ABC'. Dat m1 in twee groepen zit, is toegestaan.

### Voorbeeld met vier variabelen

Neem f = Σm(0, 1, 2, 5, 8, 9, 10):

```text
          CD=00  01   11   10
  AB=00 │  1     1    0    1
  AB=01 │  0     1    0    0
  AB=11 │  0     0    0    0
  AB=10 │  1     1    0    1
```

De vier hoeken (m0, m2, m8, m10) hebben B=0 en D=0, dus B'D'. De vier cellen m0, m1, m8, m9 hebben B=0 en C=0, dus B'C'. Cel m5 heeft alleen m1 als buur: die groep van 2 heeft A=0, C=0 en D=1, dus A'C'D.

Het resultaat is f = B'D' + B'C' + A'C'D. Zeven termen van vier variabelen zijn teruggebracht tot drie kleine.

## 5. Don't cares

Soms maakt het niet uit wat de uitvoer is voor een bepaalde invoer, bijvoorbeeld omdat die invoer nooit voorkomt. In de K-map zet je dan een X. Je mag een X als 1 rekenen als dat een grotere groep geeft, en negeren als dat niets oplevert.

Een voorbeeld: een BCD-cijfer (0 tot 9, vier bits ABCD). We willen weten of het cijfer minstens 5 is. De waarden 10 tot 15 komen niet voor, dus die zijn don't cares.

```text
          CD=00  01   11   10
  AB=00 │  0     0    0    0
  AB=01 │  0     1    1    1
  AB=11 │  X     X    X    X
  AB=10 │  1     1    X    X
```

De onderste twee rijen (m8, m9, m10, m11 en m12 tot en met m15) vormen samen een groep van 8 met A=1, dus A. Dan m5 en m7 met m13 en m15: B=1 en D=1, dus BD. En m6 en m7 met m14 en m15: B=1 en C=1, dus BC.

Het resultaat is f = A + BD + BC. Zonder don't cares had je veel meer termen nodig.

## 6. Lab: laat de computer je handwerk controleren

Een goede ontwerper vertrouwt zijn eigen rekenwerk niet blind. We schrijven de functie uit het voorbeeld twee keer: één keer als som van alle minterms en één keer vereenvoudigd. De testbench vergelijkt ze voor alle 16 invoeren.

```{.verilog include="week03/fn_sop.v"}
```

```{.verilog include="week03/tb_fn.v"}
```

Dit heet exhaustieve verificatie. Bij 4 ingangen controleer je 16 gevallen, bij 16 ingangen 65 536 (nog steeds snel) en bij 64 ingangen gaat het niet meer. Dan heb je slimmere methoden nodig, maar het idee blijft hetzelfde.

### De BCD-schakeling met don't cares, en De Morgan

```{.verilog include="week03/bcd_ge5.v"}
```

```{.verilog include="week03/tb_bcd.v"}
```

Draai de labs:

```text
cd labs/week03
iverilog -g2012 -o a.vvp tb_fn.v fn_sop.v && vvp a.vvp
iverilog -g2012 -o b.vvp tb_bcd.v bcd_ge5.v && vvp b.vvp
```

Experiment: verander in `fn_min` één term (bijvoorbeeld `~a & ~c & d` in `~a & c & d`) en kijk of de testbench de fout vindt. Zo spoor je later ook fouten in een CPU op.

## 7. Oefeningen

1. Vereenvoudig met algebra: Y = A + A'B.
2. Vereenvoudig met algebra: Y = AB + A'C + BC. Dit is de consensusstelling en hij is lastig.
3. Pas De Morgan toe op (A + B·C')' en schrijf het resultaat zonder haakjes.
4. Schrijf de XOR als som van producten.
5. Een functie van 3 variabelen heeft Y = Σm(0, 1, 2, 3, 6, 7). Vereenvoudig met een K-map.
6. Een functie van 4 variabelen heeft Y = Σm(1, 3, 5, 7, 9, 11, 13, 15). Wat komt eruit?
7. Een functie van 4 variabelen heeft Y = Σm(0, 2, 8, 10). Wat komt eruit en wat is er bijzonder aan?
8. Uitdaging: ontwerp een schakeling die 1 geeft als een 4-bit getal een priemgetal is (2, 3, 5, 7, 11, 13) en 0 voor 0, 1, 4, 6, 8, 9, 10, 12, 14 en 15. Vereenvoudig met een K-map en test je antwoord in Verilog.

## 8. Antwoorden

1. Y = A + A'B = (A + A')(A + B) = 1·(A + B) = A + B.
2. BC is overbodig: AB + A'C + BC = AB + A'C + BC(A + A') = AB + A'C + ABC + A'BC = AB(1 + C) + A'C(1 + B) = AB + A'C.
3. (A + B·C')' = A' · (B·C')' = A' · (B' + C) = A'B' + A'C.
4. A⊕B = A'B + AB'.
5. De hele rij A=0 is gevuld (m0 tot en met m3), dus A'. De 1'en m2, m3, m6 en m7 hebben B=1, dus B. Y = A' + B.
6. Dit zijn alle oneven getallen: D=1 en de rest vrij. Y = D.
7. De vier hoeken: B=0 en D=0, dus Y = B'D'. Bijzonder is dat de groep over de rand van de kaart loopt.
8. De 1'en zijn m2, m3, m5, m7, m11 en m13. Een minimale oplossing is Y = A'B'C + A'BD + B'CD + BC'D. Controleer in de testbench of jouw versie voor 0 tot 15 klopt.

## 9. Zelftest

1. Wat zegt De Morgan over (A·B)'?
2. Waarom volgen de kolommen van een K-map de volgorde 00, 01, 11, 10?
3. Welke groepsgroottes mogen in een K-map?
4. Wat is een don't care en wanneer gebruik je hem?
5. Hoe lees je de term bij een groep af?

Antwoorden: (1) Het is gelijk aan A' + B'. (2) Zodat buurcellen in precies één bit verschillen (Gray-code). (3) 1, 2, 4, 8 en 16, dus machten van twee. (4) Een invoercombinatie waarvan de uitvoer niet uitmaakt. Je rekent hem als 1 of 0, wat het gunstigst uitkomt. (5) Houd de variabelen die in de groep constant zijn en laat de variabelen weg die wisselen.

## 10. Verder lezen

- Ben Eaters video's over de besturingslogica van zijn 8-bit computer laten zien hoe zulke redeneringen in de praktijk gebruikt worden.
- *Digital Design and Computer Architecture* van Harris en Harris, hoofdstuk 2. Dit boek blijft de hele cursus nuttig.
- Zoek een online K-map solver op om je antwoorden mee te controleren.

Volgende week gebruiken we dit gereedschap voor de eerste echte bouwblokken van een computer: de multiplexer, de decoder en de opteller.
