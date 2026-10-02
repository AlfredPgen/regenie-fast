# Simulates a PLINK genotype set (geno.bed/.bim/.fam) with quantitative, binary and covariate files for testing and
# timing regenie. Samples are named s0, s1, ...; SNPs snp0, snp1, ... with --snps-per-chr SNPs on each chromosome.
#   pheno.txt  Y1 (heritability 0.4), Y2 (0.2), 100 causal SNPs shared by all traits
#   bt.txt     B1, binary (liability heritability 0.3, 15% cases)
#   covar.txt  PC1-PC3 (standard normal) and AGE (40-69)
# usage: python3 sim_plink.py --out DIR [--samples 10000] [--chromosomes 10] [--snps-per-chr 10000] [--seed 1]
# Needs numpy. The defaults reproduce the 10k-sample benchmark dataset of fast/results: geno.bed byte for byte, the
# text files value for value (that dataset was written on Windows, so its text files had CRLF line endings).
import argparse, os
import numpy as np

ap = argparse.ArgumentParser(description="simulate PLINK genotypes, phenotypes and covariates")
ap.add_argument("--out", required=True); ap.add_argument("--samples", type=int, default=10_000)
ap.add_argument("--chromosomes", type=int, default=10); ap.add_argument("--snps-per-chr", type=int, default=10_000)
ap.add_argument("--seed", type=int, default=1)
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True); os.chdir(a.out)
rng = np.random.default_rng(a.seed)
N, NCHR, M_PER = a.samples, a.chromosomes, a.snps_per_chr
M = NCHR * M_PER
if M < 100: raise SystemExit("need at least 100 SNPs (100 are causal)")
maf = rng.uniform(0.02, 0.5, M)
# bed encoding per genotype (allele1 count): 0->0b00 (hom A1), 1->0b10 (het), 2->0b11 (hom A2)
code = np.array([0b00, 0b10, 0b11], dtype=np.uint8)
nbytes = (N + 3) // 4
causal = rng.choice(M, 100, replace=False)
beta = np.zeros(M); beta[causal] = rng.normal(0, 1, 100)
g_score = np.zeros(N)
# SNPs are drawn in chunks of 1000 (memory); the chunk size also fixes the summation order of the genetic score,
# so keep it at 1000 to reproduce the published dataset
with open("geno.bed", "wb") as bed, open("geno.bim", "w", newline="\n") as bim:
    bed.write(bytes([0x6C, 0x1B, 0x01]))
    for start in range(0, M, 1000):
        idx = np.arange(start, min(start + 1000, M))
        G = rng.binomial(2, maf[idx][:, None], size=(len(idx), N)).astype(np.uint8)
        Gs = (G - 2 * maf[idx][:, None]) / np.sqrt(2 * maf[idx] * (1 - maf[idx]))[:, None]
        g_score += beta[idx] @ Gs
        c = code[G]
        pad = np.zeros((len(idx), nbytes * 4), dtype=np.uint8); pad[:, :N] = c
        p = pad.reshape(len(idx), nbytes, 4)
        packed = p[:, :, 0] | (p[:, :, 1] << 2) | (p[:, :, 2] << 4) | (p[:, :, 3] << 6)
        bed.write(packed.astype(np.uint8).tobytes())
        for j in idx:
            chrom = j // M_PER + 1
            bim.write(f"{chrom}\tsnp{j}\t0\t{(j % M_PER) * 500 + 1}\tA\tG\n")
iid = [f"s{i}" for i in range(N)]
with open("geno.fam", "w", newline="\n") as f:
    for i in iid: f.write(f"{i} {i} 0 0 {rng.integers(1,3)} -9\n")
g = g_score / g_score.std()
cov = rng.normal(size=(N, 3)); age = rng.integers(40, 70, N)
y1 = np.sqrt(0.4) * g + 0.1 * cov[:, 0] + np.sqrt(0.6) * rng.normal(size=N)
y2 = np.sqrt(0.2) * g + np.sqrt(0.8) * rng.normal(size=N)
liab = np.sqrt(0.3) * g + np.sqrt(0.7) * rng.normal(size=N)
y3 = (liab > np.quantile(liab, 0.85)).astype(int)
with open("pheno.txt", "w", newline="\n") as f:
    f.write("FID IID Y1 Y2\n")
    for i in range(N): f.write(f"{iid[i]} {iid[i]} {y1[i]:.5f} {y2[i]:.5f}\n")
with open("bt.txt", "w", newline="\n") as f:
    f.write("FID IID B1\n")
    for i in range(N): f.write(f"{iid[i]} {iid[i]} {y3[i]}\n")
with open("covar.txt", "w", newline="\n") as f:
    f.write("FID IID PC1 PC2 PC3 AGE\n")
    for i in range(N): f.write(f"{iid[i]} {iid[i]} {cov[i,0]:.5f} {cov[i,1]:.5f} {cov[i,2]:.5f} {age[i]}\n")
print(f"sim_plink: {N} samples, {M} SNPs on {NCHR} chromosomes -> {os.getcwd()}")
