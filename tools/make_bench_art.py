#!/usr/bin/env python3
"""Phase 67 placeholders: the Alchemist's Bench object (96x64, 2x detail), its 16x16
item icon, the Murky Mixture (32x32) and the bench window's tabletop art (assets/ui/,
2 art pixels per HUD pixel, drawn at half size like item icons):

  bench_table.png   the plank tabletop (452 x 352)
  bench_mortar.png  a stone mortar and pestle (96 x 76)
  bench_bowl.png    a glazed mixing bowl; the window paints the brew inside (188 x 92)
  bench_stand.png   a little wooden bottle stand with a brass ring (72 x 92)

Kept unless --force (Patrick repaints them). Run: python3 tools/make_bench_art.py [--force]
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
rnd = random.Random(67)


def save(img, rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", rel)


def band(ramp, t):
    """A color from a dark-to-light ramp by t in 0..1 (banded, no smooth gradient)."""
    t = min(max(t, 0.0), 0.999)
    return ramp[int(t * len(ramp))]


# --- the tabletop: planks with grain, seams and knots ---------------------------------------
WOOD = [(58, 34, 20), (72, 43, 25), (86, 52, 30), (100, 62, 36), (114, 72, 42)]


def tabletop(w, h):
    im = Image.new("RGBA", (w, h))
    px = im.load()
    plank_h = 44
    for y in range(h):
        p = y // plank_h
        shade = (p * 37 % 5) / 10.0 - 0.2
        for x in range(w):
            yy = y % plank_h
            g = math.sin(yy * 0.55 + math.sin(x * 0.011 + p * 2.3) * 3.0 + math.sin(x * 0.037 + p) * 0.8) * 0.5 + 0.5
            t = 0.5 + shade + (g - 0.5) * 0.22
            # Darker toward the edges (a soft vignette, in bands).
            e = min(x, w - 1 - x, y, h - 1 - y)
            t -= max(0, 24 - e) * 0.012
            c = band(WOOD, t)
            px[x, y] = c + (255,)
        if y % plank_h == 0:
            for x in range(w):
                px[x, y] = (40, 22, 12, 255)
        elif y % plank_h == 1:
            for x in range(w):
                px[x, y] = (128, 84, 50, 255)
    d = ImageDraw.Draw(im)
    for _ in range(9):  # knots
        x, y = rnd.randrange(30, w - 30), rnd.randrange(8, h - 8)
        if y % plank_h < 8 or y % plank_h > plank_h - 8:
            continue
        d.ellipse([x - 5, y - 3, x + 5, y + 3], fill=(66, 38, 22, 255))
        d.ellipse([x - 2, y - 1, x + 2, y + 1], fill=(50, 28, 16, 255))
    return im


# --- a stone mortar and a wooden pestle ----------------------------------------------------
STONE = [(70, 72, 78), (92, 95, 100), (116, 118, 122), (140, 142, 144), (166, 167, 166)]


def mortar():
    w, h = 96, 76
    im = Image.new("RGBA", (w, h))
    px = im.load()
    cx, top = 44, 30
    rx, ry = 34, 11
    # Body: a half egg under the rim, lit from the upper left.
    for y in range(top, h - 4):
        k = (y - top) / (h - 4 - top)
        half = rx * math.sqrt(max(0.0, 1 - k * k * 0.85)) * (1 - k * 0.25)
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x - (cx - half)) / max(2 * half, 1)
            px[x, y] = band(STONE, 0.85 - u * 0.75 - k * 0.25) + (255,)
    d = ImageDraw.Draw(im)
    d.rectangle([cx - 20, h - 6, cx + 20, h - 2], fill=STONE[0] + (255,))  # foot
    d.rectangle([cx - 18, h - 6, cx + 4, h - 5], fill=STONE[2] + (255,))
    # Rim and the dark hollow.
    d.ellipse([cx - rx, top - ry, cx + rx, top + ry], fill=STONE[3] + (255,))
    d.ellipse([cx - rx + 1, top - ry + 1, cx + rx - 1, top + ry - 2], fill=STONE[4] + (255,))
    d.ellipse([cx - rx + 5, top - ry + 4, cx + rx - 5, top + ry - 3], fill=(44, 40, 40, 255))
    d.ellipse([cx - rx + 9, top - ry + 7, cx + rx - 9, top + ry - 3], fill=(56, 52, 50, 255))
    # Pestle leaning out to the upper right.
    for i in range(40):
        x = cx + 8 + i * 0.95
        y = top - 2 - i * 0.62
        for t in range(-3, 4):
            c = (150, 104, 62) if t < 0 else (118, 78, 44) if t < 2 else (88, 56, 30)
            px[int(x + t * 0.5), int(y + t * 0.8)] = c + (255,)
    d.ellipse([cx + 44, top - 32, cx + 52, top - 22], fill=(150, 104, 62, 255))
    return im


# --- a glazed mixing bowl ------------------------------------------------------------------
GLAZE = [(52, 74, 92), (66, 96, 118), (82, 120, 144), (104, 146, 168), (138, 176, 192)]
CLAY = [(110, 64, 40), (140, 84, 52), (168, 106, 66)]


def bowl():
    w, h = 188, 92
    im = Image.new("RGBA", (w, h))
    px = im.load()
    cx, top = 94, 26
    rx, ry = 88, 22
    for y in range(top, h - 6):
        k = (y - top) / (h - 6 - top)
        half = rx * math.sqrt(max(0.0, 1 - k * k)) * (1 - k * 0.15)
        for x in range(int(cx - half), int(cx + half) + 1):
            u = (x - (cx - half)) / max(2 * half, 1)
            t = 0.9 - u * 0.7 - k * 0.3
            px[x, y] = band(GLAZE, t) + (255,)
    d = ImageDraw.Draw(im)
    # A clay band low on the body and a clay foot.
    for y in range(top + 30, top + 34):
        for x in range(w):
            if px[x, y][3]:
                px[x, y] = band(CLAY, 0.9 - (x / w) * 0.9) + (255,)
    d.rectangle([cx - 30, h - 8, cx + 30, h - 2], fill=CLAY[0] + (255,))
    d.rectangle([cx - 28, h - 8, cx + 6, h - 7], fill=CLAY[2] + (255,))
    # Rim (light), then the hollow the window paints the brew into.
    d.ellipse([cx - rx, top - ry, cx + rx, top + ry], fill=GLAZE[3] + (255,))
    d.ellipse([cx - rx + 2, top - ry + 1, cx + rx - 2, top + ry - 2], fill=GLAZE[4] + (255,))
    d.ellipse([cx - rx + 7, top - ry + 5, cx + rx - 7, top + ry - 3], fill=(30, 36, 44, 255))
    d.ellipse([cx - rx + 12, top - ry + 9, cx + rx - 12, top + ry - 3], fill=(38, 46, 56, 255))
    # A glint on the rim.
    d.line([cx - 60, top - 18, cx - 40, top - 21], fill=(220, 236, 240, 255), width=2)
    return im


# --- a bottle stand ------------------------------------------------------------------------
BRASS = [(120, 84, 30), (168, 122, 44), (214, 170, 70), (240, 214, 120)]


def stand():
    w, h = 72, 92
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    # Base block.
    d.rectangle([6, h - 16, w - 7, h - 3], fill=WOOD[1] + (255,))
    d.rectangle([6, h - 16, w - 7, h - 14], fill=WOOD[4] + (255,))
    d.rectangle([w - 14, h - 14, w - 7, h - 3], fill=WOOD[0] + (255,))
    # Two posts and a brass ring that cradles the bottle's neck.
    for x in (12, w - 18):
        d.rectangle([x, 30, x + 5, h - 16], fill=WOOD[2] + (255,))
        d.rectangle([x, 30, x + 1, h - 16], fill=WOOD[4] + (255,))
    d.rectangle([10, 26, w - 11, 31], fill=WOOD[3] + (255,))
    d.ellipse([20, 20, w - 20, 36], outline=BRASS[1] + (255,), width=3)
    d.arc([20, 20, w - 20, 36], 180, 300, fill=BRASS[3] + (255,), width=2)
    return im


save(tabletop(452, 352), "ui/bench_table.png")
save(mortar(), "ui/bench_mortar.png")
save(bowl(), "ui/bench_bowl.png")
save(stand(), "ui/bench_stand.png")

# The bench in the world: 6 x 4 tiles at 2x detail = 96 x 64; its pieces shrunk onto a table.
obj = Image.new("RGBA", (96, 64))
d = ImageDraw.Draw(obj)
top = 40
d.rectangle([2, top, 93, top + 5], fill=WOOD[3] + (255,))
d.rectangle([2, top, 93, top], fill=WOOD[4] + (255,))
d.rectangle([2, top + 5, 93, top + 6], fill=WOOD[0] + (255,))
for lx in (6, 86):
    d.rectangle([lx, top + 7, lx + 4, 63], fill=WOOD[1] + (255,))
    d.rectangle([lx, top + 7, lx + 1, 63], fill=WOOD[2] + (255,))
d.rectangle([10, 56, 86, 58], fill=WOOD[1] + (255,))
for piece, x, wd in [(mortar(), 6, 28), (bowl(), 34, 40), (stand(), 76, 14)]:
    small = piece.resize((wd, round(piece.height * wd / piece.width)), Image.NEAREST)
    obj.alpha_composite(small, (x, top + 1 - small.height))
bottle = make_flasks.draw("thin", "glass", ((90, 150, 210), (150, 200, 240)), None, seed=3).resize((14, 14), Image.NEAREST)
obj.alpha_composite(bottle, (76, top - 20))
save(obj, "objects/alchemists_bench.png")
save(obj.crop((0, 8, 96, 64)).resize((16, 9), Image.LANCZOS).crop((0, -4, 16, 12)), "items/icons/alchemists_bench.png")

murky = make_flasks.draw("thin", "clay", ((86, 82, 48), (120, 118, 70)), None, seed=9)
save(murky, "items/icons/murky_mixture.png")
save(murky, "items/held/murky_mixture.png")
