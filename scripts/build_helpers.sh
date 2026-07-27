#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cc -shared -fPIC -O2 -o "$ROOT/native/libhost_helpers.so" "$ROOT/native/shim/retro_shim.c"
echo "Built $ROOT/native/libhost_helpers.so"
