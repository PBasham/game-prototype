from PIL import Image
import colorsys, random, math, sys
from up2 import scale2x, shade
def hsv(c): return colorsys.rgb_to_hsv(c[0]/255,c[1]/255,c[2]/255)
def adj(c,f): return tuple(min(255,max(0,int(v*f))) for v in c[:3])+(c[3],)
def h2(x,y,s): 
    n=(x*374761393+y*668265263+s*982451653)&0x7fffffff; n=((n^(n>>13))*1274126177)&0x7fffffff; return ((n^(n>>16))&0xffff)/65536
def vnoise(x,y,s):
    xi,yi=math.floor(x),math.floor(y); fx,fy=x-xi,y-yi
    a=h2(xi,yi,s);b=h2(xi+1,yi,s);c=h2(xi,yi+1,s);d=h2(xi+1,yi+1,s)
    return (a*(1-fx)+b*fx)*(1-fy)+(c*(1-fx)+d*fx)*fy
def runs(im):
    w,h=im.size;p=im.load();H={};V={}
    for y in range(h):
        x=0
        while x<w:
            x2=x
            while x2+1<w and p[x2+1,y]==p[x,y]: x2+=1
            for k in range(x,x2+1): H[k,y]=x2-x+1
            x=x2+1
    for x in range(w):
        y=0
        while y<h:
            y2=y
            while y2+1<h and p[x,y2+1]==p[x,y]: y2+=1
            for k in range(y,y2+1): V[x,k]=y2-y+1
            y=y2+1
    return H,V
def detail(src,seed=1):
    big=shade(scale2x(src)); p=big.load(); w,h=big.size
    H,V=runs(src)
    out=big.copy(); o=out.load()
    for y in range(h):
        for x in range(w):
            c=p[x,y]
            if c[3]==0: continue
            hh,s,v=hsv(c)
            sx,sy=x//2,y//2
            horiz=H.get((sx,sy),1)>=V.get((sx,sy),1)
            if 0.03<hh<0.14 and 0.3<s<0.8 and v<0.74:   # wood: grain along the board
                u,t=(x/7.0,y*1.0) if horiz else (x*1.0,y/7.0)
                n=vnoise(u,t,seed)
                if n>0.72: o[x,y]=adj(c,0.86)
                elif n<0.12: o[x,y]=adj(c,1.07)
                if h2(x//3,y//3,seed+5)<0.012: o[x,y]=adj(c,0.7)   # knot
            elif s<0.18 and v>0.25:      # metal / stone: grit and glints
                r=h2(x,y,seed+9)
                if r<0.08: o[x,y]=adj(c,0.9)
                elif r>0.96: o[x,y]=adj(c,1.12)
    return out
# Usage (from the repo root): python3 art/concepts/stations/detail2x.py workbench furnace ...
# Reads art/concepts/stations/<name>_1x.png, writes assets/objects/<name>.png (2x) and a
# before/after cmp_<name>.png here.
if __name__=='__main__':
    import os
    here=os.path.dirname(os.path.abspath(__file__))
    for n in sys.argv[1:]:
        im=Image.open(os.path.join(here,f'{n}_1x.png')).convert('RGBA')
        a=im.resize((im.width*2,im.height*2),Image.NEAREST); b=detail(im)
        b.save(os.path.join(here,'..','..','..','assets','objects',f'{n}.png'))
        W=a.width
        sheet=Image.new('RGBA',(W*2+8,a.height),(40,40,44,255)); sheet.paste(a,(0,0),a); sheet.paste(b,(W+8,0),b)
        sheet.resize((sheet.width*4,sheet.height*4),Image.NEAREST).save(os.path.join(here,f'cmp_{n}.png'))
