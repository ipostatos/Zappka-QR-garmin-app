import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Only the public example credentials are used. Override the SDK boundary to exercise
// exceptions and silent write failures; never log exception messages or property values.
class FailingCredentialProperties extends CredentialProperties {
    var readFailure as String = "";
    var writeFailure as String = "";
    var ignoredWrite as String = "";
    var writesUntilSuccess as Number = 0;
    var secretWrites as Number = 0;
    var failReadback as Boolean = false;

    function initialize() {
        CredentialProperties.initialize();
    }

    function getValue(key as String) as Object or Null {
        if (key.equals(readFailure) ||
            (failReadback && key.equals(CredentialStore.PROP_SECRET) && secretWrites > 0)) {
            throw new Lang.Exception();
        }
        return Application.Properties.getValue(key);
    }

    function setValue(key as String, value as String) as Void {
        if (key.equals(CredentialStore.PROP_SECRET)) {
            secretWrites++;
        }
        if (key.equals(writeFailure) || writesUntilSuccess > 0) {
            writesUntilSuccess--;
            throw new Lang.Exception();
        }
        if (!key.equals(ignoredWrite)) {
            Application.Properties.setValue(key, value);
        }
    }
}

(:test)
function offlineProSignOutClearsCredentials(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    enterSettings(OTHER_ID, otherSecret()); // sign out also erases a staged replacement
    Test.assert(CredentialStore.signOut());
    Test.assertEqual(CredentialStore.load()[0], :missing);
    Test.assert(CredentialStore.stagedUserId() == null);
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_USER), "");
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_SECRET), "");
    Test.assertEqual(CredentialStore.importFromSettings(), :none);
    Test.assertEqual(enterSettings(OTHER_ID, otherSecret()), :imported);
    Test.assertEqual(storedPair(), OTHER_ID + ":" + otherSecret());
    resetStore();
    return true;
}

(:test)
function settingsWriteExceptionKeepsWorkingAccount(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    var before = storedPair();
    var fake = new FailingCredentialProperties();
    fake.writeFailure = CredentialStore.PROP_SECRET;
    CredentialStore.properties = fake;
    Test.assertEqual(enterSettings(OTHER_ID, otherSecret()), :clear_failed);
    Test.assertEqual(fake.secretWrites, 2);
    Test.assertEqual(storedPair(), before);
    Test.assert(CredentialStore.stagedUserId() == null);
    Test.assert(CredentialStore.consumeClearFailure());
    Test.assert(!CredentialStore.consumeClearFailure());
    resetStore();
    return true;
}

(:test)
function settingsSilentWriteFailureBlocksFirstImport(logger as Logger) as Boolean {
    resetStore();
    var fake = new FailingCredentialProperties();
    fake.ignoredWrite = CredentialStore.PROP_SECRET;
    CredentialStore.properties = fake;
    Test.assertEqual(enterSettings(EXAMPLE_ID, EXAMPLE_SECRET), :clear_failed);
    Test.assertEqual(CredentialStore.load()[0], :missing);
    Test.assertEqual(fake.secretWrites, 2);
    resetStore();
    return true;
}

(:test)
function settingsCleanupRetriesTransientFailure(logger as Logger) as Boolean {
    resetStore();
    var fake = new FailingCredentialProperties();
    fake.writesUntilSuccess = 1;
    CredentialStore.properties = fake;
    Test.assertEqual(enterSettings(EXAMPLE_ID, EXAMPLE_SECRET), :imported);
    Test.assertEqual(fake.secretWrites, 2);
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_SECRET), "");
    Test.assert(!CredentialStore.consumeClearFailure());
    resetStore();
    return true;
}

(:test)
function settingsReadbackFailureKeepsWorkingAccount(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    var before = storedPair();
    var fake = new FailingCredentialProperties();
    fake.failReadback = true;
    CredentialStore.properties = fake;
    Test.assertEqual(enterSettings(OTHER_ID, otherSecret()), :clear_failed);
    Test.assertEqual(storedPair(), before);
    Test.assert(CredentialStore.stagedUserId() == null);
    resetStore();
    return true;
}

(:test)
function unreadableSettingsAreNotEmptyInput(logger as Logger) as Boolean {
    var keys = [CredentialStore.PROP_USER, CredentialStore.PROP_SECRET];
    for (var i = 0; i < keys.size(); i++) {
        resetStore();
        enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
        var before = storedPair();
        var fake = new FailingCredentialProperties();
        fake.readFailure = keys[i];
        CredentialStore.properties = fake;
        Test.assertEqual(enterSettings(OTHER_ID, otherSecret()), :clear_failed);
        Test.assertEqual(storedPair(), before);
        Test.assert(CredentialStore.stagedUserId() == null);
        Test.assert(Application.Storage.getValue(CredentialStore.KEY_PENDING) == null);
    }
    resetStore();
    return true;
}

(:test)
function whitespaceSettingsAreStillCleared(logger as Logger) as Boolean {
    resetStore();
    Test.assertEqual(enterSettings("", "  \t  "), :none);
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_SECRET), "");
    resetStore();
    return true;
}

(:test)
function failedSignOutKeepsAccountAndCanRetry(logger as Logger) as Boolean {
    var keys = [CredentialStore.PROP_SECRET, CredentialStore.PROP_USER];
    for (var i = 0; i < keys.size(); i++) {
        for (var mode = 0; mode < 3; mode++) {
            resetStore();
            enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
            var before = storedPair();
            // A nonempty field makes a silent failed clear observable.
            Application.Properties.setValue(CredentialStore.PROP_SECRET, EXAMPLE_SECRET);
            var fake = new FailingCredentialProperties();
            if (mode == 0) { fake.writeFailure = keys[i]; }
            if (mode == 1) { fake.ignoredWrite = keys[i]; }
            if (mode == 2) { fake.readFailure = keys[i]; }
            CredentialStore.properties = fake;
            Test.assert(!CredentialStore.signOut());
            Test.assertEqual(storedPair(), before);
            Test.assert(CredentialStore.consumeClearFailure());
            CredentialStore.properties = new CredentialProperties();
            Test.assert(CredentialStore.signOut());
            Test.assertEqual(CredentialStore.load()[0], :missing);
        }
    }
    resetStore();
    return true;
}
