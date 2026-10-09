#!/bin/bash
# Synthese, plaatsen en routeren, en een bitstream voor een iCE40-FPGA, met de open-source tools.
# Gebruik:  bash fpga_flow.sh [hx8k|up5k] [top]        bijvoorbeeld:  bash fpga_flow.sh hx8k fpga_top
# Omgevingsvariabelen:  VENV=map met de virtuele omgeving   FREQ=doelfrequentie in MHz   PCF=pinbestand van je bord
set -e
DEV=${1:-hx8k}
if [ -f memories_f.v ]; then DEFTOP=fpga_top_f; else DEFTOP=fpga_top; fi   # week 24-versie, of de oorspronkelijke van week 23
TOP=${2:-$DEFTOP}
VENV=${VENV:-$HOME/fpga-venv}
FREQ=${FREQ:-27}

# Eenmalig: een afgesloten Python-omgeving met de tools (niets systeembreed geïnstalleerd, te wissen met rm -r)
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet yowasp-yosys yowasp-nextpnr-ice40
fi
YOSYS="$VENV/bin/yowasp-yosys"
NEXTPNR="$VENV/bin/yowasp-nextpnr-ice40"
PACK="$VENV/bin/yowasp-icepack"

python3 asm.py hello.asm                      # het programma voor de CPU: hello.hex en hello.dat
cp -n hello.hex prog.hex 2>/dev/null || true  # Yosys leest de standaardnamen ook; ze moeten bestaan
cp -n hello.dat data.hex 2>/dev/null || true

SOURCES="alu.v idecode.v memories.v memories_f.v datapath_i.v control_f.v mmio_f.v cpu_f.v fpga_top_f.v"
[ "$TOP" = "fpga_top" ] && SOURCES="alu.v idecode.v memories.v datapath_i.v control_i.v mmio.v cpu_i.v fpga_top.v"

echo "=== synthese ($TOP)"
"$YOSYS" -q -l synth.log -p "read_verilog -sv $SOURCES; synth_ice40 -flatten -top $TOP -json $TOP.json; tee -o stat.txt stat"
grep -E "SB_LUT4|SB_DFF|SB_RAM40|SB_CARRY" stat.txt

case "$DEV" in
  hx8k) ARGS="--hx8k --package ct256" ;;
  up5k) ARGS="--up5k --package sg48" ;;
  *) echo "onbekend apparaat: $DEV"; exit 1 ;;
esac
PINS="--pcf-allow-unconstrained"
[ -n "$PCF" ] && PINS="--pcf $PCF"

echo "=== plaatsen en routeren ($DEV, doel $FREQ MHz)"
set +e
"$NEXTPNR" $ARGS --json $TOP.json --asc $TOP.asc --freq $FREQ $PINS --seed 1 -l pnr.log -q
set -e
grep -E "ICESTORM_LC:|ICESTORM_RAM:|Max frequency" pnr.log | tail -4

if [ -f $TOP.asc ]; then
  "$PACK" $TOP.asc $TOP.bin && echo "=== bitstream: $TOP.bin ($(wc -c < $TOP.bin) bytes)"
fi
