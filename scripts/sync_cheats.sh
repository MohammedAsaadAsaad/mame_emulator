#!/usr/bin/env bash
# Pack FBNeo .ini cheats into assets/cheats/fbneo_cheats.zip for bundling.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-/home/mohammed/Downloads/FBNeo-cheats-master/cheats}"
OUT="$ROOT/assets/cheats/fbneo_cheats.zip"

if [[ ! -d "$SRC" ]]; then
  echo "Cheats source not found: $SRC" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
# Store flat .ini files at zip root (FBNeo expects basename match).
(
  cd "$SRC"
  zip -q -r "$OUT" . -i '*.ini'
)
COUNT="$(unzip -l "$OUT" | grep -c '\.ini$' || true)"
SIZE="$(wc -c < "$OUT" | tr -d ' ')"
echo "Wrote $OUT ($COUNT ini, $SIZE bytes)"
