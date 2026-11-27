"""Placeholders for Phase 36: the Glass block and wall, the Clay wall, and one more
row in assets/tiles/blocks.png (atlas_row 19, Glass's collision row).

python3 tools/make_glass_clay_art.py [--force]
"""
import os, sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets")
FORCE = "--force" in sys.argv


def save(img, rel):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path) and not FORCE:
        print("kept", rel)
        return
    img.save(path)
    print("wrote", rel)


def glass(wall: bool) -> Image.Image:
    # 64x64 = 8x8 blocks of 8x8 px. Thin pale frame, see-through pane, a shine.
    img = Image.new("RGBA", (64, 64))
    frame = (176, 206, 214, 255) if not wall else (140, 168, 178, 255)
    pane = (170, 220, 236, 70) if not wall else (150, 196, 214, 55)
    shine = (235, 250, 255, 170) if not wall else (210, 232, 240, 120)
    for by in range(8):
        for bx in range(8):
            for y in range(8):
                for x in range(8):
                    c = pane
                    if x == 0 or y == 0 or x == 7 or y == 7:
                        c = frame
                    elif x + y in (5, 6) and 1 < x < 6:
                        c = shine
                    img.putpixel((bx * 8 + x, by * 8 + y), c)
    return img


def clay_wall() -> Image.Image:
    src = Image.open(os.path.join(ROOT, "terrain", "clay.png")).convert("RGBA")
    out = Image.new("RGBA", src.size)
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src.getpixel((x, y))
            out.putpixel((x, y), (int(r * 0.86), int(g * 0.86), int(b * 0.88), a))
    return out


save(glass(False), "terrain/glass.png")
save(glass(True), "terrain/glass_wall.png")
save(clay_wall(), "terrain/clay_wall.png")

# Icons and held sprites for Glass: a small pane (16x16 drawn, 32x32 at detail 2 is not
# needed: item art is 16x16 placeholders).
atlas_path = os.path.join(ROOT, "tiles", "blocks.png")
atlas = Image.open(atlas_path).convert("RGBA")
if atlas.height < 20 * 8:
    grown = Image.new("RGBA", (atlas.width, 20 * 8))
    grown.paste(atlas, (0, 0))
    grown.paste(atlas.crop((0, 17 * 8, atlas.width, 18 * 8)), (0, 19 * 8))
    grown.save(atlas_path)
    print("blocks.png: added row 19")
