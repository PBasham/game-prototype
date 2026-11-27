"""Placeholder 16x16 icons for the Empower tree's nodes (assets/ui/empower/<node id>.png),
drawn in a pixel circle by the Spell Weaving Table. Run: python3 tools/make_empower_icons.py
(keeps existing files unless --force)."""
import os
import sys
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "empower")
FORCE = "--force" in sys.argv
L = (236, 226, 200, 255)  # light
M = (176, 160, 128, 255)
D = (96, 80, 60, 255)
GOLD = (232, 190, 90, 255)
BLUE = (110, 170, 240, 255)
RED = (232, 96, 60, 255)
GREEN = (110, 200, 90, 255)


def new():
    im = Image.new("RGBA", (16, 16))
    return im, ImageDraw.Draw(im)


def power():  # a pick head
    im, d = new()
    d.line((2, 6, 8, 3), fill=L, width=2)
    d.line((8, 3, 14, 6), fill=L, width=2)
    d.line((8, 4, 8, 14), fill=M, width=2)
    return im


def sharp():  # an axe head
    im, d = new()
    d.line((5, 2, 5, 14), fill=M, width=2)
    d.polygon([(6, 3), (13, 2), (14, 8), (6, 8)], fill=L)
    return im


def area():  # arrows out to four corners
    im, d = new()
    d.rectangle((6, 6, 9, 9), fill=M)
    for (x, y, dx, dy) in ((1, 1, 1, 1), (14, 1, -1, 1), (1, 14, 1, -1), (14, 14, -1, -1)):
        d.line((x, y, x + 3 * dx, y + 3 * dy), fill=L)
        d.line((x, y, x + 3 * dx, y), fill=L)
        d.line((x, y, x, y + 3 * dy), fill=L)
    return im


def reach():  # a reaching hand
    im, d = new()
    d.rectangle((1, 8, 7, 11), fill=M)  # forearm
    d.rectangle((7, 6, 10, 12), fill=L)  # palm
    for i, y in enumerate((5, 7, 9, 11)):
        d.line((11, y, 14 - (i % 2), y), fill=L)  # fingers
    d.line((8, 5, 9, 3), fill=L)  # thumb
    return im


def drop():
    im, d = new()
    d.polygon([(8, 1), (13, 9), (3, 9)], fill=BLUE)
    d.ellipse((3, 6, 13, 15), fill=BLUE)
    d.point((6, 10), fill=L)
    return im


def flame():
    im, d = new()
    d.polygon([(8, 1), (13, 9), (11, 14), (5, 14), (3, 9)], fill=RED)
    d.polygon([(8, 6), (10, 11), (8, 14), (6, 11)], fill=GOLD)
    return im


def arc():  # zigzag
    im, d = new()
    d.line([(2, 3), (7, 7), (5, 9), (13, 14)], fill=GOLD, width=2)
    return im


def distance():  # a swoosh
    im, d = new()
    d.arc((1, 3, 15, 17), 200, 330, fill=L, width=2)
    d.polygon([(13, 6), (15, 9), (11, 9)], fill=L)
    return im


def lasting():  # an hourglass
    im, d = new()
    d.line((4, 2, 12, 2), fill=M, width=2)
    d.line((4, 14, 12, 14), fill=M, width=2)
    d.polygon([(5, 3), (11, 3), (8, 8)], fill=GOLD)
    d.polygon([(8, 8), (11, 13), (5, 13)], outline=L)
    d.polygon([(7, 11), (9, 11), (10, 13), (6, 13)], fill=GOLD)
    return im


def evolve():  # a slime with an up arrow
    im, d = new()
    d.pieslice((2, 6, 14, 20), 180, 360, fill=GREEN)
    d.point((6, 10), fill=D)
    d.point((10, 10), fill=D)
    d.polygon([(8, 0), (11, 4), (5, 4)], fill=GOLD)
    return im


def limit():  # two small orbs and a plus
    im, d = new()
    d.ellipse((1, 6, 6, 11), fill=BLUE)
    d.ellipse((10, 6, 15, 11), fill=BLUE)
    d.line((8, 5, 8, 12), fill=GOLD)
    d.line((5, 8, 11, 8), fill=GOLD)
    return im


ICONS = {"mining_power": power, "chopping_power": sharp, "mining_area": area, "gather_reach": reach,
         "efficient": drop, "potency": flame, "arc": arc, "distance": distance, "lasting": lasting,
         "evolve": evolve, "limit": limit}
os.makedirs(OUT, exist_ok=True)
for name, fn in ICONS.items():
    path = os.path.join(OUT, name + ".png")
    if os.path.exists(path) and not FORCE:
        print("kept", name)
        continue
    fn().save(path)
    print("wrote", name)
