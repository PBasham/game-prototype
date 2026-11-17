# Items, inventory, mining, placing and plants

Everything Phase 4 added: what it does, where it lives, and every number you can tweak.
Live tweaking works like everywhere else: run the game, Scene panel **Remote**, select
the node (`ItemUser`, `Plants`, `Hud`, a drop under `Drops`) and edit it in the
Inspector. Permanent changes go in the `.tres` or the script's `@export` default.

## Controls

| Input | What it does |
| --- | --- |
| **1 to 0**, mouse wheel | Pick a hotbar slot |
| **Left click** | Use the held item: swing, mine, chop, place, plant. Hold to repeat. |
| **Ctrl + mouse wheel** | Change the area (mining spell 1x1 to 3x3; blocks, walls and grass seeds 1x1 to 2x2). Wheel up = bigger. |
| **E** (or Tab) | Open / close the inventory |
| **Q** | Throw the selected stack |
| **H** | Put the held item away / take it out |
| **Right click** | Reserved for interacting (doors, chests later). The debug brush still uses it to place. |

Inventory panel (E): 4 rows of 10, the top row is the hotbar.

- Left click: pick up a stack, put it down, merge or swap.
- Right click: take half, or put one down from the stack on the mouse.
- Shift + left click: move a stack between the hotbar and the rest.
- Click the world with a stack on the mouse: throw it. Closing the panel puts it back.
- Hover a slot for its tooltip.

While the mouse is over the hotbar or panel, or you're carrying a stack, clicks don't
use items.

## Items: `data/items/*.tres`

Each item is an `ItemData` (`src/items/item_data.gd`). Open one in the Inspector:

| Field | Meaning |
| --- | --- |
| `kind` | MATERIAL, BLOCK, WALL, TOOL, SPELL, SEED, WEAPON (sorting and tooltips) |
| `icon` | 16x16 inventory icon |
| `max_stack` | 999 for blocks and materials, 1 for tools |
| `held` | How it looks in hand: texture, grip pixel, item type (`data/item_types/`) |
| **Mining** | |
| `mining_damage` | Damage to blocks per hit, or per second for a beam |
| `axe_damage` | Damage to trees per hit |
| `hammer_damage` | Damage to walls per hit (no hammer exists yet) |
| `beam` | Mines continuously while held (the mining spell) |
| `mining_area` | Area in tiles (2 = 2x2). Pickaxes have a fixed area. |
| `mining_area_max` | Biggest area for the Ctrl + wheel toggle (0 = no toggle) |
| `reach_tiles` | How far it reaches, measured from the chest |
| `impact_at` | When in the swing the hit lands (0 to 1 through the animation) |
| **Placing** | |
| `places_block` / `places_wall` | Tile id it places |
| `plants` | `tree` (a sapling on grass) or `grass` (turns dirt into grass) |
| `free_place` | Can go anywhere in reach; otherwise it must touch a block or wall |
| `place_area_max` | Biggest square the area toggle places at once |

Current items:

| Item | Notes |
| --- | --- |
| Copper Pickaxe | 25 per hit, 2x2, reach 10 |
| Copper Axe | 25 per hit on trees (a tree has 100), reach 10 |
| Mining Spell | Beam, 55 per second on every tile in the area, area 2 (toggle 1 to 3), reach 12. Slightly weaker than the pickaxe (25 per 0.35 s swing is about 71 per second). |
| Dirt, Stone, Copper Ore, Wood Planks, Wood Platform, Rope | Blocks |
| Wood Wall | Background wall; placed without a tool, removed with a hammer (later) |
| Wood | From trees; becomes planks when crafting exists |
| Tree Seed | Plant on grass; grows into a tree |
| Grass Seeds | Plant on dirt that touches air; turns it into grass |

The defaults come from `tools/make_items.gd`. It never overwrites a file you edited
unless you pass `--force` (or `--only=<id> --force` for one):

```
godot --headless --path . --script res://tools/make_items.gd
```

Placeholder art (icons, held sprites, the sapling, the cracks) comes from
`tools/make_item_art.gd`; your art replaces the PNGs with the same names
(`assets/items/icons/<id>.png`, `assets/items/held/<id>.png`).

The two item types this phase added (`data/item_types/`): **block** (held small, a quick
reach toward the cursor when placing) and **spell** (the hand points at the cursor and
channels while held).

## Starting kit and the character file

A character is saved separately from worlds: `user://characters/default.gpchar` (name
and inventory). Until character select exists (Phase 7) there's one automatic
character. The first time you start a world it's made with the starting kit:

pickaxe, axe, mining spell, 50 planks, 30 platforms, 50 wood walls, 30 rope, 5 tree
seeds, 10 grass seeds, 20 dirt.

To change the kit: `STARTING_KIT` in `src/items/character_data.gd`. To get a fresh
character, delete `default.gpchar` (in the folder Project > Open User Data Folder
opens). The character saves with the world (autosave, Save, Save & Quit).

Debug builds also put the placeholder weapons (dev sword, bow, book...) in the second
inventory row. They're for testing animations, not content, and are never saved.

## Mining

- Blocks have health (`health` in `data/tiles/*.tres` and `data/walls/*.tres`): dirt
  and grass 40, stone 80, copper ore 110, planks 50, platforms 20, rope 15. A copper
  pickaxe breaks dirt in 2 hits and stone in 4.
- Damaged blocks show cracks in 4 stages (`assets/fx/cracks.png`) and heal after
  `block_heal_seconds` (5) without a hit (`World` node).
- Broken blocks drop their item (`drop_item`, empty = the item with the tile's id;
  grass drops dirt). `unbreakable` blocks can't be mined. The world's bottom row never
  breaks.
- The area is centered on the cursor: a 2x2 picks the four tiles nearest the cursor.
  Each tile must be within reach, measured from the chest to the tile's center.

## Indicators (`ItemUser`, `src/items/item_user.gd`)

| What | Meaning |
| --- | --- |
| Box around the area | White: it'll do something. Red: out of reach, nothing to mine, nowhere to place. |
| Ghost blocks | Where blocks or walls will go (grass seeds show green). |
| Beam | Mining spell, from the hand to the area. Red when there's nothing to mine there. |
| Range ring | Fades in as the cursor nears the edge of reach; red past it. |
| `2x2` label | Shows briefly after Ctrl + wheel. |

Tunables on `ItemUser`: colors, `ghost_alpha`, `ring_fade_start` (fraction of reach
where the ring appears), `ring_alpha`, `swing_cut_tiles`.

## Placing

- Left click places at the swing's impact; hold to keep placing.
- A block must touch a block or have a wall behind it (or connect to one through other
  tiles placed in the same click), can't go inside the player or a tree trunk, and
  only replaces air. Walls must touch a wall or a block. `free_place` items skip the
  touching rule.
- You can't place more than the selected stack holds.
- Placing a block where a flower or sapling stands breaks it.

## Drops (`src/items/item_drop.gd`)

Items pop out, fall, land on blocks and platforms, and fly to you inside 3 tiles.
Tunables per drop: `magnet_tiles` (3), `magnet_accel`, `gravity`, `thrown_pickup_delay`
(1 s, so a thrown stack doesn't come straight back), `despawn_minutes` (10). Drops aren't
saved with the world yet.

## Trees, saplings, flowers, grass (`Plants` node, `src/world/plant_layer.gd`)

- Natural trees and flowers come from the generator's decoration rules the first time a
  chunk loads. After that they're the world's: chopped trees stay chopped.
- **Trees:** `tree_health` (100). Each axe hit rocks the tree (`wiggle_degrees`); at 0
  it falls away from you over `fall_time` and breaks into `wood_min` to `wood_max` wood
  and 1 seed (`extra_seed_chance` of a second). Removing the grass under a tree breaks
  it on the spot.
- **Saplings:** plant a tree seed on grass with `tree_spacing` (3) tiles to the next
  tree. It grows in `grow_min_seconds` to `grow_max_seconds` (60 to 150) while the
  world runs, once there are `grow_clearance` (10) clear tiles above it.
- **Flowers:** any tool or weapon swing cuts flowers in front of you; mining or
  placing over them breaks them too. `grass_seed_chance` (0.35) to drop grass seeds.
- **Grass spread:** dirt that touches air and sits next to grass turns into grass.
  `grass_spread_checks_per_second` (1500 random checks over the loaded area) sets the
  speed: higher spreads faster.
- Saved with the world for every chunk whose plants or blocks changed.

## Scripted runs

`--aim=DX:DY` aims at an offset (px) from the player's chest instead of the mouse, so
screenshots can show mining and placing:

```
godot --path . -- --aim=60:36 --tap=hotbar_3:20 --hold=use_primary:30:200 --shot=100:/tmp/beam.png --quit=105
```
