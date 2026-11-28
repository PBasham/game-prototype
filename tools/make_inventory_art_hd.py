#!/usr/bin/env python3
"""Phase 92: inventory icons in the Phase 91 "dark arcane" look, at 3 art pixels per UI
pixel (UiSkin.DETAIL): the coin pouch (ui/coin_pouch.png, 42x42 = 14 UI px; replaces
the Phase 76 12x12 one) and the trash bin (ui/trash_bin.png, 42x42). The slots behind
them are the normal UiSkin slot art. Patrick replaces these later. Overwrites only with
--force.

Run: python3 tools/make_inventory_art_hd.py --force
"""
import os
import sys

from PIL import Image, ImageDraw

DIR = "assets/ui"
FORCE = "--force" in sys.argv
SIZE = 42
SS = 4  # drawn 4x larger, then scaled down for soft edges

GOLD = (214, 176, 88, 255)
GOLD_HI = (250, 226, 150, 255)
GOLD_LO = (122, 88, 36, 255)
VELVET = (38, 62, 132, 255)
VELVET_HI = (78, 118, 206, 255)
VELVET_LO = (18, 28, 66, 255)
STEEL = (70, 92, 138, 255)
STEEL_HI = (138, 164, 214, 255)
STEEL_LO = (30, 40, 68, 255)
EDGE = (6, 9, 18, 255)


def save(im, name):
    path = os.path.join(DIR, name + ".png")
    if os.path.exists(path) and not FORCE:
        print("kept", path)
        return
    im.save(path)
    print("wrote", path)


def canvas():
    im = Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def s(*v):
    return [x * SS for x in v]


def done(im):
    return im.resize((SIZE, SIZE), Image.LANCZOS)


def pouch():
    im, d = canvas()
    # Body: a round velvet sack, dark outline, lit from the top left.
    d.ellipse(s(6, 14, 36, 40), fill=EDGE)
    d.ellipse(s(7, 15, 35, 39), fill=VELVET_LO)
    d.ellipse(s(8, 15, 33, 36), fill=VELVET)
    d.ellipse(s(11, 18, 22, 27), fill=VELVET_HI)
    # Neck and frilled top.
    d.polygon(s(14, 16, 28, 16, 31, 8, 26, 10, 21, 6, 16, 10, 11, 8), fill=EDGE)
    d.polygon(s(15, 15, 27, 15, 29, 9, 25, 11, 21, 8, 17, 11, 13, 9), fill=VELVET)
    d.polygon(s(16, 14, 21, 9, 17, 11, 13, 9), fill=VELVET_HI)
    # Gold drawstring with a tassel.
    d.rounded_rectangle(s(12, 14, 30, 18), radius=2 * SS, fill=GOLD_LO)
    d.rounded_rectangle(s(12, 14, 30, 16.5), radius=2 * SS, fill=GOLD)
    d.line(s(13, 15, 29, 15), fill=GOLD_HI, width=SS)
    d.line(s(29, 17, 33, 25), fill=GOLD, width=int(1.5 * SS))
    d.ellipse(s(31.5, 24, 35.5, 28), fill=GOLD_LO)
    d.ellipse(s(32, 24, 35, 27), fill=GOLD)
    # A gold coin emblem stitched on the front.
    d.ellipse(s(15, 23, 27, 35), fill=GOLD_LO)
    d.ellipse(s(15.5, 23, 26.5, 34), fill=GOLD)
    d.ellipse(s(17.5, 25, 24.5, 32), outline=GOLD_LO, width=SS)
    d.line(s(18, 25.5, 20, 24.5), fill=GOLD_HI, width=SS)
    return done(im)


def trash_bin():
    im, d = canvas()
    # Can: tapered steel body with ribs and a gold rim.
    d.polygon(s(9, 13, 33, 13, 30, 38, 12, 38), fill=EDGE)
    d.polygon(s(10, 14, 32, 14, 29.2, 37, 12.8, 37), fill=STEEL)
    d.polygon(s(10, 14, 15, 14, 16, 37, 12.8, 37), fill=STEEL_HI)
    d.polygon(s(27, 14, 32, 14, 29.2, 37, 26, 37), fill=STEEL_LO)
    for x in (17, 21, 25):
        d.line(s(x, 17, x - (x - 21) * 0.15, 34), fill=STEEL_LO, width=SS)
    d.rectangle(s(12, 35, 30, 38), fill=GOLD_LO)
    # Lid with a gold band and a handle.
    d.rounded_rectangle(s(6, 8, 36, 14), radius=2 * SS, fill=EDGE)
    d.rounded_rectangle(s(7, 9, 35, 13), radius=2 * SS, fill=GOLD)
    d.line(s(8, 10, 34, 10), fill=GOLD_HI, width=SS)
    d.rounded_rectangle(s(16, 4, 26, 9), radius=2 * SS, outline=EDGE, width=2 * SS)
    d.rounded_rectangle(s(16.5, 4.5, 25.5, 9), radius=2 * SS, outline=GOLD, width=SS)
    return done(im)


if __name__ == "__main__":
    save(pouch(), "coin_pouch")
    save(trash_bin(), "trash_bin")
