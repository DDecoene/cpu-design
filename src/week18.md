---
title: "Week 18 · Stackmachines en de Forth-taal"
---

<p class="subtitle">Fase 5 · Geavanceerde architecturen · ongeveer 12 uur</p>

# Week 18: Stackmachines en Forth

## Wat je na deze week kunt

- uitleggen hoe een stackmachine rekent en waarom er geen registers in de instructies staan
- Forth lezen en schrijven, met stack-effect-notatie
- een stackmachine (S8) in Verilog bouwen met twee stapels
- een kleine Forth-compiler in Python lezen en gebruiken
- stackmachine en registermachine eerlijk vergelijken op codegrootte en snelheid

## 1. Rekenen zonder registers

Hoe reken je `(3 + 4) × 5` uit? In de gewone notatie heb je haakjes en voorrangsregels nodig. In postfix (omgekeerde Poolse notatie, RPN) schrijf je de operator achteraan: `3 4 + 5 ×`. Er zijn geen haakjes en geen voorrang nodig, en het algoritme is heel eenvoudig:

> Lees van links naar rechts. Is het een getal, zet het dan op een stapel. Is het een operator, haal dan de bovenste twee getallen eraf, reken en zet het resultaat terug.

```text
 3 4 + 5 *
 ─────────────────────────────
 3        → stapel: 3
 4        → stapel: 3 4
 +        → stapel: 7
 5        → stapel: 7 5
 *        → stapel: 35
```

Een CPU die dit doet is een stackmachine. Een instructie als `+` hoeft niet te zeggen welke registers: de operanden zijn altijd de bovenste twee van de stapel. Een instructie is daardoor vaak maar één byte.

Stackmachines zijn niet exotisch:

| Systeem | Wat |
|---------|-----|
| Java Virtual Machine | de bytecode is stackgebaseerd |
| WebAssembly | idem |
| CPython | de bytecode van Python |
| HP-rekenmachines | RPN, de klassieke toetsen |
| Forth-chips | Novix NC4000, Harris RTX2000 (gebruikt in de ruimtevaart), GA144 |

## 2. Forth

Charles Moore bedacht Forth in 1970 om telescopen te besturen met kleine computers. De taal werkt precies zoals een stackmachine.

### Woorden en de stapel

Een Forth-programma is een rij woorden, gescheiden door spaties. Elk woord is een getal (dat op de stapel wordt gezet) of een bewerking. Bij elk woord hoort een stack-effect, tussen haakjes:

```text
( voor -- na )
```

Zo dupliceert `DUP ( a -- a a )` het bovenste getal en telt `+ ( a b -- som )` twee getallen op.

### De woorden van S8

| Woord | Stack-effect | Betekenis |
|-------|-------------|-----------|
| `DUP` | `( a -- a a )` | kopieer de top |
| `DROP` | `( a -- )` | gooi de top weg |
| `SWAP` | `( a b -- b a )` | verwissel de bovenste twee |
| `OVER` | `( a b -- a b a )` | kopieer het tweede element naar boven |
| `ROT` | `( a b c -- b c a )` | draai de bovenste drie |
| `+` `-` | `( a b -- a±b )` | optellen, aftrekken |
| `AND` `OR` `XOR` | `( a b -- r )` | bitsgewijs |
| `INVERT` | `( a -- ~a )` | alle bits omdraaien |
| `2*` `2/` | `( a -- r )` | links of rechts schuiven |
| `=` | `( a b -- vlag )` | gelijk: 255 (waar), anders 0 |
| `<` | `( a b -- vlag )` | kleiner dan, zonder teken |
| `@` | `( adres -- waarde )` | lees uit het geheugen |
| `!` | `( waarde adres -- )` | schrijf naar het geheugen |
| `>R` | `( a -- )` | verplaats de top naar de terugkeerstapel |
| `R>` | `( -- a )` | haal terug van de terugkeerstapel |
| `R@` | `( -- a )` | kopieer de top van de terugkeerstapel |

### Eigen woorden definiëren

Met `:` en `;` maak je een nieuw woord. Dat werkt daarna net zo als de ingebouwde woorden:

```text
: kwadraat ( n -- n*n )  DUP mul ;
```

Je bouwt een programma op door steeds grotere woorden uit kleinere te maken. Het laatste woord is het hele programma.

### Beslissingen en lussen

```text
IF ... ELSE ... THEN        ( vlag -- )   als de vlag niet nul is
BEGIN ... UNTIL             ( vlag -- )   herhaal tot de vlag waar is
BEGIN ... WHILE ... REPEAT  ( vlag -- )   herhaal zolang de vlag waar is
```

### Twee stapels

Naast de datastapel heeft Forth een terugkeerstapel. Daar bewaart `CALL` het terugkeeradres. Je kunt hem ook gebruiken om een getal tijdelijk op te bergen (`>R` en `R>`). Dat is handig, maar je moet hem altijd weer leeg achterlaten voor de volgende `EXIT`.

## 3. De stackmachine S8

S8 is een CPU voor deze taal:

- Het programmageheugen is 256 bytes en het datageheugen ook 256 bytes (Harvard, net als W8).
- De datastapel is 16 bytes en de terugkeerstapel ook 16 bytes.
- Elke instructie is één byte. Sommige hebben een tweede byte als operand.
- Overloop van de stapels wordt niet gecontroleerd. Een slim ontwerp zou dat wel doen, maar hier is het een bewuste vereenvoudiging.

### Instructiecodering

| Byte | Betekenis |
|------|-----------|
| `1xxxxxxx` | literal: zet de 7-bit waarde `xxxxxxx` (0 tot 127) op de stapel |
| `00oooooo` | opcode van 6 bit, zie de tabel hieronder |

| Opcode | Woord | Opcode | Woord |
|:------:|-------|:------:|-------|
| 00 | NOP | 10 | `R>` |
| 01 | DUP | 11 | `R@` |
| 02 | DROP | 12 | LIT8 (de volgende byte is de waarde) |
| 03 | SWAP | 13 | JMP (de volgende byte is het doel) |
| 04 | OVER | 14 | JZ (spring naar de volgende byte als de top 0 is, en haal hem eraf) |
| 05 | `+` | 15 | CALL (zet het terugkeeradres op de terugkeerstapel en spring) |
| 06 | `-` | 16 | EXIT (spring naar het adres bovenop de terugkeerstapel) |
| 07 | AND | 17 | `=` |
| 08 | OR | 18 | `<` |
| 09 | XOR | 19 | ROT |
| 0A | INVERT | 3F | HALT |
| 0B | `2*` | | |
| 0C | `2/` | | |
| 0D | `@` | | |
| 0E | `!` | | |
| 0F | `>R` | | |

Een getal tot 127 kost dus één byte en een groter getal twee (LIT8 plus de waarde).

### De implementatie

```{.verilog include="stack/s8.v"}
```

Let op een paar dingen. De twee stapels zijn arrays (`ds` en `rs`) met een wijzer (`sp` en `rsp`) die naar de volgende vrije plaats wijst. De top is `ds[sp-1]`. Bij elke klokcyclus voert S8 één stap uit. Instructies met een operandbyte nemen twee cycli, waarbij de tweede de byte op `code[pc]` leest.

Alle werking zit in één groot `case`. Dat maakt een stackmachine zo klein: er zijn geen registeradressen om te decoderen, geen aparte operandvelden en geen opteller voor adressen. In een echte Forth-chip is dit allemaal hardware van een paar honderd poorten.

### Test van de opcodes

De eerste testbench zet bytes met de hand in het geheugen (zonder compiler) en controleert elke opcode:

```{.verilog include="stack/tb_s8_basic.v"}
```

## 4. Een Forth-compiler in Python

Bytes met de hand typen wil je niet. De compiler hieronder leest Forth-tekst en schrijft een `.hex`-bestand. Hij werkt in één pas met terugpatchen. Bij `IF` weet hij het sprongdoel nog niet, dus schrijft hij een lege plek en vult die in bij `THEN`. Een stapel van open structuren (`ctrl`) houdt bij welke plekken nog open staan.

```{.python include="stack/forth.py"}
```

Zo worden de besturingsstructuren gecompileerd:

| Forth | Gegenereerde code |
|-------|-------------------|
| `IF A ELSE B THEN` | `JZ else` / A / `JMP einde` / `else:` B / `einde:` |
| `BEGIN A UNTIL` | `begin:` A / `JZ begin` |
| `BEGIN A WHILE B REPEAT` | `begin:` A / `JZ einde` / B / `JMP begin` / `einde:` |

Alles wordt teruggebracht tot `JZ` en `JMP`, de enige twee sprongen van de machine.

Ook de compiler heeft een test, net als de assembler:

```{.python include="stack/test_forth.py"}
```

## 5. Programma's

### Rekenen

```{.text include="stack/arith.fs"}
```

### Faculteit: een recursief woord

S8 heeft geen vermenigvuldiging. We bouwen `mul` daarom zelf, met herhaald optellen en de terugkeerstapel als tijdelijke opslag. Daarna kan `fact` zichzelf aanroepen: de terugkeerstapel groeit bij elke aanroep met één adres.

```{.text include="stack/fact.fs"}
```

### Fibonacci en som

```{.text include="stack/fib.fs"}
```

```{.text include="stack/sum.fs"}
```

### Een variabele

`VARIABLE teller` reserveert een plek in het datageheugen. Het woord `teller` zet het adres op de stapel, en met `@` en `!` lees en schrijf je.

```{.text include="stack/counter.fs"}
```

### Alles testen op de hardware

Vijf stackmachines tegelijk, elk met een eigen programma:

```{.verilog include="stack/tb_forth.v"}
```

En een script om een eigen programma in één keer te compileren en te draaien:

```{.verilog include="stack/tb_s8_run.v"}
```

```{.bash include="stack/runfs.sh"}
```

```text
bash runfs.sh fact.fs
```

## 6. Stackmachine tegen registermachine

Is een stackmachine beter? Dit is wat we in onze eigen programma's meten:

| Programma | W8 (registermachine) | S8 (stackmachine) |
|-----------|---------------------|-------------------|
| Som 1 tot 10 | 12 bytes code, 66 cycli | 21 bytes code, 123 cycli |

Dat is tegen de verwachting in: de registermachine wint hier op beide punten. Hoe kan dat?

- Het S8-programma is een woord met een aanroep en heeft dus overhead: `CALL`, `EXIT`, een hoofdprogramma en veel `SWAP` en `OVER` om waarden op de juiste plek te krijgen.
- W8 bewaart de teller en de som in vaste registers, terwijl S8 ze over de stapel moet schuiven.
- Een slimmere stack-programmeur of compiler had S8 korter gekregen, maar de les blijft: stackmachines besparen bits per instructie, maar hebben meer instructies nodig.

De vergelijking in het algemeen:

| | Registermachine | Stackmachine |
|--|-----------------|--------------|
| Instructielengte | lang (registeradressen) | kort (geen adressen) |
| Aantal instructies | minder | meer (SWAP, OVER, ...) |
| Decoder | groter | zeer klein |
| Parallelle uitvoering | makkelijker | moeilijk (alles loopt via de stapeltop) |
| Compilers | complexe registerallocatie | eenvoudig te genereren |
| Gebruik | vrijwel alle CPU's | virtuele machines, zeer kleine chips |

Moderne snelle processors zijn registermachines, juist omdat parallellisme belangrijk is. Als virtuele machine (JVM, WebAssembly) blijft de stackmachine populair, omdat de code compact is en de compiler eenvoudig.

## 7. Lab

1. Draai `bash runfs.sh` op alle vijf de programma's. Noteer cycli, bytes en eindstapel.
2. Voer een programma met de hand uit op papier: teken de stapel na elk woord voor `3 7 max` (zie oefening 3).
3. Schrijf een Forth-programma dat de som van 1 tot 10 berekent zonder een definitie, alleen met `BEGIN ... UNTIL`. Meet de code in bytes en vergelijk met `sum.fs`.
4. Maak fouten (een onbekend woord, een vergeten `THEN`, 300 getallen achter elkaar). Zijn de meldingen duidelijk?
5. Voeg `NIP`, `2DUP` en `NEGATE` toe aan een eigen woordenlijst.

## 8. Oefeningen

1. Evalueer met de hand en teken de stapel na elk woord: `2 3 4 + mul`, `5 DUP mul` en `1 2 3 ROT`. (`mul` is het woord uit `fact.fs`.)
2. Wat doet `OVER OVER` ( a b -- ? ) en wat is een goede naam ervoor?
3. Schrijf de volgende woorden: `NIP ( a b -- b )`, `2DUP ( a b -- a b a b )`, `NEGATE ( a -- -a )`, `0= ( a -- vlag )` en `MAX ( a b -- max )`.
4. Hoe diep wordt de terugkeerstapel bij `5 fact`? Wat gebeurt er bij `8 fact`?
5. Hoeveel bytes kost het getal 100 in S8-code? En 200?
6. Voeg een opcode `*` (vermenigvuldigen) toe aan `s8.v` en `forth.py`. Hoe verandert dat de codegrootte en de snelheid van `fact`?
7. Waarom is het een probleem dat S8 de overloop van de stapels niet controleert? Hoe zou je dat in hardware oplossen?
8. Uitdaging: voeg `DO ... LOOP` toe aan de compiler. Hint: de lusteller staat op de terugkeerstapel.

## 9. Antwoorden

1. `2 3 4 + mul`: 2 geeft [2], 3 geeft [2 3], 4 geeft [2 3 4], `+` geeft [2 7] en `mul` geeft [14]. `5 DUP mul`: [5] wordt [5 5] en dan [25]. `1 2 3 ROT`: [1 2 3] wordt [2 3 1].
2. `OVER OVER ( a b -- a b a b )` heet in Forth `2DUP`.
3. De uitwerkingen staan hieronder, de testbench controleert ze.
4. Elke recursieve aanroep zet een terugkeeradres op de terugkeerstapel. Bij `5 fact` zijn dat 5 adressen, plus 1 voor de aanroep van `mul` en 1 voor de `>R` daarin: maximaal 7 van de 16 plaatsen. Bij `8 fact` is het maximum 10, dus ook dan loopt de stapel nog niet over. Maar 8! = 40320 past niet in 8 bits: het resultaat is 40320 mod 256 = 128.
5. 100 past in 7 bits, dus 1 byte. 200 niet (maximaal 127), dus 2 bytes (LIT8 plus 200).
6. Je voegt een opcode toe in het `case` van `s8.v` (`ds[t2] <= N * T; sp <= sp - 1`), een regel in `PRIMITIVES` en laat de compiler `*` kennen. De 8×8-vermenigvuldiging kost in hardware meer poorten, maar `fact` wordt veel korter (geen `mul`) en sneller.
7. Een programmafout kan de stapel laten overlopen, waarbij je terugkeeradressen of gegevens overschrijft. Dat is een klassieke bron van onverklaarbare fouten. In hardware voeg je een vergelijker toe tussen de wijzer en de grens (een overflow- en underflowvlag) die de CPU laat stoppen.
8. De aanpak: `DO` zet `limiet start` op de terugkeerstapel (`>R >R`), en `LOOP` verhoogt de teller, vergelijkt hem met de limiet en springt terug naar het begin. Je hebt ook `I ( -- teller )` nodig (dat is `R@`) en een extra sprong.

```{.text include="stack/answers.fs"}
```

```{.verilog include="stack/tb_answers_fs.v"}
```

## 10. Zelftest

1. Waarom hebben stackmachine-instructies geen registeradressen?
2. Wat betekent `( a b -- c )`?
3. Waar bewaart S8 het terugkeeradres bij `CALL`?
4. Hoe compileert `IF ... THEN` naar machinecode?
5. Wat is de afweging tussen stack- en registermachines?

Antwoorden: (1) De operanden zijn altijd de bovenste elementen van de stapel. (2) Het stack-effect: `a` en `b` worden van de stapel gehaald en `c` komt erop. (3) Op de terugkeerstapel. (4) Als `JZ` met een doeladres dat bij `THEN` wordt ingevuld. (5) Stackmachines hebben kortere instructies en een eenvoudigere decoder, maar meer instructies en minder mogelijkheden voor parallellisme.

## 11. Verder lezen

- Leo Brodie, *Starting Forth* (gratis online): de klassieke inleiding in de taal.
- Charles Moore's verhaal over de Forth-chips en de GA144 (144 kleine Forth-computers op één chip).
- Koopman, *Stack Computers: The New Wave* (online beschikbaar): de beste studie van stackarchitecturen.
- Jonesforth: een Forth-implementatie in assembly met uitleg in de broncode, nog steeds een meesterwerk.

Volgende week: de ongewoonste architectuur uit deze cursus, de transport-triggered architecture, waarin de enige instructie `MOVE` is.
