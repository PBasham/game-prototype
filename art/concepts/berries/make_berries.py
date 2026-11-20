"""Placeholder art for the raspberry and blueberry bushes and their foods.

Recolors the berry bush art (assets/decor/berry_bush*.png) and draws the fruit icons
and the two bowls. Run from the repo root:

    python3 art/concepts/berries/make_berries.py

Existing files are kept unless --force is given (Patrick's art is safe).
"""
import os
import sys

from PIL import Image

FORCE = "--force" in sys.argv

# The red berry colors in the plain bush art, mapped to each kind's colors.
RED = {
    (0xD0, 0x2A, 0x3A): 0, (0xE0, 0x30, 0x3F): 0, (0xC8, 0x28, 0x3A): 0,
    (0xA0, 0x1E, 0x2E): 1, (0x8A, 0x1A, 0x28): 2,
}
KINDS = {
    # name: (main, mid, dark, light, leaf tint)
    "raspberry": ((0xE8, 0x3C, 0x78), (0xB8, 0x24, 0x58), (0x7A, 0x14, 0x3A), (0xFF, 0x9C, 0xC0), (1.0, 1.0, 0.95)),
    "blueberry": ((0x5A, 0x6C, 0xD8), (0x40, 0x4C, 0xA8), (0x26, 0x2A, 0x6A), (0xB4, 0xC4, 0xFF), (0.9, 1.0, 1.08)),
}


def save(img: Image.Image, path: str) -> None:
    if os.path.exists(path) and not FORCE:
        print("kept", path)
        return
    img.save(path)
    print("wrote", path)


def tint(c, t):
    return tuple(max(0, min(255, int(c[i] * t[i]))) for i in range(3))


def bush(kind: str, src: str) -> Image.Image:
    main, mid, dark, light, leaf = KINDS[kind]
    im = Image.open(src).convert("RGBA")
    out = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            if a == 0:
                continue
            k = RED.get((r, g, b))
            if k is None:
                out.putpixel((x, y), tint((r, g, b), leaf) + (a,))
            else:
                out.putpixel((x, y), [main, mid, dark][k] + (a,))
    # A light glint on the top left pixel of each berry.
    for y in range(im.height):
        for x in range(im.width):
            if out.getpixel((x, y))[:3] == main and (x == 0 or out.getpixel((x - 1, y))[:3] not in (main, mid)) \
                    and (y == 0 or out.getpixel((x, y - 1))[:3] not in (main, mid)) and (x * 7 + y * 3) % 3 == 0:
                out.putpixel((x, y), light + (255,))
    return out


def fruit(kind: str) -> Image.Image:
    main, mid, dark, light, _ = KINDS[kind]
    im = Image.new("RGBA", (16, 16))
    centers = [(6, 8), (10, 8), (8, 11), (5, 12), (11, 12)]
    for cx, cy in centers:
        for y in range(-2, 2):
            for x in range(-2, 2):
                if (x + 0.5) ** 2 + (y + 0.5) ** 2 < 2.2 ** 2:
                    c = main
                    if kind == "raspberry" and (x + y) % 2 == 0:
                        c = mid  # bumpy drupelets
                    if y == 1 or x == 1 and y == 0:
                        c = dark if kind == "blueberry" else mid
                    im.putpixel((cx + x, cy + y), c + (255,))
        im.putpixel((cx - 1, cy - 1), light + (255,))
        if kind == "blueberry":
            im.putpixel((cx, cy - 2), dark + (255,))  # the little crown on top
    for p in [(8, 4), (9, 4), (10, 3), (9, 5), (8, 6)]:
        im.putpixel(p, (0x4A, 0x8A, 0x3A, 255))
    return im


def bowl(kind: str) -> Image.Image:
    main, mid, dark, light, _ = KINDS[kind]
    im = Image.open("assets/items/icons/wooden_bowl.png").convert("RGBA")
    # Fill: a heaped layer of fruit above the rim.
    for x in range(3, 13):
        im.putpixel((x, 8), (main if x % 3 else mid) + (255,))
    for x in range(4, 12):
        im.putpixel((x, 7), (main if (x + 1) % 3 else light) + (255,))
    for x in (5, 7, 9, 10):
        im.putpixel((x, 6), (mid if kind == "raspberry" else main) + (255,))
    im.putpixel((2, 8), (0x5C, 0x3C, 0x22, 255))
    im.putpixel((13, 8), (0x5C, 0x3C, 0x22, 255))
    if kind == "blueberry":
        for x in (4, 8, 11):
            im.putpixel((x, 8), dark + (255,))
    return im


def main() -> None:
    for kind in KINDS:
        for suffix in ("", "_young", "_bare"):
            save(bush(kind, "assets/decor/berry_bush%s.png" % suffix), "assets/decor/%s_bush%s.png" % (kind, suffix))
    for kind, item in (("raspberry", "raspberries"), ("blueberry", "blueberries")):
        icon = fruit(kind)
        save(icon, "assets/items/icons/%s.png" % item)
        save(icon.resize((9, 9), Image.NEAREST), "assets/items/held/%s.png" % item)
    for kind, item in (("raspberry", "raspberry_compote"), ("blueberry", "blueberry_mash")):
        b = bowl(kind)
        save(b, "assets/items/icons/%s.png" % item)
        save(b, "assets/items/held/%s.png" % item)


if __name__ == "__main__":
    main()
