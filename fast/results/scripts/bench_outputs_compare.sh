#!/bin/bash
# Byte comparison of every .loco/.regenie file written during the v2 benchmark (work/bench2.sh): official regenie
# v4.1.3 vs regenie-fast v2, same command, same thread count, same round. usage (WSL): bash bench_outputs_compare.sh
cd ~/rgprof/bench_merged || exit 1
n=0; bad=0
for d in t*_r*_official; do
  c=${d/_official/_candidate}
  for f in $d/*.loco $d/*.regenie; do
    [ -f "$f" ] || continue
    g=$c/$(basename $f); n=$((n+1))
    if [ -f "$g" ] && cmp -s "$f" "$g"; then echo "$f: identical"; else echo "$f: DIFFERS"; bad=$((bad+1)); fi
  done
done
echo "BENCHMARK OUTPUTS: $n files compared, $bad differ"
