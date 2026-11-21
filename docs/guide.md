# Guide: how everything works

A tour of every feature in the game so far: what it does, where the code is, and what
you can tweak. **Looking for where to change something?** Start at
[code-map.md](code-map.md): every area, its files, and the usual edits. For the rules the code follows (data-driven content, host-authoritative,
threading) see [architecture.md](architecture.md). World generation has its own deep
dive: [world-generation.md](world-generation.md); items, mining, placing, magic and plants are
in [items-and-mining.md](items-and-mining.md); crafting, stations, furniture and mana in
[crafting.md](crafting.md); day and night, health, hunger, food and dying in [survival.md](survival.md); enemies, swords, armor, equipment stats and beds in [combat.md](combat.md) (Phase 7, not playtested yet).

**Tweaking in general:** almost every number is an `@export` on a node or a setting in a
`.tres` file. Two ways to change them:

- **Live, while playing:** run the game (F5), switch the Scene panel to **Remote**,
  select the node (`Player`, `Lights`, ...) and edit values in the Inspector. They apply
  immediately but are **not saved**: write down what you like and put it in the script
  or `.tres` afterwards.
- **Permanently:** edit the default in the script (the `@export var x := ...` line) or
  in the `.tres` file.

Before testing a batch of phases, see [playtest.md](playtest.md): what to check and the
handy console commands.

## Contents

1. [Starting the game: menu, worlds, saves](#starting-the-game-menu-worlds-saves)
2. [Player movement](#player-movement)
3. [Player animation](#player-animation), [holding items](#holding-items), and
   [items, mining and placing](items-and-mining.md), [crafting](crafting.md)
4. [The world: tiles, chunks, wrap](#the-world-tiles-chunks-wrap)
5. [Terrain look](#terrain-look)
6. [Lighting](#lighting)
7. [Backdrop](#backdrop)
8. [World generation](#world-generation)
9. [Debug tools](#debug-tools)
10. [Art pipeline](#art-pipeline)
11. [Content as data](#content-as-data)
12. [Tests](#tests)

## Starting the game: menu, worlds, saves

**Main menu** (`scenes/menu/main_menu.tscn`, code `src/ui/menu/main_menu.gd`):

- **Play:** pick a character, then a world (Terraria style: any character can play any
  world).
  - **Characters:** every saved character with a live preview (hover a name), Delete
    (asks first), and **New Character**.
  - **New Character:** name, hairstyle (`<` `>`, includes bald), and a color for each
    palette group (skin, hair, tunic, trim, pants, boots and belt): click a swatch, or
    pick the group and fine tune it with the Hue / Color / Light sliders. Randomize
    picks from the swatches. The preview is the real paper doll. Swatch lists are the
    `*_PRESETS` constants in `main_menu.gd`; hairstyles are the .png files in
    `assets/sprites/hair/`.
  - **Worlds:** saved worlds (most recently played first) with Delete, and **New
    World**: name, size (Small / Medium / Large) and seed. The seed can be any number
    or word; blank picks a random one. The same seed always makes the same world.
    Options: **Hunger** on or off, and **On death**: drop items in a magic bag, or
    keep them (see [survival.md](survival.md)).
- **Test Course** (debug builds only): the Phase 1 movement course with a throwaway dev
  character. Never saved.
- **Doll Viewer** (debug builds only): every arm mode side by side, drawn vs
  code-posed, with recolor and hair buttons.
- **Quit.**

**Esc** in game opens the pause menu (`src/ui/menu/pause_menu.gd`): Resume, Save,
Settings, Save & Quit to Menu, Quit Game. **Settings** has the camera zoom slider (1.5x
to 4x, default 3x), saved in the settings file (`display/zoom`). Esc closes the
inventory first if it's open.

**How a world starts:** the menu builds a `WorldInfo` (name, kind, seed, size, save
path) and calls `Game.start_world(info)`, which switches to `scenes/world/world.tscn`.
`World._ready()` reads `Game.world_info`, creates the generator for that kind, loads
any saved chunks, and spawns the player. The character comes from `Game.character`
(the one picked on the character page; see [items-and-mining.md](items-and-mining.md)).

**Saves** (`src/world/world_save.gd`): one file per world in `user://worlds/`
(on Windows: `%APPDATA%\Godot\app_userdata\game-prototype\worlds\`). A world file
holds the world's info and **only the chunks the player changed**; everything else is
regenerated from the seed. The game saves:

- when you leave the world (Save & Quit, closing the window),
- every `autosave_minutes` (5 by default, an export on the `World` node),
- when you press Save in the pause menu.

A toast at the top of the screen confirms it. Files are written to a temp file first and
then swapped in, so a crash mid-save never destroys the old save. Tile types are stored
by id with a palette, so adding or removing tile types never scrambles old worlds.

The player's position, inventory and so on aren't saved yet: characters are their own
save files and arrive with the character system. You always start at the world's spawn.

**Running the world scene directly:** with `world.tscn` open, **F6** ("Run Current
Scene") skips the menu and uses the `World` node's "When run directly" exports (size,
seed, kind). Nothing is saved.

## Player movement

`src/player/player.gd` (scene `player.tscn`). All values are exports on `Player`,
grouped in the Inspector. Distances in tiles, speeds in tiles per second.

| Group | Settings | Notes |
| --- | --- | --- |
| Speed | `walk_speed` 10, `jog_speed` 18, `run_speed` 28, `climb_speed` 12 | Jog is the default pace. Shift runs; C toggles walk. |
| Ground | `ground_accel_time` 0.1, `ground_decel_time` 0.12 | Seconds to reach full speed / to stop. Lower = snappier. |
| Air control | `air_accel_time` 0.55, `air_turn_time` 0.4, `air_drag_time` 1.6 | How much you can steer mid-jump. `air_turn_time` is how long holding the other way takes to cancel your speed, which is what lets you slow down and drift back a bit. |
| Jump | `jump_height` 11, `time_to_apex` 0.36, `fall_gravity_multiplier` 1.5, `jump_cut` 0.45, `max_fall_speed` 90, `coyote_time` 0.1, `jump_buffer_time` 0.12 | Gravity and launch speed are worked out from height and time, so you tune the feel directly. Releasing jump early keeps `jump_cut` of the upward speed (short hops). Coyote time lets you jump just after leaving a ledge; the buffer remembers a jump pressed just before landing. |
| Terrain | `max_step_tiles` 2, `max_step_down_tiles` 1, `step_smooth_time` 0.06, `platform_drop_time` 0.25 | Walks up ledges this high without jumping, and stays on the ground walking down drops this high (no tiny falls). The body moves a whole tile per step; the sprite eases into place over `step_smooth_time` so stairs look smooth. Down + Jump drops through platforms. Down + Jump drops through a platform; platforms catch you again as soon as you are through it, so a platform one tile lower stops you; hold Down + Jump to keep dropping through them all. `platform_drop_time` is the longest they are ignored. `follow_slopes` (on): over 1-tile steps the character is drawn on the smooth slope the terrain shows (the ground height between the two nearest columns), so feet don't sink going uphill or float going downhill. The height is taken at both feet (`foot_spread_px`, 4) and the higher one wins, so no foot sinks into a hill. Stepping up ignores platforms (walking under a stack of them never lifts you). `ledge_assist_px` (10): when falling, you land on a platform or ledge whose top is just below the box's bottom, since the jump pose tucks the legs up. `air_ledge_climb_px` (12): in the air near the top of a jump (or falling), pushing into a ledge whose top is at most this far above your feet lifts you onto it, so you can jump up through a hole in a floor and step onto it. Climbing rope ignores platforms, so you can climb through them. |
| Fall damage | `fall_damage_start` 50, `fall_damage_per_tile` 5 | Tiles fallen before damage, and damage per tile beyond. Health arrives later; the overlay shows the last fall. |

Collision is 16x60 px (2 x 7.5 tiles). The camera follows in physics mode with
interpolation on, so motion is smooth at any refresh rate (see architecture.md).

## Player animation

The Scholar is a **paper doll**: each body layer of `art/Scholar-casual.aseprite` is
its own sprite, and each part picks its own frame. Legs play the movement animation,
the torso and head follow, and the arms depend on what you're holding. Everything about
drawing for it (layers, tags, arm poses, pivots, items, colors, hair, armor) is in
[character-art.md](character-art.md).

Movement animations (`_animate()` in `player.gd`):

- **Breath** standing still, **Jog** moving (playback speed follows how fast you move),
  **Idle Pose** while climbing. Pushing into a wall counts as standing still.
- **Falling** only shows after `air_grace_time` (0.08 s) off the ground, or right away
  if you jumped, so bumps and small drops don't flicker the run.
- **Jump** is scrubbed from the arc, not played on a timer: frame 1 is the takeoff (for
  `takeoff_time`), frames before the apex follow your rising speed, the apex frame
  (`jump_apex_frame`, 4) holds while vertical speed is within `apex_band` of zero, and
  later frames follow falling speed up to `jump_frame_speed`. A short hop and a full
  jump both hit the tuck at the top.
- **Landing:** after a fall of 2+ tiles, standing still, the upper body drops
  `land_dip` pixels for `land_time`. A `Land` tag in the .aseprite replaces this.
- **Walking backwards:** while aiming or using an item you face the cursor; moving the
  other way plays the legs in reverse at `backpedal_speed`.
- **Holding an item** keeps your drawn arm (the item rides in the hand). If the art has
  a `Stand` tag, it replaces Breath while an item is out.

F3 shows the current animation, frame, "rev" when reversed, and the arm mode.

## Holding items

The hotbar (top left, 1 to 0 or the mouse wheel) picks what's in your hands. Left click
uses it, H puts it away, and an empty slot means bare hands (jab, cross, uppercut; a punch does 3 damage).
Items, the inventory (I or Tab), front and back layers, mining, placing, magic, trees
and grass are all in [items-and-mining.md](items-and-mining.md).

Debug builds put placeholder weapons in the second inventory row (open it with I and
drag one to the hotbar, or shift + click it) to test the doll:

| Item (type) | Hold | Attacks | Put away |
| --- | --- | --- | --- |
| Tool (tool) | one hand | swing | back |
| 2H tool (big_tool) | both hands | slam | back |
| Wand (wand) | aims | flick | hidden |
| Dagger (dagger) | one hand | stab, stab, slash | hip |
| Sword (sword) | one hand | slash, backslash, thrust | hip |
| 2H sword (greatsword) | both hands | overhead, rising | back |
| Book (spell_book) | back hand | front palm casts at the cursor | hip |
| Crossbow (crossbow) | aims, one arm | fire (recoil) | hip |
| Bow (bow) | aims, back hand on string | draw and release | back |

Click again right after an attack ends (or hold) to continue the combo. How items are
held and their attacks come from item types (`data/item_types/`), editable as curves in
the Inspector; see [character-art.md](character-art.md). Weapons don't hit anything yet.
F3 shows the current motion and combo step.

## The world: tiles, chunks, wrap

- **Tiles are 8 px** (`World.TILE`). The Scholar is about 3 tiles wide and 8 tall.
- **Chunks** of 32x32 tiles (`ChunkData`) are generated on demand around the camera
  (`load_radius` on `World`, default 2 chunks each way) on background threads.
- **Blocks and walls:** every tile has a foreground block (dirt, grass, stone, copper,
  planks, platform, rope) and a background wall (dirt, stone, wood). Defined as data in
  `data/tiles/` and `data/walls/` (`TileDef`): collision, climbable, art row, terrain
  look.
- **Wrap:** the world loops left to right. Walk past the last column and you're back at
  column 0, with no visible seam.
- **Changing tiles:** always through `World.request_set_block(tile, id)`, never by
  writing `WorldData` directly. That's the host-authoritative rule: when multiplayer
  arrives, clients will send the same request to the host. The bottom row of the world
  can't be changed (it's the floor).

## Terrain look

`src/world/terrain.gdshader`, one per chunk. Instead of square tile sprites, it draws
per pixel from a small texture of tile ids:

- Natural blocks get a **smoothed, noisy outline** (slopes and corners come out round
  and diagonal), **lit rims** on top edges, soft undersides, **grass** cover and blades,
  and material borders that wander (dirt into stone) instead of straight lines. No dark
  outlines: transitions come from texture.
- **Built blocks** (`built = true` on the TileDef: planks, wood wall) stay crisp and
  square, like placed blocks should.
- Textures come from `assets/terrain/` (generated, see Art pipeline). Wood has three
  generated variants; B is in use, A and C are in `assets/terrain/alternates/`.
- **Detailed art:** a terrain texture covers 8x8 blocks and can be 64x64 (8 art
  pixels per block, normal) or 128x128 (16 per block, detailed). Dirt, stone, their
  walls and clay are detailed; planks, logs and ore overlays are still 64x64. See
  "Detailed art" below.
- **Collision is still exactly the tile grid** (a hidden TileMapLayer). The smoothing
  is only visual. Platforms and ropes draw on a separate visible layer.

## Lighting

`src/world/light_map.gd` (node `Lights` in the running game). A tile-level, colored
(RGB) light map over the loaded area, drawn as a smooth multiply overlay. It works like
Terraria's: light is multiplied by a share per tile it crosses, so it fades smoothly,
dies a few blocks into the ground, and caves with no light are black. Terraria keeps
0.91 per tile through air and 0.56 through blocks; its tiles are bigger next to the
player (3 tall vs our 8), so ours are those to the power 3/8.

| Setting | Default | What it does |
| --- | --- | --- |
| `ambient` | 0 | Brightness everything gets with no light (0: unlit caves are black). |
| `air_decay` | 0.965 | Share of light kept per tile through air and walls. |
| `solid_decay` | 0.8 | Share kept per tile through blocks: the surface is well lit about 3 blocks down and dark by about 10. |
| `indoors_factor` | 0 | Share kept coming out of a block into a walled space (a room, a cave): 0 = the sun doesn't shine through a roof. Rooms get light through open doors, gaps and torches. |
| `min_interval` | 0.12 | Minimum seconds between recomputes. |
| `sky_depth_tiles` | 0 | Open air counts as sky only down to this many tiles below the natural ground (the generator's surface). Deeper dug-out air gets only the light that spreads in from above. |
| `source_solid_factor` | 6 | Light sources fade this many times faster through blocks than through air (Terraria's torch: about 42 tiles of air vs 7 of blocks). Closed doors block light like blocks. |

Open sky (no block and no wall, above the natural ground) is the light source. Air you
dig out underground isn't sky, even without a back wall: before this fix, every block
mined out of wall-less rock shone like daylight. The spread runs on a background
thread (`LightJob`), so editing tiles never stalls the game; light catches up a fraction
of a second later.

**Light sources** are tile objects with a `light_radius` (`data/objects/*.tres`, group
Light), moving lights (the Light Orb and Wisp spells) and glowing forageables (the
Glowcap). A source starts at full brightness and fades the same way, scaled so it's
down to about a tenth at its radius, tinted by its `light_color`. Radii: torch 32,
furnace 16, campfire 48, Light Orb 36, Wisp 26, Glowcap 14. Sources with the same
color and radius spread in one pass, so many torches cost about the same as one.
Sunlight is white; the two add up.

**Campfire** (hand: 5 Wood + 3 Stone, 4x3 tiles, needs a floor): the biggest light,
warm, and the **Cozy** buff while you're within its `aura_radius` (12 tiles): health
refills `aura_health_regen` (1.5) per second faster, on top of the normal refill. Cozy
shows in the buff bar without a timer and ends shortly after you walk away. Any object
can have an aura (`aura_radius`, `aura_health_regen`, `aura_name`, `aura_description`
on the ObjectDef).

## Backdrop

`src/world/backdrop.gd`: sky gradient, sun, clouds, mountains and two hill layers
behind the world, each scrolling at its own speed (parallax) and repeating sideways.
It darkens as the camera goes underground. Layer speeds and heights are the `LAYERS`
table at the top of the file. The main menu uses the same backdrop, drifting slowly.

## World generation

See [world-generation.md](world-generation.md): every setting, how they work, recipes
for common changes, the preview tool, and F6 live regeneration.

## Debug tools

Debug builds only (running from the editor counts).

| Key / tool | What it does |
| --- | --- |
| **F3** | Debug overlay: FPS, position, speed, animation frame, chunk counts, timings (frames over 25 / 50 ms, chunk and light job times). |
| **F4** | Debug brush on/off. While on (and with an empty slot or the item put away), clicks dig and place instead of punching. |
| **Mouse wheel** | Debug brush (when on): pick a block type instead of a hotbar slot. |
| **Left / right mouse** | Debug brush (when on): remove / place a block instantly. |
| **F6** (in game) | Regenerate the world from `data/worldgen/forest.tres` as saved on disk. |
| **F7** (in game) | Reload item types (`data/item_types/*.tres`) after editing them. The Doll Viewer has a Reload button for the same. |
| **`** (the ~ key) | Dev console. `help` lists the commands: `give <item> [count]`, `spawn <item> [count]` (at the cursor), `items`, `spells`, `learn`, `forget`, `book <slot> <spell>`, `spellopt [option] [on|off]` (spell control options), `cast <spell>` (cast at the cursor, free), `equip`, `ready <spell>`, `fly`, `clear`, `devkit` (the dev starting kit and spells), `god`, `hurt <n>`, `kill`, `heal`, `hunger <n>`, `bush` (see survival.md), `mana` (infinite mana on / off), `tp <x> <y>` / `tp spawn`, `pos`, `dig <w> <h>` (clear a box of blocks at the cursor), `fill <block|air> <w> <h>` and `fillwall <wall|air> <w> <h>` (fill a box at the cursor), `reach` (unlimited mining / placing reach), `place <object>` (a torch, rope or furniture at the cursor), `use` (right click what's at the cursor), `cursor <dx> <dy>` / `cursor off` (pin the cursor to a tile offset from your feet, for scripted building in `--console` runs), `color <group> <hex|reset>` (recolor your character, saved), `dummy` / `dummy clear` (a training dummy for damage spells), `summon <enemy> [n]` (at the cursor), `peaceful` (toggle enemy spawns), `butcher` (kill all enemies, with loot), `spawns` (spawn table, rate and cap here), `kills` (enemies slain in this world), see combat.md, `pickups [days]` (loose sticks and rocks here; with days, let that time pass for them, see crafting.md), `grow`, `regen`, `freecraft` (craft with no materials), `creative` (the Dev items window, also **F7**: every item by tabs and search; click 1 onto the mouse, Shift + click 10, Ctrl + click a stack, right click an infinite stack that never runs out), `books` (tier 1, 2 and 3 test books), `page <spell>` (forget a spell, get its Spell Page), `cls`. The log scrolls with the mouse wheel or Page Up / Page Down. Items by id or name (any case, or a unique start). Up / Down for history, Tab completes. |
| **Esc** | Pause menu. |
| `tools/preview_world.gd` | Whole-world map PNG (see world-generation.md). |

**Scripted runs** (`src/core/dev_cli.gd`): command-line arguments after `--` drive the
game for screenshots and smoke tests. Any of them skips the menu and starts a temporary
(unsaved) world:

```
godot --path . -- --seed=42 --spawn=1440 --hold=move_right:20:60 --shot=58:/tmp/a.png --quit=62
```

| Argument | Meaning |
| --- | --- |
| `--world=forest` / `course` | Which generator |
| `--seed=N`, `--size=small` | Seed and size |
| `--spawn=X` | Spawn at column X, on the surface |
| `--hold=ACTION:FROM:TO`, `--tap=ACTION:FRAME` | Press inputs between frames |
| `--shot=FRAME:PATH` | Screenshot |
| `--quit=FRAME` | Quit |
| `--watch=KEY`, `--log=N` | Print overlay values |
| `--perf` | Print timings on quit |
| `--aim=DX:DY` | Aim at this offset (px) from the chest instead of the mouse |
| `--console=FRAME:CMD` | Run a dev console command at a frame (quote the whole argument if it has spaces) |
| `--scene=doll` | Open the Doll Viewer |
| `--menu` | Stay on the main menu instead |

## Art pipeline

Real art comes from you; generated placeholders fill the gaps. `assets/ASSETS.md` lists
every asset, its size and layout.

- **Scholar:** edit `art/Scholar-casual.aseprite`, then run the importer, which reads the
  .aseprite directly (no Aseprite install needed) and writes the parts sheet
  (`scholar_parts.png`) and `scholar.json`. Full details in
  [character-art.md](character-art.md):
  ```
  godot --headless --path . --script res://tools/import_aseprite.gd -- --in=res://art/Scholar-casual.aseprite --out=res://assets/sprites/scholar
  ```
  Hidden layers and layers named `backdrop` or `Ref` are skipped. Tags become
  animations.
- **Terrain, trees, backdrop:** generated by `tools/generate_tiles.gd`
  (`-- --export=game`; add `--wood=A|B|C` to pick the wood variant).
- **Item icons and held sprites, sapling, crack overlay:** placeholders from
  `tools/make_item_art.gd`. Replace the PNGs with yours (same names).

**Background walls** are drawn darker and a little greyer than blocks so the front layer
stands out: `wall_shade` (0.75) and `wall_desat` (0.2) on the `Chunks` node
(ChunkRenderer).

## UI look

Every window, slot and button is drawn by `UiSkin` (`src/ui/ui_skin.gd`) from nine-slice
images in `assets/ui/` (Scholar theme: leather, wood, brass, parchment). They're
placeholders from `tools/make_ui_art.gd`; replace any file with real art of the same
size, or change its margin in `UiSkin.MARGINS`. Text colors (`TEXT`, `DIM`, `GOLD`,
`INK` for parchment titles) are constants there too. Menus built from Controls get the
same look through `UiSkin.theme()`.

```
godot --headless --path . --script res://tools/make_ui_art.gd
```

**World map (N):** a full screen map of what you've explored, like Terraria's
(`WorldMap`, src/world/world_map.gd; the screen is `MapView`, src/ui/hud/map_view.gd).
Everything within `reveal_tiles` (48) of you fills in as you go (checked every
`reveal_every`, 0.4 s, and redrawn, so digging shows), one pixel per 2x2 tiles. Block
colors are the average of their terrain texture, walls darker, open air sky blue above
the original surface and dark below. Wheel zooms at the cursor, drag pans, N or Esc
closes; it wraps sideways like the world. Markers: you (blue dot) and your respawn
point (gold square). Saved with the world as the picture (`WorldSave.META_MAP`).
Bare bones for now: no trees, chests or pins yet.

The inventory is a **satchel** (`SatchelLook`, `src/ui/satchel_look.gd`, Patrick's
moonweave concept): a rounded bag of blue cloth that darkens toward the middle, cells
set apart only by a faint hue change (no lines), a soft glow on the selected and
hovered cell, and, open, a tied knot with a cord and a violet crystal off its right
side. The pictures are made in code and cached; colors and amounts are the consts at
the top (`RIM`, `MIDDLE`, `CELL_HUE`, `CELL_VALUE`). Other windows keep the UiSkin look.

In game, the HUD (`src/ui/hud/hud.gd`) has the inventory panel top left, the
**health, mana and hunger** panel bottom left (pickup notes stack above it), and
separate windows on the right (crafting, chests). See [survival.md](survival.md) for how
health and hunger work. Mana shows "inf" with infinite mana. The
windows gap from the screen edge is the `Hud`
exports `window_right` and `window_top`.

**Hover outline** (`HoverOutline` node, `src/world/hover_outline.gd`): with the cursor on
something right click or E would use, in reach, a soft light outline pulses around it:
doors, chests, stations, beds, forageables (sticks, rocks), ripe berry bushes and
the magic bag. Hidden while the mouse is over a window. Exports: `outline_color` (its
alpha is the brightest point of the pulse), `outline_alpha_min`, `pulse_speed`.

## Content as data

Every piece of content is a `.tres` resource under `data/<category>/` extending
`GameData` (id, display name, description), loaded by the `Registry` autoload. Tiles,
walls, items, item types and world generation settings work this way now; recipes,
spells, enemies and bosses will too. To add a tile type: duplicate a `.tres` in `data/tiles/`, give it a
new `id`, set its fields. Ids must never be renamed once worlds are saved with them.

## Tests

GUT, in `tests/unit/`. In the editor: the GUT panel at the bottom, **Run All**. Command
line: `godot --headless --path . -s addons/gut/gut_cmdln.gd`. CI runs them on every
push. Generation tests (`test_forest_generator.gd`) are a safety net when tuning: if a
tweak breaks a rule (spawn not flat, caves under spawn, copper at the surface), they
fail.


## Sound

`Sounds` (autoload, `src/core/sounds.gd`) plays sound effects that anything asks for with
`EventBus.sound_requested.emit(id, world_position)` (Vector2.INF = not positional). The
file is `assets/sounds/<id>.wav` or `.ogg`; a missing file is silent. Placeholders are
synthesized by `tools/make_sounds.gd` (keeps existing files unless `--force`; `--only=`).
Exports: `min_gap` (0.07 s before the same sound plays again), `max_voices` (14),
`max_distance` (720 px), `pitch_jitter` (0.06). Volume: Settings "audio" `master_volume`
and `sfx_volume` (0.8). The list of sounds is in assets/ASSETS.md.

## Detailed art (2 art pixels per world pixel)

The game measures everything in **world pixels**: a block is 8, the Scholar about 24 wide
and 64 tall. That never changes. Art can be drawn at **twice the detail**: twice as many
pixels across, shown at the same size. You can mix: detailed and normal art sit side by
side, so things can be redrawn one at a time.

| What | Normal | Detailed | How |
| --- | --- | --- | --- |
| Terrain texture (8x8 blocks) | 64x64 | 128x128 | Just use the bigger PNG in `assets/terrain/`; the renderer scales 64x64 ones up to match |
| Item icon | 16x16 | 32x32 | Just use the bigger PNG; slots, drops and thrown items draw it at the normal size |
| Held item | any | 2x | Set `detail = 2` on the item's `HeldItemLook`; `grip` / `grip2` stay in texture pixels |
| Inventory badge | | 8x8 | `ItemData.badge`, drawn in the slot's top right corner (what's in a flask) |

On a 1080p screen each detailed art pixel is 1.5 screen pixels (a little uneven, like
the squeezed icons); at 1440p it's exactly 2. The terrain shader draws in half world
pixel steps (`DET` in `terrain.gdshader`, `DETAIL` in `chunk_renderer.gd`); rims, grass
and the outline noise are still measured in world pixels, so they look as before, just
with finer edges.

- Detailed dirt, stone, walls and clay: `godot --headless --path . --script res://tools/generate_tiles.gd -- --export=terrain_hd`
  (same recipes and layout as the normal ones, details 1 art pixel). `--export=game`
  still writes the normal 64x64 versions; run `terrain_hd` after it.
- Furniture: `ObjectDef.detail = 2` and the PNG at twice the footprint (a 5x4 workbench
  is 80x64). The world, the hover outline and the placement ghost read it.
- Detailed so far: Healing Potion, Mana Potion and Clay Flask (32x32, from
  `art/concepts/flasks/make_flasks.py`); the crafting stations (Workbench, Furnace,
  Copper Anvil, Campfire, Alchemy Table, Spell Weaving Table), Table and Shelf.
  Station art was made by `art/concepts/stations/detail2x.py`: the old art scaled 2x
  with smoothed edges (Scale2x), 1 art pixel lit tops and shaded bottoms, wood grain
  along each board, grit on metal and stone. Not yet: the character (the paper doll
  would need its rig scaled), weapons, tools, chest, door, bed.
