#!/usr/bin/env python3
"""Phase 76 placeholders: Copper, Silver, Gold and Platinum coins (16x16 icon and held,
a small stack of two coins) and the coin pouch icon (ui/coin_pouch.png, 12x12). Kept
unless --force (Patrick repaints them).

Run: python3 tools/make_coin_art.py [--force]
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
FORCE = "--force" in sys.argv
METALS = {
    "copper_coin": [(122, 60, 30), (184, 98, 52), (226, 146, 90)],
    "silver_coin": [(110, 116, 124), (176, 182, 190), (230, 234, 238)],
    "gold_coin": [(150, 104, 20), (222, 172, 40), (255, 226, 120)],
    "platinum_coin": [(120, 140, 150), (196, 220, 226), (246, 252, 255)],
}


def save(img, rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


def coin(d, x, y, m):
    """A coin seen a little from above: an ellipse with a rim and a shine."""
    dark, mid, light = (c + (255,) for c in m)
    d.ellipse([x, y + 1, x + 9, y + 6], fill=dark)
    d.ellipse([x, y, x + 9, y + 5], fill=mid)
    d.ellipse([x + 2, y + 1, x + 7, y + 4], outline=light)
    d.point((x + 3, y + 1), fill=(255, 255, 255, 255))


for cid, m in METALS.items():
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    coin(d, 3, 8, m)
    coin(d, 4, 4, m)
    save(im, "items/icons/%s.png" % cid)
    save(im, "items/held/%s.png" % cid)

# The pouch: a little drawstring bag.
im = Image.new("RGBA", (12, 12))
d = ImageDraw.Draw(im)
d.ellipse([1, 3, 10, 11], fill=(120, 80, 44, 255))
d.ellipse([2, 4, 8, 9], fill=(150, 104, 60, 255))
d.rectangle([4, 1, 7, 3], fill=(120, 80, 44, 255))
d.line([3, 3, 8, 3], fill=(222, 172, 40, 255))
save(im, "ui/coin_pouch.png")
