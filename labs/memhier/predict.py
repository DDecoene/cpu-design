# FILE: memhier/predict.py
"""Sprongvoorspellers vergelijken op sporen van echte W8-programma's."""
from asm import assemble
from w8iss import run


class AlwaysNotTaken:
    naam = "altijd niet genomen"
    kort = "nooit"
    def predict(self, pc, target): return False
    def update(self, pc, taken): pass


class AlwaysTaken:
    naam = "altijd genomen"
    kort = "altijd"
    def predict(self, pc, target): return True
    def update(self, pc, taken): pass


class BackwardTaken:
    naam = "achteruit genomen (BTFN)"
    kort = "BTFN"
    def predict(self, pc, target): return target < pc      # lussen springen terug: voorspel 'genomen'
    def update(self, pc, taken): pass


class OneBit:
    naam = "1 bit per sprong"
    kort = "1-bit"
    def __init__(self): self.t = {}
    def predict(self, pc, target): return self.t.get(pc, False)
    def update(self, pc, taken): self.t[pc] = taken


class TwoBit:
    """Verzadigende teller 0..3: 0-1 voorspelt 'niet genomen', 2-3 'genomen'."""
    naam = "2 bit teller per sprong"
    kort = "2-bit"
    def __init__(self): self.t = {}
    def predict(self, pc, target): return self.t.get(pc, 1) >= 2
    def update(self, pc, taken):
        c = self.t.get(pc, 1)
        self.t[pc] = min(3, c + 1) if taken else max(0, c - 1)


PREDICTORS = [AlwaysNotTaken, AlwaysTaken, BackwardTaken, OneBit, TwoBit]


def accuracy(trace, predictor):
    """Fractie goed voorspelde sprongen in een spoor van (adres, doel, genomen)."""
    if not trace:
        return 1.0
    goed = 0
    for pc, target, taken in trace:
        if predictor.predict(pc, target) == taken:
            goed += 1
        predictor.update(pc, taken)
    return goed / len(trace)


def spoor(naam):
    prog, data, _, _ = assemble(open(naam + ".asm").read())
    _, _, _, steps, branches = run(prog, data)
    return steps, branches


if __name__ == "__main__":
    programmas = ["sum", "mul", "sort", "primes", "gcd", "calls"]
    print(f"{'programma':10} {'sprongen':>8} " + " ".join(f"{p.kort:>8}" for p in PREDICTORS))
    for naam in programmas:
        steps, tr = spoor(naam)
        cijfers = [accuracy(tr, P()) for P in PREDICTORS]
        print(f"{naam:10} {len(tr):8d} " + " ".join(f"{100 * c:7.1f}%" for c in cijfers))
