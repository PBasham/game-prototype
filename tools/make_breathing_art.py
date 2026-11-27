#!/usr/bin/env python3
"""Phase 66 placeholders: Water Breathing in every bottle (32x32, like the other potions,
from art/concepts/flasks/make_flasks.py, sea green) and the Kelp item (16x16, from the
kelp decoration). Kept unless --force (Patrick repaints them).

  items/{icons,held}/water_breathing_{clay_flask,clay_bottle,clay_jug,glass_vial,glass_bottle,glass_flask}.png
  items/{icons,held}/kelp.png
Run: python3 tools/make_breathing_art.py [--force]
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "assets")
sys.path.insert(0, os.path.join(HERE, "..", "art", "concepts", "flasks"))
import make_flasks  # noqa: E402

FORCE = "--force" in sys.argv
SEA = ((40, 150, 130), (110, 215, 190))
SHAPES = {"clay_flask": ("thin", "clay"), "clay_bottle": ("regular", "clay"), "clay_jug": ("large", "clay"),
          "glass_vial": ("thin", "glass"), "glass_bottle": ("regular", "glass"), "glass_flask": ("large", "glass")}


def save(img, rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


for bottle, (kind, mat) in SHAPES.items():
    im = make_flasks.draw(kind, mat, SEA, None, seed=5)
    save(im, f"items/icons/water_breathing_{bottle}.png")
    save(im, f"items/held/water_breathing_{bottle}.png")

# Kelp: a frond, the kelp decoration's top over one stem piece, on 16x16.
top = Image.open(os.path.join(ROOT, "decor", "kelp_top.png")).convert("RGBA")
stem = Image.open(os.path.join(ROOT, "decor", "kelp.png")).convert("RGBA")
icon = Image.new("RGBA", (16, 16))
tw = top.resize((8, 8), Image.NEAREST)
sw = stem.resize((8, 8), Image.NEAREST)
icon.alpha_composite(sw, (5, 8))
icon.alpha_composite(tw, (4, 1))
icon.alpha_composite(sw.transpose(Image.FLIP_LEFT_RIGHT), (3, 8))
save(icon, "items/icons/kelp.png")
save(icon, "items/held/kelp.png")
