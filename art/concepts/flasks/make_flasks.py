from PIL import Image, ImageDraw, ImageFont
import random, math

def profile(kind):
    p={}
    if kind=='thin':
        for y in range(3,7): p[y]=('cork',2)
        p[7]=('lip',3)
        for y in range(8,11): p[y]=('neck',2)
        p[11]=('body',3)
        for y in range(12,28): p[y]=('body',4)
        p[28]=('body',3)
        band=(18,21); level=13
    elif kind=='regular':
        for y in range(2,6): p[y]=('cork',2)
        p[6]=('lip',3)
        for y in range(7,10): p[y]=('neck',2)
        p[10]=('body',4); p[11]=('body',5)
        for y in range(12,27): p[y]=('body',6)
        p[27]=('body',5); p[28]=('body',4)
        band=(17,21); level=14
    elif kind=='regular24':
        for y in range(1,4): p[y]=('cork',2)
        p[4]=('lip',3)
        for y in range(5,7): p[y]=('neck',2)
        p[7]=('body',3); p[8]=('body',4)
        for y in range(9,20): p[y]=('body',5)
        p[20]=('body',4); p[21]=('body',3)
        band=(13,15); level=10
    elif kind=='large24':
        for y in range(1,4): p[y]=('cork',2)
        p[4]=('lip',3)
        for y in range(5,8): p[y]=('neck',2)
        cy,r=15,7.6
        for y in range(8,23):
            hw=int(round(math.sqrt(max(0,r*r-(y+0.5-cy)**2))))
            p[y]=('body',max(2,min(8,hw)))
        p[22]=('body',4)
        band=(13,16); level=12
    else:
        for y in range(1,5): p[y]=('cork',3)
        p[5]=('lip',4)
        for y in range(6,11): p[y]=('neck',3)
        cy,r=19.5,10.4
        for y in range(11,30):
            hw=int(round(math.sqrt(max(0,r*r-(y+0.5-cy)**2))))
            p[y]=('body',max(3,min(10,hw)))
        p[29]=('body',6)
        band=(18,22); level=16
    return p,band,level

def shade(base,t,y=0,amt=1.0):
    k=1.22-0.6*t
    if t>0.88: k+=0.08   # a bit of reflected light on the far edge
    return tuple(max(0,min(255,int(c*(1+(k-1)*amt)))) for c in base)

HEART=[".dd.dd..","dhxdxxd.","dxxxxxd.","dxxxxxd.",".dxxxd..","..dxd...","...d....","........"]
STAR =["...d....","..dxd...","ddxhxdd.","dxxxxxd.",".dxxxd..","dxd.dxd.","d.....d.","........"]

HEART6=['dd.dd.','xdxxd.' if False else 'dxdxd.','dxxxd.','.dxd..','..d...','......']
STAR6=['..d...','.dxd..','dxhxd.','.dxd..','d.d.d.','......']

def draw(kind, mat, liquid=None, sym=None, seed=1, size=32):
    random.seed(seed)
    im=Image.new('RGBA',(size,size))
    C=size//2
    p,band,level=profile(kind)
    inside=set()
    for y,(part,hw) in p.items():
        x0,x1=C-hw,C-1+hw
        for x in range(x0,x1+1):
            t=(x-x0)/max(1,x1-x0)
            inside.add((x,y))
            if part=='cork':
                if liquid and mat=='clay':
                    c=shade(liquid[0],t)
                else:
                    c=shade((150,108,64),t,y)
                    if random.random()<0.25: c=tuple(int(v*0.85) for v in c)
                im.putpixel((x,y),c+(255,))
            elif mat=='clay':
                base=(186,118,78)
                if part=='lip': base=(170,104,66)
                c=shade(base,t)
                if y>=max(p)-2: c=tuple(int(v*0.9) for v in c)
                if liquid and band[0]<=y<=band[1] and part=='body':
                    c=shade(liquid[1] if y==band[0] else liquid[0],t)
                elif random.random()<0.10:
                    f=0.84 if random.random()<0.75 else 1.07
                    c=tuple(min(255,int(v*f)) for v in c)
                im.putpixel((x,y),c+(255,))
            else:  # glass
                a=55
                c=shade((180,226,238),t)
                if liquid and part=='body' and y>=level:
                    lc=shade(liquid[0],t,y)
                    if y==level: lc=shade(liquid[1],t)
                    c=lc; a=235
                if t>0.85: a=max(a,140)
                im.putpixel((x,y),c+(a,))
    # glass highlights and bubbles
    if mat=='glass':
        ys=sorted(y for y,(pt,_) in p.items() if pt in('body','neck'))
        for y in ys[1:-3]:
            part,hw=p[y]
            x=C-hw+ (2 if hw>=4 else 1)
            if y%7!=3:
                im.putpixel((x,y),(255,255,255,215))
        if liquid:
            for _ in range(3 if kind!='thin' else 2):
                y=random.randint(level+3,max(p)-3); hw=p[y][1]
                x=random.randint(C-hw+3,C-1+hw-2)
                im.putpixel((x,y),tuple(min(255,v+70) for v in liquid[1])+(255,))
    # wax drips
    if liquid and mat=='clay':
        top=min(y for y in p if p[y][0]=='lip')
        hw=p[top][1]
        for (dx,dl) in [(1,2),(hw*2-2,3)]:
            for k in range(dl):
                if (C-hw+dx,top+k) in inside: im.putpixel((C-hw+dx,top+k),shade(liquid[0],0.3)+(255,))
    # outline: shape pixels touching the outside
    ol={'clay':(66,38,24,255),'glass':(44,62,72,255)}[mat]
    for (x,y) in list(inside):
        if any((x+dx,y+dy) not in inside for dx,dy in((1,0),(-1,0),(0,1),(0,-1))):
            part=p[y][0]
            if part=='cork' and not(liquid and mat=='clay'): im.putpixel((x,y),(92,62,34,255))
            elif part=='cork': im.putpixel((x,y),tuple(int(v*0.55) for v in liquid[0])+(255,))
            else: im.putpixel((x,y),ol)
    if sym:
        if size>=32:
            pat=HEART if sym=='heart' else STAR; o=24
        else:
            pat=HEART6 if sym=='heart' else STAR6; o=size-6
        col=liquid[1]
        for y,row in enumerate(pat):
            for x,ch in enumerate(row):
                if ch=='x': im.putpixel((o+x,o+y),col+(255,))
                elif ch=='h': im.putpixel((o+x,o+y),(255,240,240,255))
                elif ch=='d': im.putpixel((o+x,o+y),(28,18,18,255))
    return im

RED=((196,40,44),(238,92,86)); BLUE=((44,92,196),(100,156,242)); GREEN=((76,150,52),(126,204,84))
if __name__=='__main__':
    rows=[]
    for mat,label in (('clay','A clay'),('glass','D glass')):
        for kind in ('thin','regular','large'):
            rows.append((f"{label}, {kind}",[draw(kind,mat,seed=3),draw(kind,mat,RED,'heart',seed=3),draw(kind,mat,BLUE,'star',seed=3)]))
    S=6; cell=32*S
    W=300+3*(cell+30); H=60+len(rows)*(cell+24)
    sheet=Image.new('RGBA',(W,H),(40,36,34,255)); d=ImageDraw.Draw(sheet)
    f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',22)
    for i,t in enumerate(['empty','healing','mana']): d.text((300+i*(cell+30)+60,18),t,fill=(230,220,200),font=f)
    for r,(label,ims) in enumerate(rows):
        y=50+r*(cell+24)
        d.text((16,y+cell//2-12),label,fill=(230,220,200),font=f)
        for i,im in enumerate(ims):
            x=300+i*(cell+30)
            d.rectangle((x,y,x+cell-1,y+cell-1),fill=(58,52,48))
            b=im.resize((cell,cell),Image.NEAREST); sheet.paste(b,(x,y),b)
    sheet.save('sheet.png')
    # actual size strip (1x and 3x like in game)
    strip=Image.new('RGBA',(6*34,34),(58,52,48,255))
    for i,im in enumerate([r[1][1] for r in rows]): strip.paste(im,(i*34+1,1),im)
    strip.resize((strip.width*3,strip.height*3),Image.NEAREST).save('strip3x.png')
