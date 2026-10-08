import Toybox.Lang;

// Builds the string encoded in the QR. No rendering, no crypto.
module ZappkaPayload {
    function build(userId as String, otp as String) as String {
        return ZappkaProtocol.PAYLOAD_PREFIX + userId + ZappkaProtocol.OTP_PARAM + otp;
    }
}
