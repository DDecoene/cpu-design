#!/bin/bash
# Gebruik: bash run_tta.sh programma.tta [invoerwaarde]
# Assembleert een TTA-programma en draait het in de simulator.
python3 tta_asm.py "$1" || exit 1
base="${1%.tta}"
iverilog -g2012 -o ttarun.vvp tb_tta_run.v tta.v || exit 1
args="+prog=$base.hex"
[ -f "$base.dat" ] && args="$args +data=$base.dat"
[ -n "$2" ] && args="$args +in=$2"
vvp ttarun.vvp $args | grep -v finish
