---
title: "Week 22 · Interrupts en I/O (UART, timer)"
---

<p class="subtitle">Fase 5 · Geavanceerde architecturen · ongeveer 13 uur</p>

# Week 22: Interrupts en I/O

## Wat je na deze week kunt

- uitleggen hoe een CPU met de buitenwereld praat: memory-mapped I/O, polling en interrupts
- een UART (seriële poort) ontwerpen: zender en ontvanger, met baudrate-deler en synchronizer
- een timer bouwen en gebruiken
- een CPU uitbreiden met interrupts: aanvraag, vectorsprong, toestand bewaren en `RETI`
- een interruptroutine schrijven en bewijzen dat ze het hoofdprogramma niet verstoort

## 1. Een CPU met een buitenwereld

Een processor die alleen rekent, is nutteloos. Hij moet toetsen kunnen lezen, lampjes laten branden, tekst versturen en weten hoe laat het is. Daarvoor gebruik je apparaten (peripherals) die de CPU als geheugenplaatsen ziet.

### Memory-mapped I/O

Sommige adressen van het datageheugen zijn geen RAM maar de registers van een apparaat. Lezen en schrijven met `LD` en `ST` gaat dan naar het apparaat. Dat heet memory-mapped I/O. Het is elegant: je hebt geen aparte I/O-instructies nodig, en alles wat je met geheugen kunt doen, kun je ook met apparaten doen.

(De andere aanpak is port-mapped I/O, met speciale instructies `IN` en `OUT`, zoals bij x86 en de Z80.)

### De geheugenkaart van W8I

| Adres | Naam | Gedrag |
|:-----:|------|--------|
| `0x00`-`0xEF` | RAM | gewoon geheugen (240 bytes) |
| `0xF0` | UART data | schrijven: verzend een byte. Lezen: de ontvangen byte (wist de vlag "ontvangen") |
| `0xF1` | UART status | bit 0: zender bezig. Bit 1: byte ontvangen |
| `0xF2` | Timer herlaadwaarde | om de N klokcycli een aanvraag; 0 = uit |
| `0xF3` | Timer status | lezen: bit 0 = aanvraag. Schrijven: de aanvraag wissen |
| `0xF5` | GPIO uit | bijvoorbeeld LED's |
| `0xF6` | GPIO in | bijvoorbeeld schakelaars |
| `0xF7` | Interrupt-aan | bit 0: timer, bit 1: UART ontvangen |

## 2. De UART

Een UART (universal asynchronous receiver/transmitter) stuurt bytes over één draad, bit na bit, zonder gedeelde klok. Zender en ontvanger spreken alleen een baudrate af (bits per seconde).

### Het frame

```text
 lijn:  ‾‾‾‾‾‾‾\____/‾‾‾\____/‾‾‾‾\_/‾‾‾\_____/‾‾‾‾‾‾‾‾‾‾
 rust   │start│ d0 │ d1 │ d2 │ ... │ d7 │stop│ rust
        0     LSB                    MSB   1
```

De lijn is in rust hoog (1). Een byte begint met een startbit (0): de daling vertelt de ontvanger dat er iets aankomt. Daarna volgen 8 databits, de laagste eerst. Een stopbit (1) sluit af, en de lijn blijft hoog tot het volgende startbit.

Elke bit duurt `DIV` klokcycli van de CPU (het "clocks per bit"-getal).

### Welk getal voor DIV?

```text
 DIV = klokfrequentie / baudrate
```

Voor 9600 baud op een klok van 4 MHz: 4 000 000 / 9600 = 416,67, dus kies je 417. De fout is 0,08 %. Een UART verdraagt ongeveer 3 tot 5 % fout, omdat de ontvanger bij de laatste bit nog in het midden moet kunnen kijken.

### De zender

De zender is een schuifregister van 10 bits (`1`, 8 databits, `0`) dat om de `DIV` cycli één plek opschuift. Tijdens het verzenden is de zender bezig (`tx_busy`).

### De ontvanger

De ontvanger is lastiger, want hij kent de timing van de zender niet:

1. Hij wacht op een daling van de lijn. De ingang gaat eerst door de synchronizer (twee flipflops, week 6), want het signaal komt van buiten en is niet gesynchroniseerd met onze klok.
2. Hij wacht een halve bitperiode, zodat hij in het midden van het startbit staat. Is de lijn daar nog 0, dan is het een echte start.
3. Daarna samplet hij om de `DIV` cycli, steeds in het midden van een bit, waar de lijn het stabielst is.
4. Na 8 databits controleert hij het stopbit. Klopt dat, dan staat de byte klaar en zet hij de vlag "ontvangen".

## 3. De timer

Een teller telt klokcycli. Bij een instelbare waarde zet hij een aanvraagvlag (`t_pend`) en begint hij opnieuw. De CPU moet de aanvraag wissen (schrijven naar `0xF3`), anders blijft hij staan.

Timers geven de CPU een gevoel voor tijd: een lampje laten knipperen, een time-out of een vaste meetfrequentie.

De timer heeft een prescaler: de parameter `TDIV` bepaalt hoeveel klokcycli één tik duurt. In de simulatie is `TDIV = 1` (een tik per cyclus). Op een echte FPGA van 27 MHz kies je `TDIV = 27000`, zodat één tik 1 ms is en een herlaadwaarde van 250 een periode van 250 ms geeft. Een 8-bit teller zonder prescaler zou bij 27 MHz maar 9 microseconden kunnen tellen, veel te snel om een LED te zien knipperen.

## 4. Polling of interrupt?

Hoe weet de CPU dat er een byte is ontvangen?

Bij polling kijkt de CPU zelf steeds in het statusregister. Dat is eenvoudig, maar het wachten neemt hem volledig in beslag. Bij een interrupt meldt het apparaat zich zelf, en laat de CPU zijn werk even liggen om het af te handelen. Intussen kan de CPU nuttig werk doen.

| | Polling | Interrupt |
|--|---------|-----------|
| Hardware | geen | extra logica |
| Reactietijd | afhankelijk van de lus | kort en voorspelbaar |
| CPU-tijd | verspild aan wachten | alleen bij gebeurtenissen |
| Complexiteit | eenvoudig | subtiel |

## 5. Hoe werkt een interrupt?

Het idee in vier stappen:

1. Een apparaat zet de aanvraaglijn (`irq`) hoog.
2. Zijn interrupts toegestaan (`IE` = 1), dan neemt de CPU tussen twee instructies de aanvraag aan. Hij bewaart het huidige adres (de PC) in het register `EPC` en de vlaggen in schaduwregisters. Hij zet `IE` uit (geen nieuwe interrupts tijdens de afhandeling) en springt naar een vast adres, de vector (hier `0x02`).
3. Op dat adres staat de interruptroutine (ISR). Die handelt het apparaat af en wist de aanvraag.
4. De instructie `RETI` zet de PC terug op `EPC`, herstelt de vlaggen en zet `IE` weer aan. Het hoofdprogramma gaat verder alsof er niets gebeurd is.

```text
 hoofdprogramma:  ... ADD ... ADDI ... [ BNE ]  ...
                                 │ irq!
                                 ▼
                       EPC = adres van BNE, vlaggen bewaard, naar 0x02
                       ISR:  registers bewaren ... werk doen ... registers terug
                       RETI → PC = EPC, vlaggen terug
                                 │
                                 ▼
                        [ BNE ] ...  (ziet dezelfde vlaggen als voor de interrupt)
```

### Wat de hardware bewaart en wat de software

De interrupt kan op elk moment tussen twee instructies komen. Het hoofdprogramma weet er niet van, dus alles wat de ISR verandert, moet hersteld worden.

De hardware bewaart de PC (in `EPC`) en de vlaggen Z, N, C en V. Dat kan niet in software: je kunt de vlaggen niet lezen en je moet nog steeds weten waar je was. De software (de ISR) bewaart de registers die ze gebruikt in het geheugen. In W8 zit daar een haak aan: om iets in het geheugen te zetten heb je een register met een adres nodig. Daarom reserveren we R6 voor de interruptroutine. Het hoofdprogramma mag R6 nooit gebruiken. De ISR laadt er een adres in, bewaart de andere registers die ze nodig heeft en gebruikt R6 vrij.

Zulke conventies zie je overal. Echte CPU's lossen het soms op met gebankte registers (een aparte set voor de ISR) of met een stapel.

### Latentie

De CPU neemt een aanvraag alleen aan het begin van een instructie aan (stap T0). In het slechtste geval moet hij dus eerst de lopende instructie afmaken (2 cycli), en het aannemen zelf kost 2 cycli (een tussenstap met een NOP). De eerste ISR-instructie wordt dus uiterlijk 4 cycli na de aanvraag opgehaald. Dat is de interruptlatentie.

## 6. De hardware

De uitbreiding bestaat uit vier delen:

1. een datapath met `EPC`, `IE` en schaduwvlaggen
2. een besturing die tussen instructies de aanvraag controleert en drie nieuwe instructies (`RETI`, `EI`, `DI`) kent
3. een apparatenblok (`mmio.v`) met RAM, UART, timer en GPIO
4. een nieuwe top die ze verbindt

De ALU, de decoder en de geheugens blijven hetzelfde. Kopieer ze naar `labs/cpu_irq/`.


De nieuwe instructies zitten al sinds week 17 in `asm.py`: `RETI` (opcode `B`), `EI` (`C`) en `DI` (`D`).

### Datapath

Vergelijk dit met `datapath.v` van week 14. Nieuw zijn `epc`, `ie`, de schaduwvlaggen en de tak `int_enter`.

```{.verilog include="cpu_irq/datapath_i.v"}
```

Let op de volgorde in het `always`-blok: bij `int_enter` gebeurt alleen het interruptwerk. De instructie die tegelijk uit het geheugen komt, wordt weggegooid (het IR krijgt een `NOP`), net als bij de flush in week 20.

### Besturing

```{.verilog include="cpu_irq/control_i.v"}
```

Wat is er veranderd?

- Het controlewoord is 24 bit breed (vier nieuwe signalen).
- Tijdens T0 kijkt de besturing naar `irq && ie`. Is dat waar, dan komt er geen ophaalstap maar `F_INT` (de interrupt).
- Er zijn drie nieuwe regels in het controlegeheugen: `RETI`, `EI` en `DI`.
- `mem_rd` is nieuw. Een apparaat als de UART-ontvanger moet weten dat zijn register gelezen wordt (om "ontvangen" te wissen), en voor een leesactie bestond tot nu toe geen signaal.

### De apparaten

```{.verilog include="cpu_irq/mmio.v"}
```

Dit stuk bevat de hele UART, de timer en de GPIO. Alles wat we wisten over registers, tellers, schuifregisters en synchronizers komt hier in één module samen.

### De CPU

```{.verilog include="cpu_irq/cpu_i.v"}
```

## 7. Programma's

### Een timer-interrupt tijdens een berekening

De hoofdlus telt 1 + 2 + ... + 200 (modulo 256 is dat 132). Intussen komt er elke 40 cycli een timer-interrupt die een teller in het geheugen ophoogt. Let op twee dingen. De routine bewaart R0 en gebruikt R6 als vrij register. En aan het eind verpest ze met opzet de vlaggen (`CMP R0, R0` zet Z). Zou de hardware de vlaggen niet herstellen, dan sprong de `BNE` in de hoofdlus soms niet en zou de uitkomst niet kloppen.

```{.text include="cpu_irq/timer.asm"}
```

De referentie is dezelfde berekening zonder timer:

```{.text include="cpu_irq/timer_uit.asm"}
```

### UART met polling

De testbench sluit de zender aan op de ontvanger. Het programma verzendt "HI" en leest het terug.

```{.text include="cpu_irq/uart.asm"}
```

### UART met interrupt

De ontvanger vraagt een interrupt aan als er een byte binnen is. De routine zet de byte in een buffer. De hoofdlus wacht tot er drie bytes zijn.

```{.text include="cpu_irq/uart_irq.asm"}
```

### Een knipperlicht

De hoofdlus doet niets (`B slaap`). Al het werk gebeurt in de interruptroutine: bit 0 van de GPIO-uitgang omdraaien.

```{.text include="cpu_irq/blink.asm"}
```

## 8. Verificatie

Drie scenario's tegelijk, elk op een eigen CPU:

- A. De timer-rekenlus tegen de referentie zonder timer. Beide moeten 132 opleveren, R0 moet hersteld zijn en de routine moet echt gedraaid hebben (in de testrun 74 keer).
- B. UART-polling. De testbench bevat een onafhankelijke UART-ontvanger die de lijn afluistert en de frames decodeert. Beide kanten (de ontvanger van de CPU en die van de testbench) moeten "H" en "I" zien.
- C. UART-interrupt. De testbench zendt drie bytes met onregelmatige tussenpozen en de CPU zet ze in een buffer.

```{.verilog include="cpu_irq/tb_irq.v"}
```

En het knipperlicht:

```{.verilog include="cpu_irq/tb_blink.v"}
```

### De test testen

Verwijder de herstelregel voor de vlaggen in `datapath_i.v` (`fz <= sfz; ...` bij `reti`). Draai `tb_irq.v` opnieuw. Je ziet:

```text
FAIL A: R1 = 36 / 132
FAIL A: R3
```

De berekening is verpest, omdat een interrupt tussen `ADDI` en `BNE` de Z-vlag omdraaide. Een eerste versie van deze test ving dit niet op: de routine liet de Z-vlag toevallig in een toestand die de hoofdlus niet stoorde. Pas toen de routine de vlaggen met opzet verpestte, werd de fout zichtbaar. Dat is een algemene les over het testen van timingafhankelijke fouten: een test moet het probleem actief uitlokken, anders slaagt hij door geluk.

## 9. Lab

1. Draai `tb_irq.v` en `tb_blink.v`.
2. Haal de `CMP R0, R0` uit `timer.asm`, assembleer opnieuw en draai de test met de gesaboteerde hardware (zonder herstel van de vlaggen). Slaagt hij nu wel? Wat leert dit je?
3. Open een golfvorm van `tb_blink.v` en meet de tijd tussen twee wissels. Hoe verhoudt die zich tot de herlaadwaarde 100?
4. Verander in `blink.asm` de herlaadwaarde en bereken de verwachte knipperfrequentie bij een klok van 1 MHz.
5. Laat de ISR in `uart_irq.asm` elke ontvangen byte ook meteen terugsturen (echo).

## 10. Oefeningen

1. Bereken `DIV` voor 115 200 baud op een klok van 50 MHz. Wat is de relatieve fout?
2. Hoe lang duurt het verzenden van één byte (10 bits) op 9600 baud? En hoeveel bytes per seconde is dat maximaal?
3. De timer-ISR in `timer.asm` kost ongeveer 26 cycli. Welk deel van de CPU-tijd gaat naar de ISR bij een timerperiode van 40 cycli? Welke periode kies je voor maximaal 5 %?
4. Waarom bewaart de hardware de vlaggen, terwijl de ISR de registers zelf moet bewaren?
5. Een 16-bit teller wordt door een ISR opgehoogd (twee bytes, laag en hoog). Het hoofdprogramma leest eerst het lage byte en dan het hoge byte. Beschrijf een situatie waarin het hoofdprogramma een foute waarde leest en hoe je dat oplost (atomisch lezen).
6. Wat gebeurt er als de ISR vergeet de timeraanvraag te wissen?
7. Waarom wordt `IE` bij het aannemen van een interrupt automatisch uitgezet? Wat is er mis met geneste interrupts zonder voorzorgen?
8. Uitdaging: voeg een tweede interruptbron toe met een eigen vector (bijvoorbeeld de UART op `0x04`). Wat verandert er in de besturing en in het datapath?
9. Uitdaging: maak een kleine monitor, een programma dat bytes via de UART ontvangt en als commando uitvoert (bijvoorbeeld 'L' = zet de LED aan, 'D' = LED uit).

## 11. Antwoorden

1. DIV = 50 000 000 / 115 200 = 434,03, dus 434. De werkelijke baudrate is 50 000 000 / 434 = 115 207, een fout van 0,006 %.
2. 10 bits / 9600 = 1,04 ms, dus maximaal ongeveer 960 bytes per seconde.
3. 26 / 40 = 65 %. Voor 5 % moet de periode minstens 26 / 0,05 = 520 cycli zijn.
4. W8 heeft geen instructie om de vlaggen te lezen of te schrijven, dus software kan ze niet bewaren. De registers kan de ISR wel veiligstellen met `ST` en `LD`. Het hoofdprogramma weet niet wanneer de interrupt komt. De ISR veroorzaakt de verstoring en is dus verantwoordelijk voor het herstel, maar voor de vlaggen kan alleen de hardware dat doen.
5. De ISR kan tussen het lezen van het lage en het hoge byte komen. Rolt het lage byte net om van 0xFF naar 0x00 en is het hoge byte nog niet opgehoogd (of juist wel), dan krijg je een mengsel. Bijvoorbeeld: 0x01FF wordt eerst als laag byte 0xFF gelezen, dan komt de ISR (nu 0x0200) en daarna lees je hoog = 0x02. Je krijgt dan 0x02FF. De oplossing is interrupts tijdelijk uitzetten (`DI`) tijdens het lezen en daarna weer aan (`EI`), of de waarde twee keer lezen tot hij consistent is.
6. De aanvraag blijft staan, en zodra `RETI` interrupts weer aanzet, begint de ISR opnieuw. De CPU zit vast in de ISR en het hoofdprogramma komt niet meer aan bod.
7. Zonder die voorzorg kan de ISR zelf worden onderbroken voordat ze `EPC` en de bewaarde vlaggen heeft veiliggesteld. Met één `EPC` zou de tweede interrupt de eerste overschrijven. Geneste interrupts vragen een stapel voor de teruggekeerde toestanden of een eigen `EPC` per niveau.
8. Het datapath krijgt een vectorkeuze (welke bron?) en de besturing moet kiezen welke aanvraag voorrang heeft (prioriteit) en welk adres naar de PC gaat. Voor de ISR zelf kun je dan twee routines schrijven in plaats van in één routine uit te zoeken wie de aanvraag deed.
9. Dit is een open opdracht. De aanpak: interrupt bij ontvangst, de ISR schrijft de byte naar een buffer en de hoofdlus leest de buffer uit, vergelijkt met `CMPI` en voert het commando uit.

## 12. Zelftest

1. Wat is memory-mapped I/O?
2. Wat is het verschil tussen polling en een interrupt?
3. Wat bewaart de hardware bij een interrupt en wat de software?
4. Wat doet `RETI`?
5. Waarom samplet de UART-ontvanger in het midden van een bit?

Antwoorden: (1) Apparaatregisters die op geheugenadressen zitten en met gewone lees- en schrijfinstructies worden gebruikt. (2) Bij polling kijkt de CPU zelf steeds, bij een interrupt meldt het apparaat zich. (3) De hardware bewaart de PC en de vlaggen, de software de registers die de ISR gebruikt. (4) Het herstelt PC en vlaggen en zet interrupts weer aan. (5) Daar is de lijn het stabielst. Aan de randen kunnen kleine timingfouten en ruis de waarde verkeerd laten lezen.

## 13. Verder lezen

- Harris en Harris, 8.5 (I/O-systemen) en hoofdstuk 6.7 (interrupts en uitzonderingen).
- Het datablad van een echte UART, bijvoorbeeld de 16550, om te zien hoeveel mogelijkheden er bijkomen (FIFO's, pariteit).
- De RISC-V *privileged specification*, het hoofdstuk over traps: hoe een moderne CPU interrupts, uitzonderingen en privilegeniveaus regelt.

---

> **Fase 5 is af.** Je kent nu vier architecturen (register, stack, TTA en pipeline), geheugenhiërarchie en sprongvoorspelling, en je CPU heeft een buitenwereld met interrupts. Fase 6 brengt het naar echte hardware: eerst op een FPGA, dan op een printplaat en uiteindelijk op silicium.

Volgende week: je CPU draait nu in de simulator. Tijd om hem op echte chips te laten draaien: de FPGA.
