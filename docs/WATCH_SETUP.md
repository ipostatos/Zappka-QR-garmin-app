# Watch setup

From a fresh watch to a code at the checkout. Takes about 10 minutes, once.

## 1. Get your account data

You need two values from your own Żappka account:

| Value | Looks like | Secret? |
|---|---|---|
| User ID (`ployId`) | 12 digits | no, but personal |
| Secret | 64 hex characters (`0-9`, `a-f`) | **yes**: it generates valid codes |

Use the login script of [iGerman00/zabka-totp-webapp](https://github.com/iGerman00/zabka-totp-webapp)
(`login-for-secrets.py`). It signs in with your phone number and an SMS code and prints
`{"secret":"…","ployId":"…"}`. Read the script before running it.

- **No computer?** The script also runs on a phone: Termux on Android (`pkg install python`,
  `pip install requests`), a-Shell on iOS.
- Keep the printed JSON in a password manager. On Windows, `pwsh tools/vault.ps1 put secrets.json`
  stores it encrypted for your Windows user; then delete `secrets.json`.

## 2. Install the app

1. Build it (see the README) or take a `.prg` from a release build.
2. Connect the watch over USB and copy the `.prg` to `GARMIN\APPS`.
3. Disconnect. The app appears as **Zappka QR** in the apps list and in the glance loop.

## 3. Enter the account in Garmin Connect

Garmin Connect app → your watch → **Connect IQ apps** → **Zappka QR** → **Settings**:

- *Żappka user ID (ployId)*: the digits;
- *Żappka secret (hex)*: the 64 characters (password field).

Save. The settings travel to the watch on the next sync.

## 4. First start on the watch

Open the app. It blanks the secret field in the settings, checks the pair and moves the secret into
watch storage. From now on the QR appears immediately.

The order of the two fields does not matter: a secret entered before the ID waits for it.

## At the checkout

| Button | Action |
|---|---|
| open from glance | QR is on the screen |
| **START** | checkout mode on/off: maximum backlight, 10 min timeout |
| **MENU** | info: masked ID, key length, UTC time |
| **BACK** | exit (the app also closes itself after 3 min) |

A new code appears every 30 seconds with a short buzz. In the last 2 seconds the countdown is
inverted; the code is still valid.

## Troubleshooting

| Screen / symptom | Cause | Fix |
|---|---|---|
| *Setup required* | no account on the watch | step 3, then sync the watch |
| *Secret saved. Now enter your Zappka user ID* | secret entered without the ID | enter the ID in Garmin Connect |
| *Invalid Zappka configuration* | ID not digits, or secret not 64 hex characters, and no working account | re-enter both values |
| *New secret rejected* (4 s, then the QR) | the new value was invalid | the previous account still works; re-enter the new value if you meant to change it |
| Checkout does not accept the code | watch clock drifted or the secret was re-issued | sync the watch with the phone; MENU shows UTC time; get the secret again (step 1) |
| Scanner does not see the code | low brightness | press START for checkout mode |

## Changing the account

Enter a new secret (and ID) in Garmin Connect. A valid pair replaces the stored one.
