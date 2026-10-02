# Facts about the simulated test data quoted in fast/VERIFICATION.md, computed from the data files in work/data
# (and, for the all-pairs BGEN, from the generator's own formula in sim_allpairs.py).
# usage: python data_facts.py <data folder>
import sys, os
import numpy as np
D = sys.argv[1]
def lines(f): return sum(1 for _ in open(os.path.join(D, f)))
print("geno.fam samples:", lines("geno.fam"))
chrom = {}
for l in open(os.path.join(D, "geno.bim")): c = l.split()[0]; chrom[c] = chrom.get(c, 0) + 1
print("geno.bim SNPs per chromosome:", chrom)
ext = set(l.split()[0] for l in open(os.path.join(D, "s1_extract.txt")))
ec = {}
for l in open(os.path.join(D, "geno.bim")):
    f = l.split()
    if f[1] in ext: ec[f[0]] = ec.get(f[0], 0) + 1
print("s1_extract.txt SNPs per chromosome:", ec)
b = [l.split()[2] for l in list(open(os.path.join(D, "bt.txt")))[1:]]
print("bt.txt: cases", b.count("1"), "controls", b.count("0"))
print("covar.txt columns:", open(os.path.join(D, "covar.txt")).readline().split()[2:])
rows = [l.split() for l in list(open(os.path.join(D, "pheno_miss.txt")))[1:]]
print("pheno_miss.txt: NA in Y1", sum(r[2] == "NA" for r in rows), "NA in Y2", sum(r[3] == "NA" for r in rows),
      "NA in both", sum(r[2] == "NA" and r[3] == "NA" for r in rows))
print("remove.txt samples:", lines("remove.txt"))
pairs = np.array([(a, c) for a in range(256) for c in range(256 - a)])
N, M = 10000, 300; i = np.arange(N); seen = np.zeros(len(pairs), int); miss = 0
for j in range(M):
    np.add.at(seen, (i * 7 + j * 104729) % len(pairs), 1)
    if j % 3 == 0: miss += int(((i + j) % 997 == 0).sum())
print("allpairs.bgen: valid 8-bit pairs", len(pairs), "covered", int((seen > 0).sum()), "occurrences per pair min", int(seen.min()),
      "max", int(seen.max()), "missing genotypes", miss)
print("example data (package test/):", lines("../../dist/regenie-fast/test/example.fam") if os.path.exists(os.path.join(D, "../../dist/regenie-fast/test/example.fam")) else "n/a", "samples")
