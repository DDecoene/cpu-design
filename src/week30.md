---
title: "Week 30 · De SD-kaart en de beeldcomputer"
---

<p class="subtitle">Fase 7 · De beeldcomputer · ongeveer 16 uur</p>

# Week 30: De SD-kaart en de beeldcomputer

## Wat je na deze week kunt

- uitleggen hoe een SD-kaart in SPI-modus opstart en een blok teruggeeft
- een bootprogramma in assembler schrijven dat een kaart initialiseert en 19 blokken in het framebuffer zet
- een beeld omzetten naar het formaat dat de computer leest, en dat op een kaart zetten
- een kaartmodel in Verilog schrijven dat het protocol bewaakt, en daarmee de hele computer testen
- de computer synthetiseren voor een iCE40 UP5K en de resultaten (grootte, snelheid) beoordelen
- uitleggen wat deze computer wel en niet is, en waar je een 3D-versneller zou aanbrengen

## 1. Het plan

Alle onderdelen zijn er: de VGA-generator (week 27), het framebuffer en de registers (week 28) en de SPI-poort (week 29). Het bootprogramma moet nu in volgorde:

```text
  1. 80 klokpulsen met CS hoog, langzaam         de kaart zet zich in SPI-modus
  2. CMD0   →  antwoord 0x01                     reset, de kaart is 'idle'
  3. CMD8   →  antwoord 0x01 + 4 bytes           de kaart zegt dat hij versie 2 is
  4. CMD55 + ACMD41  (herhalen tot 0x00)         de kaart start op
  5. snelle klok
  6. 19 x  CMD17 (lees blok n)  →  512 bytes     elk byte naar het framebuffer
  7. klaar: LED's tonen 0x10
```

## 2. De SD-kaart in SPI-modus

Een SD-kaart kan op twee manieren praten: in de eigen SD-modus met vier datalijnen, of in de SPI-modus met de vier draden van vorige week. De SPI-modus is trager, maar eenvoudig. Een SD-kaart bevat zelf een kleine processor die de commando's afhandelt.

### Een commando

Elk commando is zes bytes:

```text
  byte 0:    0 1 c c c c c c         01 gevolgd door het commandonummer (6 bit)
  byte 1-4:  argument                32 bit, de MSB eerst
  byte 5:    r r r r r r r 1         CRC7 en een eindbit
```

Na het commando stuurt de kaart een antwoord. Het antwoord begint niet meteen. De kaart heeft tot 8 bytes nodig om te reageren (de specificatie noemt dat NCR), en in die tijd leest de master alleen `0xFF`. Het antwoord is het eerste byte waarvan bit 7 nul is.

Het standaardantwoord is R1, een byte van losse bits:

| Bit | Betekenis |
|:---:|-----------|
| 7 | altijd 0 |
| 6 | parameterfout |
| 5 | adresfout |
| 4 | fout in de wisreeks |
| 3 | CRC-fout |
| 2 | ongeldig commando |
| 1 | wisreset |
| 0 | de kaart is 'idle' (aan het opstarten) |

Dus `0x01` betekent: alles goed, nog bezig met opstarten. `0x00` betekent: klaar en goed. `0x05` betekent: idle en dit commando ken ik niet.

### De opstartvolgorde

Een kaart start op met de SD-modus en schakelt over naar SPI als hij CMD0 ziet terwijl CS laag is. Voordat dat kan, moet hij minstens 74 klokpulsen gezien hebben met CS hoog en MOSI hoog. We sturen er 80 (10 bytes `0xFF`), en doen dat langzaam, want tijdens het opstarten mag de klok niet sneller dan 400 kHz.

| Commando | Wat het doet | Argument | CRC | Antwoord |
|----------|--------------|----------|-----|----------|
| CMD0 | reset, ga naar SPI-modus | 0 | `0x95` | R1 = `0x01` |
| CMD8 | vraag de versie en de voedingsspanning | `0x000001AA` | `0x87` | R1 = `0x01`, dan 4 bytes die het argument herhalen |
| CMD55 | het volgende commando is een 'applicatiecommando' | 0 | niet nodig | R1 |
| ACMD41 | start de kaart op | `0x40000000` | niet nodig | R1 = `0x01` tot hij klaar is, dan `0x00` |
| CMD17 | lees een blok van 512 bytes | bloknummer | niet nodig | R1 = `0x00`, dan een token, 512 bytes en 2 CRC-bytes |

Alleen CMD0 en CMD8 moeten een goede CRC hebben, omdat de kaart dan nog niet in SPI-modus werkt. Daarna controleert hij de CRC niet meer, tenzij je dat met een commando aanzet. Het argument van CMD8 bevat een spanningsbereik (`0x1` = 2,7 tot 3,6 V) en een testpatroon (`0xAA`) dat de kaart terugstuurt. Zo weet je dat je niet met ruis praat. Het argument `0x40000000` van ACMD41 zegt dat wij kaarten met hoge capaciteit (SDHC) ondersteunen.

### Een blok lezen

CMD17 geeft het bloknummer als argument (voor SDHC; oudere kaarten tot 2 GB willen een byteadres). De kaart antwoordt met R1 = `0x00`, stuurt `0xFF` terwijl hij het blok ophaalt, dan het datatoken `0xFE`, dan 512 bytes en twee CRC-bytes. Die twee bytes lezen we, maar controleren we niet.

```text
  master → kaart:  51 00 00 00 05 xx       CMD17, blok 5
  kaart → master:  FF FF 00 FF FF FF FE d0 d1 ... d511 c0 c1
                   └ wachttijd ┘ R1 └ wacht ┘ token └── 512 bytes ──┘ crc
```

Dit programma werkt alleen met SDHC- en SDXC-kaarten (in de praktijk alle kaarten vanaf 4 GB). Een SD-kaart van 2 GB of kleiner gebruikt byteadressen en zou CMD58 en CMD16 nodig hebben. Gebruik die niet.

## 3. Een beeld op een kaart, zonder bestandssysteem

Een gewone kaart heeft een bestandssysteem (FAT), en om daar een bestand uit te lezen moet je de mappenstructuur kunnen volgen. Dat is veel werk voor een computer van 256 instructies. We slaan het over: het beeld staat op de kaart vanaf blok 0, bytes achter elkaar, zonder structuur. De kaart heet dan 'raw' beschreven.

> **Waarschuwing.** Als je een beeld op een echte kaart schrijft, wis je wat erop stond, ook de partitietabel. Gebruik een kaart die je kunt missen en let heel goed op de naam van het apparaat. Een verkeerd gekozen apparaat (bijvoorbeeld je computerschijf) wordt met hetzelfde commando net zo grondig overschreven.

Het formaat is simpel: 160 x 120 pixels, 4 bit per pixel, twee pixels per byte (de linker in de hoge nibble), rij voor rij. Dat zijn 9 600 bytes, en dat past in 19 blokken van 512 bytes (9 728 bytes) met 128 bytes over. Dit is precies het formaat van het framebuffer (week 28), zodat het programma de bytes ongewijzigd kan doorsturen.

Het script `mkbeeld.py` maakt zo'n bestand. Met `demo` maakt hij een smiley op een blauwe achtergrond met een raster, een witte rand en onderaan de 16 kleuren. Met een PPM-bestand (het formaat uit week 27) als argument zet hij een eigen beeld om naar de 16 kleuren van de palette: voor elke pixel de dichtstbijzijnde kleur.

```{.python include="beeld/mkbeeld.py"}
```

De palette in Python moet gelijk zijn aan die in `video_out.v`, anders komen de kleuren van je foto er anders uit dan je verwacht. Daarom leest de test de palette uit het Verilog-bestand en vergelijkt hem met die in Python. Zo'n controle is goedkoop en voorkomt een soort fout die je op het scherm moeilijk terugvindt.

```{.python include="beeld/test_mkbeeld.py"}
```

### Je eigen beeld op een kaart zetten

Voor een eigen foto heb je een programma nodig dat het formaat aanpast, bijvoorbeeld ImageMagick:

```text
magick foto.jpg -resize 160x120! foto.ppm
python3 mkbeeld.py foto.ppm foto          # maakt foto.img en foto.hex
```

Het uitvoer `.img` gaat op de kaart. Op macOS: zoek het apparaat van de kaart met `diskutil list` (kijk naar de grootte), zet hem los met `diskutil unmountDisk /dev/diskN` en schrijf met `sudo dd if=foto.img of=/dev/rdiskN bs=512`. Op Linux: `lsblk`, dan `sudo dd if=foto.img of=/dev/sdX bs=512 conv=fsync`. Vervang `N` en `X` door de nummers van je kaart, en controleer het nog een keer.

## 4. Een kaartmodel om tegen te testen

Zonder echte kaart hebben we iets nodig dat zich als een kaart gedraagt. Het model in `sd_model.v` kent precies de commando's van het bootprogramma, antwoordt zoals de specificatie dat zegt (na een of meer `0xFF`-bytes), en legt vast wat het programma doet. Zo wordt het een scheidsrechter:

- komt CMD0 pas na minstens 74 klokpulsen met CS hoog?
- hebben CMD0 en CMD8 de goede CRC en het goede argument?
- komt elk commando in de goede volgorde (geen CMD17 voordat de kaart klaar is)?
- welke blokken zijn gelezen, en in welke volgorde?

Het model laat ACMD41 een paar keer `0x01` zeggen voordat hij `0x00` geeft (standaard drie keer), zoals een echte kaart. Een programma dat verwacht dat de kaart bij de eerste poging klaar is, faalt dus. Zo'n gedrag moet de simulatie dwingen, anders bouw je een programma dat alleen op een perfecte kaart werkt.

```{.verilog include="beeld/sd_model.v"}
```

## 5. Het bootprogramma

Het programma past in 101 van de 256 instructies die de CPU heeft. Het gebruikt twee hulproutines en een datagebied met de commando's.

De commando's van zes bytes staan als gegevens in het datageheugen (`.data`) en worden bij de reset geladen, zoals de tekst in `hello.asm` in week 23. Zo hoeven we geen zes `LDI`'s per commando te schrijven. Alleen CMD17 verandert: het bloknummer in de laatste argumentbyte wordt na elk blok met één opgehoogd.

Hulproutines:

- **`xfer`**: stuur het byte in `R0` over SPI, wacht tot de poort klaar is, en geef het ontvangen byte terug in `R0`.
- **`cmd`**: stuur de zes bytes waar `R2` naar wijst, en lees daarna maximaal 16 bytes tot er een byte komt met bit 7 gelijk aan nul. Dat byte is R1 en komt terug in `R0`. Komt er in 16 bytes geen antwoord, dan is `R0` gelijk aan `0xFF` en schiet de vergelijking van de aanroeper daar op af.

`cmd` roept zelf `xfer` aan, en `CALL` bewaart het terugkeeradres in `R7`. De tweede `CALL` zou `R7` dus overschrijven. Daarom kopieert `cmd` `R7` eerst naar `R5` en keert het terug met `JR R5`. Dit is een kleine versie van wat een compiler met een stapel doet.

De LED's (GPIO) tonen waar het programma is: 1 = klokpulsen en CMD0 bezig, 2 = CMD0 gelukt, 3 = CMD8 gelukt, 4 = kaart klaar, 5 = bezig met lezen, `0x10` als alles klaar is, en bit 7 erbij als er iets misgaat. Die LED-nummers tellen dus anders dan de lijst in paragraaf 1. Zo kun je met een bord zonder scherm toch zien waar het mis ging.

```{.text include="beeld/boot.asm"}
```

Wat dit programma niet doet:

- Geen time-out op ACMD41. Een kaart die nooit klaar meldt, laat het programma eindeloos lussen met `0x03` op de LED's. Dit is een bewuste keuze om het kort te houden (oefening 6).
- Geen controle op de CRC van de datablokken.
- Geen ondersteuning voor kaarten tot 2 GB (byteadressering).
- Geen herstel bij een fout: het stopt (`HALT`) met een foutcode.

## 6. De hele computer

De top verbindt alles: de CPU met SPI en video, het framebuffer, de VGA-uitgang en de SD-kaart. Het is `beeld_v` van week 28 met `cpu_b` in plaats van `cpu_v`, en de SPI-pinnen naar buiten.

```{.verilog include="beeld/beeld_top.v"}
```

De testbench zet het kaartmodel (met het demobeeld) aan de SPI-pinnen, laat het bootprogramma lopen en wacht tot de LED's `0x10` tonen. Dan controleert hij:

- wat de kaart gezien heeft: de goede volgorde, de CRC's, 74 of meer klokpulsen, geen lees-commando vóór de kaart klaar was, en blokken 0 tot en met 18, elk precies één keer en in volgorde
- dat de SPI-klok tijdens het opstarten niet sneller was dan 400 kHz
- elke pixel van het scherm (307 200 stuks) tegen wat er volgens het bestand moet staan, met een eigen kopie van de palette

```{.verilog include="beeld/tb_beeld_top.v"}
```

Het resultaat in de simulatie, bij een CPU-klok van 12 MHz en een kaart die ACMD41 drie keer idle meldt:

| Fase | Duur |
|------|-----:|
| opstarten van de kaart (stap 1 tot en met 4) | 2,5 ms |
| 19 blokken lezen (9 728 bytes) | 49,3 ms |
| **samen** | **ongeveer 52 ms** |

Het lezen duurt 5,07 µs per byte: 61 klokken van 12 MHz, waarvan het SPI-byte zelf er 32 kost. De CPU is dus de helft van de tijd bezig met wachten en tellen. Een echte kaart doet er bij het opstarten vaak langer over, omdat ACMD41 niet drie keer maar meer dan honderd keer idle kan melden.

De testbench schrijft het beeld ook weg als `build/beeld.ppm`. Zet het om met `ppm2png.py`: je ziet een gele smiley op een blauwe achtergrond met een grijs raster en een witte rand, met onderaan een strook met alle 16 kleuren. Dat is de uitkomst van een hele keten: een bestand op een kaart, een protocol over vier draden, een CPU die bytes verplaatst, een geheugen met twee klokken en een generator die het afloopt.

### Streng genoeg?

Voor deze week zijn twee proeven gedaan.

| Fout | Wat de tests zeggen |
|------|---------------------|
| het kaartmodel wacht 17 bytes (`NCR = 17`) voor hij antwoordt, meer dan het programma wil afwachten | `tb_beeld_top`: LED's `10000001`, dus LED-code 1 met de foutbit: CMD0 kreeg geen antwoord. (De specificatie staat hoogstens 8 toe; het programma geeft er 16.) |
| de master leest MISO op de verkeerde flank (week 29) | al `tb_spi` faalt, lang voor deze test |

## 7. Naar de FPGA

Het ontwerp past op de UP5K. Voor een echt bord komen er drie dingen bij: een PLL die de pixelklok uit de 12 MHz maakt, een toplevel met de pinnen, en een pinbestand. Die staan in `labs/beeld_fpga/` en gebruiken chipspecifieke onderdelen, dus Icarus kan ze niet simuleren.

De PLL volgt uit het hulpprogramma `icepll -i 12 -o 25.175`, dat 25,125 MHz geeft (VCO 804 MHz, gedeeld door 32). De reset blijft actief tot de PLL vergrendeld is.

```{.verilog include="beeld_fpga/pll_ice40.v"}
```

```{.verilog include="beeld_fpga/ice40_top.v"}
```

Het script voert dezelfde stappen uit als in week 23 en 24: synthese met Yosys, plaatsen en routeren met nextpnr, en een bitstream met icepack. Het gebruikt alleen de bestanden die op de chip komen en laat de testbenches, de virtuele monitor en het kaartmodel buiten de deur.

```{.bash include="beeld_fpga/flow.sh"}
```

Resultaten van `flow.sh` (Yosys en nextpnr via YoWASP, drie seeds):

| Meting | Waarde | Beschikbaar op de UP5K |
|--------|-------:|-----------------------:|
| LUT4 | 1 109 | |
| flipflops | 372 | |
| logische cellen in totaal (nextpnr) | 1 407 | 5 280 (27 %) |
| blok-RAM (4 kbit) | 20 | 30 (67 %) |
| PLL | 1 | 1 |
| maximale frequentie CPU-klok | 17,4 tot 18,5 MHz | nodig: 12 MHz |
| maximale frequentie pixelklok | 36,3 tot 37,8 MHz | nodig: 25,125 MHz |
| bitstream | 104 090 bytes | |

Twintig blok-RAM's: negentien voor het framebuffer, één voor het datageheugen van de CPU. De instructies staan als logica (de ROM van 101 instructies in LUT's, zie week 24). De CPU-klok heeft een marge van 45 tot 55 %, de pixelklok van 45 tot 50 %. Dat verschilt per seed omdat plaatsen en routeren met een willekeurige beginwaarde werkt. Voor een ontwerp dat je op hardware gaat zetten is het goed om meerdere seeds te proberen en met de laagste waarde te rekenen.

Wat er niet gedaan is: een gate-level simulatie van de hele computer (die van week 24 ging over de kleine top) en een test op echte hardware. Week 23 liet zien dat een ontwerp dat in simulatie slaagt, op een chip leeg kan blijken te zijn. Die verificatie zou hier ruim een uur kosten. Het is de eerste stap als je het bord hebt.

### Het pinbestand

`beeld_voorbeeld.pcf` bevat alle signalen met vraagtekens in plaats van pinnummers. Vul ze in uit het schema van je bord en de handleidingen van je VGA- en SD-module, en geef het door: `PCF=beeld.pcf bash flow.sh`. Zonder pinbestand kiest nextpnr zelf pinnen. Dat is goed om te meten maar niet om op een bord te laden: er kunnen uitgangen op pinnen komen die ergens anders mee verbonden zijn.

```{.text include="beeld_fpga/beeld_voorbeeld.pcf"}
```

### Als het op een echt bord niet werkt

Een lijst om af te lopen, van simpel naar lastig:

1. **Geen beeld.** Brandt de LED van de PLL-vergrendeling of komt de pixelklok niet op gang? Meet met een oscilloscoop of logic analyzer `hsync` (31,4 kHz) en `vsync` (59,8 Hz). Staan de pinnen goed in het pinbestand? Staat je monitor op VGA?
2. **Beeld, maar kleuren verkeerd.** De kleurbits staan in de verkeerde volgorde op de module. Het kleurbalkenbeeld uit week 27 laat dat meteen zien: laad het eerst.
3. **De LED's staan op 0x81.** CMD0 krijgt geen antwoord. Controleer de bedrading van MISO, MOSI, SCK en CS, de voeding van de kaart (3,3 V) en of de kaart in de houder zit. Sommige modules hebben pull-ups nodig op de lijnen, kijk in de handleiding.
4. **De LED's staan op 0x82.** CMD0 lukt, CMD8 niet. Waarschijnlijk is het een oudere kaart (SD 1.x, 2 GB of kleiner), die CMD8 niet kent.
5. **De LED's blijven op 0x03.** ACMD41 meldt steeds idle. Wacht een of twee seconden; sommige kaarten zijn traag. Blijft het zo, dan is de kaart niet geschikt of niet goed gevoed.
6. **De LED's staan op 0x85.** CMD17 geeft geen goed antwoord: de kaart is te klein voor het bloknummer of is niet SDHC.
7. **Het beeld klopt niet.** Controleer eerst met `sd.img` en `xxd` of de kaart het goede bestand bevat. Daarna: staan de bytes in de goede volgorde (hoge nibble links)?

Deze lijst is een hulpmiddel. Ze komt uit het ontwerp en is niet op een bord gecontroleerd.

## 8. Wat dit is, en wat niet

De CPU in deze computer is de W8F uit week 22 en 24. Hij heeft een gewone 8-bit instructieset en is niet voor beelden of 3D ontworpen. De assembler is dezelfde. Wat de computer tot een beeldcomputer maakt, zit in de randapparatuur: de VGA-generator, het framebuffer en de SPI-poort. De CPU doet wat hij het best kan: bytes verplaatsen en lussen tellen.

Wil je er iets krachtigers van maken, dan zijn er drie stappen, van klein naar groot. Elk raakt een ander deel.

| Stap | Wat | Wat verandert er |
|------|-----|------------------|
| 1 | **Een tekenvlak in hardware**: een blokje dat een rechthoek vult of een lijn trekt, onder commando van de CPU | het framebuffer krijgt een tweede schrijver, naast de CPU; de CPU hoeft niet elk byte te schrijven (een blitter) |
| 2 | **Een driehoekentekenaar** (rasterizer): de hardware krijgt drie hoekpunten en vult de driehoek met een kleur | een extra eenheid met optellers en vergelijkers die per pixel kijkt of hij binnen de driehoek ligt |
| 3 | **Een andere CPU of een raytracer als coprocessor** | een instructieset met vermenigvuldigen en vectoren, of een eenheid die voor elke pixel een straal door de scène volgt |

Alleen de derde stap is wat je een 3D-processor zou noemen, en ze is veel groter dan de eerste twee. Een goed begin is stap 1: het framebuffer is er al, en het enige wat je toevoegt is een tweede schrijver met een eigen toestandsmachine. Dat is dezelfde soort uitbreiding als de SPI-poort van vorige week.

## 9. Lab

1. Draai alle tests van fase 7: `python3 test_labs.py beeld`. Het duurt ongeveer een minuut. Zoek de tien regels met `ok` (twee Python-tests en acht testbenches).
2. Maak een eigen beeld (`magick ... foto.ppm`, `mkbeeld.py foto.ppm foto`). Kopieer `foto.hex` naar `sd.hex` en draai `tb_beeld_top` opnieuw. Wat zie je in `build/beeld.ppm`?
3. Zet `ACMD41_TRIES` in het kaartmodel op 30. Hoe lang duurt het opstarten nu? Past dat bij wat je op een echte kaart zou verwachten?
4. Zet `NCR` op 8 (het maximum uit de specificatie). Werkt het programma nog? En op 17?
5. Draai `flow.sh` (gebruik de omgeving van week 23) en noteer de LUT's, het blok-RAM en de frequenties. Draai het met `SEED=2` en `SEED=3`. Hoe groot is het verschil?
6. Voeg een time-out toe aan de ACMD41-lus (oefening 6).

## 10. Oefeningen

1. Schrijf de zes bytes van CMD17 voor blok 5 met de juiste CRC. (De CRC van CMD17 hoeft de kaart niet te controleren, maar de CRC7 van de eerste vijf bytes is `0x07`.)
2. Hoe komt de CRC `0x95` van CMD0 en `0x87` van CMD8 tot stand? (Tip: ze zijn `(CRC7 << 1) | 1`, met CRC7 = `0x4A` en `0x43`.)
3. Voor een SDSC-kaart (tot 2 GB) is het argument van CMD17 een byteadres. Wat is het argument voor blok 5?
4. Hoeveel blokken zijn er nodig voor een beeld van 320 x 240 met 4 bit per pixel? En 160 x 120 met 8 bit?
5. Hoeveel instructies heeft het bootprogramma, en hoeveel ruimte is er over? Wat zou je kunnen toevoegen?
6. Voeg aan het ACMD41-gedeelte een time-out toe van ongeveer een seconde. Hoeveel pogingen kost dat, als een poging uit twee commando's van elk ongeveer 14 bytes in de langzame stand bestaat? Welke registers gebruik je?
7. Waarom gebruikt `cmd` `R5` om het terugkeeradres te bewaren en niet het datageheugen?
8. Het verschil tussen de seeds in de timing is bijna een MHz. Waarom? Hoe gebruik je dat bij het beoordelen van een resultaat?
9. De LED's tonen `0x82`. Wat is er gebeurd? En bij `0x03` dat blijft staan?
10. Uitdaging: lees een FAT16- of FAT32-bestandssysteem. Welke hulpmiddelen mist de CPU daarvoor (denk aan 16- en 32-bit getallen)? Hoeveel van de 256 instructies zou het kosten?
11. Uitdaging: ontwerp de blitter uit paragraaf 8. Welke registers heeft hij en hoe deelt hij het framebuffer met de CPU?

## 11. Antwoorden

1. `0x51 0x00 0x00 0x00 0x05 0x0F`. De CRC7 is `0x07` en met het eindbit is het laatste byte `(0x07 << 1) | 1 = 0x0F`. Het bootprogramma stuurt er `0x01`, en omdat de CRC in SPI-modus niet meer gecontroleerd wordt (na CMD0 en CMD8), werkt dat.
2. De CRC7 is de rest van een polynoomdeling (x^7 + x^3 + 1) over de eerste vijf bytes van het commando. Voor CMD0 is dat `0x4A`, voor CMD8 `0x43`. Met het eindbit erachter wordt dat `0x95` en `0x87`. In deze cursus is geen CRC behandeld; de getallen zijn met een losse berekening gecontroleerd.
3. 5 x 512 = 2 560 = `0x00000A00`.
4. 320 x 240 x 4 bit = 38 400 bytes = 75 blokken (precies). 160 x 120 x 8 bit = 19 200 bytes = 37,5, dus 38 blokken.
5. 101 van 256, dus 155 vrij. Voor de hand liggend: een time-out, een controle van de foutbits in R1 na elk commando, en tekst via de UART bij een fout.
6. Een seconde is ongeveer 12 miljoen klokken. Een poging van 2 x 14 bytes in de langzame stand kost 28 x 8 x 32 = 7 168 klokken (bijna alleen SPI-tijd), dus ongeveer 1 700 pogingen. Dat past niet in een 8-bit teller (255): je hebt twee registers nodig die als een 16-bit teller werken, of een buitenste lus van 7 rondes om een binnenste van 250. De registers `R4` en `R6` zijn na `acmd` vrij.
7. Het datageheugen werkt ook (`ST`, `LD`), maar kost twee instructies en een adresregister, en je moet er een vaste plek voor reserveren. Een vrij register kost één `MOV` en één `JR`. Het is wel een aanpak die niet meer werkt als je dieper wilt nesten: dan moet je een stapel gebruiken.
8. Plaatsen en routeren begint met een willekeurige plaatsing en verbetert die. Een andere seed geeft een andere plaatsing en dus een iets andere maximale frequentie. Gebruik de laagste waarde van meerdere seeds en reken daarmee. Dat het verschil klein is, is een goed teken: het ontwerp zit niet op de rand.
9. `0x82` is LED-code 2 met de foutbit: CMD0 lukte en CMD8 niet, wat meestal een kaart van SD 1.x is. `0x03` dat blijft staan is LED-code 3: de ACMD41-lus is nog bezig, en de kaart meldt steeds 'idle'.
10. De CPU rekent op 8 bit, een FAT-bestandssysteem op 16 en 32 bit (clusternummers, bestandsgroottes), dus elke berekening kost meerdere instructies met een carry. Daarbij moet je de directory doorzoeken en de FAT volgen. Het is te doen maar zou meer dan de 155 vrije instructies kosten. Met een uitgebreide ISA of een soft-CPU met 16 bit is het eenvoudiger.
11. Dit is een open opdracht. Denk aan: beginadres (2 registers), breedte, hoogte en kleur; een toestandsmachine die rij voor rij byte voor byte schrijft; en een arbiter die beslist wie het framebuffer mag schrijven als de CPU en de blitter tegelijk willen.

## 12. Zelftest

1. Welke stappen doorloopt een SD-kaart vóór je een blok kunt lezen?
2. Waarom moet de klok tijdens het opstarten langzaam zijn?
3. Waarom ontbreekt er een FAT-bestandssysteem in dit ontwerp, en wat is het gevolg?
4. Wat controleert het kaartmodel behalve de data?
5. Is deze CPU een 3D-processor?

Antwoorden: (1) Minstens 74 klokpulsen met CS hoog, CMD0, CMD8, en CMD55 met ACMD41 tot de kaart `0x00` zegt. (2) De kaart is nog niet klaar met opstarten en de specificatie staat tot dan maximaal 400 kHz toe. (3) Een FAT lezen kost veel instructies en 16- en 32-bit rekenwerk; het gevolg is dat het beeld op een vaste plek (blok 0) staat en dat de kaart wordt overschreven. (4) De volgorde, de CRC's van CMD0 en CMD8, het aantal klokpulsen voor de eerste commando's, de opstartsnelheid en welke blokken gelezen zijn. (5) Nee. Het is een gewone 8-bit CPU met een speciale randapparatuur voor beeld.

## 13. Verder lezen

- *SD Specifications Part 1: Physical Layer Simplified Specification* van de SD Association, het hoofdstuk over de SPI-modus en de initialisatie.
- Elm-Chan's pagina "How to Use MMC/SDC": een klassieke uitleg met voorbeeldcode, ook voor kleine microcontrollers.
- Voor de eerstvolgende stap: de ontwerpen van oude computers met een framebuffer (de Amiga-blitter, de Atari ST), en het open-sourceproject voor een eigen GPU.

---

> **Het beeld komt van de kaart.** Je computer start een SD-kaart op, leest er 19 blokken van en zet het beeld op het scherm, en alles daarvoor heb je zelf gebouwd: de CPU, de poort naar de kaart, het geheugen en de VGA-generator. Het is gesimuleerd en gesynthetiseerd, en wacht op een bord.

Wil je dit echt laten draaien? Koop een bord, laad `kleurbalken` uit week 27 of 28 om het beeld en de kleuren te controleren, en dan pas het bootprogramma met een kaart. Veel plezier.
