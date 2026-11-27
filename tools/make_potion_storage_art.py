"""Placeholder art for Phase 35: the potion furniture and the new materials and bottles.

Furniture (detail 2: 2 art px per world px; bottles are drawn on the shelves in code):
  objects/potion_cabinet.png   48x80  (3x5 tiles) glass doors, 4 shelves
  objects/potion_bookcase.png  64x96  (4x6 tiles) glass doors, 5 shelves
  (both: 2 frames side by side, the cabinet then its glass doors, drawn over the bottles)
  objects/potion_shelf.png     48x32  (3x2 tiles) a wall shelf with brackets
  items/{icons,held}/<that>.png 16x16, the same picture shrunk
Bottles: the flask concepts (art/concepts/flasks, 32x32) copied as icons and held art.
Materials: items/{icons,held}/{sand,glass}.png 16x16.
Run: python3 tools/make_potion_storage_art.py
"""
import random
import shutil
from PIL import Image, ImageDraw

WOOD = (120, 78, 48, 255)
WOOD_L = (150, 100, 62, 255)
WOOD_D = (84, 52, 32, 255)
BACK = (38, 30, 34, 255)
SHELF = (128, 86, 54, 255)
GLASS = (190, 225, 240, 60)
GLASS_EDGE = (210, 240, 250, 140)
BRASS = (220, 180, 90, 255)


def cabinet(w: int, h: int, shelves: list, doors: bool) -> Image.Image:
    """Two frames side by side: the cabinet (frame 0), and its glass doors (frame 1),
    drawn over the bottles so they stand behind the glass."""
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 2, w - 1, h - 1), fill=WOOD)  # body
    d.rectangle((0, 0, w - 1, 3), fill=WOOD_L)  # top (flat: things can stand on it)
    d.rectangle((0, h - 4, w - 1, h - 1), fill=WOOD_D)  # plinth
    d.rectangle((3, 5, w - 4, h - 5), fill=BACK)  # inside
    for y in shelves:  # shelf planks: bottles stand on these (y = the plank's top)
        d.rectangle((3, y, w - 4, y + 1), fill=SHELF)
    front = Image.new("RGBA", (w, h))
    if doors:
        fd = ImageDraw.Draw(front)
        mid = w // 2
        for x0, x1 in ((3, mid - 1), (mid + 1, w - 4)):
            pane = Image.new("RGBA", (x1 - x0 + 1, h - 9), GLASS)
            front.alpha_composite(pane, (x0, 5))
            # A glint across each pane.
            for k in range(6):
                px, py = x0 + 2 + k, 8 + k * 2
                if px <= x1 and py < h - 6:
                    front.putpixel((px, py), GLASS_EDGE)
        fd.line((mid, 5, mid, h - 5), fill=WOOD_D)
        fd.rectangle((mid - 3, h // 2 - 2, mid - 2, h // 2 + 2), fill=BRASS)
        fd.rectangle((mid + 2, h // 2 - 2, mid + 3, h // 2 + 2), fill=BRASS)
    out = Image.new("RGBA", (w * 2, h))
    out.alpha_composite(im, (0, 0))
    out.alpha_composite(front, (w, 0))
    return out


def wall_shelf(w: int, h: int) -> Image.Image:
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    plank = h - 6
    d.rectangle((0, plank, w - 1, plank + 2), fill=WOOD_L)
    d.rectangle((0, plank + 3, w - 1, plank + 3), fill=WOOD_D)
    for x in (4, w - 6):  # brackets
        d.polygon([(x, plank + 4), (x + 2, plank + 4), (x + 2, h - 1)], fill=WOOD_D)
    return im


def shrink(im: Image.Image) -> Image.Image:
    k = 16 / max(im.size)
    small = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", (16, 16))
    out.alpha_composite(small, ((16 - small.width) // 2, (16 - small.height) // 2))
    return out


def sand() -> Image.Image:
    random.seed(7)
    im = Image.new("RGBA", (16, 16))
    for y in range(7, 15):
        half = min(int((y - 6) * 0.9) + 2, 8)
        for x in range(8 - half, 8 + half):
            c = random.choice([(222, 200, 140), (210, 186, 126), (232, 214, 160), (198, 172, 112)])
            im.putpixel((x, y), c + (255,))
    return im


def glass() -> Image.Image:
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    d.polygon([(3, 4), (12, 2), (13, 12), (4, 14)], fill=(170, 215, 235, 170), outline=(120, 170, 195, 255))
    d.line((5, 6, 9, 5), fill=(240, 250, 255, 230))
    d.line((5, 8, 7, 8), fill=(240, 250, 255, 200))
    return im


furniture = {
    "potion_cabinet": cabinet(48, 80, [72, 56, 40, 24], True),
    "potion_bookcase": cabinet(64, 96, [88, 72, 56, 40, 24], True),
    "potion_shelf": wall_shelf(48, 32),
}
for name, im in furniture.items():
    im.save(f"assets/objects/{name}.png")
    if name != "potion_shelf":  # two frames: the icon is both together
        w = im.width // 2
        whole = im.crop((0, 0, w, im.height))
        whole.alpha_composite(im.crop((w, 0, w * 2, im.height)))
        im = whole
    shrink(im).save(f"assets/items/icons/{name}.png")
    shrink(im).save(f"assets/items/held/{name}.png")
for name, src in [("clay_bottle", "clay_regular_empty"), ("clay_jug", "clay_large_empty"),
                  ("glass_vial", "glass_thin_empty"), ("glass_bottle", "glass_regular_empty"),
                  ("glass_flask", "glass_large_empty")]:
    for kind in ("icons", "held"):
        shutil.copy(f"art/concepts/flasks/{src}.png", f"assets/items/{kind}/{name}.png")
for name, fn in (("sand", sand), ("glass", glass)):
    for kind in ("icons", "held"):
        fn().save(f"assets/items/{kind}/{name}.png")
print("wrote potion storage, bottles, sand, glass")
