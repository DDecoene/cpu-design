# FILE: tta_hw/bom.py
"""Telt de chips in het schema (t8_board.v) en maakt een onderdelenlijst (BOM) met een prijsindicatie.

De prijzen zijn grove schattingen voor kleine aantallen en veranderen; pas ze aan in de tabel PRIJS."""
import re
import sys
from collections import Counter

# type in Verilog -> (naam op het bord, behuizing, pinnen, omschrijving)
CHIPS = {
    "hc04":   ("74HC04",  "DIP-14", 14, "6 inverters"),
    "hc08":   ("74HC08",  "DIP-14", 14, "4 AND-poorten"),
    "hc11":   ("74HC11",  "DIP-14", 14, "3 AND-poorten met 3 ingangen"),
    "hc32":   ("74HC32",  "DIP-14", 14, "4 OR-poorten"),
    "hc86":   ("74HC86",  "DIP-14", 14, "4 XOR-poorten"),
    "hc74":   ("74HC74",  "DIP-14", 14, "2 D-flipflops"),
    "hc138":  ("74HC138", "DIP-16", 16, "3-naar-8 decoder, uitgangen actief laag"),
    "hc238":  ("74HC238", "DIP-16", 16, "3-naar-8 decoder, uitgangen actief hoog"),
    "hc151":  ("74HC151", "DIP-16", 16, "8-naar-1 multiplexer"),
    "hc161":  ("74HC161", "DIP-16", 16, "4-bit synchrone teller"),
    "hc283":  ("74HC283", "DIP-16", 16, "4-bit opteller"),
    "hc240":  ("74HC240", "DIP-20", 20, "octal inverterende buffer, tri-state"),
    "hc244":  ("74HC244", "DIP-20", 20, "octal buffer, tri-state"),
    "hc574":  ("74HC574", "DIP-20", 20, "octal D-register met tri-state"),
    "hc4078": ("74HC4078", "DIP-14", 14, "8-ingangs OR/NOR"),
    "eeprom28c256": ("28C256", "DIP-28", 28, "32K x 8 EEPROM"),
    "sram62256":    ("62256",  "DIP-28", 28, "32K x 8 statisch RAM"),
}
PRIJS = {"74HC04": 0.5, "74HC08": 0.5, "74HC11": 0.6, "74HC32": 0.5, "74HC86": 0.6, "74HC74": 0.5, "74HC138": 0.6,
         "74HC238": 0.8, "74HC151": 0.7, "74HC161": 0.7, "74HC283": 0.8, "74HC240": 0.7, "74HC244": 0.6, "74HC574": 0.8,
         "74HC4078": 0.7, "28C256": 5.0, "62256": 2.5}      # euro per stuk, grove schatting
SOCKEL = 0.25                                                # euro per IC-voet (DIP-socket), per pin klasse gemiddeld


def tel(pad):
    tekst = open(pad).read()
    c = Counter()
    for m in re.finditer(r"^\s*(\w+)\s+(?:#\([^)]*\)\s*)?u_\w+\s*\(", tekst, re.M):
        if m.group(1) in CHIPS:
            c[m.group(1)] += 1
    # Een 74HC74 bevat twee flipflops: in het schema staat elke flipflop als aparte instantie.
    c["hc74"] = (c["hc74"] + 1) // 2
    return c


def main(pad="t8_board.v"):
    c = tel(pad)
    totaal_chips = sum(c.values())
    print(f"{'chip':10} {'aantal':>6}  {'behuizing':9}  omschrijving")
    sub = 0.0
    for t, n in sorted(c.items(), key=lambda kv: CHIPS[kv[0]][0]):
        naam, beh, pins, omschr = CHIPS[t]
        print(f"{naam:10} {n:6d}  {beh:9}  {omschr}")
        sub += n * PRIJS[naam]
    voeten = totaal_chips * SOCKEL
    print(f"\nTotaal: {totaal_chips} chips, {sum(CHIPS[t][2] * n for t, n in c.items())} pinnen")
    print(f"Indicatie: chips ca. EUR {sub:.0f}, IC-voeten ca. EUR {voeten:.0f} (excl. print, condensatoren, weerstanden, connectoren, klok)")
    return c


if __name__ == "__main__":
    main(*sys.argv[1:])
