#!/usr/bin/env python3
"""Bouwt het boek uit src/*.md en de code in labs/.

  pdf/cpu-design-cursus.pdf                 voor het scherm: alles in één bestand, klikbaar
  pdf/cpu-design-cursus-print.pdf           om af te drukken (recto-verso, rugmarge): tekst en antwoorden
  pdf/cpu-design-cursus-codeboek-print.pdf  om af te drukken: de lange listings, als tweede map

Nodig: pandoc (3.1 of nieuwer) en typst (0.15). Gebruik:
  ./build.py              alle drie
  ./build.py scherm       alleen de schermversie (sneller tijdens het schrijven)
"""
import json, os, pathlib, re, shutil, subprocess, sys

root = pathlib.Path(__file__).resolve().parent
src = root / "src"
uit = root / "build" / "typst"
pdf = root / "pdf"
TYPST = os.environ.get("TYPST", "typst")
PANDOC = os.environ.get("PANDOC", "pandoc")


def ondertitel(tekst):
    m = re.search(r'<p class="subtitle">(.*?)</p>', tekst)
    return m.group(1) if m else ""


def hoofdstukken():
    """Leest de weken in: nummer, titel, fase."""
    weken = {}
    for md in sorted(src.glob("week*.md")):
        tekst = md.read_text()
        nr = int(md.stem[4:])
        titel = re.search(r"^# Week \d+: (.*)$", tekst, re.M).group(1).strip()
        fase = int(re.match(r"Fase (\d+)", ondertitel(tekst)).group(1))
        weken[nr] = {"titel": titel, "fase": fase}
    return weken


def fasen():
    """Thema en resultaat per fase, uit de tabel in de syllabus."""
    tekst = (src / "00_syllabus.md").read_text()
    blok = tekst.split("## De zeven fasen", 1)[1]
    rijen = re.findall(r"^\| (\d+) \| [^|]+ \| ([^|]+) \| ([^|]+) \|$", blok, re.M)
    return {int(n): {"titel": t.strip(), "resultaat": r.strip()} for n, t, r in rijen}


def pandoc(md, **meta):
    args = [PANDOC, str(md), "-f", "markdown", "-t", "typst", "--wrap=none",
            "--lua-filter", str(root / "boek" / "filter.lua"), "-o", str(uit / (meta["sleutel"] + ".typ"))]
    meta["uitmap"] = str(uit)
    for k, v in meta.items():
        args += ["-M", f"{k}={v}"]
    subprocess.run(args, check=True, cwd=root)


def typst_tekst(s):
    return "[" + s.replace("\\", "\\\\").replace("[", "\\[").replace("]", "\\]").replace("#", "\\#") + "]"


def hoofdbestand(weken, fase_info, met_boek=True, met_codeboek=True, titel_sub=None):
    r = ['#import "/boek/boek.typ": *', "#show: boek"]
    r.append(f"#titelpagina(ondertitel: {typst_tekst(titel_sub) if titel_sub else 'none'})")
    r.append("#colofon()")
    r.append("#inhoud()")
    if met_boek:
        r.append('#include "00_syllabus.typ"')
        for fase, info in sorted(fase_info.items()):
            nrs = [n for n, w in sorted(weken.items()) if w["fase"] == fase]
            r.append(f"#deel({fase}, {typst_tekst(info['titel'])}, weken: {tuple(nrs) if len(nrs) > 1 else '(' + str(nrs[0]) + ',)'}, "
                     f"beschrijving: {typst_tekst(info['resultaat'] + '.')})")
            r += [f'#include "week{n:02d}.typ"' for n in nrs]
        r.append('#deel("bijlagen", [Bijlagen], beschrijving: [Naslag bij de cursus: een Verilog-spiekbrief, '
                 'de drie instructiesets, de 74HC-chips, formules, gereedschap en een woordenlijst.])')
        r.append('#include "99_bijlagen.typ"')
        r.append('#deel("antwoorden", [Antwoorden], beschrijving: [De antwoorden op de oefeningen en de zelftests, '
                 'per week. Probeer eerst zelf: een antwoord dat je opzoekt, onthoud je slechter dan een antwoord '
                 'dat je zelf vindt.])')
        r += [f'#include "week{n:02d}-antw.typ"' for n in sorted(weken)]
    if met_codeboek:
        r.append('#deel("codeboek", [Codeboek], beschrijving: [De lange listings uit de weken, volledig en met '
                 'regelnummers. In de tekst staat op hun plaats een verwijzing. Alle code staat ook in de map '
                 '`labs/` van de repository en wordt daar automatisch getest.])')
        r += [f'#include "week{n:02d}-code.typ"' for n in sorted(weken)]
    return "\n".join(r) + "\n"


def main():
    welke = sys.argv[1:] or ["scherm", "print", "codeboek"]
    for prog in (PANDOC, TYPST):
        if not shutil.which(prog):
            sys.exit(f"{prog} niet gevonden (zie README: De PDF's bouwen)")
    uit.mkdir(parents=True, exist_ok=True)
    pdf.mkdir(exist_ok=True)

    weken = hoofdstukken()
    fase_info = fasen()
    (uit / "weken.json").write_text(json.dumps({"weken": {str(k): v for k, v in weken.items()}}, ensure_ascii=False))

    pandoc(src / "00_syllabus.md", sleutel="00_syllabus", soort="voor")
    pandoc(src / "99_bijlagen.md", sleutel="99_bijlagen", soort="bijlagen")
    for nr, w in weken.items():
        pandoc(src / f"week{nr:02d}.md", sleutel=f"week{nr:02d}", soort="week", nr=nr, fase=w["fase"])

    versie = subprocess.run(["git", "describe", "--tags", "--always", "--dirty"], cwd=root,
                            capture_output=True, text=True).stdout.strip() or "ontwikkelversie"
    uitgaven = {
        "scherm": ("main-scherm.typ", hoofdbestand(weken, fase_info), "scherm", "cpu-design-cursus.pdf"),
        "print": ("main-print.typ", hoofdbestand(weken, fase_info, met_codeboek=False), "print",
                  "cpu-design-cursus-print.pdf"),
        "codeboek": ("main-codeboek.typ", hoofdbestand(weken, fase_info, met_boek=False, titel_sub="Codeboek"),
                     "print", "cpu-design-cursus-codeboek-print.pdf"),
    }
    for naam in welke:
        bestand, inhoud, modus, doel = uitgaven[naam]
        (uit / bestand).write_text(inhoud)
        zonder_tags = ["--no-pdf-tags"] if modus == "print" else []  # op papier geen nut, en scheelt veel grootte
        subprocess.run([TYPST, "compile", *zonder_tags, "--root", str(root), "--font-path", str(root / "boek" / "fonts"),
                        "--ignore-system-fonts", "--input", f"modus={modus}", "--input", f"versie={versie}",
                        "--input", f"uitgave={naam}", str(uit / bestand), str(pdf / doel)], check=True, cwd=root)
        print(f"ok  pdf/{doel}")


if __name__ == "__main__":
    main()
