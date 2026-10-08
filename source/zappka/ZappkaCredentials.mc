import Toybox.Lang;

// Validated account data. Never expose `secret` via toString / logs.
class ZappkaCredentials {
    var userId as String;
    var secret as ByteArray;

    function initialize(id as String, key as ByteArray) {
        userId = id;
        secret = key;
    }

    // Returns null when the pair does not match the observed formats.
    static function parse(userId as String or Null, secretHex as String or Null) as ZappkaCredentials or Null {
        if (userId == null || secretHex == null) {
            return null;
        }
        var id = trim(userId);
        if (!isValidUserId(id)) {
            return null;
        }
        var key = Hex.decode(trim(secretHex));
        if (key == null || key.size() < ZappkaProtocol.SECRET_MIN_BYTES || key.size() > ZappkaProtocol.SECRET_MAX_BYTES) {
            return null;
        }
        return new ZappkaCredentials(id, key);
    }

    static function isValidUserId(id as String) as Boolean {
        var n = id.length();
        if (n < ZappkaProtocol.USER_ID_MIN_LEN || n > ZappkaProtocol.USER_ID_MAX_LEN) {
            return false;
        }
        var chars = id.toCharArray();
        for (var i = 0; i < n; i++) {
            var v = chars[i].toNumber();
            if (v < 48 || v > 57) {
                return false;
            }
        }
        return true;
    }

    static function trim(s as String) as String {
        var chars = s.toCharArray();
        var a = 0;
        var b = chars.size();
        while (a < b && chars[a].toNumber() <= 32) {
            a++;
        }
        while (b > a && chars[b - 1].toNumber() <= 32) {
            b--;
        }
        return s.substring(a, b) as String;
    }

    // Safe for display/logs: last 4 digits of the id only.
    function maskedUserId() as String {
        var n = userId.length();
        return n <= 4 ? "****" : "****" + userId.substring(n - 4, n);
    }

    function toString() as String {
        return "ZappkaCredentials(secret_present=true, secret_length=" + secret.size() + ")";
    }
}
