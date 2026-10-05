# FILE: memhier/test_predict.py
# Test van de ISS (tegen de resultaten van de Verilog-CPU) en van de voorspellers.
from asm import assemble
from w8iss import run
from predict import AlwaysNotTaken, AlwaysTaken, BackwardTaken, OneBit, TwoBit, accuracy, spoor

def uitvoeren(naam):
    prog, data, _, _ = assemble(open(naam + ".asm").read())
    return run(prog, data)

# Dezelfde uitkomsten en instructieaantallen als de Verilog-testbenches (2 cycli per instructie)
r, f, mem, steps, _ = uitvoeren("sum");     assert r[1] == 55 and steps * 2 == 66
r, f, mem, steps, _ = uitvoeren("mul");     assert (r[5] << 8 | r[4]) == 30000 and steps * 2 == 190
r, f, mem, steps, _ = uitvoeren("sort");    assert mem[16:24] == [1, 3, 17, 55, 77, 90, 128, 200] and steps * 2 == 564
r, f, mem, steps, _ = uitvoeren("primes");  assert r[3] == 25 and steps * 2 == 3596
r, f, mem, steps, _ = uitvoeren("gcd");     assert r[1] == 21 and steps * 2 == 60
r, f, mem, steps, _ = uitvoeren("calls");   assert r[3] == 9 and r[2] == 144 and steps * 2 == 114

# Een lus van 10 iteraties: negen keer genomen, één keer niet; 100 keer herhaald.
lus = ([(10, 4, True)] * 9 + [(10, 4, False)]) * 100
assert abs(accuracy(lus, AlwaysNotTaken()) - 0.10) < 1e-9
assert abs(accuracy(lus, AlwaysTaken()) - 0.90) < 1e-9
assert abs(accuracy(lus, BackwardTaken()) - 0.90) < 1e-9
een = accuracy(lus, OneBit())
twee = accuracy(lus, TwoBit())
assert 0.79 <= een <= 0.81, een           # twee missers per lusronde
assert 0.89 <= twee <= 0.91, twee         # één misser per lusronde
assert twee > een

# Een afwisselende sprong (T N T N ...) is de grote vijand van de 1-bit voorspeller
wissel = [(5, 1, bool(i % 2)) for i in range(1000)]
assert accuracy(wissel, OneBit()) < 0.01

print("PASS: ISS komt overeen met de Verilog-CPU en de voorspellers gedragen zich zoals verwacht")
