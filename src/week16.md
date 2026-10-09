---
title: "Week 16 · Je eerste CPU draait: verificatie en prestaties"
---

<p class="subtitle">Fase 4 · Je eerste CPU · ongeveer 12 uur</p>

# Week 16: Je eerste CPU draait

## Wat je na deze week kunt

- programma's op je CPU laten draaien en het resultaat controleren
- een instructietrace gebruiken om een programma te volgen
- een CPU verifiëren met een instructieset-simulator (referentiemodel) en willekeurige programma's
- de prestaties van je CPU meten en uitdrukken in CPI
- een bug in de CPU opsporen met je testbenches

## 1. Het moment van de waarheid

Je hebt alle onderdelen: ALU, datapath, besturing en geheugens. Samen vormen ze de CPU. Deze week maken we dat hard. We draaien er programma's op, controleren of de uitkomst klopt en bewijzen zo goed mogelijk dat hij altijd klopt.

Controleer dat je map `labs/cpu/` deze bestanden bevat: `alu.v`, `idecode.v`, `memories.v`, `datapath.v`, `control.v`, `cpu.v` en `asm_funcs.vh`.

## 2. Gerichte programma's

In week 13 hadden we een mini-assembler in Verilog-functies (`I_LDI`, `I_ALU`, ...). Daarmee zetten we vijf programma's in het instructiegeheugen:

1. Som van 1 tot 10: een lus met een teller. Verwacht R1 = 55 en precies 66 klokcycli (33 instructies × 2).
2. Fibonacci: de eerste 12 getallen in het datageheugen.
3. Subroutine: `CALL` en `JR R7`, twee keer aangeroepen.
4. Voorwaarden: een vergelijking met teken (`BLT`) en een zonder teken (`BCS`). Met R1 = 253 is dat zonder teken groter dan 5 en met teken kleiner dan 5. Beide takken moeten kloppen.
5. Geheugen en ALU: `ST` en `LD` met een offset, plus alle bitoperaties.

```{.verilog include="cpu/tb_programs.v"}
```

Draai:

```text
cd labs/cpu
iverilog -g2012 -o prog.vvp tb_programs.v alu.v idecode.v memories.v datapath.v control.v cpu.v
vvp prog.vvp
```

Je ziet PASS. Je CPU draait programma's.

## 3. Een trace: zien wat je CPU doet

Als iets niet werkt, wil je zien wat de CPU doet. Een trace schrijft bij elke uitgevoerde instructie een regel: waar de PC stond, welke instructie het was en de toestand van de registers en vlaggen. In Verilog lees je interne signalen rechtstreeks met een hiërarchische naam (`dut.dp.ir`, `dut.ctl.t`).

```{.verilog include="cpu/tb_trace.v"}
```

Een deel van de uitvoer:

```text
   3  pc=  2  ir=0250  ALU    R1=  0 R2=  4  ZNCV=0000
   4  pc=  3  ir=24ff  ADDI   R1=  4 R2=  4  ZNCV=0000
   5  pc=  4  ir=5402  Bcc    R1=  4 R2=  3  ZNCV=0010
   6  pc=  2  ir=0250  ALU    R1=  4 R2=  3  ZNCV=0010
```

Let op twee dingen. De registers die je ziet zijn de toestand voordat de effecten van die regel zijn verwerkt, en de volgende regel toont het resultaat (R1 is 4 na de `ALU`-regel). En na `ADDI R2, -1` staat C op 1. Reken maar na: 4 + 255 = 259, dat is meer dan 255, dus er is een carry-uit. Bij `ADDI` met `0xFF` betekent C = 1 dus dat er niet geleend is, net als bij aftrekken. Handig om te weten als je lussen schrijft.

## 4. De CPU verifiëren met een referentiemodel

Gerichte programma's bewijzen dat je CPU doet wat jij bedacht hebt. Maar fouten zitten waar je niet keek. Daarom doen we wat de chipindustrie ook doet (week 10): willekeurige tests tegen een referentiemodel.

### De instructieset-simulator (ISS)

Het referentiemodel is een eenvoudig programma dat de W8-ISA uitvoert zoals de specificatie het beschrijft: één instructie per stap, met gewone gehele getallen en zonder klokken, flipflops of multiplexers. Verschillen model en hardware, dan zit er een bug in de een of de ander. Het model rekent bewust anders dan de hardware (met `integer` en vergelijkingen in plaats van bit-trucs), zodat dezelfde denkfout niet in beide kan zitten.

### Willekeurige programma's

De testbench maakt 300 keer een willekeurig programma van 40 tot 200 instructies met alle soorten: ALU-instructies, `LDI`, `ADDI`, `LD`, `ST`, `CMP`, `CMPI`, voorwaardelijke sprongen en `CALL`. Sprongen gaan altijd vooruit (maximaal drie instructies), zodat elk programma gegarandeerd eindigt. Het geheugen begint met willekeurige inhoud. Na afloop vergelijken we de acht registers, de vier vlaggen, alle 256 bytes van het datageheugen en het aantal klokcycli (precies 2 per instructie).

```{.verilog include="cpu/tb_random.v"}
```

Draai:

```text
iverilog -g2012 -o rnd.vvp tb_random.v alu.v idecode.v memories.v datapath.v control.v cpu.v
vvp rnd.vvp
```

Je ziet `PASS: 300 willekeurige programma's ...`. Dat zijn tienduizenden uitgevoerde instructies zonder één afwijking.

### Test de test

Een test die nooit faalt, bewijst niets. Maak daarom met opzet een bug en kijk of de test hem vindt. Open `control.v` en verander de voorwaarde `LT` (`3'd5`) van `flag_n ^ flag_v` in `flag_n`. Draai `tb_random.v` opnieuw. Programma's wijken dan af, bijvoorbeeld zo:

```text
FAIL prog 253: vlaggen CPU 0100 model 0000
FAIL prog 289: 332 cycli, verwacht 336
```

Eén regel fout, gevonden door honderden programma's. Zet de fout daarna terug.

## 5. Prestaties

Hoe snel is je CPU? Er zijn drie kengetallen:

| Kengetal | Betekenis | Voor W8 |
|----------|-----------|---------|
| CPI | cycli per instructie | precies 2 |
| Klokfrequentie | bepaald door het langste pad (week 14) | enkele MHz op 74HC, tientallen tot honderden MHz op een FPGA |
| MIPS | miljoenen instructies per seconde = f / CPI | bij 4 MHz: 2 MIPS |

De uitvoeringstijd van een programma is:

```text
tijd = (aantal instructies) × CPI / klokfrequentie
```

Dit is de vergelijking van computerarchitectuur. Je kunt drie dingen verbeteren: het aantal instructies (een betere ISA of compiler), de CPI (pipelining, week 20) of de klokfrequentie (snellere logica). Het meeste werk in CPU-ontwerp gaat over het afwegen van deze drie.

Een voorbeeld uit onze test: de som van 1 tot 10 gebruikt 33 instructies × 2 = 66 cycli. Bij 4 MHz is dat 16,5 microseconde.

## 6. Debuggen: een werkwijze

Als een test faalt, doe je dit:

1. Reproduceer klein. Zoek het kleinste programma dat de fout geeft. Bij de willekeurige test druk je het programmanummer af en draai je alleen dat programma.
2. Gebruik de trace. Zoek de eerste instructie waarvan het effect afwijkt van wat het model zegt.
3. Kijk in de golfvorm. Zet `clk`, `t`, `ir`, de besturingssignalen en de registers erin en zoek wat in die cyclus anders is dan je verwachtte.
4. Zoek de oorzaak, niet het symptoom. Pas het testmodel niet aan tot het klopt. Het model is de specificatie.
5. Voeg een gerichte test toe voor de fout die je vond, zodat hij niet terugkomt.

## 7. Lab

1. Draai alle drie de testbenches (`tb_programs`, `tb_trace` en `tb_random`) en bewaar de uitvoer.
2. Maak de opzettelijke bug uit paragraaf 4 en laat hem falen. Probeer er nog twee: laat `BGE` hetzelfde doen als `BLT`, en laat `CALL` R6 in plaats van R7 beschrijven. Welke test vangt welke fout het eerst?
3. Schrijf met de `I_...`-functies een eigen programma dat de grootste waarde in een array van 8 bytes zoekt. Laat de testbench het controleren.
4. Maak een golfvorm (`$dumpfile`) van het somprogramma en zoek in een viewer het moment waarop `R1` verandert. Meet hoeveel klokperioden er tussen de vorige en de volgende verandering zitten.
5. Meet het aantal cycli van het Fibonacci-programma en vergelijk dat met een berekening op papier.

## 8. Oefeningen

1. Het somprogramma heeft 33 instructies. Reken zelf na welke instructies hoe vaak worden uitgevoerd.
2. Een programma voert 10 000 instructies uit op een W8 van 5 MHz. Hoe lang duurt dat?
3. Wat is de MIPS-waarde van W8 bij 8 MHz? Vergelijk met een Pentium uit 1995 (ongeveer 100 MIPS) en een moderne telefoon (tienduizenden MIPS).
4. De willekeurige test gebruikt alleen vooruitsprongen. Welke soort fouten kan hij daardoor missen, en hoe vul je dat aan?
5. Het referentiemodel is geschreven door dezelfde persoon als de hardware. Welk risico geeft dat, en hoe beperk je het?
6. Voeg aan `tb_random.v` een controle toe die telt hoe vaak elke voorwaarde (EQ, NE, CS, ...) tijdens de test is genomen. Waarom is dat nuttig?
7. Uitdaging: breid de willekeurige generator uit met achterwaartse sprongen, maar zorg dat het programma toch eindigt. Hint: gebruik een tellerregister dat andere instructies nooit veranderen.

## 9. Antwoorden

1. 2 × `LDI` = 2, de lus (`ADD`, `ADDI`, `BNE`) loopt 10 keer = 30 en `HALT` = 1. Samen 33.
2. 10 000 × 2 / 5 MHz = 20 000 / 5 000 000 = 4 ms.
3. 8 MHz / 2 = 4 MIPS. De Pentium was 25 keer sneller en een moderne telefoon duizenden keren.
4. Lussen: fouten die pas zichtbaar worden bij herhaald uitvoeren, zoals een vlag die van de vorige ronde blijft hangen. Vul het aan met gerichte lusprogramma's (zoals de som en Fibonacci) en een generator voor beperkte lussen.
5. Een misverstand van de ontwerper zit dan zowel in het model als in de hardware, en de test slaagt toch. Je beperkt dat door iemand anders het model te laten schrijven, de ISA-specificatie nogmaals heel precies te lezen of te vergelijken met een tweede, onafhankelijke implementatie (bijvoorbeeld een simulator in Python).
6. Zo zie je of de test alle voorwaarden echt heeft geraakt. Een voorwaarde die nooit genomen is, is niet getest, ook al slaagt de test (coverage, week 10).
7. Reserveer bijvoorbeeld R6 als lusteller en laat de generator R6 nooit als bestemming kiezen. Voeg lussen toe in de vorm `LDI R6,n; ... ADDI R6,-1; BNE terug`. Het model voert dezelfde lus uit en hij eindigt omdat R6 nul wordt.

## 10. Zelftest

1. Wat is een instructietrace?
2. Waarom vergelijken we de CPU met een referentiemodel?
3. Wat is CPI?
4. Waarom maak je met opzet een bug in je ontwerp?
5. Wat zegt `tijd = instructies × CPI / klokfrequentie`?

Antwoorden: (1) Een regel per uitgevoerde instructie met de toestand van de CPU. (2) Het model definieert wat goed is en vindt fouten die je zelf niet bedacht. (3) Het aantal klokcycli per instructie. (4) Om te controleren dat je test hem echt vindt. (5) Dat de uitvoeringstijd afhangt van het aantal instructies, het aantal cycli per instructie en de snelheid van de klok.

## 11. Verder lezen

- Patterson en Hennessy, *Computer Organization and Design*, hoofdstuk 1 (prestaties en de "iron law").
- Wikipedia: "Instruction set simulator". ISS'en worden gebruikt om CPU's te verifiëren en om software te schrijven voor hardware die nog niet bestaat.
- Ben Eater: de video's over het programmeren van zijn computer. Je herkent nu alle onderdelen.

---

> **Een mijlpaal.** Je hebt een eigen CPU ontworpen, gebouwd en grondig getest. Dat doen de meeste mensen die over processors praten nooit. De rest van de cursus bouwt hierop voort.

Volgende week: we hebben een CPU, maar nog geen gemakkelijke manier om hem te programmeren. We schrijven een assembler in Python.
