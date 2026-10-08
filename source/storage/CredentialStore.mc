import Toybox.Application;
import Toybox.Lang;

// Connect IQ offers no secure enclave / keystore API. Application.Storage is app-private,
// on-watch storage and is the best available option. See README "Security model".
//
// Flow: user types id + secret into Garmin Connect app settings (Application.Properties).
// On the next start / settings change the secret is validated, moved to Storage and the
// property is blanked so it is not shown again and syncs back to the phone as empty.
module CredentialStore {
    const PROP_USER = "userId";
    const PROP_SECRET = "secret";
    const KEY_USER = "u";
    const KEY_SECRET = "s";
    const KEY_INVALID = "bad";

    // Returns :none, :imported or :invalid. Never logs values.
    function importFromSettings() as Symbol {
        var propId = readProp(PROP_USER);
        var propSecret = readProp(PROP_SECRET);

        if (propSecret.length() == 0) {
            // Only the id changed (or nothing). Re-validate against the stored secret.
            var storedSecret = Application.Storage.getValue(KEY_SECRET);
            if (propId.length() == 0 || storedSecret == null) {
                return :none;
            }
            if (propId.equals(Application.Storage.getValue(KEY_USER))) {
                return :none;
            }
            return save(propId, storedSecret as String);
        }

        var result = save(propId.length() > 0 ? propId : Application.Storage.getValue(KEY_USER), propSecret);
        // Never leave the secret in Properties, valid or not.
        Application.Properties.setValue(PROP_SECRET, "");
        return result;
    }

    function save(userId as String or Null, secretHex as String) as Symbol {
        var creds = ZappkaCredentials.parse(userId, secretHex);
        if (creds == null) {
            Application.Storage.setValue(KEY_INVALID, true);
            return :invalid;
        }
        Application.Storage.setValue(KEY_USER, creds.userId);
        Application.Storage.setValue(KEY_SECRET, ZappkaCredentials.trim(secretHex).toLower());
        Application.Storage.deleteValue(KEY_INVALID);
        return :imported;
    }

    // :ok with credentials, :missing or :invalid
    function load() as [Symbol, ZappkaCredentials or Null] {
        if (Application.Storage.getValue(KEY_INVALID) == true) {
            return [:invalid, null];
        }
        var id = Application.Storage.getValue(KEY_USER);
        var secret = Application.Storage.getValue(KEY_SECRET);
        if (id == null || secret == null) {
            return [:missing, null];
        }
        var creds = ZappkaCredentials.parse(id as String, secret as String);
        return creds == null ? [:invalid, null] : [:ok, creds];
    }

    function clear() as Void {
        Application.Storage.deleteValue(KEY_USER);
        Application.Storage.deleteValue(KEY_SECRET);
        Application.Storage.deleteValue(KEY_INVALID);
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
