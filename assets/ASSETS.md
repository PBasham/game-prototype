# Assets

What the game draws, where it comes from, and the size/layout replacements must match.
Pixel scale: **1 tile = 8x8 px**. Art is drawn at 1x; the game shows it at 3x
(640x360 view scaled to 1920x1080).

Most terrain art is generated in code (`tools/generate_tiles.gd`), so it can tile
seamlessly and blend between materials. Regenerate everything with:

```
godot --headless --path . --script res://tools/generate_tiles.gd -- --export=game
```

## Player: `sprites/scholar.png` + `sprites/scholar.json`

Made from Patrick's `art/Scholar-casual.aseprite` by the importer:

```
godot --headless --path . --script res://tools/import_aseprite.gd -- --in=res://art/Scholar-casual.aseprite --out=res://assets/sprites/scholar
```

All frames side by side, cropped to the union of their bounds (currently 44x64 each).
The JSON has the foot anchor, per-frame durations and the Aseprite tags. The game uses
these tags: `Breath` (standing), `Jog` (moving, speed scales with velocity),
`Jump` (in the air), `Idle Pose` (climbing for now). Layers named `backdrop` and `Ref`
are skipped. Edit the .aseprite file and re-run the importer; nothing else changes.

### Placeholder: `sprites/scholar_jump.png` + `.json`

Cut from the Jog frames by `tools/placeholders/make_scholar_jump.py` (Python + Pillow).
Tags: `Jump Takeoff`, `Jump Rise`, `Jump Apex`, `Jump Fall`, `Land`, one frame each.
To replace: add tags with those exact names to `art/Scholar-casual.aseprite` (any number
of frames) and re-run the importer. Tags in the main sheet always win over this
placeholder, so no code changes are needed. Missing beats fall back to `Jump`.

## Terrain: `terrain/*.png` (64x64, seamless)

Drawn by `src/world/terrain.gdshader`, which blends them per pixel across tiles.

| File | Used by |
| --- | --- |
| dirt.png | dirt, grass (grass is drawn on top by the shader) |
| stone.png | stone, copper ore |
| planks.png | wood planks |
| ore_copper.png | transparent overlay of copper nuggets on stone |
| dirt_wall.png, stone_wall.png, planks_wall.png | background walls |
| noise.png | edge and blend noise (RGBA channels), not art |

Wood comes in three generated sets (`--wood=A|B|C` on the tile generator). B is the
default (thin long warm boards, no nails). The other two are kept in `terrain/alternates/`
as `planks_A.png` / `planks_wall_A.png` (olive, medium boards, nails) and `planks_C.png` /
`planks_wall_C.png` (light olive, tall short boards, nails). Copy one over `planks.png`
and `planks_wall.png`, or re-run the generator with `--wood=A`, to swap.

Grass colors live in `src/world/chunk_renderer.gd` (`GRASS_COLORS`).
Which texture a block uses is set on its TileDef (`terrain`, `grass_cover`, `ore_overlay`).

## Tiles: `tiles/blocks.png`

One 8 px row per block (`atlas_row` in `data/tiles`). Only **platforms and ropes** are
drawn from this atlas; solid rows just give the collision layer its tiles. Each row has
16 edge masks x 64 position pieces (column = `mask * 64 + piece`, piece =
`x % 8 + (y % 8) * 8`; mask bits: 1 up, 2 right, 4 down, 8 left = neighbor present).

| Row | Block |
| --- | --- |
| 0 | dirt |
| 1 | grass |
| 2 | stone |
| 3 | copper_ore |
| 4 | wood_planks |
| 5 | wood_platform (top 3 px walkable) |
| 6 | rope |

## Trees and decorations

| File | Notes |
| --- | --- |
| trees/pine_{green,olive,teal,gold}_{0,1,2}.png | foreground pines, bottom-centered on a grass tile, no outline |
| decor/flower_{0..4}.png | 5x10, stem at the bottom center |

## Backdrop: `backdrop/*.png`

Screen-space parallax layers (`src/world/backdrop.gd`), 1280 px wide and tiling
horizontally: `clouds.png`, `mountains.png`, `hills_0.png` (far), `hills_1.png` (near),
plus `sun.png` (fixed). The sky gradient is set in code.
