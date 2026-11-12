# Architecture

How the game is put together and the rules every system follows. Updated as systems land.

## Autoloads (src/core)

| Autoload | Job |
| --- | --- |
| `EventBus` | Global signals for events that cross system boundaries. |
| `Settings` | Player settings in `user://settings.cfg`, with defaults. |
| `Registry` | Loads every content definition under `res://data` and looks them up by id. |
| `SaveManager` | Save folders, file naming, versioned save headers. |
| `Game` | Top-level state (menu, loading, playing) and network role. |
| `DebugOverlay` | F3 stats panel; `DebugOverlay.watch(key, value)` from anywhere. |

## Content is data

Every piece of content (item, tile, recipe, spell, enemy, biome, boss) is a `.tres`
resource extending `GameData`, in `data/<category>/`. The Registry loads them by id.

- **Definitions are read-only and shared.** `ItemData` describes "Copper Pickaxe".
- **Instances hold per-object state.** An `ItemStack` holds count, enchantments, etc.
  and references its definition by id.
- **Saves store ids, never resource paths.** Ids must never be renamed after release.
- `GameData.validate()` checks each definition; a test runs it on all content in CI.

## Host-authoritative (multiplayer-ready)

Multiplayer is planned for later, so the game is built as if it were already networked:

- Single-player runs as a local host. `Game.is_authority()` is true.
- **Input never mutates shared state directly.** The player's mining tool calls
  something like `World.request_break_tile(pos)`; the World system checks
  `Game.is_authority()`, validates, applies, and announces the change. When
  networking arrives, clients send the same requests to the host as RPCs.
- **Simulation is separate from presentation.** World data (tiles in packed arrays)
  is not stored in TileMap nodes; the TileMap layers only draw it. Same for entities:
  state lives in plain data, nodes display and simulate it.
- Shared state: tiles, walls, liquids, dropped items, chests, entities, bosses,
  time of day. Per-player state: inventory, equipment, buffs, hunger, mana.

## World (from Phase 1)

- **Tiles:** 16 px. World measured in tiles; presets roughly Terraria-sized.
- **Chunks:** 32x32 tiles. Only chunks near the camera are loaded, drawn and collidable.
- **Horizontal wrap:** the world wraps left to right like Starbound. Chunk x coordinates
  wrap modulo the world width; the camera draws chunks across the seam; positions
  are normalized when an entity crosses it.
- **Seamless generation:** noise for terrain and caves is sampled on a cylinder so the
  seam where x wraps has no visible cut.
- **Seeded:** the same seed always generates the same world (tested).

## Physics layers

| # | Name |
| --- | --- |
| 1 | world |
| 2 | platforms |
| 3 | player |
| 4 | enemies |
| 5 | player_attacks |
| 6 | enemy_attacks |
| 7 | dropped_items |
| 8 | npcs |
| 9 | triggers |

## Rendering

Base resolution 960x540, window 1920x1080, `canvas_items` stretch with integer
scaling, nearest filtering, 2D transforms snapped to pixels. Pixel art stays crisp.
