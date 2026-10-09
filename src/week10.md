---
title: "Week 10 · Testbenches, golfvormen en verificatie"
---

<p class="subtitle">Fase 3 · Verilog en de ALU · ongeveer 11 uur</p>

# Week 10: Testbenches, golfvormen en verificatie

## Wat je na deze week kunt

- een zelfcontrolerende testbench schrijven met klok, reset, stimulus en controle
- een referentiemodel (golden model) gebruiken om een ontwerp mee te vergelijken
- gerichte, willekeurige en exhaustieve tests uit elkaar houden en weten wanneer je welke inzet
- golfvormen (VCD) maken en bekijken
- een regressiescript draaien dat alle tests automatisch uitvoert

## 1. Waarom verificatie de helft van het vak is

In de chipindustrie gaat naar schatting meer dan de helft van de ontwikkeltijd naar verificatie, vaak meer dan naar het ontwerpen zelf. De reden is eenvoudig: een bug in een geproduceerde chip kun je niet repareren. De Pentium FDIV-bug uit 1994 kostte Intel bijna 475 miljoen dollar. Op een FPGA of in een simulatie is een bug goedkoop. In silicium en op een bestelde PCB is hij duur.

Een ontwerp dat in een demo werkt, werkt daarom nog niet. Verificatie beantwoordt de vraag hoe je het zeker weet.

## 2. Opbouw van een testbench

Elke testbench heeft dezelfde onderdelen:

```text
 ┌────────────────────── testbench ────────────────────────┐
 │  klok + reset         stimulus-generator                │
 │         │                    │                          │
 │         ▼                    ▼                          │
 │   ┌───────────────────────────────┐                     │
 │   │   DUT (device under test)     │──► uitgangen ──┐    │
 │   └───────────────────────────────┘                │    │
 │                                                     ▼    │
 │   referentiemodel ───► verwachte uitgangen ──► vergelijk │
 │                                                     │    │
 │                                          PASS / FAIL     │
 └─────────────────────────────────────────────────────────┘
```

Een testbench heeft geen poorten (`module tb;`), want hij is de buitenwereld. Hij dient alleen voor simulatie, dus je mag alles gebruiken.

### Nuttige simulatieopdrachten

| Opdracht | Doel |
|----------|------|
| `$display("x=%d", x)` | print één regel |
| `$monitor(...)` | print telkens als een variabele verandert |
| `$time` | de huidige simulatietijd |
| `$finish` | stop de simulatie |
| `$random` | pseudo-willekeurig 32-bit getal (bij elke run dezelfde reeks) |
| `$dumpfile`/`$dumpvars` | schrijf golfvormen weg |
| `#10` | wacht 10 tijdseenheden |
| `@(posedge clk)` | wacht op een stijgende klokflank |

### Wanneer stuur je aan en wanneer lees je?

Een bekende valkuil: stuur je een ingang precies op de klokflank aan, dan hangt het van de volgorde in de simulator af of het ontwerp de oude of de nieuwe waarde ziet. Een veilige gewoonte is ingangen aansturen op de dalende flank (`@(negedge clk)`) en uitgangen controleren kort na de stijgende flank (`@(posedge clk); #1`).

### Een timeout voorkomt een hangende simulatie

Geeft je ontwerp nooit een `done`-signaal, dan wacht je testbench eeuwig. Zet daarom altijd een waakhond neer:

```verilog
initial begin
  #1_000_000;
  $display("FAIL: timeout");
  $finish;
end
```

## 3. Soorten tests

| Soort | Wat | Sterk | Zwak |
|-------|-----|-------|------|
| Gericht (directed) | specifieke gevallen die jij bedenkt | begrijpelijk, snel, vindt verwachte fouten | je test alleen wat je bedacht |
| Willekeurig (random) | duizenden willekeurige invoeren tegen een referentiemodel | vindt onverwachte fouten | kan hoeken missen en heeft een model nodig |
| Exhaustief | alle mogelijke invoeren | bewijs voor kleine ontwerpen | onhaalbaar bij veel bits (2⁶⁴ is te veel) |

In de praktijk combineer je ze: gerichte tests voor de bekende hoeken (0, 255, overloop), willekeurige tests voor de rest en exhaustief waar het kan. Een 8-bit ALU heeft maar 65 536 invoerparen.

### Voorbeeld: een bug die gerichte tests missen

Hier staan twee 8-bit optellers. Eén heeft een hoogst onwaarschijnlijke fout: als `a` tussen 0xF0 en 0xFF ligt en `b` precies 1 is, wordt er niet opgeteld.

```{.verilog include="week10/adders.v"}
```

```{.verilog include="week10/tb_bughunt.v"}
```

Draai het en kijk hoeveel pogingen het kostte. Zulke bugs bestaan in echte CPU's: een onopvallend hoekgeval. Daarom zijn er fabrieken met duizenden testservers die dag en nacht random tests draaien.

## 4. Het referentiemodel: een voorbeeld met een FIFO

Een FIFO (first in, first out) is een wachtrij: wat er het eerst in gaat, komt er het eerst uit. CPU's gebruiken ze overal, bijvoorbeeld tussen een UART en de processor, tussen pipeline-fasen en tussen klokdomeinen. De implementatie:

```{.verilog include="week10/fifo.v"}
```

De testbench houdt zelf een model bij, in gewone variabelen, en vergelijkt elke cyclus. Dit is het patroon: de testbench simuleert wat er hoort te gebeuren, het ontwerp doet het in hardware en een vergelijker controleert of ze hetzelfde zeggen.

```{.verilog include="week10/tb_fifo.v"}
```

Let op de controle aan het eind: `keer_vol` en `keer_leeg` tellen hoe vaak de FIFO vol en leeg was. Dat is een kleine vorm van coverage, het bewijs dat je test de interessante randgevallen ook echt heeft bereikt. Een test die nooit een volle FIFO ziet, controleert niets over de logica voor een volle FIFO, ook al slaagt hij.

## 5. Golfvormen bekijken

Tekstuitvoer is niet genoeg bij tijdsproblemen. Een golfvorm laat alle signalen in de tijd zien.

```{.verilog include="week10/tb_wave.v"}
```

Na het draaien staat er een bestand `wave.vcd` (value change dump). Open het met GTKWave (`brew install --cask gtkwave`; als die cask op jouw Mac problemen geeft, probeer dan `brew install gtkwave` of een alternatief) of met Surfer (surfer-project.org). Surfer is een moderne viewer die als programma, als VS Code-extensie en zelfs in de browser draait, handig als je niets wilt installeren.

Sleep `q` en `clk` in het venster en zoom in. Je ziet nu precies wat je tot nu toe alleen als cijfers zag.

> **Leer lezen wat je ziet.** Bij elke bug begin je zo: zoek het eerste moment waarop een uitgang afwijkt van wat je verwacht en kijk wat er in de klokperiode ervoor met de ingangen en de interne toestand gebeurde. Meestal vind je de oorzaak binnen een paar minuten.

## 6. Een regressiescript

Elke keer dat je iets aanpast, wil je alle oude tests opnieuw draaien, en je wilt niet vergeten er een uit te voeren. Het script hieronder compileert en draait elke `tb_*.v` in de huidige map:

```{.bash include="week10/run_all.sh"}
```

Het script waarmee deze cursus zelf wordt gecontroleerd (`test_labs.py` in de hoofdmap) werkt op dezelfde manier. Maak er een gewoonte van: voordat je iets afrondt, draait `run_all.sh` zonder fouten.

## 7. Een testplan

Voor een groter ontwerp begin je met een testplan, een lijst van wat je wilt bewijzen.

| # | Wat | Hoe | Klaar |
|---|-----|-----|-------|
| 1 | Reset zet alles op 0 | gericht | ☐ |
| 2 | Optellen: gewone getallen | random tegen model | ☐ |
| 3 | Optellen: overloop (carry) | gericht, hoeken | ☐ |
| 4 | Alle 65 536 invoerparen | exhaustief | ☐ |
| 5 | Flags Z, N, C, V | random tegen model | ☐ |

Schrijf het plan voordat je gaat ontwerpen. Dan weet je al wat "klaar" betekent.

## 8. Lab

1. Draai `tb_bughunt`. Hoeveel pogingen kostte het om de bug te vinden? Verklein het aantal random pogingen tot 1000. Vindt hij de bug dan nog? Reken uit waarom (de kans per poging is 16/256 · 1/256 = 1/4096).
2. Draai `tb_fifo`. Breek daarna het ontwerp op een paar manieren: laat `full` pas bij `count == 9` melden, of laat een gelijktijdige push en pop niet toe. Kijk of de testbench de fout vindt.
3. Maak `wave.vcd`, open hem in een viewer en voeg de signalen `clk`, `rst_n` en `q` toe. Meet de periode van `q[3]`: is dat 16 klokperioden?
4. Maak `run_all.sh` en draai hem in `labs/week10`.
5. Zelf doen: schrijf een testbench voor de `counter` uit week 6, met een referentiemodel (een gewone integer). Test load, enable, reset en overloop.

## 9. Oefeningen

1. Waarom stuur je ingangen aan op de dalende flank?
2. Een 12-bit opteller heeft 24 ingangsbits (twee operanden). Hoeveel combinaties zijn dat? Als de simulator 1 miljoen combinaties per seconde doet, hoe lang duurt een exhaustieve test? En bij 32 bits per operand?
3. Een bug treedt op bij één specifieke combinatie van 16 ingangsbits. Hoeveel random pogingen heb je gemiddeld nodig om hem te vinden?
4. Wat is coverage en waarom is "100% geslaagd" niet genoeg?
5. Schrijf een `task` `check_eq(input [15:0] expected, input [15:0] actual, input [255:0] name)` die bij een verschil FAIL meldt en een teller ophoogt.
6. Waarom print de testbench in deze cursus aan het eind altijd PASS, en FAIL bij fouten? Wat heeft een script daaraan?
7. Uitdaging: breid `tb_fifo` uit met een controle dat `dout` ook klopt zolang er geen pop gebeurt. Verzin daarna een bug in de FIFO die jouw nieuwe controle wel vindt en de oude niet.

## 10. Antwoorden

1. Dan verandert het signaal midden in de klokperiode, ver van de stijgende flank waarop het ontwerp bemonstert. Zo voorkom je races tussen testbench en ontwerp.
2. 2²⁴ = 16 777 216 combinaties, dus 16,8 seconden. Bij 2⁶⁴ combinaties: 1,8·10¹⁹ / 10⁶ per seconde = 1,8·10¹³ seconden, ongeveer 585 000 jaar.
3. Gemiddeld 2¹⁶ = 65 536 pogingen (de kans is 1/65 536 per poging).
4. Coverage meet hoeveel van het ontwerp of van de interessante situaties je test daadwerkelijk heeft bereikt. Een test die nooit een volle FIFO ziet, slaagt altijd voor de logica van een volle FIFO, maar bewijst daar niets over.
5. `task check_eq(input [15:0] e, input [15:0] a, input [255:0] name); if (e !== a) begin fouten = fouten + 1; $display("FAIL %0s: %h != %h", name, e, a); end endtask`
6. Een script kan alleen op tekst letten. Met één vaste afspraak ("geen FAIL en minstens één PASS") kun je automatisch testen.
7. Een voorbeeldbug: `dout` springt per ongeluk naar `mem[wp]` als de FIFO leeg is. Controleer elke cyclus dat `dout` gelijk is aan het model zolang `empty = 0`.

## 11. Zelftest

1. Wat is een referentiemodel?
2. Waarom vindt willekeurig testen soms wat gerichte tests missen?
3. Wat is coverage?
4. Wat doet `$dumpvars`?
5. Waarom heeft een testbench een timeout nodig?

Antwoorden: (1) Een eenvoudig, vanzelfsprekend correct model dat de verwachte uitvoer berekent. (2) Gerichte gevallen bedenk je zelf, random vindt ook combinaties die je niet voorzag. (3) Een maat voor hoeveel interessante situaties je test heeft bereikt. (4) Het schrijft signalen weg om golfvormen te bekijken. (5) Anders blijft de simulatie hangen als het ontwerp nooit antwoordt.

## 12. Verder lezen

- Harris en Harris, 4.9 (testbenches).
- Zoek "Pentium FDIV bug" op. Het is een leerzaam verhaal over verificatie.
- Voor later: cocotb (testbenches in Python) en Verilator, waarmee je grote ontwerpen razendsnel simuleert.

Volgende week bouwen we de ALU, het hart van elke processor, met alles wat je nu weet: bouwblokken, Verilog en een goede test.
