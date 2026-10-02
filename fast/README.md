# regenie-fast

regenie-fast is [regenie](https://github.com/rgcgithub/regenie) v4.1.3 with changes that make it run faster. It has
the same options, reads the same input files and writes the same output files. In every configuration we tested,
each step 1 `.loco` file and step 2 `.regenie` file was byte-identical to the one written by the official v4.1.3
release program ([VERIFICATION.md](VERIFICATION.md)).

It is not an official regenie release, and the regenie developers do not support it. Please report problems with it
at https://github.com/AlfredPgen/regenie-fast/issues, not to the regenie project. regenie was written by Joelle
Mbatchou, Andrey Ziyatdinov, Jonathan Marchini and colleagues at the Regeneron Genetics Center; if you use this
build, please cite regenie (see [Citing](#citing-and-reporting)).

| Document | Contents |
|---|---|
| [CHANGES.md](CHANGES.md) | Every change: what the original code did, what the new code does, and why the results are the same |
| [VERIFICATION.md](VERIFICATION.md) | How identical results were established, and which options and inputs were not tested |
| [BENCHMARKS.md](BENCHMARKS.md) | Speed and memory measurements, with hardware, data, commands and rounds |
| [build/](build/) | Build recipe (Docker) with the pinned toolchain and Intel MKL version |
| [package/](package/) | Scripts that assemble the Linux package, including `selftest.sh` and `compare_with_official.sh` |
| [verify/](verify/) | Data simulation, identical-results suite and benchmark scripts |
| [results/](results/) | Logs and tables produced by those scripts |

## Where it is faster

In our measurements (whole runs):

- **Step 1 with PLINK bed input**, where the changes speed up reading, residualising and the level 0 ridge
  regressions: about 4x faster at 1, 2 and 4 threads, for quantitative and binary traits.
- **Step 1 for a binary trait with 2,500 level 1 predictors** (500 blocks), where the level 1 logistic regression
  takes a large share of the time: 1.6x faster at 2 threads.
- **Step 2 single-variant tests** on BGEN v1.2 files with 8-bit probabilities (the usual format of imputed data):
  about 2x faster for quantitative traits and for binary traits with approximate Firth correction.

These figures come from simulated data with 10,000 samples on one laptop ([BENCHMARKS.md](BENCHMARKS.md)). Other
inputs and options (for example PGEN files, gene-based tests, interaction tests, larger samples or many-core nodes)
were not timed. Measure on your own data with `compare_with_official.sh` (below).

## Quick start on a Linux cluster

The release package needs only an x86-64 Linux system with bash. It brings its own system libraries and loader, so
the cluster's Linux distribution and installed libraries do not matter and no `module load` is needed.

**1. Download and unpack** into a folder that the compute nodes can read (home or project space):

```bash
wget https://github.com/AlfredPgen/regenie-fast/releases/download/v4.1.3-fast1/regenie-fast-linux-x86_64.zip
unzip regenie-fast-linux-x86_64.zip
cd regenie-fast
./regenie-fast --version
```

**2. Run the self-test**, once on the login node and once on a compute node (compute nodes often have different
CPUs). It runs step 1 and step 2 on regenie's example data with both the official program and regenie-fast, compares
every output file, and takes a few seconds. The last line should be `SELFTEST PASSED`.

```bash
./selftest.sh                                  # login node
srun --cpus-per-task=2 --time=00:10:00 ./selftest.sh selftest_compute   # a compute node (Slurm)
```

**3. Use `regenie-fast` in place of `regenie`**, with the same arguments. Always set `--threads` to the number of
cores the job was given: regenie's default is the number of CPUs the system reports, minus one, which ignores the
scheduler's limit ([CHANGES.md](CHANGES.md#not-changed) explains why this default was left as it is). Typical
variables are `$SLURM_CPUS_PER_TASK` (Slurm), `$NSLOTS` (SGE/UGE) and `$NCPUS` (PBS Pro).

```bash
#!/bin/bash
#SBATCH --job-name=step2_chr22
#SBATCH --cpus-per-task=8
#SBATCH --time=04:00:00
# memory: as for official regenie (regenie-fast used slightly less in our step 2 tests; see Memory below)

RF=/path/to/regenie-fast/regenie-fast
"$RF" --step 2 \
  --bgen chr22.bgen --sample chr22.sample \
  --phenoFile pheno.txt --covarFile covar.txt \
  --pred step1_pred.list --bsize 400 \
  --threads "$SLURM_CPUS_PER_TASK" \
  --out step2_chr22
```

**Memory.** In the four runs we measured of step 2 and of step 1 with 50 blocks, regenie-fast used slightly less
memory than official regenie. Step 1 for binary traits with many level 1 predictors needs more: 632 MiB instead of
442 MiB with 2,500 level 1 predictors (500 blocks). For such runs, add 5 x P x P x 8 bytes to the memory request
you use for official regenie, where P is the number of level 1 predictors (blocks times 5): about 0.3 GB for
P = 2,500 ([BENCHMARKS.md](BENCHMARKS.md#peak-memory)).

**4. Check it on your own data** (recommended before switching a pipeline). `compare_with_official.sh` runs the
official program and regenie-fast on the same command in one job, prints both run times and the speed-up, and
compares every output file. Give it a new output folder and your usual arguments without `--out`:

```bash
./compare_with_official.sh cmp_chr22 --step 2 --bgen chr22.bgen --sample chr22.sample \
  --phenoFile pheno.txt --covarFile covar.txt --pred step1_pred.list --bsize 400 --threads 8
```

The expected last line is `ALL OUTPUT FILES IDENTICAL`. The script runs both programs on the same node, which
matters: Intel MKL selects its code by CPU type, so any regenie build, official or not, can differ in the last
printed digit between machines.

## What is in the package

| Path | Contents |
|---|---|
| `regenie-fast`, `regenie-official` | Launchers. They start the programs with the bundled loader and libraries, ignore `LD_LIBRARY_PATH` and clear `LD_PRELOAD` (monitoring libraries that some clusters preload, such as XALT or Darshan, would otherwise stop the bundled libraries from loading). |
| `bin/regenie-4.1.3-fast` | regenie-fast, built from this repository |
| `bin/regenie-4.1.3-official` | The official regenie v4.1.3 program (`regenie_v4.1.3.gz_x86_64_Linux_mkl` from the [v4.1.3 release](https://github.com/rgcgithub/regenie/releases/tag/v4.1.3)), unchanged, for comparisons |
| `lib/` | Ubuntu 22.04 system libraries and loader used by both programs |
| `selftest.sh`, `compare_with_official.sh`, `test/` | Self-test, comparison script, regenie's example data |
| `regenie-4.1.3-fast.patch` | The source changes as a patch against regenie v4.1.3 |
| `README.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md`, `libs.csv`, `sources.csv`, `licenses/` | Instructions, and the licences of regenie and of the bundled third-party components |

Keep the folder together: the launchers find `bin/` and `lib/` next to themselves (a symbolic link to a launcher, for
example from `~/bin`, works). If starting it fails with `Permission denied`, either the execute permissions were lost
in copying (`chmod +x regenie-fast regenie-official *.sh lib/ld-linux-x86-64.so.2 bin/*`) or the file system does not
allow running programs (some scratch areas); move the folder to home or project space.

The package was tested on Ubuntu 26.04, Rocky Linux 8 and CentOS 7, and under emulated Intel Haswell, AMD EPYC Rome,
AMD EPYC Milan and Intel Westmere CPUs ([VERIFICATION.md](VERIFICATION.md#package-tests-on-other-systems-and-cpus)).
On Westmere, which has no AVX, the official program stops with "Illegal instruction" while regenie-fast runs.

## Citing and reporting

regenie-fast prints the same version string as official regenie (`REGENIE v4.1.3.gz`), so its log files do not show
which build was used. Please say so in your methods, for example: "regenie v4.1.3 (Mbatchou et al. 2021), run with the
regenie-fast build v4.1.3-fast1 (https://github.com/AlfredPgen/regenie-fast), whose outputs matched the official
release in our checks." Cite regenie:

Mbatchou, J., Barnard, L., Backman, J. et al. Computationally efficient whole-genome regression for quantitative and
binary traits. *Nat Genet* 53, 1097–1103 (2021). https://doi.org/10.1038/s41588-021-00870-7

## Building from source

The release program is built in Docker with the toolchain of regenie's own `Dockerfile_mkl` (Ubuntu 22.04, gcc 9,
BGEN 1.1.7, HTSlib 1.18), with Intel MKL pinned to 2024.2.0, the version inside the official v4.1.3 program, plus
libdeflate 1.26. From the repository root:

```bash
docker build -t regenie-deps:mkl2024.2 -f fast/build/Dockerfile.deps fast/build
docker build -t regenie-fast-build:v4.1.3-fast1 -f fast/build/Dockerfile.build .
c=$(docker create regenie-fast-build:v4.1.3-fast1)
docker cp "$c":/src/regenie/regenie ./regenie-4.1.3-fast && docker rm "$c"
```

The MKL pin matters: a different MKL version can change the last bits of the step 1 matrix products, and through
them printed digits of the LOCO predictions ([VERIFICATION.md](VERIFICATION.md#the-build-and-the-mkl-pin)). The
source also builds with regenie's usual `make` or `cmake` instructions on other systems, but the output of such
builds has not been compared with the official program. With other compilers or flags, the change 17 kernel falls
back to the original code, while the change 2 kernels are still used by GCC-compatible compilers on x86-64 but were
matched to the release build only ([CHANGES.md](CHANGES.md), changes 2 and 17). Without libdeflate the build uses
zlib for BGEN decompression (same results, slower).

## Licence

regenie-fast is a modified version of regenie and is distributed under regenie's MIT licence ([LICENSE](../LICENSE)).
The changes in this repository are Copyright (c) 2026 AlfredPgen (https://github.com/AlfredPgen/regenie-fast),
under the same MIT licence. The new files `src/bgen8_parse.cpp` and `src/bgen8_parse.hpp` were written for
regenie-fast; their parser is derived from regenie's `parseSnpfromBGEN`, and their headers carry regenie's notice.
The release programs contain third-party components (for example the statically linked Intel MKL), and the
package's `lib/` folder contains Ubuntu system libraries; their licences are listed in `THIRD_PARTY_NOTICES.md` and
`licenses/` in the package.
