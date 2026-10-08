import Toybox.Lang;
import Toybox.Test;

// Public example values from the reference project README - NOT a real account.
const EXAMPLE_ID = "123456789012";
const EXAMPLE_SECRET = "2db76449a55d59f1f9420b809edb1beb19dfa434ddb5dbf331f01aec35956e35";

(:test)
function payloadFormat(logger as Logger) as Boolean {
    Test.assertEqual(ZappkaPayload.build(EXAMPLE_ID, "287082"),
        "https://srln.pl/view/dashboard?ploy=123456789012&loyal=287082");
    return true;
}

(:test)
function payloadEndToEndMatchesReference(logger as Logger) as Boolean {
    // Expected value computed with the reference Python implementation (login-for-secrets.py
    // generate_totp) for t=1700000000.
    var c = ZappkaCredentials.parse(EXAMPLE_ID, EXAMPLE_SECRET) as ZappkaCredentials;
    var otp = TotpGenerator.generate(c.secret, 1700000000, ZappkaProtocol.TIME_STEP, ZappkaProtocol.DIGITS);
    Test.assertEqual(ZappkaPayload.build(c.userId, otp),
        "https://srln.pl/view/dashboard?ploy=123456789012&loyal=518623");
    return true;
}

(:test)
function credentialValidation(logger as Logger) as Boolean {
    Test.assert(ZappkaCredentials.parse(" " + EXAMPLE_ID + " ", EXAMPLE_SECRET.toUpper() + "\n") != null);
    Test.assert(ZappkaCredentials.parse("12345a789012", EXAMPLE_SECRET) == null);
    Test.assert(ZappkaCredentials.parse("123", EXAMPLE_SECRET) == null);
    Test.assert(ZappkaCredentials.parse(EXAMPLE_ID, "abcd") == null);
    Test.assert(ZappkaCredentials.parse(EXAMPLE_ID, EXAMPLE_SECRET + "0") == null);
    Test.assert(ZappkaCredentials.parse(null, EXAMPLE_SECRET) == null);
    var c = ZappkaCredentials.parse(EXAMPLE_ID, EXAMPLE_SECRET) as ZappkaCredentials;
    // toString must never contain key material
    Test.assert(c.toString().find("2db7") == null);
    Test.assertEqual(c.maskedUserId(), "****9012");
    return true;
}
