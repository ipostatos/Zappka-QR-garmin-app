import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// Glance: title + seconds left in the current code. Touches no credentials (glance memory is
// small and runs outside the main app), so it never shows or loads the secret.
(:glance)
class ZappkaGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var step = ZappkaProtocol.TIME_STEP;
        var left = step - Time.now().value() % step;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, dc.getHeight() / 2, Graphics.FONT_GLANCE, "ZAPPKA QR  " + left + "s",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
