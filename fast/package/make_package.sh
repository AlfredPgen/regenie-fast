#!/bin/bash
# Assembles the Linux release package regenie-fast-linux-x86_64.zip:
#   bin/  regenie-4.1.3-fast (built from this repository) and regenie-4.1.3-official (the official v4.1.3 MKL
#         release, downloaded from github.com/rgcgithub/regenie and checked against a pinned SHA-256)
#   lib/  every system library the two programs load, plus the loader ld-linux-x86-64.so.2, copied with ldd
#         from the build image (Ubuntu 22.04), so the package runs on any x86-64 Linux
#   launchers, selftest.sh, compare_with_official.sh, README.md, regenie's example data (test/), the source
#   patch against v4.1.3, LICENSE, and the third-party notices (THIRD_PARTY_NOTICES.md, libs.csv, sources.csv,
#   licenses/)
# The zip records Unix permissions, so `unzip` on Linux gives runnable files without chmod.
# Needs bash, docker and curl. Runs on Linux, or in Git Bash on Windows with Docker Desktop.
#
# usage: fast/package/make_package.sh [options]
#   --build-image TAG   take regenie-fast from this image, built with fast/build/Dockerfile.build
#                       (default: regenie-fast-build:v4.1.3-fast1)
#   --fast-binary PATH  use this regenie-fast program instead of taking it from an image
#   --lib-image TAG     image whose system libraries are bundled (default: the build image; with --fast-binary,
#                       regenie-deps:mkl2024.2 from fast/build/Dockerfile.deps)
#   --official-zip PATH local copy of regenie_v4.1.3.gz_x86_64_Linux_mkl.zip (default: download it once into
#                       <out>/cache)
#   --patch PATH        source patch to include (default: git diff of this repository against upstream
#                       v4.1.3.1, leaving out fast/, README.md and .github/)
#   --base REV          upstream revision for that diff (default: v4.1.3.1 = 70e196b8d76e)
#   --out DIR           output folder (default: fast/package/out); writes DIR/regenie-fast/ (the unpacked
#                       package), DIR/regenie-fast-linux-x86_64.zip and DIR/regenie-fast-linux-x86_64.zip.sha256
# example (release):
#   docker build -t regenie-deps:mkl2024.2 -f fast/build/Dockerfile.deps fast/build
#   docker build -t regenie-fast-build:v4.1.3-fast1 -f fast/build/Dockerfile.build .
#   fast/package/make_package.sh --build-image regenie-fast-build:v4.1.3-fast1
set -euo pipefail

OFFICIAL_URL=https://github.com/rgcgithub/regenie/releases/download/v4.1.3/regenie_v4.1.3.gz_x86_64_Linux_mkl.zip
OFFICIAL_NAME=regenie_v4.1.3.gz_x86_64_Linux_mkl
# SHA-256 of the official program inside that zip (the zip itself had d1372a3ca7281cbf527f449b6f8544aaf652137a2c70031a8e4271766cef62e3)
OFFICIAL_SHA256=d8dc4118a895cd179e1fdef53d4caee8536a45aeb5aab69ac8c78e2e8e3c0055
EXAMPLE_FILES="covariates.txt example.bed example.bgen example.bgen.bgi example.bim example.fam phenotype.txt phenotype_bin.txt"
ZIP_NAME=regenie-fast-linux-x86_64.zip

DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"
BUILD_IMAGE=regenie-fast-build:v4.1.3-fast1; FAST_BIN=""; LIB_IMAGE=""; OFFICIAL_ZIP=""; PATCH=""
BASE=70e196b8d76e4713fcb22a9fb51edb633d404fcf; OUT="$DIR/out"
usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit "${1:-1}"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --build-image) BUILD_IMAGE=$2; shift 2;;
    --fast-binary) FAST_BIN=$2; shift 2;;
    --lib-image) LIB_IMAGE=$2; shift 2;;
    --official-zip) OFFICIAL_ZIP=$2; shift 2;;
    --patch) PATCH=$2; shift 2;;
    --base) BASE=$2; shift 2;;
    --out) OUT=$2; shift 2;;
    -h|--help) usage 0;;
    *) echo "unknown option: $1" >&2; usage;;
  esac
done
die() { echo "make_package: $*" >&2; exit 1; }
# Docker on Windows (Git Bash) needs Windows-style host paths and no MSYS path rewriting
hostpath() { if command -v cygpath > /dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi; }
dk() { MSYS_NO_PATHCONV=1 docker "$@"; }
command -v docker > /dev/null || die "docker not found"
[ -z "$LIB_IMAGE" ] && { if [ -n "$FAST_BIN" ]; then LIB_IMAGE=regenie-deps:mkl2024.2; else LIB_IMAGE=$BUILD_IMAGE; fi; }
dk image inspect "$LIB_IMAGE" > /dev/null 2>&1 || die "image $LIB_IMAGE not found (see fast/build/README.md)"

mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"; STAGE="$OUT/regenie-fast"
case "$STAGE" in /*/regenie-fast) ;; *) die "unexpected output path $STAGE";; esac
rm -rf "$STAGE" "$OUT/.work" "$OUT/$ZIP_NAME" "$OUT/$ZIP_NAME.sha256"
mkdir -p "$STAGE/bin" "$STAGE/lib" "$STAGE/test" "$OUT/.work" "$OUT/cache"

echo "== regenie-fast program"
if [ -n "$FAST_BIN" ]; then
  [ -f "$FAST_BIN" ] || die "no such file: $FAST_BIN"
  cp "$FAST_BIN" "$STAGE/bin/regenie-4.1.3-fast"
else
  dk image inspect "$BUILD_IMAGE" > /dev/null 2>&1 || die "image $BUILD_IMAGE not found (see fast/build/README.md)"
  c=$(dk create "$BUILD_IMAGE")
  dk cp "$c:/src/regenie/regenie" "$(hostpath "$STAGE/bin/regenie-4.1.3-fast")" > /dev/null; dk rm "$c" > /dev/null
fi

echo "== official regenie v4.1.3 release"
if [ -n "$OFFICIAL_ZIP" ]; then
  [ -f "$OFFICIAL_ZIP" ] || die "no such file: $OFFICIAL_ZIP"
  cp "$OFFICIAL_ZIP" "$OUT/.work/official.zip"
else
  if [ ! -f "$OUT/cache/$OFFICIAL_NAME.zip" ]; then
    command -v curl > /dev/null || die "curl not found (or pass --official-zip)"
    curl -fsSL -o "$OUT/cache/$OFFICIAL_NAME.zip.part" "$OFFICIAL_URL" && mv "$OUT/cache/$OFFICIAL_NAME.zip.part" "$OUT/cache/$OFFICIAL_NAME.zip"
  fi
  cp "$OUT/cache/$OFFICIAL_NAME.zip" "$OUT/.work/official.zip"
fi

echo "== launchers, scripts, documents, example data"
for f in regenie-fast regenie-official selftest.sh compare_with_official.sh README.md THIRD_PARTY_NOTICES.md libs.csv sources.csv; do
  [ -f "$DIR/$f" ] || die "missing $DIR/$f"; cp "$DIR/$f" "$STAGE/"
done
[ -d "$DIR/licenses" ] || die "missing $DIR/licenses/"
cp -R "$DIR/licenses" "$STAGE/"
[ -f "$REPO/LICENSE" ] || die "missing $REPO/LICENSE"; cp "$REPO/LICENSE" "$STAGE/"
for f in $EXAMPLE_FILES; do [ -f "$REPO/example/$f" ] || die "missing $REPO/example/$f"; cp "$REPO/example/$f" "$STAGE/test/"; done
if [ -n "$PATCH" ]; then
  [ -f "$PATCH" ] || die "no such file: $PATCH"; cp "$PATCH" "$STAGE/regenie-4.1.3-fast.patch"
else
  command -v git > /dev/null || die "git not found (or pass --patch)"
  git -C "$REPO" rev-parse -q --verify "$BASE^{commit}" > /dev/null || die "revision $BASE not in $REPO (fetch upstream or pass --patch)"
  git -C "$REPO" -c core.quotepath=off diff --no-color --no-ext-diff "$BASE" HEAD -- . ':(exclude)fast' ':(exclude)README.md' ':(exclude).github' \
    > "$STAGE/regenie-4.1.3-fast.patch"
  [ -s "$STAGE/regenie-4.1.3-fast.patch" ] || die "git diff $BASE HEAD is empty: are the regenie-fast commits checked out?"
fi
EPOCH=${SOURCE_DATE_EPOCH:-$(git -C "$REPO" log -1 --format=%ct 2>/dev/null || date +%s)}

# Everything below runs inside the library image: check the official program, copy the libraries, write the zip.
cat > "$OUT/.work/inside.sh" <<'INSIDE'
set -euo pipefail
S=/out/regenie-fast
python3 - "$OFFICIAL_NAME" "$OFFICIAL_SHA256" <<'PY'
import hashlib, sys, zipfile
name, want = sys.argv[1:]
data = zipfile.ZipFile("/out/.work/official.zip").read(name)
got = hashlib.sha256(data).hexdigest()
if got != want:
    sys.exit(f"official program checksum mismatch: got {got}, expected {want}")
open("/out/regenie-fast/bin/regenie-4.1.3-official", "wb").write(data)
print("  official program SHA-256 OK:", got)
PY
chmod 755 $S/bin/*
echo "== system libraries (ldd in $LIB_IMAGE)"
for b in $S/bin/*; do
  ldd "$b" > /out/.work/ldd.txt || { cat /out/.work/ldd.txt; exit 1; }
  if grep -q "not found" /out/.work/ldd.txt; then grep "not found" /out/.work/ldd.txt; exit 1; fi
  awk '$2 == "=>" && $3 ~ /^\// { print $1, $3 } $1 ~ /^\/.*ld-linux-x86-64\.so\.2$/ { print "ld-linux-x86-64.so.2", $1 }' /out/.work/ldd.txt
done | sort -u | while read -r name path; do cp -L "$path" "$S/lib/$name"; done
chmod 644 $S/lib/*; chmod 755 $S/lib/ld-linux-x86-64.so.2
# every library must now come from lib/ when started through the bundled loader, as the launchers do
for b in $S/bin/*; do
  $S/lib/ld-linux-x86-64.so.2 --library-path $S/lib --list "$b" > /out/.work/list.txt
  if awk '$2 == "=>" && $3 !~ "^/out/regenie-fast/lib/" { bad = 1; print "  not bundled:", $0 } END { exit bad }' /out/.work/list.txt
  then echo "  $(basename "$b"): $(grep -c '=>' /out/.work/list.txt) libraries, all from lib/"; else exit 1; fi
  $S/lib/ld-linux-x86-64.so.2 --library-path $S/lib "$b" --version > /dev/null 2>&1 || { echo "  $(basename "$b") does not start"; exit 1; }
done
echo "== zip"
python3 - "$EPOCH" <<'PY'
import os, stat, sys, time, zipfile
root, out = "/out/regenie-fast", "/out/regenie-fast-linux-x86_64.zip"
when = max(time.gmtime(int(sys.argv[1]))[:6], (1980, 1, 1, 0, 0, 0))
EXEC = {"regenie-fast", "regenie-official", "lib/ld-linux-x86-64.so.2"}
def mode_for(rel):
    return 0o755 if rel in EXEC or rel.endswith(".sh") or rel.startswith("bin/") else 0o644
with zipfile.ZipFile(out + ".tmp", "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for d, dirs, files in os.walk(root):
        dirs.sort()
        for name in sorted(files):
            path = os.path.join(d, name); rel = os.path.relpath(path, root)
            data = open(path, "rb").read()
            if (rel.endswith(".sh") or rel in ("regenie-fast", "regenie-official")) and b"\r" in data:
                sys.exit(f"Windows line endings in {rel}: bash cannot run it")
            zi = zipfile.ZipInfo("regenie-fast/" + rel, date_time=when)
            zi.create_system = 3                                   # Unix, so unzip applies the mode bits
            zi.external_attr = (stat.S_IFREG | mode_for(rel)) << 16
            zi.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(zi, data)
os.replace(out + ".tmp", out)
with zipfile.ZipFile(out) as z:
    n = len(z.infolist()); nexec = sum((i.external_attr >> 16) & 0o111 != 0 for i in z.infolist())
print(f"  {os.path.basename(out)}: {n} files ({nexec} executable), {os.path.getsize(out) / 2**20:.1f} MiB")
PY
cd /out && sha256sum regenie-fast-linux-x86_64.zip > regenie-fast-linux-x86_64.zip.sha256
cd $S && sha256sum bin/* | sed 's/^/  /'
INSIDE
USER_OPT=(); [ "$(uname -s)" = Linux ] && USER_OPT=(--user "$(id -u):$(id -g)")
dk run --rm ${USER_OPT[@]+"${USER_OPT[@]}"} -v "$(hostpath "$OUT"):/out" -e OFFICIAL_NAME="$OFFICIAL_NAME" -e OFFICIAL_SHA256="$OFFICIAL_SHA256" \
  -e EPOCH="$EPOCH" -e LIB_IMAGE="$LIB_IMAGE" --entrypoint bash "$LIB_IMAGE" /out/.work/inside.sh
rm -rf "$OUT/.work"
echo "== done: $OUT/$ZIP_NAME"
sed 's/^/  sha256 /' "$OUT/$ZIP_NAME.sha256"
