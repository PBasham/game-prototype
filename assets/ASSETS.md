# Assets

What the game draws, where it comes from, and the size/layout replacements must match.
Pixel scale: **1 tile = 8x8 px**. Art is drawn at 1x; the game shows it at 3x
(640x360 view scaled to 1920x1080).

Most terrain art is generated in code (`tools/generate_tiles.gd`), so it can tile
seamlessly and blend between materials. Regenerate everything with:

```
godot --headless --path . --script res://tools/generate_tiles.gd -- --export=game
```

## Player: `sprites/scholar*`

Made from Patrick's `art/Scholar-casual.aseprite` by the importer:

```
godot --headless --path . --script res://tools/import_aseprite.gd -- --in=res://art/Scholar-casual.aseprite --out=res://assets/sprites/scholar
```

| File | What |
| --- | --- |
| `scholar_parts.png` | What the game draws: every frame, one row per body layer (paper doll parts) |
| `scholar.json` | Frame size, foot anchor, durations, tags, part list, pivots |
| `scholar.png` | Flattened frames (one-piece), for previews; not used in game |
| `scholar_palette.tres` | Recolorable color groups (skin, tunic, pants, leather, trim, hair), from `tools/make_character_palette.gd` |
| `scholar_look.tres` | Default look: colors (none changed) and hairstyle |
| `hair/short.png` | **Placeholder** hairstyle, 9x6, faces right (drawn by `make_character_palette.gd`) |

Frames are 44x64, feet at (20, 64). How to draw for the paper doll (layers, tags,
pivots, arm poses) is in [docs/character-art.md](../docs/character-art.md).

Held items in debug builds (keys 1 to 0: tools, wand, dagger, swords, spell book,
crossbow, bow) are **placeholder** shapes drawn in code
(`src/player/doll/dev_held_items.gd`); real items come in Phase 4.

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
| decor/sapling.png | 9x14 placeholder (tools/make_item_art.gd), stem at the bottom center |

## Items: `items/` (placeholders from tools/make_item_art.gd)

| File | Notes |
| --- | --- |
| items/icons/<item id>.png | 16x16 inventory icon. Tools point up-right, handle bottom-left. Block icons are cut from the terrain textures. |
| items/held/<item id>.png | Sprite drawn in hand. Tools: same as the icon (grip pixel in the item's `held.grip`). Blocks 7x7, small items 9x9. |
| items/icons/mining_spell.png | 16x16 spell icon (spells have icons only; the hand shows the equipped book) |
| items/icons/basic_spellbook.png, items/held/basic_spellbook.png | 11x11 book, upright, spine left; grip pixel (5, 9) |
| items/icons/{chopping_spell,fly,spark}.png | 16x16 placeholder spell icons |
| items/icons/torch.png, items/held/torch.png | torch item |
| objects/rope.png | 32x8: 4 frames of 8x8: single, top, middle, bottom |
| objects/torch.png | 32x16: 4 frames of 8x16 (2 tiles tall): standing, on a block to the left, to the right, on a back wall |
| items/{icons,held}/{stick,rock,flint,copper_bar,hand_hammer,stone_pickaxe,stone_axe}.png | Phase 5 materials and stone tools |
| items/{icons,held}/{workbench,furnace,copper_anvil,chest,door}.png | furniture items |
| objects/workbench.png | 40x32 (5x4 tiles), top at hip height |
| objects/furnace.png | 32x40 (4x5 tiles), glows orange in game |
| objects/copper_anvil.png, objects/chest.png | 24x24 (3x3 tiles); the anvil sits on a stump |
| objects/door.png | 8x64 (1x8 tiles), closed: planks, three rails, hinges on the left, handle on the right |
| objects/door_open.png | 16x64: 2 frames of 8x64 (1x8 tiles, like closed), Starbound style: lintel and a thin post, the door edge on (3 px) along the hinge side with its handle (frame 0 hinge left, frame 1 hinge right) |
| objects/magic_bag.png | 12x12, bottom-centered: the bag your items go into when you die |
| decor/berry_bush.png, decor/berry_bush_bare.png | 24x19, bottom-centered: full grown, ripe and picked |
| decor/berry_bush_young.png | 14x12, bottom-centered: young bush (no berries yet) |
| items/{icons,held}/berries.png | berries (food) |
| decor/pickup_{stick,rock,flint}.png | lying on the grass, bottom-centered: stick 12x5, rock 9x7, flint 7x6 |
| fx/cracks.png | 32x8: 4 crack stages of 8x8, lighter to heavier, drawn over damaged blocks |

Replace any of these with real art under the same name; if the size changes, check the
item's `held.grip` (the pixel the hand holds).

## UI: `ui/` (placeholders from tools/make_ui_art.gd)

Nine-slice images drawn by `UiSkin` (src/ui/ui_skin.gd). The number is the margin (px
from each edge that doesn't stretch); change it in `UiSkin.MARGINS` if real art differs.

| File | Size | Margin | Notes |
| --- | --- | --- | --- |
| ui/panel.png | 32x32 | 8 | Window frame: wood border, brass line and corner studs, leather inside |
| ui/title.png | 24x14 | 6 | Parchment title strip (text is dark ink) |
| ui/slot.png, slot_hot.png, slot_selected.png, slot_magic.png | 20x20 | 4 | Item slot: normal, hovered, selected (brass), spell / equipment |
| ui/button.png, button_hot.png, button_pressed.png, button_disabled.png | 24x16 | 5 | Wood plank buttons |
| ui/row_hot.png | 12x12 | 3 | Highlighted list row |
| ui/field.png | 16x16 | 4 | Text field and slider track |
| ui/icon_health.png, icon_mana.png, icon_hunger.png | 8x8 | | Status panel icons (heart, mana drop, food) |

## Backdrop: `backdrop/*.png`

Screen-space parallax layers (`src/world/backdrop.gd`), 1280 px wide and tiling
horizontally: `clouds.png`, `mountains.png`, `hills_0.png` (far), `hills_1.png` (near),
plus `sun.png` (fixed). The sky gradient is set in code.
