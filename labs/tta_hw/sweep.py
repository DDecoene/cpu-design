"""Zoekt hoe snel de klok van het 74HC-bord kan, en of het ontwerp robuust is voor snelle en trage chips.
Gebruik:  python3 sweep.py          (duurt een minuut of twee)"""
import subprocess

BESTANDEN = ["tb_t8_board_random.v", "tb_t8_board.v", "pair_hw.v", "tta.v", "t8_board.v", "hc74xx.v"]


def draai(halve_periode, schaal, rom):
    c = subprocess.run(["iverilog", "-g2012", f"-DHALF={halve_periode}", f"-DDSCALE={schaal}", f"-DROMDLY={rom}",
                        "-s", "tb_t8_board_random", "-o", "sweep.vvp"] + BESTANDEN, capture_output=True, text=True)
    if c.returncode:
        return "compileerfout: " + c.stderr[:100]
    uit = subprocess.run(["vvp", "sweep.vvp"], capture_output=True, text=True, timeout=300).stdout
    regels = [x for x in uit.splitlines() if x.startswith(("PASS", "FAIL:"))]
    return "ok" if regels and regels[-1].startswith("PASS") else "FOUT"


if __name__ == "__main__":
    print("1. Hoe snel kan de klok? (typische chips, ROM 70 ns)")
    for half in (500, 350, 300, 250, 200):
        print(f"   {1000 / (2 * half):5.2f} MHz: {draai(half, 1.0, 70)}")
    print("2. Snelle (x0,5) en trage (x2) chips op 1 MHz")
    for schaal in (0.5, 2.0):
        print(f"   vertragingsschaal {schaal}: {draai(500, schaal, 70)}")
    print("3. Houdtijd: een zeer snel ROM met trage poorten (x2), 1 MHz")
    for rom in (70, 10, 1):
        print(f"   ROM {rom:3d} ns: {draai(500, 2.0, rom)}")
    print("4. Trage chips (x2) met het langzaamste ROM (150 ns)")
    for half in (500, 400):
        print(f"   {1000 / (2 * half):5.2f} MHz: {draai(half, 2.0, 150)}")
