# Verification

This file describes how we established that regenie-fast gives the same results as official regenie v4.1.3, and
the limits of that evidence. In short: on simulated data, every `.loco` and `.regenie` file that regenie-fast wrote
was byte-identical to the file written by the official release program, in 19 test cases and in all further runs we
compared; many options and inputs were not tested (see [Not tested](#not-tested)). The scripts are in
[verify/](verify/) and their logs in [results/](results/).

## What was compared

- **Reference:** the official regenie v4.1.3 program for Linux with Intel MKL, `regenie_v4.1.3.gz_x86_64_Linux_mkl`
  from the [v4.1.3 release](https://github.com/rgcgithub/regenie/releases/tag/v4.1.3), unchanged (SHA-256
  `d8dc4118a895cd179e1fdef53d4caee8536a45aeb5aab69ac8c78e2e8e3c0055`). All comparisons are against this program,
  not against our own rebuild of the original source.
- **Tested program:** regenie-fast, built from regenie v4.1.3 plus the changes in [CHANGES.md](CHANGES.md). All
  results below were obtained with the program whose SHA-256 is
  `61cbf8994d43d547929718e6f33b3d63255ad1bda3314e7eba4f06d74e9fa6c5`; building tag v4.1.3-fast1 with the recipe in
  [build/](build/) gives this program bit for bit
  ([results/rebuild_v4.1.3-fast1.log](results/rebuild_v4.1.3-fast1.log)).
- **Method:** both programs were run with the same arguments, on the same machine, with the same thread count, and
  every `.loco` (step 1) and `.regenie` (step 2) file was compared byte for byte (`cmp`). Log files were not compared,
  as they contain timings.
- **Machine:** Intel Core i7-11370H (4 cores, 8 threads, AVX-512), Windows 11 with WSL 2, Ubuntu 26.04.1, Linux
  kernel 6.18, 7 GiB of memory available to WSL, data on the WSL ext4 file system
  ([results/system_info.log](results/system_info.log)).

## The build and the MKL pin

regenie does most of its step 1 arithmetic in Intel MKL. Different MKL versions can use different kernels and block
sizes, which changes the last bits of matrix products; in step 1 such differences can change a printed digit of a
LOCO prediction, and step 2 reads those printed values. Code changes can therefore only be compared with the official
program if the MKL is the same.

The build recipe in [build/](build/) uses the toolchain of regenie's own `Dockerfile_mkl` (Ubuntu 22.04, gcc 9,
BGEN 1.1.7, HTSlib 1.18, static MKL, Boost Iostreams) and pins Intel oneMKL to 2024.2.0. At run time, the official
program and regenie-fast both report the same MKL build, `oneMKL 2024.0 Update 2 Product build 20240605`, which is
how MKL 2024.2.0 identifies itself ([results/mkl_version.log](results/mkl_version.log)).

The official program contains AVX2 and FMA instructions in some of regenie's own routines (it stops with "Illegal
instruction" on CPUs without AVX), while our build compiles regenie's code for generic x86-64. Where the source is
unchanged, our build can therefore round differently from the official program in those routines. This does not
affect the comparisons below, which are always against the official program itself.

## Test data

All tests use simulated data ([verify/](verify/) contains the simulation scripts):

- **PLINK bed:** 10,000 samples, 100,000 SNPs on 10 chromosomes (10,000 per chromosome), minor allele frequencies
  uniform between 0.02 and 0.5, 100 causal SNPs. A copy with about 1% of genotype calls set to missing.
- **Phenotypes:** two quantitative traits; one binary trait with 1,500 cases and 8,500 controls; a version of the
  quantitative traits with missing values (150 in the first trait, 47 in the second, so the two traits have
  different missingness patterns). **Covariates:** 4 (three normal variables and an integer "age"). A `--remove`
  list of 20 samples.
- **BGEN (imputed-style):** BGEN v1.2, layout 2, 8-bit probabilities, zlib compression, with `.bgi` index and
  `.sample` file; 10,000 samples, 20,000 variants on 10 chromosomes, dosages with per-sample imputation uncertainty.
- **BGEN (all probability pairs):** 300 variants on 10,000 samples that together contain every valid pair of 8-bit
  probabilities (all 32,896 pairs, each 87 to 93 times), with about 10 missing genotypes (1 sample in 997) in every
  third variant, 1,001 in total; this checks the dosage parser on every possible input value.

## The identical-results suite (19 cases)

`verify/suite.sh` runs each case with the official program and with regenie-fast at `--threads 2`. Step 2 cases read
the official program's step 1 predictions (`--pred`), so they test step 2 alone; the two end-to-end cases chain each
program's own step 1 and step 2.

| Case | Command (shared options omitted) | What it covers |
|---|---|---|
| `s1_qt` | `--step 1 --bed geno --extract` (20,000 SNPs, 2 chromosomes) `--bsize 1000`, 2 quantitative traits | level 0 and level 1, quantitative |
| `s1_qt1` | as `s1_qt`, 1 quantitative trait | single trait |
| `s1_bt` | as `s1_qt`, `--bt`, 1 binary trait | level 1 logistic |
| `s1_missing` | as `s1_qt`, bed with 1% missing calls, missing phenotypes, `--remove` (20 samples) | imputation, masks, removed samples |
| `g1_qt` | `--step 1 --bed geno` (100,000 SNPs) `--bsize 200`, 2 quantitative traits | 500 blocks, 2,500 level 1 predictors |
| `g1_bt` | as `g1_qt`, `--bt` | 2,500 level 1 predictors, logistic |
| `s2_bgen_qt2` | `--step 2 --bgen imp.bgen --sample imp.sample --bsize 400`, 2 quantitative traits | BGEN reading, parser, closed-form tests |
| `s2_bgen_qt1` | as above, 1 quantitative trait | |
| `s2_bgen_missing` | as above, missing phenotypes, `--remove` | traits with their own masks, samples outside the analysis |
| `s2_bgen_bt_firth01` | `--bt --firth --approx --pThresh 0.01` | approximate Firth |
| `s2_bgen_bt_firth05` | `--bt --firth --approx` (default `--pThresh 0.05`) | approximate Firth, more corrected variants |
| `s2_bgen_bt_spa` | `--bt --spa --pThresh 0.01` | saddle-point approximation |
| `s2_bgen_bt_plain` | `--bt` | binary score test without correction |
| `s2_allpairs_qt2` | all-pairs BGEN, 2 quantitative traits | every 8-bit probability pair, missing genotypes |
| `s2_allpairs_ref` | as above, `--ref-first` | allele order |
| `s2_bed_qt2` | `--step 2 --bed geno --extract` (20,000 SNPs), 2 quantitative traits | PLINK bed in step 2 |
| `s2_bed_bt` | as above, `--bt --firth --approx --pThresh 0.01` | bed, Firth, sparse genotype vectors |
| `e2e_qt` | each program's own `s1_qt` predictions, then step 2 on the BGEN | end to end |
| `e2e_bt` | each program's own `s1_bt` predictions, then step 2 with Firth | end to end |

Shared options: `--covarFile covar.txt --phenoFile <traits> --threads 2`, and `--bsize 400` in step 2.

**Result: all 19 cases identical** ([results/v2_identical_results_suite.log](results/v2_identical_results_suite.log)).
They wrote 28 output files (9 `.loco`, 19 `.regenie`) with 301,435 lines and 6,314,063 whitespace-separated fields;
none differed ([results/suite_value_counts.log](results/suite_value_counts.log)).

**Thread counts.** For `s1_qt`, `s2_bgen_qt2` and `s2_bgen_bt_firth01`, each program was also run with `--threads 1`
and `--threads 4`. Each program gave identical files at 1 and 4 threads (same log). Changes 2 and 5 in CHANGES.md
take a different path with one thread; the benchmark runs below also compare 1-thread and 4-thread runs directly
with the official program.

**Each change set separately.** The changes were made in five sets (step 2 input, step 2 closed-form tests, step 2
Firth and SPA, step 1 level 0, step 1 level 1), each on top of a first round of changes. Each set passed the same
suite on its own before the sets were merged (`results/suite_s2i.log`, `suite_s2c.log`, `suite_s2f.log`,
`suite_l0.log`, `suite_l1.log`).

**Determinism of the reference.** The suite was also run with the official program in place of regenie-fast: all
cases identical, so the official program gives the same files from run to run on this machine
([results/suite_official_selfcheck.log](results/suite_official_selfcheck.log)).

## Further comparisons

| Comparison | Runs | Files compared | Result | Log |
|---|---|---|---|---|
| Benchmark runs ([BENCHMARKS.md](BENCHMARKS.md)): step 1 with 50,000 SNPs (2 quantitative traits; 1 binary trait), step 2 on the BGEN (2 quantitative traits; binary with Firth), step 1 binary with 2,500 level 1 predictors | 1, 2 and 4 threads, 2 or 3 rounds each | 50 | all identical | [results/bench_outputs_compare.log](results/bench_outputs_compare.log) |
| `--lowmem` (quantitative and binary), `--split-l0` / `--run-l0` (2 jobs) / `--run-l1` (quantitative), step 2 with `--gz` (quantitative; binary with Firth) | 2 threads | 8 | all identical | [results/extra_options_v2.log](results/extra_options_v2.log) |
| Peak-memory runs (step 1 and step 2, quantitative and binary) | 2 threads | 6 | all identical | [results/memory_v2.log](results/memory_v2.log) |

**Internal values (first round of changes only).** For the first round of changes, instrumented builds of the
original and the changed source logged internal values: the parsed BGEN dosage vectors and sums were bit-identical
for every variant; step 1 LOCO predictions differed by at most 1.1e-14 of the largest value; in step 2, test
statistics differed by at most 7.1e-12 (absolute), -log10 p by at most 1.4e-11 (absolute), standard errors by at most
1.3e-13 (relative) and effect estimates (BETA) by at most 4.2e-8 (relative; the largest difference per run ranged
from 1.7e-12 in a binary-trait run to 4.2e-8 in the quantitative-trait run with missing phenotypes); all printed
files were identical to the official program ([results/final_run.log](results/final_run.log); that run used
a smaller simulated data set with 10,000 samples, 5,000 SNPs and 5,000 BGEN variants). The later change sets were
verified through the printed outputs only.

## Package tests on other systems and CPUs

The release package (`regenie-fast-linux-x86_64.zip`) runs both programs with its own copy of the Ubuntu 22.04
system libraries and loader. Its self-test (`selftest.sh`: step 1 and step 2, quantitative and binary, on regenie's
example data with 500 samples and 1,000 SNPs, comparing all outputs) gave identical files from both programs:

- on Ubuntu 26.04 (WSL), Rocky Linux 8 (glibc 2.28) and CentOS 7 (glibc 2.17), the latter two in Docker containers
  (which use the host's Linux kernel, so older kernels themselves were not tested);
- under QEMU CPU emulation of Intel Haswell (AVX2), AMD EPYC Rome and AMD EPYC Milan, where the files were also the
  same as on the build laptop (AVX-512), although MKL chose different code paths (its AVX2 path on Haswell and its
  generic path on the AMD models);
- under emulation of Intel Westmere (no AVX), the official program stopped with "Illegal instruction"; regenie-fast
  ran, and its files were the same as on the other CPUs.

Emulation tests correctness only, not speed. These results are recorded in the package README; the raw logs of
these runs were not kept. Note that with 500 samples the binary-trait step 1 of the self-test uses leave-one-out
cross-validation (regenie switches to it automatically below 5,000 samples).

## What identical output does and does not mean

Byte-identical files mean identical printed text. regenie prints its results with 6 significant digits, while some
changes compute the same quantities with a different order of floating-point operations (marked "Rounding differs" in
[CHANGES.md](CHANGES.md)): the level 0 ridge solutions and fold products in step 1, the level 1 logistic sums, and the
closed-form score tests in step 2. Their internal values differ from those of the original code; in the first-round
measurements above, by up to 1.1e-14 of the largest value for LOCO predictions, 7.1e-12 (absolute) for test statistics
and 1.4e-11 for -log10 p, but by up to 4.2e-8 relative to the value for effect estimates (BETA). Relative differences
are largest for values close to zero, such as effect estimates near 0. A printed digit changes only if a value lies
within that distance of a rounding boundary of its 6th significant digit: for a value with a relative difference of
4e-8 the chance is roughly 0.4% to 4%, depending on its leading digits, while most values differ far less. This did
not happen in any of the comparisons above, but it cannot be excluded for other data, and the chance of at least one
printed difference grows with the number of variants. A LOCO value that printed differently would in turn change the
step 2 results that read it, in their last digits.

The same kind of last-digit difference can arise between any two regenie builds, or between CPU types, because MKL
selects its code by CPU and is not guaranteed to give identical bits across code paths. In our tests the official
program gave identical files at 1 and 4 threads and on all emulated CPUs with AVX (Haswell, EPYC Rome, EPYC Milan); it
does not run on the emulated Westmere. If you need certainty for a specific analysis, run `compare_with_official.sh`
from the package on your data and machine.

## Not tested

Everything below runs at least some changed code (only the exact-arithmetic changes where noted). Change numbers
refer to [CHANGES.md](CHANGES.md).

| Option, input or setting | Changed code it can use | Notes |
|---|---|---|
| PGEN input (`--pgen`), step 1 | 2 to 10 (the bed reader, 1, is not used) | includes "Rounding differs" changes 3, 4, 8 |
| PGEN input, step 2 | 14 (per-trait counts), 15 to 19 | the PGEN reader itself is unchanged; includes the closed-form tests (15) |
| BGEN input in step 1 | 2 to 10, and the seek change in 11 | |
| BGEN other than v1.2 with 8-bit probabilities (for example 16-bit) | 14 (per-trait counts), 15 to 19 | read with regenie's unchanged BGEN library path |
| zstd-compressed BGEN | 11, 13 to 19 | decompression itself is unchanged (zstd) |
| Burden and gene-based tests (`--anno-file`, `--mask-def`, `--set-list`, `--vc-tests`, ...), `--joint` | exact changes only: 11 to 14, 16, 17 | the closed-form tests are not used |
| Interaction tests (`--interaction`, `--interaction-snp`) | exact changes only: 11 to 14, 16 to 18 | the closed-form tests are not used |
| `--mt`, `--multiphen`, `--mcc`, LD matrices (`--compute-corr`) | exact changes only: reading and parsing (11 to 14) | the closed-form tests are not used |
| More than 2 quantitative traits, or more than 1 binary trait | 15 (traits are summed in groups of 4 in one pass) | only 1 and 2 quantitative traits and 1 binary trait were tested |
| Exact Firth (`--firth` without `--approx`) | 15 for the score test that decides which variants are corrected | the exact Firth fit is unchanged |
| `--condition-list`, `--htp`, `--test dominant` / `recessive`, `--use-prs`, `--strict`, `--keep`, `--af-cc`, `--minMAC` / `--minINFO` other than default | 11 to 19 as applicable | `--remove` was tested |
| Chromosome X (non-PAR regions, sex-specific handling) | 15 to 19; the BGEN parser falls back to the original loop there | the simulated data have no chromosome X |
| Time-to-event traits (`--t2e`) | step 1: 1 to 6 and 10; step 2: 11 to 14, 18 and 19 | the closed-form tests and the level 1 Cox model are unchanged |
| `--loocv` (and binary traits with fewer than 5,000 samples, where regenie uses it automatically) | 1, 2 and 10 | the leave-one-out level 0 and level 1 code is unchanged; covered only by the self-test on regenie's 500-sample example data |
| `--l1-phenoList`, `--keep-l0`, `--split-l0` with binary traits | 6 to 9 | `--split-l0` was tested with quantitative traits, `--lowmem` with both |
| Sparse genotype vectors in BGEN input | 14 (the non-zero count comes from the parser) | the simulated BGEN files have almost no dosages exactly 0, so their variants always took the dense path; the sparse path was exercised with PLINK bed input (binary trait, after the flip to the minor allele) |
| Larger data | all | only 10,000 samples (and 500 in the self-test), 4 covariates, step 1 block sizes 1,000, 200 (and 100), step 2 block size 400 (and 200) |
| Thread counts other than 1, 2 and 4 | all | changes 2 and 5 take a different path with one thread, change 18 with more than one |
| Real data | all | only simulated data and regenie's example data were used |
| Other builds: other compilers or flags, OpenBLAS instead of MKL, other MKL versions, macOS, non-x86 CPUs | all | the change 17 kernel is compiled only for GCC 9 with regenie's flags; the change 2 kernels are also compiled by other GCC-compatible compilers (clang, icx, other GCC versions) for x86-64, but their order of operations was matched to the release build only (CHANGES.md, change 2); such builds have not been compared with the official program |

## How to check on your own data

The release package contains the official program next to regenie-fast:

- `./selftest.sh` checks both programs on regenie's example data on the current machine (run it on a compute node
  too).
- `./compare_with_official.sh <new folder> <your regenie arguments without --out>` runs both programs on your command,
  prints both times, and compares every output file value by value. It reports `ALL OUTPUT FILES IDENTICAL`, or the
  number of differing values and the largest relative difference per file.

If you find a difference, please open an issue at https://github.com/AlfredPgen/regenie-fast/issues with the command
and the comparison output.
