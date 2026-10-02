#!/bin/bash
# Runs official regenie v4.1.3 and regenie-fast on the same command, times both and compares every output file.
# exit status: 0 = all outputs identical, 1 = some differ, 2 = a program failed
# usage:   ./compare_with_official.sh <new output folder> <regenie arguments, without --out>
# example: ./compare_with_official.sh cmp_chr22 --step 2 --bgen chr22.bgen --sample chr22.sample \
#            --phenoFile pheno.txt --covarFile covar.txt --pred fit_pred.list --bsize 400 --threads 8
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
OUT=$1; shift
[ -z "$OUT" ] || [ $# -eq 0 ] && { sed -n 2,6p "$0"; exit 1; }
mkdir -p "$OUT/official" "$OUT/fast"; rm -f "$OUT/times.txt"
for v in official fast; do
  t0=$(date +%s.%N)
  "$DIR/regenie-$v" "$@" --out "$OUT/$v/run" > "$OUT/$v/stdout.txt" 2>&1 || { echo "regenie-$v FAILED, see $OUT/$v/stdout.txt"; exit 2; }
  t1=$(date +%s.%N); awk -v a="$t0" -v b="$t1" -v v="$v" 'BEGIN { printf "%s %.3f\n", v, b - a }' >> "$OUT/times.txt"
done
awk '{ t[$1] = $2 } END { printf "official: %.1f s   fast: %.1f s   speed-up: %.2fx\n", t["official"], t["fast"], t["official"] / t["fast"] }' "$OUT/times.txt"
bad=0
for f in "$OUT"/official/run*; do
  b=$(basename "$f"); g="$OUT/fast/$b"
  case "$b" in *.log|*_pred.list) continue;; esac
  if [ ! -f "$g" ]; then echo "  $b: missing in fast output"; bad=1; continue; fi
  # compare line by line and value by value as text (needs only awk, no cmp/diff); exit status 0 = identical
  awk -v F1="$f" -v FILE="$b" '
       FILENAME == F1 { line[FNR] = $0; nf1 = FNR; next }
       { nf2 = FNR; if (($0 "") == (line[FNR] "")) { n += NF; next }
         na = split(line[FNR], a, " "); m2 = (na > NF ? na : NF)
         for (i = 1; i <= m2; i++) { x = a[i] ""; y = $i ""; n++
           if (x != y) { d++
             if (x ~ /^-?[0-9.]+([eE][-+]?[0-9]+)?$/ && y ~ /^-?[0-9.]+([eE][-+]?[0-9]+)?$/) {
               xn = x + 0; yn = y + 0; ax = (xn < 0 ? -xn : xn); ay = (yn < 0 ? -yn : yn)
               r = (xn - yn) / (ax > ay ? ax : ay); if (r < 0) r = -r; if (r > m) m = r
             } else s++ } } }
       END { if (nf1 + 0 != nf2 + 0) { printf "  %s: different number of lines (%d vs %d)\n", FILE, nf1, nf2; exit 1 }
             if (!d) { printf "  %s: identical\n", FILE; exit 0 }
             printf "  %s: %d of %d values differ (largest relative difference %.1e%s)\n", FILE, d, n, m, (s ? ", " s " non-numeric" : ""); exit 1 }' "$f" "$g" || bad=1
done
if [ $bad = 0 ]; then echo "ALL OUTPUT FILES IDENTICAL"; else echo "Some files differ (details above)"; fi
exit $bad
