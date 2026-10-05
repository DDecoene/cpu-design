---
title: "CPU Design: van nul tot chipbouwer"
---

<p class="subtitle">Een cursus van 26 weken voor beginners zonder voorkennis · hobbyistenbudget</p>

# Welkom

Deze cursus duurt zes maanden en je hoeft er niets van elektronica voor te weten. Aan het eind heb je:

1. een eigen CPU ontworpen, gesimuleerd en getest in Verilog
2. die CPU laten draaien op een FPGA, een chip die je kunt herprogrammeren tot elke digitale schakeling
3. een tweede, ongewone CPU (een transport-triggered architecture) uit losse 74HC-chips op een eigen printplaat gebouwd
4. een eigen assembler en een Forth-systeem geschreven
5. een eerste ontwerp klaar voor echt silicium (via het open-source Tiny Tapeout-programma)

> **Wat je mag verwachten.** Zes maanden maakt je geen CPU-architect met tien jaar ervaring bij Intel of Apple. Je leert wel de hele keten kennen, van transistor tot werkende processor, en je hebt alles zelf gebouwd. De rest groeit door oefening.

## Hoe de cursus werkt

- De cursus duurt 26 weken, met ongeveer 10 tot 12 uur per week (ruim 300 uur in totaal). Heb je minder tijd, rek het dan uit tot negen maanden. Dat is geen schande.
- Elke week is één PDF met doelen, theorie, uitgewerkte voorbeelden, een lab, oefeningen, antwoorden en een zelftest.
- Elk lab bevat werkende Verilog-code die met Icarus Verilog is getest. De bestanden staan ook in de map `labs/weekNN/`.
- De cursus leert door te bouwen. Lees de theorie en bouw dan meteen het lab. Snap je iets niet, bouw het dan eerst en lees daarna opnieuw.
- Typ de code over in plaats van te kopiëren. Je vingers leren sneller dan je ogen.

## De zes fasen

| Fase | Weken | Thema | Resultaat |
|------|-------|-------|-----------|
| 1 | 1–4 | Elektronica en logica | Je begrijpt hoe een transistor een poort wordt en je bouwt een eerste opteller |
| 2 | 5–8 | Geheugen en tijd | Flipflops, registers, tellers, toestandsmachines en RAM |
| 3 | 9–12 | Verilog en de ALU | Je schrijft professionele RTL, testbenches en een complete ALU |
| 4 | 13–17 | Je eerste CPU | Instructieset, datapath, besturing, assembler en een 8-bit CPU die programma's draait |
| 5 | 18–22 | Geavanceerde architecturen | Stackmachine, Forth, TTA, pipelining, caches, interrupts en I/O |
| 6 | 23–26 | Van code naar chip | FPGA, timinganalyse, PCB's en een ontwerp voor echt silicium |

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

## Wat je nodig hebt

Software (gratis):

| Tool | Waarvoor | Installatie |
|------|----------|-------------|
| Icarus Verilog | Verilog simuleren | `brew install icarus-verilog` (macOS) of via je pakketbeheerder |
| GTKWave | golfvormen bekijken | `brew install --cask gtkwave` |
| Python 3 | assembler en scripts | staat op macOS en de meeste Linux-systemen al klaar |
| Yosys + nextpnr | synthese voor FPGA (vanaf week 23) | `brew install yosys` en later de rest |
| KiCad | PCB-ontwerp (vanaf week 25) | `brew install --cask kicad` |

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

Prijzen zijn schattingen en kunnen verschillen. Controleer actuele prijzen en de compatibiliteit van het FPGA-bord met de open-source tools voordat je bestelt.

## De mappenstructuur

```
cpu-design/
├── pdf/              ← de PDF's: syllabus, 26 weken en de bijlagen
├── src/              ← de bronbestanden (Markdown)
├── labs/             ← de werkende code, per week of per project
│   ├── week01 ... week12     (fase 1 t/m 3)
│   ├── cpu/                  (weken 13-17: W8, assembler)
│   ├── stack/                (week 18: S8 en Forth)
│   ├── tta/                  (week 19: T8)
│   ├── cpu_pipe, memhier     (weken 20-21)
│   ├── cpu_irq, cpu_fpga     (weken 22-24: I/O, FPGA)
│   ├── tta_hw                (week 25: 74HC-bord)
│   └── tt_t8                 (week 26: chip)
├── extract_labs.py   ← haalt alle code uit de PDF-bronnen en test alles
└── build.sh          ← bouwt de PDF's opnieuw
```

Elke PDF bevat de volledige code. `extract_labs.py` haalt die eruit en draait alle 64 tests.

## Leeradvies

1. Plan vaste uren. Twee avonden en één lange zaterdagochtend werken beter dan elke dag een beetje.
2. Houd een logboek. Schrijf elke week op wat je niet begreep. Na een maand is dat je beste leermateriaal.
3. Maak fouten en zoek ze zelf op. Debuggen is geen bijzaak van hardwareontwerp, het is het vak.
4. Sla geen labs over. Wie alleen leest, gelooft het te begrijpen. Wie bouwt, weet het.
5. Vraag hulp als je er niet uitkomt. Plak je code en je foutmelding op een forum, bijvoorbeeld r/FPGA, r/ECE of Stack Overflow.

Veel succes. We beginnen met de allereerste vraag: wat is elektriciteit eigenlijk?
