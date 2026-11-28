#!/usr/bin/env python3
"""Phase 81 placeholders: bottles of Salt Water (the water bottles with their blue turned
sea green), the Clay Bucket of Salt Water, and Salt (a small white heap). Kept unless
--force (Patrick repaints them).

Run: python3 tools/make_salt_art.py [--force]
"""
import colorsys
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "items")
FORCE = "--force" in sys.argv
BOTTLES = ["clay_flask", "clay_bottle", "clay_jug", "glass_vial", "glass_bottle", "glass_flask"]


def save(img, rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


def salty(src):
    """Blue pixels (the water) turned sea green and a little greyer."""
    im = Image.open(src).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.5 < h < 0.72 and s > 0.25:
                h = 0.47
                s *= 0.8
                r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return im


for b in BOTTLES:
    for d in ("icons", "held"):
        save(salty(os.path.join(ROOT, d, "water_%s.png" % b)), "%s/salt_water_%s.png" % (d, b))
for d in ("icons", "held"):
    save(salty(os.path.join(ROOT, d, "clay_bucket_water.png")), "%s/clay_bucket_salt_water.png" % d)

# Salt: a little white heap with grey shading and a few sparkles (32x32 detailed).
im = Image.new("RGBA", (32, 32))
dr = ImageDraw.Draw(im)
dr.polygon([(6, 26), (12, 16), (16, 12), (20, 15), (26, 26)], fill=(196, 196, 204, 255))
dr.polygon([(9, 26), (14, 17), (17, 14), (20, 18), (23, 26)], fill=(236, 236, 242, 255))
dr.line([(6, 26), (26, 26)], fill=(150, 150, 160, 255))
for p in [(14, 20), (18, 18), (16, 23), (21, 23), (11, 24)]:
    dr.point(p, fill=(255, 255, 255, 255))
save(im, "icons/salt.png")
save(im, "held/salt.png")
