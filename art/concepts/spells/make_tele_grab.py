"""Placeholder icon for Tele Grab (16x16): a swirling violet portal with a small item
being pulled into it. Run from the repo root; keeps an existing icon unless --force."""
import math, os, sys
from PIL import Image

out = "assets/items/icons/tele_grab.png"
if os.path.exists(out) and "--force" not in sys.argv:
    print("kept", out); sys.exit()
im = Image.new("RGBA", (16, 16))
for y in range(16):
    for x in range(16):
        dx, dy = x + 0.5 - 9, (y + 0.5 - 8) * 1.25
        d = math.hypot(dx, dy)
        if d < 6.2:
            a = math.atan2(dy, dx)
            swirl = (a * 2 + d * 0.9) % (2 * math.pi) < math.pi
            if d > 5.0:
                c = (196, 150, 255)
            elif swirl:
                c = (120, 70, 200)
            else:
                c = (40, 22, 70)
            im.putpixel((x, y), c + (255,))
# a little ore chunk flying in from the left, with a streak
for p in [(1, 7), (2, 7), (1, 8), (2, 8)]:
    im.putpixel(p, (214, 140, 80, 255))
im.putpixel((1, 7), (255, 200, 140, 255))
for x in (3, 4):
    im.putpixel((x, 7), (230, 210, 255, 160 if x == 3 else 220))
im.save(out); print("wrote", out)
