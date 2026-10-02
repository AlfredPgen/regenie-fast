#!/bin/bash
# Collects the peak-memory measurements of ~/rgprof/mem (one run per build; each .time file holds
# "<max resident set size in KiB> <elapsed s>" as written by /usr/bin/time -f "%M %e"), with the options from each run's log.
cd ~/rgprof/mem || exit 1
for s in step1_qt step1_bt step2_qt step2_bt; do
  for b in official fast; do
    read kb sec < $s.$b.time
    printf "%s %-8s max RSS %7d KiB = %6.1f MiB, elapsed %s s\n" $s $b $kb $(echo "$kb/1024" | bc -l) $sec
  done
  opts=$(sed -n '/Options in effect/,/^$/p' ${s}_official.log | grep -- '--' | grep -v -- '--out' | sed 's/[[:space:]]*[\\]$//' | tr -s ' ' | tr '\n' ' ')
  echo "  options:$opts"
done
for s in step1_qt step1_bt step2_qt step2_bt; do
  for f in ${s}_official_*.loco ${s}_official_*.regenie; do [ -f "$f" ] || continue
    cmp -s $f ${f/_official_/_fast_} && echo "$f vs fast: identical" || echo "$f vs fast: DIFFERS"; done
done
