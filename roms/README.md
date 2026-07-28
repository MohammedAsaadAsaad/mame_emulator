# ROMs (you provide these)

This folder is optional seed content. The app indexes ROMs at their **original paths** — it does not copy them into app storage.

- Free test game: `gridlee.zip` (MAME2003+)
- Capcom / most modern arcade packs: **FBNeo**-matched sets (e.g. `dino.zip`, `punisher.zip`)
- Neo Geo (Metal Slug, KOF, …): game ZIPs **plus** `neogeo.zip` in the **same folder**

**Cores** (emulators) ≠ **BIOS archives** (`neogeo.zip`, `pgm.zip`, `cps3.zip`, …).  
On **Scan** / load / drop, BIOS zips are auto-copied into the libretro system dir on Linux, Windows, and Android.

The game library shows **real titles** (FBNeo gamelist) and caches **box art** in the background.

Most commercial ROM packs match **FBNeo** (or current MAME), not MAME2003+ (≈ MAME 0.78). Wrong DAT → load failure or garbled sprites with readable HUD text.

Use **Games → Scan** (folder), **Import**, or drag-drop a `.zip` from anywhere on disk.  
Save states and thumbnails live under the app’s support directory.
