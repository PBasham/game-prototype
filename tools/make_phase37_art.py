"""Placeholder art for Phase 37: filled bottles and the storage furniture.

Potions (32x32, detail 2, from art/concepts/flasks/make_flasks.py, no badge; the badge
is the item's):
  items/{icons,held}/{healing,mana}_{clay_bottle,clay_jug,glass_vial,glass_bottle,glass_flask}.png
Furniture (detail 2: 2 art px per world px), icons and held 16x16 (the picture shrunk):
  pantry_rack 48x48, food_pantry 48x64, bookshelf 48x64, barrel 32x32, crate 32x32,
  hanging_net_small 48x32, hanging_net_medium 32x48, hanging_net_large 96x64 (each net:
  2 frames side by side, frame 0 the rope and bag, frame 1 the mesh drawn over what's
  inside), liquid_barrel 32x48, iron_liquid_barrel 32x48.
Run: python3 tools/make_phase37_art.py   (keeps existing files unless --force)
"""
import math
import os
import random
import sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "assets")
sys.path.insert(0, os.path.join(HERE, "..", "art", "concepts", "flasks"))
import make_flasks  # noqa: E402

FORCE = "--force" in sys.argv

WOOD = (120, 78, 48, 255)
WOOD_L = (150, 100, 62, 255)
WOOD_D = (84, 52, 32, 255)
BACK = (52, 38, 30, 255)
SHELF = (128, 86, 54, 255)
BRASS = (220, 180, 90, 255)
IRON = (120, 124, 130, 255)
IRON_L = (160, 164, 170, 255)
IRON_D = (78, 80, 86, 255)
ROPE = (196, 162, 102, 255)
ROPE_D = (150, 118, 70, 255)


def save(img, rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


def shrink(im: Image.Image) -> Image.Image:
    k = 16 / max(im.size)
    small = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", (16, 16))
    out.alpha_composite(small, ((16 - small.width) // 2, (16 - small.height) // 2))
    return out


def furniture(name: str, im: Image.Image, frame_w: int = 0) -> None:
    save(im, f"objects/{name}.png")
    first = im.crop((0, 0, frame_w, im.height)) if frame_w else im
    if frame_w:
        first = first.copy()
        first.alpha_composite(im.crop((frame_w, 0, frame_w * 2, im.height)))
    icon = shrink(first)
    save(icon, f"items/icons/{name}.png")
    save(icon, f"items/held/{name}.png")


# --- potions -------------------------------------------------------------------------
SHAPES = {"clay_bottle": ("regular", "clay"), "clay_jug": ("large", "clay"),
          "glass_vial": ("thin", "glass"), "glass_bottle": ("regular", "glass"),
          "glass_flask": ("large", "glass")}
for effect, liquid in (("healing", make_flasks.RED), ("mana", make_flasks.BLUE)):
    for bottle, (kind, mat) in SHAPES.items():
        im = make_flasks.draw(kind, mat, liquid, None, seed=3)
        save(im, f"items/icons/{effect}_{bottle}.png")
        save(im, f"items/held/{effect}_{bottle}.png")


# --- shelves -------------------------------------------------------------------------
def frame_box(w: int, h: int) -> Image.Image:
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w - 1, h - 1), fill=WOOD)
    d.rectangle((0, 0, w - 1, 3), fill=WOOD_L)
    d.rectangle((0, h - 3, w - 1, h - 1), fill=WOOD_D)
    d.rectangle((3, 4, w - 4, h - 4), fill=BACK)
    return im


def planks(im: Image.Image, ys: list) -> None:
    d = ImageDraw.Draw(im)
    for y in ys:
        d.rectangle((3, y, im.width - 4, y + 1), fill=SHELF)
        d.line((3, y + 2, im.width - 4, y + 2), fill=WOOD_D)


rack = Image.new("RGBA", (48, 48))
d = ImageDraw.Draw(rack)
d.rectangle((4, 2, 43, 45), fill=BACK)  # a solid back board
for x in (2, 44):
    d.rectangle((x, 0, x + 2, 47), fill=WOOD)
    d.line((x, 0, x, 47), fill=WOOD_L)
d.rectangle((0, 0, 47, 2), fill=WOOD_L)
planks(rack, [24, 44])
furniture("pantry_rack", rack)

pantry = frame_box(48, 64)
planks(pantry, [22, 40])
d = ImageDraw.Draw(pantry)
d.rectangle((3, 42, 44, 60), fill=WOOD)
d.line((24, 42, 24, 60), fill=WOOD_D)
for x0, x1 in ((5, 22), (26, 42)):
    d.rectangle((x0, 44, x1, 58), outline=WOOD_D)
d.rectangle((21, 50, 22, 52), fill=BRASS)
d.rectangle((26, 50, 27, 52), fill=BRASS)
furniture("food_pantry", pantry)

books = frame_box(48, 64)
planks(books, [20, 38])
d = ImageDraw.Draw(books)
d.rectangle((3, 41, 44, 60), fill=WOOD_D)  # the drawer, pulled open
d.rectangle((5, 44, 42, 57), fill=(40, 30, 24, 255))
d.rectangle((3, 58, 44, 60), fill=WOOD_L)  # its front, low
d.rectangle((22, 59, 25, 59), fill=BRASS)
furniture("bookshelf", books)


# --- barrel and crate ----------------------------------------------------------------
def barrel(w: int, h: int, wood: tuple, band: tuple, band_l: tuple, bands: list, rivets: bool = False) -> Image.Image:
    im = Image.new("RGBA", (w, h))
    for y in range(h):
        t = abs(y - h / 2) / (h / 2)
        half = (w / 2 - 1) * (0.86 + 0.14 * math.cos(t * math.pi / 2))
        for x in range(w):
            dx = x + 0.5 - w / 2
            if abs(dx) <= half:
                u = (dx / half + 1) / 2
                f = 0.72 + 0.5 * math.sin(u * math.pi) * 0.6
                c = tuple(min(255, int(v * f)) for v in wood[:3])
                if int(u * 6) != int((u + 1.0 / (2 * half)) * 6):
                    c = tuple(int(v * 0.7) for v in c)  # stave seams
                if any(b <= y < b + 2 for b in bands):
                    c = band_l[:3] if y in bands else band[:3]
                    if rivets and int(u * 8) % 2 == 0 and y in bands:
                        c = (200, 204, 210)
                im.putpixel((x, y), c + (255,))
    d = ImageDraw.Draw(im)
    d.ellipse((3, 0, w - 4, 4), fill=tuple(int(v * 0.6) for v in wood[:3]) + (255,), outline=band[:3] + (255,))
    return im


furniture("barrel", barrel(32, 32, WOOD_L, IRON_D, IRON, [6, 24]))

crate = Image.new("RGBA", (32, 32))
d = ImageDraw.Draw(crate)
d.rectangle((0, 0, 31, 31), fill=WOOD_L)
for y in (10, 20):
    d.line((2, y, 29, y), fill=WOOD_D)
d.rectangle((0, 0, 31, 31), outline=WOOD_D)
d.rectangle((1, 1, 30, 2), fill=WOOD)
d.rectangle((1, 29, 30, 30), fill=WOOD)
d.rectangle((1, 1, 2, 30), fill=WOOD)
d.rectangle((29, 1, 30, 30), fill=WOOD)
d.line((3, 4, 28, 27), fill=WOOD, width=2)
for (x, y) in ((2, 2), (28, 2), (2, 28), (28, 28)):
    d.point((x, y), fill=IRON_L)
furniture("crate", crate)

furniture("liquid_barrel", barrel(32, 48, WOOD_L, IRON_D, IRON_L, [6, 22, 38]))
iron = barrel(32, 48, IRON, IRON_D, IRON_L, [5, 21, 37], rivets=True)
d = ImageDraw.Draw(iron)
d.rectangle((24, 30, 30, 32), fill=BRASS)  # tap
d.rectangle((28, 32, 29, 35), fill=BRASS)
furniture("iron_liquid_barrel", iron)


# --- hanging nets --------------------------------------------------------------------
def net(w: int, h: int, ropes: list, top: int, side: int) -> Image.Image:
    """Two frames: rope and bag (back), then the mesh. The bag is a teardrop from `top`
    to the bottom, `side` px in from each edge."""
    random.seed(w * h)
    back = Image.new("RGBA", (w, h))
    mesh = Image.new("RGBA", (w, h))
    cx = w / 2
    half = w / 2 - side
    inside = set()
    for y in range(top, h - 1):
        t = (y - top) / max(1, h - 2 - top)
        hw = half * (0.22 + 0.78 * math.sin(math.pi / 2 * min(1.0, t / 0.75) ** 0.8))
        if t > 0.75:
            hw *= math.sqrt(max(0.0, 1 - ((t - 0.75) / 0.27) ** 2))
        hw = max(1.5, hw)
        for x in range(w):
            if abs(x + 0.5 - cx) <= hw:
                inside.add((x, y))
    for (x, y) in inside:
        back.putpixel((x, y), (46, 36, 26, 90))
        if (x + y) % 6 == 0 or (x - y) % 6 == 0:
            mesh.putpixel((x, y), ROPE_D if (x * 7 + y) % 5 else ROPE)
        edge = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1)))
        if edge:
            mesh.putpixel((x, y), ROPE_D)
    # The gathered top and the rope(s) up to the ceiling.
    gd = ImageDraw.Draw(mesh)
    gd.rectangle((int(cx - half * 0.5), top, int(cx + half * 0.5), top + 1), fill=ROPE)
    for rx in ropes:
        for y in range(0, top + 1):
            back.putpixel((rx, y), ROPE)
            back.putpixel((rx + 1, y), ROPE_D)
        gd.line((rx, top, int(cx), top + 1), fill=ROPE)
    out = Image.new("RGBA", (w * 2, h))
    out.alpha_composite(back, (0, 0))
    out.alpha_composite(mesh, (w, 0))
    return out


furniture("hanging_net_small", net(48, 32, [23], 7, 3), 48)
furniture("hanging_net_medium", net(32, 48, [15], 9, 2), 32)
furniture("hanging_net_large", net(96, 64, [23, 71], 9, 3), 96)
