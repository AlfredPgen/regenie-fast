# regenie-fast (regenie v4.1.3, faster build) for Linux x86-64

regenie-fast is a faster build of [regenie](https://github.com/rgcgithub/regenie) v4.1.3 by Joelle Mbatchou,
Andrey Ziyatdinov and Jonathan Marchini. It has the same options and output files as regenie, and in our tests
every output file (step 1 `.loco`, step 2 `.regenie`) was byte-identical to the official v4.1.3 release.
Source code, build recipe and verification scripts: https://github.com/AlfredPgen/regenie-fast

If you use it, please cite regenie:
Mbatchou, J., Barnard, L., Backman, J. et al. Computationally efficient whole-genome regression for quantitative and
binary traits. Nat Genet 53, 1097–1103 (2021). https://doi.org/10.1038/s41588-021-00870-7

## Install

Copy the zip to the cluster, into a folder the compute nodes can see (home or project space), then:

```
unzip regenie-fast-linux-x86_64.zip
cd regenie-fast
./regenie-fast --version
./selftest.sh                      # a few seconds: official vs fast on regenie's example data
```

The self-test checks that both programs give identical results on this system (expected last line:
`SELFTEST PASSED`); its data are tiny, so its timings mean nothing. Run it once on a compute node as well
(`srun ./selftest.sh` or inside a job), since login and compute nodes often have different CPUs.

## What it needs from the cluster

Only an x86-64 Linux system with bash. It brings its own system libraries and loader in `lib/`, so the cluster's
Linux version, glibc and installed libraries do not matter, and no `module load` is needed. Loaded modules do not
interfere: the launchers ignore `LD_LIBRARY_PATH` and clear `LD_PRELOAD` (cluster monitoring tools such as XALT or
Darshan preload libraries that would otherwise stop it from starting).

Tested on Ubuntu 26.04, Rocky Linux 8 (glibc 2.28) and CentOS 7 (glibc 2.17), and under emulated cluster CPUs:
Intel Haswell (AVX2), AMD EPYC Rome and AMD EPYC Milan all gave official = fast, byte for byte, and also the same
files as on the build laptop (Intel, AVX-512), although MKL switched code paths (AVX2 on Haswell, its generic path
on AMD). On a pre-2011 CPU without AVX (Westmere) the official release crashes ("Illegal instruction"), while
regenie-fast runs and gives the same files. Emulation checks correctness only; speed has to be measured on the
cluster.

Keep the folder together: the launchers find `bin/` and `lib/` next to themselves (a symlink to a launcher, e.g. from
`~/bin`, works). If starting it says `Permission denied`, either the execute permissions were lost when copying
(`chmod +x regenie-fast regenie-official *.sh lib/ld-linux-x86-64.so.2 bin/*`) or the folder is on a filesystem
that does not allow running programs (some scratch areas); move it to home or project space.

## Memory

Peak memory (maximum resident set size), 10k samples, 2 threads, regenie-fast (official): step 1 with 50 blocks,
quantitative 288 MiB (321 MiB), binary 270 MiB (295 MiB); step 2 quantitative 60 MiB (62 MiB), binary 62 MiB
(65 MiB). Step 1 for binary traits with many level 1 predictors needs more than official: with 2,500 level 1
predictors (500 blocks), 632 MiB (442 MiB). For such runs, add 5 x P x P x 8 bytes to the memory request you use for
official regenie, where P is the number of level 1 predictors (blocks times 5): about 0.3 GB for P = 2,500. Other
runs were not measured; see `fast/BENCHMARKS.md` in the repository.

## Run

Use `regenie-fast` exactly like `regenie`:

```
/path/to/regenie-fast/regenie-fast --step 2 --bgen chr22.bgen --sample chr22.sample \
  --phenoFile pheno.txt --covarFile covar.txt --pred fit_pred.list --bsize 400 \
  --threads $SLURM_CPUS_PER_TASK --out chr22
```

- Always pass `--threads` = the cores allocated to the job (regenie's default ignores the scheduler's limit).
- Optional, in the job script: `export OMP_WAIT_POLICY=PASSIVE` (idle threads sleep instead of spinning).

## Check it on your own data

```
./compare_with_official.sh cmp_chr22 --step 2 --bgen chr22.bgen --sample chr22.sample \
  --phenoFile pheno.txt --covarFile covar.txt --pred fit_pred.list --bsize 400 --threads 8
```

Runs official regenie v4.1.3 (`regenie-official`, included) and `regenie-fast` on the same command, prints both times
and the speed-up, and compares every output file (expected: `ALL OUTPUT FILES IDENTICAL`). Compare on the same node,
since results from any regenie build can differ in the last digit between CPU types.

## Speed (official vs fast, 10k samples, mean of 2-3 rounds, laptop i7-11370H)

| Threads | Step | Official | Fast | Speed-up |
|---|---|---|---|---|
| 1 | Step 1, quantitative (2 traits), 50 blocks | 120.3 s | 29.5 s | 4.1x |
| 1 | Step 1, binary, 50 blocks | 117.0 s | 28.8 s | 4.1x |
| 1 | Step 2, quantitative (2 traits), 20k BGEN variants | 6.2 s | 3.0 s | 2.1x |
| 1 | Step 2, binary (approximate Firth), 20k BGEN variants | 5.7 s | 2.9 s | 2.0x |
| 2 | Step 1, binary, 2,500 level-1 predictors | 134.4 s | 84.9 s | 1.6x |
| 4 | Step 1, quantitative | 70.5 s | 18.0 s | 3.9x |
| 4 | Step 2, quantitative | 2.0 s | 1.0 s | 1.9x |

The full table, the data simulation and the scripts that produced it are in the repository (`fast/BENCHMARKS.md`,
`fast/verify/`, `fast/results/`).

## Contents

- `regenie-fast`, `regenie-official`: launchers; the programs are in `bin/`, their system libraries and loader in
  `lib/` (from Ubuntu 22.04).
- `bin/regenie-4.1.3-official`: the official regenie v4.1.3 MKL release program, unchanged
  (`regenie_v4.1.3.gz_x86_64_Linux_mkl` from https://github.com/rgcgithub/regenie/releases/tag/v4.1.3).
- `compare_with_official.sh`, `selftest.sh`, `test/` (regenie's example data).
- `regenie-4.1.3-fast.patch`: the source changes against regenie v4.1.3.
- `LICENSE`, `THIRD_PARTY_NOTICES.md`, `libs.csv`, `sources.csv`, `licenses/`: licences (see below).

Build: regenie v4.1.3 + patch, Ubuntu 22.04, gcc 9, Intel MKL 2024.2.0 (the official release's version), libdeflate
1.26; recipe in `fast/build/` of the repository.

## Licence

regenie-fast is a modified version of regenie and is distributed under regenie's MIT licence (`LICENSE`); its
changes are Copyright (c) 2026 AlfredPgen. The programs in `bin/` include third-party components (statically linked
libraries such as Intel MKL), and `lib/` contains Ubuntu system libraries; their licences and notices are listed in
`THIRD_PARTY_NOTICES.md`, with the full licence texts in `licenses/`; `libs.csv` and `sources.csv` list the Ubuntu
packages and source files of `lib/`. The source of the GPL- and LGPL-licensed parts is also attached to the release
as `regenie-fast-v4.1.3-fast1-gpl-sources.tar` (`THIRD_PARTY_NOTICES.md`, section 4).

This build is not an official regenie release and is not supported by the regenie authors: please report problems
with it at https://github.com/AlfredPgen/regenie-fast/issues, not to the regenie project.
