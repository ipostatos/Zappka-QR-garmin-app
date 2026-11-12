# Renders docs/assets/hero.png from docs/screenshots/qr-amoled45.png (needs Pillow, Windows fonts).
# usage (from the repo root): python -I tools/make-hero.py
from PIL import Image, ImageDraw, ImageFont, ImageFilter
W,H=1600,560
im=Image.new('RGB',(W,H)); d=ImageDraw.Draw(im)
for y in range(H):
    for x in range(0,W,4):
        u,t=x/W,y/H
        d.rectangle((x,y,x+3,y),fill=(int(8+10*u),int(64+40*(1-t)*(1-u)+20*u),int(40+10*u)))
F='C:/Windows/Fonts/'
big=ImageFont.truetype(F+'segoeuib.ttf',92); mid=ImageFont.truetype(F+'segoeui.ttf',38); sm=ImageFont.truetype(F+'segoeui.ttf',26)
d.text((90,150),'Zappka QR',font=big,fill=(255,255,255))
d.text((94,272),'Your loyalty code on the wrist.',font=mid,fill=(220,252,231))
d.text((94,326),'Offline · no permissions · new code every 30 s',font=sm,fill=(167,243,208))
x=94
for label in ['Garmin Instinct 3','Connect IQ · Monkey C']:
    w=d.textlength(label,font=sm)+40
    d.rounded_rectangle((x,400,x+w,448),radius=24,outline=(134,239,172),width=2)
    d.text((x+20,408),label,font=sm,fill=(220,252,231)); x+=w+20
qr=Image.open('docs/screenshots/qr-amoled45.png').convert('RGBA').resize((400,400),Image.LANCZOS)
cx,cy=1220,280
sh=Image.new('RGBA',(W,H),(0,0,0,0)); ImageDraw.Draw(sh).ellipse((cx-240,cy-226,cx+240,cy+254),fill=(0,0,0,150))
sh=sh.filter(ImageFilter.GaussianBlur(18)); im.paste(sh,(0,0),sh); d=ImageDraw.Draw(im)
for a,b in [((cx-252,cy-60),(cx-226,cy+60)),((cx+226,cy-60),(cx+252,cy+60))]:
    d.rounded_rectangle((*a,*b),radius=8,fill=(52,54,56))
d.ellipse((cx-234,cy-234,cx+234,cy+234),fill=(38,40,42)); d.ellipse((cx-212,cy-212,cx+212,cy+212),fill=(12,12,14))
im.paste(qr,(cx-200,cy-200),qr)
im.save('docs/assets/hero.png',optimize=True)
