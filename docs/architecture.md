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

## World

- **Tiles:** 8 px. The Scholar is about 3 tiles wide and 8 tall.
- **Chunks:** 32x32 tiles, generated on demand. Only chunks near the camera are loaded.
- **Horizontal wrap:** chunk x coordinates wrap modulo the world width; the renderer
  uses unwrapped coordinates near the camera, so the seam is invisible.
- **Seeded:** the same seed always generates the same world (tested).

## Rendering a chunk

Each loaded chunk has four parts (`src/world/chunk_renderer.gd`):

1. **Terrain sprite** drawn by `terrain.gdshader`. It gets a 36x36 tile texture (the
   chunk plus a 2-tile border; R = block terrain slot, G = wall slot) and draws per
   pixel: a smoothed outline of the solid tiles plus noise (slopes and corners come out
   diagonal and rounded), material boundaries shifted by noise, lit rims, soft
   undersides, grass, and walls. Textures come from `assets/terrain`. Blocks and walls
   marked `built` on their TileDef (planks) skip the smoothing: crisp square edges with
   a dark edge line and a lit top row.
2. **Collision layer:** a hidden TileMapLayer with full-tile and platform shapes.
   Collision stays exactly on the tile grid even though the art is smoothed.
3. **Props layer:** a visible TileMapLayer for thin tiles (platforms, ropes).
4. **Decorations:** trees and flowers on grassy surfaces (from the generator's rules).

**Lighting** (`light_map.gd`): a tile-level light map over the loaded area. Open sky
(no block, no wall) is lit; light fades per tile through air and more through blocks.
Drawn as a smoothed multiply overlay with an ambient floor. Recomputed when chunks load
or a block changes.

**Backdrop** (`backdrop.gd`): screen-space parallax layers that repeat horizontally and
darken underground.

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

Base resolution 640x360, window 1920x1080 (3x), `canvas_items` stretch with integer
scaling, nearest filtering, 2D transforms snapped to pixels. Pixel art stays crisp.
