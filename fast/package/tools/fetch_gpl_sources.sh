#!/bin/bash
# Downloads the Ubuntu source packages (upstream tarball, Ubuntu changes, .dsc) of the GPL/LGPL-licensed libraries
# listed in sources.csv (column gpl_or_lgpl = yes) into the folder given as $1 (default: third-party-sources).
# Usage: ./fetch_gpl_sources.sh [out_dir] [sources.csv]
set -eu
OUT=${1:-third-party-sources}; CSV=${2:-"$(dirname "$0")/../sources.csv"}
mkdir -p "$OUT"
tail -n +2 "$CSV" | while IFS=, read -r pkg ver gpl url; do
  [ "$gpl" = yes ] || continue
  mkdir -p "$OUT/$pkg"
  f="$OUT/$pkg/$(basename "$url")"
  [ -s "$f" ] || curl -fsSL --retry 3 -o "$f" "$url"
  echo "$pkg $ver $(basename "$url")"
done
du -sh "$OUT"
