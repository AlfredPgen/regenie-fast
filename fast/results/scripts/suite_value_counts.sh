#!/bin/bash
# Counts the lines and whitespace-separated fields of the official outputs that the identical-results suite
# (work/suite.sh) compares byte for byte with regenie-fast (19 cases; thread-consistency files t1_/t4_ excluded).
cd ~/rgprof/ref || exit 1
tl=0; tf=0
for c in s1_qt s1_qt1 s1_bt s1_missing g1_qt g1_bt s2_bgen_qt2 s2_bgen_qt1 s2_bgen_missing s2_bgen_bt_firth01 s2_bgen_bt_firth05 s2_bgen_bt_spa s2_bgen_bt_plain s2_allpairs_qt2 s2_allpairs_ref s2_bed_qt2 s2_bed_bt e2e_qt e2e_bt; do
  for f in ${c}_*.loco ${c}_*.regenie; do [ -f "$f" ] || continue
    read l w <<< $(wc -lw < $f); tl=$((tl+l)); tf=$((tf+w)); echo "$f: $l lines, $w fields"; done
done
echo "TOTAL: $tl lines, $tf fields"
