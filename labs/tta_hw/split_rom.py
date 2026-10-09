"""Splitst een TTA-programma (tta_asm.py maakt 24-bit-woorden in een .hex-bestand) in drie binaire bestanden van
256 bytes, één per EEPROM: hoog (guard + bestemming), midden (bron) en laag (constante).
Gebruik:  python3 split_rom.py programma.hex        ->  programma_hi.bin, programma_mid.bin, programma_lo.bin"""
import sys


def split(words):
    hi = bytes((w >> 16) & 0xFF for w in words)
    mid = bytes((w >> 8) & 0xFF for w in words)
    lo = bytes(w & 0xFF for w in words)
    return hi, mid, lo


def lees_hex(pad):
    woorden = [int(x, 16) for x in open(pad).read().split()]
    if len(woorden) != 256:
        raise SystemExit(f"verwacht 256 woorden, kreeg {len(woorden)}")
    return woorden


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    base = sys.argv[1].rsplit(".", 1)[0]
    for naam, data in zip(("hi", "mid", "lo"), split(lees_hex(sys.argv[1]))):
        open(f"{base}_{naam}.bin", "wb").write(data)
        print(f"{base}_{naam}.bin: {len(data)} bytes")
