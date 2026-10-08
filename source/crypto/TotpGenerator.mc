import Toybox.Cryptography;
import Toybox.Lang;

// RFC 6238 TOTP with HMAC-SHA1. Knows nothing about Żappka or the UI.
module TotpGenerator {
    function counterFor(unixTime as Number or Long, step as Number) as Long {
        return unixTime.toLong() / step;
    }

    function generate(key as ByteArray, unixTime as Number or Long, step as Number, digits as Number) as String {
        return generateForCounter(key, counterFor(unixTime, step), digits);
    }

    function generateForCounter(key as ByteArray, counter as Long, digits as Number) as String {
        // counter -> 8-byte big-endian message
        var msg = new [8]b;
        var c = counter;
        for (var i = 7; i >= 0; i--) {
            msg[i] = (c & 0xFF).toNumber();
            c = c >> 8;
        }

        var h = hmacSha1(key, msg);

        // dynamic truncation (RFC 4226 §5.3)
        var o = h[h.size() - 1] & 0x0F;
        var bin = ((h[o] & 0x7F) << 24) | (h[o + 1] << 16) | (h[o + 2] << 8) | h[o + 3];

        var mod = 1;
        for (var i = 0; i < digits; i++) {
            mod *= 10;
        }
        return (bin % mod).format("%0" + digits + "d");
    }

    // RFC 2104 HMAC built on Cryptography.Hash: the SDK's HashBasedMessageAuthenticationCode
    // rejects HASH_SHA1 (verified in simulator, SDK 9.1), while plain Hash supports it.
    function hmacSha1(key as ByteArray, msg as ByteArray) as ByteArray {
        var block = 64;
        var k = key;
        if (k.size() > block) {
            k = sha1(k);
        }
        var ipad = new [block]b;
        var opad = new [block]b;
        for (var i = 0; i < block; i++) {
            var b = i < k.size() ? k[i] : 0;
            ipad[i] = b ^ 0x36;
            opad[i] = b ^ 0x5C;
        }
        return sha1(opad.addAll(sha1(ipad.addAll(msg))));
    }

    function sha1(data as ByteArray) as ByteArray {
        var h = new Cryptography.Hash({:algorithm => Cryptography.HASH_SHA1});
        h.update(data);
        return h.digest();
    }

    function secondsRemaining(unixTime as Number or Long, step as Number) as Number {
        return (step - (unixTime.toLong() % step)).toNumber();
    }
}
