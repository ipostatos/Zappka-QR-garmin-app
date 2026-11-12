import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Settings import state machine (audit ZG-06/07). Uses the public example account only.

// helper, not a test (a (:test) annotation would make the runner call it)
function resetStore() as Void {
    CredentialStore.clear();
    Application.Properties.setValue(CredentialStore.PROP_USER, "");
    Application.Properties.setValue(CredentialStore.PROP_SECRET, "");
}

// helper, not a test (a (:test) annotation would make the runner call it)
function enterSettings(id as String, secret as String) as Symbol {
    Application.Properties.setValue(CredentialStore.PROP_USER, id);
    Application.Properties.setValue(CredentialStore.PROP_SECRET, secret);
    return CredentialStore.importFromSettings();
}

(:test)
function storeImportsPairAndBlanksSecret(logger as Logger) as Boolean {
    resetStore();
    Test.assertEqual(enterSettings(EXAMPLE_ID, EXAMPLE_SECRET), :imported);
    Test.assertEqual(CredentialStore.load()[0], :ok);
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_SECRET), "");
    Test.assertEqual(CredentialStore.importFromSettings(), :none);   // nothing changed
    resetStore();
    return true;
}

(:test)
function storeSecretBeforeIdIsKeptPending(logger as Logger) as Boolean {
    resetStore();
    Test.assertEqual(enterSettings("", EXAMPLE_SECRET), :pending);
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_SECRET), "");
    Test.assertEqual(CredentialStore.load()[0], :pending);
    Test.assertEqual(enterSettings(EXAMPLE_ID, ""), :imported);
    var r = CredentialStore.load();
    Test.assertEqual(r[0], :ok);
    Test.assertEqual((r[1] as ZappkaCredentials).userId, EXAMPLE_ID);
    resetStore();
    return true;
}

(:test)
function storeTypoKeepsWorkingPair(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    Test.assertEqual(enterSettings(EXAMPLE_ID, EXAMPLE_SECRET + "0"), :rejected);
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_SECRET), "");
    Test.assertEqual(CredentialStore.load()[0], :ok);
    Test.assert(CredentialStore.consumeRejected());
    Test.assert(!CredentialStore.consumeRejected());   // reported once
    resetStore();
    return true;
}

(:test)
function storeInvalidWithoutPairIsInvalid(logger as Logger) as Boolean {
    resetStore();
    Test.assertEqual(enterSettings(EXAMPLE_ID, "abcd"), :invalid);
    Test.assertEqual(CredentialStore.load()[0], :invalid);
    Test.assertEqual(enterSettings(EXAMPLE_ID, EXAMPLE_SECRET), :imported);   // recovers
    Test.assertEqual(CredentialStore.load()[0], :ok);
    resetStore();
    return true;
}

(:test)
function storeIdChangeRevalidatesStoredSecret(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    Test.assertEqual(enterSettings("987654321098", ""), :imported);
    Test.assertEqual((CredentialStore.load()[1] as ZappkaCredentials).userId, "987654321098");
    Test.assertEqual(enterSettings("12ab", ""), :rejected);   // bad id keeps the working pair
    Test.assertEqual((CredentialStore.load()[1] as ZappkaCredentials).userId, "987654321098");
    resetStore();
    return true;
}
