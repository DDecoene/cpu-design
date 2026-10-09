---
title: "Week 27 · VGA: een beeld uit niets"
---

<p class="subtitle">Fase 7 · De beeldcomputer · ongeveer 12 uur</p>

# Week 27: VGA, een beeld uit niets

## Wat je na deze week kunt

- uitleggen hoe een VGA-monitor een beeld opbouwt uit twee syncsignalen en drie kleurkanalen
- een timingtabel (zichtbaar, front porch, sync, back porch) omzetten in twee tellers
- een VGA-generator in Verilog schrijven en testen, zonder monitor, met een virtuele monitor
- de weerstanden voor een kleine DAC berekenen die de digitale kleur analoog maakt
- uitleggen waarom we een bord met een iCE40 UP5K kiezen voor deze fase

## 1. Waar fase 7 naartoe gaat

De eerste 26 weken gingen over CPU's. Fase 7 is een project: een kleine computer die bij het inschakelen een bestand van een SD-kaart leest en het als beeld op een VGA-monitor zet. Hij doet niets anders. Dat lijkt weinig, maar je hebt er een heleboel voor nodig, en elk onderdeel is op zichzelf een goede les.

```text
  SD-kaart ──SPI──►  W8F-CPU  ──schrijft──►  framebuffer  ──leest──►  VGA-generator ──► monitor
   (week 30)        (week 29: SPI)           (week 28)               (week 27)
```

We bouwen van rechts naar links. Deze week maken we het beeld zelf, zonder CPU. Week 28 geeft de CPU toegang tot het beeldgeheugen, week 29 voegt een SPI-poort toe en week 30 leert de computer de kaart te lezen.

### Wat dit wel en niet is

De CPU blijft de W8F uit week 22 en 24: een gewone 8-bit CPU met dezelfde instructieset en dezelfde assembler. Er is niets in de instructieset dat op beelden of 3D is afgestemd. Het speciale zit in de randapparatuur: een VGA-generator, een framebuffer en een SPI-poort. De CPU is de regisseur die bytes van de kaart naar het beeldgeheugen verplaatst. Een CPU waarvan de instructieset op 3D is toegesneden (vermenigvuldigen-en-optellen, vectoren) of een versneller die driehoeken tekent is een ander project. Daar komen we in week 30 op terug als vervolg.

### Wat er gesimuleerd is en wat niet

Zoals in de rest van de cursus is alles hier gesimuleerd met Icarus Verilog en gesynthetiseerd met Yosys en nextpnr. Er is geen bord aangesloten, geen monitor aangezet en geen kaart in een slot gestoken. De pinnummers, de analoge schakeling en de gedragingen van echte SD-kaarten moet je dus zelf controleren. Het ontwerp is wel zo gemaakt dat een eerste poging op echte hardware redelijk kans van slagen heeft: elke fout die we in simulatie kunnen vinden, is al gevonden.

## 2. Welk bord, en waarom

Voor fase 7 gebruik je een iCE40 UP5K op een bord met een klok van 12 MHz, zoals de iCEBreaker, met een VGA-module en een microSD-module op de Pmod-aansluitingen. Dit zijn de redenen.

| Eis | Wat de cursus erover weet | Daarom |
|-----|---------------------------|--------|
| De open-sourcestroom werkt | Yosys, nextpnr en icepack ondersteunen de iCE40 het best, en week 23 en 24 gebruikten al deze chip | iCE40 |
| De CPU past en haalt de klok | W8F kost 700 LUT's en haalt op de UP5K maximaal 18,4 MHz (week 24) | de CPU draait op de 12 MHz van het bord, zonder PLL |
| Het framebuffer past | 160 x 120 pixels van 4 bit is 9 600 bytes. De UP5K heeft 30 blok-RAM's van 4 kbit (120 kbit) | gemeten: het hele ontwerp gebruikt 20 van de 30 |
| Er is een tweede klok voor het beeld | VGA 640 x 480 vraagt ongeveer 25 MHz | de ingebouwde PLL maakt 25,125 MHz uit de 12 MHz |
| Geen draadjes bij 25 MHz | een los gebouwde VGA- en SD-schakeling op een breadboard is onbetrouwbaar | VGA- en microSD-modules die op de Pmod-poorten passen |
| Het blijft betaalbaar | het bord plus twee modules is ongeveer 100 euro (controleer actuele prijzen) | past in het budget van de cursus |

Waarom niet iets anders?

- **Tang Nano 9K** (Gowin): in de syllabus genoemd voor week 23. Een mooi bord met HDMI, maar zonder VGA-uitgang, en de open-sourcestroom voor Gowin is jonger. Je kunt het gebruiken, maar de PLL-code en de pinnen zijn anders, en je moet zelf een VGA-schakeling aanbrengen of HDMI doen.
- **ULX3S** (ECP5): heeft een microSD-slot en video aan boord en is veel krachtiger dan we nodig hebben. Het is ook duurder en de uitgang is HDMI, geen VGA.
- **iCE40 HX8K breakout**: groter, maar een kaal bord waarop je alles zelf moet aansluiten, en niet nodig: het ontwerp past ruim in de UP5K.

De twee getallen die de keuze bepalen zijn ook de twee die je zelf kunt controleren: 20 van de 30 RAM-blokken, en 17 tot 18,5 MHz voor de CPU-klok tegen de 12 MHz die we nodig hebben (week 30 toont de metingen). Ik heb geen van deze borden zelf gebruikt. De keuze berust op de gegevens uit de datasheets en op de metingen uit deze cursus. Controleer vóór je bestelt of het bord een 12 MHz-klok heeft en welke Pmod-poorten vrij zijn.

## 3. Hoe een monitor een beeld maakt

Een VGA-monitor heeft geen geheugen. Hij schildert het beeld op het moment dat de signalen binnenkomen. Dat komt uit de tijd van de beeldbuis, waarin een elektronenstraal lijn voor lijn over het scherm ging. Moderne schermen doen nog steeds alsof: ze verwachten de pixels in dezelfde volgorde en met dezelfde pauzes.

```text
  De straal begint linksboven en gaat naar rechts.
  Aan het eind van een lijn springt hij terug (horizontale terugslag) en begint de volgende lijn.
  Na de laatste lijn springt hij terug naar boven (verticale terugslag).

   ┌──────────────────────────────┐ ◄── zichtbaar gebied: 640 x 480
   │ ───────────────────────────► │
   │ ───────────────────────────► │      de straal beweegt in een zigzag:
   │ ───────────────────────────► │      lijn voor lijn, pixel voor pixel
   │              ...             │
   └──────────────────────────────┘
```

De monitor kent drie kleursignalen en twee syncsignalen:

| Signaal | Wat het doet | Niveau |
|---------|--------------|--------|
| R, G, B | de helderheid van rood, groen en blauw op dit moment | analoog, 0 V (zwart) tot 0,7 V (vol) |
| HSYNC | een korte puls: begin een nieuwe lijn | digitaal (3,3 V is voor de meeste monitoren goed) |
| VSYNC | een lange puls: begin een nieuw beeld | digitaal |

Op de 15-polige VGA-connector zitten rood op pin 1, groen op pin 2, blauw op pin 3, HSYNC op pin 13 en VSYNC op pin 14. De pinnen 5 tot en met 8 en pin 10 zijn aarde.

De syncpulsen komen niet direct na de laatste pixel. Er zit een pauze vóór (de front porch) en na (de back porch), want de straal had tijd nodig om terug te springen. Een moderne monitor heeft die tijd niet meer nodig, maar hij verwacht ze nog steeds, en hij gebruikt de back porch om zwart te kalibreren. Daarom is het kleursignaal in alle blanking zwart.

```text
 Een lijn, 800 pixelklokken:

 kleur  ──┤ 640 pixels zichtbaar ├──── zwart (front porch 16, sync 96, back porch 48) ────
 HSYNC  ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_______ 96 _______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
        0                            640    656           752     800

 Een beeld, 525 lijnen: 480 zichtbaar, 10 front porch, 2 lijnen VSYNC, 33 back porch.
```

## 4. De timing van 640 x 480 bij 60 Hz

Dit is de standaardtabel voor de meest gebruikte VGA-modus. Elke monitor ondersteunt hem.

| | Zichtbaar | Front porch | Sync | Back porch | Totaal | Polariteit van de sync |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Horizontaal (pixelklokken) | 640 | 16 | 96 | 48 | 800 | negatief (puls is laag) |
| Verticaal (lijnen) | 480 | 10 | 2 | 33 | 525 | negatief |

De pixelklok is 25,175 MHz. Dan duurt een lijn 800 / 25,175 MHz = 31,78 µs (31,47 kHz) en een beeld 525 lijnen = 16,68 ms (59,94 Hz).

Onze 12 MHz-klok geeft via de PLL niet precies 25,175 MHz. Het hulpprogramma `icepll -i 12 -o 25.175` rekent uit dat 25,125 MHz het dichtst komt (VCO 804 MHz, gedeeld door 32). Dat is 0,2 % te laag en geeft 59,82 Hz. Vrijwel elke monitor accepteert dat zonder merkbaar verschil.

## 5. De tellers

Alles wat de generator moet doen is tellen. Een teller `hc` telt pixels van 0 tot 799, en elke keer als hij rondgaat telt een tweede teller `vc` een lijn verder, van 0 tot 524. Alle signalen zijn vergelijkingen op die twee getallen:

- `hsync` is laag als `hc` in 656 tot en met 751 ligt (640 + 16 en 640 + 16 + 96)
- `vsync` is laag als `vc` in 490 en 491 ligt
- `active` is 1 als `hc < 640` en `vc < 480`

De module krijgt de tabel als parameters, zodat je er later een andere modus mee kunt maken (oefening 4).

```{.verilog include="beeld/vga_sync.v"}
```

Twee dingen om op te letten. De tellers hebben 11 bit, omdat grotere modi dan 640 x 480 (zoals 800 x 600) meer dan 1023 tellen. En `x` en `y` zijn gewoon de tellerwaarden: buiten het zichtbare gebied zijn ze groter dan 639 en 479, en de modules die ze gebruiken moeten dat negeren door naar `active` te kijken.

## 6. Een testbeeld

Voordat er een framebuffer is, laten we de generator een beeld maken dat alleen uit de coördinaten volgt. Dat is een testbeeld, zoals de televisie ze vroeger 's nachts uitzond. Het moet drie dingen laten zien:

1. een witte rand van 1 pixel: ligt het zichtbare gebied precies goed, dan zie je de rand aan alle vier de kanten. Ontbreekt er een kant, dan wijkt de timing af.
2. acht kleurbalken: staan de drie kleurkanalen niet verwisseld?
3. een grijsverloop van 16 stappen: werkt de DAC over het hele bereik?

```{.verilog include="beeld/vga_bars.v"}
```

Het balknummer is `x / 80`, maar we delen niet. Een deling kost veel logica, en we hoeven het getal alleen te weten tot 7. In plaats daarvan tellen we hoeveel van de zeven grenzen (80, 160, ...) `x` al voorbij is. Dat zijn zeven vergelijkingen die samen de balk geven. Dit is een veelgebruikte truc in hardware: vervang een deling door vergelijkingen of door een teller.

Tot slot de top, die de tellers en het testbeeld verbindt:

```{.verilog include="beeld/vga_testbeeld.v"}
```

Let op de uitgangsregisters onderaan. Alle uitgangen worden samen één klok vertraagd. Dat doen we met twee redenen:

1. De ingangen van de monitor mogen niet glitchen. Kleurlogica achter de tellers heeft kleine verschillen in looptijd, en een glitch op `hsync` kan de monitor laten denken dat er een nieuwe lijn begint. Een flipflop vlak voor de pin maakt de uitgang schoon.
2. Alle uitgangen horen bij dezelfde klokperiode. Als sync en kleur door verschillende logica lopen, gaan ze uit de pas: het beeld schuift een pixel. Als ze samen door een register gaan, blijft de onderlinge timing gelijk.

Dat tweede principe, alles wat bij elkaar hoort even lang vertragen, keert volgende week terug, wanneer het geheugen een klok vertraging toevoegt.

## 7. Testen zonder monitor

Een echte monitor heb je voor de simulatie niet nodig. We maken er zelf een: een stuk Verilog dat alleen voor de simulatie bedoeld is, en dat zich net zo gedraagt als een monitor. Het kijkt alleen naar de syncpulsen (zoals een echte monitor) en bepaalt daaruit waar de pixels liggen. Het beeld begint 144 pixels na het begin van de horizontale sync (96 sync + 48 back porch) en 35 lijnen na het begin van de verticale sync (2 + 33). Alle pixels komen in een geheugen, en een taak schrijft het hele beeld weg als PPM-bestand.

```{.verilog include="beeld/vga_mon.v"}
```

Er zijn twee tests. De eerste controleert de timing met losse tellers die de getallen uit de specificatie letterlijk gebruiken. Dat is een bewuste keuze: gebruik je de tellers uit het ontwerp zelf, dan controleer je het ontwerp met zichzelf en slaagt elke fout.

```{.verilog include="beeld/tb_vga_sync.v"}
```

De tweede bekijkt het testbeeld met de virtuele monitor en vergelijkt elke pixel van het eerste volledige beeld met wat het volgens de beschrijving moet zijn:

```{.verilog include="beeld/tb_vga_testbeeld.v"}
```

Als de tests slagen, schrijft de laatste ook `build/testbeeld.ppm`. Een PPM is het eenvoudigste beeldformaat dat bestaat, maar de meeste programma's openen het niet. Dit kleine script zet het om naar PNG:

```{.python include="beeld/ppm2png.py"}
```

```{.python include="beeld/test_ppm2png.py"}
```

Draai `python3 ppm2png.py ../../build/testbeeld.ppm testbeeld.png` in `labs/beeld` en open het resultaat: acht kleurbalken, daaronder drie keer het grijsverloop, en een witte rand (die je op een witte achtergrond niet ziet).

### Zijn de tests wel streng genoeg?

Een test die altijd slaagt is waardeloos. We hebben daarom met opzet fouten in het ontwerp gebracht en gekeken of de test ze vindt. Dit zijn de resultaten van die proef:

| Fout in het ontwerp | Wat de tests zeggen |
|---------------------|---------------------|
| `H_SYNC = 95` in plaats van 96 | `tb_vga_sync`: "een lijn duurt 800 klokken" en "horizontale sync is 96 klokken laag" falen |
| `V_BP = 32` in plaats van 33 | `tb_vga_sync`: "een beeld duurt 525 lijnen" faalt |
| de rechterrand op `x == 638` in plaats van 639 | `tb_vga_testbeeld`: pixel (639,321) is grijs in plaats van wit |
| `vblank` bij `y > 480` in plaats van `y >= 480` | `tb_vga_sync`: "vblank hoort bij y >= 480" faalt |
| de sync een klok te vroeg ten opzichte van de kleur | `tb_vga_testbeeld`: de balkgrenzen liggen een pixel verschoven |
| **de uitgangsregisters weglaten** | **geen enkele test merkt het: alles slaagt** |

De laatste regel is de les. Een simulatie zonder vertragingen ziet geen glitches, dus dit soort fout vang je niet met een testbench. Daar helpen alleen een ontwerpregel (elke uitgang uit een register) en, later, een timinganalyse. Weten wat je tests niet kunnen vangen is net zo belangrijk als weten wat ze wel vangen.

Probeer het zelf in oefening 8. Het is een goede gewoonte om bij elke nieuwe test minstens één fout te bedenken die hij moet vangen.

## 8. De analoge kant

Het ontwerp geeft per kleur 4 bit. De monitor wil een spanning tussen 0 en 0,7 V. Daar zit een DAC tussen (digitaal-naar-analoog-omzetter), en de eenvoudigste DAC is een weerstandsnetwerk.

De monitoringang is een weerstand van 75 Ω naar aarde. Met één bit per kleur zet je een weerstand `Rs` in serie tussen de FPGA-pin (3,3 V) en de monitor. Samen met de 75 Ω is het een spanningsdeler, en je wilt 0,7 V:

```text
  Vuit = 3,3 V · 75 / (Rs + 75) = 0,7 V   →   Rs = 75 · (3,3 / 0,7 − 1) = 279 Ω   (kies 270 Ω)
```

Met vier bits maak je een gewogen netwerk: elke bit krijgt een weerstand die twee keer zo groot is als die van de bit erboven, zodat de bits 8, 4, 2 en 1 keer meetellen. Als alle vier aan staan staan de weerstanden parallel, en hun samengestelde waarde moet weer ongeveer 270 Ω zijn. Oefening 5 laat je dit uitrekenen.

In de praktijk koop je een VGA-module die dit al doet. Er bestaan Pmod-modules met 4 bit per kleur voor FPGA-borden. Kijk in de handleiding van de module naar de volgorde van de pinnen en naar het aantal bits: 4 bit per kleur geeft de 4096 kleuren waar ons ontwerp van uitgaat, en een module met 1 of 2 bit past er ook op, met minder kleuren.

> **Controleer de pinnen zelf.** Welke FPGA-pin bij welke Pmod-pin hoort, staat in het schema van je bord en in de handleiding van de module. In `labs/beeld_fpga` staat een voorbeeld-pinbestand met vraagtekens in plaats van nummers.

## 9. Lab

1. Draai de tests van fase 7: `python3 test_labs.py beeld`. Dit draait ook de tests van de volgende weken, dus het duurt een halve minuut tot een minuut. De regels met `PASS` van `tb_vga_sync`, `tb_vga_testbeeld` en `test_ppm2png` horen bij deze week.
2. Zet `testbeeld.ppm` om naar PNG en bekijk het. Zie je alle acht balken en de 16 grijstinten?
3. Verander in `vga_bars.v` de rand: maak hem 2 pixels dik. Welke test faalt en wat moet je in de test aanpassen?
4. Zet in `vga_sync` de polariteit om (`SYNC_NEG = 0`). Welke tests falen? Wat zou je van een echte monitor verwachten?
5. Verander in `tb_vga_sync.v` de klokperiode (`always #20 pclk = ~pclk;`) in `#25`. Verandert er iets aan de testresultaten? Waarom (niet)?

## 10. Oefeningen

1. Bereken voor 25,175 MHz de lijnfrequentie en de beeldfrequentie. Bereken ook de beeldfrequentie bij de 25,125 MHz van de PLL.
2. Hoe lang duurt een lijn bij 25,125 MHz, en hoeveel daarvan is zichtbaar? Welk deel van de tijd is blanking?
3. Hoeveel geheugen heb je nodig voor een beeld van 640 x 480 met 12 bit per pixel? De UP5K heeft 120 kbit blok-RAM. Wat volgt daaruit voor volgende week?
4. De modus 800 x 600 bij 60 Hz heeft horizontaal 800 zichtbaar, 40 front porch, 128 sync en 88 back porch (totaal 1056), verticaal 600 zichtbaar, 1 front porch, 4 sync en 23 back porch (totaal 628), met positieve syncpulsen en een pixelklok van 40 MHz. Welke parameters geef je aan `vga_sync`? Haalt onze PLL 40 MHz precies? (Tip: `icepll -i 12 -o 40`.)
5. Ontwerp een DAC met vier weerstanden voor één kleurkanaal: de bit met het hoogste gewicht krijgt een weerstand `R`, de volgende `2R`, dan `4R` en `8R`. Alle bits staan aan: wat is de parallelweerstand als functie van `R`? Welke `R` geeft ongeveer 270 Ω? Kies waarden uit de E24-reeks.
6. Waarom moet het kleursignaal in de blanking zwart zijn?
7. Wat is er mis met een VGA-generator die `hsync` rechtstreeks uit de teller laat komen (zonder register), terwijl de kleur wel uit een register komt?
8. Maak de volgende fouten in het ontwerp en kijk welke test ze vangt: (a) `V_BP = 32`, (b) de rand rechts op `x == 638`, (c) `vblank` op `y > 480`, (d) de uitgangsregisters in `vga_testbeeld` vervangen door `assign`-regels. Welke wordt niet gevangen, en waarom niet?
9. Uitdaging: maak een testbeeld met een raster van 1 pixel dikke lijnen om de 32 pixels en controleer het met de virtuele monitor.

## 11. Antwoorden

1. Lijn: 25 175 000 / 800 = 31 469 Hz. Beeld: 31 469 / 525 = 59,94 Hz. Met 25,125 MHz: 25 125 000 / 800 / 525 = 59,82 Hz.
2. 800 / 25,125 MHz = 31,84 µs. Zichtbaar: 640 / 25,125 MHz = 25,47 µs, dat is 80 %. De overige 20 % is blanking (front porch, sync en back porch).
3. 640 x 480 x 12 = 3 686 400 bit, ongeveer 460 KB. De UP5K heeft 120 kbit blok-RAM, dus dat past zeker niet. We moeten dus met veel minder pixels of veel minder bits per pixel werken. Volgende week kiezen we 160 x 120 pixels van 4 bit.
4. `H_VIS=800, H_FP=40, H_SYNC=128, H_BP=88, V_VIS=600, V_FP=1, V_SYNC=4, V_BP=23, SYNC_NEG=0`. De PLL haalt 39,75 MHz (DIVF 52, DIVQ 4), dat is 0,6 % te laag. Let op: de testbeelden en de testbenches hebben 640 en 480 hard ingebouwd en moet je ook aanpassen. Bij onze meting haalt het beeldgedeelte van het ontwerp 36 tot 38 MHz, dus 40 MHz past er niet zonder meer in.
5. Parallel: 1 / (1/R + 1/2R + 1/4R + 1/8R) = R / 1,875 = 0,533 R. Voor 270 Ω is `R` = 506 Ω, dus kies 510 Ω, 1 kΩ, 2 kΩ en 4,3 kΩ (E24). Dat geeft samen 1 / (1/510 + 1/1000 + 1/2000 + 1/4300) = 271 Ω. Dit negeert de weerstand van de uitgang van de FPGA-pin en de tolerantie van de weerstanden. Een Pmod-module doet dit voor je.
6. De monitor gebruikt de back porch om zijn zwartniveau te bepalen. Staat er in de blanking een kleur, dan kalibreert hij op de verkeerde waarde en zijn alle kleuren verschoven. Daarnaast tekent hij tijdens de terugslag niet, dus een kleur zou alleen onnodig zijn.
7. De sync zou een klok eerder komen dan de kleur. Het beeld schuift dan een pixel ten opzichte van de sync, en bovendien kan de combinatorische sync glitchen. Alles wat bij elkaar hoort, hoort uit dezelfde laag registers te komen.
8. (a) wordt gevangen door `tb_vga_sync`: een beeld duurt dan 524 lijnen. (b) wordt gevangen door `tb_vga_testbeeld`: de pixel op `x = 639` is niet meer wit. (c) wordt gevangen door `tb_vga_sync`, die `vblank` op elk moment vergelijkt met `y >= 480`. (d) wordt niet gevangen: zonder registers komen sync en kleur nog steeds gelijk aan en zijn alle pixels op de goede plek. Wat je verliest (schone flanken, geen glitches) bestaat in een simulatie zonder vertragingen niet.
9. Dit is een open opdracht. Schrijf een tweede versie van `vga_bars` met `x[4:0] == 0 || y[4:0] == 0`, en pas de verwachting in de testbench aan op dezelfde voorwaarde.

## 12. Zelftest

1. Waarom heeft een VGA-monitor geen geheugen nodig?
2. Wat is het verschil tussen de front porch en de back porch?
3. Hoeveel pixelklokken duurt een lijn en een beeld in 640 x 480?
4. Waarom gaan alle uitgangen door een register?
5. Waarom controleert een test de timing met losse tellers en niet met de tellers uit het ontwerp?

Antwoorden: (1) Het beeld wordt op het moment van aankomen getekend; de signalen bevatten alles wat nodig is, in de juiste volgorde. (2) De front porch is de pauze tussen de laatste pixel en de syncpuls, de back porch de pauze tussen de syncpuls en de eerste pixel van de volgende lijn. (3) 800 klokken per lijn, 800 x 525 = 420 000 klokken per beeld. (4) Zodat de uitgangen schoon zijn (geen glitches) en sync en kleur gelijk lopen. (5) Een test die dezelfde tellers gebruikt als het ontwerp herhaalt zijn fouten, dus slaagt altijd.

## 13. Verder lezen

- De VESA-timingtabellen voor standaardmodi (zoek op "VESA DMT"), voor andere resoluties dan 640 x 480.
- Het datablad en de handleiding van het bord of de VGA-module die je kiest, voor de pinnen en de DAC.
- De documentatie van `icepll` en het hoofdstuk over de PLL in de iCE40 sysCLOCK-handleiding van Lattice.
- Voor wie het ziet zitten: de `vga`-voorbeelden bij de iCEBreaker en bij de open-sourcetools, om je ontwerp mee te vergelijken.

---

> **Het beeld staat.** Je hebt een generator die een correct VGA-signaal maakt en je weet hoe je zonder monitor kunt bewijzen dat dat zo is. Er zit alleen nog niets achter: het beeld volgt uit de coördinaten.

Volgende week: een geheugen waarin de CPU pixels kan zetten, en de brug tussen twee klokken.
