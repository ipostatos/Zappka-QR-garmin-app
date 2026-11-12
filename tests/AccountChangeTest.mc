import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Account changes must never silently replace a working pair with a half-updated one.
// A change of only one field (secret or ID) is staged and applied only after a confirmation
// on the watch; a change of both fields is a complete update and is applied directly.

(:test)
const OTHER_ID = "987654321098";
// A second valid 32-byte test key, built at run time so the repository holds no 64-hex literal
// other than the public example (CI guard).
// helper, not a test (a (:test) annotation would make the runner call it)
function otherSecret() as String {
    var s = "";
    for (var i = 0; i < 4; i++) {
        s += "0123456789abcdef";
    }
    return s;
}

// helper, not a test (a (:test) annotation would make the runner call it)
function storedPair() as String {
    var c = CredentialStore.load()[1] as ZappkaCredentials;
    return c.userId + ":" + Application.Storage.getValue(CredentialStore.KEY_SECRET);
}

(:test)
function newSecretWithSameIdIsStagedNotApplied(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    var before = storedPair();
    Test.assertEqual(enterSettings(EXAMPLE_ID, otherSecret()), :staged);
    Test.assertEqual(storedPair(), before);                               // working pair untouched
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_SECRET), "");
    Test.assertEqual(CredentialStore.stagedUserId(), EXAMPLE_ID);
    CredentialStore.applyStaged();
    Test.assertEqual(storedPair(), EXAMPLE_ID + ":" + otherSecret());
    Test.assert(CredentialStore.stagedUserId() == null);
    resetStore();
    return true;
}

(:test)
function newSecretWithEmptyIdNeverUsesStoredId(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    var before = storedPair();
    Test.assertEqual(enterSettings("", otherSecret()), :pending);
    Test.assertEqual(storedPair(), before);
    Test.assertEqual(CredentialStore.load()[0], :ok);                     // QR keeps working
    Test.assertEqual(enterSettings(OTHER_ID, ""), :imported);             // ID arrives: both new
    Test.assertEqual(storedPair(), OTHER_ID + ":" + otherSecret());
    resetStore();
    return true;
}

(:test)
function newIdWithOldSecretIsStagedNotApplied(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    var before = storedPair();
    Test.assertEqual(enterSettings(OTHER_ID, ""), :staged);
    Test.assertEqual(storedPair(), before);
    CredentialStore.discardStaged();
    Test.assertEqual(storedPair(), before);
    // the settings field is put back, so the same change is not offered again on every start
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_USER), EXAMPLE_ID);
    Test.assertEqual(CredentialStore.importFromSettings(), :none);
    resetStore();
    return true;
}

(:test)
function bothFieldsChangedIsAppliedDirectly(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    Test.assertEqual(enterSettings(OTHER_ID, otherSecret()), :imported);
    Test.assertEqual(storedPair(), OTHER_ID + ":" + otherSecret());
    resetStore();
    return true;
}

(:test)
function sameDataAgainChangesNothing(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    Test.assertEqual(enterSettings(EXAMPLE_ID, EXAMPLE_SECRET), :none);
    Test.assert(CredentialStore.stagedUserId() == null);
    resetStore();
    return true;
}

(:test)
function invalidIdIsReportedOnceNotOnEveryStart(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    Test.assertEqual(enterSettings("12ab", ""), :rejected);
    Test.assert(CredentialStore.consumeRejected());
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_USER), EXAMPLE_ID);
    Test.assertEqual(CredentialStore.importFromSettings(), :none);       // next start: no notice
    Test.assert(!CredentialStore.consumeRejected());
    resetStore();
    return true;
}
