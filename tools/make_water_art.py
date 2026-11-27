"""Placeholder art for Phase 54: water in every bottle, and the thirst and breath icons.

  items/{icons,held}/water_{clay_flask,clay_bottle,clay_jug,glass_vial,glass_bottle,glass_flask}.png
  ui/icon_thirst.png, ui/icon_breath.png (7x7, like the other status icons)
Run: python3 tools/make_water_art.py   (keeps existing files unless --force)
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "assets")
sys.path.insert(0, os.path.join(HERE, "..", "art", "concepts", "flasks"))
import make_flasks  # noqa: E402

FORCE = "--force" in sys.argv
WATER = ((70, 140, 210), (150, 205, 245))
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
    im = make_flasks.draw(kind, mat, WATER, None, seed=3)
    save(im, f"items/icons/water_{bottle}.png")
    save(im, f"items/held/water_{bottle}.png")

# A little bottle of water (thirst) and a bubble (breath), 7x7.
drop = Image.new("RGBA", (7, 7))
GLASS = (200, 225, 235, 255)
TEAL = (60, 196, 188, 255)
for x, y in [(2, 0), (3, 0), (4, 0)]:
    drop.putpixel((x, y), (150, 110, 80, 255))  # the cork
for y in range(1, 3):
    drop.putpixel((3, y), GLASS)
for y in range(3, 7):
    for x in range(1, 6):
        edge = x in (1, 5) or y == 6
        drop.putpixel((x, y), GLASS if edge else TEAL)
drop.putpixel((2, 4), (190, 245, 240, 255))
save(drop, "ui/icon_thirst.png")
bub = Image.new("RGBA", (7, 7))
for y in range(7):
    for x in range(7):
        d = ((x - 3) ** 2 + (y - 3) ** 2) ** 0.5
        if 2.2 <= d < 3.3:
            bub.putpixel((x, y), (180, 225, 250, 255))
bub.putpixel((2, 2), (255, 255, 255, 255))
save(bub, "ui/icon_breath.png")
