#!/usr/bin/env python3
"""Phase 90: the Dark Forest's stone and darkwood tree crowns retinted black, grey and
blue (Patrick: "a blue tint, but like a black / gray / blue tint"). Recolors in place by
luminance onto the palettes below, so the shapes and shading stay. Run once (it notes
what it did in assets/.dark_forest_tint so it won't tint twice; --force redoes it from
git's copy is up to you).

Run: python3 tools/make_dark_forest_tint.py
"""
import colorsys
import os
import sys

from PIL import Image

STAMP = "assets/.dark_forest_tint"
STONE = [(14, 17, 23), (28, 33, 42), (44, 51, 63), (64, 73, 88), (90, 101, 118)]
STONE_FILES = ["dark_forest_stone", "dark_forest_stone_wall", "dark_forest_stone_bricks",
               "dark_forest_stone_bricks_wall"]
# Crowns: dark blue-teal greens, a touch bluer than before.
LEAF_HUE = 0.55


def ramp(pal, v):
    v = max(0.0, min(1.0, v)) * (len(pal) - 1)
    i = min(int(v), len(pal) - 2)
    t = v - i
    return tuple(int(pal[i][k] + (pal[i + 1][k] - pal[i][k]) * t) for k in range(3))


def tint_stone(path):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    lums = [sum(px[x, y][:3]) / 3 for y in range(im.height) for x in range(im.width) if px[x, y][3]]
    lo, hi = min(lums), max(lums)
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            v = ((r + g + b) / 3 - lo) / max(hi - lo, 1)
            px[x, y] = ramp(STONE, v) + (a,)
    im.save(path)


def tint_crown(path):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if 0.2 < h < 0.5 and s > 0.15:  # the green crown, not the purple trunk
                r2, g2, b2 = colorsys.hsv_to_rgb(LEAF_HUE, min(s * 1.05, 1.0), v * 1.05)
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
            elif 0.75 < h or h < 0.05:  # trunk: a little bluer and greyer
                r2, g2, b2 = colorsys.hsv_to_rgb(0.72, s * 0.7, v)
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    im.save(path)


def main():
    if os.path.exists(STAMP) and "--force" not in sys.argv:
        print("already tinted (", STAMP, ")")
        return
    for f in STONE_FILES:
        p = "assets/terrain/%s.png" % f
        if os.path.exists(p):
            tint_stone(p)
            print("tinted", p)
    for i in range(3):
        p = "assets/trees/darkwood_%d.png" % i
        tint_crown(p)
        print("tinted", p)
    for d in ("icons", "held"):
        for f in ("dark_forest_stone", "dark_forest_stone_bricks"):
            p = "assets/items/%s/%s.png" % (d, f)
            if os.path.exists(p):
                tint_stone(p)
                print("tinted", p)
    open(STAMP, "w").write("Phase 90\n")


if __name__ == "__main__":
    main()
