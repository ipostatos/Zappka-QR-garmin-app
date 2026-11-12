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

## 2. Build the app with your account and install it

Garmin Connect shows app settings only for apps installed from the Connect IQ Store. An app copied
over USB has no settings page there, so the account goes in at build time, as the settings
defaults of a **personal build**. On Windows (Git Bash), with the vault from step 1:

```sh
sh tools/build-personal.sh instinct3amoled45mm developer_key.der   # or instinct3solar45mm, instinct3amoled50mm
```

It writes `bin/personal-<device>.prg` and restores the empty defaults in the sources afterwards.
**The file contains your secret.** Treat it like the secret itself:

1. Connect the watch over USB. In `GARMIN\APPS` delete an older Zappka `.prg` if there is one, and
   in `GARMIN\APPS\SETTINGS` the file with the same name: the watch keeps the settings it already
   has, and they would override the new defaults (after a sign out they are empty).
2. Copy `personal-<device>.prg` to `GARMIN\APPS`. Disconnect. The app appears as **Zappka QR** in
   the apps list and in the glance loop.
3. Delete the file from the computer: `rm -f bin/personal-*`.

A release `.prg` (no account inside) is for the simulator, for reviewing the build and for a
store install. If the app is ever installed from the Connect IQ Store, the account is entered in
Garmin Connect instead: your watch → **Connect IQ apps** → **Zappka QR** → **Settings**, the fields
*Żappka user ID (ployId)* and *Żappka secret (hex)*; the settings travel to the watch on the next
sync. The app treats both sources the same way.

## 3. First start on the watch

Open the app. It reads the pair from the settings, blanks the secret field, checks the pair and
moves the secret into watch storage. From now on the QR appears immediately.

The order of the two fields does not matter: a secret entered before the ID waits for it.

## At the checkout

| Button | Action |
|---|---|
| open from glance | QR is on the screen |
| **START** | checkout mode on/off: maximum backlight, 10 min timeout |
| **MENU** | menu: checkout mode, buzz on new code, auto-exit, status, sign out, about |
| **BACK** | exit (the app also closes itself after 3 min; **MENU → Auto-exit** sets 1, 3 or 5) |

A new code appears every 30 seconds with a short buzz. In the last 2 seconds the countdown is
inverted; the code is still valid.

## Troubleshooting

| Screen / symptom | Cause | Fix |
|---|---|---|
| *Setup required. Add account in Garmin Connect* | no account on the watch; after a sign out the empty settings on the watch override the defaults of a new build | step 2: personal build, delete the old `.prg` **and** its `SETTINGS` file, copy the new one |
| *Secret saved. Now add the user ID* | the build (or the Garmin Connect settings) had the secret but no ID | check `ployId` in the vault JSON, rebuild; or enter the ID in Garmin Connect for a store install |
| *Invalid account. Check ID and secret* | ID not digits, or secret not 64 hex characters, and no working account | check the JSON from step 1, rebuild and reinstall |
| *New secret rejected. Old account kept* (4 s, then the QR) | the new value was invalid | the previous account still works; re-enter the new value if you meant to change it |
| Checkout does not accept the code | watch clock drifted or the secret was re-issued | sync the watch with the phone; **MENU → Status** shows UTC time; get the secret again (step 1) |
| Scanner does not see the code | low brightness | press START for checkout mode |
| `sync?` next to the countdown (`!` on Solar) | the phone has not been connected for over 24 h, the clock may drift | connect the phone, open Garmin Connect, then the app |

## Changing the account

Put the new JSON into the vault (`pwsh tools/vault.ps1 put secrets.json`), build a new personal
`.prg`, and on the watch delete the old `.prg` and its `SETTINGS` file before copying the new one.
Keep `GARMIN\APPS\DATA`: that is where the working account lives. For a store install, enter the
new values in Garmin Connect.

Whenever a field changes (ID, secret, or both), the watch asks
*Use new account data for ID ****1234?* when the QR screen opens. Until you confirm, the old
account keeps working. NO or BACK keeps it.

## Signing out

**MENU → Sign out → confirm.** The account is deleted from the watch and both settings fields are
cleared, so nothing comes back on the next sync. The QR screen then shows *Setup required*.
To sign in again, install a personal build as in step 2, including the deletion of the
`SETTINGS` file: the cleared fields would otherwise hide the new defaults.
