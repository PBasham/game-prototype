# Items, inventory, mining, placing, magic and plants

Crafting, stations, furniture, chests, doors and mana: [crafting.md](crafting.md).

Everything Phase 4 added: what it does, where it lives, and every number you can tweak.
Live tweaking works like everywhere else: run the game, Scene panel **Remote**, select
the node (`ItemUser`, `Plants`, `Hud`, a drop under `Drops`) and edit it in the
Inspector. Permanent changes go in the `.tres` or the script's `@export` default.

## Controls

| Input | What it does |
| --- | --- |
| **1 to 0**, mouse wheel | Pick a hotbar slot |
| **Left click** | Use the held item on the **front** layer: swing, mine, chop, place a block, plant. Hold to repeat. |
| **Right click** | On something you can interact with (stations, chests, doors, pickups on the grass): interact. Otherwise use the held item on the **back** layer: place the block as a background wall, mine background walls (also behind blocks). |
| **E** | Interact with the nearest thing in reach (a station, chest or door, else the nearest pickup) |
| **I** or **Tab** | Open / close the inventory |
| **K** | Crafting window (hand crafting); see [crafting.md](crafting.md) |
| **P** | Equipment window (armor, accessories, book, conduit, stats, equipped spells); see [combat.md](combat.md) |
| **L** | Spell Index (every spell you know) |
| **R** (tap) | Take the spellbook out (like Starbound's matter manipulator), with the last spell you used; tap again to go back to your hotbar slot |
| **R** (hold) | Spell wheel: move the mouse toward a spell, let go to cast with it |
| **Ctrl + mouse wheel** | Change the area: one setting shared by spells and building (blocks, walls, grass seeds), up to the spellbook's `build_area_max` (3x3). Pickaxes keep their own fixed area. Wheel up = bigger. |
| **Q** | Throw the selected stack |
| **H** | Put the held item away / take it out |

Inventory panel (I): rows of 10, the top row is the hotbar. The number of slots is the
character's inventory size (`Inventory.size`, 40 by default, saved with the character),
so a smaller starting inventory or bags that add rows later only change that number;
the panel lays itself out from it.

- Left click: pick up a stack, put it down, merge or swap.
- Right click: take half, or put one down from the stack on the mouse.
- Shift + left click: move a stack between the hotbar and the rest.
- Ctrl + right click: equip armor, an accessory, a book or a conduit (swaps with the
  equipped one). On an equipment slot (or shift + click it): back into the inventory.
- Click the world with a stack on the mouse: throw it. Closing the panel puts it back.
- Hover a slot for its tooltip.
- To the right: the **Craft (K)**, **Equip (P)** and **Spells (L)** buttons. The
  inventory holds items only.
- **Equipment window (P)**, `src/ui/hud/equipment_window.gd`: your character in the
  middle (a live preview; armor isn't drawn on it yet), armor on the left (head, chest,
  legs), trinkets on the right (3 accessory slots), Book and Conduit underneath, stats on
  the far right. Below: **Equipped spells** (the book's slots), folded away by clicking
  its header, and the **Spell Index (L)** button.
- **Spell Index (L)**, `src/ui/hud/spell_window.gd`: every spell you know with its tier
  and description; "In book" marks the ones in your book. Mouse wheel scrolls
  (`rows_shown`, 7). Click a spell, then a book slot or a hotbar slot.
- Both are movable windows (`HudWindow`, `src/ui/hud/hud_window.gd`): drag the title
  bar. The Equipment window opens in the middle (below the inventory when there's
  room); the Spell Index opens beside it, and if you haven't moved the Equipment window
  the two are centered together. Each keeps its spot until you quit. Opening either
  opens the inventory; closing the inventory closes them.

While the mouse is over the hotbar or panel, you're carrying a stack, or the spell wheel
is open, clicks don't use items.

Items with no use (wood, books, conduits) are just held: clicking doesn't swing.

## Front and back layers (Starbound-style)

Every tile has a front block and a back wall. One item covers both: Dirt, Stone and
Wood Planks place a block with left click and a background wall with right click
(`places_wall` on the item). Mining works the same way: left click mines blocks, right
click mines background walls, even behind blocks. A mined wall drops the block it came
from (`drop_item` on `data/walls/*.tres`: dirt_wall drops dirt, stone_wall stone,
wood_wall planks). No hammer.

Background walls have their own textures (`terrain` on each wall `.tres`), so a block
and its wall can look different whenever you want them to.

Copper ore and platforms have no back-wall version (right click does nothing).

## Tile objects: rope and torches

A third layer, between the back wall and the front block: `data/objects/*.tres`
(`ObjectDef`, `src/world/object_def.gd`), drawn by `ObjectLayer`. An object can share a
tile with a platform or a back wall, never with a solid block. Items place them with
left click (`places_object`).

- **Rope:** climbable (Up / Down), right through platforms (climbing ignores them).
  Can hang through platforms. Needs something next to
  it to be placed (a block, a platform, more rope, or a wall behind), then stays.
- **Torch:** 2 tiles tall (`height_tiles`; drawn upward from its tile, which needs no
  solid block above it). Gives warm light (radius 11, see Lighting in the guide). Goes on a solid
  block below or beside it, or on a back wall, and shows the matching frame (standing,
  leaning left or right, on the wall). It can't go inside a solid block. When what holds
  it is mined, it pops off as an item.
- Mining (left click) takes an object first when there's no solid block in the tile;
  objects break in one hit and drop their item.
- Fields: `frames` (strip of frames 8 x 8*height), `height_tiles`, `style` (ROPE or
  TORCH: which frames),
  `climbable`, `needs_support`, `light_color`, `light_radius`, `health`, `drop_item`.
- Saved with the world (world file format 2; older worlds load with no objects, and
  rope that was a block before this change is gone).

## Items: `data/items/*.tres`

Each item is an `ItemData` (`src/items/item_data.gd`). Open one in the Inspector:

| Field | Meaning |
| --- | --- |
| `kind` | MATERIAL, BLOCK, WALL, TOOL, SPELL, SEED, WEAPON (sorting and tooltips) |
| `icon` | 16x16 inventory icon |
| `max_stack` | 999 for blocks and materials, 1 for tools |
| `held` | How it looks in hand: texture, grip pixel, item type (`data/item_types/`) |
| **Mining** | |
| `mining_damage` | Damage to blocks per hit, or per second for a beam |
| `axe_damage` | Damage to trees per hit |
| `beam` | Mines continuously while held (the mining spell) |
| `mining_area` | Area in tiles (2 = 2x2). Pickaxes have a fixed area. |
| `mining_area_max` | Biggest area for the Ctrl + wheel toggle (0 = no toggle) |
| `reach_tiles` | How far it reaches, measured from the chest |
| `impact_at` | When in the swing the hit lands (0 to 1 through the animation) |
| **Placing** | |
| `places_block` | Block placed with left click |
| `places_wall` | Wall placed with right click (the back layer) |
| `places_object` | Tile object placed with left click (rope, torch) |
| `plants` | `tree` (a sapling on grass) or `grass` (turns dirt into grass) |
| `free_place` | Can go anywhere in reach; otherwise it must touch a block or wall |
| `place_area_max` | 0 = up to the spellbook's `build_area_max`; 1 = always one at a time (tree seeds, platforms, rope); other = a cap |
| `place_reach_tiles` | 0 = the spellbook's `build_reach_tiles`; set it to give an item its own placing reach |
| **Magic** | |
| `spell_slots` | Books: how many spells the book holds |
| `build_reach_tiles` | Books: how far you place blocks, walls and seeds (12) |
| `build_area_max` | Books: biggest building area (3) |
| `spell_power` | Books, conduits, tomes: multiplies spell strength |
| `spell_reach_bonus` | Conduits: extra spell reach in tiles |
| `conduit_type` | Conduits: what kind (spells can require one) |
| `tome_spell` | Tomes: the spell it casts |

Current items:

| Item | Notes |
| --- | --- |
| Copper Pickaxe | 25 per hit, 2x2, reach 10 |
| Copper Axe | 25 per hit on trees (a tree has 100), reach 10 |
| Dirt, Stone, Wood Planks | Blocks; right click places them as background walls |
| Copper Ore, Wood Platform | Blocks (front only) |
| Rope, Torch | Tile objects |
| Basic Spellbook | The book used when the Book slot is empty: 4 slots, power x1 |
| Wood | From trees; becomes planks when crafting exists |
| Tree Seed | Plant on grass; grows into a tree |
| Grass Seeds | Plant on dirt that touches air; turns it into grass |

The defaults come from `tools/make_items.gd`. It never overwrites a file you edited
unless you pass `--force` (or `--only=<id> --force` for one):

```
godot --headless --path . --script res://tools/make_items.gd
```

Placeholder art (icons, held sprites, the sapling, the cracks) comes from
`tools/make_item_art.gd`; your art replaces the PNGs with the same names
(`assets/items/icons/<id>.png`, `assets/items/held/<id>.png`).

The two item types this phase added (`data/item_types/`): **block** (held small, a quick
reach toward the cursor when placing) and **spell** (the equipped book in the back
hand, the front hand channels at the cursor while held).

## Magic

Spells are data: `data/spells/<id>.tres` (`SpellData`, `src/items/spell_data.gd`).
How a spell works is its `cast`:

| Cast | What it does | Fields |
| --- | --- | --- |
| TOOL | Works on the world like a tool: mining (`mining_damage`) or chopping (`axe_damage`), as a beam while held (`beam`) or once per cast | the item fields: area, reach, `requires_conduit` |
| PROJECTILE | Fires a bolt at the cursor that hurts the first thing it hits and fizzles on solid blocks | `damage`, `projectile_speed`, `projectile_range`, `projectile_color` |
| TOGGLE | A concentration spell: a click turns its `effect` on or off. Only one at a time; the HUD shows "Concentrating: ..." | `effect` (&"fly") |

Every spell also has `mana_cost` (per cast) and `mana_per_second` (beams and
concentration), and a `tier`. Mana, costs and tiers: [crafting.md](crafting.md#mana-on-the-player-srcplayerplayergd).

| Spell | Cast | Notes |
| --- | --- | --- |
| Mining Spell | TOOL beam | 55 mining per second per tile, area 2 (toggle 1 to 3), reach 12 |
| Chopping Spell | TOOL beam | 55 chopping per second on the tree under the cursor (the copper axe is about 71/s), reach 12 |
| Fly | TOGGLE | Click to fly, click again to stop. WASD in every direction, Space goes up. No gravity or fall damage while flying. Speed on the Player: `fly_speed` (22), `fly_accel_time` (0.15). Stays on when you switch items. |
| Spark | PROJECTILE | 8 damage (times spell power), 40 tiles/s, 20 tiles. Hold to keep casting (one per 0.3 s). Nothing has health yet except the dev training dummy (console: `dummy`). |

Damageable things are nodes in the `damageable` group with `hit_rect()` and
`take_damage(amount, from)`; enemies will use the same.

- **Spells you know** are kept on the character. A new character knows none (console
  `devkit` teaches the four and fills the book). How you learn spells in the real game
  comes later.
- **The spellbook is part of the character**, not a hotbar item: the **Book** slot in
  the Equipment window. Empty = the Basic Spellbook (4 slots). Other books can have more
  slots and `spell_power`. Your loadout stays when you swap books; a smaller book just
  uses its first slots.
- **Putting spells in the book:** open the Spell Index (L), click a spell, then click a
  slot under "Equipped spells" in the Equipment window (P). Right click a book slot to
  empty it. Only
  spells in the book can be cast (from the wheel or a shortcut).
- **Casting:**
  - **R, the spellbook key:** tap R to take the book out with the last spell you used
    (or the book's first), tap again to put it away and go back to your hotbar slot.
    Hold R for the **spell wheel**: move toward a spell, let go. While the book is
    out the hotbar shows no selection; picking a slot also puts it away.
  - **Hotbar shortcuts:** click a known spell, then a hotbar slot. Number keys and the
    wheel then pick it like an item. A small blue mark shows it's a shortcut; it turns
    red when the spell can't be cast (not in the book, missing conduit). Shortcuts
    can't be thrown into the world; throwing one just removes it.
  - Left click casts on the front layer, right click on the back layer.
- **Conduit** slot: the focus your casting hand uses. `spell_power` and
  `spell_reach_bonus` boost every spell; `conduit_type` unlocks spells that require it.
  Swap conduits by dragging them in and out of the slot. A spell that needs a conduit
  you don't have shows the reason by the cursor and in its tooltip.
- **Tomes:** a hotbar item that casts one spell (`tome_spell`) without needing it in
  the book (a conduit requirement still applies). Strength uses the tome's
  `spell_power` instead of the book's.
- **The book is your building tool too:** placing blocks, walls and seeds uses the
  book's `build_reach_tiles` (12, plus the conduit's reach bonus) and the shared area
  setting, so building feels the same as the mining spell.
- **Strength:** damage = spell's `mining_damage` x book (or tome) `spell_power` x
  conduit `spell_power`. Reach = spell's `reach_tiles` + conduit `spell_reach_bonus`.
- **Mana:** 100, refills after a short pause. See [crafting.md](crafting.md).

Debug builds add test magic (runtime only, never saved, not real content) in the third
inventory row: **Dev Grimoire** (8 slots, x1.5), **Dev Focus** (a "focus" conduit,
x1.25, +4 reach), **Dev Tome**, and the spell **Dev Wide Beam** (wider, needs the focus).
Try: put Dev Wide Beam in your book, see it red on the wheel, equip Dev Focus, cast it.

## Starting state, dev kit and the character file

A character is saved separately from worlds: `user://characters/<name>.gpchar` (name,
look, inventory, equipment, spells). You pick or make one on the main menu's character
page (see [guide.md](guide.md#starting-the-game-menu-worlds-saves)); any character can
play any world. A new character starts with **nothing**: no items, no spells (see
[crafting.md](crafting.md) for how to get going).

Console `devkit` gives the old starting kit: copper pickaxe and axe, a Mining Spell
shortcut, 99 planks, 30 platforms, 30 rope, 20 torches, 5 tree seeds, 10 grass seeds,
50 dirt, and teaches Mining, Chopping, Fly and Spark (put in the book). It's
`DEV_KIT` / `DEV_SPELLS` in `src/items/character_data.gd`. Scripted runs (DevCli) start
with it. In debug builds it also adds the placeholder weapons and test magic, which
are never saved.

The character saves with the world (autosave, Save, Save & Quit). A character from
before character select is called "default" and shows up in the list like any other.

## Mining

- Blocks have health (`health` in `data/tiles/*.tres` and `data/walls/*.tres`): dirt
  and grass 40, stone 80, copper ore 110, planks 50, platforms 20, rope 15, background
  walls 30. A copper pickaxe breaks dirt in 2 hits and stone in 4.
- Damaged blocks show cracks in 4 stages (`assets/fx/cracks.png`) and heal after
  `block_heal_seconds` (5) without a hit (`World` node).
- Broken blocks drop their item (`drop_item`, empty = the item with the tile's id;
  grass drops dirt). `unbreakable` blocks can't be mined. The world's bottom row never
  breaks.
- A block a tree stands on can't be mined (the box goes red): chop the tree first.
  Later, chests and other objects will protect their blocks the same way
  (`World.is_protected`).
- The area is centered on the cursor: a 2x2 picks the four tiles nearest the cursor.
  Each tile must be within reach, measured from the chest to the tile's center.

## Indicators (`ItemUser`, `src/items/item_user.gd`)

| What | Meaning |
| --- | --- |
| Box around the area | White: it'll do something. Blue: the back layer (while right click is held). Red: out of reach, nothing to mine, nowhere to place, or the spell can't be cast. |
| Ghost blocks | Where blocks will go (darker for walls; grass seeds show green). |
| Beam | Spells, from the casting hand to the area. Red when there's nothing to mine there. |
| Red text by the cursor | Why the spell can't be cast. |
| Range ring | Fades in as the cursor nears the edge of reach; red past it. |
| `2x2` label | Shows briefly after Ctrl + wheel. |

Tunables on `ItemUser`: colors (`back_color` for the back layer), `ghost_alpha`, `ring_fade_start` (fraction of reach
where the ring appears), `ring_alpha`, `swing_cut_tiles`.

## Placing

- Left click places a block, right click a background wall, almost instantly (the
  block type's Place motion is 0.08 s and blocks land at `impact_at` 0.2); hold and drag
  to keep placing, about 12 a second.
- Hovering: when the front layer has nothing to do under the cursor but the back layer
  does (a wall could go there, or there's a wall to mine), the box shows the back
  target in blue, so you can see a right click will work.
- Platforms and rope place one at a time. **Planned:** a placing-shape toggle (square,
  horizontal line, vertical line) so platforms and rope can be laid in lines; until
  then they're single tiles.
- A block must touch a block or have a wall behind it (or connect to one through other
  tiles placed in the same click), can't go inside the player or a tree trunk, and
  only replaces air. A wall must touch a wall or a block (or have a block in front of
  it), and can go behind the player. `free_place` items skip the touching rule.
- You can't place more than the selected stack holds.
- Placing a block where a flower or sapling stands breaks it.

## Drops (`src/items/item_drop.gd`)

Thrown stacks (Q, or clicking the world with a stack) fly at `throw_speed` (8 tiles/s,
on the Player) and stop as soon as they land.

A drop is drawn at the item's size: `drop_size` on the item (px), or by kind when 0:
materials and seeds 10, blocks and the rest 11, tools and weapons 13, furniture 14.
`drop_scale` on ItemDrop multiplies all of them.

Picking items up shows one note per item that adds up ("+12 Dirt") while more keep
arriving (`note_seconds` on `Hud`, 1.6).

Items pop out, fall, land on blocks and platforms, and fly to you inside 3 tiles of
your body (measured to the nearest point of the body, so drops at your feet count).
Tunables per drop: `magnet_tiles` (3), `pickup_tiles` (0.6), `magnet_speed`,
`magnet_accel`, `gravity`, `ground_friction`, `air_friction`, `max_loose_speed` (6: if
you walk away from a drop flying toward you, it slows to this instead of shooting
off), `thrown_pickup_delay` (1 s, so a thrown stack doesn't come straight back),
`despawn_minutes` (10). Drops aren't
saved with the world yet.

## Trees, saplings, flowers, grass (`Plants` node, `src/world/plant_layer.gd`)

- Natural trees and flowers come from the generator's decoration rules the first time a
  chunk loads. After that they're the world's: chopped trees stay chopped.
- **Trees:** `tree_health` (100). Each axe hit rocks the tree (`wiggle_degrees`); at 0
  it falls away from you over `fall_time` and breaks into `wood_min` to `wood_max` wood
  and 1 seed (`extra_seed_chance` of a second). Removing the grass under a tree breaks
  it on the spot.
- **Saplings:** plant a tree seed on grass with `tree_spacing` (3) tiles to the next
  tree. It grows in `grow_min_seconds` to `grow_max_seconds` (60 to 150) while the
  world runs, once there are `grow_clearance` (10) clear tiles above it.
- **Flowers:** any tool or weapon swing cuts flowers in front of you; mining or
  placing over them breaks them too. `grass_seed_chance` (0.35) to drop grass seeds.
- **Grass spread:** dirt that touches air and sits next to grass turns into grass,
  but not under a solid block. Putting a solid block on grass turns it back to dirt.
  The grass blades that poke up from a grass block aren't drawn into a tile with a built
  back wall (a room), so floors indoors stay clean.
  `grass_spread_checks_per_second` (1500 random checks over the loaded area) sets the
  speed: higher spreads faster.
- Saved with the world for every chunk whose plants or blocks changed.

## Scripted runs

`--aim=DX:DY` aims at an offset (px) from the player's chest instead of the mouse, so
screenshots can show mining and placing:

```
godot --path . -- --aim=60:36 --tap=hotbar_3:20 --hold=use_primary:30:200 --shot=100:/tmp/beam.png --quit=105
```


## Equipment and weapons

Armor (head, chest, legs), three accessory slots and melee weapons are covered in
[combat.md](combat.md). Item kinds `ARMOR` and `ACCESSORY` were added; weapons are any item
with `melee_damage > 0`.
