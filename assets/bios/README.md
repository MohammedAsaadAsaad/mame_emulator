# Bundled BIOS (personal use)

Place FBNeo/MAME **BIOS archives** here (not game ROMs, not libretro cores):

| File | Used for |
|------|----------|
| `neogeo.zip` | Neo Geo / Metal Slug / KOF / Garou / … |
| `neogeo.zip.*` | Extra Neo Geo candidates — app CRC-picks the best |
| `neocdz.zip` | Neo Geo CD (optional) |
| `pgm.zip` | PolyGame Master |
| `cps3.zip` | Capcom CPS-3 |
| `qsound.zip` | Some CPS boards (optional) |

## Neo Geo / FBNeo

Current FBNeo requires these dumps **inside** `neogeo.zip` (exact CRC):

- `sm1.sm1` → `94416d67`
- `sfix.sfix` → `c2ea0cfd`
- `000-lo.lo` → `5a86cff2` (128 KiB)

You can drop several `neogeo.zip` / `neogeo.zip.<hash>` files here. At startup the
app scores them and installs the best match as `neogeo.zip` in the system dir.

On startup the app copies selected BIOS into the libretro system directory
(Linux / Windows / Android). No UI picker.

These zips are gitignored so they are not committed by accident.

**Android / GitHub APK:** CI builds do **not** include `neogeo.zip` (gitignored).
Either rebuild the APK on your PC with this folder present, or on first Metal Slug
launch pick `neogeo.zip` once — it is saved into app storage for later.
