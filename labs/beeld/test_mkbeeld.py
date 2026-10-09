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
