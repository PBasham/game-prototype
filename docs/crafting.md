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

Tools are spells (Phase 24): every character starts knowing the **Mining Spell** and
**Chopping Spell** (R and Ctrl + R) with a **Copper Dagger**. There are no pickaxes or
axes. The path: wood into a **Workbench**, then a **Furnace** for copper bars and an
**Anvil** for copper weapons and armor; copper bars also go into the **Spell Weaving
Table**, whose Empower tab ranks up Mining and Chopping (see below).

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
nothing is used up (Empower ranks too). **`infinite`** toggles infinite items: placing, eating, throwing and
scrolls use nothing up.

**Chests:** Shift + click moves a stack between your inventory and the chest. Buttons:
**Take all**, **Deposit all** (everything outside the hotbar), **Quick stack** (only the
items the chest already holds, from outside the hotbar, like Terraria) and **Rename**
(type a name, Enter or Done saves, Esc cancels). Hovering a chest in the world shows its
name (`World.chest_names`, saved). A torch on a wall comes down with a right click
(`ObjectDef.right_click_takes`).

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
| `requires` | Item ids that must be in the inventory but aren't used up (no recipe uses it now) |
| `output`, `output_count` | What you get |
| `unlock_items` | **Discovered recipe:** hidden until the character has had one of these items in the inventory (empty = always known). The moment one turns up: "New recipe: ..." and a chime. Remembered per character (`CharacterData.seen_items`, saved), so using the item up doesn't hide it again. Spells to learn at the table do the same with `SpellData.learn_unlock_items`. |

**Summons (Phase 22):** each summonable enemy drops a rare core that shows its summon's
recipes and goes into them; its Spell Page is a rarer drop that teaches the spell
outright (left click, anywhere), and may turn up in loot later.

| Core | Drops from | Shows |
| --- | --- | --- |
| Forest Spirit Core (1 in 20; page 1 in 50) | Forest Spirit | **Learn: Summon Forest Spirit** (Spell Weaving Table: 1 core + 5 Magic Essence), **Scroll: Summon Forest Spirit** (Scribe's Desk: Blank Scroll + 3 Magic Essence + 1 core), **Forest Spirit Pendant** |
| Slime Core (1 in 40; page 1 in 100) | Green and Blue Slime | **Learn: Summon Slime** (1 core + 20 Slime + 5 Magic Essence), **Scroll: Summon Slime** |

`SpellData.page_needs_table` (a page you must take to the table) is still there for
later spells; no summon uses it now.

Current recipes:

| Where | Recipe |
| --- | --- |
| Hand | Wood x4: 1 log |
| Hand | Wood Platform x2: 1 wood |
| Hand | Torch x5: 1 slime + 1 wood (the only torch recipe) |
| Hand | Workbench: 10 wood |
| Workbench | Chest: 8 wood + 2 copper bars |
| Workbench | Door: 6 wood |
| Workbench | Table: 8 wood |
| Workbench | Wooden Chair: 4 wood (2x3; right click to sit) |
| Workbench | Shelf: 4 wood |
| Workbench | Furnace: 20 stone + 4 wood + 3 torches |
| Workbench | Copper Anvil: 6 copper bars |
| Darkwood Workbench (tier 2) | Reinforced Wood: 4 wood + 1 iron bar = 4 |
| Darkwood Workbench (tier 2) | Reinforced Darkwood: 4 darkwood + 1 iron bar = 4 |
| Furnace | Copper Bar: 3 copper ore |
| Anvil | Copper Dagger: 4 bars |
| Anvil | Dual Storm Axes: 10 iron bars + 8 Magic Essence |
| Scribe's Desk | Storm Charm: 6 copper bars + 6 Magic Essence |
| Furnace | Iron Bar: 3 iron ore |
| Anvil | Iron Sword: 10 iron bars + 2 wood |
| Anvil | Iron Helmet 12, Iron Chestplate 20, Iron Greaves 15 iron bars |
| Hand | Campfire: 5 wood + 3 stone |

Defaults are written by `tools/make_items.gd` (items, spells, objects and recipes).
`--only=a,b` limits it to some ids; it never overwrites a file unless you pass
`--force`, so edit the `.tres` files freely.

## The Catalog (J)

The **Catalog** is a panel, not an item: **J**, or the **Catalog** button in the
inventory (next to the trash), opens it next to the inventory (`CatalogWindow`, src/ui/hud/catalog_window.gd; data in `Catalog`,
src/items/catalog.gd). Three tabs:

- **Items:** every item but spells. Ones you've never had show as black silhouettes;
  the title shows "found / total". Click a found item for its page: description, where
  it's made, which enemies drop it, how many recipes use it, and a **Recipes** button.
- **Enemies:** an enemy counts as found once you've killed one. Its page shows health,
  damage, defense, how many you've slain, and its drops (drops you've never had from it
  stay silhouettes).
- **Recipes:** put an item in the slot (drop it from the mouse; right click clears) to
  list what makes it and what it goes into. Recipes you haven't unlocked show as "???"
  with their station; known ones show the ingredients. Click a known row to jump to that
  item's recipes.
- **Search** (Items and Enemies): the box at the top right narrows the list to names
  containing what you type. Only found things match, so it doesn't give away what's
  still hidden. Enter or Esc stops typing.

"Found" items are `CharacterData.seen_items` (anything that's been in your inventory);
kills and drops are `slain` and `seen_drops` (`CharacterData.note_kill`, called from
`Enemy._die`). A recipe is known when you've had one of its `unlock_items`, the same
rule as the crafting window. Station names come from the lowest tier object with that
`station`. Dev console: `catalog [items|enemies|recipes] [name]`.

## Furniture and stations: `data/objects/<id>.tres` (`ObjectDef`)

**Facing:** furniture you place while facing left is mirrored, so it faces the way you
did (a bed's headboard on the other side). `ObjectDef.flips` (on by default) turns it
off for a piece; doors and display spots never flip. Saved with the world (meta
"flipped", `World.flipped`).

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
| `seat`, `seat_height_px`, `seat_x_px` | A chair: right click sits you on it, the seat this high above the floor and this far in from the backrest side; you face away from the back (flipped chairs face left) |

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
- **Special storage** holds only one kind of thing, but lots of it, and its picture
  fills up as it fills:

| Object | Size | Holds | Capacity | Recipe (workbench) |
| --- | --- | --- | --- | --- |
| Lumber Rack | 5x4 | Any logs and wood (Log, Darkwood Log, Wood, Darkwood, both Reinforced) | 10 full stacks (9,999 each) | 25 Wood + 4 Logs |
| Potion Cabinet | 3x5, glass doors, 4 shelves of 3 spots | Potions, coatings, bottles | 12 slots of 6 stacks (180 potions a slot) | 20 Wood + 2 Copper Bars + 4 Glass |
| Large Potion Cabinet (id `potion_bookcase`) | 4x6, 5 shelves of 4 spots | Potions, coatings, bottles | 20 slots of 6 stacks | 30 Wood + 4 Copper Bars + 6 Glass |
| Shelf (id `potion_shelf`) | 3x2, on a back wall, 4 spots | Anything | 4 slots of 2 stacks | 6 Wood |
| Pantry Rack | 3x3, 2 open shelves of 4 spots, on a floor or a back wall | Food (not potions or coatings) | 8 slots of 5 stacks | 12 Wood |
| Food Pantry | 3x4, 2 open shelves of 4 spots over a cupboard | Food | 14 slots of 4 stacks (6 in the cupboard) | 20 Wood + 2 Copper Bars |

- **Spots:** shelved storage gives each slot its own spot on a shelf
  (`ObjectDef.slots_per_shelf`): slot 0 is the top shelf's left spot, reading left to
  right, top shelf down, and the storage window lays its slots out the same way, with a
  plank under each shelf's row. A spot shows as many of its item as fit, times how full
  the stack is (at least one), spread evenly. `container_stack_mult` lets each slot hold that many
  of the item's stacks. The rule: display storage holds at least what chests would in
  the same space (a chest: 40 stacks in 9 tiles, about 4.4 a tile), so potion cabinets
  are 6, the Pantry Rack and bookshelves 5, the Food Pantry 4, the Shelf 2. The old display Shelf is
  retired (`ItemData.obsolete`: no recipe, not in Creative or the Catalog; placed ones
  still work); the Potion Shelf is now the Shelf and takes anything.
| Small Bookshelf (id `bookshelf`) | 3x4, 2 shelves over a cupboard | Books, spellbooks, tomes, scrolls, pages, paper | 12 slots of 5 stacks | 20 Wood |
| Bookshelf (id `tall_bookshelf`) | 4x6, 3 shelves over a cupboard | the same | 24 slots of 5 stacks | 36 Wood |

- **Storage for anything** (like a chest, its picture doesn't change): **Barrel** (2x2, 10
  stacks, 10 Wood + 1 Copper Bar), **Crate** (2x2, 12 stacks, 12 Wood), and three
  **Hanging Nets** that hang by rope from a block above (`ObjectDef.hang_points`: the
  columns that need a solid block right above the top row) and show what's inside heaped
  in the net (`FillLook.NET`, `net_bag`): Small (4x2, 6 stacks, 8 Rope + 2 Wood), Hanging
  Net (2x3, 8 stacks, 12 Rope + 2 Wood), Long (2x5, 12 stacks, 16 Rope + 2 Wood), Large
  (6x4, 16 stacks, two ropes, 24 Rope + 4 Wood). Their ropes are as thick as placed rope. Barrels, crates, pantries and the bookshelf have flat tops.
- **Liquid Barrels** (2x3): Liquid Barrel (iron banded wood, 1,000 buckets, 16 Wood + 2
  Iron Bars) and Iron Liquid Barrel (2,500 buckets, 8 Iron Bars + 4 Wood).
  `ObjectDef.liquid_capacity` only records the size: there are no liquids yet. Right
  click or E opens a small window with its gauge ("Empty, 0 / 1,000 buckets",
  `LiquidWindow`). Both have a brass tap.
- Storage tags worked out from the item (`ItemData.has_storage_tag`): `food` is any food
  that isn't a potion or coating; `book` is books, tomes, scrolls, pages, Paper and Blank
  Scrolls. Other tags are listed in `storage_tags`.
- **Looks:** pantries use `BOTTLES` (each food's icon on the shelves, 16x16 icons at full
  size, 32x32 ones halved); the bookshelves use `BOOKS`: one spine per book (a stack shows
  one per copy) in its icon's color, top shelf first; scrolls, pages and paper go in the
  closed cupboard and don't show.
  `ObjectDef.front_frame` draws one frame of the picture over what's inside: the glass
  doors of both potion cabinets and the nets' mesh, so the contents sit behind them.

  Fields on the `ObjectDef`: `container_accepts` (a storage tag; items list theirs in
  `ItemData.storage_tags`: every log and wood is `lumber`; healing and mana potions, poison
  coatings and flasks, and clay flasks are `potion`), `container_stack_cap` (a stack size
  that replaces the items' own, 0 = theirs), and `fill_look`: `FRAMES` (a sprite sheet of 11 frames, 0% to 100% in 10% steps; not used
  now), `PILE` (the Lumber Rack: each kind in its own color, so Darkwood shows purple;
  boards lie flat in the left `pile_boards` share (0.4) of `pile_area`, logs show round
  ends in staggered rows on the right, each filling from the bottom,
  `ObjectLayer._draw_pile`) or `BOTTLES` (the potion furniture draws the bottles inside on its shelves).
- **Bottles on shelves:** each bottle is drawn from its item's `shelf_sprite` if it has
  one, else its icon cropped and halved (`ObjectLayer.shelf_texture`, each 2x2 block keeps
  its most solid pixel). So a Clay Jug or Glass Flask is wider than a vial and takes more
  shelf, and every potion looks like its icon. Draw a `shelf_sprite` (in the furniture's
  art px, detail 2) to replace one. Each item shows bottles for its share of the shelf
  width, set left to right 1 art px apart, bottom shelf first, wrapping to the next shelf
  when one doesn't fit. A bottle taller than the room up to the shelf above (less its
  2 px plank and 1 px of air, `ObjectLayer.shelf_room`) is drawn shrunk to fit. Shelf tunables on the `ObjectDef`: `bottle_shelves` (plank tops in
  art px from the top, bottom shelf first), `bottle_x0` (where a shelf starts), and the
  shelf width `bottles_per_shelf` x `bottle_step`. `ItemData.bottle_shape` and
  `bottle_contents` record the bottle and what's in it. Art from
  `tools/make_potion_storage_art.py`.
- **Stacking:** furniture with `flat_top` (chest, table, Scribe's Desk, Lumber Rack,
  Potion Cabinet, Large Potion Cabinet) counts as a floor, so you can stand a Potion Cabinet on
  a Potion Cabinet. The bottom one can't be picked up while something stands on it ("Take
  the ... off the top first"); things displayed on a table just fall off as before.
- **Sand and glass:** Sand is in the Creative window only for now (no world sand yet).
  It's counted in grains (Phase 52): a block (left click) or a Sand Wall (right click)
  takes 16, and mining one gives 16 back. Sand blocks fall (see items-and-mining.md,
  "Voxels"). Workbench: 16 Sand = 16 Sand Bricks (one block or wall; bricks count like sand, 16 a tile, and don't fall).
  Glass is also a see-through block (left click) and Glass Wall (right click); Clay places
  a Clay Wall.
  Furnace: 16 Sand = 1 Glass; Glass Vial = 1 Glass, Glass Bottle = 2, Glass Flask = 3;
  Clay Bottle = 3 Clay, Clay Jug = 4 Clay (the Clay Flask is unchanged). The window shows
  "used / total" and a fill bar. Art from `art/concepts/storage/make_storage.py`.
- **Liquid Barrels hold water** (Phase 54): `liquid_capacity` in voxel cells (16 a tile):
  Liquid Barrel 400 (25 tiles), Iron Liquid Barrel 960 (60 tiles). Fill and empty them
  with Siphon Liquid; right click shows how full. Crafting within reach can use their
  water. Breaking one spills its water around it. Saved in world meta "liquids".
- **Water** in recipes is the pseudo item `water` (not carried, `obsolete` so it stays out
  of Creative and the Catalog): `CraftStock.water_count` / `water_take`, set by the HUD
  from `World.water_for_crafting`. Water bottle recipes: survival.md, "Thirst".
- Console `stock <item> [count]` fills the chest you have open (testing storage).
- Furniture is at most 8x8 tiles (`World.MAX_FURNITURE`). Furniture placed before a
  size change keeps its old filler tiles; mine it and place it again.
- **Station tiers:** a station with `upgrade_to` shows an **Upgrade** row at the bottom
  of its list; it costs `upgrade_cost` and replaces the station in place with the next
  tier. Recipes with a higher `station_tier` only show at that tier. The first one:
  **Workbench -> Darkwood Workbench** (tier 2) for 20 Darkwood + 3 Iron Bars. It makes
  everything a Workbench does, plus **Reinforced Wood** (4 Wood + 1 Iron Bar = 4) and
  **Reinforced Darkwood** (4 Darkwood + 1 Iron Bar = 4): sturdy building blocks (160
  health, walls 90) with iron straps, each with a back wall (right click).
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
| Potions | Clay Flask + 1 Glowcap | Glow Potion |
| Potions | the empty bottle + Red Caps / Glowcaps (Clay Bottle 3, Clay Jug 4, Glass Vial 2, Glass Bottle 3, Glass Flask 4) | the same bottle of Healing / Mana (ids `healing_<bottle>`, `mana_<bottle>`) |
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

Two magic stations:

- **Spell Weaving Table** (station `spell_weaving`, 20 wood, 5 copper bars, 4 paper at
  the workbench): two tabs, **Learn** and **Empower**. Learn: every spell you don't know yet is listed,
  cheapest tier first; **Learn** uses its `learn_cost` (copper bars by tier: 4, 10, 20;
  20 Slime for Gel Cushion) and it joins your known spells. No scroll needed. A spell
  above your book's tier can be learned; it says it needs a better book to cast.
  Spells with `learnable_at_table = false` (SpellData) aren't listed: they only come
  from a **Spell Page**. Recipes come from `Crafting.learn_recipes` (made on the fly,
  `RecipeData.teaches`).

  **Empower**: each spell you know that has nodes is listed once. Click one: its **tree**
  opens on the right, nodes as pixel circles with an icon and "rank / max" under them,
  joined by lines (gold once the node above has a rank). A node is locked (dim, a little
  padlock) until the node it hangs from has a rank. Click a node to pick it: its name,
  rank, what it does, what the next rank changes ("Max area 2 -> 3") and its cost show
  below, with the Empower button. Ranks are bought for good, per spell. Nodes are data:
  `data/empower/<id>.tres` (`EmpowerNode`, src/items/empower_node.gd); the layout is
  worked out from `requires` / `requires_any` (`Hud._empower_layout`), icons are
  `assets/ui/empower/<id>.png` (`tools/make_empower_icons.py`).

  | Field | What it does |
  | --- | --- |
  | `stat`, `per_rank` | What a rank changes (MANA_COST -0.05 = 5% cheaper per rank; FIELDS: see `adds` and `scales`) |
  | `max_rank` | Ranks (5) |
  | `cost_per_rank` | Cost of rank 1; rank n costs n times this |
  | `rank_costs` | Costs rank by rank instead (Power: 10 copper bars, then 12 iron bars) |
  | `adds` | FIELDS: SpellData numbers added per rank (`mining_power` 10) |
  | `scales` | FIELDS: SpellData numbers scaled per rank (`damage` 0.1 = 10% more) |
  | `spells` | Only these spells (by id) |
  | `casts` | Only spells cast this way (projectiles, chains...) |
  | `groups` | Spell groups it's offered for (empty = every spell that uses mana) |
  | `requires` | The node it hangs from (needs a rank first); only counts when that node is in the spell's tree, else it's a root there |
  | `requires_any` | The same for nodes shared by trees with different roots: the first of these in the tree (Reach: Power or Sharpness) |
  | `icon` | Its picture in the tree (16x16) |
  | `order` | Order in the tree |

  Nodes so far. Ranks are saved per character (`CharacterData.empower`); the spell's
  tooltip shows the new numbers and "Empowered: Power 1/2". FIELDS nodes work on a copy
  of the spell (`CharacterData.apply_empower`, `ItemData.find`), so everything that
  casts or checks the spell sees the empowered numbers.

  | Node | Spells | Per rank | Cost |
  | --- | --- | --- | --- |
  | **Power** | Mining (root) | power +10 (rank 1 mines iron), 30% faster, iron glow | 10 copper bars, then 12 iron bars |
  | **Area** | Mining, after Power | max area +1: 3x3, 4x4, 5x5 (3 ranks); placing blocks goes as big | 10, then 20 copper bars, then 15 iron bars |
  | **Sharpness** | Chopping (root) | 40% faster, metal glow | 8 copper bars, then 10 iron bars |
  | **Reach** | Mining, Chopping, after Power / Sharpness | +2 tiles (3 ranks) | 5 and 10 copper bars, then 8 iron bars |
  | **Efficient** | anything that uses mana, after Potency where there is one | 5% less mana (5 ranks) | 2 / 4 / 6 / 8 / 10 Magic Essence |
  | **Potency** | projectiles, gusts, charged, zones, summons, chains | 10% more damage (5 ranks) | 2 / 4 / 6... Magic Essence |
  | **Arc** | Chain Spark, after Potency | one more jump, a tile farther (2 ranks) | 5 essence + 5 copper bars, then 8 essence + 5 iron bars |
  | **Distance** | Blink | 3 tiles farther (3 ranks) | 3 / 6 / 9 Magic Essence |
  | **Lasting** | buffs, lights, summons | 20% longer (3 ranks) | 2 / 4 / 6 Magic Essence |
  | **Evolve** | Summon Slime, after Lasting | the next slime form | 6 essence + 15 slime |
  | **Limit** | summons, after Lasting | one more out at a time (2 ranks, `SpellData.summon_bonus_slots`) | 6 essence + 10 copper bars, then 10 essence + 10 iron bars |
- **Scribe's Desk** (station `scribing`, 15 wood, 5 paper, 2 copper bars at the
  workbench): scribe a scroll (a one-use cast) of any spell **you know**, and only
  those. It costs the spell's scroll recipe in full, times `World.scribe_cost_mult`
  (1.0; a skill can lower it later, rounded up, at least 1; the Blank Scroll stays 1).
  A spell with no recipe file costs just a Blank Scroll. It also takes a strong enough
  mage: your **max** mana must be at least `World.scroll_max_mana_by_tier` for the
  spell's tier (100 / 200 / 300); no mana is used. Recipes come from
  `Crafting.scroll_recipes`. Scrolls cast at base power (your book doesn't boost them),
  so they're for using a spell without your mana or giving one to a friend.

Both show group buttons (All, Tools, Movement, Attack, Defense, Light, the same groups
as the Spell Index) and a search box (click it and type; Esc, Enter or a click
elsewhere stops typing) above their lists.

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
