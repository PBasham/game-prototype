#!/usr/bin/env python3
"""Phase 73 placeholder: the Command spell's icon (32x32, a stone disc with a red target
reticle, like the other spell icons). Kept unless --force. Its scroll and page come from
tools/make_item_art.gd (missing ones only).

Run: python3 tools/make_command_art.py [--force]
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "items")
path = os.path.join(ROOT, "icons", "command.png")
if os.path.exists(path) and "--force" not in sys.argv:
    print("kept", path)
    sys.exit()
im = Image.new("RGBA", (32, 32))
d = ImageDraw.Draw(im)
d.ellipse([2, 2, 29, 29], fill=(150, 138, 118, 255))
d.ellipse([4, 4, 27, 27], fill=(112, 102, 92, 255))
RED = (232, 92, 70, 255)
d.ellipse([9, 9, 22, 22], outline=RED, width=2)
for a, b in [((15, 5), (16, 10)), ((15, 21), (16, 26)), ((5, 15), (10, 16)), ((21, 15), (26, 16))]:
    d.rectangle([a, b], fill=RED)
d.rectangle([15, 15, 16, 16], fill=(255, 220, 150, 255))
im.save(path)
os.makedirs(os.path.join(ROOT, "held"), exist_ok=True)
print("wrote", path)
