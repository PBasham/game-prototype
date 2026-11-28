"""Placeholder Dark Forest art: darkwood trees (3 sizes), the Dark Log and Darkwood
icons, darkwood planks and wall textures, the Forest Spirit sheet, its shot, and the
Magic Essence and Spirit Core icons. Run from the repo root; existing files are kept
unless --force is given."""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

FORCE = "--force" in sys.argv


def save(im, path):
    if os.path.exists(path) and not FORCE:
        print("kept", path)
        return
    im.save(path)
    print("wrote", path)


BARK = [(58, 34, 52), (78, 46, 66), (96, 58, 80), (44, 26, 40)]
# Phase 90: crowns are retinted blue-teal afterward (tools/make_dark_forest_tint.py).
LEAF = [(18, 34, 30), (24, 46, 38), (32, 60, 48), (44, 78, 60), (12, 24, 22)]


def darkwood_tree(h, seed):
    """A thick purple-brown trunk under a big round crown of dark green clumps."""
    rnd = random.Random(seed)
    w = 104
    im = Image.new("RGBA", (w, h))
    px = im.load()
    cx = w // 2
    crown_h = int(h * 0.42)
    trunk_w = 9 + h // 60
    # trunk with flared roots
    for y in range(int(crown_h * 0.6), h):
        t = (y - crown_h * 0.6) / max(h - crown_h * 0.6, 1)
        half = trunk_w / 2 + (max(0.0, t - 0.85) / 0.15) ** 2 * 5
        for x in range(int(cx - half), int(cx + half) + 1):
            k = (x - (cx - half)) / max(half * 2, 1)
            c = BARK[1]
            if k < 0.28:
                c = BARK[2]
            elif k > 0.75:
                c = BARK[3]
            if (x * 7 + y * 3 + seed) % 11 == 0 or (y % 9 == 0 and (x + y) % 3 == 0):
                c = BARK[0]
            px[x, y] = c + (255,)
    # a few side branches into the crown
    d = ImageDraw.Draw(im)
    for i in range(3):
        y0 = crown_h - 4 - i * 9
        side = -1 if i % 2 == 0 else 1
        d.line([(cx, y0 + 8), (cx + side * (14 + i * 4), y0)], fill=BARK[3] + (255,), width=3)
    # crown: many overlapping leafy clumps packed into one big rounded mass, lit from
    # the upper left. No outline: the edge is just the shaded leaves.
    ecx, ecy = cx, crown_h * 0.56
    erx, ery = w * 0.40, crown_h * 0.46
    clumps = []
    while len(clumps) < 60:
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.uniform(0, 1))
        clumps.append((ecx + math.cos(a) * r * (erx - 9), ecy + math.sin(a) * r * (ery - 9), rnd.uniform(8, 12.5)))
    for y in range(int(crown_h * 1.05)):
        for x in range(w):
            top = None
            for (ccx, ccy, cr) in clumps:
                dd = math.hypot(x - ccx, y - ccy)
                if dd < cr and (top is None or ccy > top[1]):
                    top = (ccx, ccy, cr, dd)
            if top is None:
                continue
            ccx, ccy, cr, dd = top
            light = ((ccx - x) * 0.7 + (ccy - y)) / cr      # within the clump
            mass = ((ecx - x) * 0.5 + (ecy - y)) / ery         # across the whole crown
            v = light * 0.6 + mass * 0.9
            i = 0 if v < -0.55 else (1 if v < 0.05 else (2 if v < 0.6 else 3))
            n = ((x * 73 + y * 151 + seed * 17) * 2654435761) % 997 / 997.0
            if n < 0.18:
                i = max(i - 1, 0)
            elif n > 0.9:
                i = min(i + 1, 3)
            px[x, y] = LEAF[i] + (255,)
    # a few faint glowing motes in the leaves
    for _ in range(4):
        x, y = rnd.randrange(20, w - 20), rnd.randrange(8, crown_h - 6)
        if px[x, y][3]:
            px[x, y] = (120, 210, 200, 255)
    return im


def icon_log():
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    d.rectangle([2, 5, 12, 11], fill=BARK[1])
    d.line([(2, 5), (12, 5)], fill=BARK[2])
    d.line([(2, 11), (12, 11)], fill=BARK[3])
    d.ellipse([10, 5, 14, 11], fill=(120, 84, 104), outline=BARK[3])
    d.point([(12, 8)], fill=(150, 110, 130))
    return im


def icon_planks():
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    for i, y in enumerate((3, 7, 11)):
        d.rectangle([2, y, 13, y + 3], fill=BARK[2] if i % 2 else BARK[1])
        d.line([(2, y + 3), (13, y + 3)], fill=BARK[3])
        d.point([(4 + i * 3, y + 1)], fill=BARK[0])
    return im


def planks_texture(size, wall):
    """Darkwood planks: the same layout as wood planks, purple-brown. 128x128 detailed."""
    im = Image.new("RGBA", (size, size))
    px = im.load()
    board = size // 8
    rnd = random.Random(7)
    for y in range(size):
        row = y // board
        for x in range(size):
            seam = (x + (row % 2) * size // 4) % (size // 2) == 0
            c = BARK[1] if row % 2 == 0 else BARK[2]
            if y % board == board - 1 or seam:
                c = BARK[3]
            elif y % board == 0:
                c = tuple(min(255, v + 12) for v in c)
            elif rnd.random() < 0.05:
                c = BARK[0]
            if wall:
                c = tuple(int(v * 0.6) for v in c)
            px[x, y] = c + (255,)
    return im


def spirit_sheet():
    """Forest Spirit: 3 frames of 24x24 (drifting, charging, shooting)."""
    im = Image.new("RGBA", (72, 24))
    px = im.load()
    for f in range(3):
        ox = f * 24
        glow = [0.6, 1.0, 0.8][f]
        for y in range(24):
            for x in range(24):
                d = math.hypot(x + 0.5 - 12, y + 0.5 - 12)
                if d < 5.5:
                    c = (90, 150, 255) if d > 3.5 else (170, 210, 255)
                    if d < 1.8:
                        c = (240, 250, 255)
                    px[ox + x, y] = c + (255,)
                elif d < 11:
                    a = int(150 * glow * (1 - (d - 5.5) / 5.5) ** 2)
                    px[ox + x, y] = (110, 170, 255, a)
        if f == 1:  # charging: a ring of sparks
            for i in range(8):
                a = i * math.tau / 8
                px[ox + 12 + int(math.cos(a) * 9), 12 + int(math.sin(a) * 9)] = (220, 240, 255, 255)
    return im


def essence():
    im = Image.new("RGBA", (16, 16))
    px = im.load()
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8, (y + 0.5 - 8.5) * 0.9)
            if d < 4.5:
                c = (150, 200, 255) if d > 2.5 else (230, 245, 255)
                px[x, y] = c + (255,)
            elif d < 7:
                px[x, y] = (110, 160, 255, int(120 * (1 - (d - 4.5) / 2.5)))
    for p in [(8, 2), (12, 4), (3, 12)]:
        px[p] = (200, 230, 255, 255)
    return im


def core():
    im = Image.new("RGBA", (16, 16))
    px = im.load()
    for y in range(16):
        for x in range(16):
            dx, dy = abs(x + 0.5 - 8), abs(y + 0.5 - 8)
            if dx * 1.3 + dy < 7:
                c = (60, 110, 220)
                if dx * 1.3 + dy < 4:
                    c = (150, 210, 255)
                if dx * 1.3 + dy < 1.8:
                    c = (250, 255, 255)
                if x < 8 and y < 8 and dx * 1.3 + dy > 4:
                    c = (100, 160, 245)
                px[x, y] = c + (255,)
    return im


def main():
    for i, h in enumerate((180, 230, 280)):
        save(darkwood_tree(h, 50 + i), "assets/trees/darkwood_%d.png" % i)
    for item, im in (("dark_log", icon_log()), ("darkwood", icon_planks()),
                     ("magic_essence", essence()), ("spirit_core", core())):
        save(im, "assets/items/icons/%s.png" % item)
        save(im.resize((9, 9), Image.NEAREST) if item != "darkwood" else im, "assets/items/held/%s.png" % item)
    save(planks_texture(64, False), "assets/terrain/darkwood_planks.png")
    save(planks_texture(64, True), "assets/terrain/darkwood_planks_wall.png")
    os.makedirs("assets/enemies", exist_ok=True)
    save(spirit_sheet(), "assets/enemies/forest_spirit.png")


if __name__ == "__main__":
    main()


def backdrop_layer(seed, trunk, canopy, count, wmin, wmax, height=480, canopy_h=120):
    """A repeating band of tall dark trunks under a ragged canopy (1280 wide, tiles
    sideways). Transparent between the trunks."""
    W = 1280
    rnd = random.Random(seed)
    im = Image.new("RGBA", (W, height))
    px = im.load()
    for _ in range(count):
        x0 = rnd.randrange(W)
        tw = rnd.randint(wmin, wmax)
        for y in range(canopy_h // 2, height):
            for dx in range(tw):
                x = (x0 + dx) % W
                c = trunk if dx > 1 else tuple(min(255, v + 8) for v in trunk)
                px[x, y] = c + (255,)
        # a couple of bare branches
        for _b in range(2):
            by = rnd.randint(canopy_h, height // 2)
            side = rnd.choice((-1, 1))
            for k in range(rnd.randint(8, 18)):
                x = (x0 + (tw if side > 0 else 0) + side * k) % W
                y = by - k // 2
                px[x, y] = trunk + (255,)
    # canopy: overlapping blobs along the top, wrapping sideways
    blobs = [(rnd.randrange(W), rnd.randint(0, canopy_h - 30), rnd.randint(30, 60)) for _ in range(70)]
    for (bx, by, r) in blobs:
        for y in range(max(0, by - r), min(height, by + r)):
            for dx in range(-r, r):
                if dx * dx + (y - by) ** 2 * 1.6 < r * r:
                    px[(bx + dx) % W, y] = canopy + (255,)
    for y in range(0, canopy_h // 3):
        for x in range(W):
            px[x, y] = canopy + (255,)
    return im


def backdrops():
    save(backdrop_layer(3, (34, 52, 54), (22, 36, 38), 34, 10, 26), "assets/backdrop/dark_forest_far.png")
    save(backdrop_layer(4, (16, 26, 28), (12, 20, 22), 16, 22, 48, canopy_h=90), "assets/backdrop/dark_forest_near.png")


if __name__ == "__main__" and "--backdrops" in sys.argv:
    backdrops()


def sapling():
    """Darkwood sapling, 9x14 like the pine sapling: a purple stem, a round dark tuft."""
    im = Image.new("RGBA", (9, 14))
    px = im.load()
    for y in range(5, 14):
        px[4, y] = BARK[2] + (255,)
    px[3, 13] = BARK[1] + (255,)
    px[5, 13] = BARK[1] + (255,)
    for y in range(0, 7):
        for x in range(9):
            if (x - 4) ** 2 + ((y - 3) * 1.2) ** 2 < 11:
                c = LEAF[3] if x < 4 and y < 3 else (LEAF[2] if (x + y) % 3 else LEAF[1])
                px[x, y] = c + (255,)
    for p in [(1, 8), (2, 8), (6, 9), (7, 9)]:
        px[p] = LEAF[2] + (255,)
    return im


def sapling_icon():
    icon = Image.new("RGBA", (16, 16))
    s = sapling()
    icon.alpha_composite(s, (4, 1))
    return icon


if __name__ == "__main__" and "--sapling" in sys.argv:
    save(sapling(), "assets/decor/darkwood_sapling.png")
    save(sapling_icon(), "assets/items/icons/darkwood_sapling.png")
    save(sapling_icon().resize((9, 9), Image.NEAREST), "assets/items/held/darkwood_sapling.png")


def darkwood_workbench():
    """The Workbench recolored to darkwood, keeping its grain (tier 2)."""
    im = Image.open("assets/objects/workbench.png").convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0 or not (r > g + 12 and r > b + 12):
                continue  # only the wood; the tools stay
            lum = (0.3 * r + 0.55 * g + 0.15 * b) / 255
            t = min(max((lum - 0.15) / 0.6, 0.0), 1.0)
            lo, hi = (40, 22, 38), (128, 82, 108)
            px[x, y] = tuple(int(lo[i] + (hi[i] - lo[i]) * t) for i in range(3)) + (a,)
    return im


def reinforced(src, dst, wall):
    """Planks with iron straps and rivets (64x64)."""
    im = Image.open(src).convert("RGBA")
    px = im.load()
    W, H = im.size
    iron, light, dark = (110, 114, 124), (170, 174, 186), (62, 64, 72)
    k = 0.6 if wall else 1.0
    for y in range(H):
        for x in range(W):
            # A strap every 2 blocks (16 px), rivets every block (Patrick: denser).
            band = (x % 16) in (6, 7, 8)
            if band:
                c = light if (x % 16) == 6 else (dark if (x % 16) == 8 else iron)
                if y % 8 == 3 and (x % 16) == 7:
                    c = (210, 214, 224)  # rivet
                px[x, y] = tuple(int(v * k) for v in c) + (255,)
    im.save(dst)
    print("wrote", dst)


def phase16():
    save(darkwood_workbench(), "assets/objects/darkwood_workbench.png")
    for name, src in (("reinforced_wood", "planks"), ("reinforced_darkwood", "darkwood_planks")):
        for wall in (False, True):
            dst = "assets/terrain/%s%s.png" % (name, "_wall" if wall else "")
            if os.path.exists(dst) and not FORCE:
                print("kept", dst)
                continue
            reinforced("assets/terrain/%s%s.png" % (src, "_wall" if wall else ""), dst, wall)


if __name__ == "__main__" and "--phase16" in sys.argv:
    phase16()
