"""Placeholder art for Phase 62 (fireflies). Keeps existing files unless --force.

  enemies/firefly.png               2 frames 6x5: glowing, dim
  items/{icons,held}/firefly.png    16x16
  items/{icons,held}/bug_net.png    16x16 (held like a sword: handle bottom left)
  objects/firefly_lamp.png          4 frames 8x16 (standing, leaning left, right, on a wall)
  items/{icons,held}/firefly_lamp.png  16x16
Run: python3 tools/make_firefly_art.py
"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
FORCE = "--force" in sys.argv

GLOW = (230, 255, 120, 255)
GLOW_HI = (255, 255, 210, 255)
GLOW_DIM = (120, 140, 60, 255)
BODY = (60, 50, 40, 255)
WING = (190, 210, 220, 160)
WOOD = (140, 98, 58, 255)
WOOD_LO = (100, 68, 40, 255)
NET = (225, 225, 215, 200)
GLASS = (200, 228, 235, 150)
GLASS_HI = (240, 252, 255, 220)
METAL = (110, 110, 118, 255)


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


def put(img, pts, c):
    for x, y in pts:
        if 0 <= x < img.width and 0 <= y < img.height:
            img.putpixel((x, y), c)


# --- the firefly ---------------------------------------------------------------------
sheet = Image.new("RGBA", (12, 5))
for f, lit in enumerate([True, False]):
    o = f * 6
    put(sheet, [(o + 1, 1), (o + 2, 1)], WING)
    put(sheet, [(o + 3, 2), (o + 4, 2)], BODY)
    put(sheet, [(o + 5, 2)], BODY)  # head
    tail = GLOW if lit else GLOW_DIM
    put(sheet, [(o + 1, 2), (o + 2, 2), (o + 1, 3), (o + 2, 3)], tail)
    if lit:
        put(sheet, [(o + 1, 2)], GLOW_HI)
save(sheet, "enemies/firefly.png")

icon = Image.new("RGBA", (16, 16))
for (x, y) in [(5, 4), (6, 4), (7, 3), (8, 3)]:
    put(icon, [(x, y)], WING)
for (x, y) in [(9, 7), (10, 7), (11, 6), (12, 6)]:
    put(icon, [(x, y)], BODY)
put(icon, [(13, 6)], BODY)
for y in range(5, 11):
    for x in range(3, 9):
        d = ((x - 5.5) ** 2 + (y - 8) ** 2) ** 0.5
        if d < 2.6:
            put(icon, [(x, y)], GLOW_HI if d < 1.2 else GLOW)
save(icon, "items/icons/firefly.png")
save(icon, "items/held/firefly.png")

# --- the bug net ---------------------------------------------------------------------
net = Image.new("RGBA", (16, 16))
for i in range(9):  # the handle, bottom left to the hoop
    put(net, [(1 + i, 14 - i)], WOOD if i % 3 else WOOD_LO)
hoop = []
for y in range(16):
    for x in range(16):
        d = ((x - 11.0) ** 2 + (y - 4.5) ** 2) ** 0.5
        if 3.2 <= d < 4.2:
            hoop.append((x, y))
        elif d < 3.2 and (x + y) % 2 == 0:
            put(net, [(x, y)], NET)
put(net, hoop, METAL)
save(net, "items/icons/bug_net.png")
save(net, "items/held/bug_net.png")


# --- the lamp --------------------------------------------------------------------------
def jar(img, ox, oy):
    """A glass jar with a metal lid, three fireflies glowing inside (6 wide, 8 tall)."""
    put(img, [(ox + 1, oy), (ox + 2, oy), (ox + 3, oy), (ox + 4, oy)], METAL)  # lid
    put(img, [(ox + 2, oy - 1), (ox + 3, oy - 1)], METAL)  # the ring
    for y in range(1, 8):
        for x in range(6):
            edge = x in (0, 5) or y == 7
            put(img, [(ox + x, oy + y)], GLASS_HI if edge and y < 3 else GLASS)
    put(img, [(ox + 2, oy + 3), (ox + 4, oy + 5), (ox + 1, oy + 6)], GLOW_HI)
    put(img, [(ox + 3, oy + 3), (ox + 3, oy + 5), (ox + 2, oy + 6)], GLOW)


lamp = Image.new("RGBA", (32, 16))
# Standing: on a short post.
jar(lamp, 1, 3)
put(lamp, [(3, 11), (4, 11), (3, 12), (4, 12), (3, 13), (4, 13), (2, 14), (3, 14), (4, 14), (5, 14), (2, 15), (5, 15)], WOOD)
# Leaning left and right: hanging from a bracket on the block beside it.
for f, side in [(1, -1), (2, 1)]:
    ox = f * 8
    jar(lamp, ox + 1, 6)
    wall_x = ox if side < 0 else ox + 7
    put(lamp, [(wall_x, 2), (wall_x, 3), (wall_x, 4)], METAL)
    arm = range(ox + 1, ox + 7)
    put(lamp, [(x, 3) for x in arm], METAL)
    put(lamp, [(ox + 3, 4), (ox + 4, 4)], METAL)  # the hook
# On a wall: on a hook.
jar(lamp, 25, 5)
put(lamp, [(27, 3), (28, 3), (27, 2)], METAL)
save(lamp, "objects/firefly_lamp.png")
lamp_icon = Image.new("RGBA", (16, 16))
big = Image.new("RGBA", (8, 10))
jar(big, 1, 1)
lamp_icon.paste(big.resize((14, 16), Image.NEAREST), (1, 0))
save(lamp_icon, "items/icons/firefly_lamp.png")
save(big.crop((0, 0, 8, 9)).resize((9, 9), Image.NEAREST), "items/held/firefly_lamp.png")
