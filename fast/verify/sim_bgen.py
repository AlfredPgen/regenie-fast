# Writes an imputed-style BGEN v1.2 file imp.bgen (layout 2, 8-bit probabilities, zlib, sample IDs), its .bgi index
# and imp.sample. Samples s0, s1, ... as in sim_plink.py, so its phenotypes and step 1 predictions can be reused.
# Genotype probabilities: true genotype mixed with the Hardy-Weinberg prior by a per-sample imputation uncertainty.
# usage: python3 sim_bgen.py --out DIR [--samples 10000] [--chromosomes 10] [--variants-per-chr 2000] [--seed 7]
#                            [--workers 2]
# Needs numpy. The defaults reproduce imp.bgen of the 10k-sample benchmark dataset of fast/results byte for byte.
import argparse, os, sqlite3, struct, time, zlib
from concurrent.futures import ProcessPoolExecutor
import numpy as np

def variant_block(args):
    j, chrom, pos, maf, seed, N = args
    rng = np.random.default_rng(seed)
    g = rng.binomial(2, maf, N)
    q = np.array([(1 - maf) ** 2, 2 * maf * (1 - maf), maf ** 2])     # HWE prior
    e = rng.beta(1, 8, N)[:, None]                                       # per-sample imputation uncertainty
    p = (1 - e) * np.eye(3)[g] + e * q                                   # columns: P(AA), P(AB), P(BB)
    v0 = np.rint(p[:, 0] * 255).astype(np.int32)
    v1 = np.minimum(np.rint(p[:, 1] * 255).astype(np.int32), 255 - v0)
    probs = np.empty(2 * N, np.uint8); probs[0::2] = v0; probs[1::2] = v1
    raw = struct.pack("<IHBB", N, 2, 2, 2) + bytes([2]) * N + struct.pack("<BB", 0, 8) + probs.tobytes()
    comp = zlib.compress(raw, 6)
    vid = rsid = f"v{j}".encode(); ch = str(chrom).encode()
    head = (struct.pack("<H", len(vid)) + vid + struct.pack("<H", len(rsid)) + rsid + struct.pack("<H", len(ch)) + ch
            + struct.pack("<IH", pos, 2) + struct.pack("<I", 1) + b"A" + struct.pack("<I", 1) + b"G")
    return head + struct.pack("<II", len(comp) + 4, len(raw)) + comp

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="simulate an imputed BGEN v1.2 file")
    ap.add_argument("--out", required=True); ap.add_argument("--samples", type=int, default=10_000)
    ap.add_argument("--chromosomes", type=int, default=10); ap.add_argument("--variants-per-chr", type=int, default=2_000)
    ap.add_argument("--seed", type=int, default=7); ap.add_argument("--workers", type=int, default=2)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True); os.chdir(a.out)
    OUT = "imp.bgen"; N, NCHR, M_PER = a.samples, a.chromosomes, a.variants_per_chr
    t0 = time.time(); M = NCHR * M_PER
    rng = np.random.default_rng(a.seed); mafs = rng.uniform(0.01, 0.5, M)
    ids = [f"s{i}".encode() for i in range(N)]
    flags = 1 | (2 << 2) | (1 << 31)                                     # zlib, layout 2, sample IDs present
    header = struct.pack("<III", 20, M, N) + b"bgen" + struct.pack("<I", flags)
    sblock_body = b"".join(struct.pack("<H", len(s)) + s for s in ids)
    sblock = struct.pack("<II", 8 + len(sblock_body), N) + sblock_body
    jobs = [(j, j // M_PER + 1, (j % M_PER) * 500 + 1, mafs[j], 1000 + j, N) for j in range(M)]
    rows = []
    with open(OUT, "wb") as f, ProcessPoolExecutor(a.workers) as ex:
        f.write(struct.pack("<I", len(header) + len(sblock))); f.write(header); f.write(sblock)
        for (j, chrom, pos, _, _, _), blk in zip(jobs, ex.map(variant_block, jobs, chunksize=50)):
            rows.append((str(chrom), pos, f"v{j}", 2, "A", "G", f.tell(), len(blk))); f.write(blk)
    if os.path.exists(OUT + ".bgi"): os.remove(OUT + ".bgi")
    db = sqlite3.connect(OUT + ".bgi")
    db.execute("CREATE TABLE Variant (chromosome TEXT NOT NULL, position INT NOT NULL, rsid TEXT NOT NULL, number_of_alleles INT NOT NULL, allele1 TEXT NOT NULL, allele2 TEXT NULL, file_start_position INT NOT NULL, size_in_bytes INT NOT NULL, PRIMARY KEY (chromosome, position, rsid, allele1, allele2, file_start_position)) WITHOUT ROWID")
    db.executemany("INSERT INTO Variant VALUES (?,?,?,?,?,?,?,?)", rows); db.commit(); db.close()
    with open("imp.sample", "w", newline="\n") as f:                    # sample file (regenie's --sample)
        f.write("ID_1 ID_2 missing sex\n0 0 0 D\n")
        for i in range(N): f.write(f"s{i} s{i} 0 1\n")
    print(f"sim_bgen: {M} variants x {N} samples, {os.path.getsize(OUT) / 1e6:.0f} MB, {time.time() - t0:.0f} s -> {os.getcwd()}")
