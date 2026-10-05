#!/usr/bin/env python3
"""Haalt code uit src/*.md (blokken met '// FILE: map/naam.v', '# FILE: ...' of '; FILE: ...') naar labs/,
voert <!-- COPY bron doel --> uit, assembleert .asm-bestanden, compileert en draait elke tb_*.v met Icarus Verilog
en draait test_*.py. Een lab slaagt als er geen FAIL in de output staat en er minstens één PASS in voorkomt.
Gebruik: ./extract_labs.py            (alles)
         ./extract_labs.py 04 cpu     (alleen labs/week04 en labs/cpu)"""
import re, sys, subprocess, shutil, pathlib, glob
root = pathlib.Path(__file__).parent
labs = root / "labs"
pat = re.compile(r"```[a-zA-Z]*\n((?://|#|;|\\) FILE: (\S+)\n.*?)```", re.S)
copy_pat = re.compile(r"<!--\s*COPY\s+(\S+)\s+(\S+)\s*-->")
copysed_pat = re.compile(r"<!--\s*COPYSED\s+(\S+)\s+(\S+)((?:\s+\"[^\"]*\"=>\"[^\"]*\")+)\s*-->")
pair_pat = re.compile(r'"([^"]*)"=>"([^"]*)"')
directive = re.compile(r"<!--\s*(COPYSED|COPY)\s")
mds = sorted(glob.glob(str(root / "src" / "week*.md")))
for md in mds:
    text = pathlib.Path(md).read_text()
    for body, path in pat.findall(text):
        out = labs / path
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(body)
for md in mds:
    text = pathlib.Path(md).read_text()
    for m in re.finditer(r"<!--\s*(COPYSED|COPY)\s.*?-->", text, re.S):
        d = m.group(0)
        if m.group(1) == "COPYSED":
            src, dst, pairs = copysed_pat.match(d).groups()
            body = (labs / src).read_text()
            for old, new in pair_pat.findall(pairs):
                body = body.replace(old, new)
            (labs / dst).parent.mkdir(parents=True, exist_ok=True)
            (labs / dst).write_text(body)
        else:
            src, dst = copy_pat.match(d).groups()
            (labs / dst).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(labs / src, labs / dst)

bad = 0
only = sys.argv[1:]
def selected(d):
    return not only or d.name in only or d.name[4:] in only

for d in sorted(p for p in labs.iterdir() if p.is_dir()):
    if not selected(d): continue
    if (d / "asm.py").exists():
        for a in sorted(d.glob("*.asm")):
            r = subprocess.run(["python3", "asm.py", a.name], capture_output=True, text=True, cwd=d)
            if r.returncode:
                print(f"ASM-FOUT {d.name}/{a.name}\n{r.stderr}"); bad += 1
    if (d / "forth.py").exists():
        for a in sorted(d.glob("*.fs")):
            r = subprocess.run(["python3", "forth.py", a.name], capture_output=True, text=True, cwd=d)
            if r.returncode:
                print(f"FORTH-FOUT {d.name}/{a.name}\n{r.stderr}"); bad += 1
    if (d / "tta_asm.py").exists():
        for a in sorted(d.glob("*.tta")):
            r = subprocess.run(["python3", "tta_asm.py", a.name], capture_output=True, text=True, cwd=d)
            if r.returncode:
                print(f"TTA-ASM-FOUT {d.name}/{a.name}\n{r.stderr}"); bad += 1
    for t in sorted(d.glob("test_*.py")):
        r = subprocess.run(["python3", t.name], capture_output=True, text=True, cwd=d)
        ok = r.returncode == 0 and "PASS" in r.stdout
        print(("ok   " if ok else "FOUT ") + f"{d.name}/{t.name}")
        if not ok: print(r.stdout[-800:], r.stderr[-600:]); bad += 1
    srcs = [f for f in d.glob("*.v") if not f.name.startswith("tb_")]
    for tb in sorted(d.glob("tb_*.v")):
        exe = root / "build" / f"{d.name}_{tb.stem}.vvp"
        c = subprocess.run(["iverilog", "-g2012", "-I", str(d), "-o", str(exe), str(tb), *map(str, srcs)],
                           capture_output=True, text=True, cwd=d)
        if c.returncode:
            print(f"COMPILE-FOUT {d.name}/{tb.name}\n{c.stderr}"); bad += 1; continue
        try:
            r = subprocess.run(["vvp", str(exe)], capture_output=True, text=True, cwd=d, timeout=120)
        except subprocess.TimeoutExpired:
            print(f"TIMEOUT {d.name}/{tb.name}"); bad += 1; continue
        ok = "FAIL" not in r.stdout and "PASS" in r.stdout and r.returncode == 0
        print(("ok   " if ok else "FOUT ") + f"{d.name}/{tb.name}")
        if not ok: print(r.stdout[-800:], r.stderr[-400:]); bad += 1
sys.exit(1 if bad else 0)
