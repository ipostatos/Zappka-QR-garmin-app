import Toybox.Application;
import Toybox.Lang;

// User preferences set from the on-watch menu. Not credentials.
module Prefs {
    const KEY_VIBRATE = "vib";

    // Buzz when a new code appears. Default: on.
    function vibrateOnRotate() as Boolean {
        return Application.Storage.getValue(KEY_VIBRATE) != false;
    }

    function setVibrateOnRotate(on as Boolean) as Void {
        Application.Storage.setValue(KEY_VIBRATE, on);
    }
}
