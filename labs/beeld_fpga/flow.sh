#!/bin/bash
# Synthese, plaatsen en routeren en een bitstream voor de beeldcomputer op een iCE40 UP5K, met de open-source tools.
# Gebruik:  bash flow.sh          (vanuit labs/beeld_fpga; de bronbestanden staan in ../beeld)
# Omgevingsvariabelen:  VENV=map met de virtuele omgeving   PCF=pinbestand van je bord   SEED=startwaarde voor het plaatsen
set -e
VENV=${VENV:-$HOME/fpga-venv}
SEED=${SEED:-1}
SRC=$(cd ../beeld && pwd)                       # absoluut, want we gaan zo naar uit/

# Dezelfde afgesloten Python-omgeving als in week 23 (wordt aangemaakt als hij nog niet bestaat)
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet yowasp-yosys yowasp-nextpnr-ice40
fi
YOSYS="$VENV/bin/yowasp-yosys"; NEXTPNR="$VENV/bin/yowasp-nextpnr-ice40"; PACK="$VENV/bin/yowasp-icepack"

mkdir -p uit && cd uit
python3 "$SRC/asm.py" "$SRC/boot.asm"        # boot.hex en boot.dat komen naast boot.asm
cp "$SRC/boot.hex" prog.hex                  # Yosys leest de standaardnamen ook; ze moeten bestaan
cp "$SRC/boot.dat" data.hex
cp "$SRC/boot.hex" "$SRC/boot.dat" .

# Alleen de synthetiseerbare bestanden: de testbenches, de virtuele monitor en het SD-model blijven buiten de chip.
V=""
for f in alu idecode memories memories_f datapath_i control_f mmio_f mmio_v mmio_b cpu_b video_io spi_io spi_master \
         fb_ram video_out vga_sync reset_sync beeld_top; do V="$V $SRC/$f.v"; done
V="$V ../pll_ice40.v ../ice40_top.v"

echo "=== synthese"
"$YOSYS" -q -l synth.log -p "read_verilog -sv $V; synth_ice40 -flatten -top ice40_top -json top.json; tee -o stat.txt stat"
grep -E "SB_LUT4|SB_DFF|SB_RAM40|SB_CARRY|SB_PLL" stat.txt

echo "=== plaatsen en routeren (UP5K, 12 MHz als doel voor de CPU-klok)"
PINS="--pcf-allow-unconstrained"
[ -n "$PCF" ] && PINS="--pcf ../$PCF"
[ -z "$PCF" ] && echo "LET OP: zonder PCF kiest nextpnr zelf pinnen. Goed om te meten, niet om op een bord te laden."
"$NEXTPNR" --up5k --package sg48 --json top.json --asc top.asc --freq 12 $PINS --seed "$SEED" -l pnr.log -q || true
grep -E "ICESTORM_LC:|ICESTORM_RAM:" pnr.log | tail -2
grep -E "Max frequency" pnr.log | tail -2
echo "(de pixelklok moet minstens 25,125 MHz halen, de CPU-klok minstens 12 MHz)"

if [ -f top.asc ]; then
  "$PACK" top.asc top.bin && echo "=== bitstream: uit/top.bin ($(wc -c < top.bin) bytes)"
fi
