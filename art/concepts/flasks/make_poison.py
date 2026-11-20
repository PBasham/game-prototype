import sys, math
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
import make_flasks as mf
from PIL import Image

GREEN = ((70, 150, 52), (126, 210, 84))
ASSETS = __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '../../../assets/items/')

# A round clay ball: a short cork and neck on a sphere, the wax strip around the middle.
def ball_profile(kind):
    if kind != 'ball':
        return orig(kind)
    p = {}
    for y in range(7, 10): p[y] = ('cork', 2)
    p[10] = ('lip', 3)
    p[11] = ('neck', 2)
    cy, r = 20.0, 8.6
    for y in range(12, 29):
        hw = int(round(math.sqrt(max(0, r * r - (y + 0.5 - cy) ** 2))))
        p[y] = ('body', max(2, min(9, hw)))
    return p, (19, 21), 14

orig = mf.profile
mf.profile = ball_profile

coat = mf.draw('thin', 'clay', GREEN, None, seed=5)
ball = mf.draw('ball', 'clay', GREEN, None, seed=6)

# 8x8 badges like heal.png / mana.png: a drop (coating) and a skull (thrown flask).
DROP = ["...d....", "..dxd...", "..dxd...", ".dxhxd..", "dxxxxxd.", "dxxxxxd.", ".dxxxd..", "..ddd..."]
SKULL = [".ddddd..", "dxxxxxd.", "dxdxdxd.", "dxxxxxd.", ".dxdxd..", ".ddddd..", "........", "........"]
def badge(pat, col):
    im = Image.new('RGBA', (8, 8))
    for y, row in enumerate(pat):
        for x, ch in enumerate(row):
            if ch == 'x': im.putpixel((x, y), col + (255,))
            elif ch == 'h': im.putpixel((x, y), (235, 255, 220, 255))
            elif ch == 'd': im.putpixel((x, y), (20, 30, 14, 255))
    return im

for name, im in (('poison_coating', coat), ('poison_flask', ball)):
    im.save(ASSETS + 'icons/%s.png' % name)
    im.save(ASSETS + 'held/%s.png' % name)
badge(DROP, GREEN[1]).save(ASSETS + 'badges/poison.png')
badge(SKULL, (226, 232, 214)).save(ASSETS + 'badges/poison_throw.png')
print('ok')
