"""Upscaled copies of the paper doll's sprite sheet, for the doll render tests
(PaperDoll art scale and turning method, console `doll`).

    python3 tools/upscale_doll.py            # from assets/sprites/scholar

Writes assets/sprites/scholar@<variant>_parts.png and .json next to the original:
  x2n   2x, each pixel a 2x2 block (looks the same, finer turning)
  x2s   2x with Scale2x (smoother diagonals, no new colors, so recoloring still works)
  x4s   4x: Scale2x twice (1x art turned the RotSprite way)
  x4ns  4x: 2x blocks, then Scale2x (2x plain art turned the RotSprite way)
Run it again after re-importing the Aseprite file. Scale2x only copies existing
colors, so the palette swap keeps working.
"""
import json
import sys

import numpy as np
from PIL import Image

BASE = sys.argv[1] if len(sys.argv) > 1 else "assets/sprites/scholar"


def scale2x(a: np.ndarray) -> np.ndarray:
    """Scale2x (EPX) on an RGBA array (h, w, 4)."""
    h, w, _ = a.shape
    v = a.view(np.uint32).reshape(h, w)
    p = np.pad(v, 1, mode="constant")
    B, D, E, F, H = p[:-2, 1:-1], p[1:-1, :-2], p[1:-1, 1:-1], p[1:-1, 2:], p[2:, 1:-1]
    e0 = np.where((D == B) & (B != F) & (D != H), D, E)
    e1 = np.where((B == F) & (B != D) & (F != H), F, E)
    e2 = np.where((D == H) & (D != B) & (H != F), D, E)
    e3 = np.where((H == F) & (D != H) & (B != F), F, E)
    out = np.empty((h * 2, w * 2), dtype=np.uint32)
    out[0::2, 0::2], out[0::2, 1::2], out[1::2, 0::2], out[1::2, 1::2] = e0, e1, e2, e3
    return out.view(np.uint8).reshape(h * 2, w * 2, 4)


def nearest2x(a: np.ndarray) -> np.ndarray:
    return a.repeat(2, axis=0).repeat(2, axis=1)


VARIANTS = {"x2n": (2, [nearest2x]), "x2s": (2, [scale2x]), "x4s": (4, [scale2x, scale2x]),
            "x4ns": (4, [nearest2x, scale2x])}
STEP_NAMES = {nearest2x: "n", scale2x: "s"}


def scale_meta(meta: dict, k: int, steps: list) -> dict:
    m = json.loads(json.dumps(meta))
    m["upscale"] = [STEP_NAMES[s] for s in steps]
    m["frame_size"] = [v * k for v in m["frame_size"]]
    m["anchor"] = [v * k for v in m["anchor"]]
    m["art_scale"] = k
    for f in m.get("frames", []):
        if "x" in f:
            f["x"] *= k
        for key, pv in f.get("pivots", {}).items():
            f["pivots"][key] = [pv[0] * k + (k - 1) / 2.0, pv[1] * k + (k - 1) / 2.0]
    return m


def main() -> None:
    meta = json.load(open(BASE + ".json"))
    parts = np.array(Image.open(BASE + "_parts.png").convert("RGBA"))
    for name, (k, steps) in VARIANTS.items():
        a = parts
        for step in steps:
            a = step(a)
        Image.fromarray(a, "RGBA").save("%s@%s_parts.png" % (BASE, name))
        json.dump(scale_meta(meta, k, steps), open("%s@%s.json" % (BASE, name), "w"), indent=1)
        print("wrote %s@%s (%dx%d)" % (BASE, name, a.shape[1], a.shape[0]))


if __name__ == "__main__":
    main()
