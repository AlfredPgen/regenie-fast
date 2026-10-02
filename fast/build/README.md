# Building regenie-fast

Two Docker images, the same toolchain as regenie's own `Dockerfile_mkl` (Ubuntu 22.04, gcc 9, BGEN 1.1.7, HTSlib 1.18,
static Intel MKL and Boost Iostreams, `STATIC=1`):

| File | What it does |
|---|---|
| `Dockerfile.deps` | toolchain and libraries, without regenie; Intel MKL pinned to 2024.2.0 (see below) |
| `Dockerfile.build` | compiles this repository on top of it, plus libdeflate 1.26 for the BGEN reader |
| `Dockerfile.build.dockerignore` | keeps `fast/`, `docs/`, `example/`, `test/` and `.git` out of the build context |
| `deps-image-packages.txt` | package versions inside the deps image used for the v4.1.3-fast1 release |

## Commands

From the repository root, on Linux or in Git Bash/WSL with Docker Desktop on Windows:

```
git clone https://github.com/AlfredPgen/regenie-fast && cd regenie-fast
git checkout v4.1.3-fast1
docker build -t regenie-deps:mkl2024.2 -f fast/build/Dockerfile.deps fast/build
docker build -t regenie-fast-build:v4.1.3-fast1 -f fast/build/Dockerfile.build .
c=$(docker create regenie-fast-build:v4.1.3-fast1)
docker cp "$c":/src/regenie/regenie ./regenie-4.1.3-fast && docker rm "$c"
sha256sum regenie-4.1.3-fast
```

The deps image is about 4 GB. The second build compiles with 2 parallel jobs by default (about 7.5 minutes on a
4-core laptop); add `--build-arg JOBS=8` to use more cores if the machine has the memory. The build ends by
printing `v4.1.3.gz`, regenie's own version string, which this build does not change.

To make the release zip from the image (launchers, bundled libraries, official program, licences):

```
fast/package/make_package.sh --build-image regenie-fast-build:v4.1.3-fast1
```

## Why MKL 2024.2.0

regenie does its linear algebra with Intel MKL, which picks its numerical kernels by MKL version and CPU. With
`MKL_VERBOSE=1`, the official regenie v4.1.3 MKL release reports `oneMKL 2024.0 Update 2 Product build 20240605`,
which is how the oneMKL 2024.2.0 packages identify themselves; a build on `Dockerfile.deps` reports the same.
MKL chooses its kernels by version, so with another MKL version even unchanged regenie code can give different last
bits in matrix products and, through them, different printed digits. `Dockerfile.deps` therefore installs exactly the
2024.2.0-663 packages, so that the comparisons in `fast/verify` measure the source changes rather than MKL version
differences. Whether unchanged v4.1.3 source built with this recipe reproduces the official program's output files
byte for byte was not tested separately: all comparisons in `fast/results` are against the official program itself
(see `fast/VERIFICATION.md`, "The build and the MKL pin").

## Reproducibility

Building tag v4.1.3-fast1 with `Dockerfile.build` on the deps image used for the release gives the release program
bit for bit (SHA-256 `61cbf8994d43d547929718e6f33b3d63255ad1bda3314e7eba4f06d74e9fa6c5`; the rebuild is recorded in
`fast/results/rebuild_v4.1.3-fast1.log`). `Dockerfile.deps` checks the SHA-256 of everything it downloads, but apart
from MKL it installs the current Ubuntu 22.04 packages; a deps image built later can therefore contain newer package
updates than those in `deps-image-packages.txt` and give a slightly different program. Such a build should still
pass the identical-results suite in `fast/verify`.

Without BuildKit (the legacy `docker build`), `Dockerfile.build.dockerignore` is ignored and the repository's
`.dockerignore` applies instead; the extra files copied into the image do not change the program.
