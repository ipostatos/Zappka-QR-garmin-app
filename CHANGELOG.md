# Changelog

All notable changes to this project are documented here. This project loosely
follows [Semantic Versioning](https://semver.org/).

## v1.0.0-rc1 — settings import, release provenance

### Changed
- **Settings import never loses a working account.** An invalid new secret or ID no longer
  replaces a valid pair: the watch shows *New secret rejected* for 4 s and keeps the previous
  account. Without a working pair it still shows *Invalid Zappka configuration*.
- **Secret before ID.** A secret entered before the user ID is kept as pending in watch storage
  until the ID arrives (new screen: *Secret saved. Now enter your Zappka user ID*).
- **Field blanked first.** The secret setting is cleared before validation and independently of
  the save, so it cannot sync back to the phone after an error.

### Added
- 5 simulator tests for the settings import state machine (17 in total, passing on Solar 45,
  AMOLED 45 and AMOLED 50).
- `tools/release.sh`: refuses a dirty tree, builds every product with `-r`, aborts on secret-like
  settings defaults, prints commit, SDK and sha256 per device (`docs/RELEASES.md`).
- `tools/vault.ps1`: keeps account data encrypted for the Windows user (DPAPI);
  `tools/build-personal.sh` reads it through a pipe.
- `screenshot.jungle` and `tools/screenshots.ps1` for simulator screenshots with the public
  example account.
- CI: secret scan (gitleaks) and repository guards (no permissions in the manifest, no
  secret-like values).

### Fixed
- Test-only constants (QR reference table, example keys) are no longer compiled into release
  builds.
- `tools/sim-e2e.sh` restores `properties.xml` on any exit.

## v0.9 — first checkout

- Offline TOTP (RFC 6238, HMAC-SHA1 on `Cryptography.Hash`, 30 s, 6 digits) and Żappka payload.
- Own QR encoder (byte mode, versions 1–10, ECC L/M), verified bit-for-bit against Project Nayuki.
- Layouts for Instinct 3 Solar 45 (octagon + subscreen), AMOLED 45 and AMOLED 50.
- Countdown, buzz on every new code, inverted countdown in the last 2 s, checkout mode, glance.
- Real Żabka checkout on Instinct 3 AMOLED 45 on 2026-10-08: accepted, points credited.
