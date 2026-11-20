# Crafting, stations, furniture and mana

Phase 5. How you go from nothing to copper tools, and where every number lives.

## Starting from nothing

A new character starts with **no items and no spells** (they've lost their memory).
The first things come off the ground:

- **Sticks and rocks** lie on the grass. Right click one (or press E near it) to pick
  it up: a stick gives 1 **Wood**, a rock 1 **Stone**.
- **Bare hands don't break anything**, not even dirt. You need a tool. (They do punch
  enemies, see combat.md.)

**Logs** are what trees drop, by size: one per `tiles_per_log` (6) tiles of height on the
`Plants` node, so small pines give 2, medium 3, large 4. One
Log crafts into **4 Wood** by hand, or you build with it: a log cabin block (right click:
a log back wall). **Wood** is the plank block (right click: a plank back wall) and the
wood in every recipe; a stick on the ground gives 1 Wood. There are no separate planks
or sticks.

The path: stone + wood = **Hand Hammer** (kept in your inventory, never used up), then
stone and wood for a **Stone Pickaxe** and **Stone Axe**, wood into a **Workbench**,
then a **Furnace** for copper bars and an **Anvil** for copper tools.

For testing, the console has `devkit` (the old starting kit plus all four spells) and
`mana` (infinite mana on or off).

### Forageables: sticks and rocks (`Forage` node, `src/world/forage_layer.gd`)

Things lying on the ground that right click or E picks up. Each type is a **ForageData**
in `data/forage/` (`stick` gives Wood, `rock` gives Stone): the item it gives, its ground sprite, and a
weight per kind of floor. New types (mushrooms, say) are a new file there.

Where they lie:

- **Surface grass:** some flower spots, plus bare grass tiles.
- **Bare surface dirt or stone** (cliffs, dug ground).
- **Cave floors:** grass, dirt or stone with air above, more than 3 tiles below the
  generated surface line, any depth.

| ForageData | Surface grass | Surface ground | Caves |
| --- | --- | --- | --- |
| Stick | 45 | 0 | 0 |
| Rock | 55 | 100 | 100 |
| Field Mushroom | 8 | 0 | 10 |
| Red Cap | 4 | 0 | 6 |
| Duskcap | 0 | 0 | 14 |
| Glowcap | 0 | 0 | 12 |

Weights compare across types on each kind of floor (on surface grass 45 / 55 / 8 / 4 out
of 112);
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

A felled tree drops 2 to 4 Logs by its size (`tiles_per_log` on the `Plants` node).

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

**Mushrooms** (Phase 9). For now they're food or ingredients; potions, poisons and
cooking each get their own brief later.

| Mushroom | Where | Use now | Later |
| --- | --- | --- | --- |
| Field Mushroom | Surface grass, caves | Food: +8 hunger, +1 health | Cooking |
| Red Cap (red, white spots) | Surface grass, caves | Barely food: +2 hunger | Healing Potions, Mushroom Stew |
| Duskcap (purple) | Caves only | Ingredient | Poison Coatings, Poison Flasks (spells later) |
| Glowcap | Caves only | Ingredient; glows (light radius 14, cyan) | Mana potions |

Console: `forage <type>` puts one on the ground under the cursor. `pickups` counts forageables and floor tiles in the loaded area and how many came
back this session; `pickups <days>` lets that many days pass for them (off screen).

Their sprites are sized like the thing (stick 12x5, rock 9x7 px), from
`tools/make_item_art.gd`.

## Crafting window

A separate window on the right side of the screen (the inventory opens with it, top
left). **K** (or the **Craft (K)** button in the inventory) opens **hand crafting**;
right click (or E) a station to open that station's list instead. The window closes
with its **x**, K, Esc, closing the inventory, or walking out of reach.

**Materials from chests:** crafting (and station upgrades and learning spells) also uses
what's in chests within `World.craft_chest_tiles` (12) of you. Your inventory is used
first, then the closest chest, then the next. The "have / need" counts include them.
Crafted items go to your inventory (`CraftStock`, src/items/craft_stock.gd).
Dev console **`freecraft`** toggles free crafting: no materials or max mana needed and
nothing is used up.

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
| Hand | Hand Hammer: 1 stone + 1 wood |
| Hand | Stone Pickaxe, Stone Axe: 3 stone + 2 wood each |
| Hand | Wood x4: 1 log |
| Hand | Wood Platform x2: 1 wood |
| Hand | Torch x5: 1 slime + 1 wood (the only torch recipe) |
| Hand | Workbench: 10 wood (needs the hand hammer) |
| Workbench | Chest: 8 wood + 2 copper bars |
| Workbench | Door: 6 wood |
| Workbench | Table: 8 wood |
| Workbench | Shelf: 4 wood |
| Workbench | Furnace: 20 stone + 4 wood + 3 torches |
| Workbench | Copper Anvil: 6 copper bars |
| Furnace | Copper Bar: 3 copper ore |
| Anvil | Copper Pickaxe: 10 bars + 3 wood; Copper Axe: 8 bars + 3 wood |
| Furnace | Iron Bar: 3 iron ore |
| Anvil | Iron Pickaxe: 12 iron bars + 3 wood; Iron Axe: 10 + 3 wood; Iron Sword: 10 + 2 wood |
| Anvil | Iron Helmet 12, Iron Chestplate 20, Iron Greaves 15 iron bars |
| Hand | Campfire: 5 wood + 3 stone |

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
| `display_surface` | Items can be put on display on its top (Table, Shelf; not stations) |
| `needs_wall` | Every tile needs a back wall when placed (Shelf) |
| `detail` | Art pixels per world pixel: 2 for detailed art (stations, Table, Shelf). See "Detailed art" in guide.md |
| `station`, `station_tier` | Makes it a crafting station |
| `upgrade_to`, `upgrade_cost` | Upgrade in place (see below) |

| Object | Size | Notes |
| --- | --- | --- |
| Workbench | 5x4 | Station `workbench`. Its top is at hip height (the Scholar is 8 tiles tall). |
| Furnace | 4x5 | Station `furnace`, gives orange light (radius 6) |
| Copper Anvil | 3x3 | Station `anvil`, on a stump |
| Chest | 3x3 | 40 slots |
| Door | 1x8 | Right click opens and closes. Starbound style, two images, same 1x8 footprint: `door.png` closed (the wall runs across the screen, so the door is seen edge on: a thick slab with iron straps under a lintel) and `door_open.png` open (it swung toward you, so you see its face, drawn 3 tiles wide starting at its hinge, the doorway's edge: `sprite_width_px` 24, `sprite_align` from the hinge side). `door_open_left` is the mirror, used when you open it from the right. It only opens where it has room to swing: if a block or another object is in the way it opens the other way, and if both sides are blocked it stays shut ("Something's in the way"). Won't close on you. Open, any visible part of it (the whole swung face) can be clicked to close it. Blocks can be placed next to it or on top (a lintel), back walls next to it, on top or behind it (`anchors_building`), open or closed. |

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
- Enchanting comes later, with a design brief first.

## Items on display

Hold a small item and **right click a free spot** on a floor, a **Table** top or a
**Shelf** to set one down on display. **Right click it** to take it back (straight into
your inventory). Displays are decoration: they don't do anything while displayed.

- **Where:** any empty tile standing on a solid block, a platform, or the top of a
  furniture piece with `display_surface` (Table, Shelf). Not on crafting stations.
- **What:** small things: materials, food, potions, seeds, scrolls (`ItemData.can_display`).
  Not tools, weapons, armor, spells, blocks or furniture. `displayable = false` on an
  item forbids it.
- **One item per tile**, drawn as the item at its size on the ground (a potion is
  about 2 blocks tall), bottom-centered on the tile.
- The block under a display can't be mined out from under it. Breaking the table or
  shelf drops what was on it. Mining the display tile itself drops the item.
- Saved with the world (`displays`, wrapped tile to item id). Code: `World.can_display_at`,
  `request_place_display`, `request_take_display`; the tile holds the `display` object.
- **Table** (4x3, workbench: 8 wood): on the floor. **Shelf** (3x1, workbench: 4 wood):
  hangs on a back wall (every tile needs one when placed), not on the floor.
- Console: `display <item>` puts one on display at the cursor, no item needed.

## Cooking and alchemy

- **Campfire** (station `cooking`): right click it to cook. Recipes and effects are in
  [survival.md](survival.md).
- **Clay** is a block found in patches in the dirt near the surface (world-generation.md).
  2 Clay fire into a **Clay Flask** at the furnace.
- **Alchemy Table** (5x3, station `alchemy`): workbench, 12 Wood + 3 Copper Bars + 2 Clay
  Flasks. Its window has tabs; a recipe picks its tab with `RecipeData.tab` (empty = the
  first tab). Tabs per station are `STATION_TABS` in `src/ui/hud/hud.gd`.

| Tab | Recipe | Makes |
| --- | --- | --- |
| Potions | Clay Flask + 2 Red Cap | Healing Potion |
| Potions | Clay Flask + 2 Glowcap | Mana Potion |
| Coatings | Clay Flask + 2 Duskcap | Poison Coating |
| Flasks | Clay Flask + 1 Duskcap + 1 Slime | 2 Poison Flasks |

What's in a flask is shown by its glaze color and a small badge in the bottom right
corner of the icon (heart: healing, star: mana, drop: coating, skull: thrown poison).
Placeholder art; the flasks are emptied, not returned. A desert biome with sand and
glass vials is planned as its own phase.

## Phase 7 recipes and the bed

Not playtested yet. Hand: 1 Slime + 1 Wood = 5 Torches. Workbench: Wooden Sword (10 wood),
Bed (20 wood). Anvil: Copper Sword (8 bars, 2 wood), Copper Helmet (10 bars), Copper
Chestplate (16 bars), Copper Greaves (12 bars). The bed object is 9x3 with `needs_floor`
and the new `ObjectDef.bed` flag; what it does is in [combat.md](combat.md).

## Spell scrolls (placeholder chain, will change)

Not playtested yet.

| Recipe | Station | Makes |
|---|---|---|
| 1 Wood | Workbench | 3 Paper |
| 3 Paper + 1 Slime | Workbench | 1 Blank Scroll |
| 20 Wood + 5 Copper Bars + 4 Paper | Workbench | Spell Weaving Table (6x3, station `spell_weaving`) |
| 1 Blank Scroll + Copper Bars (2 / 5 / 10 by spell tier) | Spell Weaving Table, **Scrolls** tab | Scroll: <spell>, only for spells you know |
| 1 Blank Scroll + 20 Slime | Spell Weaving Table, **Scrolls** tab | Scroll: Gel Cushion (exceptions are `SCROLL_COSTS` in tools/make_items.gd) |

The scroll costs are placeholders: each spell gets its own materials later (feathers for
Fly, say), in its recipe file `data/recipes/scroll_<spell>.tres`.

The **Spell Weaving Table** window has two tabs:

- **Spells:** learn spells here, for good. Every spell you don't know yet is listed,
  cheapest tier first; **Learn** uses its `learn_cost` (copper bars by tier: 4, 10, 20;
  20 Slime for Gel Cushion) and it joins your known spells. No scroll needed. A spell
  above your book's tier can be learned; it says it needs a better book to cast.
  Spells with `learnable_at_table = false` (SpellData) aren't listed: they only come
  from a **Spell Page**. Recipes come from `Crafting.learn_recipes` (made on the fly,
  `RecipeData.teaches`).
- **Scrolls:** scribe a scroll (a one-use cast) of any spell **you know**, and only
  those. It costs the spell's scroll recipe in full, times `World.scribe_cost_mult`
  (1.0; a skill can lower it later, rounded up, at least 1; the Blank Scroll stays 1).
  A spell with no recipe file costs just a Blank Scroll. It also takes a strong enough
  mage: your **max** mana must be at least `World.scroll_max_mana_by_tier` for the
  spell's tier (100 / 200 / 300); no mana is used. Recipes come from
  `Crafting.scroll_recipes`. Scrolls cast at base power (your book doesn't boost them),
  so they're for using a spell without your mana or giving one to a friend.

Under the tabs: group buttons (All, Tools, Movement, Attack, Defense, Light, the same
groups as the Spell Index) and a search box (click it and type; Esc, Enter or a click
elsewhere stops typing). They filter both tabs by the spell each recipe is about.

The craft amount (`-` / `+` / typed) is for one craft: it goes back to 1 after you craft,
when you pick another recipe, and when the window opens.

Tabs per station are `Hud.STATION_TABS` (Create and Empower join later). A recipe's
`requires_max_mana` is checked, never used up.

A scroll (`ItemData.teaches_spell`, kind SCROLL) is one use: left click casts its spell
once for free. Scrolls never teach spells.

A **Spell Page** (`page_<spell>`, `ItemData.learns_spell`, kind PAGE) is found, not
crafted: left click learns its spell for good and uses the page up (a spell you already
know keeps the page). Rare spells will only come from pages. There's no loot yet:
console `page <spell>` forgets a spell and gives you its page, `give page_<spell>` just
gives one.
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
