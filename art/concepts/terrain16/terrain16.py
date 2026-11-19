from PIL import Image, ImageDraw, ImageFont
import random, math
def hx(h): return tuple(int(h[i:i+2],16) for i in (0,2,4))
DIRT=[hx(c) for c in ["2a1d0c","413117","65441a","775728","866737","8a6a38","a0804c"]]
STONE=[hx(c) for c in ["29261f","48443a","5f5a4f","757064","8a8476","9c9688","b0aa9b"]]
GRASS=[hx(c) for c in ["1f5212","2b7018","349a20","42a628","4fb52f","5cbf3a","7fd457"]]
N=128
def put(im,x,y,c): im.putpixel((x%N,y%N),c+(255,) if len(c)==3 else c)

def dirt(seed=5):
    random.seed(seed)
    im=Image.new('RGBA',(N,N),DIRT[2]+(255,))
    # soft base variation
    for y in range(N):
        for x in range(N):
            v=math.sin(x*0.19+y*0.07)+math.sin(y*0.23-x*0.11)
            if v>1.1: put(im,x,y,DIRT[3])
            elif v<-1.3: put(im,x,y,DIRT[2])
    # clods
    for _ in range(260):
        cx,cy=random.randrange(N),random.randrange(N)
        rx,ry=random.uniform(1.6,3.4),random.uniform(1.2,2.4)
        tone=random.choice([3,4,4,5])
        for dy in range(-6,7):
            for dx in range(-6,7):
                e=(dx/rx)**2+(dy/ry)**2
                if e<1:
                    c=DIRT[tone]
                    if e>0.55 and (dx>0.3*rx or dy>0.3*ry): c=DIRT[tone-1]   # shadow side
                    if e>0.45 and dx<-0.2*rx and dy<-0.1*ry: c=DIRT[min(6,tone+1)]  # lit edge
                    put(im,cx+dx,cy+dy,c)
        # gap under the clod
        if random.random()<0.5:
            for dx in range(-int(rx)+1,int(rx)):
                put(im,cx+dx,cy+int(ry)+1,DIRT[1])
    # pebbles
    for _ in range(18):
        cx,cy=random.randrange(N),random.randrange(N)
        w=random.choice([2,3,3,4]); h=random.choice([2,2,3])
        for dy in range(h):
            for dx in range(w):
                c=STONE[4]
                if dy==h-1 or dx==w-1: c=STONE[2]
                if dx==0 and dy==0: c=STONE[6]
                put(im,cx+dx,cy+dy,c)
        for dx in range(w): put(im,cx+dx,cy+h,DIRT[1])
    # roots
    for _ in range(5):
        x,y=random.randrange(N),random.randrange(N); a=random.uniform(0,6.28)
        for k in range(random.randint(8,16)):
            put(im,int(x),int(y),DIRT[1]); put(im,int(x)+1,int(y),(140,104,62))
            a+=random.uniform(-0.5,0.5); x+=math.cos(a); y+=abs(math.sin(a))*0.8+0.3
    return im

def stone(seed=9):
    random.seed(seed)
    pts=[(random.uniform(0,N),random.uniform(0,N),random.choice([3,3,4,4,4,5])) for _ in range(72)]
    im=Image.new('RGBA',(N,N))
    def near(x,y):
        best=[]
        for i,(px,py,_) in enumerate(pts):
            dx=min(abs(x-px),N-abs(x-px)); dy=min(abs(y-py),N-abs(y-py))
            best.append((dx*dx+dy*dy*1.4,i))
        best.sort(); return best
    for y in range(N):
        for x in range(N):
            b=near(x,y); d0,i=b[0]; d1=b[1][0]
            edge=math.sqrt(d1)-math.sqrt(d0)
            tone=pts[i][2]
            c=STONE[tone]
            # light from top-left: compare with neighbor up-left
            bu=near(x-1,y-1)[0][1]; bd=near(x+1,y+1)[0][1]
            if edge<0.9: c=STONE[2]
            elif bu!=i and edge<2.2: c=STONE[min(6,tone+1)]
            elif bd!=i and edge<2.6: c=STONE[tone-1]
            elif random.random()<0.07: c=STONE[tone-1]
            elif random.random()<0.04: c=STONE[min(6,tone+1)]
            im.putpixel((x,y),c+(255,))
    return im

def scene(dtex,stex,bpx,grass_h,blade):
    W,H=12,7
    random.seed(2)
    surf=[1,1,1,0,0,1,1,1,2,2,1,1]
    stone_top=[4,4,3,3,3,4,4,5,5,4,4,4]
    im=Image.new('RGBA',(W*bpx,H*bpx),(156,200,232,255))
    for bx in range(W):
        for by in range(surf[bx],H):
            tex=dtex if by<stone_top[bx] else stex
            for y in range(bpx):
                for x in range(bpx):
                    X,Y=bx*bpx+x,by*bpx+y
                    im.putpixel((X,Y),tex.getpixel((X%tex.width,Y%tex.height)))
        # grass on the top block
        top=surf[bx]*bpx
        for x in range(bpx):
            X=bx*bpx+x
            gh=grass_h+random.choice([0,0,1,-1 if grass_h>2 else 0])
            for y in range(gh):
                c=GRASS[3] if y<gh-1 else GRASS[1]
                if y==0: c=GRASS[5]
                im.putpixel((X,top+y),c+(255,))
            if random.random()<0.45:
                h=random.randint(1,blade)
                for k in range(1,h+1):
                    if top-k>=0: im.putpixel((X,top-k),(GRASS[4] if k<h else GRASS[6])+(255,))
    return im

if __name__=='__main__':
    D,S=dirt(),stone()
    D.save('dirt16_128.png'); S.save('stone16_128.png')
    old_d=Image.open('/home/claude/game-prototype/assets/terrain/dirt.png').convert('RGBA')
    old_s=Image.open('/home/claude/game-prototype/assets/terrain/stone.png').convert('RGBA')
    a=scene(old_d,old_s,8,2,2).resize((12*48,7*48),Image.NEAREST)
    b=scene(D,S,16,4,4).resize((12*48,7*48),Image.NEAREST)
    f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',22)
    out=Image.new('RGBA',(a.width*2+60,a.height+60),(22,18,16,255)); d=ImageDraw.Draw(out)
    d.text((20,14),"Today: 8x8 blocks",fill=(235,225,205),font=f)
    d.text((a.width+40,14),"Concept: 16x16 blocks, same block size on screen",fill=(235,225,205),font=f)
    out.paste(a,(20,48)); out.paste(b,(a.width+40,48))
    out.save('terrain_compare.png')
    sw=Image.new('RGBA',(128*3*2+60,128*3+60),(22,18,16,255)); d=ImageDraw.Draw(sw)
    d.text((20,14),"Dirt 16x16 (8x8 blocks of it, tiles seamlessly)",fill=(235,225,205),font=f)
    d.text((128*3+40,14),"Stone 16x16",fill=(235,225,205),font=f)
    sw.paste(D.resize((384,384),Image.NEAREST),(20,48)); sw.paste(S.resize((384,384),Image.NEAREST),(128*3+40,48))
    sw.save('terrain_swatch.png')
