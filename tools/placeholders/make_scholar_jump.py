"""Placeholder jump frames for the Scholar, cut from the Jog frames.

Writes assets/sprites/scholar_jump.png/.json in the same format as tools/import_aseprite.gd.
Replace by adding real tags with these names to art/Scholar-casual.aseprite; tags in the
main sheet win over this one. Usage: python tools/placeholders/make_scholar_jump.py
"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets/sprites/scholar"
W, H = 44, 64
CUT = 38  # row where the tunic hem ends and the legs begin

sheet = Image.open(SRC.with_suffix(".png")).convert("RGBA")


def frame(i: int) -> Image.Image:
    return sheet.crop((i * W, 0, i * W + W, H))


def crouch(img: Image.Image, rows: int) -> Image.Image:
    """Lower the body by dropping `rows` rows from the thighs."""
    out = Image.new("RGBA", (W, H))
    out.alpha_composite(img.crop((0, CUT + 2 + rows, W, H)), (0, CUT + 2 + rows))
    out.alpha_composite(img.crop((0, 0, W, CUT + 2)), (0, rows))
    return out


def splice(top: Image.Image, legs: Image.Image, cut: int) -> Image.Image:
    out = Image.new("RGBA", (W, H))
    out.alpha_composite(legs.crop((0, cut, W, H)), (0, cut))
    out.alpha_composite(top.crop((0, 0, W, cut)), (0, 0))
    return out


def tuck(img: Image.Image, rows: int) -> Image.Image:
    """Pull the legs up by squashing them into fewer rows."""
    legs = img.crop((0, CUT, W, H))
    legs = legs.resize((W, H - CUT - rows), Image.NEAREST)
    out = Image.new("RGBA", (W, H))
    out.alpha_composite(legs, (0, CUT))
    out.alpha_composite(img.crop((0, 0, W, CUT)), (0, 0))
    return out


PANT = (76, 135, 239, 255)
PANT_SHADE = (69, 118, 208, 255)
PANT_DARK = (54, 103, 195, 255)
BOOT = (79, 60, 57, 255)
BOOT_LIGHT = (101, 64, 57, 255)


def knee_up(img: Image.Image) -> Image.Image:
    """Redraw the front leg of Jog frame 16 with the knee raised forward."""
    out = img.copy()
    px = out.load()
    for y in range(37, H):
        for x in range(25, W):
            px[x, y] = (0, 0, 0, 0)
    # Thigh: hip to knee, angled forward.
    for y in range(37, 43):
        x0 = 26 + (y - 37)
        for x in range(x0, x0 + 5):
            px[x, y] = PANT_DARK if x == x0 else (PANT_SHADE if x == x0 + 4 else PANT)
    # Shin: knee down, tilting back a little.
    for y in range(43, 51):
        x0 = 31 - (y - 43) // 4
        for x in range(x0, x0 + 4):
            px[x, y] = PANT_DARK if x == x0 else (PANT_SHADE if x == x0 + 3 else PANT)
    # Boot, toe pointing forward.
    for y in range(51, 56):
        for x in range(29, 31):
            px[x, y] = BOOT_LIGHT if x == 30 else BOOT
    for x in range(29, 33):
        px[x, 56] = BOOT
    return out


takeoff = crouch(frame(14), 3)
rise = knee_up(frame(16))
apex = tuck(frame(15), 6)
fall = splice(frame(16), frame(14), 40)
land = crouch(frame(0), 3)

anims = [
    ("Jump Takeoff", [takeoff], 70),
    ("Jump Rise", [rise], 100),
    ("Jump Apex", [apex], 100),
    ("Jump Fall", [fall], 100),
    ("Land", [land], 80),
]
images = [im for _, ims, _ in anims for im in ims]
out = Image.new("RGBA", (W * len(images), H))
frames, tags, i = [], {}, 0
for name, ims, ms in anims:
    tags[name] = [i, i + len(ims) - 1]
    for im in ims:
        out.alpha_composite(im, (i * W, 0))
        frames.append({"x": i * W, "duration_ms": ms})
        i += 1
meta = json.loads(SRC.with_suffix(".json").read_text())
dst = ROOT / "assets/sprites/scholar_jump"
out.save(dst.with_suffix(".png"))
dst.with_suffix(".json").write_text(json.dumps(
    {"anchor": meta["anchor"], "frame_size": [W, H], "frames": frames, "tags": tags}, indent=2))
print("wrote", dst)
