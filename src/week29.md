---
title: "Week 29 · SPI: praten met de buitenwereld"
---

<p class="subtitle">Fase 7 · De beeldcomputer · ongeveer 12 uur</p>

# Week 29: SPI

## Wat je na deze week kunt

- uitleggen hoe SPI werkt: master en slave, vier draden, schuifregisters, de vier modi
- een SPI-master in Verilog schrijven die in modus 0 werkt, met twee snelheden
- uitleggen waarom chip select een softwarebit is en geen deel van de overdracht
- een SPI-poort aan de CPU hangen als geheugengemapt apparaat en er een programma voor schrijven
- een testbench schrijven met een slave-model dat zelf de regels van het protocol bewaakt


## 1. Wat is SPI?

SPI (Serial Peripheral Interface) is de eenvoudigste manier om twee chips met elkaar te laten praten. Er is één master, die de klok levert, en een of meer slaves. Vier draden:

| Draad | Richting | Betekenis |
|-------|----------|-----------|
| SCLK | master → slave | de klok |
| MOSI | master → slave | master out, slave in: de data van de master |
| MISO | slave → master | master in, slave out: de data van de slave |
| CS (of SS) | master → slave | chip select: de slave doet alleen mee als CS laag is |

Het slimme is dat de master en de slave samen een groot schuifregister vormen:

```text
        master                             slave
   ┌─────────────────┐                ┌─────────────────┐
   │ schuifregister  │──── MOSI ─────►│ schuifregister  │
   │    (8 bit)      │◄─── MISO ──────│    (8 bit)      │
   └────────▲────────┘                └────────▲────────┘
            └───────────── SCLK ───────────────┘
```

Bij elke klokpuls schuift de master één bit uit via MOSI en de slave één bit uit via MISO. Na 8 pulsen hebben ze hun bytes uitgewisseld. SPI is dus altijd tweerichtingsverkeer: wil je alleen lezen, dan stuur je een nietszeggend byte (voor een SD-kaart `0xFF`) en wil je alleen schrijven, dan negeer je wat terugkomt.

Vergeleken met de UART van week 22: SPI heeft een klok erbij, en daardoor geen baudrate-afspraak, geen start- en stopbit en geen oversampling. Het is sneller en eenvoudiger, maar kost meer draden.

### De vier modi

Wanneer verandert de data en wanneer wordt hij gelezen? Dat leggen twee instellingen vast: de rustpolariteit van de klok (CPOL) en op welke flank gelezen wordt (CPHA).

| Modus | CPOL | CPHA | Klok in rust | Data gelezen op |
|:-----:|:----:|:----:|:------------:|:---------------:|
| 0 | 0 | 0 | laag | stijgende flank |
| 1 | 0 | 1 | laag | dalende flank |
| 2 | 1 | 0 | hoog | dalende flank |
| 3 | 1 | 1 | hoog | stijgende flank |

SD-kaarten gebruiken modus 0, en dat is ook wat wij bouwen.

```text
 Modus 0, de MSB eerst. Op ↑ (stijgende flank) leest de ontvanger, op ↓ (dalende flank) zet de zender het volgende bit.

 CS     ‾‾‾\____________________________________/‾‾‾
 SCLK   ______┌───┐___┌───┐___┌───┐___┌───┐______      (acht pulsen voor acht bits)
                ↑   ↓   ↑   ↓   ↑   ↓   ↑
 MOSI   ═══ bit 7 ═══╪═ bit 6 ═╪═ bit 5 ═╪═ bit 4 ═══   (elk bit staat een halve periode vóór de leesflank)
```

## 2. De master

De master is een toestandsmachine met een klokdeler. Hij werkt als volgt:

1. De CPU geeft een byte en een startpuls. Het byte komt in een schuifregister en het register `n` telt 8 bits af.
2. Na een halve SCLK-periode (de klokdeler) komt de **stijgende flank**: SCLK gaat hoog en de master leest MISO.
3. Na nog een halve periode komt de **dalende flank**: SCLK gaat laag, het schuifregister schuift één plaats op (het gelezen bit gaat erin) en MOSI toont het volgende bit.
4. Na 8 keer is het byte klaar en staat het ontvangen byte in `rx`.

Het is belangrijk dat de master MOSI **niet** verandert op de stijgende flank, want dan leest de slave op dezelfde flank misschien nog het oude bit, misschien al het nieuwe. De data hoort een halve periode vóór de flank te staan en een halve periode erna te blijven. Daarom schuift de master op de dalende flank, en leest hij MISO op de stijgende. De slave doet het omgekeerde.

Twee snelheden. De SD-specificatie vraagt tijdens het opstarten een klok van hoogstens 400 kHz, daarna mag het veel sneller. De klokdeler telt `HALF_SLOW = 16` klokken per halve periode bij het opstarten (12 MHz / 32 = 375 kHz) en `HALF_FAST = 2` daarna (12 MHz / 4 = 3 MHz).

```{.verilog include="beeld/spi_master.v"}
```

Een paar ontwerpkeuzes:

- **`miso_s`**: het op de stijgende flank gelezen bit wordt bewaard en pas bij de dalende flank in het schuifregister gezet. Zo verandert het register maar op één moment per periode.
- **Geen synchronizer op MISO.** MISO komt van de slave, die zijn data uit onze eigen SCLK afleidt. Het signaal is dus niet onafhankelijk van onze klok: het verandert kort na de dalende flank en is een halve periode stabiel vóór de stijgende flank waarop we lezen. Bij `vblank` van vorige week was dat anders (twee klokken zonder verband) en daar was een synchronizer wel nodig. Een synchronizer hier zou het gelezen moment een of twee klokken vertragen, en dan lees je bij 3 MHz net niet meer op het goede moment.
- **`start` wordt genegeerd als de master bezig is.** Een tweede schrijfactie halverwege een overdracht zou het schuifregister overschrijven en een half byte versturen. Liever geen effect dan een kapot byte.

## 3. De registers

De CPU ziet de SPI-poort als drie geheugenplaatsen:

| Adres | Naam | Gedrag |
|:-----:|------|--------|
| `0xFC` | SPI_DATA | schrijven: begin een overdracht van dit byte. Lezen: het laatst ontvangen byte |
| `0xFD` | SPI_CTRL | bit 0 = CS (0 = kaart geselecteerd, na reset 1), bit 1 = snelle klok (1 = snel) |
| `0xFE` | SPI_STATUS | lezen: bit 0 = bezig |

Chip select is een bit dat de software zet en niet een deel van de overdracht. Dat lijkt onhandig, maar een SD-kaart verwacht dat CS laag blijft gedurende een heel commando van meerdere bytes (6 bytes commando, dan het antwoord, en bij lezen nog 512 bytes data). Een master die CS bij elk byte op- en neerhaalt zou dat verbreken.

```{.verilog include="beeld/spi_io.v"}
```

## 4. Nog een laagje

Net als vorige week leggen we er een laagje omheen in plaats van `mmio_v` te veranderen. `mmio_b` bevat een `mmio_v` en een `spi_io`, en kijkt naar de bovenste zes adresbits: `111111` is `0xFC` tot en met `0xFF`, en alles daaronder gaat naar `mmio_v`. De CPU is daarmee een derde keer uitgebreid zonder dat het origineel is aangeraakt, en `cpu_b` ontstaat op dezelfde manier uit `cpu_v` als `cpu_v` uit `cpu_f`.

```{.verilog include="beeld/mmio_b.v"}
```

De hele geheugenkaart van de beeldcomputer ziet er nu zo uit:

| Adres | Naam | Uit week |
|:-----:|------|:--------:|
| `0x00`-`0xEF` | RAM | 22 |
| `0xF0` | UART data | 22 |
| `0xF1` | UART status | 22 |
| `0xF2` | Timer herlaadwaarde | 22 |
| `0xF3` | Timer status | 22 |
| `0xF5` | GPIO uit (LED's) | 22 |
| `0xF6` | GPIO in (knoppen) | 22 |
| `0xF7` | Interrupt-aan | 22 |
| `0xF8` | FB_LO | 28 |
| `0xF9` | FB_HI | 28 |
| `0xFA` | FB_DATA | 28 |
| `0xFB` | VID_STATUS | 28 |
| `0xFC` | SPI_DATA | 29 |
| `0xFD` | SPI_CTRL | 29 |
| `0xFE` | SPI_STATUS | 29 |
| `0xFF` | nog vrij | |

## 5. Testen met een nepslave

Een SPI-master controleer je tegen iets dat de regels kent. We schrijven een slave in Verilog die zich gedraagt als een kaart: hij leest MOSI op de stijgende flank, zet MISO na de dalende flank, onthoudt wat hij ontving en antwoordt met vaste bytes. Zo test de bench beide richtingen en let de slave zelf op het protocol.

```{.verilog include="beeld/tb_spi.v"}
```

De test controleert niet alleen of de bytes aankomen, maar ook het gedrag eromheen:

- 4 bytes, 32 klokpulsen: precies 8 per byte
- de klok is in rust laag en CS is na een reset hoog
- de periode is 32 systeemklokken in de langzame stand en 4 in de snelle (gemeten tussen twee stijgende flanken)
- een tweede schrijfactie tijdens een overdracht doet niets
- 100 willekeurige bytes via een lus (MISO met MOSI verbonden) komen onveranderd terug, in beide snelheden

Daarna de CPU zelf. Dit programma verstuurt 8 bytes met MISO en MOSI doorverbonden, en telt hoeveel er goed terugkomen:

```{.text include="beeld/spi_test.asm"}
```

```{.verilog include="beeld/tb_spi_cpu.v"}
```

### Streng genoeg?

| Fout | Wat de tests zeggen |
|------|---------------------|
| de master leest MISO op de dalende in plaats van de stijgende flank | `tb_spi`: "lus: verstuurd 7e, ontvangen 3f" (de bits zijn mis) |
| `HALF_FAST = 1` in plaats van 2 | `tb_spi`: "snelle SCLK-periode is 2 klokken, verwacht 4" |

De tweede fout is geen echte fout: de master werkt prima op 6 MHz. De test hangt alleen aan de waarde 4. Zo'n test noemen we scherp (hij faalt bij elke wijziging) en dat is een afweging: te scherp en je moet bij elke aanpassing de test mee aanpassen, te vaag en hij vangt niets. Hier horen de perioden bij de specificatie van de poort, en dus bij de test.

## 6. Hoe snel is het?

Bij 3 MHz duurt een byte 8 / 3 MHz = 2,67 µs, ofwel maximaal 375 KB/s. In de langzame stand is dat 8 / 375 kHz = 21 µs per byte.

Dat is de snelheid van de lijn, niet van het programma. De CPU moet na elk byte `SPI_STATUS` lezen en de lus afhandelen. Zo'n lus kost (`LD` drie klokken, `CMPI` en `BNE` elk twee, plus het wegschrijven en het klaarzetten van het volgende byte) al snel 30 klokken van 12 MHz, ongeveer evenveel als het byte zelf duurt (32 klokken). In week 30 meten we het: ongeveer 61 klokken per byte, de helft daarvan is de CPU. Een snellere SPI-klok (oefening 4) levert daarom minder op dan je zou denken.

## 7. Lab

1. Draai de tests van fase 7 (`python3 test_labs.py beeld`) en zoek de PASS-regels van `tb_spi` en `tb_spi_cpu`.
2. Zet in `spi_master.v` de waarde van `HALF_SLOW` op 15. Welke frequentie geeft dat, en waarom kiezen we toch liever 16? Welke test faalt?
3. Open een golfvorm van `tb_spi` (voeg `$dumpfile` en `$dumpvars` toe) en zoek de plek waar MOSI verandert. Verandert hij op de dalende flank van SCLK, zoals het hoort?
4. Verander in `spi_test.asm` de testbytes en laat de tests slagen. Verwissel dan `CMP R0, R4` voor `CMP R0, R2` en kijk wat de test zegt.
5. Schrijf een tweede slave-model dat in modus 3 werkt en laat zien dat de master er niet mee werkt.

## 8. Oefeningen

1. Welke vier modi bestaan er en wat verandert er bij elk? Welke modus gebruikt een SD-kaart?
2. Bij een klok van 12 MHz en `HALF` systeemklokken per halve periode: wat is de SCLK-frequentie als formule? Wat is de kleinste `HALF` die onder 400 kHz blijft?
3. Hoe lang duurt het om 9 728 bytes (19 blokken) over te sturen bij 3 MHz zonder overhead? En bij 375 kHz?
4. Wat zou je winnen door `HALF_FAST` op 1 te zetten, als de CPU na elk byte zo'n 30 klokken bezig is?
5. Waarom heeft MISO geen synchronizer maar `vblank` (week 28) wel?
6. Wat gebeurt er als de CPU `SPI_DATA` leest terwijl de poort bezig is?
7. Waarom is CS een bit dat de software zet in plaats van iets dat de hardware bij elk byte doet?
8. Waarom start de master bij reset met `sh <= 8'hFF` en `rx <= 8'hFF`?
9. Uitdaging: voeg een interrupt toe die afgaat als een overdracht klaar is. Welke registers heb je erbij nodig (week 22)?
10. Uitdaging: maak SPI sneller door de CPU een heel blok te laten ontvangen, met een teller en een kleine FIFO in hardware.

## 9. Antwoorden

1. Zie de tabel in paragraaf 1: CPOL bepaalt of de klok in rust laag of hoog is, CPHA of er op de eerste of de tweede flank gelezen wordt. Een SD-kaart gebruikt modus 0.
2. fSCLK = 12 MHz / (2 · HALF). HALF = 15 geeft precies 400 kHz, de grens zelf zonder enige marge (en de klok van een bord is nooit precies 12 MHz). HALF = 16 geeft 375 kHz en blijft er zeker onder. De test `tb_spi` meet de periode van 32 klokken en faalt bij 15.
3. 9 728 bytes · 8 bit / 3 MHz = 25,9 ms. Bij 375 kHz: 9 728 · 8 / 375 kHz = 207,6 ms.
4. Weinig. Een byte duurt dan nog 1,33 µs (16 klokken van 12 MHz) in plaats van 2,67 µs, maar de CPU heeft zelf ongeveer 30 klokken (2,5 µs) nodig. De doorvoer gaat van ongeveer 61 klokken naar 45 per byte: een winst van een kwart, niet van de helft.
5. MISO volgt onze eigen SCLK: de slave verandert hem kort na onze dalende flank en wij lezen een halve periode later. Er is dus een vaste tijdsverhouding. `vblank` komt uit een klok zonder verband met die van de CPU: hij kan op elk moment veranderen, ook vlak voor een klokflank van de CPU, en dan kan een flipflop in een onbepaalde toestand komen.
6. Je krijgt het byte van de vorige overdracht: `rx` wordt pas aan het eind van een overdracht bijgewerkt. Het programma moet dus eerst wachten tot `busy` weer 0 is (wat `xfer` in week 30 ook doet).
7. Een SD-kaart verwacht dat CS laag blijft over een heel commando en het antwoord, en bij het lezen van een blok over 512 bytes. Een hardware-CS per byte zou dat verbreken. Bij sommige andere chips is dat juist wel de bedoeling, en dan is een automatische CS handig.
8. Een SD-kaart ziet MOSI als zijn commandolijn: in rust moet die hoog zijn. We sturen bij het lezen `0xFF` om klokpulsen te maken, en dat is ook de beginwaarde van het register.
9. Een interruptvlag (een bit dat 1 wordt als `busy` van 1 naar 0 gaat), een enable-bit in het register op `0xF7` en een lijn naar `irq` in `mmio_b`. Het idee is hetzelfde als bij de UART en de timer.
10. Dit is een open opdracht. De winst is dat de CPU tijdens het ontvangen van een blok iets anders kan doen, en dat de overhead van 30 klokken per byte verdwijnt.

## 10. Zelftest

1. Hoeveel draden heeft SPI en wat doen ze?
2. In welke modus werkt een SD-kaart?
3. Waarom schuift de master op de dalende flank en leest hij op de stijgende?
4. Waarom twee snelheden?
5. Wat is het voordeel van een softwarebit voor CS?

Antwoorden: (1) Vier: SCLK, MOSI, MISO en CS. (2) Modus 0: klok in rust laag, lezen op de stijgende flank. (3) Zo staat de data een halve periode vóór en na de leesflank stabiel. (4) De kaart wil tijdens het opstarten een klok van hoogstens 400 kHz, daarna mag het veel sneller. (5) De CPU kan CS laag houden over een heel commando en antwoord van meerdere bytes.

## 11. Verder lezen

- De SD Physical Layer Simplified Specification, het hoofdstuk over de SPI-modus. Die is vrij beschikbaar in een vereenvoudigde versie.
- De beschrijving van SPI in het datablad van een chip die je kent, bijvoorbeeld de ATmega328 of de RP2040. Let op hoe zij de modi noemen.
- Week 22 van deze cursus: de UART en de timer als voorbeeld van een geheugengemapt apparaat.

---

> **De CPU praat SPI.** Er is een poort die bytes verstuurt en ontvangt, een slave-model dat het protocol bewaakt, en een programma dat het hele pad van software naar draad en terug test.

Volgende week: de SD-kaart zelf. Je schrijft de opstartvolgorde, een kaartmodel om het tegen te testen, en het bootprogramma dat een beeld op het scherm zet.
