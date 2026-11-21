"""Placeholder Wooden Chair: 2x3 tiles at detail 2 (32x48), backrest on the left, the
seat 12 world px (24 art px) above the floor. Icon and held sprite too. Run from the
repo root; keeps existing files unless --force."""
import os
import sys
from PIL import Image, ImageDraw

FORCE = "--force" in sys.argv
WOOD = (150, 104, 62)
LIGHT = (184, 134, 84)
DARK = (104, 70, 40)


def save(im, path):
    if os.path.exists(path) and not FORCE:
        print("kept", path)
        return
    im.save(path)
    print("wrote", path)


def chair():
    im = Image.new("RGBA", (32, 48))
    d = ImageDraw.Draw(im)
    # back legs and backrest (one post, left)
    d.rectangle([5, 6, 8, 47], fill=WOOD)
    d.line([(5, 6), (5, 47)], fill=LIGHT)
    d.line([(8, 6), (8, 47)], fill=DARK)
    d.rectangle([4, 4, 9, 7], fill=LIGHT)
    # backrest slats
    for y in (12, 18):
        d.rectangle([8, y, 12, y + 2], fill=WOOD)
    # seat at 24 art px above the floor (y = 48 - 24 = 24)
    d.rectangle([5, 22, 28, 25], fill=WOOD)
    d.line([(5, 22), (28, 22)], fill=LIGHT)
    d.line([(5, 25), (28, 25)], fill=DARK)
    # front leg
    d.rectangle([24, 26, 27, 47], fill=WOOD)
    d.line([(24, 26), (24, 47)], fill=LIGHT)
    d.line([(27, 26), (27, 47)], fill=DARK)
    # stretcher between the legs
    d.rectangle([9, 38, 24, 39], fill=DARK)
    return im


def main():
    c = chair()
    save(c, "assets/objects/chair.png")
    icon = Image.new("RGBA", (16, 16))
    small = c.resize((11, 16), Image.NEAREST)
    icon.alpha_composite(small, (3, 0))
    save(icon, "assets/items/icons/chair.png")
    save(c.resize((8, 12), Image.NEAREST), "assets/items/held/chair.png")


if __name__ == "__main__":
    main()
