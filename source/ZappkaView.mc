import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// Fullscreen QR. The QR is encoded once per TOTP step; the 1 s timer only redraws the countdown
// and blits the cached bitmap.
class ZappkaView extends WatchUi.View {
    private var _state as Symbol = :missing;    // :ok, :missing, :invalid, :qrfail
    private var _creds as ZappkaCredentials or Null = null;
    private var _counter as Long = -1l;
    private var _qr as QrCode or Null = null;
    private var _bitmap as Graphics.BufferedBitmap or Null = null;
    private var _layout as QrLayout or Null = null;
    private var _layoutN as Number = -1;
    private var _sub as Graphics.BoundingBox or Null = null;
    private var _timer as Timer.Timer or Null = null;
    private var _openedAt as Number = 0;
    private var _checkout as Boolean = false;   // START/SELECT toggles; max light, long timeout

    function initialize() {
        View.initialize();
        reload();
    }

    // Called on start and whenever settings change.
    function reload() as Void {
        var r = CredentialStore.load();
        _state = r[0];
        _creds = r[1];
        _counter = -1l;
        _qr = null;
        _bitmap = null;
        _layoutN = -1;
        _layout = null;
    }

    // Layout depends only on the symbol size, which is known from the payload length. Computing it
    // here keeps it out of the onUpdate watchdog budget used by the encoder.
    function onLayout(dc as Graphics.Dc) as Void {
        if (WatchUi has :getSubscreen) {
            _sub = WatchUi.getSubscreen();
        }
        ensureLayout(dc.getWidth(), dc.getHeight());
    }

    private function ensureLayout(w as Number, h as Number) as Void {
        if (_creds == null) {
            return;
        }
        var sample = ZappkaPayload.build((_creds as ZappkaCredentials).userId, "000000");
        var n = QrEncoder.sizeFor(sample.toUtf8Array().size(), ZappkaProtocol.QR_ECC);
        if (n != _layoutN) {
            _layoutN = n;
            _layout = n == 0 ? null :
                QrRenderer.computeLayout(w, h, System.getDeviceSettings().screenShape, _sub, n);
        }
    }

    function onShow() as Void {
        _openedAt = Time.now().value();
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        (_timer as Timer.Timer).start(method(:onTick), 1000, true);
        lightOn();
    }

    function toggleCheckout() as Void {
        _checkout = !_checkout;
        _openedAt = Time.now().value();   // restart the auto-exit timer
        lightOn();
        buzz(_checkout ? 60 : 30);
        WatchUi.requestUpdate();
    }

    // Brightest allowed backlight. AMOLED firmware may refuse long/level backlight; never fatal.
    private function lightOn() as Void {
        if (!(Attention has :backlight)) {
            return;
        }
        try {
            Attention.backlight(_checkout ? 1.0 : true);
        } catch (e) {
            try {
                Attention.backlight(true);
            } catch (e2) {
            }
        }
    }

    private function buzz(ms as Number) as Void {
        if (ms <= 0 || !(Attention has :vibrate)) {
            return;
        }
        try {
            Attention.vibrate([new Attention.VibeProfile(50, ms)]);
        } catch (e) {
        }
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
        }
    }

    function onTick() as Void {
        var limit = _checkout ? ZappkaProtocol.CHECKOUT_EXIT_SECONDS : ZappkaProtocol.AUTO_EXIT_SECONDS;
        if (Time.now().value() - _openedAt > limit) {
            System.exit();
        }
        if (_checkout) {
            lightOn();   // keep the screen at full brightness while waiting in line
        }
        WatchUi.requestUpdate();
    }

    // Regenerates only when the TOTP counter changes.
    private function refresh(dc as Graphics.Dc, now as Number) as Void {
        if (_state != :ok && _state != :qrfail) {
            return;
        }
        if (_layoutN == -1) {
            // Settings changed while open: lay out now, encode on the next tick.
            ensureLayout(dc.getWidth(), dc.getHeight());
            _counter = -1l;
            return;
        }
        var counter = TotpGenerator.counterFor(now, ZappkaProtocol.TIME_STEP);
        if (counter == _counter) {
            return;
        }
        var rotated = _counter != -1l;
        _counter = counter;
        if (rotated) {
            buzz(ZappkaProtocol.VIBE_ON_ROTATE_MS);
        }
        var creds = _creds as ZappkaCredentials;
        try {
            var otp = TotpGenerator.generateForCounter(creds.secret, counter, ZappkaProtocol.DIGITS);
            var qr = QrEncoder.encodeText(ZappkaPayload.build(creds.userId, otp),
                ZappkaProtocol.QR_ECC, ZappkaProtocol.QR_MASK);
            if (qr == null) {
                _state = :qrfail;
                return;
            }
            if (_layout == null || qr.size != _layoutN) {
                _state = :qrfail;
                return;
            }
            _qr = qr;
            _bitmap = QrRenderer.renderBitmap(qr, (_layout as QrLayout).modulePx);
            _state = :ok;
        } catch (e) {
            // Deliberately no details: exception text could in theory echo inputs.
            _state = :qrfail;
            _qr = null;
            _bitmap = null;
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var now = Time.now().value();
        refresh(dc, now);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();

        if (_state == :ok && _qr != null && _layout != null) {
            var l = _layout as QrLayout;
            if (_bitmap != null) {
                dc.drawBitmap(l.x, l.y, _bitmap as Graphics.BufferedBitmap);
            } else {
                QrRenderer.drawModules(dc, _qr as QrCode, l.x, l.y, l.modulePx);
            }
            var remaining = TotpGenerator.secondsRemaining(now, ZappkaProtocol.TIME_STEP);
            if (_sub != null) {
                CountdownRenderer.drawInSubscreen(dc, _sub as Graphics.BoundingBox, remaining, _checkout);
            } else if (l.textY >= 0) {
                CountdownRenderer.drawBelow(dc, l.x + l.side / 2, l.textY, remaining, _checkout);
            }
            return;
        }

        if (_state == :ok) {
            return;   // layout just recomputed; QR is encoded on the next tick (<= 1 s)
        }
        var msg;
        if (_state == :missing) {
            msg = WatchUi.loadResource(Rez.Strings.SetupRequired);
        } else if (_state == :invalid) {
            msg = WatchUi.loadResource(Rez.Strings.InvalidConfig);
        } else {
            msg = WatchUi.loadResource(Rez.Strings.QrFailed);
        }
        drawMessage(dc, msg as String);
    }

    private function drawMessage(dc as Graphics.Dc, msg as String) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        // Keep text clear of the Instinct subscreen ring.
        var cy = _sub != null ? dc.getHeight() * 3 / 5 : dc.getHeight() / 2;
        dc.drawText(dc.getWidth() / 2, cy, Graphics.FONT_XTINY, msg,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// MENU -> minimal info screen. Shows only non-sensitive facts.
class ZappkaInfoView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var r = CredentialStore.load();
        var creds = r[1];
        var now = Time.now().value();
        var lines = "Zappka QR (unofficial)\n";
        if (creds != null) {
            lines += "ID " + creds.maskedUserId() + "\nkey: " + creds.secret.size() + " B\n";
        } else {
            lines += "not configured\n";
        }
        lines += "UTC " + now + "\nnext in " + TotpGenerator.secondsRemaining(now, ZappkaProtocol.TIME_STEP) + " s";
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_XTINY, lines,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
