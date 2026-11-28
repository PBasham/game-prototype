#!/usr/bin/env python3
"""Phase 75 placeholders: the Floating Torch spell icon (32x32, a stone disc with a
little torch, like the other spell icons) and its Empower icons (16x16, ui/empower/):
torch_brighter (a torch with rays) and torch_kindled (a torch over an hourglass). Kept
unless --force. Its scroll and page come from tools/make_item_art.gd --scrolls.

Run: python3 tools/make_floating_torch_art.py [--force]
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
FORCE = "--force" in sys.argv
HANDLE = (122, 78, 40, 255)
HANDLE_L = (160, 108, 60, 255)
BAND = (90, 90, 96, 255)
FLAME = [(255, 150, 50, 255), (255, 200, 80, 255), (255, 240, 170, 255)]


def save(img, rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


def torch(d, cx, top, s):
    """A torch: flame at `top`, handle below; s = pixel size."""
    d.rectangle([cx - s, top + 4 * s, cx + s - 1, top + 11 * s], fill=HANDLE)
    d.rectangle([cx - s, top + 4 * s, cx - 1, top + 11 * s], fill=HANDLE_L)
    d.rectangle([cx - int(1.5 * s), top + 3 * s, cx + int(1.5 * s) - 1, top + 4 * s], fill=BAND)
    d.ellipse([cx - 2 * s, top - s, cx + 2 * s - 1, top + 3 * s], fill=FLAME[0])
    d.ellipse([cx - int(1.3 * s), top, cx + int(1.3 * s) - 1, top + 3 * s - 1], fill=FLAME[1])
    d.ellipse([cx - int(0.6 * s), top + s, cx + int(0.6 * s), top + 2 * s], fill=FLAME[2])


# The spell icon.
im = Image.new("RGBA", (32, 32))
d = ImageDraw.Draw(im)
d.ellipse([2, 2, 29, 29], fill=(150, 138, 118, 255))
d.ellipse([4, 4, 27, 27], fill=(112, 102, 92, 255))
d.ellipse([9, 6, 22, 19], fill=(150, 120, 80, 255))  # its glow on the stone
torch(d, 16, 8, 2)
save(im, "items/icons/floating_torch.png")

# Brighter: a torch with rays.
im = Image.new("RGBA", (16, 16))
d = ImageDraw.Draw(im)
torch(d, 8, 4, 1)
for a, b in [((8, 0), (8, 1)), ((3, 3), (4, 4)), ((12, 3), (11, 4)), ((2, 7), (3, 7)), ((13, 7), (14, 7))]:
    d.line([a, b], fill=FLAME[2])
save(im, "ui/empower/torch_brighter.png")

# Kindled: a torch beside a small hourglass.
im = Image.new("RGBA", (16, 16))
d = ImageDraw.Draw(im)
torch(d, 5, 3, 1)
GLASS = (200, 220, 230, 255)
SAND = (230, 190, 110, 255)
d.rectangle([9, 4, 14, 4], fill=HANDLE)
d.rectangle([9, 13, 14, 13], fill=HANDLE)
d.polygon([(10, 5), (13, 5), (11.5, 8.5)], fill=GLASS)
d.polygon([(10, 12), (13, 12), (11.5, 8.5)], fill=SAND)
save(im, "ui/empower/torch_kindled.png")
