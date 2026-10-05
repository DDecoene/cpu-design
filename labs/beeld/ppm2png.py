# FILE: beeld/ppm2png.py
#!/usr/bin/env python3
"""Zet een binaire PPM (P6) om naar PNG, zodat je het beeld uit de simulatie in een gewone viewer kunt openen. Alleen standaardbibliotheek.

Gebruik:  python3 ppm2png.py in.ppm uit.png [schaal]      bijvoorbeeld schaal 2 om het beeld te halveren (elke 2e pixel)
"""
import struct, sys, zlib


def lees_ppm(pad):
    data = open(pad, "rb").read()
    delen = data.split(None, 4)
    if delen[0] != b"P6" or int(delen[3]) != 255:
        raise SystemExit("verwacht een binaire PPM (P6) met 8 bit per kleur")
    w, h = int(delen[1]), int(delen[2])
    return w, h, delen[4]


def chunk(naam, inhoud):
    c = struct.pack(">I", len(inhoud)) + naam + inhoud
    return c + struct.pack(">I", zlib.crc32(naam + inhoud) & 0xFFFFFFFF)


def schrijf_png(pad, w, h, pixels):
    rijen = b"".join(b"\x00" + pixels[y * w * 3:(y + 1) * w * 3] for y in range(h))   # filtertype 0 voor elke rij
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(rijen)) + chunk(b"IEND", b""))
    open(pad, "wb").write(png)


def verklein(w, h, pixels, k):
    """Houd elke k-de pixel in elke richting over."""
    nw, nh = len(range(0, w, k)), len(range(0, h, k))
    out = bytearray()
    for y in range(0, h, k):
        for x in range(0, w, k):
            out += pixels[(y * w + x) * 3:(y * w + x) * 3 + 3]
    return nw, nh, bytes(out)


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    w, h, px = lees_ppm(argv[1])
    k = int(argv[3]) if len(argv) > 3 else 1
    if k > 1:
        w, h, px = verklein(w, h, px, k)
    schrijf_png(argv[2], w, h, px)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
