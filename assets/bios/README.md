# Bundled BIOS (personal use)

Place FBNeo/MAME **BIOS / support files** here (not game ROMs, not libretro cores).
On every launch (and before each ROM load) the app copies them into the libretro
system directory automatically — no picker.

| File | Used for |
|------|----------|
| `neogeo.zip` | Neo Geo / Metal Slug / KOF / Garou / … |
| `neogeo.zip.*` | Extra Neo Geo candidates — app CRC-picks the best |
| `neocdz.zip` | Neo Geo CD (optional) |
| `pgm.zip` | PolyGame Master |
| `cps3.zip` | Capcom CPS-3 |
| `qsound.zip` | Some CPS boards (optional) |
| `{game}.key` | CPS-2 encryption keys (e.g. `armwar.key`) — copied beside the ROM |

## Neo Geo / FBNeo

Current FBNeo requires these dumps **inside** `neogeo.zip` (exact CRC):

- `sm1.sm1` → `94416d67`
- `sfix.sfix` → `c2ea0cfd`
- `000-lo.lo` → `5a86cff2` (128 KiB)

You can drop several `neogeo.zip` / `neogeo.zip.<hash>` files here. At startup the
app scores them and installs the best match as `neogeo.zip` in the system dir.

## CPS-2 keys (Armored Warriors, etc.)

Many Capcom CPS-2 games need a separate `{romname}.key` file (e.g. `armwar.key`).
Put that file here; the app installs it into the system dir and copies it **next to
the game ZIP** before load. A game ZIP alone without its `.key` will show FBNeo’s
“romset is missing files” dialog — that is not a BIOS wiring bug.

These files are gitignored so they are not committed by accident.

**Important:** rebuild the app after adding plaintext files here. The player never
picks BIOS — choosing a game loads support files from assets automatically.

Android CI decrypts `ci/bios/neogeo.zip.enc` into this folder before packaging
so Metal Slug works on phone APKs without committing plaintext BIOS.
