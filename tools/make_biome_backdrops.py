#!/usr/bin/env python3
"""Phase 90 placeholder backdrops for the Dark Forest, the ocean (above the water) and
under the sea, in the style of the forest's (pixel art at the 640x360 base resolution,
1280 wide, tiling sideways). Patrick replaces them later. Kept unless --force.

  Dark Forest: df_far (misty blue-grey ridge with a pine line), df_mid (tall trees in the
  fog), df_near (huge dark trunks, moss and a few glowing motes).
  Ocean: ocean_far (far islands and the horizon; its row 112 sits on the sea's surface).
  (ocean_near(), rows of waves, is kept here unused.)
  Under the sea: uw_rays (light shafts), uw_far (distant rock spires and kelp), uw_near
  (near rocks and kelp).

Run: python3 tools/make_biome_backdrops.py [--force] [--out=DIR]
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

W = 1280
FORCE = "--force" in sys.argv
OUT = "assets/backdrop"
for a in sys.argv:
    if a.startswith("--out="):
        OUT = a.split("=", 1)[1]


def save(im, name):
    path = os.path.join(OUT, name)
    if os.path.exists(path) and not FORCE:
        print("kept", path)
        return
    im.save(path)
    print("wrote", path)


def wave(x, terms):
    """A periodic profile over W: sum of (amplitude, whole cycles, phase)."""
    return sum(a * math.sin(2 * math.pi * k * x / W + p) for a, k, p in terms)


def terms(rnd, spec):
    return [(a, k, rnd.uniform(0, 2 * math.pi)) for a, k in spec]


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def bayer(x, y):
    m = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    return (m[y % 4][x % 4] + 0.5) / 16.0


def dither_pick(c0, c1, t, x, y):
    return c1 if t > bayer(x, y) else c0


def mist(im, top, bottom, color, a0, a1):
    """A dithered band of mist from row top (alpha a0) to bottom (a1)."""
    px = im.load()
    for y in range(max(top, 0), min(bottom, im.height)):
        t = (y - top) / max(bottom - top, 1)
        a = a0 + (a1 - a0) * t
        for x in range(W):
            if a * 1.0 > bayer(x, y) * 0.999:
                r, g, b, aa = px[x, y]
                k = min(a, 1.0) * 0.65
                if aa == 0:
                    px[x, y] = color + (int(255 * min(a, 1.0) * 0.55),)
                else:
                    px[x, y] = lerp((r, g, b), color, k) + (aa,)


# --- Dark Forest ----------------------------------------------------------------------

DF_SKYLINE = (46, 64, 78)
DF_MIST = (70, 96, 108)


def df_far():
    rnd = random.Random(901)
    h = 200
    im = Image.new("RGBA", (W, h))
    px = im.load()
    ridge = terms(rnd, [(22, 2), (12, 5), (6, 11), (3, 23)])
    pines = terms(rnd, [(1, 37), (1, 53)])
    for x in range(W):
        top = 90 + wave(x, ridge)
        # A ragged pine line on the ridge.
        spike = (x * 7 + int(wave(x, pines) * 5)) % 9
        top -= max(0, 4 - abs(spike - 4)) * 2.2
        for y in range(int(top), h):
            t = (y - top) / (h - top)
            c = lerp(DF_SKYLINE, DF_MIST, min(1.0, t * 1.4))
            px[x, y] = c + (255,)
        # A faint rim of light on the ridge.
        if 0 <= int(top) < h:
            px[x, int(top)] = lerp(DF_SKYLINE, (110, 140, 150), 0.5) + (255,)
    mist(im, 120, 200, DF_MIST, 0.0, 0.9)
    return im


def df_tree(dr, rnd, cx, base, height, width, trunk, crown, crown_dark):
    """A tall dark-forest tree: a straight trunk and a crown of overlapping blobs."""
    top = base - height
    tw = max(3, width // 6)
    dr.rectangle([cx - tw // 2, top + height // 3, cx + tw // 2, base], fill=trunk)
    for i in range(7):
        r = rnd.randint(width // 4, width // 2)
        ox = rnd.randint(-width // 2, width // 2)
        oy = rnd.randint(0, height // 3)
        dr.ellipse([cx + ox - r, top + oy - r // 2, cx + ox + r, top + oy + r], fill=crown_dark)
    for i in range(6):
        r = rnd.randint(width // 5, width // 3)
        ox = rnd.randint(-width // 2, width // 2)
        oy = rnd.randint(-height // 12, height // 5)
        dr.ellipse([cx + ox - r, top + oy - r // 2, cx + ox + r, top + oy + r // 2], fill=crown)


def tile_draw(h, draw_fn):
    """Draws onto a 3W canvas and folds it to W wide, so shapes wrap seamlessly."""
    big = Image.new("RGBA", (W * 3, h))
    draw_fn(ImageDraw.Draw(big), big)
    out = Image.new("RGBA", (W, h))
    for k in range(3):
        part = big.crop((k * W, 0, (k + 1) * W, h))
        out.alpha_composite(part)
    return out


def df_mid():
    rnd = random.Random(902)
    h = 260

    def draw(dr, big):
        x = 0
        while x < W:
            width = rnd.randint(46, 80)
            height = rnd.randint(170, 240)
            for rep in range(3):
                df_tree(dr, random.Random(x * 13 + 1), W + x, h, height, width,
                        (34, 44, 56, 255), (40, 56, 70, 255), (32, 44, 56, 255))
                break
            x += rnd.randint(40, 90)
        # wrap copies
        left = big.crop((W, 0, W * 2, h))
        big.alpha_composite(left, (0, 0))
        big.alpha_composite(left, (W * 2, 0))

    im = tile_draw(h, draw)
    im = im.crop((0, 0, W, h))
    mist(im, 150, 260, DF_MIST, 0.0, 0.8)
    return im


def df_near():
    rnd = random.Random(903)
    h = 420
    big = Image.new("RGBA", (W, h))
    dr = ImageDraw.Draw(big)
    trunk = (16, 20, 27, 255)
    edge = (28, 36, 46, 255)
    moss = (36, 62, 60, 255)
    x = 20
    while x < W - 30:
        tw = rnd.randint(18, 34)
        dr.polygon([(x + 2, 0), (x + tw - 2, 0), (x + tw, h), (x, h)], fill=trunk)  # a slight taper
        dr.line([(x + tw - 3, 0), (x + tw - 1, h)], fill=edge)  # a faint lit side
        # Bark: long dark grooves and a few knots.
        for g in range(rnd.randint(2, 4)):
            gx = x + rnd.randint(3, tw - 4)
            gy = rnd.randint(0, h // 2)
            dr.line([(gx, gy), (gx + rnd.randint(-1, 1), gy + rnd.randint(60, 200))], fill=(10, 13, 18, 255))
        for k in range(rnd.randint(1, 2)):
            kx, ky = x + rnd.randint(4, tw - 6), rnd.randint(40, h - 80)
            dr.ellipse([kx, ky, kx + 4, ky + 6], fill=(10, 13, 18, 255), outline=edge)
        # Roots flaring at the base.
        dr.polygon([(x - 10, h), (x, h - 24), (x + tw, h - 24), (x + tw + 10, h)], fill=trunk)
        # Hanging moss strands.
        for k in range(rnd.randint(2, 5)):
            mx = x + rnd.randint(0, tw)
            my = rnd.randint(20, 150)
            ln = rnd.randint(10, 40)
            dr.line([(mx, my), (mx + rnd.randint(-2, 2), my + ln)], fill=moss)
        x += tw + rnd.randint(40, 140)
    # A low undergrowth line along the bottom (ferns), tiling.
    ferns = terms(rnd, [(6, 7), (3, 19), (2, 41)])
    px = big.load()
    for xx in range(W):
        top = h - 26 + wave(xx, ferns)
        for y in range(int(top), h):
            px[xx, y] = (14, 22, 24, 255)
    # A few glowing motes.
    for k in range(40):
        gx, gy = rnd.randrange(W), rnd.randrange(60, h - 40)
        px[gx, gy] = (140, 230, 210, 255)
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = (gx + d[0]) % W, gy + d[1]
            px[xx, yy] = (60, 120, 112, 160)
    return big


# --- Ocean (above the water) --------------------------------------------------------------

SEA_FAR = (88, 156, 196)
SEA_NEAR = (52, 120, 170)
FOAM = (214, 236, 246)


def ocean_far():
    rnd = random.Random(904)
    h = 150
    im = Image.new("RGBA", (W, h))
    px = im.load()
    horizon = 112
    # Far islands: a few low humps with tiny trees, hazy.
    islands = []
    for k in range(4):
        islands.append((rnd.randrange(W), rnd.randint(40, 110), rnd.randint(10, 26)))
    for x in range(W):
        top = horizon
        for cx, half, hh in islands:
            d = min(abs(x - cx), W - abs(x - cx))
            if d < half:
                top = min(top, horizon - hh * math.cos(d / half * math.pi / 2) ** 1.5)
        for y in range(int(top), horizon):
            px[x, y] = lerp((120, 158, 170), (150, 186, 200), (y - top) / max(horizon - top, 1)) + (255,)
        if top < horizon - 6 and (x * 13) % 17 == 0:
            for y in range(int(top) - 4, int(top)):
                px[x, y] = (110, 146, 160, 255)
    # The sea from the horizon down, lighter toward the horizon, with glints.
    for y in range(horizon, h):
        t = (y - horizon) / (h - horizon)
        c = lerp((150, 196, 220), SEA_FAR, min(1.0, t * 2.2))
        for x in range(W):
            px[x, y] = c + (255,)
    for k in range(120):
        gy = rnd.randrange(horizon + 2, h)
        gx = rnd.randrange(W)
        ln = rnd.randint(2, 6)
        for i in range(ln):
            px[(gx + i) % W, gy] = lerp(SEA_FAR, FOAM, 0.6) + (255,)
    return im


def ocean_near():
    rnd = random.Random(905)
    h = 110
    im = Image.new("RGBA", (W, h))
    px = im.load()
    for y in range(h):
        t = y / h
        c = lerp(SEA_FAR, SEA_NEAR, t)
        for x in range(W):
            px[x, y] = c + (255,)
    # Rows of waves: a crest line with foam, bigger lower down.
    for row in range(7):
        y0 = 6 + row * 15
        amp = 1.5 + row * 0.6
        ph = terms(rnd, [(amp, 20 + row * 3), (amp * 0.5, 47)])
        dark = lerp(SEA_NEAR, (30, 84, 130), 0.4 + row * 0.05)
        shade = lerp(lerp(SEA_FAR, SEA_NEAR, y0 / h), (36, 96, 146), 0.35)
        gaps = terms(rnd, [(1, 9), (1, 23)])
        for x in range(W):
            yy = int(y0 + wave(x, ph))
            # The wave's back: a darker band under the crest, a few px deep.
            for d in range(1, 4 + row // 2):
                if 0 <= yy + d < h and d / (4.0 + row / 2) < 1.0 - bayer(x, yy + d) * 0.9:
                    px[x, yy + d] = shade + (255,)
            if 0 <= yy < h:
                px[x, yy] = dark + (255,)
                if 0 <= yy - 1 < h and wave(x, ph) < -amp * 0.5 and wave(x, gaps) > -0.4:
                    px[x, yy - 1] = FOAM + (255,)
    return im


# --- Under the sea --------------------------------------------------------------------------

UW_TOP = (38, 108, 150)
UW_LOW = (8, 26, 42)


def uw_rays():
    rnd = random.Random(906)
    h = 360
    im = Image.new("RGBA", (W, h))
    px = im.load()
    rays = [(rnd.randrange(W), rnd.randint(14, 40), rnd.uniform(0.25, 0.5)) for _ in range(9)]
    for y in range(h):
        fade = max(0.0, 1.0 - y / (h * 0.9))
        for cx, wd, a in rays:
            shift = int(y * 0.35)
            for dx in range(-wd, wd):
                x = (cx + dx + shift) % W
                k = (1.0 - abs(dx) / wd) * a * fade
                if k > bayer(x, y) * 0.6:
                    r, g, b, aa = px[x, y]
                    px[x, y] = (190, 236, 250, max(aa, int(150 * k + 40)))
    return im


def uw_layer(seed, h, color, light, kelp, spires):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (W, h))
    px = im.load()
    floor = terms(rnd, [(10, 3), (6, 7), (3, 17)])
    peaks = [(rnd.randrange(W), rnd.randint(16, 40), rnd.randint(50, h - 40)) for _ in range(spires)]
    for x in range(W):
        top = h - 50 + wave(x, floor)
        for cx, half, hh in peaks:
            d = min(abs(x - cx), W - abs(x - cx))
            if d < half:
                rough = (math.sin(x * 0.9 + cx) + math.sin(x * 2.3)) * 1.6
                top = min(top, h - hh * (1.0 - (d / half) ** 1.6) - 30 + rough)
        for y in range(int(top), h):
            c = color
            # Rocky texture: ledges and pits.
            if (y * 7 + x * 3) % 23 == 0 or ((y // 6) % 5 == 0 and (x + y) % 3 == 0):
                c = lerp(color, (0, 0, 0), 0.25)
            elif (x * 5 + y * 11) % 31 == 0:
                c = lerp(color, light, 0.4)
            px[x, y] = c + (255,)
        if 0 <= int(top) < h:
            px[x, int(top)] = light + (255,)
    dr = ImageDraw.Draw(im)
    for k in range(kelp):
        x = rnd.randrange(W)
        base = h - 30
        ln = rnd.randint(40, 120)
        prev = (x, base)
        for i in range(1, ln, 4):
            nx = x + int(4 * math.sin(i * 0.12 + k))
            dr.line([prev, (nx, base - i)], fill=lerp(color, (40, 110, 80), 0.5) + (255,), width=2)
            prev = (nx, base - i)
    return im


def main():
    save(df_far(), "df_far.png")
    save(df_mid(), "df_mid.png")
    save(df_near(), "df_near.png")
    save(ocean_far(), "ocean_far.png")
    save(uw_rays(), "uw_rays.png")
    save(uw_layer(907, 260, (18, 46, 68), (70, 130, 160), 18, 6), "uw_far.png")
    save(uw_layer(908, 220, (6, 18, 30), (40, 90, 116), 26, 4), "uw_near.png")


if __name__ == "__main__":
    main()
