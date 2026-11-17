# Items, inventory, mining, placing, magic and plants

Everything Phase 4 added: what it does, where it lives, and every number you can tweak.
Live tweaking works like everywhere else: run the game, Scene panel **Remote**, select
the node (`ItemUser`, `Plants`, `Hud`, a drop under `Drops`) and edit it in the
Inspector. Permanent changes go in the `.tres` or the script's `@export` default.

## Controls

| Input | What it does |
| --- | --- |
| **1 to 0**, mouse wheel | Pick a hotbar slot |
| **Left click** | Use the held item on the **front** layer: swing, mine, chop, place a block, plant. Hold to repeat. |
| **Right click** | On something you can interact with (doors, chests later): interact. Otherwise use the held item on the **back** layer: place the block as a background wall, mine background walls (also behind blocks). |
| **E** | Interact with the nearest thing in reach (nothing interactable exists yet) |
| **I** or **Tab** | Open / close the inventory (with equipment and spells) |
| **R** (tap) | Take the spellbook out (like Starbound's matter manipulator), with the last spell you used; tap again to go back to your hotbar slot |
| **R** (hold) | Spell wheel: move the mouse toward a spell, let go to cast with it |
| **Ctrl + mouse wheel** | Change the area: one setting shared by spells and building (blocks, walls, grass seeds), up to the spellbook's `build_area_max` (3x3). Pickaxes keep their own fixed area. Wheel up = bigger. |
| **Q** | Throw the selected stack |
| **H** | Put the held item away / take it out |

Inventory panel (I): 4 rows of 10, the top row is the hotbar.

- Left click: pick up a stack, put it down, merge or swap.
- Right click: take half, or put one down from the stack on the mouse.
- Shift + left click: move a stack between the hotbar and the rest.
- Click the world with a stack on the mouse: throw it. Closing the panel puts it back.
- Hover a slot for its tooltip.
- To the right: the **Book** and **Conduit** equipment slots. Below: the **Spellbook**
  slots and **Spells you know** (see Magic).

While the mouse is over the hotbar or panel, you're carrying a stack, or the spell wheel
is open, clicks don't use items.

## Front and back layers (Starbound-style)

Every tile has a front block and a back wall. One item covers both: Dirt, Stone and
Wood Planks place a block with left click and a background wall with right click
(`places_wall` on the item). Mining works the same way: left click mines blocks, right
click mines background walls, even behind blocks. A mined wall drops the block it came
from (`drop_item` on `data/walls/*.tres`: dirt_wall drops dirt, stone_wall stone,
wood_wall planks). No hammer.

Background walls have their own textures (`terrain` on each wall `.tres`), so a block
and its wall can look different whenever you want them to.

Copper ore, platforms and rope have no back-wall version (right click does nothing).

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
| `plants` | `tree` (a sapling on grass) or `grass` (turns dirt into grass) |
| `free_place` | Can go anywhere in reach; otherwise it must touch a block or wall |
| `place_area_max` | 0 = up to the spellbook's `build_area_max`; 1 = always one at a time (tree seeds); other = a cap |
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
| Copper Ore, Wood Platform, Rope | Blocks (front only) |
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

Spells are data: `data/spells/<id>.tres` (`SpellData`, `src/items/spell_data.gd`). A
spell has the same mining fields as an item (beam, damage, area, reach) plus
`requires_conduit`.

- **Spells you know** are kept on the character. A new character knows the Mining
  Spell. (How you learn more comes with crafting and loot.)
- **The spellbook is part of the character**, not a hotbar item: the **Book** slot in
  the inventory panel. Empty = the Basic Spellbook (4 slots). Other books can have more
  slots and `spell_power`. Your loadout stays when you swap books; a smaller book just
  uses its first slots.
- **Putting spells in the book:** open the inventory, click a spell under "Spells you
  know", then click a Spellbook slot. Right click a Spellbook slot to empty it. Only
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
- No mana yet.

Debug builds add test magic (runtime only, never saved, not real content) in the third
inventory row: **Dev Grimoire** (8 slots, x1.5), **Dev Focus** (a "focus" conduit,
x1.25, +4 reach), **Dev Tome**, and the spell **Dev Wide Beam** (wider, needs the focus).
Try: put Dev Wide Beam in your book, see it red on the wheel, equip Dev Focus, cast it.

## Starting kit and the character file

A character is saved separately from worlds: `user://characters/default.gpchar` (name
and inventory). Until character select exists (Phase 7) there's one automatic
character. The first time you start a world it's made with the starting kit:

pickaxe, axe, a Mining Spell shortcut (slot 3), 99 planks, 30 platforms, 30 rope, 5
tree seeds, 10 grass seeds, 50 dirt. It knows the Mining Spell, already in the book.

To change the kit: `STARTING_KIT` in `src/items/character_data.gd`. To get a fresh
character, delete `default.gpchar` (in the folder Project > Open User Data Folder
opens). The character saves with the world (autosave, Save, Save & Quit).

Debug builds also put the placeholder weapons (dev sword, bow, book...) in the second
inventory row. They're for testing animations, not content, and are never saved.

## Mining

- Blocks have health (`health` in `data/tiles/*.tres` and `data/walls/*.tres`): dirt
  and grass 40, stone 80, copper ore 110, planks 50, platforms 20, rope 15, background
  walls 30. A copper pickaxe breaks dirt in 2 hits and stone in 4.
- Damaged blocks show cracks in 4 stages (`assets/fx/cracks.png`) and heal after
  `block_heal_seconds` (5) without a hit (`World` node).
- Broken blocks drop their item (`drop_item`, empty = the item with the tile's id;
  grass drops dirt). `unbreakable` blocks can't be mined. The world's bottom row never
  breaks.
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

- Left click places a block, right click a background wall, at the swing's impact;
  hold to keep placing.
- A block must touch a block or have a wall behind it (or connect to one through other
  tiles placed in the same click), can't go inside the player or a tree trunk, and
  only replaces air. A wall must touch a wall or a block (or have a block in front of
  it), and can go behind the player. `free_place` items skip the touching rule.
- You can't place more than the selected stack holds.
- Placing a block where a flower or sapling stands breaks it.

## Drops (`src/items/item_drop.gd`)

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
- **Grass spread:** dirt that touches air and sits next to grass turns into grass.
  `grass_spread_checks_per_second` (1500 random checks over the loaded area) sets the
  speed: higher spreads faster.
- Saved with the world for every chunk whose plants or blocks changed.

## Scripted runs

`--aim=DX:DY` aims at an offset (px) from the player's chest instead of the mouse, so
screenshots can show mining and placing:

```
godot --path . -- --aim=60:36 --tap=hotbar_3:20 --hold=use_primary:30:200 --shot=100:/tmp/beam.png --quit=105
```
