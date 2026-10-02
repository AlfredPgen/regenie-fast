# Writes allpairs.bgen (+ .bgi), a BGEN v1.2 file for checking the 8-bit genotype decoder: every valid pair of
# 8-bit probabilities (b0 + b1 <= 255, 32,896 pairs) is cycled through the samples, starting at a different pair for
# each variant, and every third variant also has missing genotypes (about 1 sample in 997). Each variant holds as many
# different pairs as there are samples; over the 300 variants every pair occurs about 91 times with 10,000 samples
# (15-19 times with 2,000). Samples s0, s1, ... as in sim_plink.py (use imp.sample from sim_bgen.py).
# usage: python3 sim_allpairs.py --out DIR [--samples 10000] [--variants 300]
# Needs numpy. The defaults reproduce allpairs.bgen of the 10k-sample benchmark dataset of fast/results byte for byte.
import argparse, os, sqlite3, struct, zlib
import numpy as np

ap = argparse.ArgumentParser(description="simulate a BGEN file containing every 8-bit probability pair")
ap.add_argument("--out", required=True); ap.add_argument("--samples", type=int, default=10_000)
ap.add_argument("--variants", type=int, default=300)
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True); os.chdir(a.out)
N, M = a.samples, a.variants
OUT = "allpairs.bgen"
pairs = np.array([(x, y) for x in range(256) for y in range(256 - x)], dtype=np.uint8)
ids = [f"s{i}".encode() for i in range(N)]
header = struct.pack("<III", 20, M, N) + b"bgen" + struct.pack("<I", 1 | (2 << 2) | (1 << 31))
sbody = b"".join(struct.pack("<H", len(s)) + s for s in ids)
sblock = struct.pack("<II", 8 + len(sbody), N) + sbody
rows = []; i = np.arange(N)
with open(OUT, "wb") as f:
    f.write(struct.pack("<I", len(header) + len(sblock))); f.write(header); f.write(sblock)
    for j in range(M):
        p = pairs[(i * 7 + j * 104729) % len(pairs)]
        ploidy = np.full(N, 2, np.uint8)
        if j % 3 == 0:
            miss = (i + j) % 997 == 0; ploidy[miss] = 0x82; p = p.copy(); p[miss] = 0
        raw = struct.pack("<IHBB", N, 2, 2, 2) + ploidy.tobytes() + struct.pack("<BB", 0, 8) + p.tobytes()
        comp = zlib.compress(raw, 6); vid = f"p{j}".encode()
        blk = (struct.pack("<H", len(vid)) + vid + struct.pack("<H", len(vid)) + vid + struct.pack("<H", 1) + b"1"
               + struct.pack("<IH", j * 100 + 1, 2) + struct.pack("<I", 1) + b"A" + struct.pack("<I", 1) + b"G"
               + struct.pack("<II", len(comp) + 4, len(raw)) + comp)
        rows.append(("1", j * 100 + 1, f"p{j}", 2, "A", "G", f.tell(), len(blk))); f.write(blk)
if os.path.exists(OUT + ".bgi"): os.remove(OUT + ".bgi")
db = sqlite3.connect(OUT + ".bgi")
db.execute("CREATE TABLE Variant (chromosome TEXT NOT NULL, position INT NOT NULL, rsid TEXT NOT NULL, number_of_alleles INT NOT NULL, allele1 TEXT NOT NULL, allele2 TEXT NULL, file_start_position INT NOT NULL, size_in_bytes INT NOT NULL, PRIMARY KEY (chromosome, position, rsid, allele1, allele2, file_start_position)) WITHOUT ROWID")
db.executemany("INSERT INTO Variant VALUES (?,?,?,?,?,?,?,?)", rows); db.commit(); db.close()
print(f"sim_allpairs: {M} variants x {N} samples, all {len(pairs)} probability pairs, "
      f"{os.path.getsize(OUT) / 1e6:.1f} MB -> {os.getcwd()}")
