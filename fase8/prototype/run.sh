#!/bin/bash
# Draait het prototype van fase 8: boot.asm van fase 7, vertaald naar de T8, tegen het SD-kaartmodel van fase 7.
# Gebruik (vanuit deze map):  bash run.sh      -> verwacht "PASS: de T8 start de kaart op ..."
set -e
B=../../labs/beeld
python3 ../../labs/tta/tta_asm.py boot_t8.tta
cp $B/sd.hex .
iverilog -g2012 -o tb_boot_t8.vvp tb_boot_t8.v tta_mm.v $B/video_io.v $B/spi_io.v $B/spi_master.v $B/sd_model.v
vvp -n tb_boot_t8.vvp | grep -v finish
rm -f sd.hex
