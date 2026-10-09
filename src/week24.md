---
title: "Week 24 · Synthese, timing en optimalisatie"
---

<p class="subtitle">Fase 6 · Van code naar chip · ongeveer 14 uur</p>

# Week 24: Synthese, timing en optimalisatie

## Wat je na deze week kunt

- een synthese- en place-and-route-rapport lezen: gebruik, maximale frequentie en kritiek pad
- uitleggen wat setup, hold, slack en timing closure zijn
- uit een rapport afleiden waar een ontwerp groot of langzaam is
- een ontwerp aanpassen voor een FPGA (blok-RAM, synchrone uitlezing) en het effect meten
- met een gate-level simulatie bewijzen dat de synthese het gedrag niet veranderd heeft
- een ontwerp vergelijken op tijd (cycli gedeeld door frequentie) en niet alleen op cycli

## 1. Wat vertelt de tool?

Aan het eind van week 23 had onze CPU de volgende kenmerken (gemeten met Yosys en nextpnr op een iCE40 HX8K):

| Gegeven | W8I |
|---------|-----|
| LUT4 | 3 202 |
| Flipflops | 2 148 |
| Gebruikte logische elementen | 5 297 van 7 680 (69 %) |
| Maximale frequentie | 34,3 MHz |

Dat is veel voor een eenvoudige 8-bit CPU. Een goede ingenieur vraagt zich nu af waar die ruimte naartoe gaat. Het antwoord staat in de details van het rapport.

### Uitvoer van de synthese

Aan het eind geeft Yosys een telling van de gebruikte cellen:

```text
      116   SB_CARRY          ← carry-ketens (de opteller)
     1920   SB_DFFE           ← 1920 flipflops met enable
      188   SB_DFFER
     3202   SB_LUT4
```

Het getal 1920 springt eruit. Reken maar: 240 bytes RAM × 8 bit = 1920. Het datageheugen is helemaal uit losse flipflops gebouwd. En naast die 1920 flipflops komt er voor het lezen ook nog een 240-op-1 multiplexer per bit bij, ongeveer 2 500 LUT's.

### Waarom?

In `dmem` lees je het geheugen asynchroon: `assign dout = mem[addr];`. De data verschijnt zodra het adres verandert. Het blok-RAM van een FPGA werkt anders: dat is synchroon. Het adres wordt bij een klokflank vastgelegd en de data staat een klokperiode later klaar. Een asynchroon geheugen past dus niet op blok-RAM, en de tool maakt het van gewone flipflops en multiplexers.

Voor FPGA's geldt: wil je blok-RAM, schrijf dan een geheugen met een synchrone uitlezing (`dout <= mem[addr]` binnen `always @(posedge clk)`).

## 2. Timing: waarom de klok niet sneller kan

Alle digitale schakelingen die we gebouwd hebben, volgen één regel (week 5):

```text
 T_klok  ≥  t_clk→Q  +  t_logica  +  t_routering  +  t_setup
```

Die regel moet gelden voor elke weg tussen twee flipflops. De langzaamste weg is het kritieke pad en bepaalt de maximale klokfrequentie. De tool schrijft het uit.

### Begrippen

| Begrip | Betekenis |
|--------|-----------|
| Setup time | hoe lang een signaal voor de klokflank stabiel moet zijn |
| Hold time | hoe lang het na de klokflank stabiel moet blijven |
| Slack | marge: de klokperiode min de padvertraging. Positief is goed, negatief betekent dat het pad te langzaam is |
| Timing closure | alle paden hebben slack ≥ 0 |
| Constraint | de eis die jij aan de tool geeft, bijvoorbeeld "27 MHz" (`--freq 27`) |

nextpnr krijgt de gewenste frequentie als doel en meldt `PASS` of `FAIL`:

```text
Max frequency for clock 'clk': 34.29 MHz (PASS at 27.00 MHz)
```

### Het kritieke pad lezen

Het rapport bevat het pad stap voor stap. De analyse van W8I:

| Onderdeel van het pad | Tijd |
|-----------------------|-----:|
| clock-to-Q van de eerste flipflop | 0,54 ns |
| logica: 18 LUT's achter elkaar | 6,12 ns |
| routering tussen die LUT's | 22,02 ns |
| setup en overig | ca. 0,5 ns |
| totaal | ca. 29,2 ns → 34,3 MHz |

Hieruit volgen twee lessen.

1. Op een FPGA is routering de grote speler: ruim driekwart van de tijd. De draden en schakelaars tussen de LUT's zijn veel langzamer dan de LUT's zelf. Een ontwerp met minder LUT's op het pad (en minder fanout) is dus sneller, en een kleiner ontwerp is ook korter bedraad.
2. Het pad is 18 LUT's diep. De weg loopt van de toestand van de besturing via het registerbestand (de multiplexer die `regb` kiest) en de ALU naar de vlaggen. Het is hetzelfde kritieke pad dat we in week 14 op papier vonden: registers lezen, ALU, terugschrijven. Pipelining (week 20) knipt het in stukken.

## 3. De oplossing: W8F

We willen het datageheugen in blok-RAM, met synchrone uitlezing. De apparaatregisters (UART, timer en GPIO) laten we op dezelfde manier uitlezen, zodat de CPU één regel heeft: de data is een klokperiode na het adres beschikbaar. En een `LD` moet daar rekening mee houden: drie stappen in plaats van twee.

De CPU heet W8F (F voor FPGA). Alles blijft hetzelfde, behalve drie bestanden. Kopieer eerst de rest (let op: het gaat om bestanden uit week 14 tot en met 23).


### Het datageheugen met synchrone uitlezing

```{.verilog include="cpu_fpga/memories_f.v"}
```

Dit is het hele geheim: de uitlezing zit binnen het klokgestuurde blok. Yosys herkent het patroon en gebruikt een `SB_RAM40_4K`, een ingebouwd geheugenblok.

### De besturing: LD in drie stappen

Voor de rest is dit `control_i.v` van week 22. Het verschil is dat de toestand `t` (1 bit) `st` (2 bits) wordt, en dat `LD` drie stappen krijgt:

| Stap | Wat gebeurt er |
|------|----------------|
| 0 | ophalen |
| 1 | het adres wordt aan het geheugen aangeboden en aan het eind van deze stap legt het geheugen de data vast |
| 2 | het gelezen woord gaat naar het register |

```{.verilog include="cpu_fpga/control_f.v"}
```

### De apparaten: ook een klokperiode vertraging

Het RAM geeft zijn data een periode later, dus moeten de apparaatregisters dat ook doen. Anders weet de CPU niet wanneer een lezing geldig is. De multiplexer die kiest tussen RAM en apparaat gebruikt het adres uit de vorige periode.

```{.verilog include="cpu_fpga/mmio_f.v"}
```

### De CPU en het toplevel

```{.verilog include="cpu_fpga/cpu_f.v"}
```

```{.verilog include="cpu_fpga/fpga_top_f.v"}
```

## 4. Verificatie van W8F

### Dezelfde programma's, naast elkaar

W8I (asynchroon RAM) en W8F draaien dezelfde zes programma's tegelijk. Registers, vlaggen en het hele RAM moeten identiek zijn, en W8F mag precies één cyclus per uitgevoerde `LD` langer doen. Die laatste eis is scherp: klopt het aantal cycli niet exact, dan gebeurt er iets wat je niet begrijpt.

```{.verilog include="cpu_fpga/tb_f_compare.v"}
```

De meting:

| Programma | W8I (cycli) | W8F (cycli) | Aantal LD's |
|-----------|------------:|------------:|------------:|
| som | 66 | 66 | 0 |
| mul | 190 | 190 | 0 |
| sorteren | 564 | 620 | 56 |
| priem | 3 596 | 3 694 | 98 |
| ggd | 60 | 60 | 0 |
| subroutine | 114 | 114 | 0 |

### De interrupt- en apparatentests

De tests uit week 22 en 23 draaien ook op W8F. Het enige verschil is de naam van de CPU. Maak er kopieën van met zoeken-en-vervangen (bijvoorbeeld met `sed`):


```text
sed 's/module tb_irq;/module tb_irq_f;/; s/cpu_i #(/cpu_f #(/' tb_irq.v > tb_irq_f.v
sed 's/module tb_blink;/module tb_blink_f;/; s/cpu_i #(/cpu_f #(/' tb_blink.v > tb_blink_f.v
sed 's/module tb_fpga_top;/module tb_fpga_top_f;/; s/fpga_top #(CLK_HZ, BAUD) dut(/fpga_top_f #(CLK_HZ, BAUD) dut(/' tb_fpga_top.v > tb_fpga_top_f.v
```

Dat het hergebruik zo goed werkt, is een teken van een goed ontworpen testbench: de test hangt af van het gedrag van de CPU en niet van zijn interne cyclustelling. Alle drie slagen.

## 5. De resultaten

Gemeten met Yosys 0.69 en nextpnr (via YoWASP), `seed 1`, met 27 MHz als doel:

| | W8I | W8F |
|--|----:|----:|
| LUT4 | 3 202 | 700 |
| Flipflops | 2 148 | 265 |
| Blok-RAM | 0 | 1 |
| Logische elementen op HX8K | 5 297 (69 %) | 898 (12 %) |
| Maximale frequentie HX8K | 34,3 MHz | 48,0 MHz |
| Kritiek pad: logica / routering | 6,1 / 22,0 ns | 5,5 / 14,7 ns |
| Past op UP5K (5 280 LC's) | nee | ja, maximaal 18,4 MHz |

W8F is 6 keer kleiner en de klokfrequentie is 40 % hoger. Ook de routering nam sterk af: minder LUT's betekent korter bedraad.

Veel UP5K-borden (bijvoorbeeld de iCEBreaker en de UPduino) draaien op 12 MHz. Daar haalt W8F ruim de maximale 18,4 MHz. Op 27 MHz zou hij het niet halen.

### Winst in tijd, niet in cycli

Alleen cycli vergelijken is misleidend. De uitvoeringstijd is:

```text
 tijd = cycli / frequentie
```

| Programma | W8I: tijd bij 34,3 MHz | W8F: tijd bij 48,0 MHz | Versnelling |
|-----------|-----------------------:|-----------------------:|:-----------:|
| sorteren | 564 / 34,3 = 16,4 µs | 620 / 48,0 = 12,9 µs | 1,27 × |
| priem | 3 596 / 34,3 = 104,8 µs | 3 694 / 48,0 = 77,0 µs | 1,36 × |
| som | 66 / 34,3 = 1,92 µs | 66 / 48,0 = 1,38 µs | 1,40 × |

Er zijn meer cycli (de extra stap voor `LD`) en toch is het sneller, omdat de klok zoveel sneller kan. Dat is de les van elke architectuurvergelijking.

## 6. Bewijzen dat de synthese klopt: gate-level simulatie

In week 23 ging het mis: de simulatie slaagde, maar de hardware was leeg. Een gate-level simulatie voorkomt zulke verrassingen. Je simuleert dan niet je Verilog, maar de netlijst die Yosys maakte, opgebouwd uit de echte celtypen van de FPGA (LUT's, flipflops, carry-ketens en blok-RAM). Slaagt je testbench daar ook op, dan weet je dat de synthese het gedrag intact liet.

Voor een snelle simulatie gebruiken we dezelfde kleine klok als in de testbench van week 23:

```{.verilog include="cpu_fpga/fpga_top_small.v"}
```


De testbench voor de netlijst is `tb_fpga_top_f.v` met twee vervangingen: `module tb_gate;` en `fpga_top_small dut(`.

```{.bash include="cpu_fpga/gatesim.sh"}
```

```text
bash gatesim.sh
```

De uitvoer:

```text
bericht: 7 tekens, LED wisselde 7 keer
PASS (gate-level): de gesynthetiseerde netlijst zegt 'W8 OK' via de UART en laat de LED knipperen
```

Dit draait op de netlijst van ongeveer 800 kB Verilog met `SB_LUT4`, `SB_DFF*`, `SB_CARRY` en een `SB_RAM40_4K`. Het is de strengste verificatie die je zonder echt bord kunt doen.

## 7. Hoe optimaliseer je verder?

| Techniek | Idee | Effect |
|----------|------|--------|
| Blok-RAM gebruiken | synchrone uitlezing (zoals hierboven) | veel minder LUT's en flipflops |
| Pipelinen | het kritieke pad met registers in stukken knippen (week 20) | hogere klok, maar meer flipflops en hazards |
| Retiming | de tool schuift registers door de logica | hogere klok zonder je code te veranderen (mits ondersteund) |
| Fanout verminderen | een signaal met honderden bestemmingen vertraagt, dus dupliceer het register | minder routering |
| One-hot toestandscodering | meer flipflops, maar veel eenvoudiger logica | snellere FSM's |
| Resource sharing | één opteller voor meerdere taken gebruiken (zoals de ALU voor adressen) | kleiner |
| Clock enable in plaats van gated clock | `if (en)` in plaats van de klok te poorten | veilig en door de FPGA ondersteund |
| Een andere seed of strengere constraint | nextpnr heeft willekeur, en een hogere doelfrequentie geeft hardere optimalisatie | soms +10 % |

### De afweging

```text
 oppervlakte (LUT's)  ◄──►  snelheid (MHz)  ◄──►  energie
```

Je kunt zelden alles tegelijk verbeteren. Snel betekent vaak groter (duplicaten, pipelineregisters) en klein betekent vaak langzamer (hergebruik). Op een chip kost oppervlakte geld, op een FPGA kost het vooral ruimte.

### Een woord over energie

Het vermogen van CMOS (week 2) is ruwweg:

```text
 P_dynamisch  ≈  α · C · V² · f
```

Hierin is α de fractie poorten die per klokperiode schakelt, C de capaciteit die wordt omgeladen, V de voedingsspanning en f de frequentie. Halve spanning geeft vier keer minder vermogen en halve frequentie de helft. Daarom draaien telefoonchips op lage spanningen en schakelen ze delen uit die niet nodig zijn. Een FPGA gebruikt ook veel energie in het statische deel (lekstroom) en in de routering.

## 8. Lab

1. Draai `bash fpga_flow.sh hx8k` (W8I) en daarna `bash fpga_flow.sh hx8k fpga_top_f` (W8F). Vul de tabel uit paragraaf 5 met je eigen cijfers (die kunnen licht afwijken door de versie van de tools).
2. Draai `bash gatesim.sh` en bevestig PASS. Maak daarna iets stuk in `control_f.v` (haal bijvoorbeeld de derde stap van `LD` weg) en kijk of zowel de RTL-test als de gate-level test falen.
3. Zoek in `pnr.log` het kritieke pad van W8F en vergelijk het met dat van W8I. Door welke onderdelen loopt het?
4. Verander de `--seed` in `fpga_flow.sh` (1, 2, 3, 4, 5) en noteer per seed de maximale frequentie. Hoeveel verschilt het?
5. Draai het script voor `up5k` met `FREQ=12` en met `FREQ=27`. Wat zegt het rapport?

## 9. Oefeningen

1. Het datageheugen van W8I heeft 240 bytes. Hoeveel flipflops kost dat? Waarom kost het daarnaast nog honderden LUT's per bit?
2. Een programma voert 10 000 instructies uit, waarvan 20 % `LD`, op W8I (34 MHz, 2 cycli per instructie) en op W8F (48 MHz, 3 cycli voor `LD`). Bereken de tijd op beide en de versnelling.
3. Een kritiek pad bestaat uit 0,5 ns clock-to-Q, 12 LUT's van 0,4 ns en 12 routeringen van 1,2 ns. Wat is de maximale frequentie? Wat levert het halveren van het aantal LUT's (en routeringen) op het pad op?
4. Leg uit waarom een asynchroon geheugen niet op blok-RAM past.
5. Wat is het verschil tussen een RTL-simulatie en een gate-level simulatie, en wat bewijst de tweede extra?
6. Je ontwerp haalt 27 MHz niet en het kritieke pad loopt door de ALU. Noem drie dingen die je kunt proberen.
7. Waarom kost het programmageheugen (de instructie-ROM) iets aan LUT's? (Gemeten: een programma van 37 instructies kost 700 LUT's, een van 20 instructies 660.) Schat de kosten per instructie.
8. Uitdaging: maak ook het instructiegeheugen synchroon (blok-RAM). Wat moet je veranderen aan het ophalen van instructies? Hoeveel cycli kost een instructie dan? Hint: het adres moet een periode eerder bekend zijn.

## 10. Antwoorden

1. 240 × 8 = 1 920 flipflops. Daarnaast heeft elke uitgangsbit een multiplexer van 240 naar 1. Een 2-naar-1-multiplexer past in één LUT, dus zo'n keuzeboom kost grofweg een LUT per ingang: ongeveer 240 per bit, samen ruim 1 900. Daarbij komt de decodering van het adres voor het schrijven. Samen geeft dat de gemeten ongeveer 2 500 LUT's bovenop de flipflops.
2. Instructies: 20 % LD = 2 000, de overige 8 000. W8I: 10 000 × 2 = 20 000 cycli / 34,3 MHz = 583 µs. W8F: 8 000 × 2 + 2 000 × 3 = 22 000 cycli / 48 MHz = 458 µs. De versnelling is 583 / 458 ≈ 1,27.
3. Het totaal is 0,5 + 12 × 0,4 + 12 × 1,2 = 0,5 + 4,8 + 14,4 = 19,7 ns, dus ongeveer 50,8 MHz. Met 6 LUT's en 6 routeringen: 0,5 + 2,4 + 7,2 = 10,1 ns, ongeveer 99 MHz, bijna het dubbele.
4. Het blok-RAM legt het adres vast bij een klokflank en levert de data via een register aan de uitgang. Asynchroon lezen verlangt dat de data zonder klok verschijnt. De hardware kan dat niet, dus bouwt de tool het uit flipflops en multiplexers.
5. RTL-simulatie voert jouw Verilog uit, gate-level simulatie voert de netlijst uit die de tool gegenereerd heeft. De tweede bewijst dat de synthese (met alle optimalisaties en interpretaties van `initial`-blokken, geheugens en klokken) het gedrag niet veranderd heeft.
6. Bijvoorbeeld: de ALU pipelinen (een register in het midden), minder fanout (registers dupliceren), een snellere opteller (carry-ketens gebruiken in plaats van losse logica), het pad verkorten door gedeeltelijke resultaten vooraf te berekenen, een hogere doelfrequentie opgeven of een andere seed proberen.
7. Een ROM in LUT's: elke plek bevat constanten die de synthese waar mogelijk wegwerkt, maar elke andere instructie voegt logica toe. Uit de twee metingen volgt (700 − 660) / (37 − 20) ≈ 2,4 LUT's per instructie. Bij een volle ROM van 256 niet-triviale instructies zou dat 600 tot 700 LUT's zijn. Een blok-RAM voor instructies zou dat overnemen.
8. Het instructiegeheugen zou bij het adres in T0 pas na een klokperiode data geven. Je hebt dan een extra ophaalstap nodig, of je legt de PC een cyclus vooruit (prefetch) zodat het adres er eerder is. Een instructie kost dan 3 cycli (ophalen in twee stappen en uitvoeren). Dit is precies de aanleiding voor pipelining.

## 11. Zelftest

1. Waar staan de 1920 flipflops voor in W8I?
2. Wat is slack?
3. Waarom domineert routering het kritieke pad op een FPGA?
4. Wat bewijst een gate-level simulatie?
5. Waarom is het vergelijken van cycli niet genoeg om twee CPU's te vergelijken?

Antwoorden: (1) Voor 240 bytes datageheugen (240 × 8) als losse flipflops. (2) Het verschil tussen de beschikbare tijd (de klokperiode) en de padvertraging. (3) De programmeerbare draden en schakelaars zijn veel langzamer dan de LUT's zelf. (4) Dat de gesynthetiseerde netlijst hetzelfde gedrag heeft als je ontwerp. (5) Tijd is cycli gedeeld door frequentie, en een CPU met meer cycli kan toch sneller zijn als zijn klok sneller is.

## 12. Verder lezen

- Het hoofdstuk over timinganalyse in elk boek over digitaal ontwerp, bijvoorbeeld Harris en Harris, 3.5 (timing van sequentiële logica).
- De documentatie van nextpnr over constraints en seeds, en de documentatie over blok-RAM van jouw FPGA-familie (de "Memory Usage Guide").
- Een inleiding over statische timinganalyse (STA) uit de ASIC-wereld. De concepten zijn hetzelfde, het gereedschap is duurder.

Volgende week: de FPGA is een tussenstap. Nu bouwen we de bijzondere machine uit week 19, de TTA, echt uit chips op een printplaat.
