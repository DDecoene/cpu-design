---
title: "Week 23 · FPGA's: je CPU in echte hardware"
---

<p class="subtitle">Fase 6 · Van code naar chip · ongeveer 14 uur</p>

# Week 23: FPGA's: je CPU in echte hardware

## Wat je na deze week kunt

- uitleggen wat een FPGA is en waaruit hij bestaat (LUT's, flipflops, routering, blok-RAM, IO)
- de open-sourcestroom volgen: synthese, plaatsen en routeren, bitstream en programmeren
- een toplevel maken voor een bord, met klok, reset, LED's en seriële poort
- begrijpen waarom code die in simulatie werkt, in synthese verrassend kan falen
- de synthesetool lezen: hoeveel LUT's en flipflops kost je ontwerp en haalt het de klok?

> **Wat in deze week getest is.** De hele softwareketen van deze week is uitgevoerd en getest: synthese, plaatsen en routeren, het maken van een bitstream en een simulatie van de gesynthetiseerde netlijst. Het laden van een bitstream op een fysiek FPGA-bord en een LED zien knipperen is niet getest. Voor dat laatste stuk (de pinnen van jouw bord en het programmeren) volg je de documentatie van je bord. Waar iets getest is, staat dat erbij.

## 1. Wat is een FPGA?

Een FPGA (field-programmable gate array) is een chip vol onbepaalde digitale hardware, die je met een bestand (de bitstream) tot elke digitale schakeling kunt maken. Elke keer dat je de bitstream laadt, wordt de chip een andere schakeling: een CPU, een UART of een videochip.

Een FPGA bestaat uit een paar soorten bouwstenen, die je allemaal al kent:

| Bouwsteen | Wat | Uit welke week |
|-----------|-----|----------------|
| LUT (lookup table) | een kleine tabel die elke logische functie van 4 ingangen kan zijn: 16 bits geheugen | week 3 en 8: een ROM als logica |
| Flipflop | onthoudt een bit, bij elke LUT hoort er een | week 5 |
| Routering | programmeerbare draden en schakelaars die alles verbinden | week 4 (multiplexers) |
| Blok-RAM | ingebouwde geheugenblokken (kilobits) | week 8 |
| IO-cellen | verbinden met de pinnen | |
| PLL | maakt andere klokfrequenties | |
| DSP (bij grotere chips) | vaste vermenigvuldigers | week 12 |

Het idee van de LUT is mooi: elke functie van vier ingangen is een tabel van 16 bits. Je schrijft de tabel in de LUT en je hebt de functie. Het is het "ROM als logica" uit week 8, miljoenen keren herhaald. Een logisch element (LE of LC) is een LUT met een flipflop erachter:

```text
   4 ingangen ──► [ LUT: 16-bit tabel ] ──► [ flipflop ] ──► uitgang
                                      └────────────────────► (of zonder flipflop)
```

### FPGA, CPLD of ASIC?

| | FPGA | ASIC (eigen chip) |
|--|------|-------------------|
| Kosten per ontwerp | laag (een bord van een paar tientallen euro) | hoog (maskers van duizenden tot miljoenen euro's, tenzij gedeeld, zie week 26) |
| Aanpasbaarheid | direct opnieuw te programmeren | onmogelijk na productie |
| Snelheid en energie | trager en minder zuinig | veel beter |
| Wanneer | prototypes, lage aantallen | massaproductie |

Een FPGA is dus perfect om een CPU-ontwerp in echte hardware te testen voordat je er een chip van maakt.

## 2. De open-sourcestroom

```text
  Verilog ──► Yosys ──► netlijst ──► nextpnr ──► plaatsing en routering ──► bitstream ──► bord
  (synthese)            (LUT's en FF's)  (place & route)                      (programmeren)
```

| Stap | Gereedschap | Wat gebeurt er |
|------|-------------|----------------|
| Synthese | Yosys | zet je Verilog om in LUT's, flipflops, carry-ketens en geheugens van de doel-FPGA |
| Plaatsen en routeren | nextpnr | kiest voor elk element een plek op de chip en routeert de draden; meet de snelheid |
| Bitstream | `icepack` (iCE40), `ecppack` (ECP5), `gowin_pack` (Gowin) | maakt het bestand voor de chip |
| Programmeren | `openFPGALoader`, `iceprog` | laadt het bestand in het bord |

Fabrikanten leveren zware grafische omgevingen (Vivado, Quartus, Radiant, Gowin EDA) van gigabytes groot. De open-sourcetools zijn veel kleiner en draaien in de terminal. Ze ondersteunen onder andere Lattice iCE40, ECP5 en Gowin.

### Installeren zonder je computer vol te zetten

Je wilt waarschijnlijk niets onnodigs installeren. De tools bestaan als Python-pakketten (YoWASP) die je in een afgesloten virtuele omgeving kunt gebruiken:

```text
python3 -m venv ~/fpga-venv
~/fpga-venv/bin/pip install yowasp-yosys yowasp-nextpnr-ice40
```

Alles staat in die ene map. Wil je het kwijt, dan verwijder je die: `rm -r ~/fpga-venv`. Er is geen Java en er is geen installatie voor het hele systeem nodig. (Om een bord echt te programmeren heb je daarnaast een programmer nodig, bijvoorbeeld `openFPGALoader`. Die installeer je pas als je een bord hebt.)

## 3. Welk bord?

Een bord kiezen is een persoonlijke afweging. Hieronder staan opties die goed samengaan met open-sourcetools. Prijzen en beschikbaarheid veranderen, dus controleer actuele informatie.

| Familie | Voorbeeld | Opmerking |
|---------|-----------|-----------|
| Lattice iCE40 | iCEBreaker, iCESugar, UPduino (UP5K, 5 280 LUT's), HX8K-borden | zeer goede ondersteuning, en de tools die voor deze cursus getest zijn |
| Gowin | Tang Nano 9K (rond de €20 tot €30), 8 640 LUT's | zeer goedkoop, ondersteund door de Apicula-tools, iets nieuwer |
| Lattice ECP5 | ULX3S, Colorlight-borden | groter (tot 85 000 LUT's), goed voor grotere ontwerpen |

Een advies: kies het goedkoopste bord waarvoor je een goede handleiding vindt. Je CPU is klein genoeg voor alles hierboven (de FPGA-vriendelijke versie uit week 24 past op een UP5K).

## 4. Het toplevel

Je CPU weet niets van een bord. Een toplevel verbindt hem met de pinnen: de klok van het bord (bijvoorbeeld 27 MHz), een resetknop, LED's (op veel borden actief laag: 0 = aan) en een seriële poort via de USB-aansluiting van het bord.

Let op de resetsynchronizer. Een knop is asynchroon. Hij mag asynchroon activeren, maar moet synchroon met de klok loslaten, anders kunnen delen van je CPU in verschillende cycli uit reset komen. Twee flipflops (week 6) regelen dat.

De parameters `DIV` en `TDIV` rekenen we uit de klokfrequentie: `DIV = CLK_HZ / BAUD` (klokcycli per UART-bit) en `TDIV = CLK_HZ / 1000` (cycli per milliseconde).


```{.verilog include="cpu_irq/fpga_top.v"}
```

### Een programma voor het bord

Het programma stuurt eerst "W8 OK" via de UART (je ziet dat in een terminal) en laat daarna de LED elke 250 ms knipperen met de timer-interrupt:

```{.text include="cpu_irq/hello.asm"}
```

### De testbench voor het toplevel

In de simulatie gebruiken we een kleine klok (16 000 Hz, 1 000 baud) zodat de test snel is, en een onafhankelijke UART-ontvanger die de lijn afluistert:

```{.verilog include="cpu_irq/tb_fpga_top.v"}
```

## 5. Een les uit de praktijk: alles verdwijnt

Een eerste synthese van deze CPU leverde iets onverwachts op: de hele CPU was weg. Yosys meldde een ontwerp met nul LUT's, de LED-uitgangen vast op 1 en de seriële uitgang vast op 1. De simulatie slaagde, maar de synthese gaf een lege chip.

Dit was er gebeurd. In `imem` stond:

```text
initial begin
  for (i = 0; i < 256; i = i + 1) mem[i] = 16'hA000;   // alles NOP
  if (LOAD) $readmemh(FILE, mem);                       // dan het programma
end
```

In een simulator werkt dat zoals je verwacht: eerst alles NOP en dan wordt het programma erover geladen. Maar een synthesetool vertaalt `initial` niet als programma, maar als beginwaarde van het geheugen, en bij twee tegenstrijdige beginwaarden voor dezelfde plaats won de eerste. Het resultaat was dat het geheugen alleen NOP's bevatte. De CPU deed nooit iets, en Yosys concludeerde (terecht) dat geen enkele uitgang ooit zou veranderen en gooide alles weg.

De oplossing is een ondubbelzinnige initialisatie, die je nu in `memories.v` (week 14) ziet:

```text
initial begin
  if (LOAD) $readmemh(FILE, mem);                       // het bestand bevat alle 256 woorden
  else for (i = 0; i < 256; i = i + 1) mem[i] = 16'hA000;
end
```

Wat je hieruit leert:

1. Dat de simulatie slaagt, betekent niet dat de synthese hetzelfde ontwerp maakt. Hoe controleer je dat? Met een gate-level simulatie van de netlijst (week 24).
2. Een leeg resultaat na synthese is bijna altijd een teken dat de tool een constante heeft ontdekt. Kijk of de uitgangen echt van je logica afhangen.
3. In `initial`-blokken die geheugen vullen mag je per plaats maar één waarde geven.

## 6. De flow in de praktijk

Het script voert synthese, plaatsen en routeren en het maken van de bitstream uit. Het maakt de virtuele omgeving zelf aan als die ontbreekt.

```{.bash include="cpu_irq/fpga_flow.sh"}
```

Gebruik:

```text
cd labs/cpu_irq
bash fpga_flow.sh hx8k
```

De meting van deze CPU (W8I uit week 22) op een iCE40 HX8K met 27 MHz als doel:

| Gegeven | Waarde |
|---------|--------|
| LUT4 | 3 202 |
| Flipflops | 2 148 |
| Gebruikte logische elementen (LC) | 5 297 van 7 680 (69 %) |
| Blok-RAM | 0 |
| Maximale klokfrequentie | ongeveer 34 MHz |

Dat haalt 27 MHz ruim. Op de kleinere UP5K (5 280 LC's) past hij niet: nextpnr stopt met de foutmelding dat er niet genoeg logische elementen zijn.

Het opvallende is hoeveel ruimte dit ontwerp kost. Een CPU met 8 registers en een kleine ALU hoort veel kleiner te zijn. Waar zit het? Dat is het onderwerp van week 24.

## 7. De pinnen en het bord

Een bitstream voor een echte chip heeft een pinbestand nodig dat zegt welke signalen op welke pin zitten. Het formaat verschilt per toolchain. Hieronder zie je het idee voor iCE40 (`.pcf`):

```text
set_io clk        35
set_io btn_rst_n  10
set_io led_n[0]   99
set_io uart_tx     6
set_io uart_rx     9
```

De getallen hierboven zijn placeholders. Zoek de echte pinnummers in de handleiding of het schema van je bord. Meestal staan ze in een tabel "pin assignments". Geef het bestand aan het script mee met `PCF=bord.pcf bash fpga_flow.sh up5k`.

Zodra je de bitstream (`.bin`) hebt, laad je hem met de programmer van je bord. De seriële poort verschijnt op je computer als een apparaat (bijvoorbeeld `/dev/tty.usbserial-...` op een Mac). Open die met `screen /dev/tty.usbserial-XXXX 115200` en druk op de resetknop: je ziet W8 OK.

## 8. Lab

1. Maak de virtuele omgeving en draai `bash fpga_flow.sh hx8k`. Noteer LUT's, flipflops en de maximale frequentie.
2. Draai `bash fpga_flow.sh up5k`. Wat is de melding en waarom past het niet?
3. Zoek in `pnr.log` het deel "Critical path report". Welke onderdelen van de CPU liggen erop? Hoeveel van de tijd gaat naar logica en hoeveel naar routering?
4. Kies een bord (of bekijk de documentatie van een kandidaat) en zoek de klokfrequentie, de LED-polariteit en de pinnen. Schrijf het pinbestand.
5. Verander de baudrate in `fpga_top.v` naar 9600. Welke `DIV` krijg je bij 27 MHz en wat is de fout?

## 9. Oefeningen

1. Een LUT heeft 4 ingangen. Hoeveel bits heeft zijn tabel? Hoeveel verschillende functies kan hij zijn?
2. Hoeveel LUT's heb je minimaal nodig voor een 8-bit opteller zonder carry-ketens? (Een full adder heeft 3 ingangen en 2 uitgangen.) Waarom gebruikt een FPGA toch speciale carry-ketens?
3. Een UART op 115 200 baud met een klok van 27 MHz: bereken `DIV` en de fout. Mag de fout 3 % zijn?
4. Waarom is de resetknop-synchronizer nodig? Beschrijf een foutscenario zonder.
5. Leg in je eigen woorden uit waarom de eerste synthese een lege chip gaf en hoe je dat had kunnen ontdekken zonder de tool.
6. Een bord heeft LED's die oplichten bij een 1 op de pin (actief hoog) in plaats van een 0. Wat verander je in `fpga_top.v`?
7. Uitdaging: sluit het GPIO-ingangsregister (`0xF6`) aan op de knoppen van je bord en schrijf een programma dat de knopstatus naar de LED's kopieert.

## 10. Antwoorden

1. 2⁴ = 16 bits. Elke bit is de uitkomst voor één ingangscombinatie, dus er zijn 2¹⁶ = 65 536 verschillende functies.
2. Per bit zijn er twee uitgangen (som en carry) met drie ingangen: twee LUT's per bit, dus 16 LUT's voor 8 bits. Maar de carry loopt door alle bits en kost zonder speciale hardware veel routering en tijd. Een FPGA heeft daarom speciale snelle carry-ketens tussen aangrenzende logische elementen.
3. DIV = 27 000 000 / 115 200 = 234,4, dus 234. De werkelijke baudrate is 115 385 en de fout 0,16 %. Dat is ruim onder de 3 %.
4. Zonder synchronizer kan de resetknop net rond een klokflank loslaten. Sommige flipflops zien de reset dan al weg en andere nog niet, waardoor de CPU in een inconsistente toestand begint (bijvoorbeeld de PC al gelopen, het instructieregister nog niet). De synchronizer laat de reset voor alle flipflops in dezelfde klokperiode los.
5. Het geheugen kreeg in de synthese tegenstrijdige beginwaarden en werd een ROM met alleen NOP's. De CPU was daardoor een teller die nooit iets doet. Je ontdekt zoiets door te kijken of de uitvoer van de synthese niet leeg is, of de aantallen LUT's logisch zijn voor je ontwerp en door een gate-level simulatie van de netlijst te draaien.
6. Haal de inversie weg: `assign led = gpio_out[5:0];` (of hernoem de poort).
7. Een eenvoudige aanpak is in een lus `LD R0,[0xF6]` en `ST R0,[0xF5]` te gebruiken. Je moet het adres eerst in een register zetten (`LDI R1,0xF6`).

## 11. Zelftest

1. Wat is een LUT?
2. Welke stappen heeft de open-source FPGA-stroom?
3. Waarom is de resetsynchronizer nodig?
4. Wat betekent het als de synthese een lege chip oplevert?
5. Hoe bereken je `DIV` voor de UART?

Antwoorden: (1) Een kleine tabel (16 bits) die elke functie van vier ingangen kan zijn. (2) Synthese (Yosys), plaatsen en routeren (nextpnr), bitstream (icepack of vergelijkbaar) en programmeren. (3) Zodat alle flipflops in dezelfde klokcyclus uit reset komen. (4) De tool heeft ontdekt dat de uitgangen constant zijn, bijvoorbeeld doordat een geheugen of beginwaarde verkeerd is. (5) De klokfrequentie gedeeld door de baudrate.

## 12. Verder lezen

- De documentatie van Yosys en nextpnr, vooral de "Yosys Manual".
- Project Apicula (Gowin) en Project IceStorm (iCE40): hoe chips van fabrikanten zijn ontleed tot open tools. Een fascinerend verhaal.
- De video's van Ben Eater en het materiaal van Nandland en FPGA4Fun voor praktische FPGA-oefeningen.

Volgende week: je CPU past, maar kost veel te veel. We leren de uitvoer van de synthese lezen, vinden de oorzaak en maken hem 6 keer kleiner en 40 % sneller.
