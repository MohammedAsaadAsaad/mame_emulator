#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/native/cores"
mkdir -p "$OUT" "$ROOT/native/support" "$ROOT/native/saves"
cd /tmp
curl -L -o fbneo.zip "https://buildbot.libretro.com/nightly/linux/x86_64/latest/fbneo_libretro.so.zip"
curl -L -o mame2003_plus.zip "https://buildbot.libretro.com/nightly/linux/x86_64/latest/mame2003_plus_libretro.so.zip"
unzip -o fbneo.zip -d "$OUT"
unzip -o mame2003_plus.zip -d "$OUT"
# Prefer shim helpers (same as Windows/Android); fallback to legacy host_helpers.c
if [[ -f "$ROOT/native/shim/retro_shim.c" ]]; then
  cc -shared -fPIC -O2 -o "$ROOT/native/libhost_helpers.so" "$ROOT/native/shim/retro_shim.c"
else
  gcc -shared -fPIC -O2 -o "$ROOT/native/libhost_helpers.so" "$ROOT/native/host_helpers.c"
fi
ls -lh "$OUT" "$ROOT/native/libhost_helpers.so"
