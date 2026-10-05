# FILE: stack/runfs.sh
#!/bin/bash
# Gebruik: bash runfs.sh programma.fs
# Compileert een Forth-programma en draait het op de stackmachine S8.
python3 forth.py "$1" || exit 1
iverilog -g2012 -o s8run.vvp tb_s8_run.v s8.v || exit 1
vvp s8run.vvp +prog="${1%.fs}.hex" | grep -v finish
