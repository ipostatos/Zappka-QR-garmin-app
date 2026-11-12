import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

// Auto-exit choice, phone-seen tracking (clock drift hint) and the countdown text width.

(:test)
function autoExitDefaultsAndCycles(logger as Logger) as Boolean {
    Application.Storage.deleteValue(Prefs.KEY_AUTO_EXIT);
    Test.assertEqual(Prefs.autoExitSeconds(), 180);
    Test.assertEqual(Prefs.cycleAutoExit(), 300);
    Test.assertEqual(Prefs.cycleAutoExit(), 60);
    Test.assertEqual(Prefs.cycleAutoExit(), 180);
    Application.Storage.setValue(Prefs.KEY_AUTO_EXIT, 7);   // unknown value -> default
    Test.assertEqual(Prefs.autoExitSeconds(), 180);
    Test.assertEqual(Prefs.autoExitLabel(300), "5 min");
    Application.Storage.deleteValue(Prefs.KEY_AUTO_EXIT);
    return true;
}

(:test)
function phoneStaleAfterADay(logger as Logger) as Boolean {
    Application.Storage.deleteValue(Prefs.KEY_LAST_PHONE);
    var t = 2000000000;
    Test.assert(!Prefs.phoneStale(t));                  // never seen: unknown, not stale
    Test.assertEqual(Prefs.phoneAgo(t), "never");
    Prefs.notePhone(false, t);                          // disconnected: nothing recorded
    Test.assert(Prefs.lastPhoneSeen() == null);
    Prefs.notePhone(true, t);
    Test.assertEqual(Prefs.phoneAgo(t + 60), "now");
    Test.assertEqual(Prefs.phoneAgo(t + 5 * 3600), "5 h ago");
    Test.assert(!Prefs.phoneStale(t + 86400));
    Test.assert(Prefs.phoneStale(t + 86401));
    Test.assertEqual(Prefs.phoneAgo(t + 3 * 86400), "3 d ago");
    Test.assert(Prefs.phoneStale(t - 3600));
    Test.assertEqual(Prefs.phoneAgo(t - 3600), "clock?");
    Prefs.notePhone(true, t + 30);                      // within a minute: no write
    Test.assertEqual(Prefs.lastPhoneSeen(), t);
    Prefs.notePhone(true, t - 3600);
    Test.assertEqual(Prefs.lastPhoneSeen(), t - 3600);
    Test.assert(!Prefs.phoneStale(t - 3600));
    Application.Storage.deleteValue(Prefs.KEY_LAST_PHONE);
    return true;
}

(:test)
function countdownWithSyncHintFits(logger as Logger) as Boolean {
    var ds = System.getDeviceSettings();
    var w = ds.screenWidth;
    var h = ds.screenHeight;
    var sub = TextScreen.subscreen();
    if (sub != null) {
        return true;   // subscreen devices show only "18!" inside the subscreen
    }
    var l = QrRenderer.computeLayout(w, h, ds.screenShape, null, 33) as QrLayout;
    var dc = (Graphics.createBufferedBitmap({:width => w, :height => h}).get() as Graphics.BufferedBitmap).getDc();
    var text = "> 28 s <  sync?";
    var dims = dc.getTextDimensions(text, Graphics.FONT_TINY);
    var x = l.x + l.side / 2 - dims[0] / 2;
    if (!QrRenderer.fits(w, h, ds.screenShape, null, x, l.textY, dims[0], dims[1])) {
        logger.error("countdown '" + text + "' w=" + dims[0] + " at y=" + l.textY + " does not fit");
        return false;
    }
    return true;
}
