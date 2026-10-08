import Toybox.Lang;

// Minimal QR Code Model 2 encoder: byte mode, versions 1-10, ECC L/M, caller-chosen mask.
// Algorithm structure follows Project Nayuki's "QR Code generator library" (MIT License,
// https://www.nayuki.io/page/qr-code-generator-library); rewritten for Monkey C with
// table-based GF(256) arithmetic to stay within the Connect IQ watchdog budget.

class QrCode {
    var size as Number;
    var modules as ByteArray;   // size*size, 1 = dark; index y*size + x

    function initialize(s as Number, m as ByteArray) {
        size = s;
        modules = m;
    }

    function isDark(x as Number, y as Number) as Boolean {
        return modules[y * size + x] != 0;
    }
}

module QrEncoder {
    const ECC_L = 0;
    const ECC_M = 1;
    const MAX_VERSION = 10;

    // [ecc][version-1]  (ISO/IEC 18004 Table 9)
    const ECC_PER_BLOCK = [
        [7, 10, 15, 20, 26, 18, 20, 24, 30, 18],
        [10, 16, 26, 18, 24, 16, 18, 22, 22, 26]
    ];
    const NUM_BLOCKS = [
        [1, 1, 1, 1, 1, 2, 2, 2, 2, 4],
        [1, 1, 1, 2, 2, 4, 4, 4, 5, 5]
    ];
    const FORMAT_ECC_BITS = [1, 0];

    var _exp as ByteArray or Null = null;
    var _log as ByteArray or Null = null;

    function encodeText(text as String, ecc as Number, mask as Number) as QrCode or Null {
        return encodeBytes(text.toUtf8Array(), ecc, mask);
    }

    // Symbol size for a byte-mode payload, without encoding (cheap; used to precompute layout).
    function sizeFor(byteLen as Number, ecc as Number) as Number {
        var v = versionFor(byteLen, ecc);
        return v == 0 ? 0 : v * 4 + 17;
    }

    function versionFor(len as Number, ecc as Number) as Number {
        for (var v = 1; v <= MAX_VERSION; v++) {
            if (4 + (v <= 9 ? 8 : 16) + len * 8 <= numDataCodewords(v, ecc) * 8) {
                return v;
            }
        }
        return 0;
    }

    function encodeBytes(data as Array<Number>, ecc as Number, mask as Number) as QrCode or Null {
        initGf();
        var len = data.size();

        var ver = versionFor(len, ecc);
        if (ver == 0) {
            return null;
        }
        var dataCw = numDataCodewords(ver, ecc);

        // --- data codewords ---
        var buf = new [dataCw]b;
        var pos = 0;
        pos = appendBits(buf, pos, 0x4, 4);                    // byte mode
        pos = appendBits(buf, pos, len, ver <= 9 ? 8 : 16);    // char count
        for (var i = 0; i < len; i++) {
            pos = appendBits(buf, pos, data[i] & 0xFF, 8);
        }
        var capBits = dataCw * 8;
        var term = capBits - pos;
        pos += term < 4 ? term : 4;                            // terminator
        pos = (pos + 7) / 8 * 8;
        var pad = 0xEC;
        for (var i = pos / 8; i < dataCw; i++) {
            buf[i] = pad;
            pad = pad == 0xEC ? 0x11 : 0xEC;
        }

        var codewords = addEccAndInterleave(buf, ver, ecc);

        // --- matrix ---
        var size = ver * 4 + 17;
        var mods = new [size * size]b;
        var fn = new [size * size]b;
        drawFunctionPatterns(mods, fn, size, ver, ecc, mask);
        drawCodewords(mods, fn, size, codewords, mask);
        return new QrCode(size, mods);
    }

    // ---------------------------------------------------------------- helpers

    function numRawDataModules(ver as Number) as Number {
        var result = (16 * ver + 128) * ver + 64;
        if (ver >= 2) {
            var na = ver / 7 + 2;
            result -= (25 * na - 10) * na - 55;
            if (ver >= 7) {
                result -= 36;
            }
        }
        return result;
    }

    function numDataCodewords(ver as Number, ecc as Number) as Number {
        return numRawDataModules(ver) / 8 - ECC_PER_BLOCK[ecc][ver - 1] * NUM_BLOCKS[ecc][ver - 1];
    }

    function appendBits(buf as ByteArray, pos as Number, val as Number, n as Number) as Number {
        for (var i = n - 1; i >= 0; i--) {
            if (((val >> i) & 1) != 0) {
                buf[pos >> 3] = buf[pos >> 3] | (0x80 >> (pos & 7));
            }
            pos++;
        }
        return pos;
    }

    function initGf() as Void {
        if (_exp != null) {
            return;
        }
        var e = new [512]b;
        var l = new [256]b;
        var x = 1;
        for (var i = 0; i < 255; i++) {
            e[i] = x;
            l[x] = i;
            x <<= 1;
            if ((x & 0x100) != 0) {
                x ^= 0x11D;
            }
        }
        for (var i = 255; i < 512; i++) {
            e[i] = e[i - 255];
        }
        _exp = e;
        _log = l;
    }

    function gfMul(x as Number, y as Number) as Number {
        if (x == 0 || y == 0) {
            return 0;
        }
        var e = _exp as ByteArray;
        var l = _log as ByteArray;
        return e[l[x] + l[y]];
    }

    function rsDivisor(degree as Number) as ByteArray {
        var result = new [degree]b;
        result[degree - 1] = 1;
        var root = 1;
        for (var i = 0; i < degree; i++) {
            for (var j = 0; j < degree; j++) {
                var v = gfMul(result[j], root);
                if (j + 1 < degree) {
                    v ^= result[j + 1];
                }
                result[j] = v;
            }
            root = gfMul(root, 0x02);
        }
        return result;
    }

    // LFSR division. Shift and XOR are fused into one pass and multiplication uses log tables:
    // this loop dominates encode time and must stay inside the Instinct watchdog budget.
    function rsRemainder(data as ByteArray, start as Number, len as Number, divisor as ByteArray) as ByteArray {
        var e = _exp as ByteArray;
        var l = _log as ByteArray;
        var deg = divisor.size();
        var logDiv = new [deg]b;   // generator coefficients are never 0
        for (var k = 0; k < deg; k++) {
            logDiv[k] = l[divisor[k]];
        }
        var last = deg - 1;
        var res = new [deg]b;
        for (var i = 0; i < len; i++) {
            var factor = data[start + i] ^ res[0];
            if (factor == 0) {
                for (var k = 0; k < last; k++) {
                    res[k] = res[k + 1];
                }
                res[last] = 0;
            } else {
                var lf = l[factor];
                for (var k = 0; k < last; k++) {
                    res[k] = res[k + 1] ^ e[logDiv[k] + lf];
                }
                res[last] = e[logDiv[last] + lf];
            }
        }
        return res;
    }

    function addEccAndInterleave(data as ByteArray, ver as Number, ecc as Number) as ByteArray {
        var numBlocks = NUM_BLOCKS[ecc][ver - 1];
        var blockEcc = ECC_PER_BLOCK[ecc][ver - 1];
        var raw = numRawDataModules(ver) / 8;
        var numShort = numBlocks - raw % numBlocks;
        var shortData = raw / numBlocks - blockEcc;
        var divisor = rsDivisor(blockEcc);

        var starts = new [numBlocks];
        var lens = new [numBlocks];
        var eccs = new [numBlocks];
        var off = 0;
        for (var j = 0; j < numBlocks; j++) {
            var dl = shortData + (j < numShort ? 0 : 1);
            starts[j] = off;
            lens[j] = dl;
            eccs[j] = rsRemainder(data, off, dl, divisor);
            off += dl;
        }

        var result = new [raw]b;
        var idx = 0;
        for (var i = 0; i <= shortData; i++) {
            for (var j = 0; j < numBlocks; j++) {
                if (i < lens[j]) {
                    result[idx] = data[starts[j] + i];
                    idx++;
                }
            }
        }
        for (var i = 0; i < blockEcc; i++) {
            for (var j = 0; j < numBlocks; j++) {
                result[idx] = (eccs[j] as ByteArray)[i];
                idx++;
            }
        }
        return result;
    }

    function setFn(mods as ByteArray, fn as ByteArray, size as Number, x as Number, y as Number, dark as Boolean) as Void {
        var i = y * size + x;
        mods[i] = dark ? 1 : 0;
        fn[i] = 1;
    }

    function drawFunctionPatterns(mods as ByteArray, fn as ByteArray, size as Number, ver as Number, ecc as Number, mask as Number) as Void {
        // timing
        for (var i = 0; i < size; i++) {
            setFn(mods, fn, size, 6, i, i % 2 == 0);
            setFn(mods, fn, size, i, 6, i % 2 == 0);
        }
        // finders (+ separators)
        drawFinder(mods, fn, size, 3, 3);
        drawFinder(mods, fn, size, size - 4, 3);
        drawFinder(mods, fn, size, 3, size - 4);
        // alignment
        if (ver >= 2) {
            var na = ver / 7 + 2;
            var step = (ver * 8 + na * 3 + 5) / (na * 4 - 4) * 2;
            var pos = new [na];
            pos[0] = 6;
            var p = size - 7;
            for (var k = na - 1; k >= 1; k--) {
                pos[k] = p;
                p -= step;
            }
            for (var i = 0; i < na; i++) {
                for (var j = 0; j < na; j++) {
                    if ((i == 0 && j == 0) || (i == 0 && j == na - 1) || (i == na - 1 && j == 0)) {
                        continue;
                    }
                    for (var dy = -2; dy <= 2; dy++) {
                        for (var dx = -2; dx <= 2; dx++) {
                            var d = abs(dx) > abs(dy) ? abs(dx) : abs(dy);
                            setFn(mods, fn, size, pos[i] + dx, pos[j] + dy, d != 1);
                        }
                    }
                }
            }
        }
        drawFormatBits(mods, fn, size, ecc, mask);
        if (ver >= 7) {
            var rem = ver;
            for (var i = 0; i < 12; i++) {
                rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
            }
            var bits = (ver << 12) | rem;
            for (var i = 0; i < 18; i++) {
                var bit = ((bits >> i) & 1) != 0;
                var a = size - 11 + i % 3;
                var b = i / 3;
                setFn(mods, fn, size, a, b, bit);
                setFn(mods, fn, size, b, a, bit);
            }
        }
    }

    function abs(v as Number) as Number {
        return v < 0 ? -v : v;
    }

    function drawFinder(mods as ByteArray, fn as ByteArray, size as Number, x as Number, y as Number) as Void {
        for (var dy = -4; dy <= 4; dy++) {
            for (var dx = -4; dx <= 4; dx++) {
                var xx = x + dx;
                var yy = y + dy;
                if (xx >= 0 && xx < size && yy >= 0 && yy < size) {
                    var d = abs(dx) > abs(dy) ? abs(dx) : abs(dy);
                    setFn(mods, fn, size, xx, yy, d != 2 && d != 4);
                }
            }
        }
    }

    function drawFormatBits(mods as ByteArray, fn as ByteArray, size as Number, ecc as Number, mask as Number) as Void {
        var data = (FORMAT_ECC_BITS[ecc] << 3) | mask;
        var rem = data;
        for (var i = 0; i < 10; i++) {
            rem = (rem << 1) ^ ((rem >> 9) * 0x537);
        }
        var bits = ((data << 10) | rem) ^ 0x5412;

        for (var i = 0; i <= 5; i++) {
            setFn(mods, fn, size, 8, i, bit(bits, i));
        }
        setFn(mods, fn, size, 8, 7, bit(bits, 6));
        setFn(mods, fn, size, 8, 8, bit(bits, 7));
        setFn(mods, fn, size, 7, 8, bit(bits, 8));
        for (var i = 9; i < 15; i++) {
            setFn(mods, fn, size, 14 - i, 8, bit(bits, i));
        }
        for (var i = 0; i < 8; i++) {
            setFn(mods, fn, size, size - 1 - i, 8, bit(bits, i));
        }
        for (var i = 8; i < 15; i++) {
            setFn(mods, fn, size, 8, size - 15 + i, bit(bits, i));
        }
        setFn(mods, fn, size, 8, size - 8, true);   // dark module
    }

    function bit(v as Number, i as Number) as Boolean {
        return ((v >> i) & 1) != 0;
    }

    // Places data bits in the zigzag order and applies the mask in the same pass
    // (remainder bits are 0 before masking, as required by the spec).
    function drawCodewords(mods as ByteArray, fn as ByteArray, size as Number, data as ByteArray, mask as Number) as Void {
        var total = data.size() * 8;
        var i = 0;
        var right = size - 1;
        while (right >= 1) {
            if (right == 6) {
                right = 5;
            }
            var upward = ((right + 1) & 2) == 0;
            for (var vert = 0; vert < size; vert++) {
                var y = upward ? size - 1 - vert : vert;
                var row = y * size;
                for (var x = right; x > right - 2; x--) {
                    if (fn[row + x] != 0) {
                        continue;
                    }
                    var v = 0;
                    if (i < total) {
                        v = (data[i >> 3] >> (7 - (i & 7))) & 1;
                        i++;
                    }
                    var inv = mask == 0 ? ((x + y) & 1) == 0 : maskBit(mask, x, y);
                    mods[row + x] = inv ? v ^ 1 : v;
                }
            }
            right -= 2;
        }
    }

    function maskBit(mask as Number, x as Number, y as Number) as Boolean {
        switch (mask) {
            case 1: return y % 2 == 0;
            case 2: return x % 3 == 0;
            case 3: return (x + y) % 3 == 0;
            case 4: return (x / 3 + y / 2) % 2 == 0;
            case 5: return x * y % 2 + x * y % 3 == 0;
            case 6: return (x * y % 2 + x * y % 3) % 2 == 0;
            case 7: return ((x + y) % 2 + x * y % 3) % 2 == 0;
            default: return (x + y) % 2 == 0;
        }
    }
}
