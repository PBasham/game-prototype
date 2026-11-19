from PIL import Image
from detail2x import detail
L=(179,148,110,255); M=(160,122,74,255); B=(138,104,64,255); D=(110,80,48,255); K=(91,67,40,255)
def rect(im,x0,y0,x1,y1,c):
    for y in range(y0,y1+1):
        for x in range(x0,x1+1): im.putpixel((x,y),c)
# Table 32x24 (4x3 tiles): top at the very top
t=Image.new('RGBA',(32,24))
rect(t,0,0,31,0,L); rect(t,0,1,31,2,M); rect(t,0,3,31,3,D)
rect(t,1,4,30,5,B); rect(t,1,5,30,5,D)
for x0 in (2,27):
    rect(t,x0,4,x0+2,23,B); rect(t,x0,4,x0,23,M); rect(t,x0+2,4,x0+2,23,D)
rect(t,5,16,26,17,B); rect(t,5,17,26,17,D)
# Shelf 24x8 (3x1): board on top, two brackets
s=Image.new('RGBA',(24,8))
rect(s,0,0,23,0,L); rect(s,0,1,23,1,M); rect(s,0,2,23,2,D)
for x0 in (3,17):
    for k in range(5):
        rect(s,x0,3+k,x0+3-k if k<4 else x0,3+k,B)
    rect(s,x0,3,x0,7,D)
for n,im in (('table',t),('shelf',s)):
    im.save(f'{n}_1x.png')  # run from art/concepts/stations
    d=detail(im); d.save(f'../../../assets/objects/{n}.png')
    ic=Image.new('RGBA',(16,16)); sc=min(16/im.width,16/im.height)
    small=im.resize((max(1,round(im.width*sc)),max(1,round(im.height*sc))),Image.NEAREST)
    ic.paste(small,((16-small.width)//2,(16-small.height)//2+ (2 if n=='table' else 0)))
    for p in ('icons','held'): ic.save(f'../../../assets/items/{p}/{n}.png')
    d.resize((d.width*6,d.height*6),Image.NEAREST).save(f'view_{n}.png')
