# Working on game-prototype

Godot 4.7.2 (GDScript) 2D sandbox. Read docs/architecture.md before changing core systems.

## Collaboration rules

- Before building any gameplay system, send Patrick a short design brief (the choices
  that matter, with defaults) and wait for his input.
- One phase per branch (`phase-NN-name`), one PR per phase, PR lists what to playtest.
- Never use en dashes in docs, comments or messages.
- Patrick supplies real art and audio; use placeholders and record them in assets/ASSETS.md.
- No dark outlines on terrain, trees or decorations; transitions use texture.
- Don't invent biomes, ores or content. Current scope: surface forest, copper only.
  New content gets a design brief first.

## Art pipeline

- Player sprite: `godot --headless --path . --script res://tools/import_aseprite.gd -- --in=res://art/Scholar-casual.aseprite --out=res://assets/sprites/scholar`
- Terrain, trees, backdrop: `godot --headless --path . --script res://tools/generate_tiles.gd -- --export=game` (style V5 = "t5")
- Tile size is 8 px (`World.TILE`). The Scholar is ~3 tiles wide, ~8 tall.

## Code conventions

- Static typing everywhere (`var x: int`, typed arrays and dictionaries, typed returns).
- Files snake_case, `class_name` PascalCase, signals past tense (`tile_changed`).
- Autoload scripts have no `class_name` (the autoload name is the global).
- Content is data: new items/tiles/spells/recipes are `.tres` under `data/<category>/`
  extending `GameData`, never hardcoded in scripts.
- Host-authoritative: shared state (tiles, items, entities) is only mutated where
  `Game.is_authority()` is true, through the owning system's request API.
- Exported tunables (`@export`) for anything Patrick may want to tweak while playtesting.

## Verify before pushing

```
godot --headless --path . --import          # must print no SCRIPT ERROR
godot --headless --path . -s addons/gut/gut_cmdln.gd   # must exit 0
godot --headless --path . --quit-after 120  # main scene runs without errors
```

## Screenshots for Patrick

Render on a virtual display with DevCli (see README):

```
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 -- --shot=60:/tmp/a.png --quit=65
```

Software rendering is slow (single-digit FPS in the overlay); that's not real performance.
