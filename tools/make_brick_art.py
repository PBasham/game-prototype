#!/usr/bin/env python3
"""Placeholder brick art: Stone Bricks, Dark Forest Stone Bricks and Sand Bricks (blocks and walls),
built from each stone texture's own colors so they match. Also their item icons and
held sprites, and the Forest Spirit Pendant icon. Kept unless --force (Patrick
repaints them later).

    python3 tools/make_brick_art.py [--force]
"""
import os
import sys

import numpy as np
from PIL import Image

ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets")
SIZE = 64  # like the planks: 8x8 art pixels per block


def shades(stone: str) -> list:
    """Four shades (dark mortar to light face) from a stone texture, darkest first."""
    a = np.array(Image.open(os.path.join(ASSETS, "terrain", stone + ".png")).convert("RGB")).reshape(-1, 3)
    lum = a @ np.array([0.3, 0.59, 0.11])
    order = np.argsort(lum)
    pick = lambda q: a[order[int(q * (len(order) - 1))]]
    return [pick(0.04), pick(0.35), pick(0.6), pick(0.88)]


def bricks(stone: str, wall: bool) -> Image.Image:
    mortar, dark, mid, light = shades(stone)
    rng = np.random.default_rng(7 if not wall else 11)
    img = np.zeros((SIZE, SIZE, 3), dtype=float)
    bh, bw = 4, 8  # a brick: 8 wide, 4 tall (two rows per block)
    for y in range(SIZE):
        row = y // bh
        off = (bw // 2) if row % 2 else 0
        for x in range(SIZE):
            bx = (x + off) % bw
            by = y % bh
            if by == bh - 1 or bx == bw - 1:
                c = mortar
            else:
                cell = ((x + off) // bw, row)
                tone = mid if (hash(cell) % 3) else dark
                c = light if by == 0 else tone  # a lit top edge on each brick
                c = c * (0.94 + 0.12 * rng.random())
            img[y, x] = c
    if wall:
        img *= 0.62  # walls read darker, behind
    return Image.fromarray(np.clip(img, 0, 255).astype("uint8")).convert("RGBA")


def save(img: Image.Image, path: str, force: bool) -> None:
    if os.path.exists(path) and not force:
        print("kept", path)
        return
    img.save(path)
    print("wrote", path)


def icon(tex: Image.Image) -> tuple:
    big = tex.resize((32, 32), Image.NEAREST)
    ic = big.crop((8, 8, 24, 24)).copy()
    px = ic.load()
    for i in range(16):
        for p in [(i, 0), (i, 15), (0, i), (15, i)]:
            r, g, b, a = px[p]
            px[p] = (int(r * 0.65), int(g * 0.65), int(b * 0.65), a)
    return ic, big.crop((8, 8, 15, 15)).copy()


def pendant() -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    cord = (120, 92, 60, 255)
    for i in range(5):  # the cord, a V down to the gem
        px[3 + i, 1 + i] = cord
        px[12 - i, 1 + i] = cord
    gem = {(7, 7): 2, (8, 7): 2, (6, 8): 1, (7, 8): 3, (8, 8): 2, (9, 8): 1, (6, 9): 1, (7, 9): 2,
           (8, 9): 2, (9, 9): 0, (6, 10): 0, (7, 10): 1, (8, 10): 1, (9, 10): 0, (7, 11): 0, (8, 11): 0,
           (7, 12): 0}
    blues = [(30, 50, 140, 255), (60, 100, 220, 255), (110, 160, 255, 255), (210, 235, 255, 255)]
    for p, k in gem.items():
        px[p] = blues[k]
    px[7, 6] = (200, 170, 90, 255)  # the clasp
    px[8, 6] = (200, 170, 90, 255)
    return img


def main() -> None:
    force = "--force" in sys.argv
    for stone, name in [("stone", "stone_bricks"), ("dark_forest_stone", "dark_forest_stone_bricks"),
                        ("sand", "sand_bricks")]:
        block = bricks(stone, False)
        save(block, os.path.join(ASSETS, "terrain", name + ".png"), force)
        save(bricks(stone, True), os.path.join(ASSETS, "terrain", name + "_wall.png"), force)
        ic, held = icon(block)
        save(ic, os.path.join(ASSETS, "items", "icons", name + ".png"), force)
        save(held, os.path.join(ASSETS, "items", "held", name + ".png"), force)
    p = pendant()
    save(p, os.path.join(ASSETS, "items", "icons", "forest_spirit_pendant.png"), force)
    save(p.resize((9, 9), Image.NEAREST), os.path.join(ASSETS, "items", "held", "forest_spirit_pendant.png"), force)


if __name__ == "__main__":
    main()
