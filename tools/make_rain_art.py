#!/usr/bin/env python3
"""Phase 81 placeholders: the Rain Catcher (a wooden funnel with green slime seams over
a clay jug, 32x48) and the Clay Rain Catcher (a wide clay basin on a wooden stand,
48x48), at 2 art px a world px, plus their 16x16 item icons. Kept unless --force.

Run: python3 tools/make_rain_art.py [--force]
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
FORCE = "--force" in sys.argv
WOOD = [(92, 60, 34, 255), (132, 90, 52, 255), (170, 122, 74, 255)]
CLAY = [(120, 62, 40, 255), (168, 94, 62, 255), (206, 132, 92, 255)]
SLIME = (96, 200, 90, 255)


def save(img, rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


def catcher():
    im = Image.new("RGBA", (32, 48))
    d = ImageDraw.Draw(im)
    dark, mid, light = WOOD
    # Legs and a cross brace.
    for x in (3, 26):
        d.rectangle([x, 14, x + 2, 47], fill=mid)
        d.line([(x, 14), (x, 47)], fill=dark)
    d.line([(5, 40), (26, 28)], fill=dark, width=2)
    # The funnel: boards narrowing down, slime in the seams.
    d.polygon([(0, 4), (31, 4), (20, 18), (11, 18)], fill=mid)
    for x in (6, 12, 19, 25):
        d.line([(x, 4), (11 + (x - 0) * 9 // 31, 18)], fill=SLIME)
    d.line([(0, 4), (31, 4)], fill=light, width=2)
    d.line([(0, 4), (11, 18)], fill=dark)
    d.line([(31, 4), (20, 18)], fill=dark)
    # The clay jug under the spout.
    cd, cm, cl = CLAY
    d.rectangle([14, 18, 17, 22], fill=dark)
    d.ellipse([8, 22, 23, 46], fill=cm)
    d.ellipse([8, 22, 23, 46], outline=cd)
    d.line([(11, 28), (11, 40)], fill=cl)
    d.rectangle([12, 21, 19, 24], fill=cd)
    return im


def clay_catcher():
    im = Image.new("RGBA", (48, 48))
    d = ImageDraw.Draw(im)
    dark, mid, light = WOOD
    cd, cm, cl = CLAY
    # A stand: four legs and a shelf.
    for x in (6, 39):
        d.rectangle([x, 22, x + 2, 47], fill=mid)
        d.line([(x, 22), (x, 47)], fill=dark)
    d.rectangle([4, 36, 43, 38], fill=mid)
    d.line([(4, 36), (43, 36)], fill=light)
    # The wide basin.
    d.chord([0, 2, 47, 34], 0, 180, fill=cm)
    d.ellipse([0, 6, 47, 18], fill=cd)
    d.ellipse([3, 8, 44, 16], fill=(80, 42, 28, 255))
    d.arc([0, 6, 47, 18], 160, 380, fill=cl)
    d.line([(6, 20), (12, 28)], fill=cl)
    d.arc([0, 2, 47, 34], 0, 180, fill=cd)
    return im


for name, img in (("rain_catcher", catcher()), ("clay_rain_catcher", clay_catcher())):
    save(img, "objects/%s.png" % name)
    icon = img.resize((img.width // 3 if img.width == 48 else img.width // 2, img.height // 3), Image.NEAREST)
    canvas = Image.new("RGBA", (16, 16))
    canvas.paste(icon, ((16 - icon.width) // 2, 16 - icon.height), icon)
    save(canvas, "items/icons/%s.png" % name)
    save(canvas, "items/held/%s.png" % name)
