---
title: "Week 28 · Het framebuffer: pixels in geheugen"
---

<p class="subtitle">Fase 7 · De beeldcomputer · ongeveer 14 uur</p>

# Week 28: Het framebuffer

## Wat je na deze week kunt

- uitrekenen hoeveel geheugen een beeld kost en daar een resolutie en kleurdiepte bij kiezen
- uitleggen wat een palette is en waarom een beeld van 16 kleuren maar 4 bit per pixel kost
- een framebuffer met twee klokken (CPU en pixelklok) bouwen en uitleggen waarom dat kan
- een pijplijn uitlijnen als een geheugen een klok vertraging toevoegt
- de CPU pixels laten tekenen via een geheugengemapte poort met auto-increment


## 1. Hoeveel geheugen is een beeld?

Vorige week kwam het beeld uit een formule. Nu moet het uit het geheugen komen, zodat de CPU het kan veranderen. Het geheugen dat het beeld bevat heet het framebuffer. Het probleem is de grootte.

Een scherm van 640 x 480 heeft 307 200 pixels. Met 12 bit kleur per pixel (4 bit per kanaal) is dat 3,7 Mbit, ongeveer 460 KB. De iCE40 UP5K heeft maar 120 kbit blok-RAM. Het past er niet in, met een factor dertig.

| Keuze | Bits | Bytes | Past in 120 kbit? |
|-------|-----:|------:|:-----------------:|
| 640 x 480, 12 bit | 3 686 400 | 460 800 | nee |
| 640 x 480, 4 bit | 1 228 800 | 153 600 | nee |
| 320 x 240, 4 bit | 307 200 | 38 400 | nee |
| 160 x 120, 4 bit | 76 800 | 9 600 | ja |
| 160 x 120, 1 bit | 19 200 | 2 400 | ja |

We kiezen 160 x 120 pixels met 16 kleuren (4 bit). Elke pixel van ons beeld is een blok van 4 x 4 schermpixels: de monitor loopt nog steeds 640 x 480 af, maar we lezen het geheugen maar één keer per vier pixels in beide richtingen. Dat is grof (zo zagen computers uit de jaren tachtig eruit), maar voor foto's van een SD-kaart en voor spelletjes is het genoeg, en het past met ruimte over.

## 2. Een palette

Vier bit per pixel geeft 16 verschillende waarden, maar de monitor wil 12 bit kleur. Daar zit een vertaaltabel tussen: de palette. De waarde in het geheugen is geen kleur, maar een nummer. Het nummer wijst een van 16 kleuren aan, en elke kleur heeft 12 bit.

| Nr | Kleur | RGB (4 bit) | Nr | Kleur | RGB (4 bit) |
|:--:|-------|:-----------:|:--:|-------|:-----------:|
| 0 | zwart | 000 | 8 | donkergrijs | 555 |
| 1 | blauw | 00A | 9 | lichtblauw | 55F |
| 2 | groen | 0A0 | 10 | lichtgroen | 5F5 |
| 3 | cyaan | 0AA | 11 | lichtcyaan | 5FF |
| 4 | rood | A00 | 12 | lichtrood | F55 |
| 5 | magenta | A0A | 13 | lichtmagenta | F5F |
| 6 | bruin | A50 | 14 | geel | FF5 |
| 7 | lichtgrijs | AAA | 15 | wit | FFF |

Dit zijn de 16 standaardkleuren van de EGA-kaart uit 1984, met een bruin en twee grijstinten. In `video_out.v` staat de tabel als een `case`: de synthesetool maakt er een kleine ROM van.

## 3. Hoe de pixels in het geheugen staan

Een byte is 8 bit en een pixel is 4 bit, dus er passen twee pixels in een byte. Het linker blok staat in de hoge nibble, het rechter in de lage. Een rij van 160 blokken is 80 bytes, en het hele beeld is 120 x 80 = 9 600 bytes.

```text
   byte 0       byte 1             byte 79
  ┌────┬────┐ ┌────┬────┐       ┌────┬────┐
  │ P0 │ P1 │ │ P2 │ P3 │  ...  │P158│P159│   rij 0
  └────┴────┘ └────┴────┘       └────┴────┘
   hoog laag
  byte 80 begint rij 1, enzovoort.
```

De monitor loopt pixels af met coördinaten `x` en `y`. Het geheugenadres volgt uit het blok waarin die pixel ligt:

```text
  bx = x / 4          (0 tot 159: de kolom van het blok)
  by = y / 4          (0 tot 119: de rij van het blok)
  adres = by · 80 + bx / 2         de nibble: bx even → hoge nibble, bx oneven → lage
```

Delen door 4 en 2 zijn schuiven, en 80 is geen macht van twee. We schrijven `by · 80` als `by · 64 + by · 16`, twee schuifbewerkingen en een optelling. Dat is heel goedkoop in hardware (alleen draden en een opteller) en geeft geen vermenigvuldiger.

## 4. Twee klokken

De CPU draait op 12 MHz en het beeld op 25,125 MHz. Het framebuffer moet door allebei bereikbaar zijn: de CPU schrijft, de VGA-generator leest. Zonder iets te doen gaat dat mis. Twee circuits met onafhankelijke klokken die dezelfde bits lezen en schrijven, hebben geen vaste verhouding in tijd. Als de ene klok een bit verandert en de andere precies dan leest, kan het bit tussen 0 en 1 hangen (een metastabiele toestand, zie week 6).

Er zijn twee verstandige oplossingen:

1. **Een echte RAM met twee poorten**, met een eigen klok per poort. Het blok-RAM van een FPGA is zo gebouwd. De schrijf- en leespoort zijn losse circuits en de chip regelt zelf de overgang. Wij gebruiken dit voor de pixeldata.
2. **Een synchronizer** (twee flipflops, week 6) voor losse bits die van het ene klokdomein naar het andere gaan. Wij gebruiken dit voor de statusbit `vblank`.

Een regel om te onthouden: **enkele bits via een synchronizer, hele woorden via een RAM met twee poorten**. Een synchronizer voor een woord van 8 bit werkt niet, want de bits kunnen op verschillende klokken aankomen en dan krijg je een mengsel van oud en nieuw.

```{.verilog include="beeld/fb_ram.v"}
```

De regel `always @(posedge rclk) rdata <= mem[raddr]` is belangrijk. Het geheugen heeft een geregistreerde uitgang: de data komt één klok na het adres. Dat is wat de synthesetool nodig heeft om er blok-RAM van te maken, en het kost ons een klok vertraging die we zo moeten opvangen.

Wat gebeurt er als de CPU en de monitor op hetzelfde moment hetzelfde adres raken? De data die de leespoort dan teruggeeft kan oud of nieuw zijn, of in het ergste geval een mengsel. Voor ons is dat geen probleem: het kost hooguit één blok een verkeerde kleur voor één beeld, en dan is het weg. Een spelletje met veel bewegende beelden zou de CPU alleen in de blanking laten tekenen (daarvoor is de statusbit `vblank`).

## 5. De video-uitgang

De module `video_out` verbindt de generator uit week 27 met het framebuffer en de palette. Hij heeft een schrijfpoort voor de CPU-kant en de VGA-pinnen aan de andere kant.

```{.verilog include="beeld/video_out.v"}
```

Er zijn drie stappen en elk kost een klok:

```text
   klok 0:  tellers geven x, y   →  adres berekend  →  RAM krijgt het adres
   klok 1:  RAM geeft het byte   →  nibble kiezen   →  palette-opzoeking (zwart buiten het beeld)
   klok 2:  uitgangsregisters laten rgb, hsync en vsync los
```

De sync- en actief-signalen komen uit dezelfde tellers als het adres, maar de pixeldata komt een klok later uit het RAM. Als we de syncsignalen niet net zo lang vertragen, loopt het beeld een pixel voor op de sync. Daarom gaan `active`, `hsync`, `vsync` en het nibble-bit `bx[0]` door het register `act1, hs1, vs1, odd1` voordat ze met de data samenkomen. Dit is het principe van week 27 (alles wat bij elkaar hoort even lang vertragen), nu in de praktijk: een pijplijn is pas goed als alle takken dezelfde diepte hebben.

Dat dit klopt, is te controleren: laat in `video_out.v` de vertraging van `hsync` weg (`hsync <= hs;`) en `tb_video_out` geeft meteen fouten, met een pixelverschuiving.

## 6. De registers voor de CPU

De CPU ziet het beeld als vier geheugenplaatsen. Het datageheugen van W8F heeft maar 256 adressen (8 bit), en 240 daarvan zijn RAM, dus we kunnen het framebuffer van 9 600 bytes niet direct in de adresruimte leggen. Daarom werken we met een pointer en een datapoort: de CPU zet eerst het adres in twee registers, en schrijft daarna bytes naar één datapoort die het adres zelf ophoogt (auto-increment).

| Adres | Naam | Gedrag |
|:-----:|------|--------|
| `0xF8` | FB_LO | laag byte van het adres in het framebuffer (lezen en schrijven) |
| `0xF9` | FB_HI | hoog byte, 6 bit (lezen en schrijven) |
| `0xFA` | FB_DATA | schrijven: zet dit byte (twee pixels) op het adres en tel het adres 1 op |
| `0xFB` | VID_STATUS | lezen: bit 0 is 1 als de monitor in de verticale blanking zit |

Het adres loopt van 0 tot 9 599 (`0x257F`). De module houdt zich eraan: een schrijfactie op een adres vanaf 9 600 wordt genegeerd, en het adres loopt niet verder op. Dat voorkomt dat een programma dat een paar bytes te ver schrijft het beeld aan de andere kant laat terugkomen. We hebben het nodig in week 30: 19 blokken van 512 bytes geven 9 728 bytes, iets meer dan de 9 600 die we nodig hebben.

```{.verilog include="beeld/video_io.v"}
```

Het register `vb1, vb2` is de synchronizer van `vblank`. Het signaal komt uit het klokdomein van het beeld en wordt door twee flipflops in het CPU-domein gehaald, zodat de CPU het veilig kan lezen.

## 7. Een laagje om de bestaande geheugenkaart

We willen `mmio_f` (de geheugenkaart met UART, timer en GPIO uit week 22 en 24) niet veranderen. Zijn tests slagen, en het is goed om werkende code met rust te laten. In plaats daarvan leggen we er een laagje omheen. `mmio_v` bevat een `mmio_f` en een `video_io`, en kijkt naar de bovenste zes adresbits: zijn het `111110` (adressen `0xF8` tot en met `0xFB`), dan is het voor het beeld, anders voor `mmio_f`.

```{.verilog include="beeld/mmio_v.v"}
```

Eén ding vraagt aandacht. Bij W8F duurt een `LD` drie klokken: de CPU biedt het adres aan, het geheugen en de apparaten houden hun antwoord een klok vast, en in de derde klok neemt de CPU de waarde over. Ons nieuwe apparaat moet dezelfde afspraak volgen, en dat doet het door `v_q` en `vsel_q` te registreren zoals `mmio_f` dat met zijn eigen waarden doet. Sla je dat over, dan leest de CPU een klok te vroeg of te laat en zie je willekeurige waarden. Zo'n fout is moeilijk te vinden zonder golfvorm.

De CPU zelf wordt `cpu_v`: dezelfde `cpu_f` van week 24, met drie aanpassingen. Het bestand is een kopie van `cpu_fpga/cpu_f.v` met deze wijzigingen:

```text
  module cpu_f #(...       →  module cpu_v #(...
  output [7:0] gpio_out    →  + input vblank, output fb_we, output [13:0] fb_waddr, output [7:0] fb_wdata
  mmio_f #(...) io(...)    →  mmio_v #(...) io(..., vblank, fb_we, fb_waddr, fb_wdata)
```

Zo blijft de bestaande CPU onaangeroerd en ziet de nieuwe versie er bijna hetzelfde uit.

## 8. Alles aan elkaar

De top verbindt de CPU met het beeld. Er zijn twee klokken, dus ook twee resets. Een reset is een asynchroon signaal (de knop) en moet in elk klokdomein synchroon eindigen, anders kan een deel van de flipflops net wel en een deel net niet uit reset komen. Dat is `reset_sync`: twee flipflops, hetzelfde als in week 23.

```{.verilog include="beeld/reset_sync.v"}
```

```{.verilog include="beeld/beeld_v.v"}
```

## 9. Het eerste programma

Het eerste programma vult het scherm met 16 verticale balken, een voor elke kleur in de palette. Het gebruikt een trucje dat je in elk programma voor deze computer terugziet: één register (`R3`) bevat het basisadres `0xF0` van de apparaten, en alle apparaten worden benaderd als `[R3 + offset]`. De offsets van de tabel staan dan rechtstreeks in de code (`+8` voor FB_LO, `+10` voor FB_DATA). Dat past in de 6 bit offset van `LD` en `ST` en bespaart een `LDI` bij elke toegang.

```{.text include="beeld/kleurbalken.asm"}
```

Het byte `0x00` is twee zwarte blokken, `0x11` twee blauwe, tot `0xFF` (wit): de hoge en lage nibble zijn gelijk, dus beide pixels hebben dezelfde kleur. Elke balk is 5 bytes (10 blokken, 40 schermpixels) breed, en 16 balken zijn 80 bytes, dus precies een rij.

## 10. Testen

Er zijn drie testbenches, van klein naar groot.

`tb_video_io` kijkt alleen naar de registers via de buslijnen, zoals de CPU dat doet: adres instellen, auto-increment, de grens bij 9 600 en de vblank-status.

```{.verilog include="beeld/tb_video_io.v"}
```

`tb_video_out` zet een patroon rechtstreeks in het framebuffer (zonder CPU) en controleert elke pixel van het scherm via de virtuele monitor. De twee klokken zijn bewust ongelijk (12 MHz en 25,125 MHz): de testbench laat zien dat de brug tussen de twee klokken werkt. Het patroon is een functie van het byteadres, zodat een verkeerd adres of een omgewisselde nibble meteen opvalt.

```{.verilog include="beeld/tb_video_out.v"}
```

`tb_beeld_v` laat de CPU het programma uitvoeren en controleert wat er op het scherm komt:

```{.verilog include="beeld/tb_beeld_v.v"}
```

### Streng genoeg?

Net als vorige week hebben we fouten in het ontwerp gebracht om te zien of de tests ze vangen.

| Fout | Wat de tests zeggen |
|------|---------------------|
| hoge en lage nibble omgewisseld in `video_out` | `tb_video_out`: pixel (3,0) is blauw in plaats van zwart |
| `hsync` niet vertraagd, de rest wel | `tb_video_out`: het hele beeld ligt een pixel verschoven, de eerste fout is pixel (16,0) |
| `vsync` niet vertraagd | geen enkele test merkt het (een klok verschil in `vsync` ligt ver van de `hsync`-flank en verandert niet welke lijn als eerste telt) |
| het adres loopt niet op na een schrijfactie in `video_io` | `tb_video_io`: "schrijf op 4661" krijgt het verkeerde adres |

De kleurbalken zijn in 6,5 ms klaar op een CPU-klok van 12 MHz. Dat is 77 760 klokken voor 9 600 bytes, ruim 8 per byte. De binnenste lus (`ST`, `ADDI`, `BNE`) kost er 6, de rest is overhead per balk en per rij. Het scherm wordt in 16,7 ms ververst, dus de CPU kan het hele framebuffer in minder dan één beeld vullen. Dat is niet slecht voor 12 MHz.

## 11. Lab

1. Draai de tests van fase 7 (`python3 test_labs.py beeld`) en zoek de PASS-regels van `tb_video_io`, `tb_video_out` en `tb_beeld_v`.
2. Zet `build/kleurbalken.ppm` om naar PNG (`ppm2png.py`, week 27) en bekijk hem. Zie je 16 balken?
3. Verander in `kleurbalken.asm` het aantal bytes per balk van 5 in 4. Het scherm wordt niet meer volledig gevuld. Wat ziet de test en wat zie je in de afbeelding?
4. Schrijf een programma dat het scherm vult met een dambord van 8 x 8 blokken, afwisselend zwart en wit. Pas `tb_beeld_v` aan zodat hij het dambord controleert.
5. Laat in `video_out.v` de vertraging van `hsync` weg (`hsync <= hs;`). Welke test valt om en waar zie je de fout? Laat daarna de vertraging van `vsync` weg. Valt er nu een test om? Wat zegt dat over de tests?

## 12. Oefeningen

1. Hoeveel bits en bytes heeft een framebuffer van 160 x 120 met 4 bit per pixel? En van 320 x 240 met 4 bit? En van 160 x 120 met 8 bit?
2. Welk byteadres en welke nibble horen bij het schermpixel (300, 200)? Welke waarden komen in FB_HI en FB_LO om daar te schrijven?
3. Waarom heeft FB_HI maar 6 bit nodig? Wat is `9 600` in hexadecimaal?
4. Het framebuffer bestaat uit blok-RAM's van 4 kbit. Hoeveel heb je er nodig voor 9 600 bytes? (Tip: een blok kan 512 bytes bevatten bij een woordbreedte van 8 bit.)
5. Waarom werkt een synchronizer wel voor `vblank` maar niet voor het adres of de data van het framebuffer?
6. Op de UP5K zou je graag twee framebuffers willen hebben (dubbele buffering: teken in de een, toon de ander). Past dat in het blok-RAM? Wat is een ander geheugen op de chip waar het wel in zou passen?
7. Waarom negeert `video_io` schrijfacties vanaf adres 9 600 in plaats van het adres te laten rondgaan?
8. Wat gebeurt er op het scherm als de CPU precies schrijft op het moment dat de monitor dat byte leest? Is dat erg?
9. Uitdaging: maak de palette schrijfbaar. Voeg 16 registers van 12 bit toe die de CPU via vier bytes (twee per kleur) kan instellen. Wat verandert er in `video_out` en `video_io`? In welk klokdomein hoort de palette?
10. Uitdaging: voeg een vlak-vulcommando toe: de CPU schrijft een kleur en een lengte, en de hardware vult zelf die bytes. Hoeveel CPU-tijd bespaart dat voor het vullen van het hele scherm?

## 13. Antwoorden

1. 160 x 120 x 4 = 76 800 bit = 9 600 bytes. 320 x 240 x 4 = 307 200 bit = 38 400 bytes. 160 x 120 x 8 = 153 600 bit = 19 200 bytes.
2. Blok: bx = 300 / 4 = 75, by = 200 / 4 = 50. Byte: 50 x 80 + 75 / 2 = 4 000 + 37 = 4 037 (`0x0FC5`). `bx` = 75 is oneven, dus de lage nibble. FB_HI = `0x0F`, FB_LO = `0xC5`.
3. 9 600 is kleiner dan 16 384 (2^14), dus 14 bit zijn genoeg: 8 in FB_LO, 6 in FB_HI. 9 600 is `0x2580`, dus het hoogste geldige adres 9 599 is `0x257F` en FB_HI is hooguit `0x25`.
4. 9 600 / 512 = 18,75, dus 19 blokken. (Samen met het datageheugen van de CPU geeft dat de 20 blokken die Yosys vindt.)
5. Een synchronizer van twee flipflops werkt voor één bit: de kans op een onbepaalde waarde wordt klein en de uitkomst is 0 of 1, nooit iets ertussen. Voor een woord kunnen de bits op verschillende klokken aankomen, zodat je een byte krijgt die nooit bestaan heeft. Het adres en de data horen daarom in een RAM met twee poorten, waarvan de chip de overgang regelt.
6. Twee framebuffers zijn 2 x 19 = 38 blokken, en de UP5K heeft er 30. Dat past niet. De UP5K heeft ook vier SPRAM's van 256 kbit (128 KB in totaal) die er wel in passen, maar die hebben één poort en een eigen interface. Het zou dus een aparte ontwerpstap zijn.
7. Zonder die grens loopt het adres rond na 16 383 en komt een lange reeks bytes vanzelf terug aan het begin, zodat een programma dat te veel schrijft het beeld overschrijft. Met de grens is het gedrag nul en netjes: te veel schrijven doet niets. Die eigenschap gebruiken we in week 30.
8. Het blok-RAM kan dan oud of nieuw teruggeven, of een mengsel. Het is niet erg: hooguit één blok heeft één beeld lang een verkeerde kleur. Wil je dat vermijden, schrijf dan in de verticale blanking (`VID_STATUS`).
9. De palette wordt een klein RAM van 16 woorden van 12 bit, geschreven door de CPU en gelezen door het beeld. Dat is weer een brug tussen twee klokken en hoort dus een RAM met twee poorten te zijn, net als het framebuffer. De `case` in `video_out` verdwijnt, en `video_io` krijgt registers voor de palette-index en de kleurdata.
10. Dit is een open opdracht. Een vlakvuller is een eerste stap naar een blitter, een stuk hardware dat het framebuffer opvult terwijl de CPU wat anders doet. Het hele scherm vullen kost nu 9 600 `ST`-instructies, ongeveer 6 ms. Met een vulling in hardware kost het twee of drie schrijfacties.

## 14. Zelftest

1. Waarom kiezen we 160 x 120 in plaats van 640 x 480?
2. Wat is een palette?
3. Wat moet er gebeuren met de syncsignalen als het geheugen een klok vertraging heeft?
4. Hoe komt een enkel bit veilig in een ander klokdomein, en hoe een byte?
5. Waarom gebruikt de CPU een pointer met auto-increment in plaats van het framebuffer direct in de adresruimte?

Antwoorden: (1) 640 x 480 met 12 bit is 460 KB en past niet in 120 kbit blok-RAM; 160 x 120 met 4 bit is 9,6 KB. (2) Een tabel die een pixelwaarde van 4 bit omzet naar een kleur van 12 bit. (3) Ze moeten even lang vertraagd worden, anders loopt het beeld voor op de sync. (4) Een bit via twee flipflops (synchronizer), een byte via een RAM met twee poorten. (5) De adresruimte van W8F is 256 bytes, en daarvan is bijna alles bezet. Een pointer en een datapoort hebben maar vier adressen nodig.

## 15. Verder lezen

- Clifford Cummings, *Clock Domain Crossing (CDC) Design and Verification Techniques*: de standaardtekst over klokdomeinen.
- De iCE40 sysMEM-handleiding van Lattice: hoe het blok-RAM met twee klokken werkt, en wat er gebeurt bij gelijktijdig lezen en schrijven op hetzelfde adres.
- Voor een kijkje in de geschiedenis: de EGA- en VGA-kaarten uit de jaren tachtig deden ongeveer wat wij nu doen, met een palette en een framebuffer.

---

> **De CPU kan tekenen.** Het scherm heeft een geheugen waar de CPU in schrijft, en de brug tussen de twee klokken is getest. Wat nog ontbreekt is iets om dat geheugen mee te vullen dat niet in het programma zelf zit.

Volgende week: SPI, de manier waarop de CPU met een SD-kaart praat.
