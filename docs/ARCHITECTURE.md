# Architecture, feasibility and sizing

## Connect IQ feasibility
| Need | API | Verified |
|---|---|---|
| UTC epoch | `Time.now().value()` (seconds, UTC, independent of timezone) | yes |
| SHA-1 | `Cryptography.Hash` (`HASH_SHA1`) | yes, sim; RFC vectors pass |
| HMAC-SHA1 | built-in HMAC **rejects SHA-1** → own RFC 2104 wrapper | yes |
| Pixel drawing | `Dc.fillRectangle`, `Graphics.createBufferedBitmap` (API 4.0+) | yes |
| Subscreen | `WatchUi.getSubscreen()` | yes (Solar) |
| Settings input | `settingConfig type="password"` | compiles; mobile UI to verify |
| Secure storage | none available → `Application.Storage` | documented limitation |

## Modules
```
ZappkaApp ─ ZappkaView ─┬─ CredentialStore ─ ZappkaCredentials ─ Hex
ZappkaDelegate          ├─ TotpGenerator (pure, no UI)
                        ├─ ZappkaPayload  (pure string)
                        ├─ QrEncoder      (pure, ByteArray matrix)
                        ├─ QrRenderer     (layout + bitmap)
                        └─ CountdownRenderer
ZappkaProtocol = all constants (TIME_STEP, DIGITS, URL parts, QR ECC/mask, UX timings)
```

## Memory / performance
- Watch-app memory: Solar 128 KB, AMOLED 768 KB. Per step: ~2 × 1089 B matrices plus a 2-colour bitmap
  (Solar 66×66, AMOLED 198×198). These are released on the next step.
- **Watchdog** is the binding constraint on Solar (instruction budget per callback). Encode, layout
  and render are split across `onLayout` and `onUpdate`. RS uses log tables; mask scoring is skipped.
- 1 Hz timer: blits the bitmap and redraws the countdown. The encoder runs once per 30 s.

## QR size (payload 61 B → version 4-M, 33 modules)
Pixel pitch is an estimate from nominal display diameters (verify on device).

| Device | Usable area | Chosen | QR (modules) | QR + quiet | ≈ physical |
|---|---|---|---|---|---|
| Instinct 3 Solar 45 | octagon 176 px minus subscreen | 2 px, q=4 | 66 px | 82 px | 0.16 mm/px → module 0.32 mm, QR ≈ 10.5 mm |
| Instinct 3 AMOLED 45 | circle 390 px | 6 px, q=4 | 198 px | 246 px | ≈0.08 mm/px → module 0.47 mm, QR ≈ 15 mm |
| Instinct 3 AMOLED 50 | circle 416 px | 6 px, q=4 (+ text band) | 198 px | 246 px | ≈0.08 mm/px → QR ≈ 15.5 mm |

Solar alternatives evaluated by brute force on the real simulator mask: 4 px does not fit at all,
and 3 px fits only with a 0-module quiet zone. So 2 px with the full quiet zone is the best compliant option.

## Settings import

`CredentialStore.importFromSettings()` runs on start and on every settings change:

1. If the secret field is not empty, it is **blanked first**, before any validation.
2. A secret without an ID is kept as *pending* in Storage until the ID arrives.
3. A valid pair replaces the stored one. An invalid one never does: with a working pair the
   watch shows "New secret rejected" for 4 s and keeps it; without one it shows "Invalid".

Covered by `tests/CredentialStoreTest.mc`.

## Menu and text screens

- `ZappkaMenu` builds a native `Menu2` (system-rendered on every device): two toggles, status,
  sign out (native `Confirmation`; the item is removed from the open menu after sign out) and about.
- `Prefs` keeps menu settings in Storage (buzz on new code, default on).
- `TextScreen` draws About, Status and the QR-screen messages. On a device with a subscreen the
  text block starts below it. `tests/TextScreenTest.mc` measures every line with the watch font
  and checks it lies inside the visible screen shape and clear of the subscreen.

## Builds

| Jungle | Purpose |
|---|---|
| `monkey.jungle` | release and tests (`-t`) |
| `screenshot.jungle` | simulator screenshots only: drops the glance (`:glanceentry`) so the QR view opens directly |
