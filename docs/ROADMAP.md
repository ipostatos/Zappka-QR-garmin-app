# Roadmap

## v1.0 — current

- [x] Offline TOTP (RFC 6238) and QR (version 4-M) on the watch, zero permissions
- [x] Instinct 3 Solar 45, AMOLED 45, AMOLED 50 layouts
- [x] Countdown, buzz on every new code, inverted countdown in the last 2 s
- [x] Checkout mode (START): maximum backlight, 10 min timeout
- [x] Glance in the widget loop
- [x] Real checkout on AMOLED 45: accepted, points credited, last seconds accepted
- [x] Settings import never loses a working account; secret before ID is kept
- [x] Test-only data excluded from release builds
- [x] Release script with commit, SDK and sha256 per device
- [x] In daily use at checkouts: tagged `v1.0.0`

## v1.1 — current: watch menu

- [x] MENU: checkout mode, buzz on new code, status (clock check), sign out with confirmation, about (version, license)
- [x] Compact message screens that fit the Instinct 3 Solar octagon and subscreen
- [x] Tests: sign out, preferences, every text screen fits the screen (EN and PL)
- [x] Clock hint after 24 h without the phone; auto-exit 1/3/5 min in the menu
- [ ] Check the menu on the watch, then tag `v1.1.0`

## v1.2 — next: link from the watch

- [ ] Spike on the real watch: sign-in requests through Garmin Connect Mobile
- [ ] Separate Link build with `Communications`; main build stays permission-free
- [ ] Phone number screen, SMS code picker (6 wheels), resend timer
- [ ] Tests for response parsing and the state machine
- [ ] Field test: link from the watch, then pay at a checkout
- [ ] **Points balance** in the menu (Link build only), see the design doc. Long-lived sign-in token on
      the watch accepted for the Link build only

Design: [`ON_WATCH_LINKING.md`](ON_WATCH_LINKING.md).

## Later

- [ ] Field tests on Instinct 3 Solar 45 (2 px modules) and AMOLED 50
- [ ] More devices (fēnix 8, epix Pro, Forerunner 965, Venu 3): one manifest line plus a layout test each
