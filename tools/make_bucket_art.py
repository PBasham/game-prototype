#!/usr/bin/env python3
"""Phase 79 placeholders: the Clay Bucket, empty and full of water (32x32 detailed icon
and held, the same picture). Kept unless --force (Patrick repaints them).

Run: python3 tools/make_bucket_art.py [--force]
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
FORCE = "--force" in sys.argv
CLAY = [(110, 58, 38, 255), (164, 92, 60, 255), (204, 128, 88, 255)]
WATER = [(46, 96, 168, 255), (92, 158, 230, 255), (190, 225, 255, 255)]


def save(img, rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


def bucket(full):
    im = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(im)
    dark, mid, light = CLAY
    # Handle: a thin arc over the top.
    d.arc([7, 2, 24, 20], 200, 340, fill=dark, width=2)
    # Body: a tapered pot, wider at the top.
    d.polygon([(6, 11), (25, 11), (22, 28), (9, 28)], fill=mid)
    d.line([(9, 28), (22, 28)], fill=dark, width=1)
    d.line([(6, 11), (9, 28)], fill=dark)
    d.line([(25, 11), (22, 28)], fill=dark)
    d.line([(10, 14), (11, 25)], fill=light)
    # Bands.
    d.line([(7, 17), (24, 17)], fill=dark)
    d.line([(8, 23), (23, 23)], fill=dark)
    # Rim and mouth.
    d.ellipse([5, 8, 26, 14], fill=dark)
    if full:
        d.ellipse([7, 9, 24, 13], fill=WATER[1])
        d.line([(10, 10), (14, 10)], fill=WATER[2])
        d.point((19, 12), fill=WATER[0])
    else:
        d.ellipse([7, 9, 24, 13], fill=(70, 36, 24, 255))
    d.arc([5, 8, 26, 14], 160, 380, fill=light)
    return im


for iid, full in (("clay_bucket", False), ("clay_bucket_water", True)):
    im = bucket(full)
    save(im, "items/icons/%s.png" % iid)
    save(im, "items/held/%s.png" % iid)
