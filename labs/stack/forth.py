"""Een kleine Forth-compiler voor de stackmachine S8.

Gebruik:  python3 forth.py programma.fs        -> programma.hex
Ondersteund: getallen (10, $FF, 0xFF, -1), : naam ... ;, VARIABLE, CONSTANT,
IF ELSE THEN, BEGIN UNTIL, BEGIN WHILE REPEAT, BEGIN AGAIN, commentaar ( ... ) en \\ ...
"""
import re
import sys

PRIMITIVES = {
    "NOP": 0x00, "DUP": 0x01, "DROP": 0x02, "SWAP": 0x03, "OVER": 0x04,
    "+": 0x05, "-": 0x06, "AND": 0x07, "OR": 0x08, "XOR": 0x09,
    "INVERT": 0x0A, "2*": 0x0B, "2/": 0x0C, "@": 0x0D, "!": 0x0E,
    ">R": 0x0F, "R>": 0x10, "R@": 0x11, "=": 0x17, "<": 0x18, "ROT": 0x19,
    "EXIT": 0x16, "HALT": 0x3F,
}
LIT8, JMP, JZ, CALL, EXIT, HALT = 0x12, 0x13, 0x14, 0x15, 0x16, 0x3F


class ForthError(Exception):
    pass


def tokenize(src):
    src = re.sub(r"\\[^\n]*", " ", src)           # \ commentaar tot einde regel
    src = re.sub(r"\([^)]*\)", " ", src)           # ( commentaar )
    return src.split()


def parse_number(tok):
    try:
        if tok.startswith("$"):
            return int(tok[1:], 16)
        if tok.lower().startswith("0x") or tok.lower().startswith("-0x"):
            return int(tok, 16)
        return int(tok, 10)
    except ValueError:
        return None


def compile_forth(src):
    toks = tokenize(src)
    code = [JMP, 0]                    # adres 0: spring naar het hoofdprogramma (adres wordt later ingevuld)
    words, consts = {}, {}
    next_var = 0
    main_tokens = []

    def emit(*bytes_):
        code.extend(bytes_)
        if len(code) > 256:
            raise ForthError("programma is langer dan 256 bytes")

    def literal(value):
        value &= 0xFF
        if value < 128:
            emit(0x80 | value)
        else:
            emit(LIT8, value)

    def compile_body(tokens):
        ctrl = []
        for tok in tokens:
            up = tok.upper()
            if up == "IF":
                emit(JZ, 0); ctrl.append(("if", len(code) - 1))
            elif up == "ELSE":
                kind, pos = ctrl.pop()
                if kind != "if":
                    raise ForthError("ELSE zonder IF")
                emit(JMP, 0)
                code[pos] = len(code)
                ctrl.append(("else", len(code) - 1))
            elif up == "THEN":
                if not ctrl or ctrl[-1][0] not in ("if", "else"):
                    raise ForthError("THEN zonder IF")
                kind, pos = ctrl.pop()
                code[pos] = len(code)
            elif up == "BEGIN":
                ctrl.append(("begin", len(code)))
            elif up == "UNTIL":
                kind, addr = ctrl.pop()
                if kind != "begin":
                    raise ForthError("UNTIL zonder BEGIN")
                emit(JZ, addr)
            elif up == "AGAIN":
                kind, addr = ctrl.pop()
                if kind != "begin":
                    raise ForthError("AGAIN zonder BEGIN")
                emit(JMP, addr)
            elif up == "WHILE":
                emit(JZ, 0); ctrl.append(("while", len(code) - 1))
            elif up == "REPEAT":
                kind, wpos = ctrl.pop()
                kind2, addr = ctrl.pop()
                if kind != "while" or kind2 != "begin":
                    raise ForthError("REPEAT zonder BEGIN ... WHILE")
                emit(JMP, addr)
                code[wpos] = len(code)
            elif tok in words:
                emit(CALL, words[tok])
            elif tok in consts:
                literal(consts[tok])
            elif up in PRIMITIVES:
                emit(PRIMITIVES[up])
            elif parse_number(tok) is not None:
                literal(parse_number(tok))
            else:
                raise ForthError(f"onbekend woord: {tok}")
        if ctrl:
            raise ForthError(f"onafgesloten structuur: {ctrl[-1][0].upper()}")

    i = 0
    while i < len(toks):
        tok = toks[i]
        if tok == ":":
            if i + 1 >= len(toks):
                raise ForthError("':' zonder naam")
            name = toks[i + 1]
            j = i + 2
            while j < len(toks) and toks[j] != ";":
                j += 1
            if j >= len(toks):
                raise ForthError(f"definitie van {name} eindigt niet met ';'")
            words[name] = len(code)
            compile_body(toks[i + 2:j])
            emit(EXIT)
            i = j + 1
        elif tok.upper() == "VARIABLE":
            consts[toks[i + 1]] = next_var
            next_var += 1
            i += 2
        elif tok.upper() == "CONSTANT":
            if not main_tokens or parse_number(main_tokens[-1]) is None:
                raise ForthError("CONSTANT verwacht een getal ervoor")
            consts[toks[i + 1]] = parse_number(main_tokens.pop()) & 0xFF
            i += 2
        else:
            main_tokens.append(tok)
            i += 1

    code[1] = len(code)
    compile_body(main_tokens)
    emit(HALT)
    return code + [HALT] * (256 - len(code))


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    try:
        code = compile_forth(open(argv[1]).read())
    except ForthError as e:
        print(f"FOUT: {e}", file=sys.stderr)
        return 1
    with open(argv[1].rsplit(".", 1)[0] + ".hex", "w") as f:
        f.write("\n".join(f"{b:02X}" for b in code) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
