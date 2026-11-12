import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

// Every line of the About and Status screens fits the visible screen of the device under test
// (circle or Instinct octagon) and stays clear of the subscreen. Measured with the real font.

// helper, not a test (a (:test) annotation would make the runner call it)
function textFitsScreen(text as String, logger as Logger) as Boolean {
    var ds = System.getDeviceSettings();
    var w = ds.screenWidth;
    var h = ds.screenHeight;
    var ref = Graphics.createBufferedBitmap({:width => w, :height => h});
    var dc = (ref.get() as Graphics.BufferedBitmap).getDc();
    var sub = TextScreen.subscreen();
    var cy = TextScreen.centerY(h, sub, TextScreen.lineCount(text));
    var fh = Graphics.getFontHeight(TextScreen.FONT);
    var lines = [] as Array<String>;
    var rest = text;
    var i = rest.find("\n");
    while (i != null) {
        lines.add(rest.substring(0, i) as String);
        rest = rest.substring(i + 1, rest.length()) as String;
        i = rest.find("\n");
    }
    lines.add(rest);
    var top = cy - lines.size() * fh / 2;
    for (var k = 0; k < lines.size(); k++) {
        var lw = dc.getTextWidthInPixels(lines[k], TextScreen.FONT);
        if (lw == 0) {
            continue;
        }
        var x1 = (w - lw) / 2;
        var x2 = x1 + lw - 1;
        var y1 = top + k * fh;
        var y2 = y1 + fh - 1;
        if (!QrRenderer.fits(w, h, ds.screenShape, sub, x1, y1, lw, fh)) {
            logger.error("line '" + lines[k] + "' w=" + lw + " at y=" + y1 + ".." + y2 + " does not fit " + w + "x" + h);
            return false;
        }
    }
    return true;
}

(:test)
function aboutScreenFits(logger as Logger) as Boolean {
    return textFitsScreen(ZappkaMenu.aboutText(), logger);
}

(:test)
function statusScreenFitsWithAccount(logger as Logger) as Boolean {
    var c = ZappkaCredentials.parse(EXAMPLE_ID, EXAMPLE_SECRET);
    return textFitsScreen(ZappkaInfoView.statusText(c, 2000000000), logger);
}

(:test)
function statusScreenFitsWithoutAccount(logger as Logger) as Boolean {
    return textFitsScreen(ZappkaInfoView.statusText(null, 2000000000), logger);
}

(:test)
function messageScreensFit(logger as Logger) as Boolean {
    var ids = [Rez.Strings.SetupRequired, Rez.Strings.NeedUserId, Rez.Strings.InvalidConfig,
               Rez.Strings.QrFailed, Rez.Strings.SecretRejected];
    for (var i = 0; i < ids.size(); i++) {
        if (!textFitsScreen(WatchUi.loadResource(ids[i]) as String, logger)) {
            return false;
        }
    }
    return true;
}

// Polish screens (the runner loads English resources only). Mirrors resources-pol/strings.xml.
(:test)
const PL_SCREENS = [
        "Brak konta\nDodaj konto w\nGarmin Connect",
        "Błędne konto\nSprawdź ID\ni sekret",
        "Nie można\nwygenerować QR",
        "Sekret zapisany\nTeraz dodaj\nID użytkownika",
        "Nowy sekret\nodrzucony\nStare konto działa",
        "Zappka QR v1.1.0\nLicencja MIT\nNieoficjalna,\nnie od Zabki",
        "Wylogować i usunąć\nkonto z tego\nzegarka?"
];

(:test)
function polishScreensFit(logger as Logger) as Boolean {
    for (var i = 0; i < PL_SCREENS.size(); i++) {
        if (!textFitsScreen(PL_SCREENS[i], logger)) {
            return false;
        }
    }
    return true;
}
