import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.StringUtil;
import Toybox.Test;

// Reference generated with Project Nayuki's Python `qrcodegen` 1.8 (independent implementation):
// QrCode.encode_segments([QrSegment.make_bytes(payload)], Ecc.MEDIUM, 4, 4, mask=0, boostecl=False)
(:test)
const QR_REF_V4M = [
    "111111100011101100110101001111111",
    "100000101110100101011101001000001",
    "101110100000101110010001001011101",
    "101110100011110110100000101011101",
    "101110101000001110110001101011101",
    "100000100110011101111101001000001",
    "111111101010101010101010101111111",
    "000000000011010101010101000000000",
    "101010100110011101011101100010010",
    "101101011111001010000100011100011",
    "110100101010110000000010101100111",
    "110011011011100101001100101010010",
    "010101110011000001100111001101010",
    "101010001101110001101010001100101",
    "111111110011101010100000010001011",
    "100100001001010101101100101100010",
    "101100100101111011010110111001000",
    "001110010000010010101100101100011",
    "100110100101110000000010111000111",
    "110010000001111011111111110110010",
    "110001100001100101101111001101001",
    "011011011011000001101010001101111",
    "101000110010011001101100101111111",
    "010000001001111011111110101101000",
    "101101111100110011011100111111010",
    "000000001110001011001111100011001",
    "111111100011110011100111101010111",
    "100000100101011001010100100010001",
    "101110101111100001111110111111010",
    "101110100011011000101101100010101",
    "101110101011111010101100110011101",
    "100000100110000101001100100011010",
    "111111101011100111001100111011011"
];

// helper, not a test (a (:test) annotation would make the runner call it)
function qrRow(qr as QrCode, y as Number) as String {
    var chars = new [qr.size];
    for (var x = 0; x < qr.size; x++) {
        chars[x] = qr.isDark(x, y) ? '1' : '0';
    }
    return StringUtil.charArrayToString(chars);
}

(:test)
function qrMatchesReferenceV4(logger as Logger) as Boolean {
    var qr = QrEncoder.encodeText("https://srln.pl/view/dashboard?ploy=123456789012&loyal=287082",
        QrEncoder.ECC_M, 0) as QrCode;
    Test.assertEqual(qr.size, 33);
    for (var y = 0; y < 33; y++) {
        var row = qrRow(qr, y);
        if (!row.equals(QR_REF_V4M[y])) {
            logger.error("row " + y + " got " + row);
            return false;
        }
    }
    return true;
}

(:test)
function qrMatchesReferenceV8UnevenBlocks(logger as Logger) as Boolean {
    // version 8-M: 2 short + 2 long RS blocks and version-information bits.
    var text = "";
    for (var i = 0; i < 15; i++) {
        text += "ABCDEFGHIJ";
    }
    var qr = QrEncoder.encodeText(text, QrEncoder.ECC_M, 5) as QrCode;
    Test.assertEqual(qr.size, 49);
    var count = 0;
    var sum = 0l;
    for (var y = 0; y < 49; y++) {
        for (var x = 0; x < 49; x++) {
            if (qr.isDark(x, y)) {
                count++;
                sum = (sum + (y * 49 + x + 1) * (x % 7 + 1)) % 1000000007l;
            }
        }
    }
    Test.assertEqual(count, 1245);
    Test.assertEqual(sum, 6096518l);
    return true;
}

(:test)
function qrTooLongReturnsNull(logger as Logger) as Boolean {
    var text = "";
    for (var i = 0; i < 30; i++) {
        text += "0123456789";
    }
    Test.assert(QrEncoder.encodeText(text, QrEncoder.ECC_M, 0) == null);
    return true;
}

(:test)
function layoutInstinct3Solar(logger as Logger) as Boolean {
    var sub = new Graphics.BoundingBox();
    sub.x = 113; sub.y = 0; sub.width = 63; sub.height = 63;
    var l = QrRenderer.computeLayout(176, 176, System.SCREEN_SHAPE_SEMI_OCTAGON, sub, 33) as QrLayout;
    logger.debug("solar m=" + l.modulePx + " q=" + l.quiet + " x=" + l.x + " y=" + l.y);
    
    Test.assertEqual(l.modulePx, 2);   // measured: 3 px fits only with zero quiet zone
    Test.assertEqual(l.quiet, 4);
    return true;
}

(:test)
function layoutInstinct3Amoled(logger as Logger) as Boolean {
    var l = QrRenderer.computeLayout(390, 390, System.SCREEN_SHAPE_ROUND, null, 33) as QrLayout;
    logger.debug("amoled45 m=" + l.modulePx + " q=" + l.quiet + " x=" + l.x + " y=" + l.y + " textY=" + l.textY);
    Test.assert(l.modulePx >= 6 && l.quiet == 4 && l.textY > 0);
    var l2 = QrRenderer.computeLayout(416, 416, System.SCREEN_SHAPE_ROUND, null, 33) as QrLayout;
    logger.debug("amoled50 m=" + l2.modulePx + " q=" + l2.quiet);
    Test.assert(l2.modulePx >= l.modulePx);
    return true;
}
