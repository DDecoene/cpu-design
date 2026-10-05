# FILE: tta_hw/test_split_rom.py
# De drie EEPROM-bestanden moeten samen precies de oorspronkelijke 24-bit-woorden opleveren.
import random
from split_rom import split
from tta_asm import assemble

prog = assemble(open("sum.tta").read())[0]
hi, mid, lo = split(prog)
assert len(hi) == len(mid) == len(lo) == 256
for k, w in enumerate(prog):
    assert (hi[k] << 16 | mid[k] << 8 | lo[k]) == w, k
# De velden die de hardware gebruikt: hi = guard[7:5] + bestemming[4:0], mid = bron[4:0]
assert hi[0] == 0x01 and mid[0] == 0x00 and lo[0] == 0x00     # '#0 -> R0': bestemming R0 = 1
woorden = [random.getrandbits(24) for _ in range(256)]
h, m, l = split(woorden)
assert all(h[i] << 16 | m[i] << 8 | l[i] == woorden[i] for i in range(256))
print("PASS: split_rom splitst 24-bit-woorden in drie bytebestanden zonder verlies")
