# On-watch account linking (planned, v1.2)

Goal: link the Żappka account **from the watch itself**, with no computer and no script.

## Can the watch read the SMS?

No. Connect IQ has no API for notification content. But it does not need one: Garmin already shows
incoming SMS as a smart notification over any app. The user reads the 6 digits on the wrist and
enters them with the buttons.

## Flow

```
Watch (Link build)                   Garmin Connect Mobile      Żappka sign-in services
─────────────────────────────────    ─────────────────────      ───────────────────────
[1] "Link account", phone number
    (from app settings or a picker)
[2] request SMS code ─────────────▶  HTTPS relay ────────────▶  SMS sent to the phone
[3]                                  phone gets the SMS ─────▶  watch shows the notification
    user reads 6 digits on the wrist, closes the notification
[4] 6-wheel picker, SELECT
[5] sign in with the code ────────▶  ─────────────────────▶    session (memory only)
[6] fetch loyalty QR data ────────▶  ─────────────────────▶    ployId + loyalty secret
[7] CredentialStore.save(), all temporary values set to null, back to the QR
```

`Communications.makeWebRequest` supports what the sign-in needs: HTTPS `POST` with a JSON body,
custom headers, JSON responses as dictionaries. Requests go through Garmin Connect Mobile on the
phone or the watch's Wi-Fi. Responses are a few KB, well inside the 128 KB Solar budget.

## Rules

- **Two builds.** The main build keeps **zero permissions**. Linking lives in a separate *Link*
  build (`monkey-link.jungle`, its own manifest with `Communications`, code under a `(:link)`
  annotation that the main build excludes).
- Only `ployId` and the **loyalty** secret are stored. Session tokens, the SMS code and any payment
  secret are never stored and are cleared right after use.
- No logging of values; errors are shown as short codes.
- At most 3 SMS per session, no resend before the server's retry time, whole flow times out after
  5 minutes.
- The Link build is for sideloading only, not for the Connect IQ Store: it talks to a private
  sign-in API that can change at any time.

## Open question before building

Does Garmin Connect Mobile pass the request headers the sign-in API expects, on a **real** phone?
The simulator sends requests from the computer and cannot answer this. A one-evening spike on the
real watch decides: if it passes, build v1.1; if not, the fallback is an Android companion app.

## Points balance (proposed)

Goal: see on the watch that the points of a purchase were credited. The official app sends no
push notification for this, so the watch cannot simply show one.

- **Where:** a *Points* item in the menu of the Link build, fetched on demand. Not under the QR:
  there is no room on Instinct 3 Solar, and points arrive after the payment, not while scanning.
- **What it needs:** network (the Link build has it) and a signed-in session. A session lasts
  about an hour, so showing points later means keeping a **long-lived refresh token** on the
  watch. That token is far more powerful than the loyalty secret: it opens the whole account.
  `Application.Storage` is not encrypted by the app.
- **Unknown:** which sign-in API request returns the balance. The reference projects do not
  read it.
- **Rules if built:** token only in the Link build, wiped by *Sign out*, never logged; the main
  build keeps zero permissions and no token.

**Decision pending:** whether a long-lived account token on the watch is acceptable for this.

## Phone settings for SMS on the watch

- Android: Garmin Connect has notification access; smart notifications are on for Messages.
- iPhone: Settings → Notifications → Messages → Show previews: **Always**, otherwise the watch
  shows "New message" without the text.
