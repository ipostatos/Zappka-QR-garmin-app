import Toybox.Application;
import Toybox.Lang;

// Connect IQ offers no secure enclave / keystore API. Application.Storage is app-private,
// on-watch storage and is the best available option. See README "Security model".
//
// Flow: user types id + secret into Garmin Connect app settings (Application.Properties).
// On the next start / settings change the secret field is blanked FIRST (so it never syncs
// back to the phone), then the pair is validated and moved to Storage.
//
// Rules:
// - a working pair is never replaced by an invalid one; the rejection is reported once;
// - a secret entered before the id is kept as "pending" in Storage until the id arrives;
// - :invalid is only reported when there is no working pair at all.
module CredentialStore {
    const PROP_USER = "userId";
    const PROP_SECRET = "secret";
    const KEY_USER = "u";
    const KEY_SECRET = "s";
    const KEY_PENDING = "ps";     // secret waiting for an id
    const KEY_INVALID = "bad";    // last input invalid and no working pair exists
    const KEY_REJECTED = "rej";   // last input invalid, previous working pair kept

    // Returns :none, :imported, :pending, :rejected or :invalid. Never logs values.
    function importFromSettings() as Symbol {
        var propId = readProp(PROP_USER);
        var propSecret = readProp(PROP_SECRET);

        if (propSecret.length() > 0) {
            blankSecretProp();
        }

        var storedId = Application.Storage.getValue(KEY_USER);
        var storedSecret = Application.Storage.getValue(KEY_SECRET);
        var pending = Application.Storage.getValue(KEY_PENDING);

        var newSecret = propSecret.length() > 0 ? propSecret : (pending instanceof String ? pending : null);
        var id = propId.length() > 0 ? propId : (storedId instanceof String ? storedId : null);

        if (newSecret == null) {
            // Only the id changed (or nothing). Re-validate it against the stored secret.
            if (propId.length() == 0 || storedSecret == null || propId.equals(storedId)) {
                return :none;
            }
            return save(propId, storedSecret as String);
        }

        if (id == null) {
            if (Hex.decode(ZappkaCredentials.trim(newSecret)) == null) {
                return reject();
            }
            Application.Storage.setValue(KEY_PENDING, ZappkaCredentials.trim(newSecret).toLower());
            return :pending;
        }
        return save(id, newSecret);
    }

    function save(userId as String or Null, secretHex as String) as Symbol {
        var creds = ZappkaCredentials.parse(userId, secretHex);
        if (creds == null) {
            return reject();
        }
        Application.Storage.setValue(KEY_USER, creds.userId);
        Application.Storage.setValue(KEY_SECRET, ZappkaCredentials.trim(secretHex).toLower());
        Application.Storage.deleteValue(KEY_PENDING);
        Application.Storage.deleteValue(KEY_INVALID);
        Application.Storage.deleteValue(KEY_REJECTED);
        return :imported;
    }

    // Invalid input: keep a working pair if there is one, otherwise report :invalid.
    function reject() as Symbol {
        Application.Storage.deleteValue(KEY_PENDING);
        if (load()[0] == :ok) {
            Application.Storage.setValue(KEY_REJECTED, true);
            return :rejected;
        }
        Application.Storage.setValue(KEY_INVALID, true);
        return :invalid;
    }

    // :ok with credentials, :missing, :pending or :invalid
    function load() as [Symbol, ZappkaCredentials or Null] {
        var id = Application.Storage.getValue(KEY_USER);
        var secret = Application.Storage.getValue(KEY_SECRET);
        if (id != null && secret != null) {
            var creds = ZappkaCredentials.parse(id as String, secret as String);
            if (creds != null) {
                return [:ok, creds];
            }
            return [:invalid, null];
        }
        if (Application.Storage.getValue(KEY_INVALID) == true) {
            return [:invalid, null];
        }
        if (Application.Storage.getValue(KEY_PENDING) != null) {
            return [:pending, null];
        }
        return [:missing, null];
    }

    // True once after an invalid new secret was ignored in favour of the working pair.
    function consumeRejected() as Boolean {
        if (Application.Storage.getValue(KEY_REJECTED) == true) {
            Application.Storage.deleteValue(KEY_REJECTED);
            return true;
        }
        return false;
    }

    function clear() as Void {
        Application.Storage.deleteValue(KEY_USER);
        Application.Storage.deleteValue(KEY_SECRET);
        Application.Storage.deleteValue(KEY_PENDING);
        Application.Storage.deleteValue(KEY_INVALID);
        Application.Storage.deleteValue(KEY_REJECTED);
    }

    // Never leave the secret in Properties. Retried once; failure must not abort the import.
    function blankSecretProp() as Void {
        try {
            Application.Properties.setValue(PROP_SECRET, "");
        } catch (e) {
            try {
                Application.Properties.setValue(PROP_SECRET, "");
            } catch (e2) {
            }
        }
    }

    function readProp(key as String) as String {
        var v = null;
        try {
            v = Application.Properties.getValue(key);
        } catch (e) {
            v = null;
        }
        return v instanceof String ? ZappkaCredentials.trim(v) : "";
    }
}
