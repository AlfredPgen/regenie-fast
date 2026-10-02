#!/bin/bash
# Simulates the test data for suite.sh and bench.sh into one folder (sim_plink.py, sim_bgen.py, sim_allpairs.py,
# make_inputs.py).
# usage: simulate.sh <data dir> [bench|tiny]
#   bench (default): 10,000 samples; PLINK 10 chromosomes x 10,000 SNPs; imp.bgen 10 x 2,000 variants;
#                    allpairs.bgen 300 variants. About 800 MB on disk, a few minutes.
#   tiny:            2,000 samples; PLINK 3 x 1,000 SNPs; imp.bgen 2 x 1,000 variants; allpairs.bgen 300 variants.
#                    About 15 MB, seconds; suite.sh then takes about a minute.
# env: PYTHON (default python3; needs numpy)
set -euo pipefail
[ $# -ge 1 ] || { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 2; }
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PY=${PYTHON:-python3}; D=$1; PRESET=${2:-bench}
case $PRESET in
  bench) N=10000 PC=10 PM=10000 BC=10 BM=2000;;
  tiny)  N=2000  PC=3  PM=1000  BC=2  BM=1000;;
  *) echo "unknown preset: $PRESET (bench or tiny)"; exit 2;;
esac
mkdir -p "$D"
"$PY" "$HERE/sim_plink.py" --out "$D" --samples $N --chromosomes $PC --snps-per-chr $PM
"$PY" "$HERE/sim_bgen.py" --out "$D" --samples $N --chromosomes $BC --variants-per-chr $BM
"$PY" "$HERE/sim_allpairs.py" --out "$D" --samples $N --variants 300
"$PY" "$HERE/make_inputs.py" --dir "$D"
echo "simulate: $PRESET data ready in $D"
