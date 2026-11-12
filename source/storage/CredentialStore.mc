import Toybox.Application;
import Toybox.Lang;

// Connect IQ offers no secure enclave / keystore API. Application.Storage is app-private,
// on-watch storage and is the best available option. See README "Security model".
//
// Flow: user types id + secret into Garmin Connect app settings (Application.Properties).
// On the next start / settings change the secret field is blanked FIRST (so it never syncs
// back to the phone), then the input is checked against the stored pair.
//
// Rules for a watch that already has a working pair:
// - both fields changed            -> complete update, applied;
// - only the secret or only the ID -> staged; applied only after a confirmation on the watch
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
    const KEY_STAGED_USER = "su";  // one-field change waiting for confirmation on the watch
    const KEY_STAGED_SECRET = "ss";
    const KEY_INVALID = "bad";     // last input invalid and no working pair exists
    const KEY_REJECTED = "rej";    // last input invalid, previous working pair kept

    // Returns :none, :imported, :pending, :staged, :rejected or :invalid. Never logs values.
    function importFromSettings() as Symbol {
        var propId = readProp(PROP_USER);
        var propSecret = readProp(PROP_SECRET);
        if (propSecret.length() > 0) {
            blankSecretProp();
        }

        var storedId = Application.Storage.getValue(KEY_USER);
        var storedSecret = Application.Storage.getValue(KEY_SECRET);
        var working = load()[0] == :ok;
        var pending = Application.Storage.getValue(KEY_PENDING);
        var newSecret = propSecret.length() > 0 ? normSecret(propSecret) :
            (pending instanceof String ? pending as String : null);

        if (newSecret == null) {
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
            Application.Storage.deleteValue(KEY_PENDING);
            return :none;
        }
        if (idChanged && secretChanged) {
            return save(propId, newSecret);
        }
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

    // ID of a staged one-field change, or null. The view asks the user to confirm it.
    function stagedUserId() as String or Null {
        var v = Application.Storage.getValue(KEY_STAGED_USER);
        return v instanceof String ? v as String : null;
    }

    function applyStaged() as Void {
        var id = stagedUserId();
        var secret = Application.Storage.getValue(KEY_STAGED_SECRET);
        clearStaged();
        if (id != null && secret instanceof String) {
            save(id, secret as String);
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
        clearStaged();
    }

    function clearStaged() as Void {
        Application.Storage.deleteValue(KEY_STAGED_USER);
        Application.Storage.deleteValue(KEY_STAGED_SECRET);
    }

    // Menu -> Sign out: forget the account on the watch and in the app settings.
    function signOut() as Void {
        clear();
        try {
            Application.Properties.setValue(PROP_USER, "");
        } catch (e) {
        }
        blankSecretProp();
    }

    function restoreIdProp() as Void {
        var id = Application.Storage.getValue(KEY_USER);
        try {
            Application.Properties.setValue(PROP_USER, id instanceof String ? id : "");
        } catch (e) {
        }
    }

    function normSecret(s as String) as String {
        return ZappkaCredentials.trim(s).toLower();
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
