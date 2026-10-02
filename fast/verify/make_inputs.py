# Derived input files for suite.sh and bench.sh, written next to the output of sim_plink.py:
#   pheno1.txt      Y1 only (regenie then runs a single trait)
#   pheno_miss.txt  pheno.txt with missing values: Y1 for samples i % 97 == 95 or i % 211 == 209, Y2 for i % 211 == 209
#   remove.txt      samples to leave out with --remove: i % 500 == 498
#   s1_extract.txt  the SNPs on chromosomes 1 and 2 (step 1 runs of the suite)
#   s1_50k.txt      the SNPs on chromosomes 1 to 5 (step 1 runs of the benchmark)
#   geno_miss.*     copy of geno.bed/.bim/.fam with about 1% of genotype calls set to missing (seed 3)
# usage: python3 make_inputs.py --dir DIR
# Needs numpy. On the default sim_plink.py output this reproduces the derived files of the benchmark dataset of
# fast/results byte for byte (geno_miss.bim/.fam apart from the CRLF line endings noted in sim_plink.py).
import argparse, os, shutil
import numpy as np

ap = argparse.ArgumentParser(description="derived inputs for the identical-results suite and the benchmark")
ap.add_argument("--dir", required=True)
os.chdir(ap.parse_args().dir)

def write(name, lines):
    with open(name, "w", newline="\n") as f: f.writelines(lines)

pheno = open("pheno.txt").read().splitlines()
write("pheno1.txt", [" ".join(l.split()[:3]) + "\n" for l in pheno])
out = [pheno[0] + "\n"]
for i, line in enumerate(pheno[1:]):
    f = line.split()
    if i % 97 == 95 or i % 211 == 209: f[2] = "NA"
    if i % 211 == 209: f[3] = "NA"
    out.append(" ".join(f) + "\n")
write("pheno_miss.txt", out)
fam = [l.split()[:2] for l in open("geno.fam")]
write("remove.txt", [f"{a} {b}\n" for i, (a, b) in enumerate(fam) if i % 500 == 498])
bim = [l.split() for l in open("geno.bim")]
write("s1_extract.txt", [b[1] + "\n" for b in bim if int(b[0]) <= 2])
write("s1_50k.txt", [b[1] + "\n" for b in bim if int(b[0]) <= 5])

# geno_miss: PLINK code 01 (missing) for ~1% of calls; random numbers drawn per block of SNPs, which gives the same
# stream as drawing them all at once
rng = np.random.default_rng(3)
N, M = len(fam), len(bim); nb = (N + 3) // 4
raw = np.fromfile("geno.bed", dtype=np.uint8)
if len(raw) != 3 + M * nb: raise SystemExit("geno.bed size does not match geno.bim/geno.fam")
nmiss = 0
with open("geno_miss.bed", "wb") as f:
    f.write(raw[:3].tobytes())
    for s in range(0, M, 1000):
        e = min(s + 1000, M)
        body = raw[3 + s * nb: 3 + e * nb].reshape(e - s, nb).copy()
        miss = rng.random((e - s, nb * 4)) < 0.01
        miss[:, N:] = False
        for k in range(4):
            sel = miss[:, k::4]                       # sample 4*b + k sits in bits 2k..2k+1 of byte b
            body[sel] = (body[sel] & ~np.uint8(3 << (2 * k))) | np.uint8(1 << (2 * k))
        nmiss += int(miss.sum()); f.write(body.tobytes())
shutil.copy("geno.bim", "geno_miss.bim"); shutil.copy("geno.fam", "geno_miss.fam")
print(f"make_inputs: {N} samples, {M} SNPs, {nmiss} missing calls in geno_miss.bed -> {os.getcwd()}")
