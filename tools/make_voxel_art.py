#!/usr/bin/env python3
"""Phase 52 placeholders: the Bomb's icon and held sprite, and blocks.png row 21 (Sand
Bricks' collision row). Kept unless --force (Patrick repaints them).

    python3 tools/make_voxel_art.py [--force]
"""
import os
import sys

from PIL import Image

ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets")
force = "--force" in sys.argv


def save(img, rel):
    path = os.path.join(ASSETS, rel)
    if os.path.exists(path) and not force:
        print("kept", path)
        return
    img.save(path)
    print("wrote", path)


def bomb():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    cx, cy, r = 7.5, 9.5, 5.2
    for y in range(16):
        for x in range(16):
            d = ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5
            if d < r:
                lit = max(0.0, 1.0 - (((x + 0.5 - (cx - 2)) ** 2 + (y + 0.5 - (cy - 2)) ** 2) ** 0.5) / 6.0)
                v = int(34 + 70 * lit)
                px[x, y] = (v, v, int(v * 1.1), 255)
    for p in [(7, 3), (8, 3)]:  # the cap
        px[p] = (120, 110, 100, 255)
    px[7, 4] = (90, 84, 78, 255)
    px[8, 4] = (90, 84, 78, 255)
    for p, c in [((9, 2), (170, 130, 80)), ((10, 1), (170, 130, 80)), ((11, 0), (255, 200, 80)), ((12, 1), (255, 140, 40))]:
        px[p] = c + (255,)  # fuse and spark
    return img


b = bomb()
save(b, "items/icons/bomb.png")
save(b.resize((9, 9), Image.NEAREST), "items/held/bomb.png")

atlas_path = os.path.join(ASSETS, "tiles", "blocks.png")
atlas = Image.open(atlas_path).convert("RGBA")
if atlas.height < 22 * 8:
    grown = Image.new("RGBA", (atlas.width, 22 * 8))
    grown.paste(atlas, (0, 0))
    grown.paste(atlas.crop((0, 17 * 8, atlas.width, 18 * 8)), (0, 21 * 8))  # like Stone Bricks' row
    grown.save(atlas_path)
    print("blocks.png: added row 21")
