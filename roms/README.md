# ROMs (not shipped)

This folder is **not** packaged with the app. Do not commit game ZIPs here
(`roms/*.zip` is gitignored).

Users add games themselves via **Games → Import** or drag-and-drop a `.zip`
from anywhere on the device.

Optional local notes for developers running smoke tests: place a public-domain
set such as `gridlee.zip` here only on your machine — the UI will not auto-index
this folder; use Import if you want it in the library.

**BIOS / keys** (Neo Geo `neogeo.zip`, CPS-2 `*.key`, …) go in `assets/bios/`
for bundling support files — those are not game ROMs.
