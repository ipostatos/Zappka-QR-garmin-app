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
    private var _state as Symbol = :missing;    // :ok, :missing, :pending, :invalid, :qrfail
    private var _noticeUntil as Number = 0;     // "new secret rejected" shown until this epoch second
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
        if (CredentialStore.consumeRejected()) {
            _noticeUntil = Time.now().value() + ZappkaProtocol.NOTICE_SECONDS;
        }
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

    function isCheckout() as Boolean {
        return _checkout;
    }

    function toggleCheckout() as Void {
        setCheckout(!_checkout);
    }

    function setCheckout(on as Boolean) as Void {
        if (on == _checkout) {
            return;
        }
        _checkout = on;
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
        var now = Time.now().value();
        Prefs.notePhone(System.getDeviceSettings().phoneConnected, now);
        var limit = _checkout ? ZappkaProtocol.CHECKOUT_EXIT_SECONDS : Prefs.autoExitSeconds();
        if (now - _openedAt > limit) {
            System.exit();
        }
        if (_checkout) {
            lightOn();   // keep the screen at full brightness while waiting in line
        }
        askStagedChange();
        WatchUi.requestUpdate();
    }

    // A one-field account change (only the secret or only the ID) is applied only after the user
    // confirms it here; until then the working pair keeps producing codes.
    private function askStagedChange() as Void {
        var id = CredentialStore.stagedUserId();
        if (id == null) {
            return;
        }
        var masked = new ZappkaCredentials(id, new [0]b).maskedUserId();
        var text = (WatchUi.loadResource(Rez.Strings.ConfirmNewData) as String) + "\nID " + masked + "?";
        WatchUi.pushView(new WatchUi.Confirmation(text), new ZappkaStagedDelegate(self), WatchUi.SLIDE_IMMEDIATE);
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
        if (rotated && Prefs.vibrateOnRotate()) {
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

        if (now < _noticeUntil) {
            drawMessage(dc, WatchUi.loadResource(Rez.Strings.SecretRejected) as String);
            return;
        }

        if (_state == :ok && _qr != null && _layout != null) {
            var l = _layout as QrLayout;
            if (_bitmap != null) {
                dc.drawBitmap(l.x, l.y, _bitmap as Graphics.BufferedBitmap);
            } else {
                QrRenderer.drawModules(dc, _qr as QrCode, l.x, l.y, l.modulePx);
            }
            var remaining = TotpGenerator.secondsRemaining(now, ZappkaProtocol.TIME_STEP);
            if (_sub != null) {
                CountdownRenderer.drawInSubscreen(dc, _sub as Graphics.BoundingBox, remaining, _checkout, Prefs.phoneStale(now));
            } else if (l.textY >= 0) {
                CountdownRenderer.drawBelow(dc, l.x + l.side / 2, l.textY, remaining, _checkout, Prefs.phoneStale(now));
            }
            return;
        }

        if (_state == :ok) {
            return;   // layout just recomputed; QR is encoded on the next tick (<= 1 s)
        }
        var msg;
        if (_state == :missing) {
            msg = WatchUi.loadResource(Rez.Strings.SetupRequired);
        } else if (_state == :pending) {
            msg = WatchUi.loadResource(Rez.Strings.NeedUserId);
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
        var cy = TextScreen.centerY(dc.getHeight(), _sub, TextScreen.lineCount(msg));
        dc.drawText(dc.getWidth() / 2, cy, Graphics.FONT_XTINY, msg,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Menu -> Status: clock check and account facts. Shows only non-sensitive values.
class ZappkaInfoView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var now = Time.now().value();
        TextScreen.draw(dc, statusText(CredentialStore.load()[1], now, Prefs.phoneAgo(now)));
    }

    static function statusText(creds as ZappkaCredentials or Null, now as Number, phoneAgo as String) as String {
        var id = creds != null ? "ID " + creds.maskedUserId() : "no account";
        return id + "\nUTC " + now + "\nnext in " +
            TotpGenerator.secondsRemaining(now, ZappkaProtocol.TIME_STEP) + " s\nphone " + phoneAgo;
    }
}
