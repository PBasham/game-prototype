# Working on game-prototype

Godot 4.7.2 (GDScript) 2D sandbox. Read docs/architecture.md before changing core systems.
docs/code-map.md says where everything is and how to change it (keep it current when files
or fields move); docs/guide.md explains every feature; docs/world-generation.md covers generation;
docs/character-art.md covers the paper doll; docs/3d-character.md covers the 3D body (Blender model rules); docs/items-and-mining.md covers items,
the inventory, layers, mining, placing, magic and plants; docs/crafting.md covers
crafting, stations, furniture, chests, doors, pickups and mana; docs/survival.md covers
day and night, health, hunger, food, berry bushes, dying and the magic bag; docs/combat.md covers
enemies, spawning, melee, armor, equipment stats and beds; the Catalog (J) is in docs/crafting.md. Keep them up to date when behavior or
tunables change: Patrick tweaks things by hand from these docs.

## Collaboration rules

- Before building any gameplay system, send Patrick a short design brief (the choices
  that matter, with defaults) and wait for his input.
- One phase per branch (`phase-NN-name`); the handoff lists what to playtest.
- Commit on the phase branch and push it (`git push -u origin phase-NN-name`). Never
  open or retarget PRs. Finished phases get merged into `main` (fast-forward, since each
  phase branches from the last) and merged branches pruned; Patrick asked for that on
  2026-11-21. New phases branch from `main`. This session can't delete branches on
  GitHub (403): give Patrick the `git push origin --delete ...` line instead.
- Never use en dashes in docs, comments or messages.
- Patrick supplies real art and audio; use placeholders and record them in assets/ASSETS.md.
- No dark outlines on terrain, trees or decorations; transitions use texture.
- Don't invent biomes, ores or content. Current scope: surface forest and one ocean, copper only
  (plus the Phase 5 sticks and rocks (pickups that give wood and stone); Phase 7: green
  and blue slime, slime, wooden and copper swords, copper armor, bed, paper, blank and spell
  scrolls, the Spell Weaving Table, and the spells in data/spells; placeholder sounds;
  Phase 21: Dark Forest Dirt, Grass, Stone and walls, Stone Bricks and Dark Forest Stone
  Bricks, the Forest Spirit Pendant; Phase 22: Slime Core, Summon Slime; Phase 23: the Catalog; Phase 24: no pickaxes or axes,
  the gathering spells from the start, the Copper Dagger, Empower tiers; Phase 25: spell
  schools, marks, the Dual Storm Axes and the Storm Charm; Phase 35: Sand, Glass, Clay
  Bottle, Clay Jug, Glass Vial, Glass Bottle, Glass Flask, Large Potion Cabinet, Potion Shelf;
  Phase 37: Healing and Mana in each bottle, Pantry Rack, Food Pantry, Bookshelf, Barrel,
  Crate, three Hanging Nets, Liquid Barrel, Iron Liquid Barrel; later: Long Hanging Net,
  Siphon Liquid, Bookshelf (tall), Glow Potion, Shaping Spell; Phase 52: Sand Bricks, the Bomb, voxel sand and water; Phase 54: thirst, swimming, bottles of water; Phase 55: the ocean (beaches, Hard Sand) and ponds; Phase 56: crabs, fish, raw and cooked crab and fish, dune grass, seagrass, kelp; Phase 62: fireflies, the Bug Net, the Firefly Lamp; Phase 64: the Deep (chasm, arena, flooded caves, scene caverns, all empty for now); Phase 65: Abyssal Stone; Phase 66: Kelp (item), Water Breathing in each bottle; Phase 67: the Alchemist's Bench, Murky Mixture; Phase 73: the Command spell; Phase 75: the Floating Torch spell, Magic Essence from slimes; Phase 76: Copper, Silver, Gold and Platinum Coins, the coin pouch).
  New content gets a design brief first.
- World generation tunables live in `data/worldgen/forest.tres`, not in code. Patrick
  plans to tune generation himself.

## World generation

- Whole-world map: `godot --headless --path . --script res://tools/preview_world.gd -- --seed=42` (options in docs/world-generation.md)
- F6 in game regenerates from the saved settings. Caves must fit the Scholar (8 tall, 3 wide).

## Art pipeline

- Player sprite: `godot --headless --path . --script res://tools/import_aseprite.gd -- --in=res://art/Scholar-casual.aseprite --out=res://assets/sprites/scholar`
- Character colors: `godot --headless --path . --script res://tools/make_character_palette.gd` (after color changes)
- The player is a paper doll (docs/character-art.md). Prefer code-posed fallbacks over
  asking Patrick for frames; he draws real poses later.
- Item types (hold + attack animations as curves): `data/item_types/`, defaults from
  `tools/make_item_types.gd` (never `--force` over Patrick's edits without asking).
- Items: `data/items/`, spells: `data/spells/`, objects: `data/objects/`, recipes: `data/recipes/`, enemies: `data/enemies/`, spawn tables: `data/spawns/`,
  defaults from `tools/make_items.gd` (same `--force` rule; `--only=a,b`);
  placeholder icons, held sprites, sapling and cracks from `tools/make_item_art.gd`.
- Armor overlays on the paper doll: placeholders from `tools/make_armor_art.gd`
  (`assets/armor/`, listed in each armor item's `wear`).
- Sounds: placeholders from `tools/make_sounds.gd` (`assets/sounds/<id>.wav`, kept unless
  `--force`). Play one with `EventBus.sound_requested.emit(id, position)`.
- UI look: `UiSkin` (src/ui/ui_skin.gd) with nine-slice art in `assets/ui/` from
  `tools/make_ui_art.gd`. Draw every new window, slot and button with it.
- Screenshots of menus: `-- --menu=characters` (or `new_character`, `worlds`, `new_world`); add
  `--overlay=off` to hide the F3 overlay.
- Scripted runs can aim with `--aim=DX:DY` (offset from the chest) for mining shots.
- Terrain, trees, backdrop: `godot --headless --path . --script res://tools/generate_tiles.gd -- --export=game` (style V5 = "t5"), then `-- --export=terrain_hd` for the detailed (128x128) dirt, stone, walls and clay
- Detailed art: 2 art pixels per world pixel (32x32 icons, `HeldItemLook.detail = 2`, 128x128 terrain), see "Detailed art" in docs/guide.md
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

## Verify before committing

```
godot --headless --path . --import          # must print no SCRIPT ERROR
godot --headless --path . -s addons/gut/gut_cmdln.gd   # must exit 0
godot --headless --path . --quit-after 120  # main menu runs without errors
godot --headless --path . -- --quit=120     # a forest world runs without errors
```

## Screenshots for Patrick

Render on a virtual display with DevCli (see README):

```
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 -- --shot=60:/tmp/a.png --quit=65
```

Software rendering is slow (single-digit FPS in the overlay); that's not real performance.
