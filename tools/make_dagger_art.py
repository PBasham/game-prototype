"""Placeholder Copper Dagger art (icon + held), cut down from the Copper Sword.
Run: python3 tools/make_dagger_art.py"""
from PIL import Image

for kind in ("icons", "held"):
    im = Image.open(f"assets/items/{kind}/copper_sword.png").convert("RGBA")
    px = im.load()
    out = Image.new("RGBA", im.size)
    o = out.load()
    for y in range(im.height):
        for x in range(im.width):
            # Keep the hilt and the first part of the blade (the sword runs from the
            # bottom left to the top right): distance along the blade = x + (15 - y).
            if x + (15 - y) <= 15:
                o[x, y] = px[x, y]
    # A point: the last blade pixel's color one step further, lighter.
    tip = None
    for y in range(im.height):
        for x in range(im.width):
            if o[x, y][3] and x + (15 - y) == 15:
                tip = (x, y)
    if tip:
        r, g, b, a = o[tip]
        o[tip[0] + 1, tip[1] - 1] = (min(r + 40, 255), min(g + 40, 255), min(b + 40, 255), a)
    out.save(f"assets/items/{kind}/copper_dagger.png")
print("wrote copper_dagger")
