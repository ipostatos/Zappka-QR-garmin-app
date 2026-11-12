# Decodes a simulator screenshot and compares with an independent TOTP (public example account only).
import cv2,sys,hmac,hashlib,struct  # run with python -I
img=cv2.imread(sys.argv[1]); t=int(sys.argv[2])
big=cv2.resize(img,None,fx=4,fy=4,interpolation=cv2.INTER_NEAREST)
data,_,_=cv2.QRCodeDetector().detectAndDecode(big)
s=bytes.fromhex("2db76449a55d59f1f9420b809edb1beb19dfa434ddb5dbf331f01aec35956e35")
def otp(t):
    h=hmac.new(s,struct.pack(">Q",t//30),hashlib.sha1).digest();o=h[-1]&15
    return "%06d"%((struct.unpack(">I",h[o:o+4])[0]&0x7fffffff)%10**6)
print("decoded :",data)
for dt in (-30,0):
    print("expected:","https://srln.pl/view/dashboard?ploy=123456789012&loyal="+otp(t+dt), "(t%+d)"%dt, "remaining", 30-(t+dt)%30)
