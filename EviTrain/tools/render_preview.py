from PIL import Image, ImageDraw
import math
exec(open('poses.py').read())
S=3
def draw(name, color):
    im=Image.new('RGB',(100*S,100*S),color); d=ImageDraw.Draw(im)
    W=(255,255,255); G=(255,255,255)
    def line(x1,y1,x2,y2,w,c):
        d.line([x1*S,y1*S,x2*S,y2*S],fill=c,width=int(w*S))
        for x,y in((x1,y1),(x2,y2)): r=w*S/2; d.ellipse([x*S-r,y*S-r,x*S+r,y*S+r],fill=c)
    prop=(225,235,245)
    for t,a in P[name]:
        if t=='L': line(*a,7,W)
        elif t=='H': x,y=a; r=6.5*S; d.ellipse([x*S-r,y*S-r,x*S+r,y*S+r],fill=W)
        elif t=='B': x1,y1,x2,y2,w=a; line(x1,y1,x2,y2,max(w,1),prop)
        elif t=='P': x,y,r=a; d.ellipse([(x-r)*S,(y-r)*S,(x+r)*S,(y+r)*S],fill=prop)
        elif t=='R': x,y,w,h=a; d.rounded_rectangle([x*S,y*S,(x+w)*S,(y+h)*S],radius=2*S,fill=prop)
        elif t=='D':
            x,y,ang=a; c,s=math.cos(math.radians(ang)),math.sin(math.radians(ang))
            line(x-7*c,y-7*s,x+7*c,y+7*s,3,prop)
            for k in(-7,7): line(x+k*c-3*s*0,y+k*s,x+k*c,y+k*s,7,prop)
        elif t=='S':
            x,y,l=a
            for k in range(3): line(x,y+k*7,x+l-k*3,y+k*7,2.5,prop)
        elif t=='A':
            x1,y1,x2,y2=a; line(x1,y1,x2,y2,3,prop)
            ang=math.atan2(y2-y1,x2-x1)
            for da in(2.5,-2.5): line(x2,y2,x2-7*math.cos(ang+da*0.25*math.pi/2.5*1.2),y2-7*math.sin(ang+da*0.25*math.pi/2.5*1.2),3,prop)
    return im
cols=[(224,71,91),(59,91,219),(15,157,138),(217,138,0),(139,70,201),(224,102,27),(26,143,214),(212,65,142),(79,138,27)]
names=list(P)
grid=Image.new('RGB',(6*110*S//3*1,((len(names)+5)//6)*125*S//3*1),(240,240,240))
from PIL import ImageFont
try: font=ImageFont.truetype('/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf',14)
except: font=None
gd=ImageDraw.Draw(grid)
for i,n in enumerate(names):
    im=draw(n,cols[i%len(cols)]).resize((100,100))
    x=(i%6)*110+5; y=(i//6)*125+5
    grid.paste(im,(x,y)); gd.text((x,y+102),n[:9],fill=(0,0,0),font=font)
grid.save('grid.png'); print(len(names))
