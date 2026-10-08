# Zappka QR for Garmin (unofficial)

An offline Garmin Connect IQ watch app that shows **your own** Żappka dynamic loyalty QR code.

> **Independent, unofficial project.** It is not affiliated with, endorsed by or connected to Żabka
> Polska. "Żabka" and "Żappka" are trademarks of their owners and are used here only to describe
> compatibility. Use it only with your own account.

## What it does

The watch computes the same time-based code the official app shows, entirely locally:

```text
Time (UTC epoch, watch clock)
  ↓
TOTP  (RFC 6238, HMAC-SHA1, 30 s, 6 digits)
  ↓
Żappka payload  https://srln.pl/view/dashboard?ploy=<ployId>&loyal=<otp>
  ↓
QR encoder (byte mode, ECC M, on-watch)
  ↓
Display (integer pixel modules, black on white, quiet zone)
```

There is no phone link at runtime, no network, no backend and no telemetry. See
[docs/zappka-protocol.md](docs/zappka-protocol.md) for what is confirmed, likely and unknown.

## Supported devices

| Device | Status | QR geometry |
|---|---|---|
| Instinct 3 Solar 45 mm (176×176 MIP, 1-bit) | simulator ✅, real device ⏳ | 2 px/module, 4-module quiet zone, countdown in the subscreen |
| Instinct 3 AMOLED 45 mm (390×390) | simulator ✅, real device ✅, Żabka checkout ✅ | 6 px/module, 4-module quiet zone, countdown below |
| Instinct 3 AMOLED 50 mm (416×416) | simulator ✅, real device ⏳ | 6 px/module, 4-module quiet zone, countdown below |

"Simulator ✅" means the simulator screenshot was decoded with OpenCV and matched an independent
Python TOTP. The AMOLED 45 mm model was tested on a real watch at a Żabka checkout on 2026-10-08: the code was accepted and points were credited, even when scanned with 3–4 s left.

Adding another device means adding a `<iq:product>` to `manifest.xml`. The layout is computed at
runtime from screen size, shape and subscreen.

## Setup

1. **Get your account data (once, on a computer).** Use `login-for-secrets.py` from
   [iGerman00/zabka-totp-webapp](https://github.com/iGerman00/zabka-totp-webapp). It logs in with your
   phone number + SMS code and prints `{"secret":"<64 hex chars>","ployId":"<digits>"}`.
   Read the script before running it.
2. **Install the app** (sideload, see Build).
3. In **Garmin Connect** → device → Connect IQ apps → Zappka QR → Settings, enter:
   - *Żappka user ID (ployId)*: the digits
   - *Żappka secret (hex)*: the 64-character hex string (password field)
4. Open the app on the watch. On first start it validates the secret, moves it into app-private
   watch storage and **blanks the settings field**, so it is not shown again.

To change accounts, enter a new secret; it overwrites the stored one.

## Using it

- Open the app and the QR appears immediately. It switches automatically every 30 s, exactly at the
  step boundary.
- The countdown shows seconds left. In the last 2 s it is shown inverted. The code is **not**
  switched early, because the server's tolerance window is unknown (see protocol doc).
- BACK exits. MENU shows an info screen (masked ID, key length, UTC time).
- The app closes itself after 3 minutes to save battery.

## Security model

- **The secret never leaves the watch at runtime.** The app declares no permissions: no
  `Communications`, no background, no positioning. The Connect IQ runtime itself prevents network
  access without a declared permission.
- **No backend, no telemetry, no analytics, no logging of credentials.** `ZappkaCredentials.toString()`
  only prints `secret_present` and the length. Error screens never include values.
- **Storage:** Connect IQ has **no secure enclave or keystore API**. The secret lives in
  `Application.Storage` (app-private, on-watch, not encrypted at rest by the app). Anyone with
  developer-level access to the watch filesystem could read it. Only `ployId` and the secret are stored.
- **Provisioning caveat:** Connect IQ app settings travel phone → Garmin Connect → watch. The
  secret therefore passes through Garmin's settings-sync channel **once**, when you enter it. The app
  then clears the field, but treat the secret as having been handled by Garmin Connect. A future
  phone-helper provisioning path (see Roadmap) could avoid this.
- The repo contains no real credentials. Tests use the public example values from the reference
  project's README (`123456789012` / `2db764…`), which are not a real account.

## Build

Requires Connect IQ SDK ≥ 7 (developed with 9.1.0) and a developer key.

```bash
openssl genrsa -out key.pem 4096 && openssl pkcs8 -topk8 -inform PEM -outform DER -in key.pem -out developer_key.der -nocrypt
```

```bash
monkeyc -f monkey.jungle -d instinct3solar45mm -o bin/zappka.prg -y developer_key.der
```

To sideload, copy `bin/zappka.prg` to `GARMIN/APPS/` on the watch over USB.

### Tests

```bash
monkeyc -f monkey.jungle -d instinct3solar45mm -o bin/test.prg -y developer_key.der -t
```

```bash
monkeydo bin/test.prg instinct3solar45mm /t
```

There are 12 deterministic tests: RFC 6238 vectors, the reference end-to-end OTP, payload format,
credential validation and redaction, QR matrix vs. Nayuki `qrcodegen` (v4 full matrix, v8 checksum),
and the layout for each Instinct 3 model.

`tools/sim-e2e.sh <device>` builds with the public example account, runs it in the simulator,
screenshots it (Windows) and decodes the QR with OpenCV.

## Implementation notes

- **HMAC:** Connect IQ's `HashBasedMessageAuthenticationCode` rejects `HASH_SHA1` (verified in
  SDK 9.1). So HMAC (RFC 2104) is built on `Cryptography.Hash` SHA-1, which works.
- **QR encoder** (`source/qr/QrEncoder.mc`): a minimal byte-mode encoder for versions 1–10 at ECC
  L/M, written for this project. Its structure follows Project Nayuki's QR Code generator (MIT, see
  `THIRD_PARTY.md`). No existing pure-Monkey C QR library with a clear license was found. The payload
  (61 bytes) gives **version 4, 33×33**. Mask is fixed (0): automatic mask scoring costs more than the
  Instinct watchdog allows in one callback, and any mask decodes correctly.
- **Watchdog:** the first build tripped the Instinct 3 Solar watchdog. The fixes were a fused
  log-table Reed–Solomon loop, masking during placement, and computing the layout in `onLayout`
  (its own budget) instead of `onUpdate`.
- **Rendering:** the QR is encoded once per 30 s step into a 2-colour `BufferedBitmap`. The 1 s timer
  only blits that bitmap and redraws the countdown. Modules are integer pixels with no scaling or
  anti-aliasing, drawn as merged horizontal runs.
- **Time:** `Time.now().value()` is UTC epoch seconds, so the result does not depend on timezone. The
  watch syncs its clock from GPS/phone; after a long period without sync, drift of more than a few
  seconds could cause rejections near step boundaries. The info screen shows UTC for checking.

## Known risks / open items

1. **Instinct 3 Solar module size.** The usable screen is an octagon with the subscreen cut out.
   Measured on the simulator mask, 3 px modules fit only with *no* quiet zone, so the app uses
   2 px (≈0.3 mm, QR ≈10–11 mm). Checkout 2D imagers usually read this, but it is the main
   real-world risk. Test at the checkout, and if it fails, consider a "3 px, reduced quiet zone" option.
2. Server acceptance window unknown (see protocol doc).
3. MIP display contrast in low light: turn on the backlight (the app requests it on open).
4. Instinct 3 Solar and AMOLED 50 mm have not been tested on real devices yet.

## Roadmap

ZPG-00…12 done (real device + checkout on AMOLED 45 mm). Next: ZPG-13 release; Solar/AMOLED 50 field tests.
A future phone-helper provisioning path (local only, no backend) can plug into `CredentialStore.save()`.

## License

MIT, see [LICENSE](LICENSE). Third-party notices: [THIRD_PARTY.md](THIRD_PARTY.md).
