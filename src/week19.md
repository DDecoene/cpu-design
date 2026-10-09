---
title: "Week 19 · Transport-triggered architecture (TTA)"
---

<p class="subtitle">Fase 5 · Geavanceerde architecturen · ongeveer 14 uur</p>

# Week 19: Transport-triggered architecture

## Wat je na deze week kunt

- uitleggen wat een TTA is en waarin ze zich fundamenteel van een gewone CPU onderscheidt
- de instructieset van T8 lezen en programma's schrijven die alleen uit `MOVE` bestaan
- begrijpen waarom bij een TTA de instructie tegelijk het besturingswoord is
- T8 in Verilog bouwen, met een assembler, en grondig testen
- de afweging tussen hardware-eenvoud en programmalengte benoemen

> **Dit is het hart van het project in deel 6.** In week 25 bouw je deze machine met 74HC-chips op een eigen printplaat. Neem de tijd om hem echt te begrijpen.

## 1. Het idee: draai de CPU binnenstebuiten

In een gewone CPU zeg je wat de machine moet doen: `ADD R1, R2, R3`. De processor zoekt zelf uit welke onderdelen daarvoor nodig zijn en verplaatst de gegevens. Die interne verplaatsingen zijn onzichtbaar voor de programmeur.

Een transport-triggered architecture doet het omgekeerd. De programmeur beschrijft alleen de verplaatsingen, en het rekenen is een bijwerking:

```text
 gewone CPU:                        TTA:
   ADD R3, R1, R2                     R1  -> OP         ; zet getal 1 klaar
                                      R2  -> ADD        ; schrijven naar ADD "triggert" de optelling
                                      RES -> R3         ; haal het resultaat op
```

Er is één enkele instructie: MOVE, `bron -> bestemming`. Alles wat de machine doet, volgt uit welke bronnen en bestemmingen er bestaan:

- Schrijf je naar een register, dan onthoudt dat register de waarde.
- Schrijf je naar `ADD`, dan telt de rekeneenheid zijn ene operand op bij de waarde die je schrijft en bewaart hij het resultaat.
- Schrijf je naar `PC`, dan is dat een sprong.

Een sprong is dus gewoon een move naar de programmateller. Een aanroep is een move van de programmateller naar een register. Er is geen opcode-decoder en er zijn geen aparte sprong-instructies: alles is verplaatsen.

TTA's zijn geen curiositeit. De TU Delft (het MOVE-project, jaren negentig) en de Tampere University (TCE, een open-sourcegereedschap voor TTA-processors) hebben ze bestudeerd, en sommige kleine, energiezuinige signaalprocessoren zijn zo ontworpen. In de hobbywereld bestaan er maar weinig werkende TTA-CPU's, dus dit is echt een bijzonder project.

## 2. Waarom is dit zo eenvoudig te bouwen?

Kijk naar W8 uit de vorige weken. De besturingseenheid kijkt naar de opcode en zet 13 signalen aan of uit. In T8 is de instructie zelf het besturingswoord:

```text
                         ┌──────── ROM (instructies) ◄── PC
                         │
              ┌──────────┴──────────────────────┐
              │ guard   bestemming   bron   constante │
              └───┬────────┬──────────┬───────┬──────┘
                  │        │          │       │
         vlaggen ─► mux     ▼          ▼       │
                  │  decoder          decoder   │
                  ▼  (wie schrijft?)  (wie levert?)
               "mag"    │          │            │
                  └────►(EN)       │            │
                         │         ▼            ▼
                         │   ┌─────────────────────────────┐
                         │   │  BUS (8 draden)              │◄── bronnen sturen
                         │   └──────┬──────────────────────┘     (tri-state)
                         ▼          ▼
                   klok van de bestemmingsregisters, data van de bus
```

Het bronveld wordt door een decoder omgezet in "wie mag de bus aansturen" (de output-enable van een tri-state register). Het bestemmingsveld wordt door een decoder omgezet in "wie neemt de waarde over" (de klokpuls van één register). En het guard-veld laat de move wel of niet doorgaan.

Dat is alles. Er is geen besturingseenheid, geen microcode en geen toestandsmachine. Het ROM zelf is de besturing. Het is de gedachte van week 8, "ROM als logica", tot het uiterste doorgevoerd. In hardware betekent dat heel weinig chips, en omdat alle toestand zichtbaar is, is debuggen op een breadboard een plezier.

## 3. De architectuur van T8

### Toestand

| Onderdeel | Beschrijving |
|-----------|-------------|
| R0 ... R3 | vier algemene registers van 8 bit |
| OP | operandregister van de rekeneenheid |
| RES | resultaatregister van de rekeneenheid |
| MAR | geheugenadresregister |
| PC | programmateller, 8 bit |
| Z, N, C | vlaggen, bijgewerkt door elke rekenbewerking |
| Programmageheugen | 256 × 24 bit |
| Datageheugen | 256 × 8 bit |
| `IN` en `OUT` | een ingangs- en een uitgangspoort van 8 bit |

### De instructie: 24 bit

```text
 bit:  23 22 21 | 20 19 18 17 16 | 15 14 13 | 12 11 10 9 8 | 7 ... 0
       guard      bestemming       (leeg)      bron           constante
```

De velden vallen precies op bytegrenzen (op de guard na): drie bytes uit het ROM, in hardware drie 8-bit EEPROM's.

### Bronnen (waar de waarde vandaan komt)

| Nr | Naam | Waarde |
|:--:|------|--------|
| 0 | `#constante` | de constante uit de instructie |
| 1-4 | `R0` ... `R3` | de registers |
| 5 | `RES` | het resultaat van de laatste rekenbewerking |
| 6 | `RESHR` | `RES` één plaats naar rechts geschoven (afgeleide bron) |
| 7 | `RESNOT` | `RES` omgekeerd (afgeleide bron) |
| 8 | `MEM` | `mem[MAR]` |
| 9 | `IN` | de ingangspoort |
| 10 | `PC2` | het adres van de instructie twee na deze, voor terugkeeradressen |
| 11 | `FLAGS` | `00000NCZ`: de vlaggen als getal |

### Bestemmingen (wat er met de waarde gebeurt)

| Nr | Naam | Effect |
|:--:|------|--------|
| 0 | `NOP` | niets |
| 1-4 | `R0` ... `R3` | schrijf het register |
| 5 | `OP` | zet de operand klaar (geen vlaggen) |
| 6 | `ADD` | RES = OP + waarde; C = carry |
| 7 | `SUB` | RES = OP − waarde; C = 1 als er niet geleend is |
| 16 | `ADC` | RES = OP + waarde + C |
| 8 | `AND` | RES = OP & waarde |
| 9 | `OR` | RES = OP \| waarde |
| 10 | `XOR` | RES = OP ^ waarde |
| 15 | `SHL` | RES = waarde << 1; C = uitgeschoven bit |
| 11 | `PC` | sprong |
| 12 | `MAR` | geheugenadres instellen |
| 13 | `MEM` | `mem[MAR]` = waarde |
| 14 | `OUT` | schrijf naar de uitgangspoort |
| 31 | `HALT` | stop |

Eén move is verboden: `MEM -> MEM`. Lezen en schrijven van hetzelfde geheugen in één cyclus is in hardware onmogelijk (week 25), dus de assembler weigert hem.

Elke bestemming van 6 tot en met 10, 15 en 16 heet een trigger: het schrijven zet de berekening in gang. Z en N volgen uit het resultaat en worden bij elke trigger bijgewerkt.

### Guards: voorwaardelijk uitvoeren

In plaats van aparte voorwaardelijke sprongen heeft elke move een guard. Staat er `?Z` voor, dan voert de machine de move alleen uit als de Z-vlag gezet is.

| Code | Guard | De move gaat door als |
|:----:|-------|-----------------------|
| 0 | (geen) | altijd |
| 1 | `?Z` | Z = 1 (resultaat was nul) |
| 2 | `?NZ` | Z = 0 |
| 3 | `?C` | C = 1 |
| 4 | `?NC` | C = 0 |
| 5 | `?N` | N = 1 (negatief) |
| 6 | `?NN` | N = 0 |
| 7 | (nooit) | nooit |

Een voorwaardelijke sprong is dus gewoon een guarded move naar `PC`: `?NZ #lus -> PC`. Maar elke andere move kan ook voorwaardelijk zijn, waardoor je korte `if`-stukjes zonder sprong kunt schrijven. Dat heet predicated execution en komt voor in veel DSP's en in ARM.

### Eén move per klokcyclus

Elke instructie duurt precies één klokcyclus: de instructie lezen, de bron op de bus zetten en de bestemming schrijven. De CPI is 1.

## 4. Programmeren met moves

### Een optelling

`R0 + R1 → R2` kost drie moves:

```text
R0  -> OP         ; operand klaarzetten
R1  -> ADD        ; trigger: RES = OP + R1
RES -> R2         ; resultaat ophalen
```

Het lijkt omslachtig, maar bedenk wat er niet is: de CPU heeft geen idee wat "optellen" is. Het is een bijwerking van een bestemming. Het mooie is dat tussenresultaten direct doorgestuurd kunnen worden: `RES -> OP` zet het resultaat van de ene optelling klaar voor de volgende, zonder register.

### Een constante gebruiken

`#5 -> ADD` triggert `OP + 5`. De constante komt rechtstreeks uit de instructie.

### Sprongen en aanroepen

```text
        #lus -> PC            ; onvoorwaardelijke sprong (macro: JMP lus)
        ?NZ #lus -> PC        ; voorwaardelijk

        PC2 -> R3             ; CALL: bewaar het terugkeeradres
        #sub -> PC            ;       en spring (macro: CALL sub)
        ...
sub:    ...
        R3 -> PC              ; RET
```

Waarom `PC2` en niet `PC`? Op het moment dat de eerste move van `CALL` loopt, wijst de PC naar die move zelf. De volgende instructie is de tweede move (de sprong). De instructie daarna is waar we naartoe terug willen. `PC2` is dus het huidige adres plus 2.

### De assembler-macro's

| Macro | Betekenis |
|-------|-----------|
| `JMP label` | `#label -> PC` |
| `CALL label` | `PC2 -> R3` en `#label -> PC` (R3 is het link register) |
| `RET` | `R3 -> PC` |
| `NOP` | `#0 -> NOP` |
| `HALT` | `#0 -> HALT` |

## 5. T8 in Verilog

Lees dit bestand en vergelijk het met het diagram in paragraaf 2: de bus is een grote `case` over het bronveld en de bestemming een `case` in het klokgestuurde blok.

```{.verilog include="tta/tta.v"}
```

Let op een paar dingen. Er is geen besturingseenheid: het decoderen van `src` en `dst` is alles. Alle toestand wordt in één klokflank bijgewerkt, en een move naar `PC` overschrijft de standaard `pc + 1`. Na `HALT` verandert er niets meer. Lege plaatsen in het ROM zijn zelf een `HALT`, zodat een verdwaalde sprong de machine laat stoppen.

## 6. De assembler

Een TTA-assembler is eenvoudiger dan die van W8. Elke regel is `bron -> bestemming`, met een optionele guard. De structuur is dezelfde (twee passen, symbolentabel). De macro's `JMP`, `CALL` en `RET` breiden zich uit tot één of twee moves.

```{.python include="tta/tta_asm.py"}
```

En de test, die de velden bit voor bit controleert:

```{.python include="tta/test_tta_asm.py"}
```

## 7. Voorbeeldprogramma's

### Som van 1 tot 10

```{.text include="tta/sum.tta"}
```

Het patroon is een aftellende lus. `#1 -> SUB` zet de Z-vlag, `RES -> R1` verandert de vlaggen niet, en `?NZ` kan dus nog de vlag van de aftrekking gebruiken.

### Fibonacci en vermenigvuldigen

```{.text include="tta/fib.tta"}
```

```{.text include="tta/mul.tta"}
```

### Subroutines

```{.text include="tta/call.tta"}
```

### Datageheugen: `MAR` en `MEM`

Het geheugen heeft een adresregister. Je zet het adres in `MAR` en leest of schrijft via `MEM`:

```{.text include="tta/array.tta"}
```

### 16-bit optellen met ADC

De carry blijft bewaard tot de volgende trigger, dus `ADC` kan hem gebruiken. Zo reken je met getallen van 16 bit op een 8-bit machine:

```{.text include="tta/add16.tta"}
```

### Guards en de ingangspoort

```{.text include="tta/guards.tta"}
```

```{.text include="tta/io.tta"}
```

## 8. Verificatie

### Acht programma's tegelijk

```{.verilog include="tta/tb_tta.v"}
```

### Willekeurige programma's tegen een referentiemodel

Net als bij W8 (week 16) doen we een willekeurige test. De testbench bevat een model dat de T8-specificatie uitvoert met gewone gehele getallen. De generator maakt 300 programma's van 40 tot 190 willekeurige moves, met willekeurige guards, alle bronnen en bestemmingen, en voorwaartse sprongen. Daarna vergelijken we registers, OP, RES, MAR, vlaggen, het hele datageheugen, de volledige uitvoerreeks en het aantal cycli.

```{.verilog include="tta/tb_tta_random.v"}
```

Draai het en kijk of de test zijn werk doet: verander bij `ADC` de `cf` in `0` in `tta.v` en je ziet fouten verschijnen. Die opzettelijke bug wordt in de 300 programma's meteen gevonden.

## 9. Tools

```{.verilog include="tta/tb_tta_run.v"}
```

```{.bash include="tta/run_tta.sh"}
```

```text
bash run_tta.sh sum.tta
bash run_tta.sh io.tta 41       # met invoerwaarde 41
```

## 10. W8 tegen T8: een eerlijke vergelijking

De som van 1 tot 10:

| | W8 (week 13-17) | T8 |
|--|-----------------|-----|
| Instructies | 6 | 11 moves |
| Programmagrootte | 12 bytes (16 bit per instructie) | 33 bytes (24 bit per move) |
| Cycli | 66 (2 per instructie) | 74 (1 per move) |
| Besturingseenheid | ja (microcode, 20 bit breed) | geen |
| Hardware om te bouwen | ALU + registerbestand + besturing + decoder | registers + ALU + bus + twee decoders |

T8 heeft meer instructies en grotere programma's. Wat het wint is een veel eenvoudiger machine, die sneller kan klokken (elke cyclus bestaat alleen uit "ROM lezen, bus, register laden"). En er is nog een troef: je kunt de machine uitbreiden zonder de ISA te veranderen. Een nieuwe rekeneenheid is gewoon een extra bestemming en bron. Een snelle vermenigvuldiger? Voeg `MUL` toe als trigger en `MULHI` als bron. Klaar.

Het echte voordeel zit in parallellisme. Met één bus is T8 sequentieel, maar met twee of drie bussen kan de machine twee of drie moves per cyclus doen. De moves zijn zichtbaar voor de programmeur (of compiler), die ze dus samen kan plannen. Daarom bestaan TTA's in de professionele DSP-wereld.

## 11. Lab

1. Draai alle tests: `tb_tta.v`, `tb_tta_random.v` en `test_tta_asm.py`.
2. Gebruik `python3 tta_asm.py sum.tta --list` en codeer drie moves met de hand na.
3. Schrijf `a = b + c` voor R0 = R1 + R2 in moves. Hoeveel cycli kost het?
4. Gebruik `run_tta.sh` om een programma te schrijven dat de ingangswaarde verdubbelt.
5. Meting: hoeveel cycli kost de optelling van twee 16-bit getallen (met ADC)? En hoeveel zou het kosten op een W8 (week 17, oefening 2)?

## 12. Oefeningen

1. Schrijf de moves voor `R0 = R1 − R2`.
2. Schrijf een programma dat het maximum van R0 en R1 in R0 zet, met één guarded move.
3. Schrijf de moves voor `R0 = −R0` (twee-complement).
4. Hoe schuif je R2 één plaats naar rechts? Hint: de afgeleide bron.
5. Hoeveel moves heeft `if (x == 0) y = 5` nodig, zonder sprong?
6. Vergelijk het aantal cycli en de codegrootte van de som van 1 tot 10 op W8, S8 (week 18) en T8.
7. Waarom heeft `CALL` twee moves nodig? Wat gebeurt er als de guard van de tweede move onwaar is?
8. Uitdaging: voeg een extra register `R4` toe als bron en bestemming. Welke velden en welke regels in `tta.v` pas je aan? Hoe groot is de uitbreiding van de ISA?
9. Uitdaging: ontwerp een tweede bus, dus twee moves per instructie (48 bit). Wat verandert er aan de hardware? Welke botsingen moet de programmeur vermijden (twee moves naar dezelfde bestemming, of lezen en schrijven van dezelfde trigger)?

## 13. Antwoorden

1. `R1 -> OP`, `R2 -> SUB`, `RES -> R0`.
2. `R0 -> OP`, `R1 -> SUB`, `?NC R1 -> R0`. De `SUB` berekent R0 − R1. C = 0 betekent dat er geleend is, dus R0 < R1, en dan wordt R0 vervangen door R1. De drie moves staan in de uitwerkingen hieronder.
3. `#0 -> OP`, `R0 -> SUB`, `RES -> R0`.
4. `R2 -> OP`, `#0 -> ADD` (RES = R2), `RESHR -> R2`. Dat zijn drie moves.
5. Bijvoorbeeld: `R0 -> OP`, `#0 -> ADD` (zet Z als R0 = 0), `?Z #5 -> R1`. Drie moves, zonder sprong.
6. Som van 1 tot 10: W8 heeft 12 bytes en 66 cycli, S8 21 bytes en 123 cycli, T8 33 bytes en 74 cycli. Geen enkele machine wint op alle punten.
7. Elke move heeft precies één bestemming, en `CALL` moet twee dingen doen: het terugkeeradres bewaren (bestemming `R3`) en springen (bestemming `PC`). Dat zijn dus twee moves. Is de guard van de tweede move onwaar, dan staat het terugkeeradres wel in `R3`, maar springt de machine niet. Dat is onschuldig, want `R3` wordt gewoon overschreven. Een guard op de eerste move zou gevaarlijk zijn: de sprong zou dan met een oud terugkeeradres doorgaan. Daarom zet de assembler de guard alleen op de sprong.
8. Voeg `R4` toe aan de lijst van bronnen en bestemmingen (de nummers zijn vrij), een extra `reg [7:0] r4`, een `case`-regel in de bus-mux en een in het schrijfblok, en laat de assembler-woordenboeken `DEST` en `SRC` het register kennen. De instructiebreedte verandert niet (we hebben 5 bits voor de bron en 5 voor de bestemming).
9. Elke bus krijgt eigen bron- en bestemmingsvelden. De hardware krijgt twee bussen en voor elke bestemming een keuze welke bus hem voedt. De programmeur moet voorkomen dat twee moves tegelijk naar dezelfde bestemming schrijven en dat een move een resultaat leest dat in dezelfde cyclus pas wordt geproduceerd.

De drie uitwerkingen (maximum, negatie en rechtsschuiven) staan in dit programma, en de testbench controleert ze:

```{.text include="tta/answers.tta"}
```

```{.verilog include="tta/tb_tta_answers.v"}
```

## 14. Zelftest

1. Wat is de enige instructie van een TTA?
2. Wat is een trigger?
3. Waarom heeft T8 geen besturingseenheid?
4. Hoe maak je een voorwaardelijke sprong?
5. Wat is `PC2`?

Antwoorden: (1) MOVE, van bron naar bestemming. (2) Een bestemming waarvan het schrijven een berekening in gang zet. (3) De instructie bevat zelf de velden die direct de bron- en bestemmingsdecoders aansturen. (4) Met een guarded move naar `PC`, bijvoorbeeld `?NZ #lus -> PC`. (5) Het adres van de instructie twee verder, gebruikt als terugkeeradres.

## 15. Verder lezen

- Henk Corporaal, *Microprocessor Architectures: from VLIW to TTA* (1997), het standaardwerk.
- De TTA-based Co-design Environment (TCE) van Tampere University: een open-sourceontwerpomgeving. Online te vinden.
- Zoek op "One Instruction Set Computer" en "MOVE machine" voor verwante ideeën, zoals de SUBLEQ-machine.

Volgende week: T8 voert elke instructie in één cyclus uit, maar W8 doet er twee over. Hoe maak je een CPU sneller door instructies te overlappen? Dat heet pipelining.
