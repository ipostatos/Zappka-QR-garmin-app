import Toybox.Lang;
import Toybox.Test;

// RFC 6238 Appendix B, SHA-1, key = ASCII "12345678901234567890".
(:test)
const RFC_KEY_HEX = "3132333435363738393031323334353637383930";

(:test)
function totpRfc6238EightDigits(logger as Logger) as Boolean {
    var key = Hex.decode(RFC_KEY_HEX) as ByteArray;
    var times = [59, 1111111109, 1111111111, 1234567890, 2000000000];
    var expected = ["94287082", "07081804", "14050471", "89005924", "69279037"];
    for (var i = 0; i < times.size(); i++) {
        var got = TotpGenerator.generate(key, times[i], 30, 8);
        if (!got.equals(expected[i])) {
            logger.error("t=" + times[i] + " got " + got);
            return false;
        }
    }
    return true;
}

(:test)
function totpRfc6238SixDigitsAndLongTime(logger as Logger) as Boolean {
    var key = Hex.decode(RFC_KEY_HEX) as ByteArray;
    // 6-digit = last 6 digits of the 8-digit vector; 20000000000 exercises a 64-bit counter.
    Test.assertEqual(TotpGenerator.generate(key, 59, 30, 6), "287082");
    Test.assertEqual(TotpGenerator.generate(key, 1111111109, 30, 6), "081804");
    Test.assertEqual(TotpGenerator.generate(key, 20000000000l, 30, 8), "65353130");
    return true;
}

(:test)
function totpCounterAndRemaining(logger as Logger) as Boolean {
    Test.assertEqual(TotpGenerator.counterFor(59, 30), 1l);
    Test.assertEqual(TotpGenerator.counterFor(60, 30), 2l);
    Test.assertEqual(TotpGenerator.secondsRemaining(60, 30), 30);
    Test.assertEqual(TotpGenerator.secondsRemaining(89, 30), 1);
    return true;
}

(:test)
function hexDecode(logger as Logger) as Boolean {
    var b = Hex.decode("00fFa5") as ByteArray;
    Test.assert(b.size() == 3 && b[0] == 0 && b[1] == 255 && b[2] == 0xA5);
    Test.assert(Hex.decode("abc") == null);
    Test.assert(Hex.decode("zz") == null);
    Test.assert(Hex.decode("") == null);
    return true;
}
