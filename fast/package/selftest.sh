#!/bin/bash
# Quick check on regenie's example data: runs step 1 and step 2 (quantitative and binary traits) with official
# regenie v4.1.3 and regenie-fast, and compares all outputs. Takes a few seconds.
DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
T="$DIR/test"; OUT=${1:-selftest_out}; mkdir -p "$OUT"
"$DIR/regenie-fast" --version > /dev/null 2>&1 || { echo "regenie-fast does not start on this system:"; "$DIR/regenie-fast" --version; exit 1; }
nbad=0; nfail=0
check() { echo "== $1"; "$DIR/compare_with_official.sh" "$OUT/$@"; case $? in 0) ;; 2) nfail=$((nfail + 1));; *) nbad=$((nbad + 1));; esac; }
check s1_qt --step 1 --bed "$T/example" --covarFile "$T/covariates.txt" --phenoFile "$T/phenotype.txt" --bsize 100 --threads 2
check s1_bt --step 1 --bed "$T/example" --covarFile "$T/covariates.txt" --phenoFile "$T/phenotype_bin.txt" --bt --bsize 100 --threads 2
check s2_qt --step 2 --bgen "$T/example.bgen" --covarFile "$T/covariates.txt" --phenoFile "$T/phenotype.txt" --pred "$OUT/s1_qt/official/run_pred.list" --bsize 200 --threads 2
check s2_bt --step 2 --bgen "$T/example.bgen" --covarFile "$T/covariates.txt" --phenoFile "$T/phenotype_bin.txt" --bt --firth --approx --pThresh 0.01 --pred "$OUT/s1_bt/official/run_pred.list" --bsize 200 --threads 2
if [ $nbad = 0 ] && [ $nfail = 0 ]; then echo "SELFTEST PASSED: all 4 runs give identical output"; exit 0; fi
[ $nfail = 0 ] || echo "SELFTEST: $nfail of 4 runs failed to run (see the stdout.txt files named above)"
[ $nbad = 0 ] || echo "SELFTEST: $nbad of 4 runs give different output (details above)"
exit 1
