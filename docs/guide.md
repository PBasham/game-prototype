# Guide: how everything works

A tour of every feature in the game so far: what it does, where the code is, and what
you can tweak. For the rules the code follows (data-driven content, host-authoritative,
threading) see [architecture.md](architecture.md). World generation has its own deep
dive: [world-generation.md](world-generation.md).

**Tweaking in general:** almost every number is an `@export` on a node or a setting in a
`.tres` file. Two ways to change them:

- **Live, while playing:** run the game (F5), switch the Scene panel to **Remote**,
  select the node (`Player`, `Lights`, ...) and edit values in the Inspector. They apply
  immediately but are **not saved**: write down what you like and put it in the script
  or `.tres` afterwards.
- **Permanently:** edit the default in the script (the `@export var x := ...` line) or
  in the `.tres` file.

## Contents

1. [Starting the game: menu, worlds, saves](#starting-the-game-menu-worlds-saves)
2. [Player movement](#player-movement)
3. [Player animation](#player-animation) and [holding items](#holding-items)
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

- **New World:** name, size (Small / Medium / Large) and seed. The seed can be any
  number or word; blank picks a random one. The same seed always makes the same world.
- **Load World:** saved worlds, most recently played first, with Delete.
- **Test Course** (debug builds only): the Phase 1 movement course. Never saved.
- **Doll Viewer** (debug builds only): every arm mode side by side, drawn vs
  code-posed, with recolor and hair buttons.
- **Quit.**

**Esc** in game opens the pause menu (`src/ui/menu/pause_menu.gd`): Resume, Save,
Save & Quit to Menu, Quit Game.

**How a world starts:** the menu builds a `WorldInfo` (name, kind, seed, size, save
path) and calls `Game.start_world(info)`, which switches to `scenes/world/world.tscn`.
`World._ready()` reads `Game.world_info`, creates the generator for that kind, loads
any saved chunks, and spawns the player.

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
| Terrain | `max_step_tiles` 2, `platform_drop_time` 0.25 | Walks up ledges this high without jumping. Down + Jump drops through platforms. |
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
  **Idle Pose** while climbing.
- **Jump** is scrubbed from the arc, not played on a timer: frame 1 is the takeoff (for
  `takeoff_time`), frames before the apex follow your rising speed, the apex frame
  (`jump_apex_frame`, 4) holds while vertical speed is within `apex_band` of zero, and
  later frames follow falling speed up to `jump_frame_speed`. A short hop and a full
  jump both hit the tuck at the top.
- **Landing:** after a fall of 2+ tiles, standing still, the upper body drops
  `land_dip` pixels for `land_time`. A `Land` tag in the .aseprite replaces this.
- **Walking backwards:** while aiming or using an item you face the cursor; moving the
  other way plays the legs in reverse at `backpedal_speed`.

F3 shows the current animation, frame, "rev" when reversed, and the arm mode.

## Holding items

Real items arrive with mining (Phase 4). Debug builds have placeholder items to test
the doll:

| Key | Item (type) | Hold | Attacks | Put away |
| --- | --- | --- | --- | --- |
| 1 | Empty hands | | nothing (unarmed punches exist but are off) | |
| 2 | Tool (tool) | one hand | swing | back |
| 3 | Two-handed tool (big_tool) | both hands | slam | back |
| 4 | Wand (wand) | aims | flick | hidden |
| 5 | Dagger (dagger) | one hand | stab, stab, slash | hip |
| 6 | Sword (sword) | one hand | slash, backslash, thrust | hip |
| 7 | Two-handed sword (greatsword) | both hands | overhead, rising | back |
| 8 | Spell book (spell_book) | back hand | front palm casts at the cursor | hip |
| 9 | Hand crossbow (crossbow) | aims, one arm | fire (recoil) | hip |
| 0 | Bow (bow) | aims, back hand on string | draw and release | back |
| H | Put away / take out | | | |
| Left click | Attack. Click again right after one ends (or hold) to continue the combo. | | | |

How items are held and their attacks come from item types (`data/item_types/`), editable
as curves in the Inspector; see [character-art.md](character-art.md). These are
placeholders: nothing fires or hits yet. F3 shows the current motion and combo step.

While holding an item, the debug brush is off (clicks use the item); press H or 1 to
free your hands and dig again.

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
- **Collision is still exactly the tile grid** (a hidden TileMapLayer). The smoothing
  is only visual. Platforms and ropes draw on a separate visible layer.

## Lighting

`src/world/light_map.gd` (node `Lights` in the running game). A tile-level light map
over the loaded area, drawn as a smooth multiply overlay.

| Setting | Default | What it does |
| --- | --- | --- |
| `ambient` | 0.16 | Darkest anything gets (so caves aren't pure black). |
| `open_falloff` | 0.06 | Light lost per tile through air and walls. |
| `solid_falloff` | 0.1 | Light lost per tile through blocks (how far sunlight soaks into the ground). |
| `min_interval` | 0.12 | Minimum seconds between recomputes. |

Open sky (no block and no wall) is the light source. The spread runs on a background
thread (`LightJob`), so editing tiles never stalls the game; light catches up a fraction
of a second later. Torches and other light sources come later.

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
| **1 to 5, H** | Placeholder held items, put away (see Holding items). |
| **Mouse wheel** | Debug brush: pick a block type. |
| **Left / right mouse** | Debug brush: remove / place a block (until real mining). |
| **F6** (in game) | Regenerate the world from `data/worldgen/forest.tres` as saved on disk. |
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

## Content as data

Every piece of content is a `.tres` resource under `data/<category>/` extending
`GameData` (id, display name, description), loaded by the `Registry` autoload. Tiles,
walls and world generation settings work this way now; items, recipes, spells, enemies
and bosses will too. To add a tile type: duplicate a `.tres` in `data/tiles/`, give it a
new `id`, set its fields. Ids must never be renamed once worlds are saved with them.

## Tests

GUT, in `tests/unit/`. In the editor: the GUT panel at the bottom, **Run All**. Command
line: `godot --headless --path . -s addons/gut/gut_cmdln.gd`. CI runs them on every
push. Generation tests (`test_forest_generator.gd`) are a safety net when tuning: if a
tweak breaks a rule (spawn not flat, caves under spawn, copper at the surface), they
fail.
