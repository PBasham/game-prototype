# Day and night, health, hunger, food and dying

Phase 6.

## Day and night (`WorldClock`, src/world/world_clock.gd, the World's `Clock` node)

A day is 24 real minutes: daytime from 4:30 to 19:30 (15 hours), night the rest, with
an hour of dawn and dusk. A new world starts at 6:30. The time shows on the health
panel and is saved with the world. At night the sky light dims and turns blue (torches
matter), the sky and hills darken, stars come out and the moon crosses the sky; the sun
crosses it by day. Growth and hunger are set in in-game days.

| Export | Default | What it does |
| --- | --- | --- |
| `day_minutes` | 24 | Real minutes per in-game day |
| `sunrise_hour`, `sunset_hour` | 4.5, 19.5 | |
| `twilight_hours` | 1 | How long dawn and dusk take |
| `start_hour` | 6.5 | When a new world starts |
| `night_light` | 0.28 | Sky light at night (0 dark, 1 day) |
| `day_color`, `twilight_color`, `night_color` | | Tint of the sky light |
| `speed` | 1 | Multiplies how fast time passes |

Sky colors are on the Backdrop (`day_sky`, `twilight_sky`, `night_sky`).

| Timer | In-game days |
| --- | --- |
| Sapling to tree (`grow_min_days`, `grow_max_days` on Plants) | 1 to 2 |
| Young bush to full grown | 2 to 3 |
| Picked bush grows berries back | 2 to 3 |
| Full hunger bar empties (`hunger_full_days` on Player) | 1.5 | The bars are bottom left (health, mana, hunger). Everything here is an export
you can tweak live on the `Player`, `World` or `Plants` node.

## Health (`Player`, src/player/player.gd)

| Export | Default | What it does |
| --- | --- | --- |
| `max_health` | 100 | |
| `health_regen` | 0.5 | Health per second refilled... |
| `health_regen_delay` | 5 | ...once you've gone this many seconds without being hurt (and you're not starving) |
| `hurt_cooldown` | 0.4 | Seconds you can't be hurt again after a hit (starving ignores it) |
| `fall_damage_start` | 25 | Tiles you can fall without getting hurt (the Scholar is 8 tall; a full jump is 11) |
| `fall_damage_per_tile` | 5 | Damage per tile beyond that |

Damage shows as a red number over your head and a red flash. Flying (the Fly spell) and
climbing reset the fall. Falls are the only damage so far; enemies come later.

## Hunger

| Export | Default | What it does |
| --- | --- | --- |
| `max_hunger` | 100 | |
| `hunger_full_days` | 1.5 | In-game days a full bar lasts (36 real minutes) |
| `hunger_run_multiplier` | 2 | Running (Shift) makes you hungry this much faster |
| `starve_damage`, `starve_interval` | 1, 3 | At 0 hunger: no health regen, and 1 damage every 3 seconds |

Spells, Fly included, don't make you hungry. With the world's Hunger option off, the bar
stays full.

## Food and berry bushes

- **Berries** (`data/items/berries.tres`, kind FOOD): left click while holding them to
  eat one: +10 hunger (`food_value`), +2 health (`heal_value`). You can't eat while
  both are full.
- **Raspberries** (+14 hunger, +1 health) and **Blueberries** (+6 hunger, +4 health):
  the same, from raspberry and blueberry bushes. Raspberries fill you up, blueberries
  heal; each cooks into its own buff food (below).
- **Berry bushes** grow on the grass like flowers. Right click (or E near) a ripe one
  to pick 1 to 3 berries (or raspberries, or blueberries); it grows them back in 2 to 3 in-game days. Breaking the ground
  under a ripe bush drops its berries. Exports on the `Plants` node:

| Export | Default | What it does |
| --- | --- | --- |
| `bush_share` | 0.06 | Share of flower spots that are a berry bush |
| `berries_min`, `berries_max` | 1, 3 | Berries per picking |
| `regrow_min_days`, `regrow_max_days` | 2, 3 | In-game days until a picked bush is ripe again |
| `bush_grown_share` | 0.7 | Share of the world's bushes that start full grown; the rest are young |
| `bush_grow_min_days`, `bush_grow_max_days` | 2, 3 | In-game days for a young bush to grow full size |

Wild bushes are slow and stingy on purpose: farming (later) should be the better way
to get food.

Young bushes are small and have no berries; once full grown (bigger) they bear berries.

**Bush kinds** are data: `data/bushes/<id>.tres` (`BushData`, src/world/bush_data.gd).

| Field | What it does |
| --- | --- |
| `fruit` | The item a ripe bush gives |
| `weight` | How often worldgen picks this kind (Berry 2, Raspberry 1, Blueberry 1: half the wild bushes are plain berry bushes) |
| `young_texture`, `ripe_texture`, `bare_texture` | Young, full grown with fruit, full grown picked |
| `save_index` | Saved in the world with each bush; never change it (0 = the plain berry bush older worlds have) |

A bush's `variant` in the plant save is `save_index * 2 + grown`, so worlds from before
the kinds still load as plain berry bushes. Changing weights only affects new chunks.
Art: `assets/decor/<kind>_bush.png` / `_bare.png` (full grown, 24x19) and
`_young.png` (14x12); raspberry and blueberry art comes from
`art/concepts/berries/make_berries.py` (recolors of the berry bush). Later: crops, and moving
bushes with special tools (a brief first).

## Cooking, potions and buffs

Food and potions are items with these `ItemData` fields (group "Food and potions").
Left click while holding one to eat or drink it. It's refused when it would do
nothing ("You're full", "No need right now") or while its sickness is on.

| Field | What it does |
| --- | --- |
| `food_value`, `heal_value`, `mana_value` | Hunger, health and mana restored |
| `sickness`, `sickness_seconds` | A group (`healing`, `mana`): after drinking, no other item of that group for this long. Shows as a buff ("Healing Sickness"). |
| `buff_name`, `buff_description`, `buff_seconds` | A timed buff, shown on the buff bar |
| `buff_health_regen` | Extra health per second while the buff is on (adds to regen and Cozy) |
| `buff_move_speed` | Extra walk speed while the buff is on (0.1 = 10%) |
| `buff_poison_hits` | A weapon coating: the next this many melee hits poison (see combat.md) |

**Cooking** happens at the **Campfire** (right click it: station `cooking`):

| Recipe | Makes | Effect |
| --- | --- | --- |
| 3 Berries | Roasted Berries | +25 hunger, +5 health |
| 1 Field Mushroom | Cooked Mushroom | +16 hunger, +4 health |
| 4 Raspberries + 1 Wooden Bowl | Raspberry Compote | +35 hunger, +6 health, Mending 4 min (+1 health/s) |
| 4 Blueberries + 1 Wooden Bowl | Blueberry Mash | +20 hunger, +10 health, Light Step 4 min (+15% speed) |
| 2 Field Mushroom + 1 Red Cap + 1 Wooden Bowl | Mushroom Stew | +40 hunger, +8 health, Well Fed 5 min (+0.5 health/s, +10% speed) |

Wooden Bowls: 2 Wood makes 2 at the workbench. Raw berries and mushrooms still work,
cooked food is just much better.

**Potions** come from the Alchemy Table (crafting.md):

| Potion | Effect | Sickness |
| --- | --- | --- |
| Healing Potion | +30 health | 30 s (`healing`) |
| Mana Potion | +40 mana | 10 s (`mana`) |

**Glow Potion** (Clay Flask + 1 Glowcap): you glow for 4 minutes ("Glowing"), a soft
cyan light 18 tiles around you, hands free (`ItemData.buff_light_radius`,
`buff_light_color`; `Player.buff_light`). No sickness.

Bigger bottles hold stronger potions, and glass is 30% stronger than clay of the same
size; bigger ones leave you sick longer (`FILLED_BOTTLES` in `tools/make_items.gd`):

| Bottle | Healing | Mana | Sickness (healing / mana) |
| --- | --- | --- | --- |
| Clay Bottle | +45 | +60 | 40 / 13 s |
| Clay Jug | +60 | +80 | 51 / 17 s |
| Glass Vial | +40 | +50 | 30 / 10 s |
| Glass Bottle | +60 | +80 | 40 / 13 s |
| Glass Flask | +80 | +105 | 51 / 17 s |

## Dying and the magic bag

At 0 health you die. "You died" shows for `respawn_seconds` (3, on the `World`), then
you're back at your bed (or the world spawn) with full health, hunger and mana. Buffs,
potion sickness, familiars and Light Orbs end.

The world option **On death** (`WorldInfo.DeathDrop`):
- **Drop everything (armor too)** (new worlds' default, `ALL`): the inventory and the
  armor and accessories you wear. Your book and conduit stay (for now).
- **Drop the inventory** (`BAG`, older worlds): the inventory only.
- **Drop items outside the hotbar** (`BACKPACK`): the hotbar stays.
- **Keep items** (`KEEP`).
- **Permadeath** (`PERMADEATH`): drop everything, and the character becomes a **ghost**:
  kept in the character list but greyed out and not playable (`CharacterData.ghost`).
  After "You died" the game goes back to the menu.

Dropped items go into a **magic bag** (`ItemBag`, src/items/item_bag.gd) that's
tossed up where you died, then falls, bounces and settles like a Terraria tombstone.
Spell shortcuts, your equipped book and conduit, and the spells you know stay with you.
Right click or E on the bag opens it like a chest (Take all, Shift + click); it vanishes
once empty. A bag on top of furniture (a workbench, say) opens before the furniture.
Bags are saved with the world. Bag exports: `gravity`, `bounce`,
`settle_speed`, `ground_friction`. Art: `assets/objects/magic_bag.png` (12x12).

A coated weapon keeps its coating in the bag.

## World options

Chosen on the New World page and saved with the world (`WorldInfo.hunger`,
`WorldInfo.death_drop`): **Hunger** on or off, **On death** bag or keep. Older worlds get
hunger on and the bag.

## Saving

Health and hunger are saved with the character, so you come back as hungry as you
left. A character saved while dead comes back full.

## Dev console

`god` (no damage), `hurt <n>`, `kill`, `heal` (full health and hunger), `hunger <n>`,
`mana` (infinite mana), `time` (show), `time <hour>` or `time day | noon | dusk | night | dawn`, `time speed <x>`,
`bush [kind] [young]` (a ripe bush on the grass under the cursor; kind = `raspberry`,
`blueberry`, or the plain berry bush when left out), `grow` (also
makes picked bushes ripe and young bushes full grown).


## Enemies, beds and sleeping

See [combat.md](combat.md): beds set your respawn point and let you sleep through the
night; enemy hits are a new death cause ("You were slain.").
