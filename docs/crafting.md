# Crafting, stations, furniture and mana

Phase 5. How you go from nothing to copper tools, and where every number lives.

## Starting from nothing

A new character starts with **no items and no spells** (they've lost their memory).
The first things come off the ground:

- **Sticks, rocks and flint** lie on the grass. Right click one (or press E near
  it) to pick it up. Felled trees also drop 1 to 3 sticks.
- **Bare hands don't break anything**, not even dirt. You need a tool.
- **Stone** blocks sometimes drop **flint** too (10%, `bonus_drop_item` and
  `bonus_drop_chance` on `data/tiles/stone.tres`).

The path: rock + stick = **Hand Hammer** (kept in your inventory, never used up), then
flint and sticks for a **Stone Pickaxe** and **Stone Axe**, wood into planks, planks into
a **Workbench**, then a **Furnace** for copper bars and an **Anvil** for copper tools.

For testing, the console has `devkit` (the old starting kit plus all four spells) and
`mana` (infinite mana on or off).

### Pickups on the grass (`Plants` node, `src/world/plant_layer.gd`)

They're seeded with the flowers: some flower spots become pickups instead.

| Export | Default | What it does |
| --- | --- | --- |
| `pickup_share` | 0.4 | Share of flower spots that are a pickup instead |
| `flint_share` | 0.2 | Of those, the share that's flint (the rest is split between sticks and rocks) |
| `sticks_min`, `sticks_max` | 1, 3 | Sticks a felled tree drops |

## Crafting window

Open the inventory (I or Tab). The crafting column is to the right of the equipment
column. With nothing open it shows **hand recipes**; right click a station in the
world to see that station's list instead (it closes when you walk out of reach).

- Each row: the output icon and name, then the inputs with counts (red when you're
  short). A required tool shows **keep** (it isn't used up). "xN" on the right is how
  many you can make right now.
- **Click** a row to craft 1, **Shift+click** to craft 10 (or as many as you can).
  Anything that doesn't fit in your inventory drops at your feet.
- Mouse wheel scrolls the list. Hovering shows what's missing.

### Recipes: `data/recipes/<id>.tres` (`RecipeData`, `src/items/recipe_data.gd`)

| Field | What it does |
| --- | --- |
| `station` | Station id that makes it (`workbench`, `furnace`, `anvil`), empty = by hand |
| `station_tier` | Minimum station tier (1 = any) |
| `inputs` | Item id to count, used up |
| `requires` | Item ids that must be in the inventory but aren't used up (the hand hammer) |
| `output`, `output_count` | What you get |

Current recipes:

| Where | Recipe |
| --- | --- |
| Hand | Hand Hammer: 1 rock + 1 stick |
| Hand | Stone Pickaxe, Stone Axe: 3 flint + 2 sticks each |
| Hand | Wood Planks x2: 1 wood |
| Hand | Wood Platform x2: 1 plank |
| Hand | Torch x3: 1 stick + 1 wood |
| Hand | Workbench: 10 planks (needs the hand hammer) |
| Workbench | Rock x3: 1 stone (needs the hand hammer) |
| Workbench | Chest: 8 planks + 2 copper bars |
| Workbench | Door: 6 planks |
| Workbench | Furnace: 20 stone + 4 wood + 3 torches |
| Workbench | Copper Anvil: 6 copper bars |
| Furnace | Copper Bar: 3 copper ore |
| Anvil | Copper Pickaxe: 10 bars + 3 sticks; Copper Axe: 8 bars + 3 sticks |

Stone tools: Stone Pickaxe 15 mining, Stone Axe 15 chopping, both reach 7 (the copper
ones are stronger).

Defaults are written by `tools/make_items.gd` (items, spells, objects and recipes).
`--only=a,b` limits it to some ids; it never overwrites a file unless you pass
`--force`, so edit the `.tres` files freely.

## Furniture and stations: `data/objects/<id>.tres` (`ObjectDef`)

Furniture is a tile object several tiles big. Its item (`kind` FURNITURE,
`places_object`) places it with the cursor at the bottom middle; a translucent ghost
shows where. It needs a clear footprint and (with `needs_floor`) a solid block or a
platform under the whole bottom row. Mine any of its tiles to pick it back up. You
can't mine the floor under furniture.

| Field | What it does |
| --- | --- |
| `width_tiles`, `height_tiles` | Footprint (the anchor is the bottom-left tile) |
| `frame` | Frame of the sprite sheet to draw |
| `needs_floor` | Must stand on blocks or platforms |
| `blocks_movement` | Solid to the player (closed doors) |
| `toggles_to` | Right click swaps to this object (door to open door and back) |
| `container_slots` | Makes it a chest with this many slots |
| `station`, `station_tier` | Makes it a crafting station |
| `upgrade_to`, `upgrade_cost` | Upgrade in place (see below) |

| Object | Size | Notes |
| --- | --- | --- |
| Workbench | 3x2 | Station `workbench` |
| Furnace | 3x3 | Station `furnace`, gives orange light (radius 6) |
| Copper Anvil | 2x2 | Station `anvil` |
| Chest | 2x2 | 40 slots |
| Door | 1x8 | Right click opens and closes. Won't close on you. |

- **Chests:** right click opens the chest grid in place of the magic sections. Click
  to move items like the inventory; Shift+click moves a whole stack between chest and
  inventory. A chest with something in it can't be broken. Contents save with the world.
- **Station tiers:** a station with `upgrade_to` shows an **Upgrade** row at the bottom
  of its list; it costs `upgrade_cost` and replaces the station in place with the next
  tier. Recipes with a higher `station_tier` only show at that tier. No station has an
  upgrade yet; the framework is ready for it.
- Alchemy and enchanting stations come later, each with a design brief first.

## Mana (on the Player, `src/player/player.gd`)

| Export | Default | What it does |
| --- | --- | --- |
| `max_mana` | 100 | Mana pool |
| `mana_regen` | 15 | Mana per second refilled |
| `mana_regen_delay` | 1.0 | Seconds after spending before the refill starts |

The mana bar sits under the hotbar. Costs are on each spell (`mana_cost` per cast,
`mana_per_second` while a beam or concentration is on):

| Spell | Cost |
| --- | --- |
| Mining Spell | 4 per second |
| Chopping Spell | 3 per second |
| Fly | 10 per second (while on; mana doesn't refill while flying) |
| Spark | 2 per cast |

Running out stops a beam and ends Fly ("Out of mana"). Casting with too little shows
"Not enough mana". Console `mana` toggles infinite mana and refills.

## Spell tiers

Each spell has a `tier` (1 for all real spells now) and each spellbook a
`max_spell_tier` (Basic Spellbook: 1). A spell above the book's tier can't go in the
book: "Too powerful for your spellbook". The debug Dev Wide Beam is tier 2 and needs the
Dev Grimoire (tier 3).
