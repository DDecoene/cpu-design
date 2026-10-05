# FILE: cpu_fpga/gatesim.sh
#!/bin/bash
# Gate-level simulatie: de testbench draait op de door Yosys gesynthetiseerde netlijst (LUT's, flipflops, blok-RAM)
# in plaats van op je Verilog. Zo bewijs je dat de synthese het ontwerp niet veranderd heeft.
# Gebruik: bash gatesim.sh        (na fpga_flow.sh; gebruikt dezelfde VENV)
set -e
VENV=${VENV:-$HOME/fpga-venv}
YOSYS="$VENV/bin/yowasp-yosys"
CELLS=$(ls "$VENV"/lib/python*/site-packages/yowasp_yosys/share/ice40/cells_sim.v)
SOURCES="alu.v idecode.v memories.v memories_f.v datapath_i.v control_f.v mmio_f.v cpu_f.v fpga_top_f.v fpga_top_small.v"
python3 asm.py hello.asm
cp -n hello.hex prog.hex 2>/dev/null || true
cp -n hello.dat data.hex 2>/dev/null || true
"$YOSYS" -q -p "read_verilog -sv $SOURCES; synth_ice40 -flatten -top fpga_top_small; write_verilog -noattr netlist_small.v"
iverilog -g2012 -o gate.vvp tb_gate.v netlist_small.v "$CELLS"
vvp gate.vvp | grep -v finish
