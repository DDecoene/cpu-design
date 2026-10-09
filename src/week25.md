---
title: "Week 25 · Je TTA bouwen uit chips: ontwerp, simulatie en printplaat"
---

<p class="subtitle">Fase 6 · Van code naar chip · ongeveer 16 uur</p>

# Week 25: De T8 uit 74HC-chips

## Wat je na deze week kunt

- een gedragsmodel (week 19) omzetten in een ontwerp op chipniveau: welke chip doet wat en hoe zijn ze verbonden
- de timing van een synchroon bord ontwerpen: wanneer telt de PC, wanneer krijgt een register zijn klokpuls en waarom
- een structureel model van het bord schrijven en cyclus voor cyclus vergelijken met het gedragsmodel, voordat je een print bestelt
- laten zien hoeveel marge het ontwerp heeft (snelle en trage chips, kloksnelheid, houdtijd)
- een onderdelenlijst (BOM) afleiden en een bouwplan maken: breadboard, KiCad-schema, printplaat, opbouw en ingebruikname

> **Wat in deze week getest is.** Het ontwerp, het structurele model, de verificatie en de timinganalyse in dit hoofdstuk zijn uitgevoerd en getest in de simulator, met realistische vertragingen. KiCad draaien, een print laten maken en het bord echt bouwen en inschakelen is niet gedaan. De paragrafen over KiCad, bestellen en solderen zijn daarom een zorgvuldig plan met aandachtspunten en geen bewezen recept. Pinnummers en vertragingen controleer je altijd in de databladen van de chips die je koopt.

## 1. Waarom de TTA zo geschikt is voor chips

Kijk terug naar week 19. De T8 heeft geen besturingseenheid: de instructie is het besturingswoord. In hardware betekent dat een ROM met de instructies, twee rijtjes decoders (wie zet data op de bus en wie neemt hem over), een bus van 8 draden en registers en een rekeneenheid die aan die bus hangen.

Er is geen toestandsmachine, geen microcode en geen opcode-decoder. Daarom is dit project haalbaar zonder een kamer vol logica.

Een eerlijke schatting van de omvang: 59 chips in het schema (plus klok, reset en stapschakeling), samen ruim 1000 pinnen. Dat is groot voor een breadboard en prima voor een printplaat. Een advies:

1. Bouw eerst kleine deelschakelingen op een breadboard (programmateller en ROM, één register aan de bus, de opteller) om de technieken te leren.
2. Teken dan het complete schema in KiCad.
3. Bestel één printplaat, bouw hem in stappen op met voetjes (sockets) voor alle chips en test elk blok voordat je het volgende plaatst.

## 2. Het blokschema

```text
  klok ─► PC (2×161) ─► buffer ─► ROM (3×28C256) ─► instructie van 24 bit
            ▲ laden van de bus                          │
            │                       ┌───────────────────┼─────────────────────┐
            │                       ▼                   ▼                     ▼
            │                 guard + vlaggen     bestemmingsvelden       bronveld
            │                  (151) → "go"       (4× 238, levels)      (2× 138, OE')
            │                       │                   │                     │
            │                       └──► pulsen ◄───────┘                     │
            │                              │ (AND met phi, go, niet gehalt)   │ OE'
            │                              ▼                                  ▼
            └──────────────────────  BUS (8 draden, met pull-down)  ◄─────────┘
                                       ▲  │   ▲  │   ▲  │   ▲  │
                                       │  ▼   │  ▼   │  ▼   │  ▼
                               R0..R3 (4×574)  OP     MAR/RAM     IN / OUT
                                               (574)  (574+62256) (244 / 574)

     rekeneenheid:  OP + bus ─► opteller / AND / OR / XOR / SHL ─► RES (574) en vlaggen (74)
```

## 3. Hoe de hardware de ideeën uit het model uitvoert

### De bus en de bronnen

De bus bestaat uit acht draden, aan één kant met pull-down-weerstanden naar massa (een weerstandsnetwerk van 8 × 10 kΩ). Als niemand de bus aanstuurt, leest iedereen 0. Dat is precies het gedrag van het gedragsmodel voor bronnen die niet bestaan.

Elke bron is een chip met een tri-state uitgang, die alleen aan staat als zijn output-enable (OE', actief laag) laag is:

| Bron | Chip |
|------|------|
| `#constante` | 74HC244 aan de laagste ROM-byte |
| `R0` ... `R3` | de uitgang van het 74HC574-register zelf |
| `RES` | 74HC244 achter het resultaatregister |
| `RESHR` | 74HC244 met de bits één plaats verschoven (puur bedrading) |
| `RESNOT` | 74HC240, een inverterende buffer |
| `MEM` | de datapinnen van het RAM |
| `IN` | 74HC244 aan de ingangspoort |
| `PC2` | twee 74HC283 (PC + 2) met een 74HC244 |
| `FLAGS` | 74HC244 aan de drie vlag-flipflops |

Het bronveld van de instructie loopt naar twee 74HC138-decoders. Eén van de acht uitgangen is laag, en dat is precies de OE' van de gekozen bron.

### De bestemmingen en de timing

Hier zit het lastigste deel van het ontwerp. We willen dat een register precies op het juiste moment zijn waarde overneemt, en dat de data dan nog stabiel is.

```text
 clk      ┌─────────┐         ┌─────────┐
          │         │         │         │
 ─────────┘         └─────────┘         └─────
          ↑ t = 0   ↓ T/2     ↑ T
 PC        verandert                     verandert (telt of laadt)
 ROM        ├── zoeken ──┤
 decoders    ├─ settelen ─┤
 bus                 stabiel ───────────────────┤
 doelregister                  ▲ kort klokpuls: de MOVE gebeurt hier
```

Op de stijgende flank van de klok telt de PC door (of laadt hij een sprongdoel). Het ROM zoekt de nieuwe instructie op en de decoders en de bus settelen in de eerste helft van de cyclus. Op de dalende flank krijgt het doelregister een korte klokpuls en neemt het de waarde van de bus over. De bus is dan al lang stabiel en blijft dat tot na de volgende stijgende flank. Dat geeft een grote houdtijdmarge.

Dit lost een klassiek probleem op. Klok je de bestemmingsregisters op het signaal dat tegelijk de bron selecteert, dan is er een race: de bus kan veranderen op hetzelfde moment als de klokflank. Door in het midden van de cyclus te klokken, ver van elke verandering, verdwijnt het probleem.

De bestemmingsdecoders zijn daarom 74HC238-chips (met actief hoge uitgangen) die niveaus geven, stabiel zodra het ROM gesetteld is. Een AND-poort per register maakt er een puls van:

```text
 puls_register = niveau_van_de_decoder  AND  phi  AND  go  AND  niet_gehalt  AND  niet_in_reset
```

Hierin is `phi` de omgekeerde klok (hoog in de tweede helft) en `go` de uitkomst van de guard.

### De guard

Drie bits van de instructie kiezen met een 74HC151 (8-naar-1 multiplexer) welke vlag meetelt. De ingangen zijn `1`, Z, !Z, C, !C, N, !N en `0`. De omgekeerde vlaggen komen gratis uit de Q'-uitgangen van de flipflops.

### De rekeneenheid

```text
          bus ───┬────────────────────────────┐
                 │                            │
   OP (574) ─────┼─► opteller (2×283) ─┐      │
                 │   (bus ^ SUB: XOR)  │      │
                 ├─► AND  (2×08)  ─────┤      ▼
                 ├─► OR   (2×32)  ─────┼─► resultaatbus (tri-state, 5×244) ─► RES (574)
                 ├─► XOR  (2×86)  ─────┤                    │
                 └─► SHL (bedrading) ──┘                    └─► Z, N, C (74)
```

Elke bewerking heeft een eigen tri-state buffer op de resultaatbus, en de bestemming kiest welke aan staat. Bij `SUB` worden alle bits van de bus omgekeerd (XOR met het SUB-niveau) en gaat de carry-in omhoog: `OP + ~bus + 1`. Bij `ADC` is de carry-in de C-vlag.

De Z-vlag is een NOR met 8 ingangen (74HC4078) over de resultaatbus. De N-vlag is bit 7. De C-vlag komt van de carry-uit van de opteller (bij ADD, SUB en ADC) of van bit 7 van de bus (bij SHL), en wordt nul bij AND, OR en XOR.

## 4. Het schema als code

Eerst de chipmodellen. Elk model heeft de pinnen en de actief-laag-conventies van het datablad, plus een typische vertraging. Die vertragingen zijn schattingen, dus controleer ze in de databladen van de chips die je koopt.


Kopieer het gedragsmodel (`tta.v`), de assembler (`tta_asm.py`) en de programma's uit `labs/tta/` naar `labs/tta_hw/`.

```{.verilog include="tta_hw/hc74xx.v"}
```

Dan het bord zelf. Elke `u_...` is één chip en elke `wire` een draad. Als je een schema in KiCad tekent, is dit je tekening in tekst.

```{.verilog include="tta_hw/t8_board.v"}
```

### Wie is wie op het bord?

| Chip(s) | Rol |
|---------|-----|
| `u_pc_lo`, `u_pc_hi` (74HC161) | programmateller, telt en laadt |
| `u_pc_buf` (244) | buffer op het ROM-adres (extra marge voor de houdtijd) |
| `u_rom_hi/mid/lo` (28C256) | het programmageheugen: drie bytes per instructie |
| `u_ram` (62256) | het datageheugen |
| `u_d0` ... `u_d3` (74HC238) | bestemmingsdecoders (niveaus) |
| `u_s0`, `u_s1` (74HC138) | brondecoders (actief laag) |
| `u_guard` (74HC151) | guardkeuze |
| `u_fz`, `u_fn`, `u_fc`, `u_halt` (74HC74) | vlaggen en de halt-flipflop |
| `u_r0` ... `u_r3` (574) | algemene registers |
| `u_op`, `u_res`, `u_mar`, `u_out` (574) | operand, resultaat, geheugenadres, uitvoer |
| `u_g1` ... `u_g4`, `u_e2` | AND-poorten voor de pulsen |
| `u_inv1`, `u_inv2` | inverters |
| `u_add_*`, `u_bx_*`, `u_and_*`, `u_or_*`, `u_xor_*`, `u_rb_*` | rekeneenheid |
| `u_trig`, `u_zero` (4078) | "is het een trigger" en "is het resultaat nul" |
| `u_imm`, `u_resb`, `u_reshr`, `u_resn`, `u_in`, `u_pc2`, `u_flags` | bronbuffers |

## 5. Wat de simulatie aan het licht bracht

Deze punten zijn op papier makkelijk te missen en op een bord duur. De simulatie vond ze alle drie.

1. De halt-flipflop wiste zichzelf. Bij `HALT` werd `halted` 1. Maar zodra `halted` 1 is, valt `e2` (de "mag-doorgaan"-schakeling) weg, dus `halt_d` wordt 0 en de volgende klokflank zette `halted` weer terug op 0. Een stopvlag moet blijven staan. De oplossing is een OR met de eigen uitgang (`u_o2`).
2. Er ontstonden valse pulsen tijdens een reset. Bij een reset zakken de vlaggen en de halt-flipflop met licht verschillende vertragingen. In die korte tijd kon een schrijfpuls ontstaan die een register vulde (in de test kreeg `OP` zomaar de waarde van een constante). Op een echt bord kan zo'n valse puls ook het uitvoerregister of het RAM raken. De oplossing is dat de reset meetelt in "mag-doorgaan" (`u_e2`, een 74HC11).
3. De registers hebben geen reset. Een 74HC574 heeft geen resetpin en bevat na het inschakelen willekeurige data. Een programma mag dus nooit aannemen dat R0 nul is. In het model begint het bord met nullen en de test "schakelt de voeding uit en aan" door ze tussen de programma's op nul te zetten.

Alle drie volgden uit de manier van testen: het gedragsmodel is de specificatie, het bord is de implementatie en een verschil van één bit in één cyclus was genoeg om de fout te vinden.

## 6. Verificatie: het bord naast het gedragsmodel

`pair_hw` zet één bord naast één gedragsmodel uit week 19 met hetzelfde programma. Na elke klokcyclus vergelijkt het de volledige toestand: PC, R0 tot en met R3, OP, MAR, RES, de vlaggen, de uitvoer en de halt-vlag. Het controleert ook dat er nooit een X (conflict) op de bus staat.

```{.verilog include="tta_hw/pair_hw.v"}
```

Eerst de acht programma's uit week 19:

```{.verilog include="tta_hw/tb_t8_board.v"}
```

Dan 300 willekeurige programma's, met alle guards, bronnen en bestemmingen, cyclus voor cyclus vergeleken:

```{.verilog include="tta_hw/tb_t8_board_random.v"}
```

Beide slagen.

## 7. Hoeveel marge heeft het ontwerp?

Een logisch correct ontwerp kan toch niet werken als de klok te snel is. Het bord is onder verschillende omstandigheden gesimuleerd. Het script `sweep.py` doet dit na.

```{.python include="tta_hw/sweep.py"}
```

De resultaten (voor alle 300 willekeurige programma's):

| Omstandigheden | Resultaat |
|----------------|-----------|
| typische chips, ROM 70 ns, 1 MHz | ok |
| typische chips, ROM 70 ns, 2 MHz | ok |
| typische chips, ROM 70 ns, 2,5 MHz | fout |
| snelle chips (×0,5), 1 MHz | ok |
| trage chips (×2), 1 MHz | ok |
| trage poorten (×2) met een zeer snel ROM (1 ns), 1 MHz | ok (houdtijd is geen probleem) |
| trage chips (×2) en het langzaamste ROM (150 ns), 1 MHz | ok |
| trage chips (×2), ROM 150 ns, 1,25 MHz | fout |

Wat hieruit volgt:

- Mik op 1 MHz. Dat werkt in de simulatie met snelle en trage chips en met elk ROM, van 1 tot 150 ns toegangstijd.
- Houdtijd is geen probleem, doordat de klok in het midden van de cyclus wordt gegeven en door de buffer op het ROM-adres.
- De grens ligt bij ongeveer 2 MHz met typische waarden, bepaald door de keten ROM, decoder, bus en opteller binnen een halve klokperiode.
- Gebruik eerst de enkelstapsklok (één puls per druk op een knop). Pas daarna zet je een kristaloscillator in.

Deze simulatie is zo goed als haar modellen. Echte chips hebben minimale en maximale vertragingen, de printbanen voegen vertraging en ruis toe en de voedingen hebben pieken. De marge (een factor 2 in kloksnelheid) is bedoeld om dat op te vangen.

## 8. De onderdelenlijst

Het script telt de chips direct uit het schema, zodat de lijst nooit afwijkt van het ontwerp:

```{.python include="tta_hw/bom.py"}
```

De uitvoer:

```text
28C256          3  DIP-28     32K x 8 EEPROM
62256           1  DIP-28     32K x 8 statisch RAM
74HC04          2  DIP-14     6 inverters
74HC08          6  DIP-14     4 AND-poorten
74HC11          1  DIP-14     3 AND-poorten met 3 ingangen
74HC138         2  DIP-16     3-naar-8 decoder, uitgangen actief laag
74HC151         1  DIP-16     8-naar-1 multiplexer
74HC161         2  DIP-16     4-bit synchrone teller
74HC238         4  DIP-16     3-naar-8 decoder, uitgangen actief hoog
74HC240         1  DIP-20     octal inverterende buffer, tri-state
74HC244        12  DIP-20     octal buffer, tri-state
74HC283         4  DIP-16     4-bit opteller
74HC32          4  DIP-14     4 OR-poorten
74HC4078        2  DIP-14     8-ingangs OR/NOR
74HC574         8  DIP-20     octal D-register met tri-state
74HC74          2  DIP-14     2 D-flipflops
74HC86          4  DIP-14     4 XOR-poorten

Totaal: 59 chips
```

Daarnaast heb je nodig (niet in het schema):

| Onderdeel | Aantal | Waarvoor |
|-----------|-------:|----------|
| IC-voetjes (DIP) | 59 | zodat je chips kunt vervangen |
| Condensator 100 nF | ca. 60 | ontkoppeling, één bij elke chip |
| Elco 100 µF | 2 | buffer voor de voeding |
| Weerstandsnetwerk 8 × 10 kΩ (SIP) | 2 | pull-down van de bus en van de ingangspoort |
| Kristaloscillator 1 MHz | 1 | de klok |
| 74HC00 en 74HC14 (of gelijkwaardig) | 2 | enkelstapsknop met debouncing, reset |
| Drukknoppen, schakelaar | 3 | stap, reset, run/stap |
| LED's met weerstanden | 30 tot 40 | bus, PC, registers, vlaggen, uitvoer (voor debuggen) |
| Connector voor de voeding, ingangspoort en uitgangspoort | | |

De prijsindicatie van het script (ruwweg €50 voor de chips, €15 voor de voetjes, plus print, LED's, condensatoren en connectoren) is een grove schatting voor kleine aantallen. Controleer actuele prijzen. Reken op een totaal van enkele tientallen euro's tot rond de honderd, waarbij de drie EEPROM's het duurste onderdeel zijn.

## 9. De ROM programmeren

Een EEPROM-programmer heeft een binair bestand nodig. Het ROM van de T8 is 24 bit breed en bestaat uit drie 8-bit chips. Dit script splitst het hex-bestand van de assembler in drie bestanden van 256 bytes:

```{.python include="tta_hw/split_rom.py"}
```

```{.python include="tta_hw/test_split_rom.py"}
```

```text
python3 tta_asm.py sum.tta
python3 split_rom.py sum.hex        # maakt sum_hi.bin, sum_mid.bin, sum_lo.bin
```

Programmeer elke chip met een EEPROM-programmer (bijvoorbeeld een goedkope USB-programmer of een Arduino-schakeling zoals Ben Eater beschrijft) met zijn eigen bestand, op adres 0. De rest van de 32 KB mag leeg blijven: de adreslijnen A8 tot en met A14 sluit je aan op massa.

> **`MEM -> MEM` bestaat niet.** Op het bord zouden lezen en schrijven dan tegelijk de bus aansturen. De assembler weigert hem.

## 10. KiCad en de printplaat: het plan

KiCad is een open-source ontwerpprogramma voor schema's en printplaten. Het is een grote installatie. Wil je niets installeren, dan zijn er online alternatieven zoals EasyEDA. De werkwijze is in beide gelijk. Dit deel is niet in de praktijk uitgevoerd, het is een plan.

### Stap voor stap

1. Schema. Teken het schema per blok op aparte bladen (hiërarchische bladen): klok en reset, PC en ROM, decoders en guard, registers en bus, rekeneenheid, en geheugen en I/O. Gebruik de bibliotheek `74xx` voor de chips. Geef de chips dezelfde namen als in `t8_board.v` (`U_PC_LO`, ...), zodat schema en model één op één samenvallen.
2. Bus. Gebruik busnetten (`D[0..7]`) met netlabels. Zet op elk blad dezelfde namen.
3. Voeding. Elke chip krijgt een condensator van 100 nF tussen VCC en GND, zo dicht mogelijk bij de pinnen. Plaats power flags en teken de voedingsnetten expliciet.
4. Ongebruikte ingangen. Elke ingang van een chip moet ergens aan hangen, nooit zwevend (week 2). Ongebruikte poorten leg je vast op massa of VCC.
5. ERC. Laat de elektrische regelcontrole (ERC) draaien tot er geen fouten meer zijn.
6. Footprints. Kies voor elke chip de footprint van een DIP-voetje (DIP-14, 16, 20 of 28).
7. Indeling. Leg de chips in rijen, zodat de bus als een rechte strook langs de registers loopt. Groepeer wat bij elkaar hoort (alle registers aan de bus, de rekeneenheid ernaast).
8. Printbanen. Leg eerst de bus, dan de besturingslijnen en dan de rest. Gebruik brede banen voor voeding en massa. Een massavlak (ground fill) aan beide zijden helpt.
9. DRC. Laat de designregelcontrole draaien met de minimale baanbreedte en afstand van de printfabrikant.
10. Exporteren. Maak Gerber-bestanden en een boorbestand, controleer ze in een viewer en bestel.

### Maat en lagen

Een print van ongeveer 160 × 100 mm met twee lagen is haalbaar. Hij hoeft niet klein te zijn, want DIP-chips zijn groot. Bij 59 chips is het verstandig ruim te plaatsen, dat maakt het routeren makkelijker. Een print met vier lagen en aparte voedingsvlakken is robuuster maar duurder. Voor 1 MHz zijn twee lagen met een goed massavlak genoeg.

### Opbouw en ingebruikname

1. Controleer vóór het solderen met de doorgangstest van je multimeter op kortsluiting: er mag geen verbinding zijn tussen VCC en GND.
2. Soldeer eerst de voetjes en condensatoren, nog geen chips. Test opnieuw op kortsluiting.
3. Zet de voeding aan zonder chips. Controleer de spanning op de VCC-pinnen van alle voetjes.
4. Bouw in stappen. Plaats eerst de klok, de enkelstap en de PC en controleer met LED's dat de PC telt. Plaats dan ROM en buffer en laat de PC door een programma van `NOP`'s lopen. Plaats dan decoders en één register, voer `#5 -> R0` uit en bekijk R0 op de bus. Daarna volgen de rest van de registers, de rekeneenheid, het RAM en de I/O.
5. Test elk blok met een kort programma dat je vooraf met de simulator hebt gecontroleerd.
6. Pas als alles werkt komen de kristaloscillator en een echt programma.

### Debuggen met wat je geleerd hebt

- Heb je een logic analyzer (week 8)? Kijk naar de klok, de bestemmingspuls van een register en de bus tegelijk. Je zou de puls midden in de cyclus moeten zien, in het stabiele deel van de bus.
- Een chip die warm wordt, wijst op een busconflict (twee uitgangen tegelijk aan) of op kortsluiting.
- Vergelijk met de simulator: draai hetzelfde programma en vergelijk de registers per stap.
- Gebruik de enkelstapsklok: één move per druk op de knop, terwijl je naar de LED's kijkt.

## 11. Lab

1. Draai `tb_t8_board.v` en `tb_t8_board_random.v`. Hoe lang duurt de random-test?
2. Draai `python3 sweep.py` en vergelijk met de tabel hierboven.
3. Sabotage-oefening: haal de OR met de eigen uitgang uit de halt-flipflop weg (`halt_hold`), draai `tb_t8_board.v` en kijk wat de test meldt. Doe hetzelfde met de reset in `u_e2`.
4. Draai `bom.py` en pas de prijzen in het script aan naar actuele aanbiedingen. Wat is je totaal?
5. Maak met `tta_asm.py` en `split_rom.py` de drie ROM-bestanden voor `fib.tta`.
6. Teken, op papier of in KiCad, het blad "programmateller en ROM" van het schema.
7. Bouw op een breadboard de kern: twee 74HC161 (PC), een 74HC244 (adresbuffer), een EEPROM met een handgemaakt programma en LED's op de PC. Laat de PC tellen met een knop als klok.

## 12. Oefeningen

1. Waarom krijgen de bestemmingsregisters hun klokpuls in de tweede helft van de cyclus en niet op de stijgende flank?
2. Het ROM heeft een toegangstijd van 150 ns en de rest van de keten (buffer, decoder, poorten, bus, opteller) kost ongeveer 200 ns. Bereken de maximale klokfrequentie als de keten binnen een halve klokperiode klaar moet zijn.
3. De bus heeft een capaciteit van ongeveer 100 pF en de pull-down is 10 kΩ. Wat is de tijdconstante van het zakken van de bus naar nul als niemand hem aanstuurt? Is dat een probleem bij 1 MHz?
4. Waarom hoort in `u_e2` de reset als ingang? Beschrijf het foutscenario in je eigen woorden.
5. Schat de voedingsstroom van het bord (neem aan dat de EEPROM's en het RAM elk ongeveer 30 mA gebruiken en de andere chips samen ongeveer 100 mA bij 1 MHz). Volstaat een USB-voeding van 500 mA?
6. Wat verandert er in het schema als je R4 tot en met R7 toevoegt (vier registers meer)? Tel de chips en noem de aanpassing aan de decoders.
7. Waarom is `MEM -> MEM` op het bord niet toegestaan?
8. Uitdaging: ontwerp een tweede bus, zodat twee moves per cyclus mogelijk zijn. Wat verandert er in het ROM, de decoders en de registers? Welke conflicten moeten de programmeur of de assembler vermijden?

## 13. Antwoorden

1. Klok je een register op de stijgende flank terwijl tegelijk de PC verandert en het ROM een nieuwe instructie levert, dan kan de bus net veranderen als het register zijn data neemt: een race (houdtijd). Door in de tweede helft te klokken zijn de bus en alle besturingssignalen al lang stabiel en blijven ze dat tot na de volgende stijgende flank.
2. Halve periode ≥ 150 + 200 = 350 ns, dus periode ≥ 700 ns, ongeveer 1,4 MHz. Met marge kies je 1 MHz.
3. τ = R·C = 10 kΩ × 100 pF = 1 µs. De bus zakt dus in enkele microseconden, veel langzamer dan de klok bij 1 MHz. Dat is geen probleem, want de bus wordt elke cyclus actief aangestuurd door de gekozen bron en de pull-down is alleen voor ongebruikte bronnen. Het is wel de reden dat de houdtijd van een bus na een uitgang naar Z gunstig is.
4. Tijdens een reset (of vlak erna) zakken de vlaggen en de halt-flipflop met verschillende vertragingen. De guard `go` en `halted_n` kunnen even een waarde geven die een korte schrijfpuls laat ontstaan. Een register, het RAM of de uitvoer krijgt dan een willekeurige waarde. Met de reset als ingang van `e2` blijven alle pulsen uit zolang de reset actief is.
5. Drie EEPROM's en één RAM: 4 × 30 mA = 120 mA. De overige chips samen zijn ongeveer 100 mA, dus ongeveer 220 mA. Dertig LED's van elk 5 mA komen daar nog eens 150 mA bij: samen ongeveer 370 mA. Dat past in de 500 mA van een USB-poort, maar met weinig marge. Gebruik zuinige LED's (1 tot 2 mA) of een aparte voeding.
6. Vier extra 74HC574 (registers) en vier extra bronnen in de decoders. De brondecoder `u_s1` heeft nog vrije uitgangen (bronnen 12 tot 15), en de bestemmingsdecoder `u_d3` ook (24 tot 30). Het gedragsmodel, de assembler en de decodertabellen moeten dezelfde nummers krijgen. Reken op 4 chips voor de registers, plus de AND-poorten voor de pulsen (een extra 74HC08).
7. Een move leest de bron en schrijft de bestemming in dezelfde cyclus. Bij `MEM -> MEM` zou het RAM zijn data op de bus zetten (OE' laag) terwijl hij ook schrijft (WE' laag): de datapinnen zouden tegelijk uitgang en ingang zijn. Het resultaat is ongedefinieerd.
8. Het ROM wordt twee keer zo breed (twee moves, dus twee keer guard, bron, bestemming en constante). Elke bus krijgt eigen brondecoders en een eigen keuze van wie hem aanstuurt, en elk register moet kiezen van welke bus het neemt (een 2:1-multiplexer ervoor). Conflicten zijn twee moves naar dezelfde bestemming in dezelfde cyclus, en het lezen van een resultaat dat een andere move in dezelfde cyclus nog moet produceren. De assembler moet dat controleren.

## 14. Zelftest

1. Hoeveel chips telt het T8-bord ongeveer?
2. Waarom is een pull-down op de bus nodig?
3. Wanneer neemt een doelregister zijn waarde over?
4. Wat bracht de simulatie bij de halt-flipflop aan het licht?
5. Wat is het doel van een buffer op het ROM-adres?

Antwoorden: (1) Ongeveer 59 in het schema. (2) Zodat een bus waar niemand op stuurt 0 leest, zoals in het gedragsmodel. (3) Op de dalende klokflank, in het midden van de cyclus, met een korte puls. (4) Dat hij zichzelf weer uitzette: een stopvlag moet zichzelf vasthouden. (5) Extra vertraging, zodat de bus niet te vroeg verandert.

## 15. Verder lezen

- *The Art of Electronics* (Horowitz en Hill): het hoofdstuk over digitale logica, timing en praktische problemen als ontkoppeling.
- Het datablad van de 74HC574, de 74HC238 en de 28C256. Lees de tabellen met setup- en houdtijden.
- De video's van Ben Eater over de breadboardcomputer en de EEPROM-programmer, vooral de uitleg over de bus en het klokken van registers.
- De KiCad-handleiding "Getting Started": schema, footprints en printontwerp.

Volgende week: het slot van de cursus. Je maakt een eindopdracht en kijkt naar de laatste stap, echt silicium, met het open-source programma Tiny Tapeout.
