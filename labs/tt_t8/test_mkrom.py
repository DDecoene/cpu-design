# Het gegenereerde ROM moet precies de woorden van het programma bevatten; en het mag niet groter zijn dan het adresbereik.
import re, subprocess, sys
from mkrom import maak_rom
from tta_asm import assemble

prog = assemble(open("chip.tta").read())[0]
tekst = maak_rom(prog, 6)
gevonden = {int(a): int(w, 16) for a, w in re.findall(r"6'd(\d+): d = 24'h([0-9A-F]{6});", tekst)}
verwacht = {a: w for a, w in enumerate(prog) if w != 0x1F0000}
assert gevonden == verwacht, (gevonden, verwacht)
assert "default: d = 24'h1F0000" in tekst
try:
    maak_rom([0x010000] * 100, 6)      # 100 woorden passen niet in 6 adresbits
    raise AssertionError("moest falen")
except SystemExit as e:
    assert "adres" in str(e)
print("PASS: mkrom maakt een ROM met precies de programmawoorden en weigert programma's die te groot zijn")
