import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

// Placement of the QR on the physical screen. Everything in integer pixels.
class QrLayout {
    var modulePx as Number;   // px per module (integer, never scaled)
    var quiet as Number;    // quiet-zone modules guaranteed visible + white
    var x as Number;        // top-left of the first QR module
    var y as Number;
    var side as Number;     // n * module
    var textY as Number;    // baseline area for the countdown when no subscreen (-1 = none)

    function initialize(m as Number, q as Number, px as Number, py as Number, s as Number, ty as Number) {
        modulePx = m;
        quiet = q;
        x = px;
        y = py;
        side = s;
        textY = ty;
    }
}

module QrRenderer {
    const TEXT_BAND = 22;    // px reserved under the quiet zone for "18 s" on screens without subscreen

    const GOOD_MODULE_PX = 3;   // below this, shrinking the quiet zone is preferred over smaller modules
    const SUBSCREEN_PAD = 8;    // physical bezel ring around the Instinct subscreen (measured in sim mask)

    // shape: System.SCREEN_SHAPE_*; sub: subscreen bounding box or null.
    // Policy: full 4-module quiet zone first. Only if that forces modules < GOOD_MODULE_PX, try a
    // narrower quiet zone (>= QR_QUIET_MIN) with modules >= GOOD_MODULE_PX.
    function computeLayout(w as Number, h as Number, shape as Number, sub as Graphics.BoundingBox or Null, n as Number) as QrLayout or Null {
        var maxM = (w < h ? w : h) / (n + 2 * ZappkaProtocol.QR_QUIET_MIN);
        var best = null;
        for (var m = maxM; m >= 1 && best == null; m--) {
            best = place(w, h, shape, sub, n, m, ZappkaProtocol.QR_QUIET_TARGET);
        }
        if (best != null && (best as QrLayout).modulePx >= GOOD_MODULE_PX) {
            return best;
        }
        for (var m = maxM; m >= GOOD_MODULE_PX; m--) {
            for (var q = ZappkaProtocol.QR_QUIET_TARGET - 1; q >= ZappkaProtocol.QR_QUIET_MIN; q--) {
                var l = place(w, h, shape, sub, n, m, q);
                if (l != null) {
                    return l;
                }
            }
        }
        return best;
    }

    function place(w as Number, h as Number, shape as Number, sub as Graphics.BoundingBox or Null,
                   n as Number, m as Number, q as Number) as QrLayout or Null {
        var outer = (n + 2 * q) * m;
        var band = sub == null ? TEXT_BAND : 0;
        // Slide away from the subscreen (down-left), or upwards to make room for the countdown text.
        for (var t = 0; t <= w / 4; t += 2) {
            var ox = (w - outer) / 2 - (sub != null ? t : 0);
            var oy = (h - outer - band) / 2 + (sub != null ? t : -t + band / 2);
            if (fits(w, h, shape, sub, ox, oy, outer, outer + band)) {
                return new QrLayout(m, q, ox + q * m, oy + q * m, n * m, sub == null ? oy + outer : -1);
            }
        }
        return null;
    }

    function fits(w as Number, h as Number, shape as Number, sub as Graphics.BoundingBox or Null,
                  x as Number, y as Number, sw as Number, sh as Number) as Boolean {
        var x2 = x + sw - 1;
        var y2 = y + sh - 1;
        if (x < 0 || y < 0 || x2 >= w || y2 >= h) {
            return false;
        }
        if (!inShape(w, h, shape, x, y) || !inShape(w, h, shape, x2, y) ||
            !inShape(w, h, shape, x, y2) || !inShape(w, h, shape, x2, y2)) {
            return false;
        }
        if (sub != null) {
            var pad = SUBSCREEN_PAD;
            var sx = sub.x - pad;
            var sy = sub.y - pad;
            var sx2 = sub.x + sub.width + pad;
            var sy2 = sub.y + sub.height + pad;
            if (x <= sx2 && x2 >= sx && y <= sy2 && y2 >= sy) {
                return false;
            }
        }
        return true;
    }

    // Visible-area test. Shapes are convex, so checking the corners is sufficient.
    function inShape(w as Number, h as Number, shape as Number, px as Number, py as Number) as Boolean {
        var cx2 = 2 * px + 1 - w;   // doubled offsets from centre, avoids floats
        var cy2 = 2 * py + 1 - h;
        if (shape == System.SCREEN_SHAPE_ROUND) {
            return cx2 * cx2 + cy2 * cy2 <= w * w;
        }
        if (shape == System.SCREEN_SHAPE_SEMI_OCTAGON || shape == System.SCREEN_SHAPE_SEMI_ROUND) {
            // octagon measured on the Instinct 3 Solar mask: |dx|+|dy| <= ~1.48 * half-side
            var ax = cx2 < 0 ? -cx2 : cx2;
            var ay = cy2 < 0 ? -cy2 : cy2;
            return (ax + ay) * 25 <= w * 37;
        }
        return true;
    }

    // Draws dark modules as merged horizontal runs. Pixel-exact; no scaling, no anti-aliasing.
    function drawModules(dc as Graphics.Dc, qr as QrCode, ox as Number, oy as Number, m as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        var n = qr.size;
        var mods = qr.modules;
        for (var y = 0; y < n; y++) {
            var row = y * n;
            var x = 0;
            while (x < n) {
                if (mods[row + x] != 0) {
                    var start = x;
                    while (x < n && mods[row + x] != 0) {
                        x++;
                    }
                    dc.fillRectangle(ox + start * m, oy + y * m, (x - start) * m, m);
                } else {
                    x++;
                }
            }
        }
    }

    // Renders once per OTP into a 2-colour bitmap; the view only blits it afterwards.
    function renderBitmap(qr as QrCode, m as Number) as Graphics.BufferedBitmap or Null {
        if (!(Graphics has :createBufferedBitmap)) {
            return null;
        }
        var side = qr.size * m;
        var ref = Graphics.createBufferedBitmap({
            :width => side,
            :height => side,
            :palette => [Graphics.COLOR_WHITE, Graphics.COLOR_BLACK]
        });
        var bmp = ref.get() as Graphics.BufferedBitmap;
        var bdc = bmp.getDc();
        bdc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        bdc.clear();
        drawModules(bdc, qr, 0, 0, m);
        return bmp;
    }
}
