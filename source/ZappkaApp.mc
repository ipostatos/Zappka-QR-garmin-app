import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ZappkaApp extends Application.AppBase {
    private var _view as ZappkaView or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    // onStart also runs for the glance, where credential code is not loaded: import in getInitialView.
    function onStart(state as Dictionary?) as Void {
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        CredentialStore.importFromSettings();
        var view = new ZappkaView();
        _view = view;
        return [view, new ZappkaDelegate(view)];
    }

    // Glance in the widget loop: one press from the watch face opens the QR.
    // :glanceentry lets screenshot.jungle drop the glance so the simulator opens the QR view directly.
    (:glance :glanceentry)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new ZappkaGlanceView()];
    }

    function onSettingsChanged() as Void {
        CredentialStore.importFromSettings();
        if (_view != null) {
            (_view as ZappkaView).reload();
        }
        WatchUi.requestUpdate();
    }
}

function getApp() as ZappkaApp {
    return Application.getApp() as ZappkaApp;
}
