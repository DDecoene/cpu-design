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

```{.python include="memhier/w8iss.py"}
```

Daarna de voorspellers en een functie die de nauwkeurigheid over een spoor meet:

```{.python include="memhier/predict.py"}
```

De test controleert eerst dat de ISS dezelfde uitkomsten geeft als de Verilog-CPU, en daarna het gedrag van de voorspellers op een synthetisch lusspoor:

```{.python include="memhier/test_predict.py"}
```

De bestanden `asm.py` en de zes `.asm`-programma's staan al in `labs/cpu/`. Kopieer ze naar `labs/memhier/`.


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

```{.verilog include="memhier/cache.v"}
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

```{.verilog include="memhier/tb_cache.v"}
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
