from PIL import Image
import sys
def same(a,b): return a==b
def scale2x(im):
    w,h=im.size; src=im.load(); out=Image.new('RGBA',(w*2,h*2)); o=out.load()
    g=lambda x,y: src[min(max(x,0),w-1),min(max(y,0),h-1)] if 0<=x<w and 0<=y<h else (0,0,0,0)
    for y in range(h):
        for x in range(w):
            P=g(x,y);A=g(x,y-1);B=g(x+1,y);C=g(x-1,y);D=g(x,y+1)
            e0=e1=e2=e3=P
            if A!=D and C!=B:
                if C==A: e0=A
                if A==B: e1=B
                if C==D: e2=C
                if D==B: e3=B
            o[2*x,2*y]=e0;o[2*x+1,2*y]=e1;o[2*x,2*y+1]=e2;o[2*x+1,2*y+1]=e3
    return out
def lum(c): return c[0]*0.3+c[1]*0.59+c[2]*0.11
def shade(img):
    # 1 art px lit top edge and shaded bottom edge inside each region, like the terrain
    w,h=img.size; p=img.load(); out=img.copy(); o=out.load()
    for y in range(h):
        for x in range(w):
            c=p[x,y]
            if c[3]==0: continue
            up=p[x,y-1] if y>0 else (0,0,0,0)
            dn=p[x,y+1] if y<h-1 else (0,0,0,0)
            def adj(c,f): return tuple(min(255,max(0,int(v*f))) for v in c[:3])+(c[3],)
            if up!=c and (up[3]==0 or lum(up)<lum(c)*0.8) and y>0 and p[x,y+1]==c:
                o[x,y]=adj(c,1.12)
            elif dn!=c and dn[3]!=0 and lum(dn)<lum(c)*0.8 and p[x,y-1]==c:
                o[x,y]=adj(c,0.9)
    return out
if __name__=='__main__':
    for n in sys.argv[1:]:
        im=Image.open(f'/home/claude/game-prototype/assets/objects/{n}.png').convert('RGBA')
        a=im.resize((im.width*2,im.height*2),Image.NEAREST); b=shade(scale2x(im))
        W=a.width
        sheet=Image.new('RGBA',(W*2+8,a.height),(40,40,44,255)); sheet.paste(a,(0,0),a); sheet.paste(b,(W+8,0),b)
        sheet.resize((sheet.width*4,sheet.height*4),Image.NEAREST).save(f'cmp_{n}.png')
