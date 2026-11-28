#!/usr/bin/env python3
"""Phase 83: whole-block ore terrain (assets/terrain/<ore>_ore.png, 128x128 detailed, like
Terraria's ore blocks): the stone picture's shading mapped onto an ore palette, with
bright metallic glints, so the whole block reads as ore instead of stone with flecks.
Kept unless --force (Patrick repaints them).

Run: python3 tools/make_ore_art.py [--force]
"""
import os
import random
import sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "terrain")
FORCE = "--force" in sys.argv
# Dark to light, then the glint color, then an accent speck color (copper's green patina).
ORES = {
    "copper_ore": [(66, 34, 22), (112, 58, 34), (160, 88, 48), (204, 124, 66), (246, 186, 116), (92, 168, 140)],
    "iron_ore": [(54, 40, 38), (96, 68, 60), (138, 100, 86), (176, 138, 118), (226, 206, 190), (150, 70, 50)],
}


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def ramp(pal, v):
    """v 0..1 across the four body colors."""
    v = max(0.0, min(1.0, v)) * 3.0
    i = min(int(v), 2)
    return lerp(pal[i], pal[i + 1], v - i)


def make(name, pal):
    src = Image.open(os.path.join(ROOT, "stone.png")).convert("RGBA")
    out = Image.new("RGBA", src.size)
    sp, op = src.load(), out.load()
    lums = [sum(sp[x, y][:3]) / 3 for y in range(src.height) for x in range(src.width) if sp[x, y][3] > 0]
    lo, hi = min(lums), max(lums)
    rnd = random.Random(name)
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = sp[x, y]
            if a == 0:
                continue
            v = ((r + g + b) / 3 - lo) / max(hi - lo, 1)
            op[x, y] = ramp(pal, v * 1.1) + (a,)
    # Glints and specks in 2x2 art-pixel dots (one world pixel), on the lit parts.
    for _ in range(90):
        x, y = rnd.randrange(0, src.width - 2, 2), rnd.randrange(0, src.height - 2, 2)
        if sp[x, y][3] == 0:
            continue
        v = (sum(sp[x, y][:3]) / 3 - lo) / max(hi - lo, 1)
        if v < 0.45:
            continue
        col = pal[4] if rnd.random() < 0.8 else pal[5]
        for dx in (0, 1):
            for dy in (0, 1):
                op[x + dx, y + dy] = col + (255,)
    path = os.path.join(ROOT, name + ".png")
    if os.path.exists(path) and not FORCE:
        print("kept", name)
        return
    out.save(path)
    print("wrote", name)


for n, p in ORES.items():
    make(n, p)

# Item icons and held pictures (16x16): a corner of the new terrain, at world pixels.
# (Phase 83 wrote them over the old stone-with-nuggets icons.)
ITEMS = os.path.join(ROOT, "..", "items")
for n in ORES:
    tex = Image.open(os.path.join(ROOT, n + ".png")).convert("RGBA")
    icon = tex.crop((0, 0, 32, 32)).resize((16, 16), Image.NEAREST)
    for d in ("icons", "held"):
        path = os.path.join(ITEMS, d, n + ".png")
        if os.path.exists(path) and not FORCE:
            print("kept", d, n)
            continue
        icon.save(path)
        print("wrote", d, n)
