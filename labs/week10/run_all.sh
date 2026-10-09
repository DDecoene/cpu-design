#!/bin/bash
# Gebruik: bash run_all.sh   (in een map met je .v-bestanden)
fail=0
for tb in tb_*.v; do
  others=$(ls *.v | grep -v '^tb_')
  if ! iverilog -g2012 -o /tmp/regr.vvp "$tb" $others 2>/tmp/regr.err; then
    echo "COMPILE-FOUT  $tb"; cat /tmp/regr.err; fail=1; continue
  fi
  out=$(vvp /tmp/regr.vvp)
  if echo "$out" | grep -q FAIL || ! echo "$out" | grep -q PASS; then
    echo "FOUT          $tb"; echo "$out" | tail -5; fail=1
  else
    echo "ok            $tb"
  fi
done
exit $fail
