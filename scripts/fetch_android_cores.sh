#!/usr/bin/env bash
# Download Android libretro cores + build libhost_helpers.so into jniLibs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="https://buildbot.libretro.com/nightly/android/latest"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
NDK_VERSION="${ANDROID_NDK_VERSION:-26.3.11579264}"
NDK="${ANDROID_NDK_HOME:-$SDK/ndk/$NDK_VERSION}"
if [[ ! -d "$NDK" ]]; then
  echo "NDK not found at $NDK — install with: sdkmanager \"ndk;$NDK_VERSION\"" >&2
  exit 1
fi
PREBUILT="$(echo "$NDK"/toolchains/llvm/prebuilt/*/bin)"

fetch_core() {
  local abi="$1" core="$2" dest_name="$3"
  local url="${BASE}/${abi}/${core}.so.zip"
  local out="$ROOT/android/app/src/main/jniLibs/${abi}"
  mkdir -p "$out"
  echo "→ $abi / $dest_name"
  curl -fL --retry 3 -o "$TMP/${core}_${abi}.zip" "$url"
  unzip -qo "$TMP/${core}_${abi}.zip" -d "$TMP/${core}_${abi}"
  local so
  so="$(find "$TMP/${core}_${abi}" -name '*.so' | head -1)"
  cp -f "$so" "$out/$dest_name"
  chmod +x "$out/$dest_name"
}

build_helpers() {
  local abi="$1" triple="$2"
  local out="$ROOT/android/app/src/main/jniLibs/${abi}/libhost_helpers.so"
  mkdir -p "$(dirname "$out")"
  echo "→ $abi / libhost_helpers.so"
  "$PREBUILT/${triple}-clang" -shared -fPIC -O2 \
    -o "$out" \
    "$ROOT/android/app/src/main/cpp/retro_shim.c"
}

for abi in arm64-v8a armeabi-v7a; do
  fetch_core "$abi" mame2003_plus_libretro_android libmame2003_plus_libretro.so
  fetch_core "$abi" fbneo_libretro_android libfbneo_libretro.so
done
build_helpers arm64-v8a aarch64-linux-android21
build_helpers armeabi-v7a armv7a-linux-androideabi21

echo "Android natives ready:"
ls -lh "$ROOT/android/app/src/main/jniLibs"/*/
