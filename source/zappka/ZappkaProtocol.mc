import Toybox.Lang;

// Single source of truth for every protocol parameter.
// See docs/zappka-protocol.md for the CONFIRMED / LIKELY / UNKNOWN status of each value.
(:glance)
module ZappkaProtocol {
    const APP_VERSION = "1.1.0";   // keep in sync with the git tag and CHANGELOG

    // TOTP (RFC 6238 compatible)
    const TIME_STEP = 30;          // seconds
    const DIGITS = 6;
    // HASH_ALGORITHM: SHA-1 (Cryptography.HASH_SHA1), selected in TotpGenerator.

    // Payload
    const PAYLOAD_PREFIX = "https://srln.pl/view/dashboard?ploy=";
    const OTP_PARAM = "&loyal=";

    // Account data validation (observed formats, see protocol doc)
    const USER_ID_MIN_LEN = 6;
    const USER_ID_MAX_LEN = 20;
    const SECRET_MIN_BYTES = 16;
    const SECRET_MAX_BYTES = 64;

    // QR rendering parameters
    const QR_ECC = 1;              // QrEncoder.ECC_M
    const QR_MASK = 0;             // fixed mask, see README "QR encoder"
    const QR_QUIET_MIN = 2;        // modules; layout prefers 4 and falls back
    const QR_QUIET_TARGET = 4;

    // UX
    const SAFETY_WINDOW = 2;       // seconds; countdown highlighted, QR NOT switched early
    const AUTO_EXIT_SECONDS = 180; // close the app if left open (battery)
    const CHECKOUT_EXIT_SECONDS = 600; // checkout mode: longer, but still bounded
    const VIBE_ON_ROTATE_MS = 120;     // short pulse when a new code appears (0 = off)
    const NOTICE_SECONDS = 4;          // "new secret rejected" notice before the QR returns
}
