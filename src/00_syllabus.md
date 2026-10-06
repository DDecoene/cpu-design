---
title: "CPU Design Cursus: van nul tot chipbouwer"
---

<p class="subtitle">Een cursus van 26 weken plus een vervolgproject van 4 weken, voor beginners zonder voorkennis · hobbyistenbudget</p>

# Welkom

Deze cursus duurt zes maanden en je hoeft er niets van elektronica voor te weten. Aan het eind heb je:

1. een eigen CPU ontworpen, gesimuleerd en getest in Verilog
2. die CPU laten draaien op een FPGA, een chip die je kunt herprogrammeren tot elke digitale schakeling
3. een tweede, ongewone CPU (een transport-triggered architecture) uit losse 74HC-chips op een eigen printplaat gebouwd
4. een eigen assembler en een Forth-systeem geschreven
5. een eerste ontwerp klaar voor echt silicium (via het open-source Tiny Tapeout-programma)

Daarna volgt een vervolgproject van vier weken (fase 7, week 27 tot 30): een kleine computer die bij het inschakelen een beeld van een SD-kaart leest en op een VGA-monitor zet. Dat project is niet verplicht en bouwt voort op de weken 22 tot 24.

> **Wat je mag verwachten.** Zes maanden maakt je geen CPU-architect met tien jaar ervaring bij Intel of Apple. Je leert wel de hele keten kennen, van transistor tot werkende processor, en je hebt alles zelf gebouwd. De rest groeit door oefening.

## Hoe de cursus werkt

- De cursus duurt 26 weken (fase 7 voegt er nog vier toe), met ongeveer 10 tot 12 uur per week (ruim 300 uur in totaal). Heb je minder tijd, rek het dan uit tot negen maanden. Dat is geen schande.
- Elke week is één PDF met doelen, theorie, uitgewerkte voorbeelden, een lab, oefeningen, antwoorden en een zelftest.
- Elk lab bevat werkende Verilog-code die met Icarus Verilog is getest. De bestanden staan ook in de map `labs/weekNN/`.
- De cursus leert door te bouwen. Lees de theorie en bouw dan meteen het lab. Snap je iets niet, bouw het dan eerst en lees daarna opnieuw.
- Typ de code over in plaats van te kopiëren. Je vingers leren sneller dan je ogen.

## De zeven fasen

| Fase | Weken | Thema | Resultaat |
|------|-------|-------|-----------|
| 1 | 1–4 | Elektronica en logica | Je begrijpt hoe een transistor een poort wordt en je bouwt een eerste opteller |
| 2 | 5–8 | Geheugen en tijd | Flipflops, registers, tellers, toestandsmachines en RAM |
| 3 | 9–12 | Verilog en de ALU | Je schrijft professionele RTL, testbenches en een complete ALU |
| 4 | 13–17 | Je eerste CPU | Instructieset, datapath, besturing, assembler en een 8-bit CPU die programma's draait |
| 5 | 18–22 | Geavanceerde architecturen | Stackmachine, Forth, TTA, pipelining, caches, interrupts en I/O |
| 6 | 23–26 | Van code naar chip | FPGA, timinganalyse, PCB's en een ontwerp voor echt silicium |
| 7 | 27–30 | De beeldcomputer | Een VGA-generator, een framebuffer, SPI en een SD-kaart: een computer die een beeld van een kaart op een scherm zet |

### Fase 7 en de snelle route

Fase 7 is een project met een eigen doel. Wil je vooral dat bouwen, dan hoef je niet alle 26 weken te doen. Deze weken heb je minstens nodig:

| Weken | Waarom |
|-------|--------|
| 1 tot en met 17 | logica, geheugen, Verilog en de 8-bit CPU met assembler |
| 22 | de geheugengemapte apparaten (UART, timer) waar de SPI-poort op lijkt |
| 23 en 24 | FPGA, synthese en de CPU die op een kleine FPGA past (W8F) |
| 27 tot en met 30 | de beeldcomputer |

De weken 18 tot en met 21 (stackmachine, TTA, pipelining, caches) heb je daarvoor niet nodig, en ook niet week 25 en 26.

Voor fase 7 gebruik je een iCE40 UP5K-bord met een klok van 12 MHz (bijvoorbeeld de iCEBreaker), een VGA-module en een microSD-module op de Pmod-aansluitingen. De keuze en de redenen staan in week 27, paragraaf 2: de open-sourcestroom werkt het best voor de iCE40, de W8F haalt daar ruim 12 MHz, het framebuffer past (20 van de 30 blok-RAM's) en de modules maken losse draden bij 25 MHz overbodig. Het is gesimuleerd en gesynthetiseerd, maar nooit op zo'n bord uitgeprobeerd.

## Weekoverzicht

| Wk | Titel |
|----|-------|
| 1 | Elektriciteit, het breadboard en je eerste schakeling |
| 2 | Transistoren en logische poorten |
| 3 | Booleaanse algebra en het vereenvoudigen van logica |
| 4 | Combinatorische bouwblokken: mux, decoder en opteller |
| 5 | Geheugen met poorten: latches en flipflops |
| 6 | Registers, tellers en de klok |
| 7 | Toestandsmachines (FSM's) |
| 8 | Geheugen (RAM/ROM) en de bus |
| 9 | Verilog: hardware beschrijven in plaats van programmeren |
| 10 | Testbenches, golfvormen en verificatie |
| 11 | De ALU ontwerpen |
| 12 | Getalrepresentatie, shifters en vermenigvuldigen |
| 13 | Instructieset-architectuur (ISA) ontwerpen |
| 14 | Het datapath |
| 15 | De besturingseenheid en microcode |
| 16 | Je eerste CPU in Verilog: het hele ding samenvoegen |
| 17 | Een assembler in Python en echte programma's |
| 18 | Stackmachines en de Forth-taal |
| 19 | Transport-triggered architecture (TTA) |
| 20 | Pipelining |
| 21 | Hazards, branch prediction en caches |
| 22 | Interrupts en I/O (UART, timers) |
| 23 | FPGA's: je CPU in echte hardware |
| 24 | Synthese, timing en optimalisatie |
| 25 | Je TTA bouwen uit 74HC-chips: ontwerp, simulatie en printplaat |
| 26 | Eindopdracht en de weg naar silicium |
| 27 | VGA: een beeld uit niets |
| 28 | Het framebuffer: pixels in geheugen |
| 29 | SPI: praten met de buitenwereld |
| 30 | De SD-kaart en de beeldcomputer |

## Wat je nodig hebt

Software (gratis):

| Tool | Waarvoor | Installatie |
|------|----------|-------------|
| Icarus Verilog | Verilog simuleren | `brew install icarus-verilog` (macOS) of via je pakketbeheerder |
| GTKWave | golfvormen bekijken | `brew install --cask gtkwave` |
| Python 3 | assembler en scripts | staat op macOS en de meeste Linux-systemen al klaar |
| Yosys + nextpnr | synthese voor FPGA (vanaf week 23) | `brew install yosys` en later de rest |
| KiCad | PCB-ontwerp (vanaf week 25) | `brew install --cask kicad` |
| ImageMagick (optioneel) | eigen foto's omzetten voor fase 7 | `brew install imagemagick` |

Hardware (ongeveer €200 tot €300 in totaal, gespreid over de hele cursus):

| Onderdeel | Richtprijs | Vanaf week |
|-----------|-----------|------------|
| Digitale multimeter | €15–25 | 1 |
| Breadboards (2×), jumperdraden, USB-voedingsmodule voor breadboard | €13 | 1 |
| LED's, weerstandenassortiment, drukknoppen, dip-switches | €15 | 1 |
| 74HC-chips (00, 04, 08, 32, 86, 138, 151, 161, 245, 273, 574, ...) | €20–30 | 2 |
| 28C256 EEPROM, 62256 SRAM, 555-timer, kristaloscillator | €10–15 | 6 |
| Arduino Nano (als EEPROM-programmer en voor experimenten) | €5–10 | 8 |
| USB-logic-analyzer (8 kanalen, Saleae-kloon) | €10 | 8 |
| FPGA-bord (iCE40, Tang Nano 9K of vergelijkbaar, met open-source toolchain) | €20–50 | 23 |
| Onderdelen voor het 74HC-bord (59 chips, voetjes, condensatoren, LED's) en de print | ca. €80–150 | 25 |
| Fase 7: iCE40 UP5K-bord met 12 MHz-klok (bijvoorbeeld iCEBreaker), VGA-Pmod (4 bit per kleur), microSD-Pmod | ca. €100 samen | 27 |
| Fase 7: een microSD-kaart van 4 GB of meer (SDHC of SDXC) die je mag wissen, en een VGA-monitor of een adapter die 640 x 480 aankan | €5–10 voor de kaart | 30 |

Prijzen zijn schattingen en kunnen verschillen. Controleer actuele prijzen en de compatibiliteit van het FPGA-bord met de open-source tools voordat je bestelt.

## De mappenstructuur

```
cpu-design-cursus/
├── pdf/              ← de PDF's: syllabus, 30 weken en de bijlagen
├── src/              ← de bronbestanden (Markdown)
├── labs/             ← de werkende code, per week of per project
│   ├── week01 ... week12     (fase 1 t/m 3)
│   ├── cpu/                  (weken 13-17: W8, assembler)
│   ├── stack/                (week 18: S8 en Forth)
│   ├── tta/                  (week 19: T8)
│   ├── cpu_pipe, memhier     (weken 20-21)
│   ├── cpu_irq, cpu_fpga     (weken 22-24: I/O, FPGA)
│   ├── beeld, beeld_fpga     (weken 27-30: beeldcomputer, SD-kaart)
│   ├── tta_hw                (week 25: 74HC-bord)
│   └── tt_t8                 (week 26: chip)
├── extract_labs.py   ← haalt alle code uit de PDF-bronnen en test alles
└── build.sh          ← bouwt de PDF's opnieuw
```

Elke PDF bevat de volledige code. `extract_labs.py` haalt die eruit en draait alle 74 tests.

## Leeradvies

1. Plan vaste uren. Twee avonden en één lange zaterdagochtend werken beter dan elke dag een beetje.
2. Houd een logboek. Schrijf elke week op wat je niet begreep. Na een maand is dat je beste leermateriaal.
3. Maak fouten en zoek ze zelf op. Debuggen is geen bijzaak van hardwareontwerp, het is het vak.
4. Sla geen labs over. Wie alleen leest, gelooft het te begrijpen. Wie bouwt, weet het.
5. Vraag hulp als je er niet uitkomt. Plak je code en je foutmelding op een forum, bijvoorbeeld r/FPGA, r/ECE of Stack Overflow.

Veel succes. We beginnen met de allereerste vraag: wat is elektriciteit eigenlijk?
