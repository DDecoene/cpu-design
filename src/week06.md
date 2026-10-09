---
title: "Week 6 · Registers, tellers en de klok"
---

<p class="subtitle">Fase 2 · Geheugen en tijd · ongeveer 11 uur</p>

# Week 6: Registers, tellers en de klok

## Wat je na deze week kunt

- een register met laadsignaal (enable) ontwerpen en uitleggen waarom je de klok niet uitzet
- shiftregisters en tellers bouwen, in Verilog en met 74HC-chips
- het verschil uitleggen tussen een asynchrone (ripple) en een synchrone teller
- een klok maken (555, kristal) en die met de hand stap voor stap laten lopen
- uitleggen waarom een asynchroon signaal eerst door twee flipflops moet (synchronizer)

## 1. Het register

Een register is een rij flipflops die samen één getal bewaren. Een 8-bit register bestaat uit acht D-flipflops met dezelfde klok. Bij elke klokflank neemt het alle acht bits tegelijk over.

Meestal willen we dat niet. Een register in een CPU moet zijn waarde vasthouden tot we zeggen: laad nu. Daarom voegen we een load-enable toe:

```text
          ┌───────┐
  d ──────┤1      │
          │  MUX  ├──── D ─┤FF├── q
  q ──┬───┤0      │             │
      │   └───▲───┘             │
      │       en                │
      └────────────────────────┘
```

Bij `en = 1` gaat `d` de flipflop in. Anders loopt zijn eigen uitgang `q` terug naar zijn ingang, en houdt hij vast. Alle flipflops krijgen dezelfde klok.

> **Een regel om aan te houden.** Zet de klok zelf nooit aan of uit met een poort (clock gating) om een register te laten vasthouden. Dat geeft glitches en timingproblemen. Gebruik altijd een enable-ingang. Moderne chips doen wel aan clock gating, maar met speciale, veilige cellen. Dat is iets voor later.

```{.verilog include="week06/regs.v"}
```

`{W{1'b0}}` betekent W keer een 0, hoe breed het register ook is.

### Echte chips

| Chip | Wat het is |
|------|-----------|
| 74HC273 | 8 flipflops met gemeenschappelijke clear, zonder enable |
| 74HC377 | 8 flipflops met load-enable |
| 74HC574 | 8 flipflops met tri-state uitgang (OE), de standaardbouwsteen voor een register aan een bus |

## 2. Het shiftregister

Een shiftregister schuift bij elke klokflank alle bits één plek op. Aan de ene kant komt een nieuw bit binnen, aan de andere kant valt het oudste eruit.

```text
 serieel in ─►[FF0]─►[FF1]─►[FF2]─►[FF3]─►  serieel uit
```

Je kunt het op een paar manieren gebruiken. Van serieel naar parallel: je stuurt 8 bits over één draad en haalt ze parallel weer op (de 74HC595, handig voor 8 LED's met 3 pinnen). Van parallel naar serieel: je leest 8 schakelaars over één draad in (de 74HC165). Ook vermenigvuldigen en delen met 2 gaat zo: één plek opschuiven naar links is ×2, naar rechts ÷2. Dat komt terug in week 12. En bit-serial CPU's laten de hele ALU op één bit tegelijk werken.

```{.verilog include="week06/shift.v"}
```

## 3. De teller

Een teller is een register dat bij elke klokflank met één ophoogt: `q <= q + 1`. Na 255 komt weer 0 (bij 8 bits).

Een teller is ook de programmateller (PC) van een CPU. Hij wijst naar de volgende instructie. In Ben Eaters computer is dat een 4-bit teller, in onze CPU wordt het 8 of 16 bits.

Een paar handige uitbreidingen: load zet een vaste waarde in de teller (en dat is een sprong in het programma), enable laat hem alleen tellen als `en = 1`, en reset brengt hem terug naar 0.

```{.verilog include="week06/counter.v"}
```

De volgorde in de `if` bepaalt de voorrang: load wint van en. In een CPU wil je dat ook zo, want een sprong gaat voor op doortellen.

### Asynchroon (ripple) en synchroon

Bij een ripple-teller is de uitgang van elke flipflop de klok van de volgende, net als bij de toggle-ketting van vorige week. Het is eenvoudig, maar de flipflops veranderen na elkaar, dus de uitgang zit even in een tussentoestand. Bij de overgang van 7 naar 8 (0111 naar 1000) zie je kort 0110, 0100 en 0000 voor 1000 verschijnt. Voor logica die de tellerwaarde leest, geeft dat glitches.

Bij een synchrone teller delen alle flipflops dezelfde klok, en extra logica berekent per bit of het mag toggelen (bit n toggelt als alle lagere bits 1 zijn). Alle bits veranderen tegelijk. De 74HC161 is zo'n teller: 4 bits, synchroon, met load, clear, twee enables (ENP en ENT) en een `RCO` (ripple carry out) waarmee je meerdere chips koppelt tot 8 of 16 bits.

In een CPU gebruik je altijd synchrone logica.

### Frequentiedeler

Bit n van een teller wisselt met frequentie f_klok / 2^(n+1). Zo maak je van een snelle klok een trage, bijvoorbeeld voor een LED die zichtbaar knippert of voor een tik van 1 Hz.

```{.verilog include="week06/lfsr.v"}
```

Een LFSR is een shiftregister met een XOR-terugkoppeling. Hij is heel klein en wordt gebruikt voor willekeurige getallen, CRC-controlesommen en het testen van chips.

## 4. De klok

Een klok is een periodiek blokgolfsignaal. De snelheid ervan is de hartslag van de computer. Hoe maak je er een?

### De 555-timer (astabiele modus)

Met twee weerstanden en een condensator maak je een oscillator:

```text
f ≈ 1,44 / ((R1 + 2·R2) · C)
```

Neem R1 = 1 kΩ, R2 = 100 kΩ en C = 1 µF: f ≈ 1,44 / (201 000 × 0,000001) ≈ 7,2 Hz. Dat is mooi om met LED's naar te kijken. Met C = 100 nF en R2 = 10 kΩ krijg je ongeveer 690 Hz.

### Kristaloscillator

Een kwartskristal trilt heel stabiel op zijn eigen frequentie. Een oscillatormodule (een blikje met 4 pinnen: VCC, GND, uitgang en soms een enable) geeft een nette blokgolf. Gangbare frequenties zijn 1 MHz, 4 MHz en 16 MHz. Voor je CPU's gebruik je er een. Met een kristal en een teller heb je alle lagere frequenties.

### Handmatige klok

Bij het debuggen wil je één klokpuls per druk op de knop. Gebruik het gedebouncete knopje uit week 5 en een schakelaar die kiest tussen de oscillator en de knop (een mux). Zo kijk je stap voor stap wat je computer doet. Ben Eater doet precies dit.

### Hoe snel mag de klok?

Uit week 5 weet je:

```text
T_klok  ≥  t_clk→Q  +  t_logica(max)  +  t_su
```

Bij een breadboard-CPU met 74HC-chips en lange jumperdraden is 1 tot 4 MHz realistisch. Draden op een breadboard hebben capaciteit en inductie, en die zitten niet in een simulatie. De echte schakeling is dus trager dan je theorie voorspelt.

## 5. Asynchrone ingangen en de synchronizer

Een signaal van buiten (een knop, een UART) is niet gesynchroniseerd met je klok. Het kan precies veranderen binnen het setup/hold-venster van een flipflop, en dan wordt die metastabiel (zie week 5).

De standaardoplossing is twee flipflops achter elkaar op dezelfde klok. De eerste mag metastabiel worden: hij heeft een hele klokperiode om te beslissen. De tweede ziet een stabiele waarde. Het is geen garantie, maar de kans op een fout wordt astronomisch klein.

```{.verilog include="week06/sync.v"}
```

Elke CPU die iets van buiten inleest, heeft hier een van nodig.

## 6. Tests

```{.verilog include="week06/tb_regs.v"}
```

```{.verilog include="week06/tb_sync.v"}
```

Draai ze:

```text
cd labs/week06
iverilog -g2012 -o a.vvp tb_regs.v regs.v shift.v counter.v lfsr.v && vvp a.vvp
iverilog -g2012 -o b.vvp tb_sync.v sync.v && vvp b.vvp
```

## 7. Lab op het breadboard

Je hebt nodig: een 555, weerstanden (1 kΩ, 100 kΩ, 10 kΩ), condensatoren (1 µF, 100 nF, 10 nF), een 74HC161, 8 LED's, een 74HC574 of 74HC595 en een gedebounced knopje.

1. 555-klok: bouw de astabiele schakeling (een schema vind je in het datablad). Laat een LED knipperen met ongeveer 7 Hz. Meet de frequentie en vergelijk die met de formule.
2. Teller: voed een 74HC161 met de 555 en verbind de vier uitgangen met LED's. Je ziet een binaire teller tellen.
3. Laden: zet vier schakelaars op de data-ingangen A tot D van de 74HC161 en een knop op LOAD'. Laad de waarde 12 en kijk hoe hij verder telt.
4. Register: zet een 74HC574 achter de teller en klok hem met de handmatige klok. Hij onthoudt wat hij zag.
5. Stap voor stap: vervang de 555 door je gedebouncete knop. Elke druk is nu één stap.

Vraag voor je logboek: meet de frequentie van uitgang QD op de 74HC161. Hoeveel keer lager is die dan de ingangsklok, en waarom?

## 8. Oefeningen

1. Een 16-bit teller heeft een klok van 1 MHz. Hoe lang duurt het voordat hij rondgaat? Met welke frequentie wisselt het hoogste bit?
2. Een klok van 4 MHz moet naar 1 Hz. Welke deler (een macht van twee) komt het dichtst bij, en wat is dan de werkelijke frequentie?
3. Teken de tabel van een 3-bit synchrone teller en schrijf per bit op onder welke voorwaarde hij toggelt.
4. Waarom is clock gating met een AND-poort een slecht idee voor beginners?
5. Een register laadt als `en = 1`. Wat gebeurt er als `en` vlak voor de klokflank verandert? Welke timingregel hoort hierbij?
6. Schrijf een Verilog-module `updown` die op- of aftelt afhankelijk van een ingang `dir`.
7. Uitdaging: ontwerp in Verilog een teller die bij 9 terugvalt naar 0 (een BCD-teller), met een uitgang `carry` die één klokperiode hoog is bij de overgang van 9 naar 0. Test hem.

## 9. Antwoorden

1. 2^16 = 65 536 klokpulsen bij 1 MHz is 65,5 ms. Het hoogste bit (bit 15) wisselt met f / 2^16 ≈ 15,26 Hz.
2. 4 000 000 / 2^22 = 0,95 Hz en 4 000 000 / 2^21 = 1,91 Hz. Het dichtst bij 1 Hz ligt 2^22 (4 194 304), dat geeft 0,954 Hz. Precies 1 Hz krijg je door te delen door 4 000 000, en dat is geen macht van twee. Gebruik daarvoor een teller die bij 3 999 999 terugvalt.
3. Bit 0 toggelt altijd. Bit 1 toggelt als bit 0 = 1. Bit 2 toggelt als bit 0 = 1 en bit 1 = 1.
4. De AND van klok en enable kan glitches geven als `en` verandert terwijl de klok hoog is: er ontstaat een valse extra klokflank. Het register laadt dan op een willekeurig moment of twee keer.
5. De enable moet net als elk ander D-signaal voldoen aan de setup- en holdregels van de flipflop. Verandert hij vlak voor de flank, dan kan de waarde ongedefinieerd (metastabiel) zijn.
6. `always @(posedge clk or negedge rst_n) if (!rst_n) q <= 0; else if (en) q <= dir ? q + 1 : q - 1;`
7. `if (q == 9) begin q <= 0; end else q <= q + 1;` en `assign carry = (q == 9) & en;`. Test de reeks 0 tot 9 en de overloop.

## 10. Zelftest

1. Waarom heeft een register een enable nodig en blokkeer je niet de klok?
2. Wat is het verschil tussen een ripple-teller en een synchrone teller?
3. Hoeveel D-flipflops heeft een 16-bit programmateller minimaal?
4. Waarvoor gebruik je een synchronizer?
5. Wat is een LFSR en waarvoor dient hij?

Antwoorden: (1) Een geblokkeerde klok geeft glitches, een enable houdt de klok schoon. (2) Bij ripple klokt elke flipflop op de vorige en veranderen de bits na elkaar. Bij synchroon delen alle flipflops dezelfde klok. (3) 16. (4) Om een signaal van buiten veilig aan de eigen klok te koppelen. (5) Een shiftregister met XOR-terugkoppeling dat pseudo-willekeurige reeksen maakt, voor ruis, CRC en testen.

## 11. Verder lezen

- Ben Eater: de video's over de program counter, het register en de klokmodule. Alles klopt nu met wat je geleerd hebt.
- Het datablad van de 74HC161: bekijk de timingtabel (t_su, t_h, f_max).
- Harris en Harris, 3.4 en 5.4 (registers, tellers en shiftregisters).

Volgende week: een teller met een paar slimme poorten erbij kan een hele reeks acties uitvoeren. Dat heet een toestandsmachine en het is het brein van elke CPU.
