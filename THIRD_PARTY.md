# Third-party notices

## Project Nayuki — QR Code generator library
`source/qr/QrEncoder.mc` is an independent Monkey C implementation whose structure (bit-stream
building, block interleaving, Reed–Solomon divisor/remainder, function-pattern drawing and zigzag
placement) follows the algorithm of Project Nayuki's QR Code generator library.
Source: https://www.nayuki.io/page/qr-code-generator-library, Copyright (c) Project Nayuki, MIT License.
The Python `qrcodegen` package from the same project is used (dev only, not shipped) to produce
the reference matrices in `tests/QrEncoderTest.mc`.

## Protocol references (no code copied)
- iGerman00/zabka-totp-webapp — TOTP/payload format reference.
- TehFridge/ZappkaQR — TOTP/payload format reference.

## RFC test vectors
RFC 6238 Appendix B (IETF Trust).
