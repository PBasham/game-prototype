# World generation

How worlds are made, what every setting does, and how to tune them yourself.

- **Code:** `src/world/generation/forest_generator.gd`
- **Settings:** `data/worldgen/forest.tres` (class `ForestGenSettings`,
  `src/world/generation/forest_gen_settings.gd`)
- **Tests:** `tests/unit/test_forest_generator.gd`

## Quick start: tweaking generation

1. Open `data/worldgen/forest.tres` in the editor. Every setting is in the Inspector,
   grouped (Surface level, Rolling hills, Big hills, Cliffs, Spawn, Dirt and stone,
   Caves, Copper, Trees and flowers). Hover a setting to see its description.
2. Change values and **save** (Ctrl+S).
3. See the result one of three ways:
   - **In game, live:** run the game (debug build), load or create a world, press
     **F6**. The world regenerates from the saved settings around you, and the player
     is placed back on the surface. Chunks you've edited are kept.
   - **Whole-world map:** run the preview tool (below) and open the PNG. This is the
     fastest way to judge caves, copper and the overall shape.
   - **New world:** create a new world from the menu.
4. If you break something, `git checkout data/worldgen/forest.tres` restores the
   defaults. Tests (`test_forest_generator.gd`) check the important rules still hold:
   flat spawn, no caves under spawn, copper underground only, solid floor, and so on.

Changing settings affects every world, including saved ones. Saves only store chunks
the player edited; everything else is regenerated from the seed each time. So after a
settings change, an old world's unedited areas come out different, and there can be a
visible seam where an edited chunk meets a regenerated one. During development that's
fine; before release, saves will need to store generated chunks too (or pin settings
per world).

### Preview tool

```
godot --headless --path . --script res://tools/preview_world.gd -- --seed=42
```

Draws the world to a PNG, 2 tiles per pixel by default, from just above the highest
hill to 700 tiles below spawn. Prints where it saved the file. Options:

| Option | Meaning |
| --- | --- |
| `--seed=N` | World seed (default 1337) |
| `--size=small` | `tiny`, `small`, `medium`, `large` |
| `--x=X0:WIDTH` | Columns to draw (default: whole world, centered on spawn) |
| `--y=Y0:HEIGHT` | Rows to draw |
| `--step=N` | Tiles per pixel (1 = full detail, 4 = quick overview) |
| `--scale=N` | Upscale the PNG (nearest) for easier viewing |
| `--out=PATH` | Output file (default `user://preview_<seed>.png`) |
| `--world=course` | Draw the test course instead |

Colors: sky blue, grass green, dirt brown, stone gray, copper orange, caves dark
(slightly brown where the cave wall is dirt), tree trunks as dark green ticks above the
surface, flowers as pink dots.

Examples:

```
# Close-up around spawn at full detail, 3x bigger
... preview_world.gd -- --seed=42 --x=0:600 --y=560:200 --step=1 --scale=3
# Quick overview of a large world
... preview_world.gd -- --seed=42 --size=large --step=6
```

## Basics

- **Units:** tiles (8 px). Row 0 is the top of the world, so **y grows downward**:
  "higher" ground has a smaller y. **Depth** means tiles below the surface at that
  column.
- **Sizes** (`WorldData.SIZES`): Small 6400x2048, Medium 9600x2816, Large 12800x3584,
  scaled from Terraria's so the world feels the same size relative to the player (the
  Scholar is 8 tiles tall; a Terraria player is 3). Tiny (1024x512) is for tests.
- **Seeds:** the same seed always makes the same world. Seeds can be typed as numbers
  or words (`WorldInfo.seed_from_text`); blank means random.
- **Chunks:** the world is generated 32x32 tiles at a time, on demand, on background
  threads. Every tile is a pure function of (seed, x, y), so chunks can be made in any
  order and always fit together.
- **Wrap:** the world wraps left to right. All noise is sampled on a cylinder (column x
  is an angle around a circle whose circumference is the world width), so the last
  column and the first are true neighbors and there is no seam.

## How a tile is decided

For each column, the generator first works out the **surface height** and the **dirt
thickness**. Then for each tile in the column, top to bottom:

1. Above the surface: **air**.
2. In the bottom `floor_rows` rows of the world: **stone**, always.
3. Inside a **cave** (entrance shaft, tunnel or cavern): **air**.
4. The surface tile itself: **grass**.
5. Within the dirt thickness: **dirt** (with occasional stone pockets).
6. Below that: **stone** (with dirt pockets).
7. If the tile is stone and inside an **iron blob**: **iron**.
8. If the tile is stone (or dirt, if allowed) and inside a **copper blob**: **copper**.
9. If the tile is still dirt and inside a **clay patch**: **clay**.

Background **walls** are separate: none in the top 4 tiles below the surface (so the sky
shows behind shallow holes), dirt wall in the dirt band, stone wall below. Walls are
there even inside caves, which is why caves look like rooms rather than holes to the
sky.

## Settings

The amounts below marked "0 to 1" are **calibrated**: when the generator starts, it
samples its own noise and picks the cutoff so that roughly that fraction of the world
qualifies. `cliff_amount = 0.25` really means about a quarter of the world can have
cliffs. This makes the numbers predictable to tune.

### Surface level

| Setting | Default | What it does |
| --- | --- | --- |
| `surface_level` | 0.3 | Baseline surface height as a fraction of world height (0.3 = top 30% is sky). |
| `surface_min` / `surface_max` | 0.15 / 0.45 | Hard limits; hills and valleys are clamped to these. |

### Rolling hills

The everyday shape of the ground.

| Setting | Default | What it does |
| --- | --- | --- |
| `hill_height` | 20 | How far ordinary hills go up or down from the baseline. |
| `hill_width` | 160 | Rough distance between hilltops. Bigger = longer, gentler hills. |
| `hill_detail` | 3 | Noise layers. 1 = smooth swells, 4 to 5 = bumpy, lumpy ground. |

### Big hills

Occasional tall hills added on top of the rolling ones. They only ever go up.

| Setting | Default | What it does |
| --- | --- | --- |
| `big_hill_height` | 50 | Height of the tallest big hills. |
| `big_hill_width` | 700 | Rough distance between them. |
| `big_hill_amount` | 0.3 | How much of the world has a big hill (0 to 1). |

### Cliffs

Steep faces where the ground steps up or down. Each cliff region has a step size
between min and max; within a region, a step happens wherever a slow noise crosses
zero.

| Setting | Default | What it does |
| --- | --- | --- |
| `cliff_height_min` / `max` | 6 / 12 | Size of each step. |
| `cliff_spacing` | 220 | Rough distance between possible steps. |
| `cliff_amount` | 0.25 | How much of the world can have cliffs (0 to 1). 0 turns them off. |
| `cliff_face_width` | 2 | How many columns a step takes. 1 to 2 = a wall, 6+ = a steep slope. |

### Spawn

| Setting | Default | What it does |
| --- | --- | --- |
| `spawn_x` | 200 | Spawn column (near x = 0 so the wrap seam is a short walk left). |
| `spawn_flat_radius` | 30 | The ground is perfectly flat this far either side of spawn. |
| `spawn_blend` | 30 | Distance over which the flat area eases back into the hills. |
| `spawn_safe_radius` | 40 | No cave entrances, and no caves shallower than 40 tiles, this close to spawn. |

### Dirt and stone

| Setting | Default | What it does |
| --- | --- | --- |
| `dirt_depth_min` / `max` | 15 / 30 | Dirt thickness under the grass varies between these. |
| `dirt_depth_width` | 60 | How quickly the thickness changes along the surface. |
| `dirt_edge_jitter` | 3 | Small wobble on the dirt/stone line so it's never a smooth curve. |
| `dirt_pocket_amount` | 0.08 | Fraction of the stone that's dirt pockets (0 to 1). |
| `dirt_pocket_size` | 14 | Size of dirt pockets. |
| `stone_pocket_amount` | 0.05 | Fraction of the dirt that's stone pockets (0 to 1). |
| `stone_pocket_min_depth` | 8 | No stone pockets in the top 8 tiles of dirt. |
| `floor_rows` | 3 | Bottom rows that are always solid stone. The very last row can't be dug (enforced in `World.request_set_block`). |

### Caves

Three kinds, all carved out of the solid ground:

- **Tunnels:** winding passages. Made where a noise value is close to zero, which
  traces long wiggly lines; `tunnel_width` sets how thick the lines are. A second,
  slower noise switches tunnels on and off by region (`tunnel_coverage`), so some
  areas are riddled with them and others are solid.
- **Caverns:** big open blobs, rarer near the top and more common deeper down.
- **Surface entrances:** shafts from the surface down into the ground, ending in a
  small chamber. One candidate per `entrance_spacing` columns, placed randomly inside
  its stretch.

`cave_flatten` stretches all caves sideways: at 1.5 they're half again as wide as they
are tall, like Terraria's.

Sizes are set for the Scholar: **8 tiles tall, 3 wide**. A tunnel under about 10 tall
is a crawl space he can't walk through.

| Setting | Default | What it does |
| --- | --- | --- |
| `tunnel_min_depth` | 16 | Tunnels start this deep. They narrow near the top so they rarely break the surface. |
| `tunnel_width` | 24 | Typical tunnel height in tiles (was 13, then 18: tunnels were too low to move through without mining). |
| `tunnel_length`, `tunnel_breaks` | 160, 0.35 | Tunnels break into runs about `tunnel_length` tiles long (some shorter, some longer); `tunnel_breaks` is how much is cut away into gaps (0 = one long ribbon wherever coverage allows). |
| `tunnel_taper` | 0.8 | Where a tunnel runs out (edge of its coverage, or its first tiles of depth) it narrows to this share of `tunnel_width` before ending. Low = long crawl spaces at tunnel ends. |
| `tunnel_spacing` | 240 | Rough distance between neighboring tunnels. Smaller = denser network. |
| `tunnel_coverage` | 0.5 | Fraction of the underground with tunnels (0 to 1). |
| `cave_flatten` | 1.5 | Above 1, caves are wider than tall. |
| `cavern_min_depth` | 80 | Caverns start this deep. |
| `cavern_size` | 140 | Rough size of a cavern. |
| `cavern_amount_top` | 0.04 | Fraction of the ground that's cavern at `cavern_min_depth`... |
| `cavern_amount_deep` | 0.2 | ...and at `cavern_full_depth` and below (it ramps in between). |
| `cavern_full_depth` | 500 | Depth where caverns reach their deep amount. |
| `entrance_spacing` | 600 | Average distance between entrances. |
| `entrance_chance` | 0.85 | Chance each stretch actually gets one. |
| `entrance_depth_min` / `max` | 50 / 110 | How deep the shaft goes. |
| `entrance_width_min` / `max` | 10 / 13 | Shaft width (the mouth is a bit wider). Was 7 / 10: the tightest shallow spots. |
| `entrance_wobble` | 8 | How far the shaft winds left and right. |
| `entrance_chamber` | 9 | Radius of the chamber at the bottom. |

**Density presets** (from the brief): the defaults are "medium". For *sparser*, try
`tunnel_coverage 0.3`, `cavern_amount_deep 0.12`, `entrance_spacing 900`. For
*denser*, try `tunnel_coverage 0.7`, `tunnel_spacing 180`, `cavern_amount_deep 0.3`.

### Copper

The world is cut into 8x8 tile cells. Each cell may hold one small oval blob of copper;
the chance grows with depth. A tile is copper if it falls inside any nearby blob and is
stone (or dirt, if `copper_in_dirt` is on). Copper never replaces air, so it shows up in
cave walls naturally.

| Setting | Default | What it does |
| --- | --- | --- |
| `copper_min_depth` | 6 | Never shallower than this. |
| `copper_chance_shallow` | 0.05 | Chance per 8x8 cell near the top... |
| `copper_chance_deep` | 0.14 | ...and at `copper_full_depth` and below. |
| `copper_full_depth` | 150 | Depth where copper reaches its deep chance. |
| `copper_radius_min` / `max` | 1.2 / 1.9 | Blob size. 1.2 is about 4 tiles of ore, 1.9 about 10. |
| `copper_in_dirt` | true | Copper can replace dirt too, not only stone. |

### Iron

Same blobs as copper, only in stone, deeper and rarer at first (like Terraria's spread).
Where an iron and a copper blob overlap, it's iron. Iron ore needs
`mining_power` 35: the Mining Spell with Power rank 1 (see items-and-mining.md).

| Setting | Default | What it does |
| --- | --- | --- |
| `iron_min_depth` | 40 | Never shallower than this (below the dirt layer). |
| `iron_chance_shallow` | 0.02 | Chance per 8x8 cell at `iron_min_depth`... |
| `iron_chance_deep` | 0.1 | ...and at `iron_full_depth` and below. |
| `iron_full_depth` | 250 | Depth where iron reaches its deep chance. |
| `iron_radius_min` / `max` | 1.0 / 1.6 | Blob size (a bit smaller than copper's). |

### Clay

Patches in the dirt (never stone or the grass row), like Terraria's: common just under
the surface, rarer deeper. Same blob method as the ores, bigger blobs.

| Setting | Default | What it does |
| --- | --- | --- |
| `clay_min_depth` | 2 | Never shallower than this |
| `clay_chance_shallow` | 0.12 | Chance per 8x8 cell at `clay_min_depth`... |
| `clay_chance_deep` | 0.04 | ...and at `clay_full_depth` and below |
| `clay_full_depth` | 60 | Depth where clay reaches its deep chance |
| `clay_radius_min` / `max` | 1.6 / 2.6 | Patch size |

### How roomy are the caves? (`tools/cave_fit.gd`)

Measures the share of cave floor tiles where the Scholar fits standing (3 wide, 8 tall
of open air above), overall and by depth. Any setting can be overridden to compare:

```
godot --headless --path . --script res://tools/cave_fit.gd -- --seed=42
godot --headless --path . --script res://tools/cave_fit.gd -- --seed=42 --tunnel_width=20.0
godot --headless --path . --script res://tools/cave_fit.gd -- --seed=42 --fit_h=11   # room to hop
```

Before Phase 9 (`tunnel_width` 13): 64 to 75% fit (seeds 42, 7, 99). Phase 9 (18, taper
0.6): 79 to 83%. Now (24, taper 0.8, entrances 10 to 13), with room to hop too
(`--fit_h=11`, 3x11): 77% (seed 42, was 64%) and 78% (seed 7, was 69%); the first 50
tiles below the surface went from 51% to 80% (seed 42) and 37% to 54% (seed 7). Only new
chunks and F6 use new settings: places you've already explored keep their caves.

*Rarer and deeper* (so it feels earned): `copper_min_depth 25`,
`copper_chance_shallow 0.02`, `copper_chance_deep 0.1`. *Bigger veins*:
`copper_radius_max 2.6` (and lower the chances a little).

### Trees and flowers

Groves and clearings come from a slow noise along the surface (`groveness`, 0 = deep
in a clearing, 1 = deep in a grove). There's one possible tree spot every
`tree_spacing` columns; the chance it gets a tree depends on how grove-like that spot
is. Flowers work the opposite way: common in clearings, rare under the trees.

| Setting | Default | What it does |
| --- | --- | --- |
| `tree_spacing` | 9 | One tree spot per this many columns (also the closest two trees can be). |
| `grove_width` | 120 | Rough size of groves and clearings. |
| `grove_amount` | 0.55 | Fraction of the surface that's grove (0 to 1). |
| `grove_tree_chance` | 0.85 | Chance a spot in a grove gets a tree. |
| `clearing_tree_chance` | 0.06 | Chance a spot in a clearing gets a tree (the odd lone tree). |
| `tree_max_slope` | 2 | No trees where the ground rises or falls more than this over 4 columns. |
| `clearing_flower_chance` | 0.14 | Flower chance per column in clearings. |
| `grove_flower_chance` | 0.03 | ...and in groves. |
| `tree_variants` / `flower_variants` | 12 / 5 | How many art variants exist (match `assets/trees`, `assets/decor`). |

Trees and flowers only grow on grass with air above, so cave entrances and dug-out
ground stay bare. Placement rules live in `tree_at` / `flower_at`; the chunk builder
(`chunk_build_job.gd`) asks them per column.

### Dark Forest

One big Dark Forest region (like Terraria's jungle) on one side of spawn. Inside: tall
darkwood trees packed close together, a dark backdrop of trunks under a canopy, half
the daylight, and Forest Spirits (combat.md). The edges fade over a few dozen tiles.

| Setting | Default | What it does |
| --- | --- | --- |
| `dark_forest_share` | 0.25 | Share of the world's width that is Dark Forest (0 = none). |
| `dark_forest_patches` | 1 | How many regions (1 = one big one: Small 1,600 tiles, Medium 2,400, Large 3,200). 0 = split by `dark_forest_patch_tiles` and spread evenly. |
| `dark_forest_patch_tiles` | 640 | Patch width when `dark_forest_patches` is 0. |
| `dark_forest_distance` | 0.3 | With one region: its middle's distance from spawn, as a share of the world's width (east or west by seed). |
| `dark_forest_spawn_clear` | 300 | No Dark Forest closer to spawn than this (tiles to the patch's edge). |
| `dark_forest_edge_tiles` | 40 | The fade at each edge. |
| `dark_tree_spacing` | 5 | One dark tree spot per this many columns (pines: 9). |
| `dark_tree_chance` | 0.9 | Chance a spot has a tree. |
| `dark_tree_variants` | 3 | Darkwood tree art (`assets/trees/darkwood_<n>.png`, 180 to 280 px tall). |
| `dark_flower_chance` | 0.01 | Flowers under the dark trees. |
| `dark_forest_wobble_tiles` | 40 | Underground, the region's sides wander in and out by up to this many tiles as they go down (less near the surface, so they meet the trees). |
| `dark_forest_wobble_length` | 110 | One wiggle every this many tiles going down. |
| `dark_forest_fringe_tiles` | 7 | At its edge, a band this wide where both kinds of ground mix in clumps. |

**Its ground (Phase 21).** Under the Dark Forest, all the way to the bottom of the
world, the ground is its own blocks: **Dark Forest Dirt**, **Dark Forest Grass** (the
surface, blue-black blades) and **Dark Forest Stone**, with **Dark Forest Dirt Wall** and
**Dark Forest Stone Wall** behind (`ForestGenerator.dark_forest_blocks_at`, swapped in
`_block` and `_wall`). Ores stay as they are; there's no clay under the Dark Forest (it becomes Dark Forest Dirt). The art is a placeholder blend
toward black with a hint of blue (`python3 tools/make_dark_forest_terrain.py --force`,
per texture `--dirt=amount,brightness`, `--dirt_wall=`, `--stone=`, `--stone_wall=`); the
grass colors are `ChunkRenderer.dark_grass_colors`.

**Which biome you're in** is counted from the ground around you, like Terraria
(`World.biome_at(tile)`, `biome_amount`): in a `biome_box` (48 x 32 tiles, sampled
every `biome_sample_step` 2), if `biome_share` (30%) of the blocks and walls belong to a
biome (`TileDef.biome`), you're in it. The share is counted against at least
`biome_min_ground` (60%) of the box, so a few blocks in open air don't turn it. So digging, or building with Dark Forest blocks,
changes it. High in the open sky (little ground around) the column's surface biome
counts instead. It drives the spawn tables and the dark backdrop; the canopy's shade
on the light is still by column (`dark_forest_at`).

**Trees stand on level ground**: no column under the trunk lower than the root (pines:
the root column; darkwood: a tile each side), at most one tile lower at the trunk's
edge (`_trunk_fits`). Planted saplings need a block each side of the root too. Each
tree is mirrored or not and leans up to `Plants.tree_lean_degrees` (4) either way.

`tp dark` in the console goes to the middle of the Dark Forest.

`ForestGenerator.dark_forest_at(x)` (0 to 1) and `biome_at(x)` (`forest` or
`dark_forest`) drive the trees, the spawn tables, the backdrop (`Backdrop.DARK_LAYERS`,
`dark_veil`, `dark_fade_speed`) and the light (`LightMap.dark_forest_shade`, 0.5 = half
as bright). The world map preview draws dark trees as taller purple ticks. Changes
only affect chunks not generated yet.

### Ocean (Phase 55)

One ocean on the far side of the world (`ocean_distance` 0.5 of the width from spawn):
deep water over a sand floor, with a sandy beach rising to the land on both sides. Off
with `ocean = false`; worlds too narrow for it (ocean plus beaches over 60% of the width)
get none.

| Setting | Default | What it does |
| --- | --- | --- |
| `ocean_share`, `ocean_min_width` | 0.2, 140 | Width of the water at sea level |
| `ocean_depth` | 220 | The upper sea floor's deepest point below sea level, around the chasm's mouth (at most half the world below sea level) |
| `ocean_shelf`, `ocean_shelf_depth` | 0.3, 8 | A shallow shelf near each shore (share of the half width, depth) before the drop |
| `ocean_floor_bumps` | 3 | Bumps on the sea floor (deeper parts only) |
| `beach_width` | 60 | Each beach, from the water's edge to the land. It never dips below sea level, so the water can't spill over it |
| `sea_level_below` | 3 | Sea level, tiles below the baseline surface (`surface_level`) |
| `ocean_sand_depth`, `ocean_hard_sand_depth` | 6, 14 | Sand on top, then Hard Sand, then stone (and its ores) |
| `sunlit_water_tiles` | 24 | Sunlight reaches this far down into the sea (`light_floor_at`); deeper water darkens like caves |

The beach's land end mixes sand and grass in clumps. No trees, flowers or Dark Forest on
the ocean or its beaches. Walls: Sand Wall, then Hard Sand Wall. The ocean is its own
biome (`biome_at` = `ocean`; Sand and Hard Sand carry `biome = ocean`); there's no spawn
table for it yet, so nothing spawns there.

### The Deep (Phase 64)

Under the ocean, down to the world's floor:

- **The chasm:** a shaft of open water from the middle of the sea floor down to the
  **arena**: an empty chamber `arena_width` x `arena_height` (140 x 70) at the bottom, for
  a boss later. `chasm_width_min`/`max` (50 to 80) wide. It isn't straight:
  - big bends up to `chasm_wander` (70) tiles off the middle, about every
    `chasm_bend_tiles` (260) rows, plus kinks up to `chasm_kink` (12) about every
    `chasm_kink_tiles` (45); the bends ease in over the first 60 rows so the mouth sits
    in the middle of the sea floor
  - its width swells and narrows by up to `chasm_wobble` (8) each side
  - jagged rock on the walls, up to `chasm_jag` (7) tiles in spikes about
    `chasm_jag_tiles` (6) tall, only on some stretches
  - `ForestGenerator.chasm_open(x, y)`, `chasm_center(y)`
- **Flooded caves** under the upper sea floor across the ocean's width (less
  `deep_margin` 24 of rock each side, for the barrier), below `deep_crust` (6) of rock
  under the Hard Sand and above `deep_floor_rows` (8) of floor: caverns where a noise
  (`deep_cave_tiles` 120) is over `deep_open` (0.22), tunnels where a second noise
  (`deep_tunnel_tiles` 160) is within `deep_tunnel` (0.045) of zero. They thin out toward
  the edges so they don't end in straight lines.
- **Scene caverns:** `scene_caverns` (4) empty `scene_cavern_width` x `scene_cavern_height`
  (40 x 20) caverns spread over both sides, for scenes later.
- No dry caves anywhere under the ocean or its beaches: only the flooded ones.
- `ForestGenerator.deep_open(x, y)`, `deep_layout()` (arena, scenes, chasm width).
- Dev console `fullbright` turns the lighting off to look around (the Deep is black).

### Sea plants (Phase 56)

`sea_plant_at(x)` gives each ocean or pond column at most one plant, drawn by `SeaFlora`
(decoration only, nothing to harvest; it shows while its ground is there with room above):

| Setting | Default | What it does |
| --- | --- | --- |
| `kelp_chance`, `kelp_min_depth`, `kelp_max_tiles` | 0.3, 6, 22 | Kelp on sea floor at least 6 under water, up to 22 tall, never reaching the surface (ponds have none) |
| `seagrass_chance` | 0.45 | Seagrass on other underwater floor (ocean and ponds) |
| `dune_grass_chance` | 0.3 | Dune grass on dry beach sand |

`SeaFlora` exports: `kelp_sway_px` 2.5, `kelp_sway_speed` 1.3, `grass_sway_px` 0.6,
`underwater_tint` (plants in water are drawn bluer), and for mining kelp (Phase 66,
survival.md) `kelp_tiles_per_item` 3, `kelp_regrow_days` 1.

### Ponds (Phase 55)

Small ponds on fairly flat ground: a spot every `pond_spacing` (140) columns, with
`pond_chance` (0.6), `pond_width_min`/`max` (8, 18) wide and `pond_depth_min`/`max` (3, 6)
deep, where the ground rises or falls at most `pond_max_slope` (5) over the width, not
within `pond_spawn_clear` (40) of spawn, the ocean or the Dark Forest. The bed is sand,
the water's top is one row below the lower bank, and there are no caves within 12 tiles
under a pond or trees right beside it. Phase 81: each `pond_spacing` stretch tries
`pond_tries` (6) spots for flat enough ground, and a spot whose banks or floor would be
open (a cave entrance) is skipped, so nothing leaks.

### Lakes (Phase 81)

Big fresh water pools, placed before the ponds and built the same way (they share
`ponds()` and the pond code): a spot every `lake_spacing` (700) columns with `lake_chance`
(0.8), `lake_width_min`/`max` (24, 60) wide and `lake_depth_min`/`max` (6, 15) deep, where
the ground rises or falls at most `lake_max_slope` (12), trying `lake_tries` (12) spots, not
within `lake_spawn_clear` (80) of spawn. Ponds keep clear of lakes.

### Salt and fresh water (Phase 81)

Generated water is salt in the sea and the Deep's flooded caves (`salt_at`, chunk water
value 2) and fresh in ponds and lakes (value 1); the voxel layer imports them as the
`salt_water` and `water` materials. The sea refills with salt water. Voxel materials keep a
fixed cell `code` (sand 1, Sand Bricks 2, water 3, salt water 4) so saved cells keep their
material.

### Abyssal Stone (Phase 65)

**Abyssal Stone** is the ocean's outer layer on both sides, `abyss_thickness` (4) tiles
thick:

- a wall straight down each side of the Deep (at `deep_margin` in from the water's
  edge) to the world's floor
- from there, a layer under the sand and Hard Sand following their curve out across the
  beach; over the last `abyss_taper` (0.35) of the beach it rises to `abyss_cover` (3)
  tiles under the surface, ending at least `abyss_rise` (2) rows above sea level (the
  beach rises a little to keep it covered: `_beach_cap`). Under the layer is the land's
  own ground.

Nothing breaks it (`TileDef.unbreakable`: not mining, not the Bomb, and the Shaping Spell
can't reshape it), so the sea can't drain into the land and the Deep is only reached
through the sea. `ForestGenerator.abyssal_at(x, y)`, `_abyss_top`; `sea_at(x, y)` is the
sea inside it (at or below sea level), where the sea refills itself (below).

### Water

`water_at(x, y)` says where the world starts full of water. Generating a chunk records
it in `ChunkData.water`; the voxel layer fills those tiles with water cells
(`VoxelLayer.import_generated`), at rest, once per chunk. The world map preview draws
water blue and sand tan.

- **Pristine water** (Phase 65): a chunk whose water nothing has touched and whose blocks
  were never edited (`VoxelLayer.is_pristine`) isn't saved: the generator makes it again
  on load. Touched chunks are saved whole and marked imported, so reloading never adds
  water twice. Pristine chunks farther than `water_unload_tiles` (192) from you are
  dropped from memory and put back within `water_load_tiles` (144) (`stream_water`).
- **The sea refills itself** (Phase 65): open space in the sea (`sea_at`) next to water
  fills back up, `refill_tiles_per_second` (8) tiles a second within `refill_radius` (48)
  of you (`ocean_refill`, `refill_samples` 48 tries a pass, 4 passes a second;
  `VoxelLayer.refill_sea`). A sealed dry room under the sea stays dry (only tiles touching
  water refill). Phase 85: only tiles the generator filled (`water_at`) in chunks whose
  water is already in (`_imported`) refill, so dry caverns in the Deep don't slowly flood
  and queued chunks don't get water poured into them early.
- **Keeping the sea smooth** (Phase 85, the ocean lag): the cost was drawing, not the
  water. Now:
  - Streamed and loaded water is queued: chunks on or next to the screen go in at once,
    the rest `imports_per_frame` (1) a frame (`_queue_generated`, `_import_some`;
    `flush_imports` adds everything now). Their tiles are painted on a budget of
    `bulk_paint_ms` (2.5 ms) a frame (`_paint_bulk`), while edits and moving water paint
    at once (`_paint`).
  - Drawing water never makes the main thread generate land
    (`WorldData.peek_block`; land not generated yet counts as solid to the water).
  - Only water regions on screen are drawn.
  - Like Noita, only water within `sim_radius_tiles` (96) of you moves; the rest waits
    where it is. A step stops after `step_budget_ms` (5 ms) and carries on next step.
  - `--perf` prints the voxel timings ("voxel step", "voxel paint", "voxel import",
    "voxel draw"...). Dev console `tp ocean` and `tp deep` jump there.

## Code tour

`ForestGenerator` (`forest_generator.gd`), in reading order:

| Function | Job |
| --- | --- |
| `_init` | Builds all noise generators from the seed and settings; calibrates the "amount" cutoffs (`_calibrate`). After this nothing is written, which is what makes it safe on many threads. |
| `surface_at(x)` | Final surface row: `_raw_surface` plus spawn flattening. |
| `_raw_surface(x)` | Rolling hills + big hills + cliffs, clamped. |
| `generate_chunk(chunk)` | Fills a chunk. Works column by column (`_column`) so per-column values are computed once. |
| `_column(x)` | Surface, dirt thickness, the column's cylinder coordinates, distance from spawn. |
| `_block(x, y, ...)` | The tile rules listed above. |
| `_carved(...)` | Entrances, tunnels, caverns. |
| `_entrances_near(x, span)` / `_in_entrance` | Where entrance shafts are and whether a tile is inside one. |
| `_copper(x, y, depth)` | The 8x8 cell blob test. |
| `groveness`, `tree_at`, `flower_at` | Surface life. |
| `_noise`, `_cyl`, `_calibrate` | Helpers: make a noise, map x to the wrap cylinder, turn an amount into a cutoff. |

`block_at(x, y)` and `wall_at(x, y)` give a single tile (used by tests and the preview
tool); in game, everything goes through `generate_chunk`.

### Adding things later

- **New tunable:** add an `@export` to `ForestGenSettings` (with a `##` comment, it
  shows as the Inspector tooltip), read it via `settings.<name>`, document it here.
- **New biome (later, with a design brief first):** biomes will sit side by side
  across the world. The plan is a "biome map" function of x that says which biome owns
  each column, with a blend zone at the borders; each biome gets its own settings
  `.tres` under `data/worldgen/` and the generator picks settings per column. The
  forest stays the first biome, around spawn.
- **Structures, lakes (later):** these need to know about more than one tile at a
  time. They'll come from a small "feature map" worked out once per world from the
  seed (where each structure sits), which chunks then consult. That keeps chunk
  generation pure and threaded.
- **Underground layers (later):** depth bands below the forest with their own rules.

## The test course

The Phase 1 movement course (steps, 4 and 10 tall walls, pit, platforms, 90-deep shaft
for fall damage, rope shaft, wood house) is its own generator, `CourseGenerator`
(`course_generator.gd`). It's only reachable from the main menu's **Test Course** button
(debug builds) or `-- --world=course` on the command line, and it's never saved.
