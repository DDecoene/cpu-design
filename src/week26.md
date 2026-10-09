---
title: "Week 26 · Eindopdracht en de weg naar echt silicium"
---

<p class="subtitle">Fase 6 · Van code naar chip · ongeveer 16 uur</p>

# Week 26: Eindopdracht en de weg naar silicium

## Wat je na deze week kunt

- de stappen van een ASIC-ontwerpstroom benoemen en uitleggen wat er anders is dan bij een FPGA
- je T8 omzetten naar een compacte chipvariant en zijn grootte schatten
- begrijpen waarom een vast programma in ROM de hardware kan laten krimpen
- een eindopdracht kiezen, uitvoeren en beoordelen
- terugkijken op zes maanden en bepalen wat je vervolgens leert

> **Wat in deze week getest is.** De chipvariant, de verificatie en de grootteschattingen in dit hoofdstuk zijn gedraaid in simulatie en met Yosys. Een echte ASIC-ontwerpstroom met een procesbibliotheek en een bestelling bij Tiny Tapeout is niet uitgevoerd. Voor die laatste stap (prijzen, deadlines en regels) volg je de actuele documentatie van het project.

## 1. Van FPGA naar echte chip

Een ASIC (application-specific integrated circuit) is een chip waarvan de transistoren voor jouw ontwerp zijn gemaakt. De stroom lijkt op die van een FPGA, maar eindigt anders:

| Stap | Wat gebeurt er |
|------|----------------|
| RTL (Verilog) | jouw ontwerp, zoals in de hele cursus |
| Synthese | omzetten naar standaardcellen: kleine, vooraf getekende poorten en flipflops van de fabrikant |
| Floorplan en plaatsing | cellen op de chip leggen |
| Klokboom | de klok met gelijke vertraging naar alle flipflops verdelen |
| Routering | de metaallagen die alles verbinden |
| Verificatie | DRC (houdt het ontwerp zich aan de fabricageregels?), LVS (komt de getekende chip overeen met het schema?) en timing |
| GDSII | het bestand met de maskertekeningen |
| Fabricage | de fabriek maakt de chips |

Voor alle stappen bestaat open-source gereedschap: Yosys (synthese), OpenROAD (plaatsen en routeren) en Magic en KLayout (tekeningen en controles), samengebracht in de ontwerpstroom OpenLane. De procesbibliotheek (PDK) is open, bijvoorbeeld SkyWater SKY130 (130 nm) en GF180MCU.

### Tiny Tapeout

Tiny Tapeout is een project waarin honderden kleine ontwerpen op één gedeelde chip worden gemaakt. Een eigen chip kost dan enkele tientallen tot een paar honderd euro in plaats van tienduizenden. Een ontwerp is een Verilog-module met een vaste poortindeling (8 ingangen, 8 uitgangen, 8 bidirectionele pennen, klok en reset) die in een tegel van vaste grootte moet passen. Controleer op de website van het project de actuele regels, de grootte van een tegel, de kosten en de deadlines. Die veranderen per ronde.

Het verschil met een FPGA is groot: een fout in silicium is niet te repareren. Daarom is de verificatie uit week 10, 16, 19 en 25 geen luxe.

## 2. De T8 als chip

Een tegel is klein (in de orde van duizend standaardcellen; controleer de actuele waarde). Onze T8 uit week 19 heeft 256 bytes RAM en 256 instructies. Dat past niet. We maken daarom een compacte variant:

- De programmateller wordt 6 bits (64 instructies).
- Het datageheugen wordt 8 bytes (3 adresbits).
- Het programma zit als logica in de chip (een `case`-tabel), want een chip heeft geen `$readmemh`.

### Eerst bewijzen dat de herstructurering klopt

We splitsen het gedragsmodel in een kern met instelbare breedtes (`t8_core`) en een los ROM. Met de volle breedtes (8 en 8) moet de kern exact de machine uit week 19 zijn. Dat controleren we met dezelfde willekeurige test, cyclus voor cyclus.


Kopieer `tta.v` en `tta_asm.py` uit `labs/tta/` naar `labs/tt_t8/`.

```{.verilog include="tt_t8/t8_core.v"}
```

```{.verilog include="tt_t8/tb_core_equiv.v"}
```

### Het programma en het ROM

Het programma in de chip is de rij van Fibonacci, op de uitgangspennen.

```{.text include="tt_t8/chip.tta"}
```

Het ROM maken we met een generator, zodat het programma de enige bron van waarheid blijft:

```{.python include="tt_t8/mkrom.py"}
```

```{.python include="tt_t8/test_mkrom.py"}
```

Het resultaat voor ons programma (gegenereerd, nooit met de hand aanpassen):

```{.verilog include="tt_t8/rom_t8.v"}
```

### Het toplevel voor de chip

```{.verilog include="tt_t8/tt_t8.v"}
```

### De test van de chip

```{.verilog include="tt_t8/tb_tt_t8.v"}
```

## 3. Hoe groot is hij?

Zonder een echte procesbibliotheek kunnen we de oppervlakte niet berekenen, maar Yosys kan het ontwerp wel omzetten in eenvoudige poorten en flipflops. Dat geeft een bruikbare schatting.

### Het verrassende resultaat: een vast programma laat hardware verdwijnen

De volledige chip (kern en ROM) is gesynthetiseerd voor verschillende RAM-groottes, en steeds kwam er ongeveer 185 cellen uit, ook bij 256 bytes RAM. Dat kan niet kloppen voor een machine met 256 bytes RAM. De verklaring is dat ons programma het RAM nooit gebruikt. De synthesetool ziet dat en gooit het RAM weg, evenals alle bronnen en bestemmingen die het programma niet gebruikt. Wat overblijft is een machine die alleen kan wat dit ene programma nodig heeft.

Dat is een belangrijke les over chips: een vast programma in ROM is geen software meer maar logica, en logica die nooit nodig is, verdwijnt. Je moet die 185 cellen dus niet lezen als "de grootte van de T8".

### De programmeerbare kern

Om te weten hoe groot de machine is die elk programma kan draaien, synthetiseren we de kern los, met de instructie als ingang:

```{.python include="tt_t8/core_size.py"}
```

De uitkomst:

| Programmateller | RAM | Cellen | Flipflops |
|----------------:|----:|-------:|----------:|
| 6 bits | 1 byte | 593 | 73 |
| 6 bits | 4 bytes | 680 | 99 |
| 6 bits | 8 bytes | 792 | 132 |
| 6 bits | 16 bytes | 1 015 | 197 |
| 6 bits | 32 bytes | 1 428 | 326 |
| 8 bits | 256 bytes | 7 309 | 2 123 |

Zo lees je dit: de kern zonder geheugen is ongeveer 500 tot 600 cellen. Elk extra bit RAM kost een flipflop plus uitleeslogica. Het RAM van 256 bytes is verantwoordelijk voor ruim 85 % van de volledige machine. Een chip met een programma in ROM komt dus in de orde van 800 tot 1000 cellen (de ROM-logica erbij), aan de rand van wat in één kleine tegel past. Reken het zelf na met de actuele tegelgrootte.

```{.bash include="tt_t8/chip_size.sh"}
```

### Wat je hiermee leert

- Op een chip is elk bit geheugen duur. Daarom hebben chips weinig RAM en veel slimme logica.
- Het ontwerp bepaalt de grootte. Ons T8-ontwerp heeft een prima verhouding, omdat de besturing wegvalt.
- Een gegenereerd ROM (uit een te assembleren programma) is hoe vaste programma's in echte chips komen: firmware is logica.

## 4. De eindopdracht

De opdracht: maak iets dat je in deze cursus niet gebouwd hebt, test het zoals een professional en schrijf het op. Kies een van de onderstaande opdrachten, of verzin iets van dezelfde omvang (ongeveer 40 uur).

| # | Opdracht | Wat je laat zien |
|---|----------|------------------|
| 1 | T8 met twee bussen: twee moves per cyclus, met een assembler die conflicten weigert en een verificatie tegen het bestaande model | architectuur, parallellisme, verificatie |
| 2 | W8 met cache: de data-cache uit week 21 aan de CPU koppelen, met een meting van de versnelling | geheugenhiërarchie |
| 3 | De 74HC-print afmaken: schema in KiCad, controle tegen `t8_board.v`, bestelling en bouw | hardware realiseren |
| 4 | Een Forth-systeem voor S8: een interactieve interpreter met UART, woordenboek en compile-modus | software op eigen hardware |
| 5 | W8 op een FPGA met VGA of LED-matrix: een klein spel of animatie (de bouwstenen staan in week 27 tot 30) | systeemontwerp |
| 6 | De T8-chip in Tiny Tapeout: het hele ontwerp, de testbenches en de documentatie klaarmaken voor inzending | silicium |
| 7 | Bit-serial CPU: een CPU die 1 bit tegelijk rekent, met minimale hardware | een nieuwe architectuur |
| 8 | Een eigen ISA (met assembler, simulator en CPU) voor een toepassing naar keuze | volledig ontwerp |

### Wat je oplevert

1. Een specificatie: wat doet het en wat doet het niet (één pagina).
2. Het ontwerp: blokschema, belangrijkste keuzes en waarom.
3. De code: alle bronbestanden, goed gedocumenteerd.
4. Verificatie: minstens een zelfcontrolerende testbench, een referentiemodel en een willekeurige test. Voeg een mutatietest toe: maak met opzet drie bugs en laat zien dat je tests ze vinden.
5. Een meting: prestaties, grootte of timing, met cijfers.
6. Een verslag van vier tot zes pagina's: wat werkte, wat ging mis en wat heb je geleerd.

### Beoordeling (voor jezelf)

| Onderdeel | Punten |
|-----------|:------:|
| Het werkt en je bewijst het met tests | 30 |
| Kwaliteit van de verificatie (referentiemodel, willekeur, mutaties) | 25 |
| Ontwerpkeuzes zijn beargumenteerd en gemeten | 20 |
| Code en documentatie zijn leesbaar | 15 |
| Verslag, eerlijk over fouten en beperkingen | 10 |

Eerlijkheid over wat misging is geen minpunt. Het is wat professionals het meest waarderen.

## 5. Het eindexamen

Beantwoord de vragen zonder terug te kijken (de antwoorden staan eronder). Een goed resultaat is 20 van 25.

Elektronica en logica:

1. Wat is de wet van Ohm? Bereken de weerstand voor een LED van 2 V bij 5 V en 10 mA.
2. Hoe vormen twee transistoren een CMOS-inverter en waarom gebruikt hij in rust geen stroom?
3. Waarom is NAND universeel?
4. Vereenvoudig `Y = AB + AB'` en `Y = A + A'B`.
5. Beschrijf een SR-latch en leg uit waarom een flipflop die op de klokflank werkt beter is dan een latch.

Digitaal ontwerp:

6. Wat is het verschil tussen combinatorische en sequentiële logica? Geef van elk een voorbeeld.
7. Wat is het kritieke pad en hoe bepaalt het de klokfrequentie?
8. Schrijf in Verilog een 8-bit teller met reset, enable en load. Welke toekenning gebruik je en waarom?
9. Wat is een tri-state bus en wat is een busconflict?
10. Hoe trek je af met een opteller en wat betekent C = 1 na een SUB in deze cursus?

Architectuur:

11. Noem de onderdelen van een datapath en vertel wat de besturing doet. Wat is microcode?
12. Wat is het verschil tussen een register-, een stack- en een transport-triggered machine? Noem van elk een voordeel.
13. Wat kost een genomen sprong in de tweetrapspipeline van W8P en waarom zijn er geen datahazards?
14. Wat zegt `tijd = instructies × CPI / frequentie`? Verklaar ermee waarom W8F sneller is dan W8I, ondanks meer cycli.
15. Wat is forwarding en wat is het load-use-probleem?

Systemen en praktijk:

16. Wat is memory-mapped I/O? Hoe werkt een interrupt en wat bewaart de hardware?
17. Hoe werkt een direct-mapped cache? Splits een adres in tag, index en offset.
18. Wat is een LUT en waarom past een asynchroon RAM niet op blok-RAM?
19. Wat is een gate-level simulatie en wat bewijst ze?
20. Waarom is een vast programma in ROM op een chip logica en wat betekent dat voor de grootte?

Verificatie:

21. Waarom vergelijk je een ontwerp met een referentiemodel en niet met je eigen verwachting?
22. Wat is een mutatietest en welk voorbeeld heb je in deze cursus gezien?
23. Waarom slaagde de eerste versie van de interrupttest ondanks een fout in de hardware?
24. Noem twee ontwerpfouten die de bordsimulatie van de T8 vond voordat er een print was.
25. Wat is het verschil tussen "de simulatie slaagt" en "het ontwerp werkt"?

### Antwoorden

1. V = I × R. R = (5 − 2) / 0,010 = 300 Ω (kies 330 Ω).
2. Een PMOS naar Vdd en een NMOS naar GND, met dezelfde ingang. Ze staan nooit tegelijk aan, dus er is geen pad van plus naar min. Alleen bij het schakelen loopt er stroom.
3. Alle andere poorten zijn uit NAND te bouwen (NOT, AND, OR, XOR).
4. AB + AB' = A(B + B') = A. A + A'B = A + B.
5. Twee kruiselings gekoppelde NOR- of NAND-poorten. Een latch is transparant zolang de enable aan staat, wat bij terugkoppeling tot oscillatie leidt. Een flipflop neemt alleen op de klokflank over.
6. Combinatorisch: de uitgang hangt alleen af van de huidige ingangen (ALU, multiplexer). Sequentieel: er is geheugen (register, teller).
7. Het langzaamste pad tussen twee flipflops: t_clk→Q + t_logica + t_routering + t_setup. De klokperiode moet minstens zo lang zijn.
8. `always @(posedge clk or negedge rst_n) if (!rst_n) q <= 0; else if (load) q <= d; else if (en) q <= q + 1;` met de niet-blokkerende toekenning `<=`, zodat alle flipflops hun oude waarde lezen.
9. Een bus waarop meerdere bronnen kunnen schrijven via uitgangen die losgekoppeld kunnen worden (Z). Een conflict is wanneer twee bronnen tegelijk met verschillende waarden aansturen (kortsluiting, X in simulatie).
10. A − B = A + ~B + 1. C = 1 betekent dat er niet geleend is: A ≥ B zonder teken.
11. Datapath: registers, ALU, multiplexers en geheugens. Besturing: de signalen per klokcyclus, hier een controlegeheugen. Microcode: de besturing als tabel (ROM) in plaats van vaste logica.
12. Register: weinig instructies en veel parallelle mogelijkheden. Stack: korte instructies en een eenvoudige decoder. TTA: geen besturingseenheid en veel parallellisme mogelijk, maar lange programma's.
13. Eén cyclus (de flush). Registers worden aan het eind van EX geschreven en de volgende instructie leest pas in haar eigen EX.
14. W8F heeft meer cycli (LD kost 3) maar een veel hogere klok (48 tegen 34 MHz). Tijd is cycli gedeeld door frequentie, dus is W8F netto sneller (1,27 tot 1,40 ×).
15. Een resultaat rechtstreeks naar een volgende trap sturen zonder te wachten op het registerbestand. Load-use: een instructie die een zojuist geladen waarde meteen gebruikt, moet één cyclus wachten.
16. Apparaatregisters op geheugenadressen. Bij een interrupt worden de PC en de vlaggen bewaard, volgt een sprong naar de vector en herstelt RETI de toestand. De hardware bewaart PC en vlaggen, de software de registers.
17. Een regel is uniek bepaald door de index, en de tag controleert of het juiste blok erin zit. Adres 0xB7 in 16 regels van 4 bytes: tag 10, index 1101, offset 11.
18. Een LUT is een tabel van 16 bit voor een functie van vier ingangen. Blok-RAM legt het adres vast bij een klokflank (synchroon), een asynchroon RAM doet dat niet.
19. Een simulatie van de netlijst die de synthese maakte. Ze bewijst dat de synthese het gedrag niet veranderd heeft.
20. Doordat de invoer constant is, kan de tool hardware wegwerpen die het programma nooit gebruikt: het programma wordt logica. De chip is kleiner dan een universele machine.
21. Het model is een onafhankelijke specificatie en vindt fouten die je zelf niet bedacht. Het kan ook blijken dat je verwachting zelf fout was.
22. Een opzettelijke bug in het ontwerp om te zien dat de test hem vindt. Voorbeelden: het vlaggenherstel bij de interrupt (week 22), het ADC-voorbeeld (week 19) en de voorwaarde LT (week 16).
23. De routine liet de Z-vlag toevallig in een toestand die de hoofdlus niet stoorde. Pas toen de vlaggen met opzet werden verpest, werd de fout zichtbaar.
24. De halt-flipflop die zichzelf wiste, en valse schrijfpulsen tijdens reset.
25. Een simulatie bewijst alleen dat je ontwerp zich gedraagt zoals de tests die je draaide verwachten. Werkt het ontwerp echt, dan geldt dat ook voor de synthese, de timing en de echte hardware.

## 6. Terugblik

Zes maanden geleden wist je misschien niet wat een volt was. Nu heb je:

- een transistor, een poort, een flipflop en een bus begrepen en gebouwd (week 1 tot en met 8)
- Verilog geschreven en professioneel getest (week 9 tot en met 12)
- drie CPU's ontworpen (register, stack en TTA), een assembler en een Forth-compiler geschreven en een pipeline en een cache gebouwd (week 13 tot en met 22)
- een CPU op een FPGA gebracht, geoptimaliseerd en een printplaat- en chipontwerp voorbereid (week 23 tot en met 26)

Dat is veel. Maar wees eerlijk over wat je nog niet hebt:

- Je hebt geen jaren ervaring met grote ontwerpen (miljoenen poorten), complexe protocollen (PCIe, DDR) of cachecoherentie in multicore-systemen.
- Je hebt met simulaties gewerkt, en echte hardware heeft eigen verrassingen (ruis, temperatuur, voeding).
- Je hebt nog geen chip echt laten maken.

Dat zijn de vervolgstappen, en je kent het vak nu goed genoeg om ze te zetten.

## 7. Wat nu?

| Doel | Eerste stap |
|------|-------------|
| Moderne CPU's begrijpen | Hennessy en Patterson, *Computer Architecture: A Quantitative Approach*; ontwerp een RISC-V-CPU (de ISA is open) |
| Echte FPGA-projecten | Bouw een video- of audiosysteem en leer over clock-domain-crossing en timingconstraints |
| Chips maken | Dien een ontwerp in bij Tiny Tapeout en leer OpenLane |
| Verificatie als vak | cocotb, SystemVerilog en UVM, formele verificatie (SymbiYosys) |
| Het hele veld | Volg open-sourceprojecten (RISC-V, OpenROAD, SkyWater) en lees de verslagen van ASIC-ontwerpers |
| Printplaten | Bouw je T8-print en leer daarna sneller ontwerpen met meer lagen en SMD |

### Gemeenschap

Ontwerpen is een sociaal vak. Open-sourcehardware (RISC-V, OpenROAD, Tiny Tapeout, de Lattice- en Gowin-gemeenschappen), forums voor FPGA's en elektronica en conferenties (FOSDEM, het Chaos Communication Congress) zijn prettige plekken om te leren en te delen.

## 8. Slot

Het idee waar deze cursus mee begon: een CPU is niets bijzonders. Het zijn schakelaars die elkaar aan- en uitzetten, gestapeld in lagen die elk een paar dingen doen. Wie de lagen kent, ziet de magie niet meer. Je ziet een slim en begrijpelijk stuk techniek, en je kunt het zelf bouwen.

Veel plezier met je eigen projecten.

---

> **Cursus voltooid.** Je bent zes maanden bezig geweest met CPU-ontwerp, van de wet van Ohm tot een chipontwerp. Bewaar je logboek, je labs en je eindopdracht. Ze zijn je portfolio.

Wil je nog een project? Fase 7 (week 27 tot 30) bouwt een computer die een beeld van een SD-kaart op een VGA-monitor zet, met de CPU uit week 24 en een FPGA. Het begint met week 27.
