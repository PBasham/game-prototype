# game-prototype

A 2D side-scrolling sandbox for PC: procedurally generated worlds, mining, building,
crafting, deep magic, summons, farming, survival and bosses. Placeholder name and
placeholder assets for now.

**Plan:** [Project plan](https://claude.ai/artifact/CXB7mRPD7CvxJhTRsmLGAM) (phases, systems, decisions).
Architecture notes are in [docs/architecture.md](docs/architecture.md); decisions in
[docs/decisions.md](docs/decisions.md).

## Requirements

- **Godot 4.7.2 stable** (standard build, not .NET). Other 4.7.x patch versions should
  work; CI is pinned to 4.7.2.

## Getting started

1. Open Godot, choose **Import**, select this folder's `project.godot`.
2. Press **F5** to run. You spawn in the Phase 1 test world (forest), as the Scholar.
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
| Mouse wheel | Debug brush: pick block |
| Left / right mouse | Debug brush: remove / place block (until mining in Phase 3) |
| F3 | Debug overlay |

Movement values are exported on the Player: run the game, open the **Remote** tree,
select `Player`, and tweak them live in the Inspector.

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
scenes/    top-level scenes (boot, later menus and the world)
src/       code, by feature: core, world, player, items, magic, ...
tests/     GUT tests, mirroring src/
tools/     editor-time scripts (placeholder generation, etc.)
```

## Art

`assets/ASSETS.md` lists every asset, its size and layout.

- **Scholar:** edit `art/Scholar-casual.aseprite`, then re-import:
  ```
  godot --headless --path . --script res://tools/import_aseprite.gd -- --in=res://art/Scholar-casual.aseprite --out=res://assets/sprites/scholar
  ```
- **Terrain, trees, backdrop** are generated:
  ```
  godot --headless --path . --script res://tools/generate_tiles.gd -- --export=game
  ```

## Scripted runs and screenshots

`DevCli` (autoload) drives the game from the command line, for screenshots and
smoke tests. Example: spawn at column 6, walk left across the world seam, screenshot:

```
godot --path . -- --spawn=6 --hold=move_left:20:60 --shot=58:/tmp/seam.png --quit=62
```

See `src/core/dev_cli.gd` for all options.

## Workflow

One phase = one branch = one pull request. Each PR lists what to playtest.
