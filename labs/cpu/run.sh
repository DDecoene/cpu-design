# FILE: cpu/run.sh
#!/bin/bash
# Gebruik: bash run.sh programma.asm
# Assembleert het programma en draait het op de W8-CPU in de simulator.
python3 asm.py "$1" || exit 1
base="${1%.asm}"
iverilog -g2012 -o w8run.vvp tb_run.v alu.v idecode.v memories.v datapath.v control.v cpu.v || exit 1
if [ -f "$base.dat" ]; then
  vvp w8run.vvp +prog="$base.hex" +data="$base.dat"
else
  vvp w8run.vvp +prog="$base.hex"
fi
