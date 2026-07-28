#!/usr/bin/env bash
# Decrypt ci/bios/neogeo.zip.enc → assets/bios/neogeo.zip for release builds.
# Requires env NEOGEO_BIOS_PASSPHRASE (GitHub Actions secret).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENC="${1:-$ROOT/ci/bios/neogeo.zip.enc}"
OUT="${2:-$ROOT/assets/bios/neogeo.zip}"

if [[ -z "${NEOGEO_BIOS_PASSPHRASE:-}" ]]; then
  echo "NEOGEO_BIOS_PASSPHRASE is not set" >&2
  exit 1
fi
if [[ ! -f "$ENC" ]]; then
  echo "Missing encrypted BIOS: $ENC" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$ENC" \
  -out "$OUT" \
  -pass env:NEOGEO_BIOS_PASSPHRASE

SIZE="$(wc -c < "$OUT" | tr -d ' ')"
if [[ "$SIZE" -lt 100000 ]]; then
  echo "Decrypted BIOS looks too small ($SIZE bytes)" >&2
  exit 1
fi
echo "Restored Neo Geo BIOS → $OUT ($SIZE bytes)"
