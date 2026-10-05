# FILE: beeld/test_ppm2png.py
#!/usr/bin/env python3
"""Test van ppm2png.py: een klein PPM-bestand omzetten en de PNG weer uitpakken."""
import os, struct, subprocess, sys, tempfile, zlib

fouten = 0
def check(ok, tekst):
    global fouten
    if not ok:
        fouten += 1
        print("FAIL:", tekst)

def lees_png(pad):
    data = open(pad, "rb").read()
    check(data[:8] == b"\x89PNG\r\n\x1a\n", "PNG-handtekening")
    pos, idat, w, h = 8, b"", 0, 0
    while pos < len(data):
        n, naam = struct.unpack(">I4s", data[pos:pos + 8])
        inhoud = data[pos + 8:pos + 8 + n]
        crc = struct.unpack(">I", data[pos + 8 + n:pos + 12 + n])[0]
        check(crc == zlib.crc32(naam + inhoud) & 0xFFFFFFFF, f"CRC van chunk {naam}")
        if naam == b"IHDR": w, h = struct.unpack(">II", inhoud[:8])
        if naam == b"IDAT": idat += inhoud
        pos += 12 + n
    raw = zlib.decompress(idat)
    return w, h, b"".join(raw[y * (w * 3 + 1) + 1:(y + 1) * (w * 3 + 1)] for y in range(h))

with tempfile.TemporaryDirectory() as t:
    pixels = bytes([255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255,      # rij 0: rood, groen, blauw, wit
                    0, 0, 0, 10, 20, 30, 40, 50, 60, 70, 80, 90])          # rij 1
    ppm, png = os.path.join(t, "a.ppm"), os.path.join(t, "a.png")
    open(ppm, "wb").write(b"P6\n4 2\n255\n" + pixels)
    r = subprocess.run([sys.executable, "ppm2png.py", ppm, png], capture_output=True, text=True)
    check(r.returncode == 0, "ppm2png.py faalt: " + r.stderr)
    w, h, px = lees_png(png)
    check((w, h) == (4, 2) and px == pixels, "de pixels komen ongewijzigd terug")
    r = subprocess.run([sys.executable, "ppm2png.py", ppm, png, "2"], capture_output=True, text=True)
    w, h, px = lees_png(png)
    check((w, h) == (2, 1) and px == pixels[0:3] + pixels[6:9], "schaal 2 houdt elke tweede pixel over")

if fouten == 0:
    print("PASS: ppm2png zet een PPM om naar een geldige PNG")
sys.exit(1 if fouten else 0)
