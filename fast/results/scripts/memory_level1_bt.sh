#!/bin/bash
# Peak memory of the official program and regenie-fast in step 1 with one binary trait and 2,500 level 1 predictors
# (suite case g1_bt: all 100,000 SNPs, --bsize 200 = 500 blocks x 5 level 0 ridge parameters), 2 threads, one run per
# program, at low priority. Prints maximum resident set size (/usr/bin/time %M) and compares the .loco files.
# Elapsed times are not reported: this run measured memory only, while other work was running on the machine.
B=~/rgprof/bin; D=~/rgprof/data; O=~/rgprof/mem_l1
mkdir -p $O && cd $D || exit 1
OPTS="--step 1 --bed geno --covarFile covar.txt --phenoFile bt.txt --bt --bsize 200 --threads 2"
(cd $B && sha256sum regenie_official regenie_merged)
for b in official fast; do
  R=$B/regenie_official; [ $b = fast ] && R=$B/regenie_merged
  nice -n 19 /usr/bin/time -f "%M" -o $O/g1_bt.$b.time $R $OPTS --out $O/g1_bt_$b > /dev/null 2>&1 || echo "g1_bt $b FAILED"
done
for b in official fast; do
  kb=$(tail -n 1 $O/g1_bt.$b.time)
  awk -v b=$b -v kb=$kb 'BEGIN { printf "g1_bt %-8s max RSS %7d KiB = %6.1f MiB\n", b, kb, kb / 1024 }'
done
echo "  options: $OPTS"
cmp -s $O/g1_bt_official_1.loco $O/g1_bt_fast_1.loco && echo "g1_bt_official_1.loco vs fast: identical" \
  || echo "g1_bt_official_1.loco vs fast: DIFFERS"
