#!/bin/bash
# Maps each file of the package's lib/ folder to the Ubuntu package that installs an identical file (same SHA-256),
# and copies that package's copyright file. Run inside the image the libraries were copied from, e.g.:
#   docker run --rm -v "$PWD/fast/package/out/regenie-fast/lib:/libs:ro" -v "$PWD/out:/out" \
#     -v "$PWD/fast/package/tools:/tools:ro" \
#     regenie-deps:mkl2024.2 bash /tools/identify_libs.sh
# Output: /out/libs.tsv (file, sha256, installed path, package, version, source package, source version, arch)
# and /out/copyright/<package>/copyright. A "?" row means no installed file matched.
set -u
OUT=/out; mkdir -p "$OUT/copyright"; : > "$OUT/libs.tsv"
for f in /libs/*; do
  n=$(basename "$f"); h=$(sha256sum "$f" | cut -d' ' -f1); match=""; owner=""
  for d in /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu /lib64 /usr/lib64; do
    [ -e "$d/$n" ] || continue
    r=$(readlink -f "$d/$n")
    if [ "$(sha256sum "$r" | cut -d' ' -f1)" = "$h" ]; then
      match="$r"
      for q in "$r" "${r#/usr}" "/usr$r" "$d/$n" "${d#/usr}/$n"; do
        o=$(dpkg -S "$q" 2>/dev/null | head -1 | cut -d: -f1)
        if [ -n "$o" ]; then owner="$o"; break; fi
      done
      break
    fi
  done
  if [ -n "$owner" ]; then
    info=$(dpkg-query -W -f='${Package}\t${Version}\t${source:Package}\t${source:Version}\t${Architecture}' "$owner")
    mkdir -p "$OUT/copyright/$owner"; cp -L "/usr/share/doc/$owner/copyright" "$OUT/copyright/$owner/copyright"
  else
    info=$(printf '?\t?\t?\t?\t?')
  fi
  printf '%s\t%s\t%s\t%s\n' "$n" "$h" "$match" "$info" >> "$OUT/libs.tsv"
done
cat "$OUT/libs.tsv"
