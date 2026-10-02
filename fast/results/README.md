# Results

The logs and tables behind the numbers in [BENCHMARKS.md](../BENCHMARKS.md) and
[VERIFICATION.md](../VERIFICATION.md). Everything was run on one laptop (Intel Core i7-11370H, WSL 2 with Ubuntu
26.04; [system_info.log](system_info.log)). "official" is the official regenie v4.1.3 MKL release program (SHA-256
`d8dc4118a895cd179e1fdef53d4caee8536a45aeb5aab69ac8c78e2e8e3c0055`); "candidate", "fast" and "merged" are
regenie-fast (SHA-256 `61cbf8994d43d547929718e6f33b3d63255ad1bda3314e7eba4f06d74e9fa6c5`).

| File | Contents | Produced by |
|---|---|---|
| [v2_identical_results_suite.log](v2_identical_results_suite.log) | The 19-case identical-results suite on regenie-fast, and the 1 vs 4 thread checks | `verify/suite.sh` (1) |
| [suite_s2i.log](suite_s2i.log), [suite_s2c.log](suite_s2c.log), [suite_s2f.log](suite_s2f.log), [suite_l0.log](suite_l0.log), [suite_l1.log](suite_l1.log) | The same suite on each of the five change sets alone (step 2 input, step 2 closed-form tests, step 2 Firth and SPA, step 1 level 0, step 1 level 1), each on top of the first round of changes | `verify/suite.sh` (1) |
| [suite_official_selfcheck.log](suite_official_selfcheck.log) | The suite with the official program in place of regenie-fast | `verify/suite.sh` (1) |
| [suite_value_counts.log](suite_value_counts.log) | Lines and fields of the 28 files the suite compares | [scripts/suite_value_counts.sh](scripts/suite_value_counts.sh) |
| [v2_side_by_side.csv](v2_side_by_side.csv) | Wall and CPU time of every benchmark run | `verify/bench.sh` (1) |
| [v2_side_by_side_table.md](v2_side_by_side_table.md) | The benchmark table made from that CSV | `verify/bench_table.py` |
| [bench_outputs_compare.log](bench_outputs_compare.log) | Byte comparison of every output file of the benchmark runs | [scripts/bench_outputs_compare.sh](scripts/bench_outputs_compare.sh) |
| [level1_share.log](level1_share.log) | Time spent in level 1 in the case with 2,500 level 1 predictors | [scripts/level1_share.sh](scripts/level1_share.sh) |
| [memory_v2.log](memory_v2.log) | Peak memory of runs under `/usr/bin/time`, and comparison of their output files | [scripts/memory_v2_extract.sh](scripts/memory_v2_extract.sh) |
| [memory_level1_bt.log](memory_level1_bt.log) | Peak memory of step 1 with a binary trait and 2,500 level 1 predictors (suite case `g1_bt`), and comparison of the `.loco` files | [scripts/memory_level1_bt.sh](scripts/memory_level1_bt.sh) |
| [extra_options_v2.log](extra_options_v2.log) | `--lowmem`, `--split-l0` / `--run-l0` / `--run-l1` and `--gz` | [scripts/extra_options_v2.sh](scripts/extra_options_v2.sh) |
| [mkl_version.log](mkl_version.log) | The MKL build each program reports at run time | [scripts/mkl_version.sh](scripts/mkl_version.sh) |
| [rebuild_v4.1.3-fast1.log](rebuild_v4.1.3-fast1.log) | Rebuild of the release program from a fresh clone with [build/Dockerfile.build](../build/Dockerfile.build) on the release deps image, and its SHA-256 compared with that of the tested program | `docker build`, commands in the log |
| [system_info.log](system_info.log) | Operating system, kernel, CPU, memory and file system of the test machine | [scripts/system_info.sh](scripts/system_info.sh) |
| [data_facts.log](data_facts.log) | Facts about the simulated test data quoted in VERIFICATION.md | [scripts/data_facts.py](scripts/data_facts.py) |
| [final_run.log](final_run.log) | First round of changes only: internal values of instrumented builds of the original and the changed source, and the printed files compared with the official program (10,000 samples, 5,000 SNPs, 5,000 BGEN variants) | Instrumented builds and a script that are not part of this repository |

(1) An earlier version of the script in [verify/](../verify/), with the paths of the test machine built in. The
published scripts take paths as arguments and run the same cases with the same regenie options.

The scripts in [scripts/](scripts/) are kept as they were run on the test machine, where the data, reference outputs
and programs were in `~/rgprof` (`regenie_official` is the official program, `regenie_merged` is regenie-fast). They
are a record of how these logs were made, not general tools. One user-specific path in `mkl_version.sh` was replaced
by an argument, and in the logs the home folder of the test machine is written as `~/`.

Some names in these files come from the test machine's working folders, which are not part of this repository. "v2"
and "merged" mean the released regenie-fast (SHA-256 `61cbf899...` above), the second round of changes;
`work/suite.sh` and `work/bench2.sh` are the earlier, path-specific versions of `verify/suite.sh` and
`verify/bench.sh`; `work/data` is the folder of the simulated test data; and `dist/regenie-fast/test` is the `test/`
folder of the release package (regenie's example data).
