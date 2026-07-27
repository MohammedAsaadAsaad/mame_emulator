# MAME Emulator (Flutter)

Flutter arcade cabinet with **libretro** cores (FBNeo / MAME2003+).

[![Build](https://github.com/MohammedAsaadAsaad/mame_emulator/actions/workflows/build.yml/badge.svg)](https://github.com/MohammedAsaadAsaad/mame_emulator/actions/workflows/build.yml)

## Features

- Remappable keyboard bindings
- Game library indexes ROMs at their original paths (Import / Scan / drag-drop — no copy)
- Save states + thumbnails under app support (`mame_cabinet/`)
- 10 save slots (MEMORY PACK)
- Pause / Reset / Speed (0.5×–1.5×)
- CRT / xBRZ / HQx / integer shaders
- Sound enable/mute + volume controls
- Portrait + landscape control layouts
- Skeuomorphic arcade pad (toggleable)

## CI artifacts

GitHub Actions builds on every push to `main`:

| Artifact | Contents |
|----------|----------|
| `linux-x64` | `mame_cabinet-linux-x64.tar.gz` |
| `windows-x64` | `mame_cabinet-windows-x64.zip` |
| `android-apks` | `armeabi-v7a` + `arm64-v8a` APKs |

Download from the **Actions** run → Artifacts.

## Setup (local)

```bash
./scripts/fetch_cores.sh          # Linux x86_64 libretro cores
./scripts/build_helpers.sh
flutter pub get
flutter run -d linux
```

### Windows

```powershell
.\scripts\fetch_windows_cores.ps1   # cores + host_helpers.dll (needs VS Build Tools)
flutter pub get
flutter run -d windows
```

CI packages `cores\*.dll` and `host_helpers.dll` next to the exe inside the zip.

### Android

```bash
# Requires Android SDK + NDK 26.3.11579264
./scripts/fetch_android_cores.sh  # arm64-v8a + armeabi-v7a cores + helpers
flutter build apk --release --split-per-abi
```

Point the app at your ROM folders via **Games → Scan**, **Import**, or drag-drop.  
Public-domain test ROM notes live in `roms/README.md` (`roms/*.zip` is gitignored).

## Default keys

| Key | Action |
|-----|--------|
| Arrows | Move |
| Z X C V | A B C D |
| 5 | Coin |
| 1 / Enter | Start |
| Space | Pause |
| F1 | Reset |
| F5 / F7 | Quick save / load |
| [ ] | Slot − / + |
| Esc | Unload |

Remap anytime via toolbar **Keys**.

## Icon

Regenerate platform launcher icons after changing `assets/icon/app_icon.png`:

```bash
dart run flutter_launcher_icons
```
