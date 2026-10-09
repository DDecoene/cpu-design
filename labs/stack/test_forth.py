# Tests voor de Forth-compiler: bytes van kleine programma's, controlestructuren, foutmeldingen.
from forth import compile_forth, ForthError

def moet_falen(bron, deel):
    try:
        compile_forth(bron)
    except ForthError as e:
        assert deel in str(e), f"verkeerde melding: {e}"
        return
    raise AssertionError(f"verwachtte een fout voor {bron!r}")

c = compile_forth("3 4 +")
assert c[:6] == [0x13, 2, 0x83, 0x84, 0x05, 0x3F]           # JMP 2, LIT 3, LIT 4, +, HALT
c = compile_forth("200 7 AND")
assert c[:6] == [0x13, 2, 0x12, 200, 0x87, 0x07]            # 200 past niet in 7 bit: LIT8
c = compile_forth("-1")
assert c[2:4] == [0x12, 255]
c = compile_forth("$FF 0x10")
assert c[2:6] == [0x12, 255, 0x90, 0x3F]                     # $FF past niet in 7 bit, 0x10 = 16 wel

# definitie en aanroep
c = compile_forth(": dubbel DUP + ; 5 dubbel")
assert c[0:2] == [0x13, 5]                                  # springt over de definitie naar adres 5
assert c[2:5] == [0x01, 0x05, 0x16]                         # DUP + EXIT
assert c[5:8] == [0x85, 0x15, 2]                            # 5, CALL 2

# IF ELSE THEN: JZ naar het ELSE-deel, JMP over het ELSE-deel
c = compile_forth("1 IF 2 ELSE 3 THEN")
assert c[2:10] == [0x81, 0x14, 8, 0x82, 0x13, 9, 0x83, 0x3F]   # JZ -> ELSE-deel (8), JMP -> einde (9)

# BEGIN ... UNTIL springt terug naar het begin; WHILE/REPEAT
c = compile_forth("BEGIN 1 UNTIL")
assert c[2:6] == [0x81, 0x14, 2, 0x3F]
c = compile_forth("BEGIN 1 WHILE 2 REPEAT")
assert c[2:9] == [0x81, 0x14, 8, 0x82, 0x13, 2, 0x3F]            # JZ -> einde (8), JMP terug naar BEGIN (2)

# variabelen en constanten
c = compile_forth("VARIABLE a VARIABLE b a b 7 CONSTANT zeven zeven")
assert c[2:5] == [0x80, 0x81, 0x87]

# commentaar
assert compile_forth("( dit is commentaar ) 1 \\ en dit ook\n 2")[2:4] == [0x81, 0x82]

moet_falen("foo", "onbekend woord")
moet_falen("IF 1", "onafgesloten")
moet_falen("1 THEN", "THEN zonder IF")
moet_falen(": x 1", "eindigt niet")
moet_falen(" ".join(["1"] * 300), "langer dan 256")

print("PASS: Forth-compiler (getallen, definities, IF/ELSE/THEN, BEGIN/UNTIL/WHILE/REPEAT, VARIABLE, CONSTANT, fouten) werkt")
