#!/bin/bash
# Extra identity checks for options the 19-case suite does not cover: --lowmem, the --split-l0/--run-l0/--run-l1
# workflow, and gzip output (--gz). Official regenie v4.1.3 release binary vs regenie-fast v2 (same binary as the
# release zip), same data as the suite (10,000 samples; step 1 on 20,000 PLINK bed SNPs; step 2 on 20,000 BGEN variants).
# usage: bash extra_options_v2.sh   (WSL; writes ~/rgprof/extra_v2 and prints one line per compared file)
OFF=~/rgprof/bin/regenie_official; FAST=~/rgprof/bin/regenie_merged; D=~/rgprof/data; O=~/rgprof/extra_v2
sha256sum $OFF $FAST
rm -rf $O; mkdir -p $O/official $O/fast; cd $D || exit 1
S1="--step 1 --bed geno --extract s1_extract.txt --covarFile covar.txt --bsize 1000 --threads 2"
for b in official fast; do
  R=$OFF; [ $b = fast ] && R=$FAST; P=$O/$b
  $R $S1 --phenoFile pheno.txt --lowmem --lowmem-prefix $P/tmp_qt --out $P/lowmem_qt > /dev/null 2>&1 || echo "FAILED $b lowmem_qt"
  $R $S1 --phenoFile bt.txt --bt --lowmem --lowmem-prefix $P/tmp_bt --out $P/lowmem_bt > /dev/null 2>&1 || echo "FAILED $b lowmem_bt"
  $R $S1 --phenoFile pheno.txt --split-l0 $P/split_qt,2 --out $P/split_qt > /dev/null 2>&1 || echo "FAILED $b split-l0"
  # --extract only for --split-l0 and --run-l1: each --run-l0 job reads its own variant list from the master file
  for k in 1 2; do $R ${S1/--extract s1_extract.txt /} --phenoFile pheno.txt --run-l0 $P/split_qt.master,$k --out $P/split_qt_job$k > /dev/null 2>&1 || echo "FAILED $b run-l0 $k"; done
  $R $S1 --phenoFile pheno.txt --run-l1 $P/split_qt.master --out $P/split_qt_l1 > /dev/null 2>&1 || echo "FAILED $b run-l1"
  $R --step 2 --bgen imp.bgen --sample imp.sample --covarFile covar.txt --bsize 400 --threads 2 --phenoFile pheno.txt \
     --pred ~/rgprof/ref/s1_qt_pred.list --gz --out $P/gz_qt > /dev/null 2>&1 || echo "FAILED $b gz_qt"
  $R --step 2 --bgen imp.bgen --sample imp.sample --covarFile covar.txt --bsize 400 --threads 2 --phenoFile bt.txt --bt \
     --firth --approx --pThresh 0.01 --pred ~/rgprof/ref/s1_bt_pred.list --gz --out $P/gz_bt > /dev/null 2>&1 || echo "FAILED $b gz_bt"
done
n=0; bad=0
for f in $O/official/*.loco $O/official/*.loco.gz $O/official/*.regenie $O/official/*.regenie.gz; do
  [ -f "$f" ] || continue; g=$O/fast/$(basename $f); n=$((n+1))
  if [ -f "$g" ] && cmp -s "$f" "$g"; then echo "$(basename $f): identical"; else echo "$(basename $f): DIFFERS"; bad=$((bad+1)); fi
done
echo "EXTRA OPTIONS: $n files compared, $bad differ"
