#!/usr/bin/env bash
# Local pre-push checks for Neo Geo / Android BIOS packaging.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="${FLUTTER_ROOT:-$HOME/development/flutter}/bin:$PATH"

echo "== dart analyze (bios / load paths) =="
dart analyze \
  lib/services/system_bios_service.dart \
  lib/services/rom_library_service.dart \
  lib/emulator/emulator_controller.dart \
  lib/models/library_models.dart

echo "== flutter test Neo Geo smoke =="
flutter test test/neogeo_smoke_test.dart --reporter expanded

echo "== ALL LOCAL CHECKS PASSED =="
