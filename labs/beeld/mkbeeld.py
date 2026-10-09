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
