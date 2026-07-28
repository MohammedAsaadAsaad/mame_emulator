# Packaged Neo Geo BIOS (encrypted)

`neogeo.zip.enc` is an AES-256 encrypted copy of a personal Neo Geo BIOS set
used only so **Android CI APKs** can bundle BIOS for Metal Slug / KOF / etc.

- Plaintext `assets/bios/neogeo.zip` stays gitignored.
- GitHub Actions secret `NEOGEO_BIOS_PASSPHRASE` decrypts this file before
  `flutter build apk` (see `scripts/decrypt_bios.sh`).
- Do not commit the passphrase or the plaintext zip.
