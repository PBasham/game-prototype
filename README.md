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
2. Press **F5** to run. Phase 0 shows a boot screen with the placeholder tile atlas.
3. **F3** toggles the debug overlay (FPS, draw calls, game state, live watch values).

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

## Placeholder assets

`assets/ASSETS.md` lists every placeholder, its size and layout. Replacing a
placeholder with real art is a file swap with the same name and layout.
Regenerate placeholders with:

```
godot --headless --path . --script res://tools/generate_placeholders.gd
```

## Workflow

One phase = one branch = one pull request. Each PR lists what to playtest.
