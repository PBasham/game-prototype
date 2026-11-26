"""Placeholder art for the Phase 25 Storm gear: Dual Storm Axes (held: one axe; icon:
two crossed) and the Storm Charm. 16x16 like the other weapons.
Run: python3 tools/make_storm_art.py"""
from PIL import Image

HANDLE = (92, 70, 52, 255)
HANDLE_D = (62, 46, 36, 255)
STEEL = (120, 170, 215, 255)
STEEL_L = (190, 225, 250, 255)
STEEL_D = (70, 110, 160, 255)
BOLT = (255, 230, 90, 255)


def axe() -> Image.Image:
    im = Image.new("RGBA", (16, 16))
    px = im.load()
    # Handle: bottom left to the head, top right.
    for i in range(11):
        x, y = 2 + i, 13 - i
        px[x, y] = HANDLE
        if y + 1 < 16:
            px[x, y + 1] = HANDLE_D
    # Head: a blade on the upper side of the handle's end.
    head = [(9, 2), (10, 2), (11, 2), (8, 3), (9, 3), (10, 3), (11, 3), (12, 3),
            (8, 4), (9, 4), (10, 4), (11, 4), (8, 5), (9, 5), (10, 5), (9, 6)]
    for (x, y) in head:
        px[x, y] = STEEL
    for (x, y) in [(9, 2), (8, 3), (8, 4), (8, 5)]:
        px[x, y] = STEEL_L  # the edge
    for (x, y) in [(11, 4), (10, 5), (9, 6)]:
        px[x, y] = STEEL_D
    px[10, 3] = BOLT  # the storm in it
    px[9, 4] = BOLT
    return im


def crossed() -> Image.Image:
    a = axe()
    b = a.transpose(Image.FLIP_LEFT_RIGHT)
    out = Image.new("RGBA", (16, 16))
    out.alpha_composite(b)
    out.alpha_composite(a)
    return out


def charm() -> Image.Image:
    im = Image.new("RGBA", (16, 16))
    px = im.load()
    cord = (150, 120, 80, 255)
    for i in range(5):
        px[5 + i, 2 + i // 2] = cord
        px[10 - i, 2 + i // 2] = cord
    gem = [(x, y) for y in range(6, 13) for x in range(5, 11) if abs(x - 7.5) + abs(y - 9) <= 3.6]
    for (x, y) in gem:
        px[x, y] = STEEL
    for (x, y) in gem:
        if x + y <= 14:
            px[x, y] = STEEL_L
    for (x, y) in [(8, 7), (7, 8), (8, 9), (7, 10)]:
        px[x, y] = BOLT  # a little zigzag
    return im


held = axe()
held.save("assets/items/held/dual_storm_axes.png")
crossed().save("assets/items/icons/dual_storm_axes.png")
charm().save("assets/items/icons/storm_charm.png")
charm().save("assets/items/held/storm_charm.png")
print("wrote dual_storm_axes, storm_charm")
