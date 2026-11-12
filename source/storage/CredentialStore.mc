import Toybox.Application;
import Toybox.Lang;

// Connect IQ offers no secure enclave / keystore API. Application.Storage is app-private,
// on-watch storage and is the best available option. See README "Security model".
//
// Flow: user types id + secret into Garmin Connect app settings (Application.Properties).
// On the next start / settings change the secret field is blanked and read back FIRST.
// This does not prove that Garmin Connect or cloud caches erased previous values.
//
// Rules for a watch that already has a working pair:
// - any changed field(s)          -> staged; applied only after a confirmation on the watch
//   (a half-updated account must never silently replace a working one);
// - a secret without an ID         -> kept as pending; never combined with the stored ID;
// - invalid input                  -> ignored, working pair kept, reported once.
// Without a working pair there is nothing to lose: a valid pair is applied directly.
module CredentialStore {
    const PROP_USER = "userId";
    const PROP_SECRET = "secret";
    const KEY_USER = "u";
    const KEY_SECRET = "s";
    const KEY_PENDING = "ps";      // secret waiting for an id
    const KEY_STAGED_USER = "su";  // account change waiting for confirmation on the watch
    const KEY_STAGED_SECRET = "ss";
    const KEY_INVALID = "bad";     // last input invalid and no working pair exists
    const KEY_REJECTED = "rej";    // last input invalid, previous working pair kept
    const KEY_CLEAR_FAILURE = "cf";  // secret could not be cleared from app settings

    var properties as CredentialProperties = new CredentialProperties();

    // Returns :none, :imported, :pending, :staged, :rejected, :invalid or :clear_failed.
    // Never logs credential values or exception contents.
    function importFromSettings() as Symbol {
        var propId = readProp(PROP_USER);
        var propSecret = readProp(PROP_SECRET);
        // Verify even an empty/whitespace field. Read failures must not look like empty input.
        var cleared = blankSecretProp();
        if (!cleared || propId == null || propSecret == null) {
            Application.Storage.setValue(KEY_CLEAR_FAILURE, true);
            return :clear_failed;
        }
        Application.Storage.deleteValue(KEY_CLEAR_FAILURE);

        var storedId = Application.Storage.getValue(KEY_USER);
        var storedSecret = Application.Storage.getValue(KEY_SECRET);
        var working = load()[0] == :ok;
        var pending = Application.Storage.getValue(KEY_PENDING);
        var newSecret = propSecret.length() > 0 ? normSecret(propSecret) :
            (pending instanceof String ? pending as String : null);

        if (newSecret == null) {
            // The secret field was already cleared when this pair was staged. An unchanged
            // settings callback/restart must not replace its secret with the working secret.
            if (propId.equals(stagedUserId())) {
                return :staged;
            }
            clearStaged();
            // Only the ID field (or nothing) changed.
            if (propId.length() == 0 || propId.equals(storedId)) {
                return :none;
            }
            if (!working) {
                return storedSecret == null ? :none : save(propId, storedSecret as String);
            }
            return stageOrReject(propId, storedSecret as String);
        }

        if (propId.length() == 0) {
            clearStaged();
            // Never pair a new secret with the stored ID: wait for the ID.
            if (Hex.decode(newSecret) == null) {
                return reject();
            }
            Application.Storage.setValue(KEY_PENDING, newSecret);
            return :pending;
        }

        if (!working) {
            return save(propId, newSecret);
        }
        var idChanged = !propId.equals(storedId);
        var secretChanged = !newSecret.equals(storedSecret);
        if (!idChanged && !secretChanged) {
            clearStaged();
            Application.Storage.deleteValue(KEY_PENDING);
            return :none;
        }
        // Confirmation is required for every change to a working account,
        // including both fields changed together.
        return stageOrReject(propId, newSecret);
    }

    function stageOrReject(userId as String, secretHex as String) as Symbol {
        if (ZappkaCredentials.parse(userId, secretHex) == null) {
            return reject();
        }
        Application.Storage.deleteValue(KEY_PENDING);
        Application.Storage.setValue(KEY_STAGED_USER, userId);
        Application.Storage.setValue(KEY_STAGED_SECRET, secretHex);
        return :staged;
    }

    // ID of a staged account change, or null. The view asks the user to confirm it.
    function stagedUserId() as String or Null {
        var v = Application.Storage.getValue(KEY_STAGED_USER);
        return v instanceof String ? v as String : null;
    }

    function applyStaged() as Void {
        var id = stagedUserId();
        var secret = Application.Storage.getValue(KEY_STAGED_SECRET);
        if (id != null && secret instanceof String) {
            save(id, secret as String);  // save() clears staged data after validation
        } else {
            clearStaged();
        }
    }

    // Keep the working pair and put the settings ID back, so the change is not offered again.
    function discardStaged() as Void {
        clearStaged();
        restoreIdProp();
    }

    function save(userId as String or Null, secretHex as String) as Symbol {
        var creds = ZappkaCredentials.parse(userId, secretHex);
        if (creds == null) {
            return reject();
        }
        Application.Storage.setValue(KEY_USER, creds.userId);
        Application.Storage.setValue(KEY_SECRET, normSecret(secretHex));
        Application.Storage.deleteValue(KEY_PENDING);
        Application.Storage.deleteValue(KEY_INVALID);
        Application.Storage.deleteValue(KEY_REJECTED);
        clearStaged();
        return :imported;
    }

    // Invalid input: keep a working pair if there is one, otherwise report :invalid.
    function reject() as Symbol {
        clearStaged();
        Application.Storage.deleteValue(KEY_PENDING);
        if (load()[0] == :ok) {
            Application.Storage.setValue(KEY_REJECTED, true);
            restoreIdProp();   // otherwise the same bad ID is rejected again on every start
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

    // True once if an attempted secret-setting cleanup failed.
    function consumeClearFailure() as Boolean {
        if (Application.Storage.getValue(KEY_CLEAR_FAILURE) == true) {
            Application.Storage.deleteValue(KEY_CLEAR_FAILURE);
            return true;
        }
        return false;
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
        Application.Storage.deleteValue(KEY_CLEAR_FAILURE);
        clearStaged();
    }

    function clearStaged() as Void {
        Application.Storage.deleteValue(KEY_STAGED_USER);
        Application.Storage.deleteValue(KEY_STAGED_SECRET);
    }

    // Menu -> Sign out: forget the account on the watch and in the app settings.
    function signOut() as Boolean {
        // Do not forget a working account unless both settings are actually cleared.
        if (!blankSecretProp()) {
            Application.Storage.setValue(KEY_CLEAR_FAILURE, true);
            return false;
        }
        try {
            properties.setValue(PROP_USER, "");
            var clearedId = properties.getValue(PROP_USER);
            if (!(clearedId instanceof String) || !(clearedId as String).equals("")) {
                Application.Storage.setValue(KEY_CLEAR_FAILURE, true);
                return false;
            }
        } catch (e) {
            Application.Storage.setValue(KEY_CLEAR_FAILURE, true);
            return false;
        }
        clear();
        return true;
    }

    function restoreIdProp() as Void {
        var id = Application.Storage.getValue(KEY_USER);
        try {
            properties.setValue(PROP_USER, id instanceof String ? id : "");
        } catch (e) {
        }
    }

    function normSecret(s as String) as String {
        return ZappkaCredentials.trim(s).toLower();
    }

    // Verify the secret field is empty before accepting credentials or signing out.
    // Does not guarantee the phone/Garmin cloud discarded historical synced values.
    function blankSecretProp() as Boolean {
        for (var attempt = 0; attempt < 2; attempt++) {
            try {
                properties.setValue(PROP_SECRET, "");
                var cleared = properties.getValue(PROP_SECRET);
                if (cleared instanceof String && (cleared as String).equals("")) {
                    return true;
                }
            } catch (e) {
                // Retry once without logging exception contents.
            }
        }
        return false;
    }

    function readProp(key as String) as String or Null {
        var v = null;
        try {
            v = properties.getValue(key);
        } catch (e) {
            v = null;
        }
        return v instanceof String ? ZappkaCredentials.trim(v) : null;
    }
}
