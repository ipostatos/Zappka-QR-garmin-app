import Toybox.Application;
import Toybox.Lang;

// User preferences set from the on-watch menu, and the last time the phone was seen.
// Not credentials.
module Prefs {
    const KEY_VIBRATE = "vib";
    const KEY_AUTO_EXIT = "ax";
    const KEY_LAST_PHONE = "lp";

    const AUTO_EXIT_CHOICES = [60, 180, 300];   // seconds; menu cycles through them
    const AUTO_EXIT_DEFAULT = 180;
    const PHONE_STALE_SECONDS = 86400;          // 24 h without the phone: the clock may drift
    const PHONE_MARK_EVERY = 60;                // write at most once a minute

    // Buzz when a new code appears. Default: on.
    function vibrateOnRotate() as Boolean {
        return Application.Storage.getValue(KEY_VIBRATE) != false;
    }

    function setVibrateOnRotate(on as Boolean) as Void {
        Application.Storage.setValue(KEY_VIBRATE, on);
    }

    // Seconds before the app closes itself outside checkout mode.
    function autoExitSeconds() as Number {
        var v = Application.Storage.getValue(KEY_AUTO_EXIT);
        for (var i = 0; i < AUTO_EXIT_CHOICES.size(); i++) {
            if (v == AUTO_EXIT_CHOICES[i]) {
                return v as Number;
            }
        }
        return AUTO_EXIT_DEFAULT;
    }

    // Next choice after the current one (1 -> 3 -> 5 -> 1 min). Returns the new value.
    function cycleAutoExit() as Number {
        var cur = autoExitSeconds();
        var next = AUTO_EXIT_CHOICES[0];
        for (var i = 0; i < AUTO_EXIT_CHOICES.size(); i++) {
            if (AUTO_EXIT_CHOICES[i] == cur) {
                next = AUTO_EXIT_CHOICES[(i + 1) % AUTO_EXIT_CHOICES.size()];
            }
        }
        Application.Storage.setValue(KEY_AUTO_EXIT, next);
        return next as Number;
    }

    function autoExitLabel(seconds as Number) as String {
        return (seconds / 60) + " min";
    }

    // Called while the app is open. The watch takes its time from the phone, so "phone seen
    // recently" is a good proxy for "clock is right".
    function notePhone(connected as Boolean, now as Number) as Void {
        if (!connected) {
            return;
        }
        var last = lastPhoneSeen();
        if (last == null || now < (last as Number) || now - (last as Number) >= PHONE_MARK_EVERY) {
            Application.Storage.setValue(KEY_LAST_PHONE, now);
        }
    }

    function lastPhoneSeen() as Number or Null {
        var v = Application.Storage.getValue(KEY_LAST_PHONE);
        return v instanceof Number ? v as Number : null;
    }

    // True when the phone was seen before, but not for 24 h. Unknown is not stale.
    function phoneStale(now as Number) as Boolean {
        var last = lastPhoneSeen();
        // Backward time jumps must also warn; otherwise a stale future timestamp hides drift.
        return last != null && (now < (last as Number) || now - (last as Number) > PHONE_STALE_SECONDS);
    }

    // "now", "5 h ago", "3 d ago", or "never".
    function phoneAgo(now as Number) as String {
        var last = lastPhoneSeen();
        if (last == null) {
            return "never";
        }
        var d = now - (last as Number);
        if (d < 0) {
            return "clock?";
        }
        if (d < 3600) {
            return "now";
        }
        if (d < 2 * 86400) {
            return (d / 3600) + " h ago";
        }
        return (d / 86400) + " d ago";
    }
}
