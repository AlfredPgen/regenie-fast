# What changed, and why the results are the same

This file describes every change that regenie-fast makes to regenie v4.1.3. The changes are performance changes
only: no option, default, model, input format or output format was changed.

The full change set is the patch `regenie-4.1.3-fast.patch` (3,098 lines; it applies to the v4.1.3 tag) and the
commits of this repository. It touches 12 files:

| File | Changes |
|---|---|
| `CMakeLists.txt`, `Makefile` | build the new file `bgen8_parse.cpp` with strict IEEE arithmetic; `CMakeLists.txt` links libdeflate when found; header dependency tracking in the Makefile |
| `src/Data.cpp`, `src/Data.hpp` | step 1 genotype block preparation, fold matrices, prediction output; step 2 block loop (reading, closed-form tests, output thread) |
| `src/Geno.cpp`, `src/Geno.hpp` | PLINK bed reader (step 1), BGEN reading, decompression and parsing, imputation, per-trait counts |
| `src/Step1_Models.cpp`, `src/Step1_Models.hpp` | level 0 ridge regression; level 1 for quantitative and binary traits; level 0 prediction files |
| `src/Step2_Models.cpp`, `src/Step2_Models.hpp` | closed-form score tests; approximate Firth correction; saddle-point approximation (SPA) |
| `src/bgen8_parse.cpp`, `src/bgen8_parse.hpp` (new) | 8-bit BGEN dosage parser, derived from regenie's `parseSnpfromBGEN`, and per-sample sums of the closed-form tests |

## How to read "why the results are the same"

Each change is in one of three classes:

- **Exact.** The new code performs the same floating-point operations on the same operands in the same order, or
  the change involves no floating-point arithmetic at all (reading files, copying, integer counts, memory layout,
  writing text). The results are bit-identical by construction, given the same compiler and flags.
- **Same library call.** The same Intel MKL (BLAS or LAPACK) routine is applied to the same numbers, but to pieces of
  a matrix (panels of columns) or with different work buffers. Every output element is still computed from the same
  inputs by the same routine, so bit-identical values are expected, but this depends on MKL's internal blocking and
  is therefore backed only by the output comparisons in [VERIFICATION.md](VERIFICATION.md).
- **Rounding differs.** The new computation is algebraically equal to the old one but uses a different algorithm or
  a different order of additions, so internal values can differ. In the first round of changes, measured with
  instrumented builds of the original and changed source, the step 1 LOCO predictions differed by at most 1.1e-14 of
  the largest value; in step 2, the test statistics differed by at most 7.1e-12 (absolute), -log10 p by at most
  1.4e-11 (absolute), the standard errors by at most 1.3e-13 (relative) and the effect estimates (BETA) by at most
  4.2e-8 (relative). Relative differences are largest for values close to zero, such as effect estimates near 0
  (`results/final_run.log`; these measurements cover the first-round changes only). regenie prints results with 6
  significant digits, and in every comparison we made, the printed files were identical. A value that happens to lie
  close enough to a rounding boundary of its 6th digit could still print differently, and the chance of that grows
  with the number of values printed; this is why identity is a tested property, not a guarantee (see
  [VERIFICATION.md](VERIFICATION.md#what-identical-output-does-and-does-not-mean)).

"Before" refers to regenie v4.1.3, "after" to regenie-fast. "The release build" means the program as built by the
recipe in [build/](build/): GCC 9 with regenie's flags (`-O3 -ffast-math`, generic x86-64) and Intel MKL 2024.2.0.
Function names are given so the code can be found in either version.

## Step 1

### 1. PLINK bed reader (Exact)

`readChunkFromBedFileToG` in `src/Geno.cpp`. Used for every step 1 block when the genotypes are a PLINK bed file.

- **Before:** one file read per SNP. One OpenMP task per SNP decoded its bytes through a lookup table that returned
  an Eigen array per byte, wrote each genotype into the block matrix, which is stored SNP by sample (so neighbouring
  SNPs handled by different threads write into the same cache lines), and then made a second pass over the SNP for
  mean imputation (`mean_impute_g`).
- **After:** one read for each run of SNPs that are consecutive in the file. The mean of each SNP is computed from a
  256-entry table that gives, for each byte (4 samples), the number of non-missing genotypes and their sum as
  integers; samples outside the analysis are masked to the missing code before the lookup. The block is then written
  in tiles of 64 samples: their 2-bit codes are transposed and each sample's column is written in one contiguous
  sweep (with streaming stores for large blocks), with missing genotypes replaced by the SNP mean in the same sweep.
  If the sample bookkeeping does not have the usual shape, a fallback decodes 8 consecutive SNPs per task and writes
  them sample by sample.
- **Why the results are the same:** the values written are the integers 0, 1, 2 and the imputed mean. Before and
  after, the mean is the sum of integer genotypes, which is exact in double precision, divided by the same count, so
  it is the same double. Samples outside the analysis are set to 0, as `mean_impute_g` did.
- In addition, for bed input the block matrix is no longer filled with zeros before reading
  (`Data::level_0_calculations` in `src/Data.cpp`), because the reader writes every entry.

### 2. Residualising and scaling the genotype block (Exact, one part Same library call)

`Data::residualize_genotypes` in `src/Data.cpp`. Used for every step 1 block, for every genotype format.

- **Before:** (a) multiply every entry by the 0/1 indicator of the samples in the analysis; (b) subtract the
  covariate projection, `Gmat -= beta * X^T`, through a temporary block-size by N matrix; (c) compute the norm of each
  SNP's row with Eigen's `rowwise().norm()`, which sweeps two rows at a time across all columns; (d) divide each row
  by its norm (scaled by the square root of N minus the number of covariates).
- **After:** (a) skipped for bed input, whose reader has already written 0 for those samples (other formats keep the
  multiplication). (b) With `--threads 1`, the same product is formed and subtracted one panel of columns at a time,
  so no block-size by N temporary is allocated and the panel is still in cache when it is subtracted; with more
  threads the original expression is kept, because a threaded BLAS splits the whole product differently. (c) An SSE2
  kernel reads the matrix once and adds the squares of each row in exactly the order of Eigen 3.4.0's SSE2 packet
  reduction (the first column, then groups of four columns added as `(a^2 + b^2) + (c^2 + d^2)`, then the remaining
  columns one by one), in parallel over strips of rows; it ends with the same square root and multiplication by
  `1/sqrt(N - C)`. (d) The divisions are done column by column in parallel, kept as true divisions.
- **Why the results are the same:** (a) the skipped entries are already +0 and the others are multiplied by 1. (b)
  each panel is a call of the same MKL routine on the same numbers as the corresponding columns of the whole product
  (Same library call). (c) and (d) perform the same IEEE operations in the same order as the code that GCC generates
  for the Eigen expressions in the release build (`-O3 -ffast-math`, generic x86-64). Empty inline-assembly barriers
  stop the compiler from reassociating the sums or turning divisions into multiplications. The kernel in (c) is
  compiled whenever the compiler defines `__GNUC__` (GCC of any version, and also clang and Intel icx), the target
  has SSE2 but no AVX or FMA code generation (for example generic x86-64), and Eigen is 3.4.0; other builds use the
  original Eigen expression. The division loop in (d) is used by any such compiler with SSE2, also with AVX. Their
  order of operations was matched to GCC 9 with regenie's flags (the release build) only; another compiler or other
  flags may compile the original expressions differently (for example with reciprocals under `-ffast-math`), so such
  builds can differ from the original code in the last bits.

### 3. Fold cross-products by symmetric rank update (Rounding differs)

`Data::calc_cv_matrices` in `src/Data.cpp`. Used in step 1 with k-fold cross-validation (the default; not with
`--loocv`).

- **Before:** for each cross-validation fold, the block-size by block-size matrix `G_k G_k^T` was computed with a
  general matrix product, and the full matrices were summed into `GGt`.
- **After:** `G_k G_k^T` is computed with a symmetric rank-k update (BLAS `syrk`), which computes only the lower
  triangle and needs half the floating-point operations. When the level 0 Cholesky path of change 4 is used, only the
  lower triangles are summed; otherwise the upper triangle is filled by copying, as the other code paths read it.
- **Why the results are the same:** the products are mathematically identical; `syrk` and `gemm` may add the terms
  of each entry in a different order, so the entries can differ in the last bits.

### 4. Level 0 ridge regression by Cholesky factorization (Rounding differs)

`ridge_level_0` in `src/Step1_Models.cpp`. Used in step 1 with k-fold cross-validation when there are at most 20
level 0 ridge parameters (the default is 5).

- **Before:** for each fold, a full eigendecomposition of `GGt - G_k` (1,000 by 1,000 with `--bsize 1000`), then
  for each ridge parameter lambda, `beta = U (D + lambda I)^-1 U^T (GtY - GtY_k)`.
- **After:** for each fold and ridge parameter, a Cholesky factorization of `GGt - G_k + lambda I` (`LAPACKE_dpotrf`
  on the lower triangle, written into a reused work matrix) followed by the two triangular solves that Eigen's
  `LLT::solve` uses. One Cholesky factorization costs about `bs^3/3` floating-point operations, a symmetric
  eigendecomposition about `9 bs^3`, so with 5 ridge parameters this part needs about one fifth of the work. With more
  than 20 ridge parameters the original eigendecomposition is used.
- **Why the results are the same:** both compute the ridge solution `(A + lambda I)^-1 b` for the same symmetric
  positive definite matrix; the two algorithms round differently. A Cholesky factorization needs the matrix to be
  positive definite, which it is for a positive ridge parameter; should it fail numerically, regenie-fast stops with
  an error that names the block.

### 5. Level 0 predictions with one pass over the genotypes (Same library call)

`ridge_level_0` in `src/Step1_Models.cpp`. Used with `--threads 1` and the Cholesky path.

- **Before:** the out-of-sample predictions `beta^T G_k` of each fold were computed separately for each ridge
  parameter, so the fold's genotypes were read from memory once per ridge parameter (5 times by default).
- **After:** the solutions for all ridge parameters are computed first, then the predictions are formed one panel of
  the fold's columns at a time (multiples of 192 columns) for all ridge parameters, so the genotypes are read once.
  With more threads, or if the panel outputs would need more than 256 MB, the whole-fold product is kept.
- **Why the results are the same:** each panel is a call of the same MKL routine with the same row count and inner
  dimension as the whole-fold product, only fewer columns.

### 6. Level 0 prediction files (`--lowmem`, `--run-l0`, `--run-l1`) (Exact)

`ridge_level_0` and `read_l0_chunk` in `src/Step1_Models.cpp`.

- **Before:** the level 0 predictions of each block were copied into a zeroed samples by ridge-parameters matrix and
  that matrix was written to the temporary file; at level 1 they were read back one number at a time.
- **After:** the same bytes are written directly from the fold matrices, column by column and fold by fold, which is
  the column-major order of the old matrix; at level 1 each column of each fold is read with one call. A failed
  write or read now raises an error.
- **Why the results are the same:** the files contain the same bytes in the same order, and the same values are read
  back.

### 7. Level 1 ridge regression, quantitative traits (Exact)

`ridge_level_1` in `src/Step1_Models.cpp`.

- **Before:** for each fold, `X_k^T X_k` was computed and the full matrices were summed; the matrix for each held-out
  fold was formed in full and passed to the symmetric eigensolver.
- **After:** only the lower triangles are summed and subtracted (the upper triangle is then mirrored); the per-fold
  solve was moved into a separate function with reusable work matrices.
- **Why the results are the same:** Eigen's `SelfAdjointEigenSolver`, like the LAPACK routine behind it, reads only
  the lower triangle of its input, and the lower triangles are computed by the same additions as before.
- Two optional variants exist in the code but are **not enabled** in any build unless their macros are defined at
  compile time: `L1_QT_SYRK` (fold products by symmetric rank update) and `L1_QT_PAR_FOLDS` (folds solved
  concurrently with sequential MKL). Neither was shown to give bitwise-equal results.

### 8. Level 1 ridge logistic regression, binary traits (Exact, one part Rounding may differ)

`ridge_logistic_level_1` in `src/Step1_Models.cpp`. This is the slowest part of step 1 for binary traits when there
are many level 1 predictors (about 2,500 at 500 blocks of 1,000 SNPs).

- **Before:** in every iteration of the iteratively reweighted least squares fit, for each held-out fold and each
  training fold: compute the linear predictor and fitted probabilities (`get_pvec`), the weights and working
  response, form `XtW = X_k^T diag(w)` by a serial strided copy, add `XtW X_k` to `XtWX` and `XtW z` to `XtWZ`, then
  solve with `XtWX.llt()` (which first copies the matrix). The step-halving check and the score evaluation then
  recomputed the fitted probabilities for the same coefficients.
- **After:**
  - The linear predictor and fitted probabilities of each training fold are cached together with the coefficient
    vector they belong to, and reused when the same coefficients are evaluated again (compared bit for bit).
  - `XtW` is written tile by tile in parallel into one buffer reused for all folds; each entry is still the single
    product `X(r,a) * w(r)`.
  - At the first iteration of the first ridge parameter the coefficients are 0 for every held-out fold, so the
    products of each training fold are the same for all held-out folds; they are computed once and kept (when they
    need no more memory than the `XtW` buffer, or at most 256 MB).
  - Each training fold's product `XtW X_k` (and `XtW z`) is formed in its own matrix and its lower triangle is then
    added to `XtWX`, which is the only part the Cholesky factorization reads.
  - The Cholesky factorization is done in place, with the same routine and the same two triangular solves as
    `llt().solve()`.
- **Why the results are the same:** the first three points and the last reuse values that are bit-identical or
  perform the same operations (Exact). For the fourth point, the original code let the BLAS routine add each fold's
  product directly into the running sum, while the new code adds the finished product. If MKL accumulates partial
  sums into its output matrix, the order of these additions differs, which can change the last bit of `XtWX`; this
  was not measured separately (Rounding may differ). The printed LOCO files were identical in all tests, including
  binary traits with 2,500 level 1 predictors.
- An optional variant (`L1_BT_GEMMT`, lower triangle only with MKL `dgemmt`) exists in the code and is **not enabled**.

### 9. LOCO predictions kept from level 1 (`--lowmem`, `--run-l1`) (Exact)

`keep_l1_predictions` in `src/Step1_Models.cpp`; `Data::make_predictions` and `Data::make_predictions_binary` in
`src/Data.cpp`.

- **Before:** with `--lowmem` or `--run-l1`, after level 1 had chosen the ridge parameter, each trait's level 0
  predictions (the largest data of step 1) were read from disk a second time to form the LOCO predictions.
- **After:** while a trait's level 0 predictions are still in memory at level 1, the LOCO prediction blocks are
  formed for the ridge parameter that the cross-validation criterion selects, using the same products. They are used
  only if the output step selects the same parameter; otherwise the files are read again as before. At most 256 MB
  (and no more than one trait's level 0 predictions) is kept.
- **Why the results are the same:** the same products of the same values; only when they are computed changes.

### 10. Writing the LOCO files (Exact)

`Data::write_predictions`, `Data::write_ID_header` and `Data::write_chr_row` in `src/Data.cpp`.

- **Before:** each chromosome's row was formatted by walking the sample ID map again.
- **After:** the sample order is recorded once while the header is written, and the rows of all chromosomes are
  formatted in parallel and written in order.
- **Why the results are the same:** the same text, formatted by the same stream operations, in the same order.

## Step 2

### 11. Reading BGEN files (Exact)

`Data::test_snps_fast`, `Data::analyze_block` and `Data::compute_tests_mt` in `src/Data.cpp`; `readChunkFromBGEN`
in `src/Geno.cpp`.

- **Before:** for each block of variants (400 with `--bsize 400` in our tests), one thread read all records from the
  file, seeking to each record and reading its header fields one by one, while the other threads waited; then the
  block was parsed in parallel.
- **After:** for BGEN v1.2 (layout 2) files with 8-bit probabilities, zlib- or zstd-compressed (the files that
  regenie's streaming BGEN path handles), the thread that parses a variant reads its record itself with positioned
  reads (`pread`: a 4 KiB window for the header fields and the start of the data, then the rest of the data), and asks
  the operating system to start reading the matching variant of the next block (`posix_fadvise`). Read errors are
  collected and reported after the parallel loop. When building burden masks, or if the file cannot be opened as a
  regular file, the original reader is used. In the original reader, a seek is now skipped when the record starts
  where the previous one ended (a seek discards the stream buffer).
- **Why the results are the same:** the same bytes are read for every variant.

### 12. Decompression with libdeflate (Exact)

`parseSnpfromBGEN` in `src/Geno.cpp`.

- **Before:** zlib-compressed genotype blocks were inflated with zlib's `uncompress` into a newly allocated buffer for
  every variant.
- **After:** they are inflated with libdeflate (`libdeflate_zlib_decompress`, which also checks the Adler-32
  checksum) into a buffer reused by each thread. zstd-compressed files are decompressed as before. Builds without
  libdeflate use zlib.
- **Why the results are the same:** DEFLATE decompression is deterministic; both libraries produce the same bytes.

### 13. Parsing 8-bit dosages (Exact)

`bgen8_parse_fast` and `bgen8_trait_counts` in the new file `src/bgen8_parse.cpp`, called from `parseSnpfromBGEN`.

- **Before:** a general loop over samples handled every case (ploidy, missingness, allele order, sex chromosomes,
  case-control counts) and, for samples with missing values in some trait, called `update_trait_counts` for each
  sample. The genotype column was zeroed first.
- **After:** the common case (not the non-PAR region of chromosome X in step 2, not burden-mask construction, not
  `--af-cc`) is handled by a specialised loop, compiled in eight variants (allele order, whether homozygote counts
  are needed, whether per-trait corrections are needed). It computes each dosage, the running sums (dosage total,
  MAC, INFO numerator) and counts (non-missing, homozygous, missing, exact zeros and twos), writes every entry of the
  column, and records the samples that need per-trait corrections, which are then applied per trait in sample order.
  Other cases use the original loop.
- **Why the results are the same:** `bgen8_parse.cpp` is compiled without `-ffast-math` and with
  `-ffp-contract=off`, so each operation is one IEEE-rounded instruction in the order written. The per-sample
  sequence is the one that the original loop performs in the release build: probability = byte times (1/255)
  (`-ffast-math` turns the original division by 255 into this multiplication); `prob2 = max(1 - (prob0 + prob1), 0)`;
  dosage `2 * p + prob1`, where `p` is `prob0`, or `prob2` with `--ref-first`; INFO term `(4 * p + prob1) - dosage^2`
  (multiplying by 2 or 4 is exact); and the sums are accumulated in sample order. The
  per-trait corrections subtract the same values in the same order; the only operations skipped are subtractions of
  +0 from sums that start at +0 and are never -0, which change nothing. In the first-round tests, the parsed dosage
  vectors and sums were bit-identical for every variant (`results/final_run.log`).

### 14. Imputation, allele flip and sparsity check (Exact)

`parseSnpfromBGEN`, `flip_geno_analyzed`, `check_sparse_G` and `update_trait_counts` in `src/Geno.cpp`;
`Data::compute_tests_mt` in `src/Data.cpp`.

- **Before:** after parsing, every variant went through mean imputation (two full passes over the samples), the
  minor-allele flip for binary traits, and a separate pass that counted non-zero genotypes to decide whether to use
  the sparse code path. `update_trait_counts` subtracted a sample's values from every trait multiplied by a 0/1 mask.
- **After:** samples outside the analysis are written as 0 during parsing, so imputation only replaces the missing
  analysed values, and is skipped when there are none; the flip leaves the samples outside the analysis at 0. The
  number of non-zero genotypes is derived from the parsing counts (for additive tests), so the separate counting pass
  is not needed; the sparsity check is also skipped for variants that already failed the filters, whose results are
  not computed. `update_trait_counts` subtracts only from the traits in which the sample is masked. When values are
  read before imputation (`--htp` genotype counts, LD matrices, interaction tests), the original order is kept.
- **Why the results are the same:** the final column holds the same values (0 outside the analysis, the mean for
  missing analysed samples, flipped genotypes for the others); the non-zero count equals the counted one, so each
  variant takes the same code path; the per-trait sums change by the same subtractions (the skipped ones subtract 0).

### 15. Closed-form score tests (Rounding differs)

`cf_supported`, `cf_prepare` and `cf_variant` in `src/Step2_Models.cpp`; `cf_sumsq_qt` and `cf_sumsq_bt` in
`src/bgen8_parse.cpp`; the score functions `compute_score_qt` and `compute_score_bt` use the results.

regenie works with an orthonormal basis `X` of the covariates. For a variant `g`, the score test needs the residual
`r = g - X X^T g` only through a few inner products.

- **Before:** for each dense variant, regenie formed `r` explicitly (`X^T g`, then `g - X (X^T g)`, reading all
  samples and covariates for every variant), computed its norm and then its inner products with the residualised
  phenotypes.
  For binary traits it did the same with `Gamma^1/2 g` and the weighted covariates of the null model, for each trait.
- **After:** after the whole block is parsed, one matrix product `S = W^T G` gives all inner products for all
  variants of the block, where `W` holds the centring vector `e`, the covariates, the covariates masked by each trait
  whose missingness pattern differs from the analysis mask, and the residualised phenotypes. Then
  `yres^T r = yres^T c - (yres^T X) b` and `sum_i m_i r_i^2 = sum_i m_i c_i^2 - 2 b^T (X_m^T c) + b^T (X_m^T X_m) b`,
  with `c = g - mu e` and `b = X^T c`. The only remaining pass over the samples computes the sums of squares of `c`,
  for all traits at once. Binary traits use the same identities with `Gamma^1/2 g`, `X_Gamma` and the score residuals.
  `W` and its small cross-products are built once per chromosome, because the LOCO residuals change per chromosome.
  For binary traits, the residualised genotype is still formed in the original way for every variant whose
  statistic will be corrected by Firth or SPA.
- **Why the results are the same:** the formulas are exact algebraic identities. The centring by `e` (the analysis
  indicator or the all-ones vector, whichever lies in the span of the covariates, so it does not change `r`) keeps
  the sums well conditioned. The sums are added in a different order than before, so the results can differ
  slightly; in the first-round tests the largest differences were 7.1e-12 for the test statistic and 1.4e-11 for
  -log10 p (absolute), and 4.2e-8 for the effect estimate (relative; relative differences grow as an estimate
  approaches 0), and every printed result was identical.
- **When it applies:** quantitative and binary traits in the standard single-variant test mode, for dense variants.
  It is not used for sparse variants (most genotypes 0), time-to-event or count traits, burden or gene-based tests,
  `--joint`, interaction tests, `--mcc`, `--nocov-approx`, LD computation, `--mt` or `--multiphen`; those run the
  original code.

### 16. Approximate Firth correction (Exact)

`fit_null_firth`, `fit_firth_logistic_snp_fast`, `fit_firth_pseudo` and `fit_firth` (the single-variant versions) in
`src/Step2_Models.cpp`. Used with `--firth --approx`.

- **Before:** for each corrected variant, the fitted probabilities and deviance at a variant effect of 0 (which
  depend only on the covariate offset) were recomputed over all samples; in each iteration of the pseudo-data fit,
  the fitted probabilities were recomputed at the start (although the previous iteration had just computed them for
  the same coefficient) and the deviance was computed at every iteration (it is only used after convergence).
- **After:** the probabilities and deviance at effect 0 are computed once per chromosome and trait, with the same
  calls, where the offset is set (`fit_null_firth`), and reused. The fit skips the repeated probability computation
  from the second iteration on and computes the deviance only at convergence, from the same probabilities and
  information as before.
- **Why the results are the same:** the reused values are bit-identical to the recomputed ones (same functions, same
  inputs); the cached probability vector is copied before use so that the compiler generates the same code for the
  summation as without the cache.

### 17. Saddle-point approximation (Exact)

`solve_K1_snp`, `get_SPA_pvalue_snp` and the new `compute_K12_snp` in `src/Step2_Models.cpp`. Used with `--spa`.

- **Before:** the Newton iterations evaluated `K'(t)` and `K''(t)` at the same point in separate passes over the
  samples; `K'(0)` was computed for each of the two tails; `K''` at the root was computed again for the p-value.
- **After:** `K'(t)` and `K''(t)` are computed together, `K'(0)` and `K''(0)` are computed once for both tails
  (`exp(+0) = exp(-0) = 1`), and `K''` at the root is reused for the p-value.
- **Why the results are the same:** the same values are reused. For the release build (GCC 9, generic x86-64,
  `-ffast-math`), the combined pass is a kernel that repeats the exact operations GCC generates for the original
  functions, compiled without fast-math and contraction so that this order is kept. As a safeguard, its results are
  compared bit for bit with the original functions on the first 64 calls of each kernel; after any difference the
  original functions are used for the rest of the run. Other compilers or flags always use the original functions.

### 18. Writing results on a separate thread (Exact)

`block_writer` in `src/Data.cpp`. Used in step 2 with more than one thread.

- **Before:** after each block was computed, its result lines were written while all threads waited.
- **After:** a separate thread writes them while the next block is computed. Each file receives the same strings in
  the same order (also with `--gz`).

### 19. Smaller items (Exact)

- When the closed-form tests are used, the step 2 genotype matrix keeps its largest allocation across blocks instead
  of being reallocated for each block.
- The per-block progress line is no longer flushed separately; it is flushed with the next block's line.
- Per-variant buffers in the BGEN parser are reused per thread.

## Build changes

- `CMakeLists.txt` and `Makefile` compile `src/bgen8_parse.cpp` with `-fno-fast-math -ffp-contract=off` (all other
  files keep regenie's flags, including `-ffast-math`).
- `CMakeLists.txt` links libdeflate if `libdeflate.a` and `libdeflate.h` are found and defines `WITH_LIBDEFLATE`;
  otherwise zlib is used as before.
- The `Makefile` tracks header dependencies (`-MMD -MP`), so changing a header rebuilds the objects that use it.

## Not changed

- regenie's statistical methods, options, defaults, input handling, output formats and printed precision. The program
  reports the same version string as official v4.1.3.
- The default number of threads (the number of CPUs the system reports, minus one). It ignores job scheduler limits,
  which is why `--threads` should always be set on a cluster, but changing a default would change behaviour, which
  this fork does not do.
- The PGEN reader, the BGEN reader for other BGEN layouts and bit depths, leave-one-out cross-validation at level 0
  and level 1 (`--loocv`, and the automatic use for binary traits with fewer than 5,000 samples), time-to-event and
  count-trait models, burden mask construction, gene-based tests (SKAT, ACAT), interaction-test statistics, the exact
  Firth fit and the output formatting of results. Runs that use these still pass through some of the changed code
  above (for example step 1 changes 1 to 4, or the BGEN reading and parsing);
  [VERIFICATION.md](VERIFICATION.md#not-tested) lists which.

## Considered and left out

- Step 1 without a residualised genotype block (a low-rank covariate correction): no speed gain at 10,000 samples,
  and printed LOCO values started to differ in the 6th digit.
- Caching the trait masks once per block in step 2: changed the last bits of the test statistics.
- Lower-triangle-only level 1 products (`L1_QT_SYRK`, `L1_BT_GEMMT`) and concurrent level 1 folds
  (`L1_QT_PAR_FOLDS`): kept in the code as compile-time options, disabled, because equal results were not shown.
