# Markdown table from the bench.csv written by bench.sh: per thread count and step, the mean wall time (and CPU
# seconds) of official and candidate over the rounds both completed, and the mean paired speed-up [min-max].
# usage: python3 bench_table.py <bench.csv>
import csv, statistics as st, sys
from collections import defaultdict

if len(sys.argv) != 2: raise SystemExit("usage: python3 bench_table.py <bench.csv>")
w = defaultdict(lambda: defaultdict(dict)); c = defaultdict(lambda: defaultdict(dict))
for r in csv.DictReader(open(sys.argv[1])):
    w[(r["threads"], r["step"])][r["build"]][r["round"]] = float(r["wall"])
    c[(r["threads"], r["step"])][r["build"]][r["round"]] = float(r["cpu"])
names = {"step1_qt": "Step 1, QT (2 traits), --bsize 1000", "step1_bt": "Step 1, BT, --bsize 1000",
         "level1_bt2500": "Step 1, BT, --bsize 200 (many level-1 predictors)",
         "step2_qt": "Step 2, QT (2 traits), BGEN", "step2_bt": "Step 2, BT Firth, BGEN"}
order = list(names)
print("| Threads | Step | Official wall (CPU) | Candidate wall (CPU) | Speed-up [min-max] | Rounds |")
print("|---|---|---|---|---|---|")
for (t, s) in sorted(w, key=lambda k: (int(k[0]), order.index(k[1]) if k[1] in order else len(order), k[1])):
    o, p = w[(t, s)]["official"], w[(t, s)]["candidate"]
    rs = sorted(set(o) & set(p))
    if not rs: continue
    oc, pc = c[(t, s)]["official"], c[(t, s)]["candidate"]
    ratio = [o[k] / p[k] for k in rs]
    print(f"| {t} | {names.get(s, s)} | {st.mean(o[k] for k in rs):.1f} s ({st.mean(oc[k] for k in rs):.0f}) | "
          f"{st.mean(p[k] for k in rs):.1f} s ({st.mean(pc[k] for k in rs):.0f}) | "
          f"{st.mean(ratio):.2f}x [{min(ratio):.2f}-{max(ratio):.2f}] | {len(rs)} |")
