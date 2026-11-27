#!/usr/bin/env python3
"""Phase 65 placeholders: Abyssal Stone (128x128 terrain, like stone), its icon and held
sprite, and blocks.png row 23 (its collision row, a copy of stone's). Kept unless
--force (Patrick repaints them).

    python3 tools/make_abyss_art.py [--force]
"""
import os
import random
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


# Stone's picture, nearly black and cold blue, with a few faint teal glints.
src = Image.open(os.path.join(ASSETS, "terrain", "stone.png")).convert("RGBA")
out = src.copy()
px = out.load()
w, h = out.size
rnd = random.Random(65)
for y in range(h):
    for x in range(w):
        r, g, b, a = px[x, y]
        lum = (r * 0.3 + g * 0.59 + b * 0.11) / 255.0
        v = 18 + lum * 46
        px[x, y] = (int(v * 0.8), int(v * 0.9), int(v * 1.25), a)
for _ in range(70):
    x, y = rnd.randrange(w), rnd.randrange(h)
    for dx, dy in [(0, 0), (1, 0), (0, 1)] if rnd.random() < 0.4 else [(0, 0)]:
        px[(x + dx) % w, (y + dy) % h] = (60, 150, 160, 255)
block = out
save(block, "terrain/abyssal_stone.png")
icon = block.crop((0, 0, 32, 32)).resize((16, 16), Image.LANCZOS)
save(icon, "items/icons/abyssal_stone.png")
save(icon, "items/held/abyssal_stone.png")

atlas_path = os.path.join(ASSETS, "tiles", "blocks.png")
atlas = Image.open(atlas_path).convert("RGBA")
if atlas.height < 24 * 8:
    grown = Image.new("RGBA", (atlas.width, 24 * 8))
    grown.paste(atlas, (0, 0))
    grown.paste(atlas.crop((0, 2 * 8, atlas.width, 3 * 8)), (0, 23 * 8))  # like stone's row
    grown.save(atlas_path)
    print("blocks.png: added row 23")
