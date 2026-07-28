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
| `{game}.key` | CPS-2 key (e.g. `armwar.key`, `avsp.key`) |
| `cps2keys.zip` / `keys.zip` | Pack of many `*.key` files (optional) |

## Neo Geo / FBNeo

Current FBNeo requires these dumps **inside** `neogeo.zip` (exact CRC):

- `sm1.sm1` → `94416d67`
- `sfix.sfix` → `c2ea0cfd`
- `000-lo.lo` → `5a86cff2` (128 KiB)

You can drop several `neogeo.zip` / `neogeo.zip.<hash>` files here. At startup the
app scores them and installs the best match as `neogeo.zip` in the system dir.

## CPS-2 keys (Armored Warriors, Alien vs Predator, …)

Capcom CPS-2 games need a separate encryption key, e.g.:

- `armwar.key` (CRC `fe979382` for current FBNeo)
- `avsp.key` for Alien vs. Predator

Put each `.key` here (or one `cps2keys.zip` containing them). On load the app:

1. installs keys into the system dir  
2. copies them next to the game ZIP  
3. injects them **into** the app’s private copy of the ZIP  

Your game ZIP alone without the matching `.key` will show FBNeo’s
“romset is missing files” dialog — that is an incomplete set, not an app bug.

Neo Geo / Metal Slug does **not** use these keys and is unaffected.
These files are gitignored so they are not committed by accident.

**Important:** rebuild the app after adding plaintext files here. The player never
picks BIOS/keys — choosing a game loads support files from assets automatically.

Android CI decrypts `ci/bios/neogeo.zip.enc` into this folder before packaging
so Metal Slug works on phone APKs without committing plaintext BIOS.
