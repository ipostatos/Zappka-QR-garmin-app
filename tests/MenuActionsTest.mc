import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

// Menu actions that change stored state. Uses the public example account only.

(:test)
function signOutForgetsAccountEverywhere(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    Test.assertEqual(CredentialStore.load()[0], :ok);
    CredentialStore.signOut();
    Test.assertEqual(CredentialStore.load()[0], :missing);
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_USER), "");
    Test.assertEqual(Application.Properties.getValue(CredentialStore.PROP_SECRET), "");
    Test.assertEqual(CredentialStore.importFromSettings(), :none);   // nothing comes back on sync
    Test.assertEqual(CredentialStore.load()[0], :missing);
    resetStore();
    return true;
}

(:test)
function signOutThenNewAccountWorks(logger as Logger) as Boolean {
    resetStore();
    enterSettings(EXAMPLE_ID, EXAMPLE_SECRET);
    CredentialStore.signOut();
    Test.assertEqual(enterSettings("987654321098", EXAMPLE_SECRET), :imported);
    Test.assertEqual((CredentialStore.load()[1] as ZappkaCredentials).userId, "987654321098");
    resetStore();
    return true;
}

(:test)
function vibratePreferenceDefaultsOnAndPersists(logger as Logger) as Boolean {
    Application.Storage.deleteValue(Prefs.KEY_VIBRATE);
    Test.assert(Prefs.vibrateOnRotate());
    Prefs.setVibrateOnRotate(false);
    Test.assert(!Prefs.vibrateOnRotate());
    Prefs.setVibrateOnRotate(true);
    Test.assert(Prefs.vibrateOnRotate());
    Application.Storage.deleteValue(Prefs.KEY_VIBRATE);
    return true;
}

(:test)
function versionIsSemver(logger as Logger) as Boolean {
    var v = ZappkaProtocol.APP_VERSION;
    var dots = 0;
    var chars = v.toCharArray();
    for (var i = 0; i < chars.size(); i++) {
        var c = chars[i].toNumber();
        if (c == 46) {
            dots++;
        } else if (c < 48 || c > 57) {
            return false;
        }
    }
    Test.assertEqual(dots, 2);
    return true;
}
