# Crafting, stations, furniture and mana

Phase 5. How you go from nothing to copper tools, and where every number lives.

## Starting from nothing

A new character starts with **no items and no spells** (they've lost their memory).
The first things come off the ground:

- **Sticks, rocks and flint** lie on the grass. Right click one (or press E near
  it) to pick it up. A rock gives 1 **Stone**. Felled trees also drop 1 to 3 sticks.
- **Bare hands don't break anything**, not even dirt. You need a tool.
- **Stone** blocks sometimes drop **flint** too (10%, `bonus_drop_item` and
  `bonus_drop_chance` on `data/tiles/stone.tres`).

The path: stone + stick = **Hand Hammer** (kept in your inventory, never used up), then
flint and sticks for a **Stone Pickaxe** and **Stone Axe**, wood into planks, planks into
a **Workbench**, then a **Furnace** for copper bars and an **Anvil** for copper tools.

For testing, the console has `devkit` (the old starting kit plus all four spells) and
`mana` (infinite mana on or off).

### Forageables: sticks, rocks and flint (`Forage` node, `src/world/forage_layer.gd`)

Things lying on the ground that right click or E picks up. Each type is a **ForageData**
in `data/forage/` (`stick`, `rock`, `flint`; the rock gives Stone): the item it gives, its ground sprite, and a
weight per kind of floor. New types (mushrooms, say) are a new file there.

Where they lie:

- **Surface grass:** some flower spots, plus bare grass tiles.
- **Bare surface dirt or stone** (cliffs, dug ground).
- **Cave floors:** grass, dirt or stone with air above, more than 3 tiles below the
  generated surface line, any depth.

| ForageData | Surface grass | Surface ground | Caves |
| --- | --- | --- | --- |
| Stick | 45 | 0 | 0 |
| Rock | 40 | 75 | 75 |
| Flint | 15 | 25 | 25 |

Weights compare across types on each kind of floor (45 / 40 / 15 = 45% / 40% / 15%);
0 = never there. A tile's first roll is fixed by its position (the same spot always gives
the same thing). Areas you haven't changed are re-seeded when a world loads, so new
settings show up there. Digging out the ground under one, or putting a block on it, drops
it as an item.

| `Forage` export | Default | What it does |
| --- | --- | --- |
| `flower_spot_share` | 0.4 | Share of flower spots that hold one instead of a flower |
| `surface_grass_chance` | 0.06 | Chance a bare surface grass tile has one: about one every 16 tiles |
| `surface_ground_chance` | 0.05 | Chance a bare surface dirt or stone tile has one |
| `cave_chance` | 0.03 | Chance a cave floor tile has one |

Sticks also drop from felled trees (`sticks_min`, `sticks_max` on the `Plants` node, 1 to 3).

**They come back over time** (random ticks, like grass spreading). A few times a second
the game picks random floor tiles in the loaded area and gives each a small chance to get
a new one, by the same weights. New ones are random, not fixed per tile, and are saved
like anything else. Rules:

- Never on screen: tiles you can see (plus 2 tiles) are skipped.
- Never indoors: none on a tile with a background wall or furniture above it.
- Crowding brake: the chance drops with every forageable within `crowd_radius` tiles
  and is zero at `crowd_cap`, so floors never fill up.
- Areas you were away from catch up when they load again, up to `regrow_catch_up_days`.
  Sleeping counts too.

| `Forage` export | Default | What it does |
| --- | --- | --- |
| `regrow_days_per_item` | 2.5 | In-game days for one new forageable per `regrow_floor_tiles` of open floor, on average |
| `regrow_floor_tiles` | 32 | About a chunk's width of ground |
| `cave_regrow_scale` | 0.5 | Caves come back at this fraction of the surface rate |
| `crowd_radius`, `crowd_cap` | 16, 6 | The crowding brake |
| `regrow_checks_per_second` | 200 | Random tiles checked per second; only changes how evenly it trickles in, not the rate |
| `regrow_catch_up_days` | 3 | Most time an area catches up on when it loads again |

Console: `pickups` counts forageables and floor tiles in the loaded area and how many came
back this session; `pickups <days>` lets that many days pass for them (off screen).

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
- Bottom row: **[-] [amount] [+] Craft**. Craft makes the amount in the field (it
  turns red when you can't make that many; Craft then makes as many as you can, up to
  it). Click the field and type a number (Enter crafts, Esc stops typing), use the
  wheel over it, or [-] / [+] (Shift or right click: by 10). The amount resets to 1 when
  you pick another recipe.
- **Shift + Craft** makes 10, **Ctrl + Craft** makes as many as you can, up to one full
  stack of the item. "Can make N" above the row says how many you could.
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
| Hand | Hand Hammer: 1 stone + 1 stick |
| Hand | Stone Pickaxe, Stone Axe: 3 flint + 2 sticks each |
| Hand | Wood Planks x2: 1 wood |
| Hand | Wood Platform x2: 1 plank |
| Hand | Torch x3: 1 stick + 1 wood |
| Hand | Workbench: 10 planks (needs the hand hammer) |
| Workbench | Chest: 8 planks + 2 copper bars |
| Workbench | Door: 6 planks |
| Workbench | Furnace: 20 stone + 4 wood + 3 torches |
| Workbench | Copper Anvil: 6 copper bars |
| Furnace | Copper Bar: 3 copper ore |
| Anvil | Copper Pickaxe: 10 bars + 3 sticks; Copper Axe: 8 bars + 3 sticks |

Stone tools: Stone Pickaxe 15 mining in a 2x2 area (Ctrl + wheel: 1x1), Stone Axe 15 chopping, both reach 7 (the copper
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
| Door | 1x8 | Right click opens and closes. Starbound style, two images, same 1x8 footprint: `door.png` closed (the wall runs across the screen, so the door is seen edge on: a thick slab with iron straps under a lintel) and `door_open.png` open (it swung toward you, so you see its face, drawn 3 tiles wide starting at its hinge, the doorway's edge: `sprite_width_px` 24, `sprite_align` from the hinge side). `door_open_left` is the mirror, used when you open it from the right. It only opens where it has room to swing: if a block or another object is in the way it opens the other way, and if both sides are blocked it stays shut ("Something's in the way"). Won't close on you. Open, any visible part of it (the whole swung face) can be clicked to close it. |

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

## Phase 7 recipes and the bed

Not playtested yet. Hand: 1 Slime + 1 Stick = 5 Torches. Workbench: Wooden Sword (10 planks),
Bed (20 planks). Anvil: Copper Sword (8 bars, 2 planks), Copper Helmet (10 bars), Copper
Chestplate (16 bars), Copper Greaves (12 bars). The bed object is 9x3 with `needs_floor`
and the new `ObjectDef.bed` flag; what it does is in [combat.md](combat.md).

## Spell scrolls (placeholder chain, will change)

Not playtested yet.

| Recipe | Station | Makes |
|---|---|---|
| 1 Wood | Workbench | 3 Paper |
| 3 Paper + 1 Slime | Workbench | 1 Blank Scroll |
| 20 Wood Planks + 5 Copper Bars + 4 Paper | Workbench | Spell Weaving Table (6x3, station `spell_weaving`) |
| 1 Blank Scroll + Copper Bars (2 / 5 / 10 by spell tier) | Spell Weaving Table | Scroll: <spell>, one recipe per spell |
| 1 Blank Scroll + 20 Slime | Spell Weaving Table | Scroll: Gel Cushion (exceptions are `SCROLL_COSTS` in tools/make_items.gd) |
| 1 Blank Scroll (and a big enough max mana) | Spell Weaving Table, **Copy** tab | **Copy: <spell>**, for any spell you know |

The **Spell Weaving Table** window has two tabs:

- **Craft:** the scroll recipes. A spell you know (learned, in your book or not) costs
  half the materials, rounded up (`World.known_scroll_discount`, 0.5); the Blank Scroll
  is still needed. Those are listed in green with a note. The plain recipes stay until
  scrolls come from loot.
- **Copy:** every spell you know, written onto a Blank Scroll. It takes a strong enough
  mage: your **max** mana must be at least `World.copy_max_mana_by_tier` for the
  spell's tier (100 / 200 / 300), so a starting mage copies tier 1 spells. No mana is
  used, so you can copy as many as you have Blank Scrolls. This is also how you'll make
  more of spells that can't be crafted at all. Recipes come from `Crafting.copy_recipes`
  (made on the fly, not data files). Later: mastery of the spell as a requirement too.

Tabs per station are `Hud.STATION_TABS` (Create and Empower join later). A recipe's
`requires_max_mana` is checked, never used up.

A scroll (`ItemData.teaches_spell`, kind SCROLL) is one use: left click casts its spell
once for free, right click at a Spell Weaving Table learns it for the spell's
`learn_cost` (items-and-mining.md, Magic).
The bar costs per tier are `SCROLL_BARS` in tools/make_items.gd. The table becomes the
Create and Empower table in the Magic progression phase.

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

Each spell has a `tier` (1 for all real spells now except Hyper Drill, tier 3) and each spellbook a
`max_spell_tier` (Basic Spellbook: 1). A spell above the book's tier can't go in the
book: "Too powerful for your spellbook". The debug Dev Wide Beam is tier 2 and needs the
Dev Grimoire (tier 3).
