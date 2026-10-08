import Toybox.Lang;

// Hex string <-> ByteArray. The Żappka secret is delivered as lowercase hex (not Base32).
module Hex {
    // Returns null on odd length or any non-hex character.
    function decode(str as String) as ByteArray or Null {
        var chars = str.toLower().toCharArray();
        var n = chars.size();
        if (n == 0 || n % 2 != 0) {
            return null;
        }
        var out = new [n / 2]b;
        for (var i = 0; i < n; i += 2) {
            var hi = nibble(chars[i]);
            var lo = nibble(chars[i + 1]);
            if (hi < 0 || lo < 0) {
                return null;
            }
            out[i / 2] = (hi << 4) | lo;
        }
        return out;
    }

    function nibble(c as Char) as Number {
        var v = c.toNumber();
        if (v >= 48 && v <= 57) {   // 0-9
            return v - 48;
        }
        if (v >= 97 && v <= 102) {  // a-f
            return v - 87;
        }
        return -1;
    }
}
