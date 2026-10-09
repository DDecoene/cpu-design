"""Instructieset-simulator (ISS) voor W8 in Python. Voert een programma uit en bewaart een spoor van alle
voorwaardelijke sprongen (adres, doel, genomen of niet), zodat we sprongvoorspellers kunnen vergelijken."""

COND = {0: lambda f: True, 1: lambda f: f["z"], 2: lambda f: not f["z"], 3: lambda f: f["c"],
        4: lambda f: not f["c"], 5: lambda f: f["n"] != f["v"], 6: lambda f: f["n"] == f["v"], 7: lambda f: f["n"]}


def sgn(x):
    return x - 256 if x >= 128 else x


def alu(fn, a, b):
    c = v = False
    if fn == 0:
        s = a + b; y = s & 255; c = s > 255
        v = not -128 <= sgn(a) + sgn(b) <= 127
    elif fn == 1:
        y = (a - b) & 255; c = a >= b
        v = not -128 <= sgn(a) - sgn(b) <= 127
    elif fn == 2: y = a & b
    elif fn == 3: y = a | b
    elif fn == 4: y = a ^ b
    elif fn == 5: y = 255 - a
    elif fn == 6: y = (a << 1) & 255; c = a >= 128
    else: y = a >> 1; c = bool(a & 1)
    return y, {"z": y == 0, "n": y >= 128, "c": c, "v": v}


def run(prog, data=None, max_steps=2_000_000):
    """Geeft (registers, vlaggen, geheugen, aantal instructies, sprongspoor)."""
    r = [0] * 8
    mem = list(data) if data else [0] * 256
    f = {"z": False, "n": False, "c": False, "v": False}
    pc, steps, branches = 0, 0, []
    while steps < max_steps:
        w = prog[pc]
        op, rd, rs1, rs2, fn = w >> 12, (w >> 9) & 7, (w >> 6) & 7, (w >> 3) & 7, w & 7
        imm, off, cnd = w & 255, w & 63, (w >> 9) & 7
        here, pc = pc, (pc + 1) & 255
        steps += 1
        if op == 0:
            r[rd], f = alu(fn, r[rs1], r[rs2])
        elif op == 1:
            r[rd] = imm
        elif op == 2:
            r[rd], f = alu(0, r[rd], imm)
        elif op == 3:
            r[rd] = mem[(r[rs1] + off) & 255]
        elif op == 4:
            mem[(r[rs1] + off) & 255] = r[rd]
        elif op == 5:
            taken = COND[cnd](f)
            if cnd != 0:                                   # alleen echte voorwaardelijke sprongen tellen mee
                branches.append((here, imm, taken))
            if taken:
                pc = imm
        elif op == 6:
            _, f = alu(1, r[rs1], r[rs2])
        elif op == 7:
            _, f = alu(1, r[rd], imm)
        elif op == 8:
            r[7] = pc; pc = imm
        elif op == 9:
            pc = r[rs1]
        elif op == 15:
            break
    return r, f, mem, steps, branches
