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
CLAY = [(128, 66, 44, 255), (176, 98, 66, 255), (200, 124, 88, 255)]  # matte terracotta
ROPE = [(120, 96, 60, 255), (170, 140, 92, 255)]
WATER = [(46, 96, 168, 255), (92, 158, 230, 255), (190, 225, 255, 255)]


def save(img, rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


def bucket(full):
    """A thick, rounded fired-clay pot with a rope handle: no metal bands or shine."""
    im = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(im)
    dark, mid, light = CLAY
    # Rope handle: a loop over the top, tied through two lugs.
    d.arc([6, 1, 25, 22], 195, 345, fill=ROPE[0], width=2)
    d.arc([7, 2, 24, 21], 200, 340, fill=ROPE[1], width=1)
    # Body: a squat rounded pot, wider in the belly.
    d.ellipse([4, 9, 27, 30], fill=mid)
    d.rectangle([7, 9, 24, 14], fill=mid)
    d.arc([4, 9, 27, 30], 20, 160, fill=dark, width=2)  # shade along the bottom
    # Rough clay texture: a few darker and lighter flecks, a soft (not shiny) side light.
    for p in [(9, 18), (14, 22), (20, 19), (23, 24), (11, 26), (17, 27), (21, 14)]:
        d.point(p, fill=dark)
    for p in [(8, 15), (8, 20), (9, 23), (10, 17)]:
        d.point(p, fill=light)
    # Lugs where the rope ties on.
    d.rectangle([4, 11, 6, 13], fill=dark)
    d.rectangle([25, 11, 27, 13], fill=dark)
    # A thick rim and the mouth.
    d.ellipse([6, 7, 25, 13], fill=dark)
    if full:
        d.ellipse([8, 8, 23, 12], fill=WATER[1])
        d.line([(11, 9), (15, 9)], fill=WATER[2])
    else:
        d.ellipse([8, 8, 23, 12], fill=(76, 38, 26, 255))
    return im


for iid, full in (("clay_bucket", False), ("clay_bucket_water", True)):
    im = bucket(full)
    save(im, "items/icons/%s.png" % iid)
    save(im, "items/held/%s.png" % iid)
