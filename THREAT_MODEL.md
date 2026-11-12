# THREAT MODEL — Zappka QR for Garmin

> Method: STRIDE over the watch app and its provisioning. Updated for v1.0: 2026-11-12.

---

## 1. System description

A Connect IQ watch app that shows the owner's Żappka loyalty QR code. It computes an RFC 6238
TOTP from a stored secret every 30 seconds and encodes it as a QR code on the watch. It declares
no permissions: no network, no background, no positioning. Account data is entered once through
the app settings in Garmin Connect.

---

## 2. Assets

| ID | Asset | Sensitivity | Where |
|----|-------|-------------|-------|
| A1 | Loyalty secret (32 bytes, hex) | **High**: generates valid codes for the account | watch `Application.Storage`; in transit once via Garmin Connect |
| A2 | User ID (`ployId`) | Medium: personal identifier | watch `Application.Storage`, inside every QR |
| A3 | Current QR / OTP | Low: valid for one 30 s step | watch screen |
| A4 | Developer signing key | High for releases | developer machine, never in the repo |
| A5 | Source and release builds | Low-Medium | Git, `docs/RELEASES.md` hashes |

---

## 3. Trust boundaries

```
TB1: Phone (Garmin Connect app settings) -> Garmin Connect -> watch Properties
     Once, at setup. The app blanks the secret field before validation.

TB2: Watch Properties -> app Storage
     CredentialStore validates the pair; invalid input never replaces a working pair.

TB3: Watch screen -> checkout scanner
     The QR is visible to anyone looking at the screen while the app is open.

TB4: Developer machine -> repository / release
     No account data or keys in the repo; CI scans every push.
```

---

## 4. Threats (STRIDE)

| ID | Threat | Category | Mitigation | Residual |
|----|--------|----------|------------|----------|
| T1 | Secret read from watch storage by someone with developer-level filesystem access | Information disclosure | app-private storage; watch stays on the wrist; device lock | **Accepted**: Connect IQ has no keystore |
| T2 | Secret kept by Garmin Connect after setup | Information disclosure | field blanked first; one-time transit | Unknown retention on Garmin's side; removed by on-watch linking (v1.1) |
| T3 | Secret sent off the watch by the app | Information disclosure | **no permissions**, enforced by the runtime; CI guard on the manifest | None known |
| T4 | Secret in logs or error screens | Information disclosure | `toString()` shows only presence and length; errors carry no values | None known |
| T5 | Typo or bad sync disables a working account | Denial of service | invalid input never replaces a working pair; rejection shown once | Low |
| T6 | Secret committed to the repo or baked into a shared `.prg` | Information disclosure | `.gitignore`, gitleaks, `check-secrets.py`, release script aborts on secret-like defaults; personal builds read from an encrypted vault and must be deleted after install | Personal builds remain the user's responsibility |
| T7 | Shoulder-surfing / photo of the QR | Spoofing | code valid for one 30 s step; auto-exit after 3 min | Low |
| T8 | Watch clock drift makes codes invalid | Denial of service | UTC clock, sync with phone; MENU shows UTC time | Low |
| T9 | Tampered release | Tampering | builds signed with the developer key; sha256 per build in `docs/RELEASES.md` | Low |
| T10 | Żabka changes the scheme (host, secret rotation, signature) | Availability | all constants in `ZappkaProtocol.mc`; protocol notes in `docs/PROTOCOL.md` | Outside our control |

---

## 5. Out of scope

Żabka's services, the official app, Garmin firmware and Garmin Connect, and the third-party login
script used to obtain the account data (read it before running it).
