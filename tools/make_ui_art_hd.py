#!/usr/bin/env python3
"""Phase 91: the UI's nine-slice art, "dark arcane": deep navy panels with gold trim, blue
glows and gem corners, drawn at 3 art pixels per UI pixel (UiSkin.DETAIL) so it reads
crisp instead of chunky. Replaces tools/make_ui_art.gd's panel, title, slot, button,
field and row art (bench art and icons are untouched; the inventory icons are
tools/make_inventory_art_hd.py).
Patrick replaces these later. Overwrites only with --force.

Run: python3 tools/make_ui_art_hd.py --force
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

DIR = "assets/ui"
FORCE = "--force" in sys.argv

NAVY_TOP = (22, 32, 58)
NAVY_LOW = (11, 17, 33)
GOLD = (198, 160, 76)
GOLD_HI = (246, 220, 140)
GOLD_LO = (120, 88, 36)
EDGE = (5, 8, 15)
BLUE_GLOW = (86, 150, 232)
STEEL = (52, 70, 110)


def save(im, name):
    path = os.path.join(DIR, name + ".png")
    if os.path.exists(path) and not FORCE:
        print("kept", path)
        return
    im.save(path)
    print("wrote", path)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def vgrad(w, h, top, low):
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        c = lerp(top, low, y / max(h - 1, 1)) + (255,)
        for x in range(w):
            px[x, y] = c
    return im


def rect_line(dr, r, color, width=1):
    x0, y0, x1, y1 = r
    for i in range(width):
        dr.rectangle([x0 + i, y0 + i, x1 - i, y1 - i], outline=color)


def bevel(dr, r, hi, lo):
    """Light top and left, shadow bottom and right (one line)."""
    x0, y0, x1, y1 = r
    dr.line([(x0, y0), (x1, y0)], fill=hi)
    dr.line([(x0, y0), (x0, y1)], fill=hi)
    dr.line([(x0, y1), (x1, y1)], fill=lo)
    dr.line([(x1, y0), (x1, y1)], fill=lo)


def glow(im, r, color, width, strength):
    """A soft glow inside a rectangle's edge (inner glow)."""
    layer = Image.new("RGBA", im.size)
    d = ImageDraw.Draw(layer)
    for i in range(width):
        a = int(strength * (1.0 - i / width) ** 2)
        d.rectangle([r[0] + i, r[1] + i, r[2] - i, r[3] - i], outline=color + (a,))
    im.alpha_composite(layer)


def gem(dr, cx, cy, size, color):
    """A small gold-set diamond with a colored stone."""
    s = size
    dr.polygon([(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)], fill=GOLD, outline=GOLD_LO)
    t = max(s - 3, 1)
    dr.polygon([(cx, cy - t), (cx + t, cy), (cx, cy + t), (cx - t, cy)], fill=color)
    dr.point((cx - 1, cy - 1), fill=(255, 255, 255, 230))
    dr.line([(cx - s + 1, cy), (cx, cy - s + 1)], fill=GOLD_HI)


def panel():
    w = h = 96
    im = vgrad(w, h, NAVY_TOP, NAVY_LOW)
    dr = ImageDraw.Draw(im)
    rect_line(dr, (0, 0, w - 1, h - 1), EDGE, 1)
    # Gold frame: a hi/lo beveled band, a dark gap, then a thin blue line.
    rect_line(dr, (1, 1, w - 2, h - 2), GOLD, 3)
    bevel(dr, (1, 1, w - 2, h - 2), GOLD_HI, GOLD_LO)
    bevel(dr, (3, 3, w - 4, h - 4), GOLD_LO, GOLD_HI)
    rect_line(dr, (4, 4, w - 5, h - 5), EDGE, 2)
    rect_line(dr, (6, 6, w - 7, h - 7), (40, 64, 112), 1)
    glow(im, (7, 7, w - 8, h - 8), BLUE_GLOW, 9, 70)
    dr = ImageDraw.Draw(im)
    # Corner filigree: an L of gold with a gem.
    for cx, cy, sx, sy in ((10, 10, 1, 1), (w - 11, 10, -1, 1), (10, h - 11, 1, -1), (w - 11, h - 11, -1, -1)):
        dr.line([(cx, cy), (cx + sx * 12, cy)], fill=GOLD)
        dr.line([(cx, cy), (cx, cy + sy * 12)], fill=GOLD)
        dr.point((cx + sx * 13, cy), fill=GOLD_HI)
        dr.point((cx, cy + sy * 13), fill=GOLD_HI)
        gem(dr, cx - sx * 3 + sx * 3, cy - sy * 3 + sy * 3, 5, (70, 150, 240, 255))
    return im


def title():
    w, h = 72, 42
    im = vgrad(w, h, (34, 48, 86), (18, 26, 48))
    dr = ImageDraw.Draw(im)
    rect_line(dr, (0, 0, w - 1, h - 1), EDGE, 1)
    dr.line([(1, 1), (w - 2, 1)], fill=(70, 96, 150))
    # A gold rule along the bottom with a fine highlight.
    dr.line([(2, h - 5), (w - 3, h - 5)], fill=GOLD_HI)
    dr.line([(2, h - 4), (w - 3, h - 4)], fill=GOLD)
    dr.line([(2, h - 3), (w - 3, h - 3)], fill=GOLD_LO)
    glow(im, (1, 1, w - 2, h - 6), BLUE_GLOW, 6, 40)
    dr = ImageDraw.Draw(im)
    gem(dr, 8, h - 4, 4, (70, 150, 240, 255))
    gem(dr, w - 9, h - 4, 4, (70, 150, 240, 255))
    return im


def slot(border, glow_color, glow_strength, inner=(14, 21, 38)):
    s = 60
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    dr.rounded_rectangle([0, 0, s - 1, s - 1], radius=6, fill=EDGE)
    dr.rounded_rectangle([1, 1, s - 2, s - 2], radius=5, fill=border)
    dr.rounded_rectangle([4, 4, s - 5, s - 5], radius=3, fill=inner)
    # Recessed: shadow top-left, a faint lip bottom-right.
    for i in range(4):
        a = 120 - i * 30
        dr.line([(5, 5 + i), (s - 6, 5 + i)], fill=(0, 0, 0, a))
        dr.line([(5 + i, 5), (5 + i, s - 6)], fill=(0, 0, 0, a))
    dr.line([(6, s - 6), (s - 6, s - 6)], fill=lerp(inner, (60, 84, 130), 0.6))
    dr.line([(s - 6, 6), (s - 6, s - 6)], fill=lerp(inner, (60, 84, 130), 0.6))
    # Border bevel.
    dr.arc([1, 1, 12, 12], 180, 270, fill=lerp(border, (255, 255, 255), 0.35))
    dr.line([(6, 1), (s - 7, 1)], fill=lerp(border, (255, 255, 255), 0.35))
    dr.line([(1, 6), (1, s - 7)], fill=lerp(border, (255, 255, 255), 0.25))
    if glow_strength > 0:
        glow(im, (4, 4, s - 5, s - 5), glow_color, 8, glow_strength)
    return im


def button(top, low, border, hi, lo, glow_color=None, pressed=False):
    w, h = 72, 48
    im = Image.new("RGBA", (w, h))
    body = vgrad(w, h, low if pressed else top, top if pressed else low)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=7, fill=255)
    im.paste(body, (0, 0), mask)
    dr = ImageDraw.Draw(im)
    dr.rounded_rectangle([0, 0, w - 1, h - 1], radius=7, outline=EDGE)
    dr.rounded_rectangle([1, 1, w - 2, h - 2], radius=6, outline=border, width=2)
    dr.rounded_rectangle([3, 3, w - 4, h - 4], radius=4, outline=lo)
    # A glassy top highlight.
    y = 6 if not pressed else 9
    dr.line([(8, y), (w - 9, y)], fill=hi)
    dr.line([(10, y + 1), (w - 11, y + 1)], fill=hi[:3] + (90,))
    if glow_color:
        glow(im, (4, 4, w - 5, h - 5), glow_color, 7, 90)
    return im


def field():
    s = 48
    im = Image.new("RGBA", (s, s))
    dr = ImageDraw.Draw(im)
    dr.rounded_rectangle([0, 0, s - 1, s - 1], radius=4, fill=EDGE)
    dr.rounded_rectangle([1, 1, s - 2, s - 2], radius=3, fill=STEEL)
    dr.rounded_rectangle([3, 3, s - 4, s - 4], radius=2, fill=(10, 15, 28))
    for i in range(3):
        dr.line([(4, 4 + i), (s - 5, 4 + i)], fill=(0, 0, 0, 110 - i * 35))
    return im


def row_hot():
    s = 36
    im = Image.new("RGBA", (s, s))
    dr = ImageDraw.Draw(im)
    dr.rounded_rectangle([0, 0, s - 1, s - 1], radius=4, fill=(74, 130, 220, 70), outline=(120, 180, 250, 150))
    dr.line([(1, 3), (1, s - 4)], fill=GOLD_HI + (200,))
    return im


def main():
    save(panel(), "panel")
    save(title(), "title")
    save(slot(STEEL, BLUE_GLOW, 0), "slot")
    save(slot((92, 150, 220), (120, 190, 255), 110), "slot_hot")
    save(slot(GOLD, (255, 214, 120), 120, inner=(20, 26, 44)), "slot_selected")
    save(slot((150, 110, 230), (180, 140, 255), 120, inner=(20, 16, 40)), "slot_magic")
    save(button((52, 78, 138), (26, 40, 76), GOLD, (190, 215, 255, 200), (16, 24, 46)), "button")
    save(button((70, 104, 176), (34, 54, 104), GOLD_HI, (220, 236, 255, 230), (20, 30, 58), BLUE_GLOW), "button_hot")
    save(button((52, 78, 138), (20, 30, 58), GOLD, (150, 175, 220, 150), (10, 16, 30), pressed=True), "button_pressed")
    save(button((52, 56, 68), (34, 37, 46), (90, 92, 100), (120, 124, 136, 120), (24, 26, 32)), "button_disabled")
    save(field(), "field")
    save(row_hot(), "row_hot")


if __name__ == "__main__":
    main()
