import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Black-on-white text screens (About, Status). On screens with a subscreen (Instinct Solar)
// the text block starts below the subscreen ring; elsewhere it is centred.
module TextScreen {
    const FONT = Graphics.FONT_XTINY;
    const SUB_GAP = 10;   // px between the subscreen box and the first line

    function lineCount(text as String) as Number {
        var n = 1;
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            if (chars[i] == '\n') {
                n++;
            }
        }
        return n;
    }

    // Vertical centre of the text block. Shared with the layout tests.
    function centerY(h as Number, sub as Graphics.BoundingBox or Null, lines as Number) as Number {
        var block = lines * Graphics.getFontHeight(FONT);
        var cy = h / 2;
        if (sub != null) {
            var minCy = sub.y + sub.height + SUB_GAP + block / 2;
            if (cy < minCy) {
                cy = minCy;
            }
        }
        return cy;
    }

    function subscreen() as Graphics.BoundingBox or Null {
        return (WatchUi has :getSubscreen) ? WatchUi.getSubscreen() : null;
    }

    function draw(dc as Graphics.Dc, text as String) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        var cy = centerY(dc.getHeight(), subscreen(), lineCount(text));
        dc.drawText(dc.getWidth() / 2, cy, FONT, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
