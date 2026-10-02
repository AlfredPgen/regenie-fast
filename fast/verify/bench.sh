#!/bin/bash
# Side-by-side timing of official regenie v4.1.3 and a candidate build on the same data and thread counts. Rounds
# alternate which build runs first. Per thread count and round, each build runs:
#   step1_qt       step 1, Y1 and Y2, SNPs of s1_50k.txt (chromosomes 1-5), --bsize 1000
#   step1_bt       step 1, binary B1, same SNPs and --bsize
#   step2_qt       step 2 on imp.bgen, Y1 and Y2, --bsize 400
#   step2_bt       step 2 on imp.bgen, B1 with --firth --approx --pThresh 0.01, --bsize 400
#   level1_bt2500  step 1, B1, all SNPs at --bsize 200 (many level-1 predictors; at LEVEL1_THREADS only)
# Step 2 uses predictions from one official step 1 run (2 threads), computed once into <output dir>/pred.
# usage: bench.sh <data dir> <official regenie> <candidate regenie> <output dir>
# env:   THREADS_LIST (default "1 2 4"), ROUNDS (rounds per entry of THREADS_LIST, default "3 3 2"),
#        LEVEL1_THREADS (default 2; empty to skip level1_bt2500), LEVEL1_ROUNDS (default 2)
# Writes <output dir>/bench.csv (threads,round,build,step,wall,cpu in seconds) and, with python3,
# <output dir>/bench_table.md (made by bench_table.py). cpu = user + system seconds, measured with bash's time.
# The output dir path must not contain spaces. Run nothing else on the machine meanwhile.
set -uo pipefail
[ $# -eq 4 ] || { sed -n '2,/^set -uo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 2; }
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
abspath() { (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd)" "$(basename "$1")"); }
DATA=$(cd "$1" && pwd) || exit 2; OFF=$(abspath "$2"); CAND=$(abspath "$3")
mkdir -p "$4" && O=$(cd "$4" && pwd) || exit 2
case "$O" in *" "*) echo "output dir must not contain spaces: $O"; exit 2;; esac
THREADS_LIST=${THREADS_LIST:-1 2 4}; ROUNDS=${ROUNDS:-3 3 2}; LEVEL1_THREADS=${LEVEL1_THREADS-2}; LEVEL1_ROUNDS=${LEVEL1_ROUNDS:-2}
for f in geno.bed covar.txt pheno.txt bt.txt s1_extract.txt s1_50k.txt imp.bgen imp.sample; do
  [ -f "$DATA/$f" ] || { echo "missing $DATA/$f (run simulate.sh first)"; exit 2; }
done
cd "$DATA"
mkdir -p "$O/pred"
for t in qt:pheno.txt bt:bt.txt; do IFS=: read -r n ph <<< "$t"
  extra=(); [ "$n" = bt ] && extra=(--bt)
  [ -f "$O/pred/s1_${n}_pred.list" ] || "$OFF" --step 1 --bed geno --covarFile covar.txt --phenoFile "$ph" ${extra[@]+"${extra[@]}"} \
    --bsize 1000 --extract s1_extract.txt --threads 2 --out "$O/pred/s1_$n" > "$O/pred/s1_$n.log" 2>&1 \
    || { echo "official step 1 for the predictions failed, see $O/pred/s1_$n.log"; exit 1; }
done
CSV=$O/bench.csv; echo "threads,round,build,step,wall,cpu" > "$CSV"
prog() { if [ "$1" = official ]; then echo "$OFF"; else echo "$CAND"; fi; }
run() { # threads round build step regenie-arguments...
  local T=$1 r=$2 b=$3 s=$4; shift 4; local P=$O/t${T}_r${r}_$b TIMEFORMAT='%R %U %S'; mkdir -p "$P"
  { time "$(prog "$b")" "$@" --threads "$T" --out "$P/$s" > "$P/$s.log" 2>&1; } 2> "$P/$s.time" \
    || { echo "FAILED: $b $s, $T threads, see $P/$s.log"; return; }
  tail -1 "$P/$s.time" | awk -v p="$T,$r,$b,$s" '{ printf "%s,%.2f,%.2f\n", p, $1, $2 + $3 }' >> "$CSV"; }
set -- $ROUNDS
for T in $THREADS_LIST; do
  NR=${1:-1}; [ $# -gt 0 ] && shift
  for r in $(seq 1 "$NR"); do
    if [ $((r % 2)) -eq 1 ]; then ORDER="official candidate"; else ORDER="candidate official"; fi
    for b in $ORDER; do
      run "$T" "$r" $b step1_qt --step 1 --bed geno --extract s1_50k.txt --covarFile covar.txt --phenoFile pheno.txt --bsize 1000
      run "$T" "$r" $b step1_bt --step 1 --bed geno --extract s1_50k.txt --covarFile covar.txt --phenoFile bt.txt --bt --bsize 1000
      run "$T" "$r" $b step2_qt --step 2 --bgen imp.bgen --sample imp.sample --covarFile covar.txt --phenoFile pheno.txt \
        --pred "$O/pred/s1_qt_pred.list" --bsize 400
      run "$T" "$r" $b step2_bt --step 2 --bgen imp.bgen --sample imp.sample --covarFile covar.txt --phenoFile bt.txt --bt \
        --firth --approx --pThresh 0.01 --pred "$O/pred/s1_bt_pred.list" --bsize 400
      [ "$T" = "$LEVEL1_THREADS" ] && [ "$r" -le "$LEVEL1_ROUNDS" ] && \
        run "$T" "$r" $b level1_bt2500 --step 1 --bed geno --covarFile covar.txt --phenoFile bt.txt --bt --bsize 200
    done
  done
  echo "done: $T threads"
done
if command -v python3 > /dev/null; then python3 "$HERE/bench_table.py" "$CSV" | tee "$O/bench_table.md"; fi
echo "BENCH DONE: $CSV"
