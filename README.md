# game-prototype

A 2D side-scrolling sandbox for PC: procedurally generated worlds, mining, building,
crafting, deep magic, summons, farming, survival and bosses. Placeholder name and
placeholder assets for now.

**Plan:** [Project plan](https://claude.ai/artifact/CXB7mRPD7CvxJhTRsmLGAM) (phases, systems, decisions).
Docs:

- [docs/guide.md](docs/guide.md): how every feature works and what you can tweak.
- [docs/world-generation.md](docs/world-generation.md): world generation in depth.
- [docs/character-art.md](docs/character-art.md): drawing for the paper doll character.
- [docs/architecture.md](docs/architecture.md): how the code is organized and its rules.
- [docs/decisions.md](docs/decisions.md): decision log.

## Requirements

- **Godot 4.7.2 stable** (standard build, not .NET). Other 4.7.x patch versions should
  work; CI is pinned to 4.7.2.

## Getting started

1. Open Godot, choose **Import**, select this folder's `project.godot`.
2. Press **F5** to run. The main menu opens: **New World**, **Load World**, and in
   debug builds **Test Course** (movement test course) and **Doll Viewer**.
3. **F3** toggles the debug overlay (FPS, position, speed, chunks, last fall).

## Controls (current)

| Key | Action |
| --- | --- |
| A / D | Move (jog) |
| Shift (hold) | Run |
| C | Toggle walk |
| Space | Jump (hold for full height; steer a little in the air) |
| W / S | Climb ropes |
| S + Space | Drop through a platform |
| 1 to 0, mouse wheel | Pick a hotbar slot |
| Left click | Use the held item on the front layer: mine, chop, place, swing, cast; punch with empty hands |
| Right click | Interact with what's under the cursor; otherwise the back layer (place background walls, mine them) |
| E | Interact with the nearest thing |
| I or Tab | Inventory, equipment (book, conduit) and spells |
| R | Tap: spellbook out / away. Hold: spell wheel |
| Ctrl + mouse wheel | Mining / placing area |
| Q | Throw the selected stack |
| H | Put the held item away / take it out |
| B | Debug brush on/off (wheel picks a block, left / right mouse remove / place) |
| Esc | Pause menu (resume, save, settings with zoom, quit to menu) |
| ` (~) | Dev console (debug builds): `help` for commands |
| F3 | Debug overlay |
| F6 | Regenerate the world from `data/worldgen/forest.tres` (debug builds) |
| F7 | Reload item types after editing `data/item_types/*.tres` (debug builds) |

Movement values are exported on the Player: run the game, open the **Remote** tree,
select `Player`, and tweak them live in the Inspector.

## World generation

Settings live in `data/worldgen/forest.tres`: open it in the Inspector, change values,
save, then press **F6** in game to regenerate, or render a whole-world map:

```
godot --headless --path . --script res://tools/preview_world.gd -- --seed=42
```

Everything is explained in [docs/world-generation.md](docs/world-generation.md).

## Tests

Tests use [GUT](https://github.com/bitwes/Gut) (bundled in `addons/gut`).

- **In the editor:** open the GUT panel at the bottom and click **Run All**.
- **Command line:**
  ```
  godot --headless --path . -s addons/gut/gut_cmdln.gd
  ```
- **CI:** every push and pull request runs the suite in GitHub Actions
  (`.github/workflows/tests.yml`).

## Project layout

```
assets/    art, audio, fonts, shaders (placeholders until real assets land)
data/      game content as .tres resources, one folder per category
docs/      architecture notes and decision log
scenes/    top-level scenes: main menu, world
src/       code, by feature: core, world, player, items, magic, ...
tests/     GUT tests, mirroring src/
tools/     editor-time scripts (placeholder generation, etc.)
```

## Art

`assets/ASSETS.md` lists every asset, its size and layout.

- **Scholar:** edit `art/Scholar-casual.aseprite`, then re-import (how to draw for the
  paper doll: [docs/character-art.md](docs/character-art.md)):
  ```
  godot --headless --path . --script res://tools/import_aseprite.gd -- --in=res://art/Scholar-casual.aseprite --out=res://assets/sprites/scholar
  ```
- **Terrain, trees, backdrop** are generated:
  ```
  godot --headless --path . --script res://tools/generate_tiles.gd -- --export=game
  ```
- **Item icons and held sprites** (placeholders) and the default items
  ([docs/items-and-mining.md](docs/items-and-mining.md)):
  ```
  godot --headless --path . --script res://tools/make_item_art.gd
  godot --headless --path . --script res://tools/make_items.gd
  ```

## Scripted runs and screenshots

`DevCli` (autoload) drives the game from the command line, for screenshots and
smoke tests. Any DevCli argument skips the menu and starts a temporary world (add
`--seed=`, `--size=`, `--world=course` to choose it, or `--menu` to stay on the menu).
Example: spawn at column 6, walk left across the world seam, screenshot:

```
godot --path . -- --spawn=6 --hold=move_left:20:60 --shot=58:/tmp/seam.png --quit=62
```

See `src/core/dev_cli.gd` for all options.

## Workflow

One phase = one branch (`phase-NN-name`). Patrick reviews, pushes and merges; each
phase's handoff lists what to playtest.
