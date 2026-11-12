## Summary

<!-- What does this PR do and why? One or two sentences. -->

## Changes

<!-- Bullet the notable changes. -->
-

## Testing

<!-- How did you verify this? -->
- [ ] Simulator tests pass on `instinct3solar45mm` (`monkeydo … /t`)
- [ ] Release build (`-r`) for every device in `manifest.xml`
- [ ] `python -I tools/check-secrets.py`
- [ ] Manual check on a watch or at a checkout (describe):

## Screenshots

<!-- Required if the screen changed. Simulator with the public example account only.
     Remove this section if nothing on the screen changed. -->

## Risks

<!-- What could this break? Anything touching credentials, settings import, the TOTP/QR path,
     or watchdog time on Solar 45 deserves a note. -->

## Checklist

- [ ] No permissions added to `manifest.xml`
- [ ] No real account data, keys or personal builds committed
- [ ] Tests added/updated for changed behavior
- [ ] Docs and CHANGELOG updated if needed
