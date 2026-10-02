#!/bin/bash
# Identical-results suite: runs official regenie v4.1.3 and a candidate build on the same inputs and compares every
# step 1 .loco and step 2 .regenie file byte for byte.
#   17 cases: step 1 quantitative (2 traits and 1 trait), binary, missing phenotypes and genotypes with --remove,
#     many level-1 predictors (--bsize 200; quantitative and binary); step 2 on imp.bgen (2 traits, 1 trait, missing,
#     binary with Firth at --pThresh 0.01 and the default 0.05, SPA, no correction), on allpairs.bgen (every 8-bit
#     probability pair; also with --ref-first) and on the PLINK .bed (quantitative; binary with Firth).
#     Step 2 cases of both builds read the official build's step 1 predictions, so they compare identical inputs.
#   2 end-to-end cases: each build's own step 1 predictions -> its own step 2 (quantitative; binary with Firth).
#   thread consistency: 1 vs 4 threads, each build against itself (one step 1 and two step 2 cases).
# usage: suite.sh <data dir> <official regenie> <candidate regenie> <output dir>
#   <data dir>   made by simulate.sh; the programs may be binaries or the package launchers (regenie-official,
#                regenie-fast). The output dir path must not contain spaces (regenie's --pred lists cannot hold them).
# env: THREADS (default 2) for all cases except the thread-consistency check.
# Official outputs are kept in <output dir>/official and reused by later runs with the same official program and data;
# candidate outputs go to <output dir>/candidate. Needs bash, awk and coreutils. Exit status 0 = all identical.
set -uo pipefail
[ $# -eq 4 ] || { sed -n '2,/^set -uo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 2; }
abspath() { (cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd)" "$(basename "$1")"); }
for p in "$2" "$3"; do [ -f "$p" ] || { echo "no such program: $p"; exit 2; }; done
DATA=$(cd "$1" && pwd) || exit 2; OFF=$(abspath "$2"); CAND=$(abspath "$3")
mkdir -p "$4" && OUT=$(cd "$4" && pwd) || exit 2
case "$OUT" in *" "*) echo "output dir must not contain spaces: $OUT"; exit 2;; esac
T=${THREADS:-2}; REF=$OUT/official; CO=$OUT/candidate
for f in geno.bed geno_miss.bed covar.txt pheno.txt pheno1.txt pheno_miss.txt bt.txt remove.txt s1_extract.txt \
         imp.bgen imp.sample allpairs.bgen; do
  [ -f "$DATA/$f" ] || { echo "missing $DATA/$f (run simulate.sh first)"; exit 2; }
done
for p in "$OFF" "$CAND"; do "$p" --version > /dev/null 2>&1 || { echo "does not start: $p"; "$p" --version; exit 2; }; done
# cached official outputs are valid only for the same official program, thread count and data files
stamp=$(echo "$OFF threads=$T"; cksum < "$OFF"; "$OFF" --version 2>&1 | head -1
        cd "$DATA" && stat -L -c '%n %s %Y' geno.bed geno_miss.bed imp.bgen allpairs.bgen *.txt imp.sample 2>/dev/null)
if [ -f "$REF/.stamp" ] && [ "$(cat "$REF/.stamp")" != "$stamp" ]; then
  echo "(official program, threads or data changed: recomputing official outputs)"; rm -rf "$REF"; fi
rm -rf "$CO"; mkdir -p "$REF" "$CO"; printf '%s\n' "$stamp" > "$REF/.stamp"
cd "$DATA"

args_for() { # sets array A to the regenie arguments of case $1; step 2 reads step 1 predictions from folder $2
  local P=$2
  local SM=(--sample imp.sample) C2=(--covarFile covar.txt --bsize 400)
  local S1=(--step 1 --covarFile covar.txt --bsize 1000 --extract s1_extract.txt)
  local G1=(--step 1 --bed geno --covarFile covar.txt --bsize 200)
  case $1 in
    s1_qt)              A=("${S1[@]}" --bed geno --phenoFile pheno.txt);;
    s1_qt1)             A=("${S1[@]}" --bed geno --phenoFile pheno1.txt);;
    s1_bt)              A=("${S1[@]}" --bed geno --phenoFile bt.txt --bt);;
    s1_missing)         A=("${S1[@]}" --bed geno_miss --phenoFile pheno_miss.txt --remove remove.txt);;
    g1_qt)              A=("${G1[@]}" --phenoFile pheno.txt);;
    g1_bt)              A=("${G1[@]}" --phenoFile bt.txt --bt);;
    s2_bgen_qt2)        A=(--step 2 --bgen imp.bgen "${SM[@]}" "${C2[@]}" --phenoFile pheno.txt --pred "$P/s1_qt_pred.list");;
    s2_bgen_qt1)        A=(--step 2 --bgen imp.bgen "${SM[@]}" "${C2[@]}" --phenoFile pheno1.txt --pred "$P/s1_qt_pred.list");;
    s2_bgen_missing)    A=(--step 2 --bgen imp.bgen "${SM[@]}" "${C2[@]}" --phenoFile pheno_miss.txt --remove remove.txt --pred "$P/s1_qt_pred.list");;
    s2_bgen_bt_firth01) A=(--step 2 --bgen imp.bgen "${SM[@]}" "${C2[@]}" --phenoFile bt.txt --bt --firth --approx --pThresh 0.01 --pred "$P/s1_bt_pred.list");;
    s2_bgen_bt_firth05) A=(--step 2 --bgen imp.bgen "${SM[@]}" "${C2[@]}" --phenoFile bt.txt --bt --firth --approx --pred "$P/s1_bt_pred.list");;
    s2_bgen_bt_spa)     A=(--step 2 --bgen imp.bgen "${SM[@]}" "${C2[@]}" --phenoFile bt.txt --bt --spa --pThresh 0.01 --pred "$P/s1_bt_pred.list");;
    s2_bgen_bt_plain)   A=(--step 2 --bgen imp.bgen "${SM[@]}" "${C2[@]}" --phenoFile bt.txt --bt --pred "$P/s1_bt_pred.list");;
    s2_allpairs_qt2)    A=(--step 2 --bgen allpairs.bgen "${SM[@]}" "${C2[@]}" --phenoFile pheno.txt --pred "$P/s1_qt_pred.list");;
    s2_allpairs_ref)    A=(--step 2 --bgen allpairs.bgen "${SM[@]}" "${C2[@]}" --phenoFile pheno.txt --pred "$P/s1_qt_pred.list" --ref-first);;
    s2_bed_qt2)         A=(--step 2 --bed geno --extract s1_extract.txt "${C2[@]}" --phenoFile pheno.txt --pred "$P/s1_qt_pred.list");;
    s2_bed_bt)          A=(--step 2 --bed geno --extract s1_extract.txt "${C2[@]}" --phenoFile bt.txt --bt --firth --approx --pThresh 0.01 --pred "$P/s1_bt_pred.list");;
    e2e_qt)             A=(--step 2 --bgen imp.bgen "${SM[@]}" "${C2[@]}" --phenoFile pheno.txt --pred "$P/s1_qt_pred.list");;
    e2e_bt)             A=(--step 2 --bgen imp.bgen "${SM[@]}" "${C2[@]}" --phenoFile bt.txt --bt --firth --approx --pThresh 0.01 --pred "$P/s1_bt_pred.list");;
  esac
}
same_bytes() { if command -v cmp > /dev/null; then cmp -s "$1" "$2"; else [ "$(cksum < "$1")" = "$(cksum < "$2")" ]; fi; }
detail() { # how two differing text files differ: line counts, number of differing values, largest relative difference
  awk -v F1="$1" '
    FILENAME == F1 { line[FNR] = $0; nf1 = FNR; next }
    { nf2 = FNR; if ($0 == line[FNR]) next
      na = split(line[FNR], a, " "); m2 = (na > NF ? na : NF)
      for (i = 1; i <= m2; i++) { x = a[i] ""; y = $i ""
        if (x != y) { d++
          if (x ~ /^-?[0-9.]+([eE][-+]?[0-9]+)?$/ && y ~ /^-?[0-9.]+([eE][-+]?[0-9]+)?$/) {
            xn = x + 0; yn = y + 0; ax = (xn < 0 ? -xn : xn); ay = (yn < 0 ? -yn : yn)
            r = (xn - yn) / (ax > ay ? ax : ay); if (r < 0) r = -r; if (r > m) m = r
          } else s++ } } }
    END { if (nf1 + 0 != nf2 + 0) printf "different number of lines (%d vs %d)", nf1, nf2
          else printf "%d values differ, largest relative difference %.1e%s", d, m, (s ? ", " s " non-numeric" : "") }' "$1" "$2"; }
cmpfiles() { # case, official folder, candidate folder: compares all .loco and .regenie files of the case
  local n=$1 a=$2 b=$3 bad=0 nf=0 f g
  for f in "$a/${n}"_*.loco "$a/${n}"_*.regenie; do [ -f "$f" ] || continue; nf=$((nf + 1)); g=$b/$(basename "$f")
    if [ ! -f "$g" ]; then echo "  $(basename "$f"): MISSING in candidate output"; bad=1
    elif ! same_bytes "$f" "$g"; then echo "  $(basename "$f"): DIFFERS ($(detail "$f" "$g"))"; bad=1; fi
  done
  [ $nf -gt 0 ] || { echo "  no output files from the official run"; bad=1; }
  return $bad; }
run() { # program, output prefix, log file: runs regenie with array A, prints the wall time in seconds
  local t0 t1; t0=$(date +%s.%N)
  "$1" "${A[@]}" --threads "$T" --out "$2" > "$3" 2>&1 || return 1
  t1=$(date +%s.%N); awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.2f", b - a }'; }

fail=0
for c in s1_qt s1_qt1 s1_bt s1_missing g1_qt g1_bt s2_bgen_qt2 s2_bgen_qt1 s2_bgen_missing s2_bgen_bt_firth01 \
         s2_bgen_bt_firth05 s2_bgen_bt_spa s2_bgen_bt_plain s2_allpairs_qt2 s2_allpairs_ref s2_bed_qt2 s2_bed_bt; do
  args_for $c "$REF"
  if [ ! -f "$REF/$c.done" ]; then
    run "$OFF" "$REF/$c" "$REF/$c.log" > /dev/null && touch "$REF/$c.done" || { echo "$c: OFFICIAL FAILED, see $REF/$c.log"; fail=1; continue; }
  fi
  if ! secs=$(run "$CAND" "$CO/$c" "$CO/$c.log"); then
    echo "$c: CANDIDATE FAILED: $(grep -m1 -i error "$CO/$c.log")"; fail=1; continue; fi
  if cmpfiles $c "$REF" "$CO" > "$CO/$c.cmp"; then echo "$c: identical ($secs s)"; else echo "$c: NOT IDENTICAL"; cat "$CO/$c.cmp"; fail=1; fi
done
# end to end: each build's own step 1 predictions -> its own step 2
for c in e2e_qt e2e_bt; do
  if [ ! -f "$REF/$c.done" ]; then args_for $c "$REF"; run "$OFF" "$REF/$c" "$REF/$c.log" > /dev/null && touch "$REF/$c.done"; fi
  args_for $c "$CO"
  run "$CAND" "$CO/$c" "$CO/$c.log" > /dev/null || { echo "$c: CANDIDATE FAILED"; fail=1; continue; }
  if cmpfiles $c "$REF" "$CO" > "$CO/$c.cmp"; then echo "$c: identical"; else echo "$c: NOT IDENTICAL"; cat "$CO/$c.cmp"; fail=1; fi
done
# thread consistency: 1 vs 4 threads, each build compared with itself (official result cached)
same_threads() { # folder: 1 if all t1_ and t4_ outputs of case $c are identical
  local same=1 f; for f in "$1/t1_${c}"_*.loco "$1/t1_${c}"_*.regenie; do [ -f "$f" ] || continue
    same_bytes "$f" "$1/t4_${f#"$1/t1_"}" || same=0; done; echo $same; }
word() { [ "$1" = 1 ] && echo identical || echo DIFFERENT; }
for c in s1_qt s2_bgen_qt2 s2_bgen_bt_firth01; do
  args_for $c "$REF"
  if [ ! -f "$REF/t4_$c.done" ]; then
    "$OFF" "${A[@]}" --threads 1 --out "$REF/t1_$c" > /dev/null 2>&1; "$OFF" "${A[@]}" --threads 4 --out "$REF/t4_$c" > /dev/null 2>&1
    same_threads "$REF" > "$REF/t4_$c.same"; touch "$REF/t4_$c.done"
  fi
  "$CAND" "${A[@]}" --threads 1 --out "$CO/t1_$c" > /dev/null 2>&1; "$CAND" "${A[@]}" --threads 4 --out "$CO/t4_$c" > /dev/null 2>&1
  echo "threads 1 vs 4, $c: candidate $(word "$(same_threads "$CO")"), official $(word "$(cat "$REF/t4_$c.same")")"
done
echo "SUITE: $([ $fail = 0 ] && echo ALL IDENTICAL || echo FAILURES)"
exit $fail
