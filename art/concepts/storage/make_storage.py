"""Placeholder art for the Lumber Rack (11 fill frames, 0% to 100% in 10% steps, logs
stacked in flat layers) and the Potion Cabinet (empty; the game draws the bottles in
the colors of what's inside). Detailed art: 2 art pixels per world pixel."""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, '../../../assets/')

def rack_frame(fill):
    W, H = 48, 48
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    post, postl, postd = (110, 72, 42), (146, 98, 58), (74, 46, 26)
    d.rectangle([1, 42, 46, 45], fill=post); d.line([(1, 42), (46, 42)], fill=postl); d.line([(1, 45), (46, 45)], fill=postd)
    for x0 in (2, 42):
        d.rectangle([x0, 8, x0 + 3, 44], fill=post); d.line([(x0, 8), (x0, 44)], fill=postl); d.line([(x0 + 3, 8), (x0 + 3, 44)], fill=postd)
        d.rectangle([x0 - 1, 6, x0 + 4, 8], fill=postl)
    # 5 rows of 5 log ends, filled bottom row first, left to right: flat layers.
    spots = [(9 + i * 7, 37 - row * 7) for row in range(5) for i in range(5)]
    for cx, cy in spots[:round(len(spots) * fill)]:
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(150, 104, 60), outline=(82, 52, 28))
        d.ellipse([cx - 1, cy - 1, cx + 1, cy + 1], outline=(196, 150, 96))
    return im

strip = Image.new('RGBA', (48 * 11, 48), (0, 0, 0, 0))
for k in range(11):
    strip.alpha_composite(rack_frame(k / 10.0), (48 * k, 0))
strip.save(os.path.join(ASSETS, 'objects/lumber_rack.png'))

def cabinet():
    W, H = 48, 64
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    wood, woodl, woodd = (92, 56, 34), (128, 82, 48), (60, 36, 20)
    d.rectangle([2, 2, 45, 61], fill=wood); d.rectangle([2, 2, 45, 5], fill=woodl); d.rectangle([2, 58, 45, 61], fill=woodd)
    d.rectangle([5, 7, 42, 56], fill=(34, 26, 30))
    for y in (22, 38, 54):
        d.rectangle([5, y, 42, y + 1], fill=woodl)
    d.line([(23, 7), (24, 56)], fill=woodd)
    d.rectangle([20, 30, 21, 33], fill=(214, 180, 90)); d.rectangle([26, 30, 27, 33], fill=(214, 180, 90))
    return im

cabinet().save(os.path.join(ASSETS, 'objects/potion_cabinet.png'))
# icons: the full rack and a cabinet with a few bottles, 16x16
for name, im in (('lumber_rack', rack_frame(1.0)), ('potion_cabinet', cabinet())):
    small = im.resize((16, 16) if name == 'lumber_rack' else (12, 16), Image.LANCZOS)
    c = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); c.alpha_composite(small, ((16 - small.width) // 2, 0))
    px = c.load()
    for y in range(16):
        for x in range(16):
            r, g, b, a = px[x, y]; px[x, y] = (r, g, b, 255 if a > 110 else 0)
    if name == 'potion_cabinet':
        for i, col in enumerate([(220, 70, 70), (70, 120, 230), (110, 200, 80)]):
            px[4 + i * 3, 5] = col + (255,); px[4 + i * 3, 4] = (205, 190, 170, 255)
    c.save(os.path.join(ASSETS, 'items/icons/%s.png' % name)); c.save(os.path.join(ASSETS, 'items/held/%s.png' % name))
print('ok')
