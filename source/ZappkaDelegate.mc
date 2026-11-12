import Toybox.Lang;
import Toybox.WatchUi;

// BACK = exit (default behaviour). MENU = menu. START/SELECT = checkout mode on/off.
class ZappkaDelegate extends WatchUi.BehaviorDelegate {
    private var _view as ZappkaView;

    function initialize(view as ZappkaView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.toggleCheckout();
        return true;
    }

    function onMenu() as Boolean {
        ZappkaMenu.open(_view);
        return true;
    }
}
