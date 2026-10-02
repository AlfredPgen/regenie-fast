# Benchmarks

All numbers below were measured on one laptop with simulated data of 10,000 samples. They show where the changes
help and by how much under these conditions; they are not predictions for other data sizes, other machines or
cluster storage. To measure on your own data, use `compare_with_official.sh` from the release package
([README.md](README.md#quick-start-on-a-linux-cluster)).

## Results

Official regenie v4.1.3 against regenie-fast, same commands, same machine:

| Threads | Run | Official: wall (CPU) | regenie-fast: wall (CPU) | Speed-up [range] | Rounds |
|---|---|---|---|---|---|
| 1 | Step 1, 2 quantitative traits, 50 blocks | 120.3 s (120) | 29.5 s (29) | 4.12x [3.57-4.39] | 3 |
| 1 | Step 1, 1 binary trait, 50 blocks | 117.0 s (117) | 28.8 s (29) | 4.07x [3.84-4.24] | 3 |
| 1 | Step 2, 2 quantitative traits, 20,000 variants | 6.2 s (6) | 3.0 s (3) | 2.08x [1.93-2.16] | 3 |
| 1 | Step 2, 1 binary trait with approximate Firth, 20,000 variants | 5.7 s (6) | 2.9 s (3) | 1.97x [1.86-2.04] | 3 |
| 2 | Step 1, 2 quantitative traits, 50 blocks | 82.7 s (162) | 21.9 s (42) | 3.78x [3.74-3.82] | 3 |
| 2 | Step 1, 1 binary trait, 50 blocks | 82.0 s (160) | 20.7 s (40) | 3.96x [3.96-3.97] | 3 |
| 2 | Step 1, 1 binary trait, 2,500 level 1 predictors | 134.4 s (257) | 84.9 s (169) | 1.58x [1.57-1.60] | 2 |
| 2 | Step 2, 2 quantitative traits, 20,000 variants | 3.4 s (7) | 1.6 s (3) | 2.10x [2.05-2.17] | 3 |
| 2 | Step 2, 1 binary trait with approximate Firth, 20,000 variants | 3.2 s (6) | 1.6 s (3) | 1.95x [1.88-2.01] | 3 |
| 4 | Step 1, 2 quantitative traits, 50 blocks | 70.5 s (270) | 18.0 s (68) | 3.91x [3.89-3.93] | 2 |
| 4 | Step 1, 1 binary trait, 50 blocks | 69.6 s (267) | 17.3 s (65) | 4.02x [4.00-4.05] | 2 |
| 4 | Step 2, 2 quantitative traits, 20,000 variants | 2.0 s (8) | 1.0 s (4) | 1.94x [1.93-1.94] | 2 |
| 4 | Step 2, 1 binary trait with approximate Firth, 20,000 variants | 2.1 s (8) | 1.1 s (4) | 1.87x [1.84-1.90] | 2 |

- **Wall:** elapsed time, mean over rounds. **CPU:** user plus system CPU seconds, mean over rounds; CPU divided by
  wall shows how many cores were busy on average.
- **Speed-up:** official wall time divided by regenie-fast wall time for the same command in the same round,
  averaged over rounds, with the lowest and highest round in brackets. (It is therefore not exactly the ratio of the
  two mean times.)
- Source: [results/v2_side_by_side_table.md](results/v2_side_by_side_table.md), the table that `bench_table.py`
  ([verify/](verify/)) makes from the per-run measurements in [results/v2_side_by_side.csv](results/v2_side_by_side.csv).
- Every output file of these runs (50 files) was byte-identical between the two programs
  ([results/bench_outputs_compare.log](results/bench_outputs_compare.log)).

## Peak memory

Maximum resident set size, one run per program, 2 threads, same data and commands as above
([results/memory_v2.log](results/memory_v2.log) for the first four rows,
[results/memory_level1_bt.log](results/memory_level1_bt.log) for the last):

| Run | Official | regenie-fast |
|---|---|---|
| Step 1, 2 quantitative traits, 50 blocks | 321 MiB | 288 MiB |
| Step 1, 1 binary trait, 50 blocks | 295 MiB | 270 MiB |
| Step 2, 2 quantitative traits, 20,000 variants | 62 MiB | 60 MiB |
| Step 2, 1 binary trait with approximate Firth, 20,000 variants | 65 MiB | 62 MiB |
| Step 1, 1 binary trait, 2,500 level 1 predictors | 442 MiB | 632 MiB |

regenie-fast used less memory in the first four runs, but 190 MiB (43%) more in the binary-trait run with 2,500 level
1 predictors. By the code, the main cause is change 8 in [CHANGES.md](CHANGES.md) (not measured separately): for
binary traits, level 1 keeps the fold products at coefficients 0, which take k x P x P x 8 bytes for k
cross-validation folds (5 by default) and P level 1 predictors (the number of blocks times 5): 250 MB for P = 2,500.
They are kept when they need at most 256 MB, or no more than the level 1 work matrix of P values for each sample of
the largest fold, so with many samples they can take more (1 GB for P = 5,000 with 125,000 samples or more). Two
smaller caches can also add memory: with `--lowmem` or `--run-l1`, up to 256 MB of LOCO prediction blocks (change 9),
and with `--threads 1`, the level 0 predictions of one fold for all ridge parameters, about 8 bytes x traits x samples
and at most 256 MB (change 5).

For step 1 with binary traits and many level 1 predictors, request k x P x P x 8 bytes more memory than for official
regenie (250 MB, so about 0.3 GB, for 2,500 level 1 predictors and 5 folds). Memory was not measured for other options
(including quantitative traits with many level 1 predictors), more samples or more threads.

## Setup

**Machine.** Intel Core i7-11370H (4 cores, 8 threads, AVX-512), Windows 11, WSL 2 with Ubuntu 26.04.1 (Linux
6.18), 7 GiB of memory available to WSL, data on the WSL ext4 file system
([results/system_info.log](results/system_info.log)). CPU frequency scaling and background load were not recorded.

**Programs.** The official regenie v4.1.3 MKL release program and regenie-fast, as described in
[VERIFICATION.md](VERIFICATION.md#what-was-compared). Both use Intel MKL 2024.2.0.

**Data** (simulated, see [VERIFICATION.md](VERIFICATION.md#test-data)): 10,000 samples, 4 covariates.

- Step 1: PLINK bed, the 50,000 SNPs of chromosomes 1 to 5 (`--extract`) with `--bsize 1000`, which
  gives 50 blocks; two quantitative traits, or one binary trait with 1,500 cases and 8,500 controls.
- Step 1 with 2,500 level 1 predictors: all 100,000 SNPs with `--bsize 200`, which gives 500 blocks and, with
  regenie's 5 level 0 ridge parameters, 2,500 predictors at level 1 (as many as in an analysis of 500,000 SNPs with
  `--bsize 1000`); one binary trait. This case was run at 2 threads only.
- Step 2: BGEN v1.2, 8-bit, zlib-compressed, 20,000 variants on 10 chromosomes, `--bsize 400` (50 blocks). Both
  programs read the same step 1 predictions, made by the official program from the 20,000 SNPs of chromosomes 1
  and 2 (suite cases `s1_qt` and `s1_bt` in [VERIFICATION.md](VERIFICATION.md#the-identical-results-suite-19-cases)).

**Commands** (`bench.sh` in [verify/](verify/); `$T` is the thread count):

```
regenie --step 1 --bed geno --extract s1_50k.txt --covarFile covar.txt --phenoFile pheno.txt --bsize 1000 --threads $T --out ...
regenie --step 1 --bed geno --extract s1_50k.txt --covarFile covar.txt --phenoFile bt.txt --bt --bsize 1000 --threads $T --out ...
regenie --step 2 --bgen imp.bgen --sample imp.sample --covarFile covar.txt --phenoFile pheno.txt \
  --pred s1_qt_pred.list --bsize 400 --threads $T --out ...
regenie --step 2 --bgen imp.bgen --sample imp.sample --covarFile covar.txt --phenoFile bt.txt --bt \
  --firth --approx --pThresh 0.01 --pred s1_bt_pred.list --bsize 400 --threads $T --out ...
regenie --step 1 --bed geno --covarFile covar.txt --phenoFile bt.txt --bt --bsize 200 --threads 2 --out ...
```

**Procedure.** For 1, 2 and 4 threads, 3 rounds (2 at 4 threads). In each round, one program ran all the commands,
then the other program ran them: the official program first in odd rounds and regenie-fast first in even rounds.
Each run was timed with `/usr/bin/time` (elapsed, user and system time).

## What these numbers do not show

- **Other data sizes.** Only 10,000 samples were timed. How the gain changes with more samples, more SNPs or more
  covariates was not measured.
- **Other machines.** Only one 4-core laptop was used. Cluster nodes have more cores, other CPUs and network file
  systems; scaling to many threads and the effect of slower storage on step 2 were not measured.
- **Other options and inputs.** PGEN input, BGEN files that are not 8-bit, gene-based and burden tests, interaction
  tests, `--lowmem`, many traits and real data were not timed. Some of them do not use the main changed code paths
  (for example, burden tests do not use the closed-form score tests), so their gain may be small.
- **The level 1 case.** In the run with 2,500 level 1 predictors, regenie's own log shows that level 1 took 92.7 to
  93.3 s of the official program's 134 s and 72.9 to 73.5 s of regenie-fast's 85 s; the rest of the run (reading the
  genotypes and level 0) went from about 41.5 s to about 11.7 s
  ([results/level1_share.log](results/level1_share.log)). In the level 1 logistic fit, the changes remove repeated
  and serial work but not the fold matrix products (`XtW X_k`, change 8 in [CHANGES.md](CHANGES.md)), whose number is
  reduced only at the first iteration of the first ridge parameter (where the products at coefficients 0 are shared
  by all held-out folds); with many level 1 predictors, the gain for binary traits is therefore much smaller than at
  level 0.
