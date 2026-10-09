#!/usr/bin/env python3
"""Assembler voor de 8-bit CPU van deze cursus.

Gebruik:  python3 asm.py programma.asm            -> programma.hex (en programma.dat bij .data)
          python3 asm.py programma.asm --list     -> met listing op het scherm
"""
import re
import sys

REGS = {f"R{i}": i for i in range(8)} | {"LR": 7}
ALU3 = {"ADD": 0, "SUB": 1, "AND": 2, "OR": 3, "XOR": 4}
ALU2 = {"NOT": 5, "SHL": 6, "SHR": 7}
CONDS = {"B": 0, "BEQ": 1, "BZ": 1, "BNE": 2, "BNZ": 2, "BCS": 3, "BHS": 3,
         "BCC": 4, "BLO": 4, "BLT": 5, "BGE": 6, "BMI": 7}


class AsmError(Exception):
    pass


def parse_number(tok, symbols, line_no):
    tok = tok.strip()
    try:
        if tok in symbols:
            return symbols[tok]
        if re.fullmatch(r"-?0[xX][0-9a-fA-F]+", tok):
            return int(tok, 16)
        if re.fullmatch(r"-?0[bB][01]+", tok):
            return int(tok, 2)
        return int(tok, 10)
    except ValueError:
        raise AsmError(f"regel {line_no}: onbekend getal of label '{tok}'")


def reg(tok, line_no):
    r = tok.strip().upper()
    if r not in REGS:
        raise AsmError(f"regel {line_no}: '{tok.strip()}' is geen register (R0..R7)")
    return REGS[r]


def imm8(value, line_no):
    if not -128 <= value <= 255:
        raise AsmError(f"regel {line_no}: waarde {value} past niet in 8 bit (-128..255)")
    return value & 0xFF


def split_operands(text):
    # splitst op komma's maar niet binnen [ ]
    parts, depth, cur = [], 0, ""
    for ch in text:
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur.strip())
    return parts


def mem_operand(tok, symbols, line_no):
    m = re.fullmatch(r"\[\s*(\w+)\s*(?:\+\s*([\w\-x]+))?\s*\]", tok.strip())
    if not m:
        raise AsmError(f"regel {line_no}: verwacht [Rn] of [Rn+offset], kreeg '{tok}'")
    base = reg(m.group(1), line_no)
    off = parse_number(m.group(2), symbols, line_no) if m.group(2) else 0
    if not 0 <= off <= 63:
        raise AsmError(f"regel {line_no}: offset {off} moet tussen 0 en 63 liggen")
    return base, off


def assemble(source):
    """Geeft (programma: lijst van 256 woorden, data: lijst van 256 bytes, listing)."""
    lines = []
    for n, raw in enumerate(source.splitlines(), 1):
        text = raw.split(";")[0].strip()
        if text:
            lines.append((n, text))

    symbols, items, pc = {}, [], 0
    data = [0] * 256
    uses_data = False

    # Eerste ronde: adressen van labels bepalen, .equ en .data verwerken.
    for n, text in lines:
        while True:
            m = re.match(r"^([A-Za-z_]\w*)\s*:\s*(.*)$", text)
            if not m:
                break
            label, text = m.group(1), m.group(2)
            if label in symbols:
                raise AsmError(f"regel {n}: label '{label}' bestaat al")
            symbols[label] = pc
        if not text:
            continue
        head, _, rest = text.partition(" ")
        head = head.upper()
        if head == ".EQU":
            name, val = [x.strip() for x in rest.split(",", 1)]
            symbols[name] = parse_number(val, symbols, n)
        elif head == ".ORG":
            pc = parse_number(rest, symbols, n)
        elif head == ".DATA":
            parts = split_operands(rest)
            addr = parse_number(parts[0], symbols, n)
            for k, v in enumerate(parts[1:]):
                if addr + k > 255:
                    raise AsmError(f"regel {n}: data voorbij adres 255")
                data[addr + k] = parse_number(v, symbols, n) & 0xFF
            uses_data = True
        else:
            items.append((pc, n, head, rest))
            pc += 1
            if pc > 256:
                raise AsmError(f"regel {n}: programma is langer dan 256 instructies")

    # Tweede ronde: instructies coderen.
    prog = [0xA000] * 256
    listing = []
    for addr, n, op, rest in items:
        ops = split_operands(rest)

        def need(k):
            if len(ops) != k:
                raise AsmError(f"regel {n}: {op} verwacht {k} operand(en), kreeg {len(ops)}")

        if op in ALU3:
            need(3)
            word = (0 << 12) | (reg(ops[0], n) << 9) | (reg(ops[1], n) << 6) | (reg(ops[2], n) << 3) | ALU3[op]
        elif op in ALU2:
            need(2)
            word = (reg(ops[0], n) << 9) | (reg(ops[1], n) << 6) | ALU2[op]
        elif op == "MOV":
            need(2)
            rs = reg(ops[1], n)
            word = (reg(ops[0], n) << 9) | (rs << 6) | (rs << 3) | ALU3["OR"]
        elif op in ("LDI", "ADDI", "CMPI"):
            need(2)
            code = {"LDI": 1, "ADDI": 2, "CMPI": 7}[op]
            word = (code << 12) | (reg(ops[0], n) << 9) | imm8(parse_number(ops[1], symbols, n), n)
        elif op in ("LD", "ST"):
            need(2)
            base, off = mem_operand(ops[1], symbols, n)
            code = 3 if op == "LD" else 4
            word = (code << 12) | (reg(ops[0], n) << 9) | (base << 6) | off
        elif op == "CMP":
            need(2)
            word = (6 << 12) | (reg(ops[0], n) << 6) | (reg(ops[1], n) << 3)
        elif op in CONDS:
            need(1)
            target = parse_number(ops[0], symbols, n)
            if not 0 <= target <= 255:
                raise AsmError(f"regel {n}: sprongdoel {target} ligt buiten 0..255")
            word = (5 << 12) | (CONDS[op] << 9) | target
        elif op == "CALL":
            need(1)
            word = (8 << 12) | parse_number(ops[0], symbols, n)
        elif op == "JR":
            need(1)
            word = (9 << 12) | (reg(ops[0], n) << 6)
        elif op == "RET":
            need(0)
            word = (9 << 12) | (7 << 6)
        elif op == "NOP":
            need(0)
            word = 0xA000
        elif op in ("RETI", "EI", "DI"):          # interrupts: zie week 22
            need(0)
            word = {"RETI": 0xB000, "EI": 0xC000, "DI": 0xD000}[op]
        elif op == "HALT":
            need(0)
            word = 0xF000
        else:
            raise AsmError(f"regel {n}: onbekende instructie '{op}'")
        prog[addr] = word
        listing.append(f"{addr:02X}: {word:04X}   {op} {rest}".rstrip())
    return prog, data, listing, uses_data


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    path = argv[1]
    try:
        prog, data, listing, uses_data = assemble(open(path).read())
    except AsmError as e:
        print(f"FOUT: {e}", file=sys.stderr)
        return 1
    base = path.rsplit(".", 1)[0]
    with open(base + ".hex", "w") as f:
        f.write("\n".join(f"{w:04X}" for w in prog) + "\n")
    if uses_data:
        with open(base + ".dat", "w") as f:
            f.write("\n".join(f"{b:02X}" for b in data) + "\n")
    if "--list" in argv:
        print("\n".join(listing))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
