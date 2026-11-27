"""Placeholder art for Phase 56 (sea life). Keeps existing files unless --force.

  enemies/crab.png   3 frames 16x10: resting, walking a, walking b
  enemies/fish.png   3 frames 14x8: swimming a, swimming b, flopping
  items/{icons,held}/{raw_crab,crab_legs,raw_fish,cooked_fish}.png  16x16
  decor/kelp.png      16x16 stem piece (2 art pixels a world pixel: 8x8 world)
  decor/kelp_top.png  16x16 top piece
  decor/seagrass_{0,1,2}.png  16x16 tufts on the sea or pond floor
  decor/dune_grass_{0,1}.png  16x24 tufts on dry beach sand
Run: python3 tools/make_sea_life_art.py
"""
import math
import os
import random
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
FORCE = "--force" in sys.argv


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c + (255,) if len(c) == 3 else c)


# --- crab -------------------------------------------------------------------------
SHELL = (214, 86, 52)
SHELL_HI = (240, 132, 84)
SHELL_LO = (150, 52, 36)
EYE = (30, 24, 24)


def crab_frame(step):
    im = Image.new("RGBA", (16, 10))
    # Body: a wide oval, rows 4..7.
    for y in range(4, 8):
        half = {4: 4, 5: 5, 6: 5, 7: 4}[y]
        for x in range(8 - half, 8 + half):
            px(im, x, y, SHELL_HI if y == 4 else (SHELL_LO if y == 7 else SHELL))
    # Eyes on stalks.
    for x in (6, 9):
        px(im, x, 3, SHELL_LO)
        px(im, x, 2, EYE)
    # Claws, raised a little when walking.
    lift = 1 if step else 0
    for side in (-1, 1):
        cx = 8 + side * 6 - (1 if side > 0 else 0)
        px(im, cx, 3 - lift, SHELL)
        px(im, cx + side, 3 - lift, SHELL_HI)
        px(im, cx, 4 - lift, SHELL_LO)
        px(im, cx - side, 5, SHELL)
    # Legs: three a side, moving in turn.
    for i in range(3):
        for side in (-1, 1):
            base = 8 + side * (2 + i)
            off = ((i + step) % 2) if step else 0
            px(im, base + side * off, 8, SHELL_LO)
            px(im, base + side * (1 + off), 9, SHELL_LO)
    return im


sheet = Image.new("RGBA", (48, 10))
for i, step in enumerate([0, 1, 2]):
    sheet.paste(crab_frame(step), (i * 16, 0))
save(sheet, "enemies/crab.png")

# --- fish --------------------------------------------------------------------------
BODY = (120, 160, 190)
BELLY = (200, 220, 225)
BACK = (70, 105, 140)
FIN = (90, 130, 170)


def fish_frame(tail, flop):
    im = Image.new("RGBA", (14, 8))
    for x in range(2, 12):
        t = (x - 2) / 9.0
        half = 3.0 * math.sin(math.pi * min(1.0, t * 1.1)) + 0.3
        for y in range(8):
            d = y - 4
            if -half <= d < half:
                c = BACK if d < -half + 1.2 else (BELLY if d > half - 1.4 else BODY)
                px(im, x, y, c)
    # Tail: two corners flicking.
    up = tail
    px(im, 1, 2 + up, FIN)
    px(im, 0, 1 + up, FIN)
    px(im, 1, 5 - (1 - up), FIN)
    px(im, 0, 6 - (1 - up), FIN)
    px(im, 1, 3, FIN)
    px(im, 1, 4, FIN)
    px(im, 6, 1, FIN)  # back fin
    px(im, 10, 3, (20, 20, 30))  # eye
    if flop:
        im = im.rotate(-20, resample=Image.NEAREST, expand=False)
    return im


sheet = Image.new("RGBA", (42, 8))
for i, (tail, flop) in enumerate([(0, False), (1, False), (0, True)]):
    sheet.paste(fish_frame(tail, flop), (i * 14, 0))
save(sheet, "enemies/fish.png")


# --- food icons --------------------------------------------------------------------
def icon_crab(cooked):
    im = Image.new("RGBA", (16, 16))
    big = crab_frame(0).resize((16, 10), Image.NEAREST)
    if cooked:
        im = Image.new("RGBA", (16, 16))
        # A pile of cooked legs and a claw.
        LEG = (232, 96, 48)
        LEG_HI = (255, 168, 110)
        for i, (x0, y0, x1, y1) in enumerate([(2, 12, 11, 5), (4, 14, 13, 8), (1, 9, 8, 3)]):
            n = max(abs(x1 - x0), abs(y1 - y0))
            for k in range(n + 1):
                x = round(x0 + (x1 - x0) * k / n)
                y = round(y0 + (y1 - y0) * k / n)
                px(im, x, y, LEG)
                px(im, x, y - 1, LEG_HI)
                if k % 4 == 3:
                    px(im, x, y + 1, (170, 60, 30))  # joint
        for (x, y) in [(12, 3), (13, 3), (13, 4), (11, 2), (14, 5)]:
            px(im, x, y, LEG)
        px(im, 12, 2, LEG_HI)
        return im
    im.paste(big, (0, 3))
    return im


def icon_fish(cooked):
    f = fish_frame(0, False).resize((14, 8), Image.NEAREST)
    im = Image.new("RGBA", (16, 16))
    big = f.resize((16, 9), Image.NEAREST)
    if cooked:
        pix = big.load()
        for y in range(big.height):
            for x in range(big.width):
                r, g, b, a = pix[x, y]
                if a:
                    # Browned and seared.
                    k = 0.85 if y < 4 else 0.7
                    pix[x, y] = (int(200 * k + r * 0.2), int(130 * k + g * 0.1), int(70 * k), a)
        for x in (5, 8, 11):
            for y in range(2, 7):
                if pix[x, y][3]:
                    pix[x, y] = (90, 50, 25, 255)  # grill marks
    im.paste(big, (0, 4))
    return im


for name, img in [("raw_crab", icon_crab(False)), ("crab_legs", icon_crab(True)),
                  ("raw_fish", icon_fish(False)), ("cooked_fish", icon_fish(True))]:
    save(img, f"items/icons/{name}.png")
    save(img, f"items/held/{name}.png")

# --- plants (2 art pixels a world pixel) --------------------------------------------
rnd = random.Random(7)
KELP = (56, 120, 64)
KELP_HI = (96, 168, 84)
KELP_LO = (34, 82, 48)


def kelp_piece(top):
    im = Image.new("RGBA", (16, 16))
    for y in range(16):
        wob = int(round(math.sin(y / 16 * math.tau) * 1.5))
        for x in range(7 + wob, 9 + wob):
            px(im, x, y, KELP_LO if x == 7 + wob else KELP)
    # Leaves: blades off the stem, alternating sides.
    for i, y0 in enumerate([2, 9] if not top else [3, 8, 12]):
        side = 1 if i % 2 == 0 else -1
        for k in range(6):
            x = 8 + side * (1 + k)
            y = y0 + k // 2
            px(im, x, y, KELP_HI if k < 3 else KELP)
            px(im, x, y + 1, KELP)
    if top:
        for y in range(0, 4):
            px(im, 8, y, KELP_HI)
        px(im, 7, 0, (0, 0, 0, 0))
    return im


save(kelp_piece(False), "decor/kelp.png")
save(kelp_piece(True), "decor/kelp_top.png")

GRASS = [(70, 140, 90), (96, 170, 110), (50, 110, 80)]
for v in range(3):
    im = Image.new("RGBA", (16, 16))
    for blade in range(5 + v):
        x = 2 + rnd.randrange(12)
        h = 5 + rnd.randrange(8)
        lean = rnd.choice([-1, 0, 1])
        for k in range(h):
            px(im, x + (lean * k) // 4, 15 - k, GRASS[(blade + k // 3) % 3])
    save(im, f"decor/seagrass_{v}.png")

DUNE = [(196, 184, 110), (168, 160, 90), (214, 204, 140)]
for v in range(2):
    im = Image.new("RGBA", (16, 24))
    for blade in range(7 + v * 3):
        x = 3 + rnd.randrange(10)
        h = 8 + rnd.randrange(14)
        lean = rnd.choice([-2, -1, 1, 2])
        for k in range(h):
            px(im, x + (lean * k * k) // 60, 23 - k, DUNE[(blade + k // 4) % 3])
    save(im, f"decor/dune_grass_{v}.png")
