# FILE: cpu/test_asm.py
# Tests voor de assembler: bekende codes, fouten, labels en negatieve getallen.
from asm import assemble, AsmError


def code(regel):
    prog, _, _, _ = assemble(regel)
    return prog[0]


def moet_falen(bron, deel_van_melding):
    try:
        assemble(bron)
    except AsmError as e:
        assert deel_van_melding in str(e), f"verkeerde melding: {e}"
        return
    raise AssertionError(f"verwachtte een fout voor: {bron!r}")


# Dezelfde woorden als met de hand gecodeerd in week 13.
assert code("LDI R1, 5") == 0x1205
assert code("LDI R2, 7") == 0x1407
assert code("ADD R3, R1, R2") == 0x0650
assert code("ST R3, [R0+9]") == 0x4609
assert code("LD R4, [R0+9]") == 0x3809
assert code("CMP R3, R4") == 0x60E0
assert code("BEQ 0") == 0x5200
assert code("CALL 0x2A") == 0x802A
assert code("RET") == 0x91C0
assert code("JR R7") == 0x91C0
assert code("ADDI R5, -1") == 0x2AFF
assert code("CMPI R2, 10") == 0x740A
assert code("HALT") == 0xF000
assert code("NOP") == 0xA000
assert code("RETI") == 0xB000 and code("EI") == 0xC000 and code("DI") == 0xD000
assert code("MOV R2, R5") == (2 << 9) | (5 << 6) | (5 << 3) | 3   # MOV = OR rd, rs, rs
assert code("LD R1, [R2]") == code("LD R1, [R2+0]")

# Labels (vooruit en achteruit) en .equ
prog, _, _, _ = assemble("""
        .equ AANTAL, 3
start:  LDI R1, AANTAL
        B   einde
        B   start
einde:  HALT
""")
assert prog[0] == 0x1203 and prog[1] == 0x5003 and prog[2] == 0x5000 and prog[3] == 0xF000

# Meerdere labels op één regel, labelnaam op een eigen regel
prog, _, _, _ = assemble("a:\nb: NOP\n   B a\n   B b")
assert prog[1] == 0x5000 and prog[2] == 0x5000

# .data en .org
prog, data, _, uses = assemble(".data 10, 1, 2, 3\n.org 5\nHALT")
assert uses and data[10:13] == [1, 2, 3] and prog[5] == 0xF000

# Fouten
moet_falen("FOO R1", "onbekende instructie")
moet_falen("LDI R9, 1", "geen register")
moet_falen("LDI R1, 300", "past niet")
moet_falen("LD R1, [R2+64]", "offset")
moet_falen("B nergens", "onbekend")
moet_falen("x: NOP\nx: NOP", "bestaat al")
moet_falen("ADD R1, R2", "verwacht 3")

print("PASS: assembler (codering, labels, .equ, .data, .org, foutmeldingen) werkt")
