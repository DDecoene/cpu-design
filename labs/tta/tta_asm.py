# FILE: tta/tta_asm.py
"""Assembler voor de transport-triggered architecture T8.

Gebruik:  python3 tta_asm.py programma.tta [--list]     -> programma.hex (en programma.dat)

Een regel is een move:     [?guard] bron -> bestemming
Constanten schrijf je als  #5   #0xFF   #-1   #label   #NAAM
"""
import re
import sys

DEST = {"NOP": 0, "R0": 1, "R1": 2, "R2": 3, "R3": 4, "OP": 5, "ADD": 6, "SUB": 7,
        "AND": 8, "OR": 9, "XOR": 10, "PC": 11, "MAR": 12, "MEM": 13, "OUT": 14,
        "SHL": 15, "ADC": 16, "HALT": 31}
SRC = {"R0": 1, "R1": 2, "R2": 3, "R3": 4, "RES": 5, "RESHR": 6, "RESNOT": 7,
       "MEM": 8, "IN": 9, "PC2": 10, "FLAGS": 11}
GUARD = {"": 0, "Z": 1, "NZ": 2, "C": 3, "NC": 4, "N": 5, "NN": 6, "NEVER": 7}


class AsmError(Exception):
    pass


def number(tok, symbols, n):
    tok = tok.strip()
    if tok in symbols:
        return symbols[tok]
    try:
        if re.fullmatch(r"-?0[xX][0-9a-fA-F]+", tok):
            return int(tok, 16)
        return int(tok, 10)
    except ValueError:
        raise AsmError(f"regel {n}: onbekend getal of label '{tok}'")


def parse_move(text, n):
    """Geeft (guard, bron, bestemming) als tekst."""
    m = re.fullmatch(r"(?:\?(\w+)\s+)?(\S+)\s*->\s*(\S+)", text.strip())
    if not m:
        raise AsmError(f"regel {n}: verwacht 'bron -> bestemming', kreeg '{text}'")
    guard = (m.group(1) or "").upper()
    if guard not in GUARD:
        raise AsmError(f"regel {n}: onbekende guard '?{guard}'")
    return guard, m.group(2), m.group(3).upper()


def encode(guard, src, dst, symbols, n):
    if dst not in DEST:
        raise AsmError(f"regel {n}: onbekende bestemming '{dst}'")
    if dst == "MEM" and src.upper() == "MEM":
        raise AsmError(f"regel {n}: MEM -> MEM is niet toegestaan (op het bord zouden lezen en schrijven de bus tegelijk aansturen)")
    if src.startswith("#"):
        value = number(src[1:], symbols, n)
        if not -128 <= value <= 255:
            raise AsmError(f"regel {n}: constante {value} past niet in 8 bit")
        srcnum, imm = 0, value & 0xFF
    else:
        if src.upper() not in SRC:
            raise AsmError(f"regel {n}: onbekende bron '{src}'")
        srcnum, imm = SRC[src.upper()], 0
    return (GUARD[guard] << 21) | (DEST[dst] << 16) | (srcnum << 8) | imm


def expand(op, rest, n):
    """Macro's omzetten in moves. Geeft een lijst (guard, bron, bestemming)."""
    guard = ""
    m = re.match(r"\?(\w+)\s+(.*)", op + " " + rest)
    if m:
        guard, text = m.group(1).upper(), m.group(2)
        op, _, rest = text.partition(" ")
    op = op.upper()
    if op == "JMP":
        return [(guard, "#" + rest.strip(), "PC")]
    if op == "CALL":
        return [("", "PC2", "R3"), (guard, "#" + rest.strip(), "PC")]
    if op == "RET":
        return [(guard, "R3", "PC")]
    if op == "NOP":
        return [("", "#0", "NOP")]
    if op == "HALT":
        return [(guard, "#0", "HALT")]
    return None


def assemble(source):
    lines = []
    for n, raw in enumerate(source.splitlines(), 1):
        text = raw.split(";")[0].strip()
        if text:
            lines.append((n, text))

    symbols, items, pc = {}, [], 0
    data, uses_data = [0] * 256, False

    for n, text in lines:
        while True:
            m = re.match(r"^([A-Za-z_]\w*)\s*:\s*(.*)$", text)
            if not m:
                break
            if m.group(1) in symbols:
                raise AsmError(f"regel {n}: label '{m.group(1)}' bestaat al")
            symbols[m.group(1)] = pc
            text = m.group(2)
        if not text:
            continue
        head, _, rest = text.partition(" ")
        if head.upper() == ".EQU":
            name, val = [x.strip() for x in rest.split(",", 1)]
            symbols[name] = number(val, symbols, n)
        elif head.upper() == ".ORG":
            pc = number(rest, symbols, n)
        elif head.upper() == ".DATA":
            parts = [x.strip() for x in rest.split(",")]
            addr = number(parts[0], symbols, n)
            for k, v in enumerate(parts[1:]):
                data[addr + k] = number(v, symbols, n) & 0xFF
            uses_data = True
        else:
            moves = expand(head, rest, n)
            if moves is None:
                moves = [parse_move(text, n)]
            for mv in moves:
                items.append((pc, n, mv))
                pc += 1
            if pc > 256:
                raise AsmError(f"regel {n}: programma is langer dan 256 moves")

    prog = [0x1F0000] * 256
    listing = []
    for addr, n, (guard, src, dst) in items:
        word = encode(guard, src, dst, symbols, n)
        prog[addr] = word
        g = f"?{guard} " if guard else ""
        listing.append(f"{addr:02X}: {word:06X}   {g}{src} -> {dst}")
    return prog, data, listing, uses_data


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    try:
        prog, data, listing, uses_data = assemble(open(argv[1]).read())
    except AsmError as e:
        print(f"FOUT: {e}", file=sys.stderr)
        return 1
    base = argv[1].rsplit(".", 1)[0]
    with open(base + ".hex", "w") as f:
        f.write("\n".join(f"{w:06X}" for w in prog) + "\n")
    if uses_data:
        with open(base + ".dat", "w") as f:
            f.write("\n".join(f"{b:02X}" for b in data) + "\n")
    if "--list" in argv:
        print("\n".join(listing))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
