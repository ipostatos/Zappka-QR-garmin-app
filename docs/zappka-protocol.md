# Żappka dynamic QR — protocol notes (ZPG-00)

Status as of **2026-10-02**. Żabka publishes no official documentation for this. Everything below
comes from independent reverse-engineered clients, cross-checked against each other and against
RFC 6238 test vectors.

## Sources

| Source | What it shows | Last activity |
|---|---|---|
| [iGerman00/zabka-totp-webapp](https://github.com/iGerman00/zabka-totp-webapp) (`script.js`, `login-for-secrets.py`) | TOTP code, payload URL, secret/ID format, how the owner obtains them | login script updated 2026-05-09 (app client `5.35.1`) |
| [TehFridge/ZappkaQR](https://github.com/TehFridge/ZappkaQR) (`main.c`) | Same TOTP (decompiled from the Android app), same URL, `TIME_STEP 30`, `DIGITS 6` | — |
| TehFridge/Zappka3DS | Original port that the web app credits | — |

The two implementations are independent (C vs. JS/Python) and agree byte-for-byte on the algorithm.

## CONFIRMED (two independent implementations agree, and the math checks out)

- **Payload:** `https://srln.pl/view/dashboard?ploy=<ployId>&loyal=<otp>`
- **OTP:** standard RFC 6238 TOTP
  - counter = `floor(unix_utc_seconds / 30)`, packed as 8-byte big-endian
  - HMAC-**SHA-1**
  - dynamic truncation (RFC 4226 §5.3), `& 0x7FFFFFFF`
  - `mod 10^6`, zero-padded to **6 digits**
- **Time step:** 30 s
- **Secret encoding:** **hex string** (64 hex chars = 32 bytes in observed accounts).
  ⚠ **Differs from the initial hypothesis.** It is not Base32, so `Base32.mc` was replaced by `Hex.mc`.
- **Account identifier (`ployId`):** a numeric string (12 digits in the published example).
- **How the owner gets the data:** the owner logs in with their own phone number + SMS code via
  `login-for-secrets.py`, which returns `{"secret": "...", "ployId": "..."}`. This happens once, on a
  computer. The Garmin app never talks to Żabka.

## LIKELY

- `ployId` is always 12 digits. The app accepts 6–20 digits so as not to over-fit one sample.
- QR ECC level and mask are irrelevant to the checkout. Reference clients use different ECC
  levels (H in ZappkaQR, Q in the web app), and a QR decoder handles any valid level/mask.
- The payload is not checked as a URL by the checkout, only parsed for `ploy` and `loyal`.

## FIELD-CONFIRMED (2026-10-08)

- The watch-generated QR is accepted at a real Żabka checkout and loyalty points are credited.
- A code scanned 3–4 s before its step ends is still accepted.

## UNKNOWN

- **Server acceptance window** (partly answered: the end of a step is safe in practice; whether an already-expired code is accepted is still untested): whether the previous/next 30 s code is also accepted (RFC 6238
  suggests ±1 step, but this is not verifiable without server access).
  → The app **does not switch early**. It shows the current code until the step changes, and in the
  last `SAFETY_WINDOW` (2 s) it only highlights the countdown.
- Whether Żabka will rotate secrets, change the URL host, or add a signature in future app
  versions. If the official app stops matching, re-check the sources above.
- Whether the secret is ever re-issued (for example after logging in on a new phone). If the QR is
  rejected at checkout, fetch the secret again.

## Verification performed

| Check | Result |
|---|---|
| RFC 6238 SHA-1 vectors (t = 59, 1111111109, 1111111111, 1234567890, 2000000000, 20000000000) | pass (simulator unit tests) |
| End-to-end OTP vs. reference Python `generate_totp` (example secret, t = 1700000000) | pass |
| QR matrix vs. Project Nayuki `qrcodegen` (v4-M mask 0, full matrix; v8-M mask 5, checksum) | bit-identical |
| Simulator screen → OpenCV decode → compare with independent Python TOTP | match on Instinct 3 Solar 45, AMOLED 45, AMOLED 50 |
| QR rotation across a 30 s boundary in the simulator | new code shown, no watchdog error |
| Real Żabka checkout (Instinct 3 AMOLED 45 mm, owner's account, 2026-10-08) | **accepted, points credited** |
| Code scanned with only 3–4 s of its 30 s left | **accepted** |
