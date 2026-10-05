# FILE: tt_t8/chip_size.sh
#!/bin/bash
# Schat de grootte van de chip: Yosys zet het ontwerp om in eenvoudige poorten en flipflops, zoals voor een echte chip.
# Er is hier geen echte celbibliotheek (SKY130) bij, dus dit is een SCHATTING in 'poorten', niet de uiteindelijke oppervlakte.
# Gebruik:  bash chip_size.sh [PCW] [AW]      (standaard 6 en 3)       VENV=map met de Yosys-installatie
VENV=${VENV:-$HOME/fpga-venv}
PCW=${1:-6}
AW=${2:-3}
YOSYS="$VENV/bin/yowasp-yosys"
python3 tta_asm.py chip.tta
python3 mkrom.py chip.hex $PCW > rom_t8.v
sed "s/#(.PCW(6), .AW(3))/#(.PCW($PCW), .AW($AW))/; s/wire \[5:0\]  pc_addr;/wire [$((PCW-1)):0]  pc_addr;/; s/assign uio_out = {halted, 1'b0, pc_addr};/assign uio_out = {halted, {$((7-PCW)){1'b0}}, pc_addr};/" tt_t8.v > tt_t8_cfg.v
"$YOSYS" -q -p "read_verilog -sv tt_t8_cfg.v t8_core.v rom_t8.v; synth -top tt_um_t8_tta -flatten; abc -g AND,NAND,OR,NOR,XOR,XNOR,MUX; opt_clean; tee -o chip_stat.txt stat" > /dev/null
grep -E "cells|\\\$_" chip_stat.txt | sed 's/^ *//'
