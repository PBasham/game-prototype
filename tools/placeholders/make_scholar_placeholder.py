"""Placeholder landing frame for the Scholar (idle pose, crouched).

Writes assets/sprites/scholar_placeholder.png/.json in the same format as
tools/import_aseprite.gd. Replace by adding a "Land" tag to art/Scholar-casual.aseprite;
tags in the main sheet win over this one.
Usage: python tools/placeholders/make_scholar_placeholder.py
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


land = crouch(frame(0), 3)

anims = [
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
dst = ROOT / "assets/sprites/scholar_placeholder"
out.save(dst.with_suffix(".png"))
dst.with_suffix(".json").write_text(json.dumps(
    {"anchor": meta["anchor"], "frame_size": [W, H], "frames": frames, "tags": tags}, indent=2))
print("wrote", dst)
