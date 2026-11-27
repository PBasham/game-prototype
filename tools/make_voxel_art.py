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


# Phase 55: Hard Sand (block and wall, 128x128 like sand) from the sand picture: darker,
# packed, with flat layers. Its icon and held sprite are the block shrunk. Row 22 of
# blocks.png is its collision row (a copy of stone's).
def hard_sand(src_name, out_name, darken):
    src = Image.open(os.path.join(ASSETS, "terrain", src_name)).convert("RGBA")
    out = src.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        band = 0.93 if (y // 6) % 3 == 0 else (1.04 if (y // 6) % 3 == 1 else 1.0)
        for x in range(w):
            r, g, b, a = px[x, y]
            k = darken * band
            # Packed sand: a bit redder and darker.
            px[x, y] = (min(255, int(r * k * 0.98)), min(255, int(g * k * 0.9)), min(255, int(b * k * 0.78)), a)
    save(out, "terrain/" + out_name)
    return out


block = hard_sand("sand.png", "hard_sand.png", 0.86)
hard_sand("sand_wall.png", "hard_sand_wall.png", 0.86)
icon = block.crop((0, 0, 32, 32)).resize((16, 16), Image.LANCZOS)
save(icon, "items/icons/hard_sand.png")
save(icon, "items/held/hard_sand.png")
atlas = Image.open(atlas_path).convert("RGBA")
if atlas.height < 23 * 8:
    grown = Image.new("RGBA", (atlas.width, 23 * 8))
    grown.paste(atlas, (0, 0))
    grown.paste(atlas.crop((0, 2 * 8, atlas.width, 3 * 8)), (0, 22 * 8))  # like stone's row
    grown.save(atlas_path)
    print("blocks.png: added row 22")
