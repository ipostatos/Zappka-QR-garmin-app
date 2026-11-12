import Toybox.Graphics;
import Toybox.Lang;

// Draws the seconds left for the current OTP. Never touches the QR area.
module CountdownRenderer {
    // In the Instinct subscreen: just the number, inverted in the safety window; "!" when the
    // phone (the clock source) has not been seen for a day.
    function drawInSubscreen(dc as Graphics.Dc, sub as Graphics.BoundingBox, remaining as Number, checkout as Boolean,
                             stale as Boolean) as Void {
        var cx = sub.x + sub.width / 2;
        var cy = sub.y + sub.height / 2;
        var r = (sub.width < sub.height ? sub.width : sub.height) / 2;
        var urgent = remaining <= ZappkaProtocol.SAFETY_WINDOW;
        dc.setColor(urgent ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(urgent ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, checkout ? Graphics.FONT_LARGE : Graphics.FONT_MEDIUM, remaining.toString() + (stale ? "!" : ""),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Under the QR quiet zone: "18 s"; checkout mode adds a marker and a larger font; "sync?" when
    // the phone (the clock source) has not been seen for a day.
    function drawBelow(dc as Graphics.Dc, cx as Number, y as Number, remaining as Number, checkout as Boolean,
                       stale as Boolean) as Void {
        var text = checkout ? "> " + remaining.toString() + " s <" : remaining.toString() + " s";
        if (stale) {
            text += "  sync?";
        }
        var font = checkout ? Graphics.FONT_TINY : Graphics.FONT_XTINY;
        if (remaining <= ZappkaProtocol.SAFETY_WINDOW) {
            var dims = dc.getTextDimensions(text, font);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - dims[0] / 2 - 4, y, dims[0] + 8, dims[1]);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(cx, y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
