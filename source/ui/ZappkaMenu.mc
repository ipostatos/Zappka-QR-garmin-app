import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// MENU button: checkout mode, buzz on new code, status, sign out, about.
module ZappkaMenu {
    function aboutText() as String {
        return "Zappka QR v" + ZappkaProtocol.APP_VERSION + "\n" +
            (WatchUi.loadResource(Rez.Strings.AboutBody) as String);
    }

    function open(view as ZappkaView) as Void {
        var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.MenuTitle) as String});
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuCheckout, Rez.Strings.MenuCheckoutSub,
            :checkout, view.isCheckout(), null));
        menu.addItem(new WatchUi.ToggleMenuItem(Rez.Strings.MenuVibrate, Rez.Strings.MenuVibrateSub,
            :vibrate, Prefs.vibrateOnRotate(), null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuAutoExit, Prefs.autoExitLabel(Prefs.autoExitSeconds()),
            :autoexit, null));
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuStatus, Rez.Strings.MenuStatusSub, :status, null));
        var creds = CredentialStore.load()[1];
        if (creds != null) {
            menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuSignOut,
                "ID " + (creds as ZappkaCredentials).maskedUserId(), :signout, null));
        }
        menu.addItem(new WatchUi.MenuItem(Rez.Strings.MenuAbout, "v" + ZappkaProtocol.APP_VERSION, :about, null));
        WatchUi.pushView(menu, new ZappkaMenuDelegate(view, menu), WatchUi.SLIDE_UP);
    }
}

class ZappkaMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _view as ZappkaView;
    private var _menu as WatchUi.Menu2;

    function initialize(view as ZappkaView, menu as WatchUi.Menu2) {
        Menu2InputDelegate.initialize();
        _view = view;
        _menu = menu;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :checkout) {
            _view.setCheckout((item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :vibrate) {
            Prefs.setVibrateOnRotate((item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :autoexit) {
            item.setSubLabel(Prefs.autoExitLabel(Prefs.cycleAutoExit()));
            WatchUi.requestUpdate();
        } else if (id == :status) {
            WatchUi.pushView(new ZappkaInfoView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :about) {
            WatchUi.pushView(new ZappkaAboutView(), new WatchUi.BehaviorDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :signout) {
            WatchUi.pushView(new WatchUi.Confirmation(WatchUi.loadResource(Rez.Strings.SignOutConfirm) as String),
                new ZappkaSignOutDelegate(_view, _menu), WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

// The Confirmation closes itself; the menu stays open without the sign-out item.
class ZappkaSignOutDelegate extends WatchUi.ConfirmationDelegate {
    private var _view as ZappkaView;
    private var _menu as WatchUi.Menu2;

    function initialize(view as ZappkaView, menu as WatchUi.Menu2) {
        ConfirmationDelegate.initialize();
        _view = view;
        _menu = menu;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            CredentialStore.signOut();
            _view.reload();
            var i = _menu.findItemById(:signout);
            if (i >= 0) {
                _menu.deleteItem(i);
            }
        }
        return true;
    }
}

// Confirmation of a staged one-field account change. YES applies it, NO or BACK keeps the
// working pair and puts the settings ID back.
class ZappkaStagedDelegate extends WatchUi.ConfirmationDelegate {
    private var _view as ZappkaView;

    function initialize(view as ZappkaView) {
        ConfirmationDelegate.initialize();
        _view = view;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            CredentialStore.applyStaged();
        } else {
            CredentialStore.discardStaged();
        }
        _view.reload();
        return true;
    }
}

// About: name, version, license, disclaimer, source.
class ZappkaAboutView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        TextScreen.draw(dc, ZappkaMenu.aboutText());
    }
}
