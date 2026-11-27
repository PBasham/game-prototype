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
    # 64x64 = 8x8 blocks of 8x8 px, one continuous pane (no frame per block: the terrain
    # shader draws a light rim where the glass meets open space). Long diagonal shines.
    img = Image.new("RGBA", (64, 64))
    pane = (170, 220, 236, 60) if not wall else (150, 196, 214, 50)
    shine = (235, 250, 255, 150) if not wall else (210, 232, 240, 110)
    for y in range(64):
        for x in range(64):
            c = pane
            k = (x + y) % 23
            if k in (0, 1) or k == 4:
                c = shine
            img.putpixel((x, y), c)
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


# Phase 40: Sand block and Sand Wall (128x128 detailed, like clay), and blocks.png row 20.
def sand_texture(wall: bool) -> Image.Image:
    import random
    random.seed(303)
    pal = [(0x5c, 0x4a, 0x24), (0x7f, 0x65, 0x32), (0xa3, 0x86, 0x4a), (0xb9, 0x9c, 0x5c),
           (0xc9, 0xad, 0x6c), (0xd6, 0xbd, 0x7f), (0xe4, 0xcf, 0x98)]
    img = Image.new("RGBA", (128, 128))
    for y in range(128):
        for x in range(128):
            r = random.random()
            i = 4 if r < 0.45 else (5 if r < 0.72 else (3 if r < 0.9 else (6 if r < 0.96 else 2)))
            # Soft ripples so it isn't flat noise.
            if (x + 2 * (y // 6)) % 11 == 0 and random.random() < 0.6:
                i = max(2, i - 1)
            c = pal[i]
            if wall:
                c = tuple(int(v * 0.8) for v in c)
            img.putpixel((x, y), c + (255,))
    return img


save(sand_texture(False), "terrain/sand.png")
save(sand_texture(True), "terrain/sand_wall.png")
atlas = Image.open(atlas_path).convert("RGBA")
if atlas.height < 21 * 8:
    grown = Image.new("RGBA", (atlas.width, 21 * 8))
    grown.paste(atlas, (0, 0))
    grown.paste(atlas.crop((0, 9 * 8, atlas.width, 10 * 8)), (0, 20 * 8))  # like clay's row
    grown.save(atlas_path)
    print("blocks.png: added row 20")
