# Assets

What the game draws, where it comes from, and the size/layout replacements must match.
Pixel scale: **1 tile = 8x8 px**. Art is drawn at 1x; the game shows it at 3x
(640x360 view scaled to 1920x1080).

Most terrain art is generated in code (`tools/generate_tiles.gd`), so it can tile
seamlessly and blend between materials. Regenerate everything with:

```
godot --headless --path . --script res://tools/generate_tiles.gd -- --export=game
```

## 3D body (Phase 20): `body3d/`

| File | What |
| --- | --- |
| `mannequin.glb` | **Placeholder** rigged mannequin (Rigify bone names, materials named by color group), from `tools/make_test_body.gd` (kept unless `--force`). Open it in Blender as a reference. |
| `scholar.glb` | Patrick's character, exported from Blender (not there yet). Rules: docs/3d-character.md. Source `.blend` goes in `art/body3d/`. |

The code-made styles (`fit`, `blocky`, `soft`, `round`) are built in code, no files.

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
| `scholar@x2n*`, `@x2s*`, `@x4s*`, `@x4ns*` | Upscaled sheets for the render test (Phase 19), from `python3 tools/upscale_doll.py`: nearest 2x, Scale2x 2x (base to refine), Scale2x 4x, nearest then Scale2x 4x. Rerun after reimporting. |

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
| items/{icons,held}/{stick,rock,copper_bar}.png | Phase 5 materials (stick and rock icons are unused: sticks give Wood, rocks Stone) |
| items/{icons,held}/{workbench,furnace,copper_anvil,chest,door}.png | furniture items |
| objects/workbench.png | 40x32 (5x4 tiles), top at hip height |
| objects/furnace.png | 32x40 (4x5 tiles), glows orange in game |
| objects/copper_anvil.png, objects/chest.png | 24x24 (3x3 tiles); the anvil sits on a stump |
| objects/door.png | 8x64 (1x8 tiles), closed, Starbound style: lintel, the door edge on (a 4 px slab with iron straps), hinge knuckles, handles |
| objects/door_open.png | 48x64: 2 frames of 24x64, open: the door face on (boards, rails, brace, hinge straps, ring handle), drawn 3 tiles wide starting at the hinge side of the 1 tile doorway; frame 1 is the mirror (hinge on the right). The item icon uses this face. |
| objects/magic_bag.png | 12x12, bottom-centered: the bag your items go into when you die |
| decor/berry_bush.png, decor/berry_bush_bare.png | 24x19, bottom-centered: full grown, ripe and picked |
| decor/berry_bush_young.png | 14x12, bottom-centered: young bush (no berries yet) |
| decor/raspberry_bush*.png, decor/blueberry_bush*.png | Same sizes as the berry bush: recolored placeholders (`art/concepts/berries/make_berries.py`) |
| items/icons + held: raspberries, blueberries, raspberry_compote, blueberry_mash | 16x16 icons (held 9x9 for the fruit), placeholders from the same script |
| items/{icons,held}/berries.png | berries (food) |
| decor/pickup_{stick,rock}.png | lying on the grass, bottom-centered: stick 12x5, rock 9x7 |
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

Also `moon.png` (28x28) and `stars.png` (320x130, tiles across the night sky), placeholders
from tools/make_item_art.gd.

Screen-space parallax layers (`src/world/backdrop.gd`), 1280 px wide and tiling
horizontally: `clouds.png`, `mountains.png`, `hills_0.png` (far), `hills_1.png` (near),
plus `sun.png` (fixed). The sky gradient is set in code.

## Phase 7 placeholders (tools/make_item_art.gd)

| File | Size | Notes |
|---|---|---|
| enemies/slime.png | 108x27 | 3 frames of 36x27 (rest, squash, air), pale; tinted per enemy |
| objects/bed.png | 72x24 | Bed, 9x3 tiles |
| items/icons/ and items/held/: slime, wooden_sword, copper_sword, copper_helmet, copper_chestplate, copper_greaves, bed | | Icons and held sprites |

## Armor overlays: `armor/*.png` (tools/make_armor_art.gd)

1232x64 strips, one 44x64 cell per doll frame, laid out like one row of
`sprites/scholar_parts.png`. Placeholders cut from the body parts and shaded copper.

| File | Part |
|---|---|
| copper_helmet_head.png | Head (top half, 1 px rim) |
| copper_chestplate_torso.png, _front_arm_upper.png, _back_arm_upper.png | Chest and shoulders |
| copper_greaves_front_leg_upper.png, _back_leg_upper.png, _front_leg_lower.png, _back_leg_lower.png | Legs (feet left bare) |

## Phase 7 spell icons (tools/make_item_art.gd -- --new-spells)

`items/icons/levitate.png`, `hyper_drill.png`, `air_push.png`, `blink.png`, `light_orb.png`,
`mend.png`: 16x16 placeholders. The Light Orb, Blink and Air Push effects are drawn in
code (`src/combat/light_orb.gd`, `src/combat/spell_effect.gd`).

## Scrolls and the Spell Weaving Table (tools/make_item_art.gd -- --scrolls)

`items/icons/paper.png`, `blank_scroll.png`, `scroll_<spell>.png` (parchment with the spell's
icon), `page_<spell>.png` (a flat torn page with a gold corner and the spell's icon, plus
`items/held/page_<spell>.png`), `spell_weaving_table.png`, and `objects/spell_weaving_table.png` (48x24, 6x3 tiles).
Also `items/icons/wisp.png` (spell). Placeholders.

## Phase 8 placeholders

`items/icons/gel_cushion.png` (spell), `scroll_gel_cushion.png`. The Gel Cushion splat is
drawn in code (`SpellEffect.Kind.SPLAT`). **Sound wanted:** `gel_cushion_used` (a squish
when it saves you), played through `EventBus.sound_requested` once audio exists.

## Phase 8 spell icons and scrolls

`items/icons/` arcane_bolt, healing_circle, spark_ward, familiar, conjure_platform,
arcane_edge, barrier, chain_spark, recall, seek_ore (16x16) and a `scroll_<spell>` for each.
Effects (zone, ward rune, familiar, platform, ore outlines, lightning, ritual ring, shield
bubble) are drawn in code in `src/combat/`.

## Sounds: `sounds/*.wav` (placeholders from tools/make_sounds.gd)

Synthesized blips, sweeps and noise. Replace any with a real file of the same name (.wav
or .ogg); the generator never overwrites without `--force`.

| Sound | When |
|---|---|
| cast_projectile, cast_gust, cast_blink, cast_light, cast_buff, cast_zone, cast_ward, cast_summon, cast_conjure, cast_chain, cast_ritual, cast_sense | A spell of that type is cast |
| bolt_charge, bolt_fire | Arcane Bolt starts charging, fires |
| toggle_on, toggle_off | A concentration spell turns on or off |
| gel_cushion_used | Gel Cushion saves you from a fall |
| ward_trigger, familiar_shot, platform_fade | A ward goes off, the familiar shoots, a conjured platform fades |
| shield_pop, shield_block | Barrier pops, its shield soaks a whole hit |
| buff_end | A buff runs out |
| ritual_start, ritual_done | A ritual begins, completes |
| learn_spell | You learn a spell from a scroll |
| player_hurt | You take damage |
| enemy_hit, enemy_die, slime_hop | An enemy is hit, dies, a slime hops (slime_land is made but not used yet) |
| swing | A melee weapon swings |
| mine_hit, block_break, block_place | Mining a tile, a block breaking, a block placed |
| item_pickup, craft, eat, door | Picking something up, crafting, eating, a door opening or closing |

## Log cabin (playtest round 3)

| File | What |
| --- | --- |
| terrain/logs.png, terrain/logs_wall.png | Log cabin block and back wall (64x64, rounded horizontal logs, style B2; the wall is the same darkened). Hand-made placeholders, not from generate_tiles.gd. The block ends sticking out 2 px are drawn by the terrain shader (`overhang_px` on the tile) |
| items/{icons,held}/log.png | Copies of the old wood (log) icon and held sprite |
| tiles/blocks.png row 7 | Collision row for the log block (a copy of the planks row) |

## Phase 9: underground

| File | What |
| --- | --- |
| objects/campfire.png, items/{icons,held}/campfire.png | Campfire (32x24, 4x3 tiles): stone ring, crossed logs, flames. Hand-drawn placeholder |
| items/{icons,held}/iron_{ore,bar,sword,helmet,chestplate,greaves}.png, armor/iron_*.png | The copper versions recolored grey (wood kept) |
| terrain/ore_iron.png | The copper ore overlay recolored |
| tiles/blocks.png row 8 | Collision row for iron ore (copy of the copper ore row) |
| decor/pickup_{field_mushroom,red_cap,duskcap,glowcap}.png, items/{icons,held}/ same names | Mushrooms (9x8 on the ground), hand-made placeholders. The icon and held sprites are the 9x8 ground sprite centered on 16x16 (Patrick: the full-size ones read too big) |

## Food and alchemy

| File | What |
| --- | --- |
| terrain/clay.png | Clay block (64x64): the dirt texture recolored terracotta. Not made by generate_tiles.gd |
| tiles/blocks.png row 9 | Collision row for clay (copy of the dirt row) |
| items/{icons,held}/clay.png | Clay block icon |
| items/{icons,held}/clay_flask.png | Empty clay flask (16x16) |
| items/{icons,held}/{poison_coating,poison_flask}.png | 32x32 clay (detail 2): the thin vial and a round ball, green wax, from `art/concepts/flasks/make_poison.py`; badges `items/badges/{poison,poison_throw}.png` (drop, skull) |
| items/{icons,held}/{wooden_bowl,mushroom_stew,roasted_berries,cooked_mushroom}.png | Food placeholders (16x16) |
| objects/alchemy_table.png, items/{icons,held}/alchemy_table.png | Alchemy Table (40x24, 5x3 tiles): table, three flasks, a jar, mortar and pestle |

## Concepts (not used in game yet)

| File | What |
| --- | --- |
| art/concepts/flasks/{clay,glass}_{thin,regular,large}_{empty,healing,mana}.png | 32x32 flask concepts Patrick picked: clay (wax seal, glaze band, corner badge) and glass for the later desert tier, in three sizes. Made by `make_flasks.py` (Python, PIL). For when icons move to 32x32 (16 px tiles); the game's slots draw icons at 16x16 today |
| art/concepts/flasks/icon_compare.png | The flasks at 16, 24 and 32 px in real inventory slots, at today's and other scales |
| art/concepts/terrain16/ | 16x16-per-block dirt and stone concepts (128x128 seamless, 8x8 blocks each) and a side by side with today's 8x8 terrain. Made by `terrain16.py` |

## Phase 10: detailed art

| File | What |
| --- | --- |
| terrain/{dirt,stone,dirt_wall,stone_wall,clay}.png | 128x128 detailed versions (16 art pixels per block) from `generate_tiles.gd --export=terrain_hd`; same recipes as the 64x64 ones |
| items/{icons,held}/{healing_potion,mana_potion,clay_flask}.png | 32x32 thin clay vials (detail 2) from `art/concepts/flasks/make_flasks.py` |
| items/badges/{heal,mana}.png | 8x8 inventory badges (heart, star) |
| objects/{workbench,furnace,copper_anvil,campfire,alchemy_table,spell_weaving_table}.png | Stations at 2x detail (`ObjectDef.detail = 2`): the 1x art through `art/concepts/stations/detail2x.py` (Scale2x, 1 px lit and shaded edges, wood grain, grit) |
| objects/{table,shelf}.png, items/{icons,held}/{table,shelf}.png | Table (64x48, 4x3 tiles) and Shelf (48x16, 3x1, on a back wall), drawn at 1x in the workbench's wood colors by `art/concepts/stations/furn.py`, then the same 2x pass |
| objects/scribes_desk.png, items/{icons,held}/scribes_desk.png | Scribe's Desk (4x3 tiles, detail 2): a writing desk with an open scroll, inkwell and quill, candle. Hand-drawn placeholder (PIL) |
| objects/lumber_rack.png, items/{icons,held}/lumber_rack.png | Lumber Rack (5x4 tiles, detail 2): 2 frames of 80x64, the rack behind and its front posts; the logs are drawn in code. `tools/make_phase37_art.py` |
| objects/potion_cabinet.png, items/{icons,held}/potion_cabinet.png | Potion Cabinet (3x5 tiles, detail 2): 48x80, glass doors, 4 shelves; bottles are drawn in code (`ObjectLayer.draw_bottle`). From `tools/make_potion_storage_art.py` |
| objects/potion_bookcase.png, objects/potion_shelf.png (+ icons, held) | Potion Bookcase (4x6, 64x96, 5 shelves) and Potion Shelf (3x2, 48x32, one plank). Same script |
| items/{icons,held}/{clay_bottle,clay_jug,glass_vial,glass_bottle,glass_flask}.png | Copies of the empty flask concepts (`art/concepts/flasks/*_empty.png`). Same script |
| items/{icons,held}/{sand,glass}.png | Sand pile and glass pane placeholders. Same script |
| terrain/glass.png, terrain/glass_wall.png | 64x64 Glass block and wall: one continuous see-through pane (alpha ~0.25) with long diagonal shines; the rim is drawn by the shader. Placeholders from `tools/make_glass_clay_art.py` |
| terrain/clay_wall.png | The clay block art darkened. Same script |
| items/{icons,held}/{healing,mana}_{clay_bottle,clay_jug,glass_vial,glass_bottle,glass_flask}.png | Filled bottles (32x32) from `art/concepts/flasks/make_flasks.py` via `tools/make_phase37_art.py` |
| objects/{pantry_rack,food_pantry,bookshelf,tall_bookshelf,barrel,crate,liquid_barrel,iron_liquid_barrel}.png (+ icons, held) | Storage placeholders (detail 2). Same script |
| objects/hanging_net_{small,medium,long,large}.png (+ icons, held) | Nets (4x2, 2x3, 2x5, 6x4; ropes 4 art px thick), 2 frames: rope and bag, then the mesh drawn over the contents. Same script |
| objects/potion_cabinet.png, potion_bookcase.png | Now 2 frames: the cabinet, then its glass doors (`front_frame`). `tools/make_potion_storage_art.py` |
| terrain/sand.png, terrain/sand_wall.png | 128x128 detailed sand grains with soft ripples (the wall darker). `tools/make_glass_clay_art.py` |
| ui/empower/<node id>.png | 16x16 Empower node icons (pick head, axe head, expanding arrows, reaching hand, drop, flame, zigzag, swoosh, hourglass, slime, two orbs and a plus). `tools/make_empower_icons.py` |
| terrain/sand_bricks.png, terrain/sand_bricks_wall.png, items/{icons,held}/sand_bricks.png | Placeholder Sand Bricks from the sand texture's colors (`tools/make_brick_art.py`, Phase 52) |
| items/{icons,held}/water_{clay_flask,clay_bottle,clay_jug,glass_vial,glass_bottle,glass_flask}.png, ui/icon_thirst.png, ui/icon_breath.png | Placeholder water bottles (the flask drawer with blue water), a drop and a bubble (`tools/make_water_art.py`, Phase 54) |
| terrain/hard_sand.png, terrain/hard_sand_wall.png, items/{icons,held}/hard_sand.png | Placeholder Hard Sand: the sand pictures darker and redder with flat layers (`tools/make_voxel_art.py`, Phase 55) |
| enemies/crab.png, enemies/fish.png, items/{icons,held}/{raw_crab,crab_legs,raw_fish,cooked_fish}.png, decor/{kelp,kelp_top,seagrass_0..2,dune_grass_0..1}.png | Placeholder sea life: crab (3 frames 16x10), fish (3 frames 14x8), the four foods, kelp pieces and tufts (`tools/make_sea_life_art.py`, Phase 56) |
| items/{icons,held}/bomb.png | 16x16 placeholder Bomb: a dark round bomb with a lit fuse (`tools/make_voxel_art.py`, Phase 52) |
| sounds/bomb.wav | Placeholder explosion (`tools/make_sounds.gd`, Phase 52) |
| items/icons/shaping_spell.png (+ scroll_, page_ icons) | 16x16 Shaping Spell: a small mallet over a slope. Placeholder (`make_item_art.gd --new-spells`, Phase 51) |
| items/{icons,held}/siphon_liquid.png (+ scroll_, page_ icons) | 16x16 Siphon Liquid: a blue drop under a curling arrow. Placeholder (PIL, Phase 45) |
| items/{icons,held}/glow_potion.png, items/badges/glow.png | Glow Potion: a thin clay flask with teal glaze (`make_flasks.draw`), and an 8x8 sparkle badge. Placeholders |
| tiles/blocks.png row 20 | Sand's collision row (a copy of clay's). Same script |
| tiles/blocks.png row 19 | Glass's collision row (a copy of row 17). Same script |
| items/{icons,held}/spellbook_t{1,2,3}.png | Tier 1 / 2 / 3 Spellbooks: the Basic Spellbook recolored green, blue, purple |
| items/icons/tele_grab.png (+ scroll_ and page_ icons) | 16x16 Tele Grab spell icon: a violet swirl pulling in an ore chunk. Placeholder from `art/concepts/spells/make_tele_grab.py` |
| trees/darkwood_{0,1,2}.png | Darkwood trees, 104 wide, 180 / 230 / 280 tall: purple-brown trunk, round dark crown. Placeholders from `art/concepts/dark_forest/make_dark_forest.py` |
| backdrop/dark_forest_far.png, backdrop/dark_forest_near.png | 1280x480, tiles sideways: dark trunks under a canopy (`--backdrops` on the same script) |
| terrain/darkwood_planks.png, terrain/darkwood_planks_wall.png | 64x64 darkwood planks (block, back wall) |
| items/{icons,held}: dark_log, darkwood, magic_essence, spirit_core | 16x16 icons, same script |
| enemies/forest_spirit.png | 72x24: three 24x24 frames (drifting, charging, shooting) |
| decor/darkwood_sapling.png, items/{icons,held}/darkwood_sapling.png | 9x14 darkwood sapling (and its icon). Same script, `--sapling` |
| items/icons/call_spirit.png (+ scroll_, page_ icons) | Call Spirit: the spirit's first frame over a ring. Placeholder |
| items/icons/air_step.png, bound.png (+ scroll_, page_ icons) | 16x16 spell icons: cloud steps with an up chevron; an arcing arrow. Placeholders |
| objects/darkwood_workbench.png (+ icon, held) | The Workbench recolored to darkwood (80x64, detail 2). Placeholder (`--phase16` on `art/concepts/dark_forest/make_dark_forest.py`) |
| terrain/reinforced_wood{,_wall}.png, terrain/reinforced_darkwood{,_wall}.png | 64x64 planks with iron straps (one every 2 blocks) and rivets (one per block); icons and held sprites cut from them. Same script |
| tiles/blocks.png rows 11, 12 | Collision atlas rows for the reinforced blocks (copies of the planks row) |
| terrain/darkwood_logs.png, terrain/darkwood_logs_wall.png | The log block and wall recolored to darkwood. Placeholders |
| tiles/blocks.png row 13 | Collision row for the darkwood log block (copy of the log row) |
| objects/chair.png (+ icon, held) | Wooden Chair, 32x48 (2x3 tiles, detail 2), backrest left, seat 24 art px up. Placeholder (`art/concepts/chair/make_chair.py`) |


## Phase 21 placeholders

| Files | What |
| --- | --- |
| `terrain/dark_forest_{dirt,dirt_wall,stone,stone_wall}.png`, `items/{icons,held}/dark_forest_{dirt,stone}.png` | **Placeholder**: the dirt and stone art blended toward black with a hint of blue (`python3 tools/make_dark_forest_terrain.py --force`). |
| `terrain/{stone_bricks,dark_forest_stone_bricks}{,_wall}.png`, their icons and held sprites | **Placeholder** bricks built from each stone's colors (`python3 tools/make_brick_art.py --force`). |
| `items/{icons,held}/forest_spirit_pendant.png` | **Placeholder** pendant icon (same tool). |
| `tiles/blocks.png` rows 14 to 18 | Copies of the dirt, grass and stone rows (dark forest blocks, bricks): collision only, the terrain shader draws them. |

| `items/icons/{summon_slime,scroll_summon_slime,page_summon_slime,slime_core}.png` (and held) | **Placeholder**: the Summon Forest Spirit icons and the spirit core, turned slime green. |

## Phase 24: tools are spells

| File | Status |
| --- | --- |
| `fx/phantom_pickaxe.png`, `fx/phantom_axe.png` | **Placeholder** (32x32, pale so the rank tint colors them): the old copper pickaxe and axe art, doubled and whitened. The gathering spells' phantom tools. |
| `items/{icons,held}/copper_dagger.png` | **Placeholder**: the Copper Sword cut short (`tools/make_dagger_art.py`). |
| `sounds/phantom_mine.wav`, `phantom_chop.wav` | **Placeholder** (`tools/make_sounds.gd`): the phantom tool landing. |
| Removed | Pickaxe, axe, stone tool, hand hammer and flint art (those items are gone). |

## Phase 25: weapons and schools

| File | Status |
| --- | --- |
| `items/icons/dual_storm_axes.png` (two crossed), `items/held/dual_storm_axes.png` (one axe, drawn in each hand) | **Placeholder** (`tools/make_storm_art.py`) |
| `items/{icons,held}/storm_charm.png` | **Placeholder** (`tools/make_storm_art.py`) |
| `sounds/slam.wav` | **Placeholder** (`tools/make_sounds.gd`): the leap slam landing |
