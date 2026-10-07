# AGENTS.md: werknotities voor fase 8 (alleen op branch `fase8`)

> **Niet mergen naar `main`.** Dit bestand, `CLAUDE.md` en de map `fase8/` horen alleen bij de branch `fase8`.
> Haal ze weg (of verplaats wat bruikbaar is naar `src/`) voordat de branch naar `main` gaat. Zie "Afronden" onderaan.

Dit document legt vast wat er besproken en beslist is over fase 8, zodat het werk op een andere computer
(of door een andere agent) verder kan zonder de oorspronkelijke conversatie. Laatst bijgewerkt: 2026-10-07.

## Het idee

Fase 8 (week 31 tot 34) bouwt **de beeldcomputer van fase 7 opnieuw, maar met de T8** (de transport-triggered
architecture van week 19) in plaats van de W8F. Zelfde taak, zelfde randapparatuur (VGA, framebuffer, SPI, SD-kaart),
andere CPU. Dat geeft een eerlijke vergelijking tussen een registermachine en een TTA, en laat zien waar een TTA sterk in
is: de beeldcomputer verplaatst vooral bytes (SPI -> framebuffer), en verplaatsen is het enige wat een TTA doet.

## Beslissingen van de auteur

- **Week 19 blijft ongewijzigd.** `labs/tta/tta.v` en de hoofdstuktekst van week 19 worden niet aangeraakt.
  De T8 voor fase 8 is een **nieuwe variant ernaast**, zoals `cpu_v` en `cpu_b` naast `cpu_f` staan
  (afgeleid met een `<!-- COPYSED ... -->`-regel in de Markdown, of als nieuw bestand).
- **Het 74HC-spoor mag terugkomen**, als plan, op dezelfde manier als week 25: gesimuleerd, niet gebouwd.

## Wat er al gemeten is

`boot.asm` uit fase 7 (`labs/beeld/boot.asm`) is met de hand vertaald naar T8-assembly en gesimuleerd tegen de
bestaande `video_io`, `spi_io`, `spi_master` en `sd_model` van fase 7. Klok 12 MHz, zoals in `tb_beeld_top.v`.

| | W8F (fase 7) | T8, letterlijke vertaling |
|---|---|---|
| Programmagrootte | 101 instructies | 146 moves (van de 256) |
| Kaart opstarten | 2,5 ms | 2,4 ms |
| 19 blokken lezen | 49,3 ms | 42,6 ms |
| Resultaat | PASS | PASS: 9 600 bytes in het framebuffer, gelijk aan `sd.hex`; geen CRC-, volgorde- of initfout in het SD-model |

Conclusies:

- **Het programmageheugen (256 moves) is geen probleem.** De eerdere schatting (2 à 3 keer zo lang als W8) was te
  pessimistisch: de T8 schrijft constanten rechtstreeks naar een apparaat (`#1 -> MEM`), waar W8 er twee instructies voor nodig heeft.
  Een bredere PC is dus niet nodig. (Mocht dat later toch moeten: het instructieformaat heeft 3 lege bits,
  `guard | bestemming | leeg(3) | bron | constante`, en `labs/tt_t8/t8_core.v` heeft al een instelbare `PCW`.)
- **Geneste subroutines** (`cmd` roept `xfer` aan) lossen we op in software: R3 is het link-register van de
  `CALL`-macro, dus `cmd` bewaart R3 in het RAM (`#SAVE -> MAR`, `R3 -> MEM`) en keert terug met `MEM -> PC`.
- **De T8 is sneller**: één move per klok, tegenover 2 à 3 klokken per W8F-instructie (LD kost 3 cycli).
- **De hardwarewijziging is klein**: als `MAR` in `F0`-`FF` ligt, gaan `MEM`-lezen en -schrijven naar de apparaten
  in plaats van naar het RAM. Dezelfde geheugenkaart als de W8F: `F5` GPIO (LED's), `F8`-`FB` video, `FC`-`FE` SPI.

## Het prototype in `fase8/prototype/`

| Bestand | Wat |
|---|---|
| `boot_t8.tta` | de vertaalde bootcode (146 moves) |
| `tta_mm.v` | `labs/tta/tta.v` met memory-mapped I/O (`io_we`, `io_addr`, `io_wdata`, `io_rdata`); module `tta_mm` |
| `tb_boot_t8.v` | testbench: T8 + `video_io` + `spi_io` + `sd_model` + GPIO-register; vergelijkt het framebuffer met `sd.hex` |
| `run.sh` | `cd fase8/prototype && bash run.sh` (verwacht `PASS`) |

Dit is werkmateriaal, geen lesstof. Het staat bewust **niet** in `labs/`, want `labs/` wordt gegenereerd uit `src/`
(zie hieronder). Er is nog niets gesynthetiseerd (geen LUT's of fmax voor de T8-beeldcomputer).

## Het plan voor fase 8

| Week | Onderwerp | Inhoud |
|---|---|---|
| 31 | De T8 krijgt een buitenwereld | Nieuwe T8-variant met memory-mapped I/O op `F0`-`FF`. Subroutines in subroutines met het terugkeeradres in het RAM. Eerst GPIO en een klein testprogramma. Week 19 blijft gelijk. |
| 32 | De beeldcomputer op de T8 | De bootcode van het prototype als lesstof, met dezelfde top, virtuele monitor (`vga_mon`) en `sd_model` als fase 7. Synthese op de iCE40 UP5K en vergelijking met de W8F: LUT's, fmax, programmagrootte, laadtijd. |
| 33 | I/O als transportpoorten | `SPI` en `FB` als nieuwe bron/bestemming (vrij: bestemmingen 17-30, bronnen 12-31). Schrijven naar `SPI` start een overdracht, lezen geeft de ontvangen byte; schrijven naar `FB` zet de byte in het framebuffer en verhoogt het adres. Doel: de binnenste lus (nu 7 moves per byte plus 9 in `xfer`) veel korter maken en meten hoeveel het scheelt. De les: bij een TTA is een randapparaat toevoegen hetzelfde als een functionele eenheid toevoegen. |
| 34 | De T8-beeldcomputer uit 74HC-chips (plan) | Hoe de adresdecodering op het bord van week 25 (`labs/tta_hw/`) komt, en welke delen redelijk in losse chips kunnen: SPI met schuifregisters, VGA-timing met tellers, het framebuffer in SRAM. Gesimuleerd, niet gebouwd, net als week 25. |

Open punten:

- Mapnamen voor de labs (voorstel: `labs/tta_io/` voor week 31, `labs/beeld_t8/` voor 32-33, `labs/beeld_t8_hw/` voor 34).
- Of de T8-variant `tta.v` kopieert met `COPYSED` (zoals `cpu_v`/`cpu_b`) of `t8_core.v` uit `labs/tt_t8/` als basis neemt.
- Hoe de transportpoorten van week 33 samengaan met wachten op `SPI` (lezen terwijl de poort bezig is: wachten of de CPU laten stilstaan?).

## Hoe deze repo werkt (afspraken om te volgen)

- **De bron is `src/*.md`.** Elk codeblok dat begint met `// FILE: map/naam.v`, `# FILE: ...` of `; FILE: ...`
  wordt door `extract_labs.py` naar `labs/map/naam` geschreven. `<!-- COPY bron doel -->` en
  `<!-- COPYSED bron doel "oud"=>"nieuw" ... -->` maken afgeleide bestanden. Schrijf dus nooit alleen in `labs/`:
  wat niet uit `src/` komt, verdwijnt of loopt uit de pas.
- **Testen:** `python3 extract_labs.py` (alles) of `python3 extract_labs.py beeld tta` (enkele mappen). Een lab slaagt
  als er minstens één `PASS` en geen `FAIL` in de uitvoer staat. `.asm`, `.fs` en `.tta` worden automatisch geassembleerd.
- **Opbouw van een week** (zie `src/week27.md` als voorbeeld): front matter met `title`, een `<p class="subtitle">` met fase
  en tijd, `# Week NN: ...`, dan `## Wat je na deze week kunt`, genummerde secties met uitleg, `## Lab`, `## Oefeningen`,
  `## Antwoorden`, `## Zelftest`, `## Verder lezen`.
- **Taal en toon:** Nederlands, voor een beginner. Eerlijk over wat gesimuleerd is en wat niet (zie "Stand van zaken" in `README.md`).
- **Bij het toevoegen van fase 8** ook bijwerken: de tabel en de testtelling in `README.md`, de syllabus (`src/00_syllabus.md`),
  de bijlagen (`src/99_bijlagen.md`, o.a. de T8-instructieset als er poorten bijkomen) en eventueel `build.sh` en de release-workflow.
- **Commits:** geen vermelding van Claude/Anthropic/AI als co-auteur of in de tekst.
- **Werkomgeving:** de devcontainer (`.devcontainer/`) heeft Icarus Verilog, Python, Yosys/nextpnr (YoWASP in `~/fpga-venv`), pandoc en Chromium.

## Afronden (voor de merge naar `main`)

1. Alle lesstof staat in `src/week31.md` t/m `src/week34.md`, en `python3 extract_labs.py` slaagt.
2. Verwijder `AGENTS.md`, `CLAUDE.md` en `fase8/` op de branch (`git rm -r AGENTS.md CLAUDE.md fase8`).
3. Pas dan mergen.
