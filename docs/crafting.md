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

Their sprites are sized like the thing (stick 12x5, rock 9x7, flint 7x6 px), from
`tools/make_item_art.gd`.

## Crafting window

A separate window on the right side of the screen (the inventory opens with it, top
left). **K** (or the **Craft (K)** button in the inventory) opens **hand crafting**;
right click (or E) a station to open that station's list instead. The window closes
with its **x**, K, Esc, closing the inventory, or walking out of reach.

- **Left:** the recipe list. Each row is the output icon and name; the green number is
  how many you can make right now; rows you can't make are dimmed. Mouse wheel scrolls.
- **Right:** the selected recipe: a big icon, the description, **Needs** (have / need,
  green or red) and **Tools (kept)** (required, not used up).
- **Craft** makes 1, **x10** makes up to 10, **All (N)** makes as many as you can.
  Double click a row to make 1. Anything that doesn't fit in your inventory drops at
  your feet.

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
| `toggles_to_left` | Used instead of `toggles_to` when the player is on the right, so a door swings away from you. If that side is blocked, it uses the other one. |
| `hinge_offset` | The footprint column the object turns around: the toggled object keeps this column on the same tile |
| `sprite_width_px` | Draw the sprite this wide (px) (an open door's face is 24 px from its 8 px doorway); 0 = footprint width |
| `sprite_align` | Where a wider sprite sits: centered, starting at the footprint's left edge, or ending at its right edge (an open door starts at its hinge) |
| `container_slots` | Makes it a chest with this many slots |
| `station`, `station_tier` | Makes it a crafting station |
| `upgrade_to`, `upgrade_cost` | Upgrade in place (see below) |

| Object | Size | Notes |
| --- | --- | --- |
| Workbench | 5x4 | Station `workbench`. Its top is at hip height (the Scholar is 8 tiles tall). |
| Furnace | 4x5 | Station `furnace`, gives orange light (radius 6) |
| Copper Anvil | 3x3 | Station `anvil`, on a stump |
| Chest | 3x3 | 40 slots |
| Door | 1x8 | Right click opens and closes. Starbound style, two images, same 1x8 footprint: `door.png` closed (the wall runs across the screen, so the door is seen edge on: a thick slab with iron straps under a lintel) and `door_open.png` open (it swung toward you, so you see its face, drawn 3 tiles wide starting at its hinge, the doorway's edge: `sprite_width_px` 24, `sprite_align` from the hinge side). `door_open_left` is the mirror, used when you open it from the right. Won't close on you. |

- **Chests:** right click opens the chest in its own window on the right (the inventory
  opens too). Click to move items like the inventory; Shift+click moves a whole stack
  between chest and inventory. **Take all** empties the chest into your inventory;
  **Deposit all** puts in everything below your hotbar. A chest with something in it
  can't be broken. Contents save with the world. A chest's size is its
  `container_slots`.
- Furniture is at most 8x8 tiles (`World.MAX_FURNITURE`). Furniture placed before a
  size change keeps its old filler tiles; mine it and place it again.
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

The mana bar is in the health, mana and hunger panel, bottom left. Costs are on each spell (`mana_cost` per cast,
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
