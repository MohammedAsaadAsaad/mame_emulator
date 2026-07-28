# FBNeo native cheats

Place the official pack here so Android/desktop builds can install it into
`system/fbneo/cheats/` automatically:

1. Download https://github.com/finalburnneo/FBNeo-cheats/archive/master.zip
2. Run: `./scripts/sync_cheats.sh /path/to/FBNeo-cheats-master/cheats`
3. That writes `assets/cheats/fbneo_cheats.zip` (gitignored)

On launch the app extracts the zip into the libretro system directory.
Cheats appear under **Cheats** in the toolbar after a game is loaded
(FBNeo core options — re-enable after each boot; arcade self-tests require that).
