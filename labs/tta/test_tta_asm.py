# Tests voor de TTA-assembler.
from tta_asm import assemble, AsmError

def eerste(bron):
    return assemble(bron)[0][0]

def moet_falen(bron, deel):
    try:
        assemble(bron)
    except AsmError as e:
        assert deel in str(e), f"verkeerde melding: {e}"
        return
    raise AssertionError(f"verwachtte een fout voor {bron!r}")

# Veldindeling: guard[23:21] bestemming[20:16] bron[15:8] constante[7:0]
assert eerste("#5 -> R0")         == 0x010005          # bestemming R0 = 1, bron IMM = 0, constante 5
assert eerste("R0 -> OP")         == 0x050100          # OP = 5, bron R0 = 1
assert eerste("R1 -> ADD")        == 0x060200
assert eerste("RES -> R2")        == 0x030500
assert eerste("#-1 -> R3")        == 0x0400FF
assert eerste("#0xAB -> OUT")     == 0x0E00AB
assert eerste("?Z #7 -> PC")      == 0x2B0007          # guard Z = 1 -> bit 21
assert eerste("?NZ #7 -> PC")     == 0x4B0007
assert eerste("?C #7 -> PC")      == 0x6B0007
assert eerste("PC2 -> R3")        == 0x040A00
assert eerste("#0 -> HALT")       == 0x1F0000

# Macro's
prog = assemble("CALL sub\nHALT\nsub: RET")[0]
assert prog[0] == 0x040A00 and prog[1] == 0x0B0003 and prog[2] == 0x1F0000 and prog[3] == 0x0B0400
assert eerste("JMP 9") == 0x0B0009
assert eerste("?Z JMP 9") == 0x2B0009

# Labels, .equ, .data, .org
prog, data, _, uses = assemble(".equ N, 3\nstart: #N -> R0\n?NZ #start -> PC\n.data 4, 9, 8\n.org 10\nNOP")
assert prog[0] == 0x010003 and prog[1] == 0x4B0000 and data[4:6] == [9, 8] and uses and prog[10] == 0x000000

# Fouten
moet_falen("R0 -> NIET", "onbekende bestemming")
moet_falen("NIET -> R0", "onbekende bron")
moet_falen("#300 -> R0", "past niet")
moet_falen("R0 R1", "bron -> bestemming")
moet_falen("?XX #1 -> R0", "onbekende guard")
moet_falen("#nergens -> PC", "onbekend")
moet_falen("a: NOP\na: NOP", "bestaat al")
moet_falen("MEM -> MEM", "niet toegestaan")

print("PASS: TTA-assembler (velden, guards, macro's, labels, .equ, .data, .org, fouten) werkt")
