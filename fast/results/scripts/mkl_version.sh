#!/bin/bash
# Prints the MKL build each binary reports at run time (MKL_VERBOSE=1), on regenie's example data.
# usage (WSL): bash mkl_version.sh <folder with regenie's example data, e.g. the test/ folder of the release package>
T=${1:?usage: mkl_version.sh <example data folder>}; O=$(mktemp -d)
for b in regenie_official regenie_merged; do
  echo "== $b: $(MKL_VERBOSE=1 ~/rgprof/bin/$b --step 1 --bed $T/example --covarFile $T/covariates.txt --phenoFile $T/phenotype.txt --bsize 100 --threads 1 --out $O/$b 2>&1 | grep -m1 'MKL_VERBOSE oneMKL')"
done
rm -rf $O
