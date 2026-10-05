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

```python
# FILE: beeld/mkbeeld.py
#!/usr/bin/env python3
"""Maakt het beeld voor de beeldcomputer: 160 x 120 pixels, 16 kleuren, twee pixels per byte (de linker in de hoge nibble).

Gebruik:  python3 mkbeeld.py demo [uit]       maakt het ingebouwde testbeeld (een smiley)
          python3 mkbeeld.py foto.ppm [uit]   zet een PPM-bestand (P6, 160 x 120) om naar de 16 kleuren van de palette

Er komen twee bestanden uit, zonder extensie op te geven:  <uit>.img (de ruwe bytes voor de SD-kaart) en <uit>.hex (een byte per regel,
voor de simulatie). Standaard is <uit> gelijk aan 'sd'. Beide worden aangevuld tot een veelvoud van 512 bytes, een SD-blok.
"""
import sys

W, H = 160, 120
BLOCK = 512

# De palette: moet gelijk zijn aan de palette in video_out.v (4 bit per kleurkanaal). test_mkbeeld.py controleert dat.
PALETTE = [
    (0x0, 0x0, 0x0), (0x0, 0x0, 0xA), (0x0, 0xA, 0x0), (0x0, 0xA, 0xA),
    (0xA, 0x0, 0x0), (0xA, 0x0, 0xA), (0xA, 0x5, 0x0), (0xA, 0xA, 0xA),
    (0x5, 0x5, 0x5), (0x5, 0x5, 0xF), (0x5, 0xF, 0x5), (0x5, 0xF, 0xF),
    (0xF, 0x5, 0x5), (0xF, 0x5, 0xF), (0xF, 0xF, 0x5), (0xF, 0xF, 0xF),
]
ZWART, BLAUW, BRUIN, DONKERGRIJS, GEEL, WIT = 0, 1, 6, 8, 14, 15


def dichtstbij(r, g, b):
    """Index van de palettekleur die het dichtst bij (r, g, b) ligt (0..255 per kanaal)."""
    best, beste = 0, None
    for i, (pr, pg, pb) in enumerate(PALETTE):
        d = (r - pr * 17) ** 2 + (g - pg * 17) ** 2 + (b - pb * 17) ** 2
        if beste is None or d < beste:
            best, beste = i, d
    return best


def pak(indices):
    """Lijst van W*H paletteindexen (rij voor rij) -> bytes, twee pixels per byte."""
    assert len(indices) == W * H
    return bytes((indices[i] << 4) | indices[i + 1] for i in range(0, len(indices), 2))


def pak_uit(data):
    """De omgekeerde bewerking van pak: bytes -> lijst van W*H indexen."""
    out = []
    for byte in data[: W * H // 2]:
        out += [byte >> 4, byte & 15]
    return out


def demo():
    """Een smiley op een blauwe achtergrond met een witte rand, een raster en onderaan alle 16 kleuren."""
    px = [BLAUW] * (W * H)

    def zet(x, y, k):
        if 0 <= x < W and 0 <= y < H:
            px[y * W + x] = k

    for y in range(H):
        for x in range(W):
            if x % 20 == 0 or y % 20 == 0:
                zet(x, y, DONKERGRIJS)                       # raster om de 20 pixels
            d2 = (x - 80) ** 2 + (y - 52) ** 2
            if d2 <= 40 ** 2:
                zet(x, y, GEEL)                             # gezicht
            if 38 ** 2 < d2 <= 40 ** 2:
                zet(x, y, ZWART)                            # rand van het gezicht
            for ex in (66, 94):                             # ogen
                if (x - ex) ** 2 + (y - 42) ** 2 <= 5 ** 2:
                    zet(x, y, ZWART)
            m2 = (x - 80) ** 2 + (y - 54) ** 2              # mond: een halve ring onder het midden
            if 20 ** 2 <= m2 <= 24 ** 2 and y >= 58:
                zet(x, y, ZWART)
    for k in range(16):                                      # palettestrook: 16 vakjes van 10 pixels
        for y in range(106, 116):
            for x in range(k * 10, k * 10 + 10):
                zet(x, y, k)
    for x in range(W):                                       # witte rand van 1 pixel rondom
        zet(x, 0, WIT); zet(x, H - 1, WIT)
    for y in range(H):
        zet(0, y, WIT); zet(W - 1, y, WIT)
    return px


def lees_ppm(pad):
    data = open(pad, "rb").read()
    delen = data.split(None, 4)
    if delen[0] != b"P6":
        raise SystemExit("alleen binaire PPM (P6) wordt ondersteund")
    w, h, maxval = int(delen[1]), int(delen[2]), int(delen[3])
    if (w, h) != (W, H):
        raise SystemExit(f"het beeld is {w} x {h}, maar moet {W} x {H} zijn (bijvoorbeeld: magick foto.png -resize {W}x{H}! foto.ppm)")
    px = delen[4]
    assert maxval == 255 and len(px) == W * H * 3
    return [dichtstbij(px[3 * i], px[3 * i + 1], px[3 * i + 2]) for i in range(W * H)]


def schrijf(data, basis):
    data = data + bytes(-len(data) % BLOCK)
    open(basis + ".img", "wb").write(data)
    open(basis + ".hex", "w").write("".join(f"{b:02X}\n" for b in data))
    return len(data) // BLOCK


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    indices = demo() if argv[1] == "demo" else lees_ppm(argv[1])
    basis = argv[2] if len(argv) > 2 else "sd"
    blokken = schrijf(pak(indices), basis)
    print(f"{basis}.img en {basis}.hex: {blokken} blokken van {BLOCK} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

De palette in Python moet gelijk zijn aan die in `video_out.v`, anders komen de kleuren van je foto er anders uit dan je verwacht. Daarom leest de test de palette uit het Verilog-bestand en vergelijkt hem met die in Python. Zo'n controle is goedkoop en voorkomt een soort fout die je op het scherm moeilijk terugvindt.

```python
# FILE: beeld/test_mkbeeld.py
#!/usr/bin/env python3
"""Test van mkbeeld.py: dezelfde palette als de hardware, de omzetting heen en terug, de demo en de PPM-invoer.
Maakt als bijproduct sd.img en sd.hex, die de testbench van de complete computer inlaadt."""
import re, subprocess, sys, os, tempfile
import mkbeeld as m

fouten = 0
def check(ok, tekst):
    global fouten
    if not ok:
        fouten += 1
        print("FAIL:", tekst)

# 1. De palette in Python is dezelfde als in video_out.v.
verilog = open("video_out.v").read()
uit_verilog = {}
for nr, hexwaarde in re.findall(r"4'd(\d+):\s*palette = 12'h([0-9A-F]{3});", verilog):
    uit_verilog[int(nr)] = tuple(int(c, 16) for c in hexwaarde)
m15 = re.search(r"default:\s*palette = 12'h([0-9A-F]{3});", verilog)
uit_verilog[15] = tuple(int(c, 16) for c in m15.group(1))
check(len(uit_verilog) == 16, "16 kleuren in video_out.v verwacht")
check([uit_verilog[i] for i in range(16)] == m.PALETTE, "de palette in mkbeeld.py wijkt af van video_out.v")

# 2. Inpakken en uitpakken.
voorbeeld = [(i * 7 + i // 160) % 16 for i in range(m.W * m.H)]
check(m.pak_uit(m.pak(voorbeeld)) == voorbeeld, "pak en pak_uit zijn elkaars omgekeerde")
check(m.pak([1, 2] * (m.W * m.H // 2))[0] == 0x12, "de linker pixel staat in de hoge nibble")

# 3. De demo: afmetingen, rand, gezicht, palettestrook.
d = m.demo()
check(len(d) == m.W * m.H, "demo heeft 19200 pixels")
check(d[0] == m.WIT and d[m.W * m.H - 1] == m.WIT, "witte hoeken")
check(d[52 * m.W + 80] == m.GEEL, "midden van het gezicht is geel")
check(d[42 * m.W + 66] == m.ZWART, "linkeroog is zwart")
check(all(d[110 * m.W + k * 10 + 5] == k for k in range(16)), "palettestrook toont alle 16 kleuren")

# 4. De PPM-invoer: elke palettekleur wordt zichzelf, en een bijna-gelijke kleur gaat naar de dichtstbijzijnde.
with tempfile.TemporaryDirectory() as t:
    pad = os.path.join(t, "in.ppm")
    kleuren = [m.PALETTE[i % 16] for i in range(m.W * m.H)]
    ruwe = b"".join(bytes([r * 17, g * 17, b * 17]) for r, g, b in kleuren)
    open(pad, "wb").write(b"P6\n160 120\n255\n" + ruwe)
    check(m.lees_ppm(pad) == [i % 16 for i in range(m.W * m.H)], "PPM met palettekleuren geeft dezelfde indexen")
    for kleur, index, naam in (((250, 10, 10), 4, "rood"), ((250, 90, 85), 12, "lichtrood"), ((5, 5, 5), 0, "zwart")):
        open(pad, "wb").write(b"P6\n160 120\n255\n" + bytes(kleur) * (m.W * m.H))
        check(set(m.lees_ppm(pad)) == {index}, f"{kleur} wordt {naam} (index {index})")
    open(pad, "wb").write(b"P6\n80 60\n255\n" + bytes(80 * 60 * 3))
    r = subprocess.run([sys.executable, "mkbeeld.py", pad, os.path.join(t, "x")], capture_output=True, text=True)
    check(r.returncode != 0 and "160" in (r.stdout + r.stderr), "een PPM met een verkeerd formaat wordt geweigerd")

# 5. De bestanden voor de SD-kaart.
r = subprocess.run([sys.executable, "mkbeeld.py", "demo", "sd"], capture_output=True, text=True)
check(r.returncode == 0, "mkbeeld.py demo faalt: " + r.stderr)
img = open("sd.img", "rb").read()
check(len(img) == 19 * 512, f"sd.img is {len(img)} bytes, verwacht {19 * 512}")
check(m.pak_uit(img) == d, "sd.img bevat de demo")
hexregels = open("sd.hex").read().split()
check(len(hexregels) == len(img) and bytes(int(h, 16) for h in hexregels) == img, "sd.hex is gelijk aan sd.img")
check(img[9600:] == bytes(len(img) - 9600), "het eind van het laatste blok is nul")

if fouten == 0:
    print("PASS: palette gelijk aan de hardware, inpakken heen en terug, demo, PPM-omzetting en SD-bestanden")
sys.exit(1 if fouten else 0)
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

```verilog
// FILE: beeld/sd_model.v
// Een SD-kaart in SPI-modus, alleen voor simulatie. Hij kent precies de commando's die ons bootprogramma nodig heeft:
//   CMD0  (reset)               -> R1 = 0x01 (idle)         vereist de CRC 0x95
//   CMD8  (spanning/versie)     -> R1 = 0x01 + 4 bytes      vereist argument 0x1AA en CRC 0x87
//   CMD55 + ACMD41 (opstarten)  -> R1 = 0x01 enkele keren, dan 0x00 (klaar)
//   CMD17 (lees een blok)       -> R1 = 0x00, enkele 0xFF, token 0xFE, 512 bytes, 2 CRC-bytes   (SDHC: adres is een bloknummer)
// Net als een echte kaart antwoordt hij pas na een of meer 0xFF-bytes, en alleen terwijl CS laag is. De inhoud komt uit een hex-bestand.
module sd_model #(
  parameter FILE = "sd.hex",
  parameter BYTES = 9728,          // grootte van de inhoud in het bestand (19 blokken); daarachter geeft de kaart 0xFF
  parameter ACMD41_TRIES = 3,      // zoveel keer meldt de kaart nog 'idle'
  parameter NCR = 2,               // aantal 0xFF-bytes voor het antwoord (een echte kaart: 0 tot 8)
  parameter NAC = 3                // aantal 0xFF-bytes tussen R1 en het datatoken van CMD17
) (
  input  sclk,
  input  mosi,
  input  cs_n,
  output miso
);
  reg [7:0] flash [0:BYTES-1];     // de inhoud van de kaart
  reg [7:0] cmd [0:5];
  reg [7:0] uit [0:2047];          // wachtrij met bytes die de kaart nog gaat sturen
  integer q_w = 0, q_r = 0;
  integer cmd_n = 0, sclk_cs_hoog = 0, bit_n = 0, acmd41_n = 0, i, blok;
  reg [7:0] in_sh = 0, out_sh = 8'hFF;
  reg app = 0;
  // Wat de testbench controleert:
  reg idle = 1;                    // 1 tot ACMD41 geslaagd is
  reg gereset = 0, v2 = 0;
  integer fout_init = 0, fout_crc = 0, fout_volgorde = 0, blokken = 0;
  integer blok_log [0:63];

  assign miso = cs_n ? 1'b1 : out_sh[7];

  initial begin
    $readmemh(FILE, flash);
  end

  task zet(input [7:0] b); begin uit[q_w % 2048] = b; q_w = q_w + 1; end endtask
  task antwoord(input [7:0] r1); begin repeat (NCR) zet(8'hFF); zet(r1); end endtask

  task commando;
    reg [31:0] arg; reg [5:0] nr;
    begin
      nr = cmd[0][5:0]; arg = {cmd[1], cmd[2], cmd[3], cmd[4]};
      if (nr != 0 && !gereset) begin fout_volgorde = fout_volgorde + 1; antwoord(8'h05); end
      else case (nr)
        0: begin
             if (sclk_cs_hoog < 74) fout_init = fout_init + 1;       // eerst minstens 74 klokpulsen met CS hoog
             if (cmd[5] !== 8'h95) begin fout_crc = fout_crc + 1; antwoord(8'h09); end
             else begin gereset = 1; idle = 1; antwoord(8'h01); end
           end
        8: begin
             if (cmd[5] !== 8'h87 || arg !== 32'h1AA) begin fout_crc = fout_crc + 1; antwoord(8'h05); end
             else begin v2 = 1; antwoord(8'h01); zet(8'h00); zet(8'h00); zet(8'h01); zet(8'hAA); end
           end
        55: begin app = 1; antwoord(idle ? 8'h01 : 8'h00); end
        41: begin
              if (!app) antwoord(8'h05);
              else if (!v2 || arg[30] !== 1'b1) antwoord(8'h01);                   // zonder HCS-bit wordt de kaart nooit klaar
              else begin
                acmd41_n = acmd41_n + 1;
                if (acmd41_n > ACMD41_TRIES) begin idle = 0; antwoord(8'h00); end
                else antwoord(8'h01);
              end
            end
        17: begin
              if (idle) begin fout_volgorde = fout_volgorde + 1; antwoord(8'h05); end
              else begin
                blok = arg;
                if (blokken < 64) blok_log[blokken] = blok;
                blokken = blokken + 1;
                antwoord(8'h00);
                repeat (NAC) zet(8'hFF);
                zet(8'hFE);
                for (i = 0; i < 512; i = i + 1) zet(blok * 512 + i < BYTES ? flash[blok * 512 + i] : 8'hFF);
                zet(8'hDE); zet(8'hAD);                                            // de CRC wordt niet gecontroleerd
              end
            end
        default: antwoord(8'h05);
      endcase
      if (nr != 55) app = 0;
    end
  endtask

  task byte_klaar(input [7:0] b);
    begin
      if (cmd_n > 0) begin
        cmd[cmd_n] = b; cmd_n = cmd_n + 1;
        if (cmd_n == 6) begin cmd_n = 0; commando; end
      end else if (b[7:6] == 2'b01) begin cmd[0] = b; cmd_n = 1; end        // 01xxxxxx begint een commando; 0xFF is een leeg byte
    end
  endtask

  task volgende_uit;
    begin
      if (q_r < q_w) begin out_sh = uit[q_r % 2048]; q_r = q_r + 1; end
      else out_sh = 8'hFF;
    end
  endtask

  always @(posedge sclk) begin
    if (cs_n) sclk_cs_hoog = sclk_cs_hoog + 1;
    else begin
      in_sh = {in_sh[6:0], mosi};                       // de kaart leest MOSI op de stijgende flank
      bit_n = bit_n + 1;
      if (bit_n == 8) begin bit_n = 0; byte_klaar(in_sh); end
    end
  end
  always @(negedge sclk) if (!cs_n) begin               // en zet MISO na de dalende flank
    if (bit_n == 0) volgende_uit; else out_sh = {out_sh[6:0], 1'b1};
  end
  always @(negedge cs_n) begin bit_n = 0; volgende_uit; end
  always @(posedge cs_n) begin cmd_n = 0; q_r = q_w; end       // CS hoog: een lopend antwoord of lopende datablok vervalt
endmodule
```

## 5. Het bootprogramma

Het programma past in 101 van de 256 instructies die de CPU heeft. Het gebruikt twee hulproutines en een datagebied met de commando's.

De commando's van zes bytes staan als gegevens in het datageheugen (`.data`) en worden bij de reset geladen, zoals de tekst in `hello.asm` in week 23. Zo hoeven we geen zes `LDI`'s per commando te schrijven. Alleen CMD17 verandert: het bloknummer in de laatste argumentbyte wordt na elk blok met één opgehoogd.

Hulproutines:

- **`xfer`**: stuur het byte in `R0` over SPI, wacht tot de poort klaar is, en geef het ontvangen byte terug in `R0`.
- **`cmd`**: stuur de zes bytes waar `R2` naar wijst, en lees daarna maximaal 16 bytes tot er een byte komt met bit 7 gelijk aan nul. Dat byte is R1 en komt terug in `R0`. Komt er in 16 bytes geen antwoord, dan is `R0` gelijk aan `0xFF` en schiet de vergelijking van de aanroeper daar op af.

`cmd` roept zelf `xfer` aan, en `CALL` bewaart het terugkeeradres in `R7`. De tweede `CALL` zou `R7` dus overschrijven. Daarom kopieert `cmd` `R7` eerst naar `R5` en keert het terug met `JR R5`. Dit is een kleine versie van wat een compiler met een stapel doet.

De LED's (GPIO) tonen waar het programma is: 1 tot 5 voor de stappen, `0x10` als alles klaar is, en bit 7 erbij als er iets misgaat. Zo kun je met een bord zonder scherm toch zien waar het mis ging.

```text
; FILE: beeld/boot.asm
; Het bootprogramma van de beeldcomputer: start de SD-kaart op, lees 19 blokken van 512 bytes en zet ze in het framebuffer.
; De LED's (GPIO) laten zien waar het programma is: 1 = klokpulsen, 2 = CMD0 gelukt, 3 = CMD8 gelukt (de kaart start op),
; 4 = kaart klaar, 5 = bezig met lezen, 0x10 = klaar. Bit 7 erbij betekent: fout in die stap.
;
; Registers: R3 = 0xF0 (basis van alle apparaten), R7 = terugkeeradres (CALL), R0 = byte voor/na een SPI-overdracht.
;
; Datageheugen: de zes bytes van elk SD-commando (commandobyte, 4 bytes argument, CRC). Alleen CMD0 en CMD8 hebben een echte CRC nodig.
        .data 0x10, 0x40, 0x00, 0x00, 0x00, 0x00, 0x95     ; CMD0  (GO_IDLE_STATE)
        .data 0x16, 0x48, 0x00, 0x00, 0x01, 0xAA, 0x87     ; CMD8  (SEND_IF_COND), argument 0x1AA
        .data 0x1C, 0x77, 0x00, 0x00, 0x00, 0x00, 0x01     ; CMD55 (APP_CMD)
        .data 0x22, 0x69, 0x40, 0x00, 0x00, 0x00, 0x01     ; ACMD41 (SD_SEND_OP_COND), HCS-bit gezet
        .data 0x28, 0x51, 0x00, 0x00, 0x00, 0x00, 0x01     ; CMD17 (READ_SINGLE_BLOCK); bloknummer in de bytes op 0x2B en 0x2C

start:  LDI  R3, 0xF0
        LDI  R0, 1
        ST   R0, [R3+5]         ; LED's: stap 1
        ST   R0, [R3+13]        ; SPI_CTRL: CS hoog (niet geselecteerd), langzame klok
        LDI  R4, 10             ; 10 bytes = 80 klokpulsen met CS hoog: de kaart zet zich in SPI-modus
init:   LDI  R0, 0xFF
        CALL xfer
        ADDI R4, -1
        BNE  init
        LDI  R0, 0
        ST   R0, [R3+13]        ; CS laag: kaart geselecteerd

        LDI  R2, 0x10
        CALL cmd                ; CMD0
        CMPI R0, 0x01           ; verwacht R1 = 0x01 (idle)
        BNE  fout
        LDI  R0, 2
        ST   R0, [R3+5]

        LDI  R2, 0x16
        CALL cmd                ; CMD8
        CMPI R0, 0x01
        BNE  fout
        LDI  R4, 4              ; de rest van het antwoord (4 bytes) lezen en weggooien
r7:     LDI  R0, 0xFF
        CALL xfer
        ADDI R4, -1
        BNE  r7
        LDI  R0, 3
        ST   R0, [R3+5]

opstart: LDI R2, 0x1C
        CALL cmd                ; CMD55: het volgende commando is een 'applicatiecommando'
        LDI  R2, 0x22
        CALL cmd                ; ACMD41
        CMPI R0, 0x00           ; 0x01 = nog bezig met opstarten, probeer opnieuw; 0x00 = klaar
        BNE  opstart
        LDI  R0, 4
        ST   R0, [R3+5]
        LDI  R0, 2
        ST   R0, [R3+13]        ; CS laag en nu de snelle klok

        LDI  R0, 5
        ST   R0, [R3+5]
        LDI  R4, 19             ; 19 blokken van 512 bytes = 9728 bytes, genoeg voor de 9600 bytes van het beeld
blok:   LDI  R2, 0x28
        CALL cmd                ; CMD17
        CMPI R0, 0x00
        BNE  fout
token:  LDI  R0, 0xFF
        CALL xfer
        CMPI R0, 0xFE           ; wacht op het datatoken
        BNE  token
        LDI  R5, 2              ; 512 bytes = 2 x 256
ronde:  LDI  R1, 0              ; 0 telt 256 keer af tot 0 (8 bit)
data:   LDI  R0, 0xFF
        CALL xfer
        ST   R0, [R3+10]        ; FB_DATA: byte (twee pixels) naar het framebuffer
        ADDI R1, -1
        BNE  data
        ADDI R5, -1
        BNE  ronde
        LDI  R0, 0xFF
        CALL xfer               ; twee CRC-bytes lezen en weggooien
        LDI  R0, 0xFF
        CALL xfer
        LDI  R2, 0x2C           ; het bloknummer in het CMD17-commando met 1 ophogen
        LD   R0, [R2]
        ADDI R0, 1
        ST   R0, [R2]
        ADDI R4, -1
        BNE  blok

        LDI  R0, 3
        ST   R0, [R3+13]        ; CS hoog
        LDI  R0, 0xFF
        CALL xfer               ; nog 8 klokpulsen zodat de kaart loslaat
        LDI  R0, 0x10
        ST   R0, [R3+5]         ; klaar
        HALT

fout:   LD   R0, [R3+5]         ; het stapnummer behouden en bit 7 zetten
        LDI  R1, 0x80
        OR   R0, R0, R1
        ST   R0, [R3+5]
        HALT

; xfer: stuur R0 over SPI en wacht tot het klaar is. Terug in R0: het ontvangen byte.
xfer:   ST   R0, [R3+12]        ; SPI_DATA
xwacht: LD   R6, [R3+14]        ; SPI_STATUS
        CMPI R6, 0
        BNE  xwacht
        LD   R0, [R3+12]
        RET

; cmd: stuur het commando van 6 bytes waar R2 naar wijst en wacht op R1 (het eerste byte met bit 7 = 0). Terug in R0: R1.
; Bij een time-out (16 bytes zonder antwoord) is R0 = 0xFF. R5 bewaart het terugkeeradres, want xfer overschrijft R7.
cmd:    MOV  R5, R7
        LDI  R1, 6
cbyte:  LD   R0, [R2]
        CALL xfer
        ADDI R2, 1
        ADDI R1, -1
        BNE  cbyte
        LDI  R1, 16
cantw:  LDI  R0, 0xFF
        CALL xfer
        CMPI R0, 0x80
        BLO  cklaar             ; kleiner dan 0x80: dit is het antwoord
        ADDI R1, -1
        BNE  cantw
cklaar: JR   R5
```

Wat dit programma niet doet:

- Geen time-out op ACMD41. Een kaart die nooit klaar meldt, laat het programma eindeloos lussen met `0x03` op de LED's. Dit is een bewuste keuze om het kort te houden (oefening 6).
- Geen controle op de CRC van de datablokken.
- Geen ondersteuning voor kaarten tot 2 GB (byteadressering).
- Geen herstel bij een fout: het stopt (`HALT`) met een foutcode.

## 6. De hele computer

De top verbindt alles: de CPU met SPI en video, het framebuffer, de VGA-uitgang en de SD-kaart. Het is `beeld_v` van week 28 met `cpu_b` in plaats van `cpu_v`, en de SPI-pinnen naar buiten.

```verilog
// FILE: beeld/beeld_top.v
// De complete beeldcomputer: CPU, SPI naar de SD-kaart, framebuffer en VGA-uitgang.
// Het programma staat in boot.hex (instructies) en boot.dat (de commando's voor de kaart in het datageheugen).
module beeld_top #(
  parameter PROG = "boot.hex", parameter DATA = "boot.dat", parameter DLOAD = 1,
  parameter DIV = 104, parameter TDIV = 12000            // 12 MHz: 115 200 baud en een timertik van 1 ms
) (
  input        clk,          // CPU-klok, 12 MHz
  input        pclk,         // pixelklok, ongeveer 25 MHz
  input        rst_n,
  output       hsync, vsync,
  output [3:0] r, g, b,
  output       sd_sclk, sd_mosi, sd_cs_n,
  input        sd_miso,
  output [7:0] led,
  output       txd,
  input        rxd
);
  wire rst_cpu, rst_pix;
  reset_sync rs_cpu(.clk(clk),  .rst_n_in(rst_n), .rst_n_out(rst_cpu));
  reset_sync rs_pix(.clk(pclk), .rst_n_in(rst_n), .rst_n_out(rst_pix));

  wire        vblank, fb_we;
  wire [13:0] fb_waddr;
  wire [7:0]  fb_wdata;

  cpu_b #(PROG, 1, DIV, TDIV, DATA, DLOAD) cpu(
    .clk(clk), .rst_n(rst_cpu), .halted(),
    .pc_out(), .r0(), .r1(), .r2(), .r3(), .r4(), .r5(), .r6(), .r7(),
    .flag_z(), .flag_n(), .flag_c(), .flag_v(),
    .txd(txd), .rxd(rxd), .gpio_in(8'h00), .gpio_out(led),
    .vblank(vblank), .fb_we(fb_we), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata),
    .spi_sclk(sd_sclk), .spi_mosi(sd_mosi), .spi_cs_n(sd_cs_n), .spi_miso(sd_miso)
  );

  video_out vid(
    .pclk(pclk), .rst_n(rst_pix),
    .wclk(clk), .we(fb_we), .waddr(fb_waddr), .wdata(fb_wdata),
    .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .vblank(vblank)
  );
endmodule
```

De testbench zet het kaartmodel (met het demobeeld) aan de SPI-pinnen, laat het bootprogramma lopen en wacht tot de LED's `0x10` tonen. Dan controleert hij:

- wat de kaart gezien heeft: de goede volgorde, de CRC's, 74 of meer klokpulsen, geen lees-commando vóór de kaart klaar was, en blokken 0 tot en met 18, elk precies één keer en in volgorde
- dat de SPI-klok tijdens het opstarten niet sneller was dan 400 kHz
- elke pixel van het scherm (307 200 stuks) tegen wat er volgens het bestand moet staan, met een eigen kopie van de palette

```verilog
// FILE: beeld/tb_beeld_top.v
`timescale 1ns/1ps
// De hele beeldcomputer: een SD-kaartmodel met het demobeeld, het bootprogramma op de CPU, en de virtuele monitor.
// Gecontroleerd wordt het gedrag naar de kaart toe (volgorde, klokpulsen, snelheid, blokken) en het beeld dat op het scherm komt.
module tb_beeld_top;
  reg clk = 0, pclk = 0, rst_n = 0;
  wire hsync, vsync, sd_sclk, sd_mosi, sd_cs_n, sd_miso, txd, frame_done;
  wire [3:0] r, g, b;
  wire [7:0] led;
  wire [31:0] frames;
  integer fouten = 0, x, y, i, bx, klokken = 0, vorige = 0, korst = 1000000;
  reg [7:0] kaart [0:9727];
  reg [7:0] byte_i;
  reg [11:0] pal [0:15], verwacht;
  reg [31:0] f0;
  realtime t_lezen = 0, t_klaar = 0;

  beeld_top dut(.clk(clk), .pclk(pclk), .rst_n(rst_n), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b),
                .sd_sclk(sd_sclk), .sd_mosi(sd_mosi), .sd_cs_n(sd_cs_n), .sd_miso(sd_miso), .led(led), .txd(txd), .rxd(1'b1));
  sd_model card(.sclk(sd_sclk), .mosi(sd_mosi), .cs_n(sd_cs_n), .miso(sd_miso));
  vga_mon mon(.pclk(pclk), .hsync(hsync), .vsync(vsync), .r(r), .g(g), .b(b), .frame_done(frame_done), .frames(frames));
  always #41.667 clk = ~clk;
  always #19.9 pclk = ~pclk;
  always @(posedge clk) klokken = klokken + 1;
  always @(led) if (led === 8'h05) t_lezen = $realtime;       // stap 5: het lezen van de blokken begint

  // De SD-specificatie vraagt tijdens het opstarten een klok van hoogstens 400 kHz: minstens 30 klokken van 12 MHz tussen twee flanken.
  always @(posedge sd_sclk) begin
    if (card.idle && vorige != 0 && klokken - vorige < 30) begin
      fouten = fouten + 1; $display("FAIL: SCLK te snel tijdens het opstarten: periode %0d klokken", klokken - vorige);
    end
    vorige = klokken;
  end

  initial begin
    $readmemh("sd.hex", kaart);
    pal[0]=12'h000; pal[1]=12'h00A; pal[2]=12'h0A0; pal[3]=12'h0AA; pal[4]=12'hA00; pal[5]=12'hA0A; pal[6]=12'hA50; pal[7]=12'hAAA;
    pal[8]=12'h555; pal[9]=12'h55F; pal[10]=12'h5F5; pal[11]=12'h5FF; pal[12]=12'hF55; pal[13]=12'hF5F; pal[14]=12'hFF5; pal[15]=12'hFFF;
    #200 rst_n = 1;
    wait (led[4] === 1'b1 || led[7] === 1'b1);                // klaar of fout
    t_klaar = $realtime;
    $display("LED's = %b; opstarten van de kaart: %0.1f ms, de 19 blokken lezen: %0.1f ms", led, t_lezen / 1.0e6, (t_klaar - t_lezen) / 1.0e6);
    if (led !== 8'h10) begin fouten = fouten + 1; $display("FAIL: LED's %b, verwacht 00010000 (klaar)", led); end

    // wat de kaart zag
    if (card.fout_init  !== 0) begin fouten = fouten + 1; $display("FAIL: CMD0 kwam voor minstens 74 klokpulsen met CS hoog"); end
    if (card.fout_crc   !== 0) begin fouten = fouten + 1; $display("FAIL: een commando had een verkeerde CRC"); end
    if (card.fout_volgorde !== 0) begin fouten = fouten + 1; $display("FAIL: een commando kwam in de verkeerde volgorde"); end
    if (card.blokken !== 19) begin fouten = fouten + 1; $display("FAIL: %0d blokken gelezen, verwacht 19", card.blokken); end
    if (card.blokken === 19) for (i = 0; i < 19; i = i + 1)
      if (card.blok_log[i] !== i) begin fouten = fouten + 1; $display("FAIL: leesactie %0d vroeg blok %0d", i, card.blok_log[i]); end
    if (sd_cs_n !== 1'b1) begin fouten = fouten + 1; $display("FAIL: CS moet aan het eind hoog zijn"); end

    // wat er op het scherm staat: het eerste volledige beeld erna is nieuw genoeg, we nemen het tweede
    f0 = frames;
    wait (frames == f0 + 2);
    #1;
    if (mon.painted_last !== 640 * 480) begin fouten = fouten + 1; $display("FAIL: %0d pixels geschilderd", mon.painted_last); end
    for (y = 0; y < 480; y = y + 1)
      for (x = 0; x < 640; x = x + 1) begin
        bx = x / 4;
        byte_i = kaart[(y / 4) * 80 + bx / 2];
        verwacht = pal[(bx % 2 == 0) ? byte_i[7:4] : byte_i[3:0]];
        if (mon.img[y*640 + x] !== verwacht && fouten < 10) begin
          fouten = fouten + 1; $display("FAIL: pixel (%0d,%0d) is %h, verwacht %h", x, y, mon.img[y*640 + x], verwacht);
        end
      end
    mon.write_ppm("../../build/beeld.ppm");
    if (fouten == 0) $display("PASS: de computer start de kaart op, leest 19 blokken en toont het beeld");
    $finish;
  end

  initial begin #200_000_000 $display("FAIL: time-out, LED's = %b", led); $finish; end
endmodule
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
| het kaartmodel wacht 17 bytes (`NCR = 17`) voor hij antwoordt, meer dan het programma wil afwachten | `tb_beeld_top`: LED's `10000001`, dus stap 1, fout: CMD0 kreeg geen antwoord. (De specificatie staat hoogstens 8 toe; het programma geeft er 16.) |
| de master leest MISO op de verkeerde flank (week 29) | al `tb_spi` faalt, lang voor deze test |

## 7. Naar de FPGA

Het ontwerp past op de UP5K. Voor een echt bord komen er drie dingen bij: een PLL die de pixelklok uit de 12 MHz maakt, een toplevel met de pinnen, en een pinbestand. Die staan in `labs/beeld_fpga/` en gebruiken chipspecifieke onderdelen, dus Icarus kan ze niet simuleren.

De PLL volgt uit het hulpprogramma `icepll -i 12 -o 25.175`, dat 25,125 MHz geeft (VCO 804 MHz, gedeeld door 32). De reset blijft actief tot de PLL vergrendeld is.

```verilog
// FILE: beeld_fpga/pll_ice40.v
// De pixelklok uit de 12 MHz van het bord, met de PLL van de iCE40. De getallen komen van het hulpprogramma icepll:
//   icepll -i 12 -o 25.175   geeft 25,125 MHz (VCO 804 MHz, gedeeld door 32). Dat ligt 0,2 % onder de standaard 25,175 MHz.
// Dit bestand gebruikt een primitief van de chip en kan daarom niet in Icarus Verilog gesimuleerd worden.
module pll_ice40(
  input  clk_in,
  output clk_out,
  output locked
);
  SB_PLL40_CORE #(
    .FEEDBACK_PATH("SIMPLE"),
    .DIVR(4'b0000),            // referentie: 12 MHz / (DIVR + 1)
    .DIVF(7'b1000010),         // VCO: 12 MHz * (DIVF + 1) = 12 * 67 = 804 MHz
    .DIVQ(3'b101),             // uitgang: VCO / 2^DIVQ = 804 / 32 = 25,125 MHz
    .FILTER_RANGE(3'b001)
  ) pll (
    .REFERENCECLK(clk_in),
    .PLLOUTCORE(clk_out),
    .LOCK(locked),
    .RESETB(1'b1),
    .BYPASS(1'b0)
  );
endmodule
```

```verilog
// FILE: beeld_fpga/ice40_top.v
// Het toplevel voor een iCE40 UP5K-bord met een klok van 12 MHz (bijvoorbeeld de iCEBreaker), een VGA-module met 4 bit per kleur
// en een microSD-module. De CPU draait op de 12 MHz van het bord, het beeld op de 25,125 MHz van de PLL.
module ice40_top(
  input        clk12,
  input        btn_n,                 // resetknop (0 = ingedrukt)
  output [3:0] vga_r, vga_g, vga_b,
  output       vga_hs, vga_vs,
  output       sd_sck, sd_mosi, sd_cs,
  input        sd_miso,
  output [7:0] led,                   // statusstappen van het bootprogramma; sluit aan wat je bord heeft
  output       uart_tx,
  input        uart_rx
);
  wire pclk, locked;
  pll_ice40 pll(.clk_in(clk12), .clk_out(pclk), .locked(locked));

  // Zolang de PLL niet vergrendeld is, houden we alles in reset. De knop werkt zoals altijd actief laag.
  wire rst_n = btn_n & locked;

  beeld_top #(.DIV(104), .TDIV(12000)) top(          // 12 MHz: 115 200 baud en een timertik van 1 ms
    .clk(clk12), .pclk(pclk), .rst_n(rst_n),
    .hsync(vga_hs), .vsync(vga_vs), .r(vga_r), .g(vga_g), .b(vga_b),
    .sd_sclk(sd_sck), .sd_mosi(sd_mosi), .sd_cs_n(sd_cs), .sd_miso(sd_miso),
    .led(led), .txd(uart_tx), .rxd(uart_rx)
  );
endmodule
```

Het script voert dezelfde stappen uit als in week 23 en 24: synthese met Yosys, plaatsen en routeren met nextpnr, en een bitstream met icepack. Het gebruikt alleen de bestanden die op de chip komen en laat de testbenches, de virtuele monitor en het kaartmodel buiten de deur.

```bash
# FILE: beeld_fpga/flow.sh
#!/bin/bash
# Synthese, plaatsen en routeren en een bitstream voor de beeldcomputer op een iCE40 UP5K, met de open-source tools.
# Gebruik:  bash flow.sh          (vanuit labs/beeld_fpga; de bronbestanden staan in ../beeld)
# Omgevingsvariabelen:  VENV=map met de virtuele omgeving   PCF=pinbestand van je bord   SEED=startwaarde voor het plaatsen
set -e
VENV=${VENV:-$HOME/fpga-venv}
SEED=${SEED:-1}
SRC=$(cd ../beeld && pwd)                       # absoluut, want we gaan zo naar uit/

# Dezelfde afgesloten Python-omgeving als in week 23 (wordt aangemaakt als hij nog niet bestaat)
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet yowasp-yosys yowasp-nextpnr-ice40
fi
YOSYS="$VENV/bin/yowasp-yosys"; NEXTPNR="$VENV/bin/yowasp-nextpnr-ice40"; PACK="$VENV/bin/yowasp-icepack"

mkdir -p uit && cd uit
python3 "$SRC/asm.py" "$SRC/boot.asm"        # boot.hex en boot.dat komen naast boot.asm
cp "$SRC/boot.hex" prog.hex                  # Yosys leest de standaardnamen ook; ze moeten bestaan
cp "$SRC/boot.dat" data.hex
cp "$SRC/boot.hex" "$SRC/boot.dat" .

# Alleen de synthetiseerbare bestanden: de testbenches, de virtuele monitor en het SD-model blijven buiten de chip.
V=""
for f in alu idecode memories memories_f datapath_i control_f mmio_f mmio_v mmio_b cpu_b video_io spi_io spi_master \
         fb_ram video_out vga_sync reset_sync beeld_top; do V="$V $SRC/$f.v"; done
V="$V ../pll_ice40.v ../ice40_top.v"

echo "=== synthese"
"$YOSYS" -q -l synth.log -p "read_verilog -sv $V; synth_ice40 -flatten -top ice40_top -json top.json; tee -o stat.txt stat"
grep -E "SB_LUT4|SB_DFF|SB_RAM40|SB_CARRY|SB_PLL" stat.txt

echo "=== plaatsen en routeren (UP5K, 12 MHz als doel voor de CPU-klok)"
PINS="--pcf-allow-unconstrained"
[ -n "$PCF" ] && PINS="--pcf ../$PCF"
[ -z "$PCF" ] && echo "LET OP: zonder PCF kiest nextpnr zelf pinnen. Goed om te meten, niet om op een bord te laden."
"$NEXTPNR" --up5k --package sg48 --json top.json --asc top.asc --freq 12 $PINS --seed "$SEED" -l pnr.log -q || true
grep -E "ICESTORM_LC:|ICESTORM_RAM:" pnr.log | tail -2
grep -E "Max frequency" pnr.log | tail -2
echo "(de pixelklok moet minstens 25,125 MHz halen, de CPU-klok minstens 12 MHz)"

if [ -f top.asc ]; then
  "$PACK" top.asc top.bin && echo "=== bitstream: uit/top.bin ($(wc -c < top.bin) bytes)"
fi
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

```text
# FILE: beeld_fpga/beeld_voorbeeld.pcf
# Voorbeeld van een pinbestand voor nextpnr (iCE40). Kopieer naar beeld.pcf en vul de pinnen in uit het schema van je bord
# en de handleidingen van je VGA- en microSD-module. De getallen ontbreken met opzet: ik heb geen van deze borden gebruikt.
# Gebruik:  PCF=beeld.pcf bash flow.sh
set_io clk12      ??        # klokingang van het bord (12 MHz)
set_io btn_n      ??        # resetknop
set_io vga_r[0]   ??        # VGA-module: vier bits per kleur, hs en vs
set_io vga_r[1]   ??
set_io vga_r[2]   ??
set_io vga_r[3]   ??
set_io vga_g[0]   ??
set_io vga_g[1]   ??
set_io vga_g[2]   ??
set_io vga_g[3]   ??
set_io vga_b[0]   ??
set_io vga_b[1]   ??
set_io vga_b[2]   ??
set_io vga_b[3]   ??
set_io vga_hs     ??
set_io vga_vs     ??
set_io sd_sck     ??        # microSD-module in SPI-modus: SCK, MOSI, MISO en CS
set_io sd_mosi    ??
set_io sd_miso    ??
set_io sd_cs      ??
set_io led[0]     ??        # statusled's: sluit aan wat je bord heeft
set_io uart_tx    ??
set_io uart_rx    ??
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

1. Draai alle tests van fase 7: `python3 extract_labs.py beeld`. Het duurt ongeveer een minuut. Zoek de tien regels met `ok` (twee Python-tests en acht testbenches).
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
9. `0x82` is stap 2 met de foutbit: CMD0 lukte en CMD8 niet, wat meestal een kaart van SD 1.x is. `0x03` dat blijft staan is stap 3: de ACMD41-lus is nog bezig, en de kaart meldt steeds 'idle'.
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
