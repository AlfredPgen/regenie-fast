# Verification and benchmark scripts

These scripts simulate test data, check that a regenie build gives byte-identical output files to official regenie
v4.1.3, and time the two builds side by side. Earlier versions of them, with the test machine's paths built in,
produced the suite and benchmark files in `fast/results` (see `fast/results/README.md`).

| Script | What it does |
|---|---|
| `simulate.sh` | runs the four Python scripts below into one data folder (`tiny` or `bench` size) |
| `sim_plink.py` | PLINK genotypes (`geno.bed/.bim/.fam`), two quantitative traits, one binary trait, covariates |
| `sim_bgen.py` | imputed-style BGEN v1.2 (8-bit, zlib) with `.bgi` index and `.sample` file |
| `sim_allpairs.py` | BGEN containing every valid pair of 8-bit genotype probabilities, some genotypes missing |
| `make_inputs.py` | derived files: one-trait and missing-value phenotypes, `--remove` list, SNP lists, `geno_miss` |
| `suite.sh` | identical-results suite: 17 cases, 2 end-to-end cases, thread consistency |
| `bench.sh`, `bench_table.py` | side-by-side timing, rounds alternating which build runs first, and its table |

Needs: Linux with bash, awk and coreutils for `suite.sh` and `bench.sh` (python3 only for the table at the end of
`bench.sh`), and Python 3 with numpy for the simulation (any OS). The two programs to compare can be plain binaries
or the launchers of the release zip (`regenie-official` = the official v4.1.3 MKL release program, `regenie-fast`).

## Quick check (about a minute)

From the repository root, with `R` set to the folder of the unpacked release zip (the folder that contains the
launchers `regenie-official` and `regenie-fast`), or to `fast/package/out/regenie-fast` after `make_package.sh`:

```
R=/path/to/unpacked/regenie-fast
fast/verify/simulate.sh ~/rgtest/tiny tiny
fast/verify/suite.sh ~/rgtest/tiny "$R/regenie-official" "$R/regenie-fast" ~/rgtest/suite_tiny
```

Every case should print `identical`, and the last line should be `SUITE: ALL IDENTICAL` (exit status 0). For a
case that differs, the suite names the file, the number of values that differ and the largest relative difference.
Official outputs are cached in `<output dir>/official`, so testing another candidate against the same official
program and data only runs the candidate.

## Full size (as in fast/results)

```
fast/verify/simulate.sh ~/rgtest/bench bench         # 10,000 samples, 100,000 SNPs, 20,000 BGEN variants; ~800 MB
fast/verify/suite.sh ~/rgtest/bench <official> <candidate> ~/rgtest/suite_bench
fast/verify/bench.sh ~/rgtest/bench <official> <candidate> ~/rgtest/bench_out
```

`bench.sh` runs 1, 2 and 4 threads (3, 3 and 2 rounds) by default, about 40 minutes on a 4-core laptop; set
`THREADS_LIST` and `ROUNDS` to change that (e.g. `THREADS_LIST="8 16" ROUNDS="2 2"`). It writes `bench.csv` and
`bench_table.md`. Run nothing else on the machine meanwhile.

The `bench` dataset reproduces the one behind `fast/results`: genotype and BGEN files byte for byte, and the
phenotype, covariate, `.bim` and `.fam` files value for value (the original was written on Windows, so those had
CRLF line endings; regenie accepts both).

## What "identical" means here

The suite compares the printed output files (`.loco` from step 1, `.regenie` from step 2) byte for byte (`cmp`, or
`cksum` where `cmp` is missing).
Run both builds on the same machine: MKL picks different code paths on different CPUs, so even the official program
can print different last digits on another CPU type. The candidate must be built with the same MKL version as the
official release (2024.2.0, see `fast/build/README.md`), otherwise unchanged code already differs.
