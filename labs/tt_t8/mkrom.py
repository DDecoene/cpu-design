"""Maakt van een T8-programma (.hex van tta_asm.py) een synthetiseerbaar ROM-module in Verilog.
Gebruik:  python3 mkrom.py programma.hex 6 > rom_t8.v      (6 = aantal adresbits van de programmateller)
Een echte chip heeft geen $readmemh nodig: het programma wordt een 'case'-tabel, dat is gewone logica."""
import sys

HALT = 0x1F0000


def maak_rom(woorden, pcw):
    n = 1 << pcw
    gebruikt = [(a, w) for a, w in enumerate(woorden) if w != HALT]
    if gebruikt and max(a for a, _ in gebruikt) >= n:
        raise SystemExit(f"het programma gebruikt adres {max(a for a, _ in gebruikt)}, maar {pcw} adresbits halen maar {n - 1}")
    regels = [
        "// Gegenereerd door mkrom.py. Niet met de hand aanpassen.",
        f"module t8_rom (input [{pcw - 1}:0] a, output reg [23:0] d);",
        "  always_comb begin",
        "    case (a)",
    ]
    for a, w in gebruikt:
        regels.append(f"      {pcw}'d{a}: d = 24'h{w:06X};")
    regels += ["      default: d = 24'h1F0000;   // HALT", "    endcase", "  end", "endmodule"]
    return "\n".join(regels) + "\n"


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        raise SystemExit(2)
    woorden = [int(x, 16) for x in open(sys.argv[1]).read().split()]
    sys.stdout.write(maak_rom(woorden, int(sys.argv[2])))
