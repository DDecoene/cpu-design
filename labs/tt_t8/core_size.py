"""Schat de grootte van de programmeerbare T8-kern (zonder programma): de instructie is een ingang van de chip,
dus de synthese kan niets wegwerken op grond van een vast programma. Hetzelfde idee als chip_size.sh, andere vraag."""
import os, subprocess, sys

VENV = os.environ.get("VENV", os.path.expanduser("~/fpga-venv"))
YOSYS = f"{VENV}/bin/yowasp-yosys"


def schat(pcw, aw):
    top = f"""module kern(input clk, input rst_n, input [7:0] in_port, output [7:0] out_port, output halted,
                 output [{pcw-1}:0] rom_addr, input [23:0] instr);
  t8_core #({pcw}, {aw}) c(clk, rst_n, in_port, out_port, halted, rom_addr, instr, , , , , , , , , );
endmodule
"""
    open("kern_tmp.v", "w").write(top)
    script = ("read_verilog -sv t8_core.v kern_tmp.v; synth -top kern -flatten; "
              "abc -g AND,NAND,OR,NOR,XOR,XNOR,MUX; opt_clean; tee -o kern_stat.txt stat")
    subprocess.run([YOSYS, "-q", "-p", script], capture_output=True, text=True)
    cellen = ff = 0
    for regel in open("kern_stat.txt"):
        d = regel.split()
        if len(d) >= 2 and d[1] == "cells":
            cellen = int(d[0])
        if len(d) == 2 and d[1].startswith("$_DFF"):
            ff += int(d[0])
    return cellen, ff


if __name__ == "__main__":
    print(f"{'PCW':>4} {'AW':>3} {'RAM (bytes)':>12} {'cellen':>7} {'flipflops':>10}")
    for pcw, aw in [(6, 0), (6, 2), (6, 3), (6, 4), (6, 5), (8, 8)]:
        c, f = schat(pcw, aw)
        print(f"{pcw:4d} {aw:3d} {(1 << aw):12d} {c:7d} {f:10d}")
