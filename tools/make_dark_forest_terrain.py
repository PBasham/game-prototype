#!/usr/bin/env python3
"""Placeholder Dark Forest terrain and item art: blends the dirt and stone textures (and
their walls, icons and held sprites) toward a blue-black. Patrick repaints these later.

    python3 tools/make_dark_forest_terrain.py            # keeps existing files
    python3 tools/make_dark_forest_terrain.py --force    # remakes them
    --dirt=0.9,0.42 --stone=0.9,0.52 --dirt_wall=0.9,0.85  # blend amount, brightness

Each pixel moves `amount` of the way to its own brightness in blue (BLUE), then is
scaled by `brightness`. Writes assets/terrain/dark_forest_{dirt,dirt_wall,stone,
stone_wall}.png and assets/items/{icons,held}/dark_forest_{dirt,stone}.png.
"""
import os
import sys

import numpy as np
from PIL import Image

ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets")
BLUE = np.array([0.80, 0.90, 1.25])  # the blue a gray pixel turns into


def tint(src: str, out: str, amount: float, brightness: float, force: bool) -> None:
    if os.path.exists(out) and not force:
        print("kept", out)
        return
    a = np.array(Image.open(src).convert("RGBA")).astype(float)
    rgb = a[:, :, :3]
    lum = (rgb * np.array([0.3, 0.59, 0.11])).sum(2, keepdims=True)
    a[:, :, :3] = np.clip((rgb * (1 - amount) + lum * BLUE * amount) * brightness, 0, 255)
    Image.fromarray(a.astype("uint8")).save(out)
    print("wrote", out)


def main() -> None:
    force = "--force" in sys.argv
    # Blend amount and brightness per texture. Walls start much darker than blocks, so
    # they keep more of their brightness (or the background goes black).
    look = {"dirt": (0.9, 0.42), "stone": (0.9, 0.52), "dirt_wall": (0.9, 0.85), "stone_wall": (0.9, 0.9)}
    for arg in sys.argv[1:]:
        for k in sorted(look, key=len, reverse=True):  # dirt_wall before dirt
            if arg.startswith("--%s=" % k):
                look[k] = tuple(float(v) for v in arg.split("=", 1)[1].split(","))
    for name in ["dirt", "dirt_wall", "stone", "stone_wall"]:
        t = os.path.join(ASSETS, "terrain")
        tint(os.path.join(t, name + ".png"), os.path.join(t, "dark_forest_%s.png" % name), *look[name], force)
    for name in ["dirt", "stone"]:
        for d in ["icons", "held"]:
            folder = os.path.join(ASSETS, "items", d)
            tint(os.path.join(folder, name + ".png"), os.path.join(folder, "dark_forest_%s.png" % name), *look[name], force)


if __name__ == "__main__":
    main()
