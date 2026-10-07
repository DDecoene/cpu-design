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
| `src/` | de bron van alle hoofdstukken (Markdown) |
| `labs/` | de code uit de hoofdstukken, per week of per project |
| `extract_labs.py` | haalt de code uit `src/` en draait alle tests |
| `build.sh` | bouwt de PDF's opnieuw |
| `.devcontainer/` | een werkomgeving met alle tools (Codespaces of VS Code) |

De PDF's staan niet in de repo maar bij de [Releases](../../releases): `00_syllabus.pdf`, `week01.pdf` t/m `week30.pdf` en `99_bijlagen.pdf`, ook als een zip. Begin met de syllabus: die beschrijft de werkwijze en welke software en onderdelen je nodig hebt. Wil je liever zelf bouwen, zie hieronder.

## Werkomgeving in een container

De map `.devcontainer/` beschrijft een kant-en-klare omgeving. Open de repo in GitHub Codespaces of in VS Code met de Dev Containers-extensie ("Reopen in Container"). Daarin staan Icarus Verilog, Python, Yosys en nextpnr (als YoWASP in `~/fpga-venv`, zoals week 23 beschrijft), pandoc en Chromium klaar, plus de VS Code-extensies voor Verilog en Surfer (golfvormen). Bij het aanmaken draait de container meteen `extract_labs.py`.

KiCad (week 25) en het programmeren van een echt FPGA-bord zitten er niet in: daarvoor heb je je eigen computer nodig.

## De code testen

Je hebt [Icarus Verilog](https://steveicarus.github.io/iverilog/) en Python 3 nodig.

```text
python3 extract_labs.py            # alle tests (74)
python3 extract_labs.py 04 cpu     # alleen labs/week04 en labs/cpu
```

## De PDF's bouwen

Bij elke release bouwt GitHub Actions de PDF's automatisch (`.github/workflows/release.yml`). Zelf bouwen kan ook.

Je hebt [pandoc](https://pandoc.org/) en Google Chrome of Chromium nodig.

```text
./build.sh                 # alle hoofdstukken
./build.sh src/week01.md   # een enkel hoofdstuk
CHROME=/pad/naar/chrome ./build.sh   # als Chrome ergens anders staat
```

## Stand van zaken

- De Verilog-ontwerpen worden gesimuleerd met Icarus Verilog en de Python-hulpmiddelen worden getest.
  Alle 74 tests in `extract_labs.py` slagen.
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
