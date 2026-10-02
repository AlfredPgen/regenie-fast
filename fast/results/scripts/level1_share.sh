#!/bin/bash
# Level 1 time vs total time in the benchmark case "step 1, binary trait, 2,500 level-1 predictors" (2 threads),
# from regenie's own log lines ("-on phenotype 1 (B1)...done (N ms)" and "Elapsed time"). usage (WSL): bash level1_share.sh
cd ~/rgprof/bench_merged || exit 1
for b in official candidate; do for r in 1 2; do f=t2_r${r}_$b/level1_bt2500.log
  l1=$(grep -A1 "Level 1 ridge" $f | grep -o "done ([0-9]*ms)" | grep -o "[0-9]*"); tot=$(grep "Elapsed time" $f | grep -o "[0-9.]*")
  awk -v b=$b -v r=$r -v l1=$l1 -v t=$tot 'BEGIN { printf "%-9s round %d: total %.1f s, level 1 %.1f s (%.0f%%), rest %.1f s\n", b, r, t, l1/1000, 100*l1/1000/t, t - l1/1000 }'
done; done
