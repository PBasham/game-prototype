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
| **Right click** | If the held item has a back layer action here (place the block as a background wall; mine a background wall with a pickaxe or mining spell), that comes first, unless something outlined is under the cursor (a door, chest, station, bed, display, a stick, rock or mushroom, a ripe bush): that gets picked up or used instead. Otherwise interact (furniture, sticks and rocks, bushes, mushrooms), put a small item on display, or use the back layer. |
| **I** or **Tab** | Open / close the inventory |
| **K** | Crafting window (hand crafting); see [crafting.md](crafting.md) |
| **P** | Equipment window (armor, accessories, book, conduit, stats, quick spells); see [combat.md](combat.md) |
| **L** | Spell Index (every spell you know: tabs and a search box) |
| **Q**, **E** (hold) | That spell wheel: move the mouse toward a spell, let go. That spell becomes the wheel's tap spell; a cast-right-away spell isn't cast by the pick (tap to cast), an in-hand one goes in your hand |
| **Q**, **E** (tap) | The wheel's last pick again |
| **Z**, **X**, **C** | Their quick spell (cast or put in hand, by the slot's mode), or the item they're a shortcut to |
| **B** | The buff set: casts every spell in it at once |
| **R** | Mining Spell in hand (again: put it away, back to your hotbar slot) |
| **Ctrl + R** | Chopping Spell in hand (same) |
| **Alt + R** | Shaping Spell in hand (same) |
| **F** | Movement spell on or off. Levitate: up raises you to its hover height, down lowers you, and you stay at the height you leave it (the one in the Equipment window's Movement slot; empty = Fly, else Levitate) |
| **Caps Lock** | Walk / run toggle |
| **Ctrl + mouse wheel** | Change the area: one setting shared by spells and building (blocks, walls, grass seeds), up to the spellbook's `build_area_max` (3x3). Pickaxes keep their own fixed area. Wheel up = bigger. |
| **H** | Put the held item away / take it out |

Inventory panel (I): rows of 10, the top row is the hotbar. The number of slots is the
character's inventory size (`Inventory.size`, 40 by default, saved with the character),
so a smaller starting inventory or bags that add rows later only change that number;
the panel lays itself out from it.

- Left click: pick up a stack, put it down, merge or swap.
- A dev infinite stack (Creative window, right click) shows an infinity sign instead of a count.
- Right click: take one onto the mouse (hold it to keep taking, faster and faster: `Hud.take_repeat_delay` 0.35 s, down to `take_repeat_fastest` 0.03 s), or put one down in an empty slot from the stack on the mouse. Shift + right click: take half.
- Shift + left click: move a stack between the hotbar and the rest.
- Ctrl + left click: **trash** it. The trash slot (bottom right, a bin) also takes the
  stack on the mouse; it keeps the last thing thrown away (click it to take it back)
  until the next one replaces it. Saved with the character (`CharacterData.trash`).
- Ctrl + right click: equip armor, an accessory, a book or a conduit (swaps with the
  equipped one). On an equipment slot (or shift + click it): back into the inventory.
- A stack on the mouse, over the world, is **held and used** like Terraria: left click
  swings a sword, mines with a pickaxe, places blocks or furniture (with the usual
  preview), from the mouse stack, not the hotbar (`Player.mouse_stack`, set by the HUD;
  placing uses `Player.take_held`). **Right click throws the stack.** Closing the panel
  puts it back. A spell shortcut on the mouse can't be used; a click on the world drops
  it.
- Hover a slot for its tooltip.
- To the right: the **Craft (K)**, **Equip (P)** and **Spells (L)** buttons. The
  inventory holds items only.
- **Equipment window (P)**, `src/ui/hud/equipment_window.gd`: your character in the
  middle (a live preview; armor isn't drawn on it yet), armor on the left (head, chest,
  legs), trinkets on the right (3 accessory slots), Book and Conduit underneath, stats on
  the far right. Below: **Quick spells** (the Q and E wheels, Z X C, the buff set),
  folded away by clicking its header, and the **Spell Index (L)** button.
- **Spell Index (L)**, `src/ui/hud/spell_window.gd`: every spell you know with its tier
  and description, tabs by group and a search box; "On Q, Z" says which quick slots hold
  it. Mouse wheel scrolls (`rows_shown`, 7). Click a spell, then a quick slot.
- Both are movable windows (`HudWindow`, `src/ui/hud/hud_window.gd`): drag the title
  bar. The Equipment window opens in the middle (below the inventory when there's
  room); the Spell Index opens beside it, and if you haven't moved the Equipment window
  the two are centered together. Each keeps its spot until you quit. Opening either
  opens the inventory; closing the inventory closes them.

While the mouse is over the hotbar or panel, you're carrying a stack that can't be
placed (a spell shortcut), or the spell wheel is open, clicks don't use items.

**A spell in hand** shows its icon and name (in blue) under the hotbar. Below that: a
coated weapon's coating and hits left (green), and the spell you're concentrating on
(Fly, Mend...) with its icon (violet).

Zoomed out, more chunks load around you (enough to fill the screen plus one), so the
edges of the view are never empty or unlit.

**Tables and shelves:** holding something that can go on display over a free spot shows
a faint picture of it there; right click puts it down (from the hotbar, a Z X C item, or
the mouse stack with the inventory open).

**Loose items:** resting drops of the same item within 1.5 tiles merge into one stack
(`ItemDrop.merge_tiles`), and resting drops skip their physics. At most
`World.max_drops` (400) lie around; past that the oldest disappear (like Terraria).

A click that starts on a window (its close button, say) never reaches the world.

**Food and potions:** left click eats or drinks (in the hotbar, or on the mouse with the
inventory open, where right click throws the stack).

Items with no use (wood, books, conduits) are just held: clicking doesn't swing.

## Front and back layers (Starbound-style)

Every tile has a front block and a back wall. One item covers both: Dirt, Stone and
Wood (the plank block) place a block with left click and a background wall with right click
(`places_wall` on the item). Mining works the same way: left click mines blocks, right
click mines background walls, even behind blocks. A mined wall drops the block it came
from (`drop_item` on `data/walls/*.tres`: dirt_wall drops dirt, stone_wall stone,
wood_wall wood, log_wall a log). No hammer.

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
  Clicking a rope with rope in hand adds one to the bottom of that rope
  (`ItemUser.rope_end`). Ropes side by side are joined by a short rope across.
- **Torch:** 2 tiles tall (`height_tiles`; drawn upward from its tile, which needs no
  solid block above it). Gives warm light (radius 11, see Lighting in the guide). Goes on a solid
  block below or beside it, on a back wall, or on a tree's bare trunk (Phase 61:
  `PlantLayer.trunk_at`, the lower `trunk_share` 60% of it; it drops when the tree is
  cut), and shows the matching frame (standing,
  leaning left or right, on the wall). It can't go inside a solid block. When what holds
  it is mined, it pops off as an item. Held, a torch is out in front of you (item type
  `torch`) and lights around you (`ItemData.held_light_radius` 24, `held_light_color`;
  `HeldLight`, a light source that follows your hand). Only blocks and back walls show
  light, so in open air you see it on the ground and walls around you.
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
| `max_stack` | 9999 for blocks (dirt, stone, wood, ores, torches, platforms...), 999 for materials, 1 for tools |
| `held` | How it looks in hand: texture, grip pixel, item type (`data/item_types/`) |
| **Mining** | |
| `mining_damage` | Damage to blocks per hit, or per second for a beam |
| `axe_damage` | Damage to trees per hit |
| `beam` | Mines continuously while held (the mining spell) |
| `mining_area` | Area in tiles (2 = 2x2) a swing starts at. Ctrl + wheel can always go down to 1x1. |
| `mining_area_max` | Biggest area for the Ctrl + wheel toggle (0 = no bigger than `mining_area`) |
| `reach_tiles` | How far it reaches, measured from the chest |
| `impact_at` | When in the swing the hit lands (0 to 1 through the animation) |
| **Placing** | |
| `places_block` | Block placed with left click |
| `places_wall` | Wall placed with right click (the back layer) |
| `places_object` | Tile object placed with left click (rope, torch) |
| `plants` | `tree` (a sapling on grass) or `grass` (turns dirt into grass) |
| `free_place` | Can go anywhere in reach; otherwise it must touch a block or wall |
| `place_area_max` | 0 = up to the spellbook's `build_area_max`; 1 = always one at a time (tree seeds, platforms, rope); other = a cap |
| `place_reach_tiles` | 0 = the Mining Spell's reach (with Empower and conduit); set it to give an item its own placing reach |
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
| Copper Dagger | Everyone starts with one: 8 damage, reach 3.5 (`dagger` item type) |
| Dirt, Stone, Wood, Log | Blocks (Wood places planks, Log a log cabin block whose run ends stick out 2 px, `overhang_px` on the tile); right click places them as background walls |
| Copper Ore, Wood Platform | Blocks (front only) |
| Rope, Torch | Tile objects |
| Basic Spellbook | The book used when the Book slot is empty: power x1, tier 1 |
| Sapling (`tree_seed`) | From pines; plant on grass; grows into a pine |
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
| TOGGLE | A concentration spell: a click turns its `effect` on or off. Only one at a time; the HUD shows "Concentrating: ..." | `effect` (&"fly", &"levitate", &"mend"), `move_speed`, `boost_speed_mult`, `boost_mana_mult`, `hover_tiles`, `heal_per_second` |
| GUST | A push in a cone toward the cursor: shoves and hurts what's in it; in the air it pushes you back | `damage`, `gust_tiles`, `gust_angle`, `gust_push`, `gust_recoil` |
| BLINK | Teleports you toward the cursor to the farthest spot you fit | `blink_tiles` |
| BUFF | A timed effect on you (`effect`, `duration` seconds), shown as an icon with the time left above the health panel (hover for details; it blinks in its last 10 s). Casting again refreshes it. Buffs end when you leave the world. Effects: `gel_cushion`, `arcane_edge`, `barrier` | `effect`, `duration`, `melee_mult`, `trigger_health`, `shield_amount`, `shield_seconds` |
| CHARGED | Hold to charge, let go to fire a bolt; damage, size and mana grow with the charge. A ring around the hand closes as it charges | `charge_seconds`, `charge_min_damage`, `charge_min_mana`, `damage`, `mana_cost`, projectile fields |
| ZONE | A circle at the cursor for `duration`; heals you while you stand in it | `zone_tiles`, `heal_per_second` |
| WARD | A rune on the ground under the cursor (within 12 tiles down); the first enemy to touch it takes `damage` and `knockback`. Up to `max_active`, the oldest goes | `damage`, `knockback`, `duration`, `max_active` |
| SUMMON | A familiar that follows you and shoots the nearest enemy in range. One at a time | `damage`, `summon_interval`, `summon_tiles`, `duration`, projectile fields |
| CONJURE | A temporary platform at the cursor (only in open air). Works like a platform tile (Down + Jump drops through), drops nothing, blinks in its last 3 s | `conjure_tiles`, `duration` |
| CHAIN | A bolt shoots toward the cursor out to `reach_tiles`; the first thing it touches is hit, then it jumps. A block stops it; if it misses, it fizzles (mana spent) | `damage`, `chain_jumps`, `chain_tiles`, `chain_falloff` |
| RITUAL | Stand still for `ritual_seconds` (moving or getting hurt cancels it); mana is paid when it completes. Effect `recall`: back to your bed or the world spawn | `ritual_seconds`, `effect` |
| SENSE | Outlines every `sense_block` tile within `sense_tiles` of you, above the darkness, for `duration` (a snapshot when cast) | `sense_block`, `sense_tiles`, `duration` |
| LIGHT | A floating light: follows you (one at a time; casting again refreshes it), or with `light_placed` you steer it with the cursor while the button is held and it stays where you let go | `light_radius`, `light_color`, `duration`, `light_placed`, `light_max` |
| GRAB | Held like a beam: a portal opens at the cursor (pulled in to `reach_tiles`, needs sight unless `needs_sight` is off) and loose items within `grab_tiles` of it fly into it, straight through blocks, and pop out of a small portal at your hand, where you pick them up. Mana per second while held | `grab_tiles`, `grab_pull_speed`, `reach_tiles`, `mana_per_second`, `needs_sight` |

Every spell also has `mana_cost` (per cast) and `mana_per_second` (beams and
concentration), `reagents` (items used up by each cast, e.g. 5 Slime; it can't be cast
without them, and a cast that fails on mana uses nothing), a `tier`, and a `cooldown` (seconds before it can be cast again; 0 = only
the casting animation limits it). An item with `mining_round` mines a circle as wide as
its area instead of a square (Hyper Drill). Mana, costs and tiers: [crafting.md](crafting.md#mana-on-the-player-srcplayerplayergd).

| Spell | Cast | Notes |
| --- | --- | --- |
| Mining Spell | TOOL beam, phantom pickaxe | Known from the start, free. 45 mining per second per tile, landing once per swing (`phantom_swing_time` 0.3 s); power 30 (stone, dirt, copper), area 2 (toggle 1 to 2), reach 8. Empower: Power (copper then iron bars: power 40 then 50, 30% faster per rank), Area (max 3x3, 4x4, 5x5), Reach (+2 tiles, 3 ranks). Placing blocks and walls goes as big as its max area. |
| Shaping Spell | TOOL (`shapes_blocks`) | Known from the start, free. Click a placed block to step it to its next shape: full, bottom half, top half, then the four slopes (solid toward bottom-left, bottom-right, top-left, top-right). Logs (blocks with `overhang_px`) also get "turned", which flips the automatic upright/sideways look. Right click shapes the wall: full, bottom half, top half, and for log walls a fourth step, turned (upright, or sideways in a single column). **Shift + click** steps back. Only blocks some item places can be shaped (not grass or natural-only tiles). Collision follows the shape. Reach 8. Empower: Reach. |
| Siphon Liquid | TOOL | Learned at the Spell Weaving Table. Ready for liquids (there are none yet): hold to draw up liquid, right click to pour it. Reach 8, area 1. Empower: Reach, Area. |
| Chopping Spell | TOOL beam, phantom axe | Known from the start, free. 60 chopping per second, once per swing, reach 8. Empower: Sharpness (copper then iron bars, 40% faster per rank), Reach |
| Fly | TOGGLE | Click to fly, click again to stop. WASD in every direction, Space goes up. No gravity or fall damage while flying. 34 tiles/s (`move_speed`; the Player's `fly_speed` is the fallback), `fly_accel_time` (0.15). **Hold Shift while moving to boost:** speed x2 (`boost_speed_mult`), mana x4 (`boost_mana_mult`: 40/s, a full bar in about 2.5 s). The boost is meant to become an empowerment later. Stays on when you switch items. 10 mana/s. |
| Spark | PROJECTILE | 8 damage (times spell power), 40 tiles/s, 20 tiles. Hold to keep casting (one per 0.3 s). 2 mana. |
| Levitate | TOGGLE | Hovers 5 tiles (`hover_tiles`) above the ground under you and follows it; 30 tiles/s sideways. Down lowers you to the ground; you can't rise above the hover height. With no ground within 40 tiles you sink slowly. No fall damage. 4 mana/s. Tunables on the Player: `levitate_accel_time`, `levitate_follow`, `levitate_max_vertical`, `levitate_scan_tiles`, `levitate_sink`. |
| Air Step | TOGGLE (readied) | On like Fly (F, or click), but free while on. Press Jump in the air: a second jump, steering 1.8x quicker and 15% faster until you land. 8 mana per jump, once per time in the air. That landing never hurts (`air_jump_power`, `air_control_mult`, `air_speed_mult`). |
| Bound | TOGGLE (readied) | Same, but Jump in the air leaps far forward in an arc (48 tiles/s ahead, a low arc rising 4 tiles from wherever you press it; momentum kept unless you steer against it). 12 mana. Safe landing (`leap_speed`, `leap_height` in tiles). |
| Hyper Drill | TOOL beam | Tier 3 (needs the Dev Grimoire for now). 400 mining per second on every tile in a circle 5 tiles out from the center (`mining_area` 11, `mining_round`), reach 24. Right click: back walls. 30 mana/s. |
| Air Push | GUST | Cone 8 tiles long, 35 degrees each side; walls and closed doors stop it. 2 damage, push 36 tiles/s. It pushes you back 26 tiles/s: in the air, or on the ground when aimed down (a gust jump). 8 mana, 0.6 s cooldown. |
| Blink | BLINK | Up to 12 tiles toward the cursor (your middle goes there), stopping at the farthest spot you fit; nothing happens if there's no room. 15 mana, 1 s cooldown. |
| Light Orb | LIGHT | A warm light (radius 10) floating by your head for 3 minutes, fading at the end. Not concentration, so it works while you fly. 10 mana. |
| Wisp | LIGHT (placed) | Hold to steer a cool light with the cursor (within 24 tiles of you), let go to leave it there. Radius 9, 5 minutes, up to 3 at once (the oldest goes). 12 mana, 0.5 s cooldown. |
| Gel Cushion | BUFF | The next fall that would hurt does no damage, then the buff is gone ("*squish*" and a green splat at your feet). Otherwise it lasts 2 minutes. 10 mana + **5 Slime** per cast. Scroll: Blank Scroll + 20 Slime. A sound hook fires when it saves you (`EventBus.sound_requested`, id `gel_cushion_used`). |
| Arcane Bolt | CHARGED | Up to 1.5 s: a tap does 6 damage for 4 mana, a full charge 30 for 15, and the bolt grows. 45 tiles/s, 26 tiles. |
| Healing Circle | ZONE | 5 tile radius at the cursor, 10 s, heals 4/s (times spell power) while you're inside. 25 mana, 2 s cooldown. One at a time (`max_active` 1): casting again moves it, so circles don't stack. |
| Spark Ward | WARD | A rune for 2 minutes; the first enemy on it takes 20 and knockback 20. Up to 3. 15 mana. |
| Familiar | SUMMON | Follows you for 60 s, shoots the nearest enemy within 15 tiles every second for 5. One at a time. 30 mana. |
| Summon Forest Spirit | SUMMON | A Forest Spirit fights for you for 90 s: charges 1 s (`summon_charge`), then shoots the nearest enemy within 20 tiles for 15, every 2.2 s. Drawn from `summon_texture`. 45 mana. Learned at the table with a Forest Spirit Core, or straight from its rarer Spell Page (crafting.md). Summons are yours: they never drop loot. |
| Summon Slime | SUMMON (melee) | A slime fights beside you for 90 s, going straight for enemies (aimed hops, sliding into them up close) and hitting on contact for 8. Evolve (Empower) grows it into a Blue Slime. 35 mana. Learned with a Slime Core, or its Spell Page (combat.md). |
| Conjure Platform | CONJURE | 6 tiles wide at the cursor for 30 s. 10 mana. |
| Arcane Edge | BUFF | Melee damage x1.5 for 60 s. 20 mana. |
| Barrier | BUFF (reactive) | Waits up to 5 minutes. When a hit would leave you under 25% health it pops: a shield soaks the next 30 damage for 10 s (a bubble, "blocked" when it soaks a whole hit). 30 mana. |
| Chain Spark | CHAIN | Lightning toward the cursor, up to 12 tiles: 10 damage to the first thing it touches, then up to 3 jumps of 6 tiles, 20% weaker each. A miss still costs the 12 mana. Hold the button to keep casting (every 0.6 s cooldown). |
| Recall | RITUAL | 3 s standing still, then home (your bed, else the world spawn). 40 mana at the end. |
| Seek Ore | SENSE | Copper ore within 30 tiles glows through everything for 15 s. 15 mana. |
| Mend | TOGGLE | Heals 3 health per second (times spell power) while on. 6 mana/s. |
| Tele Grab | GRAB | Hold: portal up to 25 tiles away, pulls loose items within 3 tiles of it (18 tiles/s) to your hand. 3 mana/s. Learned at the Spell Weaving Table; name is temporary. Sticks, rocks and other forageables in its pull come loose and fly in too. |

Damageable things are nodes in the `damageable` group with `hit_rect()` and
`take_damage(amount, from)`; enemies will use the same.

- **Any spell you know can be cast**, from a quick slot (below), R / Ctrl + R, or a tome.
  The equipped book powers every spell (`spell_power`) and limits the tier you can cast
  (`max_spell_tier`). Spells don't go in the book any more, and not on the hotbar.
- **Spells you know** are kept on the character. A new character knows none. You learn
  them in the **Spells** tab of a Spell Weaving Table (crafting.md), for each spell's
  `learn_cost`: copper bars by tier (4, 10, 20), or 20 Slime for Gel Cushion; or from a
  found **Spell Page** (left click it), the only way for spells that aren't
  `learnable_at_table`.
- **Scrolls are one use.** Hold one:
  - **Left click: cast the spell once, free:** no mana, reagents, book or tier
    needed; it does share the spell's cooldown with casting it normally (a tier 3 spell works before you have a tier 3 book). Concentration spells
    run free for 60 s (`Player.scroll_concentration_seconds`) and held beams can be used
    for 15 s (`scroll_beam_seconds`), both shown as a buff that ends the spell (a beam
    you don't know is put away). A charged bolt fires at full charge; a ritual still
    needs you to stand still. If the spell can't go off (no room, no target), the
    scroll isn't used. A scroll item's `scroll_seconds` overrides the time.
  - The tooltip and a hint by the cursor spell both out. Console `devkit` teaches them all; `quick <slot> <spell>` puts one
  in a quick slot (q1..q8, e1..e8, z, x, c, buff1..buff6). How you learn spells in the real game
  comes later.
- **The spellbook is part of the character**, not a hotbar item: the **Book** slot in
  the Equipment window. Empty = the Basic Spellbook (x1 power, tier 1). A book's tooltip:
  its name with "Tier N" on the right, then "Spell power xN", then its modifiers (the
  book's `stats`, like "+10% Magic damage"), then its description. Other books have
  more `spell_power` and a higher `max_spell_tier`. (`spell_slots` on books is unused now.)
- **Quick spells** (Equipment window, P, "Quick spells"): click a spell in the Spell
  Index (L), then a slot. Click a filled slot to pick its spell up; right click empties it.
  - **Q and E wheels**, 8 slots each. Hold Q (or E): the wheel opens; move toward a spell
    and let go: that spell becomes the tap spell (a cast-right-away one isn't cast by
    the pick). Tap Q: the last spell picked on that wheel again (or its first). The
    small panel beside the hotbar shows what Q and E would pick, and Z, X, C, with each
    key's letter above its square. Hover a square for the spell's full tooltip (or the
    item's) and what the key does.
  - **Z, X, C**: one spell each, **or a shortcut to any item**: click the slot with an
    item on the mouse (the stack stays on the mouse; right click clears). Food and
    potions are used right away; anything else (a block, a station, a tool) goes in your
    hand like picking its hotbar slot, from the backpack too (`CharacterData.quick_item`,
    saved as `item:<id>`). The square shows how many you have (faded at none).
  - **Movement slot** (under the buff set): the spell F turns on (no double jump; it was removed in Phase 11).
    Click a movement toggle (Fly, Levitate: `SpellData.fits_movement_slot`) from the
    Spell Index, then the slot. Empty shows the default faded (Fly, else Levitate);
    right click goes back to it (`CharacterData.movement_spell`).
  - **Holding** keeps casting: the mouse button with a spell in hand, or a quick key
    (Z, X, C...) set to cast, as fast as the spell's cooldown and your mana allow. Q and E
    open the wheel when held, so those cast on a tap.
  - **Cast or in hand:** each wheel slot and Z X C either **casts right away** (aimed at
    the cursor, then you're back to what you held; a toggle spell just toggles) or **puts
    the spell in your hand** (left click casts, like a tool). A small gold bolt in the
    slot's top right corner means "casts right away"; click that corner to flip it. The
    default comes from the spell (`SpellData.quick_default`; by cast: bolts, beams, charged
    and chain spells and steered lights go in hand, everything else casts).
  - **Buff set (B)**, 6 slots, only timed effects on you (buffs, Light Orb, Familiar). B
    casts them all at once, in order, without the casting animation. One that's already
    on is skipped; one that can't go off (mana, cooldown, reagents) is skipped and named.
  - The same spell can be on both wheels and a key; within one wheel (or Z X C, or the
    buff set) putting it in a new slot moves it.
  - Saved with the character (`quick`, `quick_modes`, `wheel_last`). Older characters:
    the book's spells went on the Q wheel and hotbar spell shortcuts on the E wheel.
- **Casting from your hand:** left click casts on the front layer, right click on the
  back layer (mining and chopping spells). Picking a hotbar slot puts the spell away.
- **Timers:** buffs, and your Familiar, Light Orb and Wisps while they're out, show in
  the row above the health panel with the time left (Wisps also show how many are out,
  like 2/3). Hover for details. **Right click** one to end it now (summons and lights
  vanish); potion sickness and auras like Cozy can't be ended (`Hud.dismiss_buff`).
- **Spell Index (L):** tabs (All, Tools, Movement, Attack, Defense, Light: the spell's
  `group`) and a search box (click it and type; Enter or Esc stops). Each row says which
  quick slots hold the spell. Spell tooltips: name, description, mana, then what else
  it needs (reagents, a conduit, a book tier) and its cooldown.
- **Conduit** slot: the focus your casting hand uses. `spell_power` and
  `spell_reach_bonus` boost every spell; `conduit_type` unlocks spells that require it.
  Swap conduits by dragging them in and out of the slot. A spell that needs a conduit
  you don't have shows the reason by the cursor and in its tooltip.
- **Tomes:** a hotbar item that casts one spell (`tome_spell`) without needing to know
  it (a conduit requirement still applies). Strength uses the tome's
  `spell_power` instead of the book's.
- **Building reaches as far as you mine:** placing blocks, walls and seeds uses the
  Mining Spell's reach (8, plus its Empower Reach ranks and the conduit's reach bonus)
  and the shared area setting. An item's own `place_reach_tiles` still wins when set;
  the book's `build_reach_tiles` is only the fallback if the Mining Spell is missing.
- **Strength:** damage = spell's `mining_damage` x book (or tome) `spell_power` x
  conduit `spell_power`. Reach = spell's `reach_tiles` + conduit `spell_reach_bonus`.
- **Mana:** 100, refills after a short pause. See [crafting.md](crafting.md).

Debug builds add test magic (runtime only, never saved, not real content) in the third
inventory row: **Dev Grimoire** (x1.5, tier 3), **Dev Focus** (a "focus" conduit,
x1.25, +4 reach), **Dev Tome**, and the spell **Dev Wide Beam** (tier 2, wider, needs the
focus). Try: put Dev Wide Beam on a wheel, see it red, equip the Dev Grimoire and the Dev
Focus, cast it. The dev kit fills both wheels, Z X C and the buff set to try things with.

## Starting state, dev kit and the character file

A character is saved separately from worlds: `user://characters/<name>.gpchar` (name,
look, inventory, equipment, spells). You pick or make one on the main menu's character
page (see [guide.md](guide.md#starting-the-game-menu-worlds-saves)); any character can
play any world. A new character starts with the **Mining Spell**, **Chopping Spell** and **Shaping Spell**
(tools are spells: R, Ctrl + R and Alt + R take them in hand) and a **Copper Dagger**, nothing
else (`CharacterData.STARTING_SPELLS`, `STARTING_ITEMS`). Characters from before Phase
24 learn both spells when loaded; their old pickaxes and axes are gone.

### Where the spellbook is (Phase 30)

The equipped spellbook rests on your **hip**, behind the arms so the hand hangs in front of it (`PaperDoll._book_hip`, `book_hip_offset` (0, 20),
`book_hip_angle`) whenever it isn't in use. Each spell says where it goes while you cast
it (SpellData `book_pose`):

| Pose | Looks like | Spells |
| --- | --- | --- |
| HAND (default) | in the back hand, the front hand aims (item type `spell`) | most: Spark, Air Push, Mining, Chopping, summons... |
| FLOAT | hovers open in front of the chest, both hands push (`spell_float`; `book_float_distance`, `book_float_bob`) | Chain Spark, Arcane Bolt, Hyper Drill |
| HIP | stays on the hip and glows, the front hand gestures (`spell_hip`) | Arcane Edge, Barrier, Gel Cushion, Healing Circle, Mend, Levitate, Fly, Air Step, Bound, Seek Ore |

A **quick cast** of a HAND spell (Z, X, C or a wheel) with a weapon out keeps the
weapon in your front hand (`PaperDoll.offhand`, `offhand_angle`) and the book comes out
in the back hand, thrust at the cursor (`spell_offhand`), then goes back to the hip.
The weapon still counts as in hand (school amp). Change a spell's pose in its `.tres`
(`book_pose`: 0 HAND, 1 FLOAT, 2 HIP) or in `BOOK_POSES` (tools/make_items.gd).

### Phantom tools

The gathering spells conjure a pickaxe or axe of light (`PhantomTool`,
src/items/phantom_tool.gd, driven by `ItemUser`). Every swing it comes into being,
strikes the middle of the target fast and fades; the next swing conjures it again. The
mining or chopping lands at the strike (`phantom_impact`, 0.8 of the swing), with a
flash, sparks and a sound (`phantom_mine` / `phantom_chop`). One swing takes
`phantom_swing_time` (0.3 s). It glows in its rank's color (`phantom_tints` by
`gather_rank`: spirit blue, copper, iron).

While a gathering spell is in your hand, its tool **hovers beside you** like a summon
(behind your shoulder, bobbing). When you mine it's pulled from there into the swing
(`pull_time` 0.16 s), every style and test variant swinging as before, and when you
stop it drifts back. Tunables on PhantomTool: `hover_offset`, `hover_bob`,
`hover_follow`, `pull_time`, `hover_alpha`.

While you hold a gathering spell, the blocks it will mine light up like Starbound's
mining cursor: each one glows blue (no outline), and the cursor is a real light
(`light_radius` 3 tiles, `light_color`), so the blocks show up in the dark. A tree's
trunk glows the same way; where it can't work, a faint red fill.

Styles (SpellData `phantom_style`; try them with console `phantom arc|echo|comet`).
Debug builds' dev kit also has test spells to compare with Mining, which stays as it
is: **Mining v2** (quick arc, 0.2 s), **v3** (heavy arc: big, slow, 0.5 s), **v4**
(echo), **v5** (rapid echo, 0.18 s), **v6** (comet), **v7** (slow comet from higher
up), **v8** (flick: a big wind up, a very fast snap), and Chopping (echo) and (comet)
(`DevMagic.STYLE_SPELLS`). They mine at the same rate per second; only the swing
differs. A spell can change PhantomTool's tunables for itself: SpellData
`phantom_tuning` (e.g. `{size_mult: 1.9, wind_up: 2.8}`).

| Style | What it does |
| --- | --- |
| Arc (0, default) | Appears raised beside the target, a fast arc down, a glowing crescent streak behind the point |
| Echo (1) | The same arc, leaving fading copies of itself behind |
| Comet (2) | Appears high above the target, spins once as it drops onto it, a comet tail |

The tool is drawn solid; its streak, glow, box and flash are additive light above the
lighting (z 56), so they light up the dark. Where it strikes: SpellData `phantom_grip`
and `phantom_tip` (fractions of the art: the pick's point, the axe's edge); the strike
puts the tip exactly on the middle of the target. Tunables on PhantomTool: `size_mult`
(1.5), `wind_up`, `appear` and `strike_from` (parts of the swing), `comet_height`,
`tool_alpha`, `glow_alpha`, `streak_alpha`, `box_fill_alpha`, `box_pulse_speed`. Art: `phantom_texture` (placeholders `assets/fx/phantom_pickaxe.png`,
`phantom_axe.png`).

Console `devkit` gives the dev kit: a copper and wooden sword, 99 wood, 30 platforms, 30 rope, 20 torches, 5 saplings, 10 grass seeds,
50 dirt, and teaches every spell, with Mining and Chopping fully empowered. It's
`DEV_KIT` / `DEV_SPELLS` in `src/items/character_data.gd`. Scripted runs (DevCli) start
with it. In debug builds it also adds the placeholder weapons and test magic, which
are never saved.

The character saves with the world (autosave, Save, Save & Quit). A character from
before character select is called "default" and shows up in the list like any other.

## Ground kinds, biome blocks and bricks (Phase 21)

Tiles say what natural ground they act as (`TileDef.kind`: `grass`, `dirt` or `stone`),
so biome versions behave like the plain ones: grass spreads onto any dirt and turns it
into that dirt's own grass (`grows_to`; Dark Forest Dirt grows Dark Forest Grass),
grass covered by a block goes back to its dirt (`bare_to`), trees and bushes root in
any grass, sticks and rocks lie on any of them, and Grass Seeds plant on any dirt.
`TileDef.biome` marks the blocks a biome is counted from (world-generation.md).

| Block | Item | Wall | Notes |
| --- | --- | --- | --- |
| Dark Forest Dirt | Dark Forest Dirt | Dark Forest Dirt Wall | 40 health, like dirt. |
| Dark Forest Grass | (drops Dark Forest Dirt) | | Blue-black grass (`dark_grass`). |
| Dark Forest Stone | Dark Forest Stone | Dark Forest Stone Wall | 80 health, like stone. |
| Stone Bricks | Stone Bricks | Stone Bricks Wall | 2 Stone at a Furnace. Built (crisp edges), 90 health. |
| Dark Forest Stone Bricks | Dark Forest Stone Bricks | Dark Forest Stone Bricks Wall | 2 Dark Forest Stone at a Furnace. |

Right click places the wall, as with dirt and stone. Brick art: placeholders from
`python3 tools/make_brick_art.py` (built from each stone's colors; `--force` remakes).

## Moving lights

Moving lights (Light Orb, Wisps, a Forest Spirit) sit between tiles: their light is
shared over the nearest four (`LightJob._sources`), they ask for a relight every
quarter tile, and each new light map fades in over the last one
(`LightMap.fade_seconds`, 0.14 s; `src/world/light_map.gdshader`), so they glide instead
of jumping a tile at a time.

## Mining

- Blocks have health (`health` in `data/tiles/*.tres` and `data/walls/*.tres`): dirt
  and grass 40, stone 80, copper ore 110, iron ore 160, planks and logs 50, platforms
  20, rope 15, background walls 30. Mining I breaks dirt in 1 swing and stone in 2 (per tile).
- **Mining power** (like Terraria's pickaxe power): a block's `min_mining_power` is the
  `mining_power` the Mining Spell (or another mining item) needs to mine it at all;
  below that the box goes red with "Too hard". A strong enough but weaker spell just
  takes longer (its `mining_damage`). Iron ore needs 35. Mining Spell 30, 40 with Power
  1 (copper bars), 50 with Power 2 (iron bars); Hyper Drill 55.
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
Drops never start buried: one made inside solid ground (a tree felled into a hillside,
loot against a wall) moves straight up onto the first open tile (`World.out_of_ground`),
and a resting drop with a block placed on it comes up onto the block.

## Trees, saplings, flowers, grass (`Plants` node, `src/world/plant_layer.gd`)

Sticks and rocks lying around are the `Forage` node (crafting.md).

- Natural trees and flowers come from the generator's decoration rules the first time a
  chunk loads. After that they're the world's: chopped trees stay chopped.
- **Trees:** `tree_health` (100). Each axe hit rocks the tree (`wiggle_degrees`); at 0
  it falls away from you over `fall_time` and breaks into Logs along its trunk (one per
  `tiles_per_log`, 6, tiles of height: 2 to 4) and 1 seed (`extra_seed_chance` of a second). Removing the grass under a tree breaks
  it on the spot.
- **Darkwood trees** (the Dark Forest, tree variants after the 12 pines) drop **Darkwood
  Logs** (`dark_log`) instead, more of them (they're 22 to 35 tiles tall). They build
  a Darkwood Log block and back wall like Logs do. 1 Darkwood Log = 4
  **Darkwood** by hand; Darkwood places Darkwood Planks (block, 70 health) and, with
  right click, a Darkwood Wall. They also drop **Darkwood Saplings** (plant like a pine
  Sapling; it grows a darkwood tree anywhere). Saplings (`tree_seed`) grow pines. Saved as the
  sapling's variant (0 pine, 1 darkwood).
- **Saplings:** plant a sapling on grass with `tree_spacing` (3) tiles to the next
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



## Block shapes (Shaping Spell)

Every tile has a shape byte (`ChunkData.shapes`, saved with the world under "shapes"):

| Bits | Meaning |
| --- | --- |
| 0 to 2 | Block shape: 0 full, 1 bottom half, 2 top half, 3 to 6 slopes solid toward bottom-left, bottom-right, top-left, top-right |
| 3 | Log turned (flips the automatic upright look of a single column) |
| 4 to 5 | Wall shape: 0 full, 1 bottom half, 2 top half |
| 6 | Log wall turned (flips its upright/sideways look, like bit 3 for log blocks) |

Breaking or replacing a block keeps the wall's shape and clears the block's, and the
other way around. The terrain shader cuts the shape out (the wall shows through) and draws
a dark rim along the cut on built blocks. Collision uses TileSet alternatives 1 to 6
(`ChunkRenderer.SHAPE_POLYGONS`). Dev console: `shapes` builds every shape to your right.

## Voxels (Phase 52, the experiment)

A finer grid on top of the tiles: **4x4 cells a tile** (each 2x2 world pixels), only in
tiles whose block is air (`VoxelLayer`, src/world/voxel_layer.gd). Materials are data
(`data/voxels/*.tres`, `VoxelMaterial`):

| Material | Behavior | Notes |
| --- | --- | --- |
| Sand | POWDER | Falls, piles at 45 degrees, sinks through water. One Sand item a cell. |
| Water | LIQUID | Falls, and slides sideways toward any drop within `water_spread` (32) cells, so it levels out and then settles (a level pool costs nothing). No collision. You swim in it (survival.md). Siphon Liquid carries it. |
| Sand Bricks | STATIC | Never moves. Only explosions turn a Sand Bricks block into cells. One Sand Bricks item a cell, like sand. |

- **Sand falls:** a sand block (`TileDef.voxel`) with nothing whole under it (a solid
  unshaped block, or a tile full of solid cells) turns into 16 sand cells. A block that
  is held up stays a block (placed walls of sand on the ground don't slump).
  `solidify_piles` (off) would turn resting full tiles back into blocks; off because the
  terrain shader rounds their edges inside a loose pile.
- **Mining** a tile of cells takes all its solid cells at once (water stays). Sand gives
  one Sand per cell, a bitten Sand Bricks tile one brick per cell left (`cells_per_item` 1).
- **Placing:** Sand costs `place_units` 16 a tile, but a tile partly full of loose sand
  only takes the missing grains (they become the block). Sand Bricks work the same way
  (16 a tile, a bitten tile takes only the missing bricks). Other cells in the way: other solid
  cells are lost, water is pushed into the tile above.
- **Drawn over you:** the voxel layer (and the sea plants) sit at `VoxelLayer.Z` 3, over
  the player, enemies and drops, so whatever is in the water is seen through it.
- **Building against loose sand:** a tile of sand cells (or a bitten brick) counts as
  something to place against, and a part-full tile can be topped up.
- **Collision:** solid cells have 2x2 px collision (a hidden TileMapLayer), so you walk
  on piles; water has none. Thrown items stop on solid cells.
- **Explosions** (the Bomb, `boom`): sand and Sand Bricks tiles near the blast become
  cells and every solid cell inside the radius is destroyed; tiles the blast only
  grazed go back to whole blocks.
- **Simulation:** host only, only around changes (`_active` tiles), `ticks_per_second` 30,
  `fall_cells` 2 a step, `sand_sink_chance` 0.35, `sleep_steps` 30. Whole tiles of falling
  cells shift at once and full tiles boxed in by full tiles or rock are skipped, so a 200 block sand drop costs
  about 2 ms a step.
- **Look:** cells are painted into 16x16 tile pictures at the terrain's detail. Grains
  carry a patch of the sand texture (picked by their shade), bricks show the texture
  where they are, water is see-through with a lighter surface. `cell_shade` (0.84)
  matches loose cells to the blocks the shader draws.
- **Saving:** world meta "voxels" (material ids plus 16 bytes a tile).
- Dev console: `water <w> <h>`, `boom [radius]`, `voxels`, and `fill sand <w> <h>` to drop sand.

## Siphon Liquid (Phase 54)

`SpellData.siphons`: hold left click to draw water from the targeted tiles (its area grows
with Empower Area, its reach with Empower Reach) into the spell's reservoir
(`CharacterData.water`, saved), `siphon_rate` 32 cells a second, up to `liquid_capacity`
256 (16 tiles). Right click pours it into the empty cells there. Aimed at a Liquid
Barrel, it draws from or pours into the barrel. A message shows "Water 120 / 256" while
you siphon. Crafting uses its water for water bottles. `ItemUser.Mode.SIPHON`.
