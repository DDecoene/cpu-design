# CPU Design Cursus: van nul tot chipbouwer

Een Nederlandstalige zelfstudiecursus over digitale elektronica en CPU-ontwerp, verdeeld over 26 weken, plus een vervolgproject van vier weken.
De stof loopt van spanning, stroom en weerstand via logische poorten en Verilog naar een eigen 8-bit CPU,
een stackmachine, een transport-triggered architecture, pipelining, caches en interrupts. De laatste weken
gaan over FPGA's, een ontwerp met 74HC-chips en de stappen naar een chip. Een vervolgproject (week 27 tot 30) bouwt een computer die een beeld van een SD-kaart op een VGA-monitor zet.

De cursus gaat uit van een beginner zonder voorkennis van elektronica. Programmeerervaring helpt voor de
Python- en Verilog-delen, maar is niet vereist.

## Inhoud

| Fase | Weken | Onderwerp |
|------|-------|-----------|
| 1 | 1-4 | Elektronica en logica: transistor, poorten, Booleaanse algebra, mux, decoder, opteller |
| 2 | 5-8 | Geheugen en tijd: latches, flipflops, registers, tellers, toestandsmachines, RAM en bus |
| 3 | 9-12 | Verilog en de ALU: testbenches, verificatie, getalrepresentatie, shifters, vermenigvuldigen |
| 4 | 13-17 | Een 8-bit CPU: instructieset, datapath, microcode, verificatie, assembler in Python |
| 5 | 18-22 | Andere architecturen: stackmachine en Forth, TTA, pipelining, caches, interrupts en I/O |
| 6 | 23-26 | Richting hardware: FPGA, timing, een TTA uit 74HC-chips, ASIC-ontwerpstroom en eindopdracht |
| 7 | 27-30 | De beeldcomputer (project): VGA-generator, framebuffer, SPI en een SD-kaart |

Elke week bestaat uit doelen, uitleg, een lab met Verilog- of Python-code, oefeningen met antwoorden en een zelftest.
De bijlagen bevatten een Verilog-spiekbrief, de instructiesets, een chiplijst, formules en een woordenlijst.

## Wat staat waar

| Map of bestand | Inhoud |
|----------------|--------|
| `src/` | de tekst van alle hoofdstukken (Markdown) |
| `labs/` | alle code, per week of per project; het boek neemt zijn listings hieruit over |
| `boek/` | de opmaak van het boek: Typst-sjabloon, pandoc-filter, kleuring en letters |
| `test_labs.py` | draait alle tests |
| `build.py` | bouwt het boek |
| `.devcontainer/` | een werkomgeving met alle tools (Codespaces of VS Code) |

Het boek staat niet in de repo maar bij de [Releases](../../releases), in drie PDF's:

| Bestand | Voor |
|---------|------|
| `cpu-design-cursus.pdf` | het scherm: alles in één bestand, met klikbare inhoud, verwijzingen en webadressen |
| `cpu-design-cursus-print.pdf` | afdrukken: recto-verso op A4, met een bredere binnenmarge voor een ringmap; elk hoofdstuk begint op een rechterpagina |
| `cpu-design-cursus-codeboek-print.pdf` | afdrukken: de lange listings, als tweede map naast het boek |

Korte listings staan in de tekst. Een lange listing (meer dan 40 regels) staat in het codeboek; in de tekst staat op die plaats een verwijzing. De antwoorden op de oefeningen en de zelftests staan achteraan in het boek.

Begin met het hoofdstuk Welkom: dat beschrijft de werkwijze en welke software en onderdelen je nodig hebt. Wil je liever zelf bouwen, zie hieronder.

## Werkomgeving in een container

De map `.devcontainer/` beschrijft een kant-en-klare omgeving. Open de repo in GitHub Codespaces of in VS Code met de Dev Containers-extensie ("Reopen in Container"). Daarin staan Icarus Verilog, Python, Yosys en nextpnr (als YoWASP in `~/fpga-venv`, zoals week 23 beschrijft), pandoc en Typst klaar, plus de VS Code-extensies voor Verilog en Surfer (golfvormen). Bij het aanmaken draait de container meteen `test_labs.py`.

KiCad (week 25) en het programmeren van een echt FPGA-bord zitten er niet in: daarvoor heb je je eigen computer nodig.

## De code testen

Je hebt [Icarus Verilog](https://steveicarus.github.io/iverilog/) en Python 3 nodig.

```text
python3 test_labs.py            # alle tests (74)
python3 test_labs.py 04 cpu     # alleen labs/week04 en labs/cpu
```

## Het boek bouwen

Bij elke push bouwt GitHub Actions het boek (`.github/workflows/release.yml`); bij een tag komen de PDF's bij de release. Zelf bouwen kan ook.

Je hebt [pandoc](https://pandoc.org/) 3.1 of nieuwer en [Typst](https://typst.app/) 0.13 nodig. In de container staan ze al klaar.

```text
./build.py            # alle drie de PDF's (ongeveer een halve minuut)
./build.py scherm     # alleen de schermversie
```

Zo werkt het: `build.py` zet elk hoofdstuk uit `src/` met pandoc en `boek/filter.lua` om naar Typst, en Typst zet het boek met het sjabloon `boek/boek.typ`.

Code staat nooit in de tekst zelf. Een hoofdstuk verwijst naar een bestand in `labs/`, en het boek neemt het over:

````text
```{.verilog include="cpu/alu.v"}
```
````

Zo is de code in het boek altijd dezelfde als de geteste code. Langer dan 40 regels gaat naar het codeboek. Met de klasse `.volledig` blijft een lange listing toch in de tekst. Met `van=12 tot=30` toon je alleen die regels in de tekst; het hele bestand komt dan in het codeboek.

## Stand van zaken

- De Verilog-ontwerpen worden gesimuleerd met Icarus Verilog en de Python-hulpmiddelen worden getest.
  Alle 74 tests in `test_labs.py` slagen.
- De synthese en place-and-route in week 23 en 24 zijn met Yosys en nextpnr uitgevoerd. De bijbehorende
  getallen (LUT's, frequenties) komen uit die runs.
- De beeldcomputer van week 27 tot 30 is gesimuleerd (virtuele VGA-monitor, SD-kaartmodel) en met Yosys en nextpnr gesynthetiseerd voor een iCE40 UP5K (1 407 van 5 280 logische cellen, 20 van 30 blok-RAM's, de klokken met marge). De pinbestanden zijn niet ingevuld en alles is nooit op een bord uitgeprobeerd.
- Er is geen hardware gebouwd. Het FPGA-bord uit week 23, de 74HC-print uit week 25 (KiCad) en de chip uit
  week 26 (Tiny Tapeout) zijn beschreven als plan en nooit in de praktijk uitgevoerd.
- De oefeningen en hun antwoorden zijn niet door een lezer uitgeprobeerd. Fouten zijn dus mogelijk.
- Pinnummers, vertragingen en prijzen moet je altijd controleren in de documentatie van de onderdelen die je koopt.

Een fout gevonden of iets onduidelijk? Open een issue.

## Licentie

De tekst valt onder CC BY-SA 4.0 en de code onder de MIT-licentie. Zie [LICENSE.md](LICENSE.md).
