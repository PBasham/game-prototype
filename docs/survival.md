# Health, hunger, food and dying

Phase 6. The bars are bottom left (health, mana, hunger). Everything here is an export
you can tweak live on the `Player`, `World` or `Plants` node.

## Health (`Player`, src/player/player.gd)

| Export | Default | What it does |
| --- | --- | --- |
| `max_health` | 100 | |
| `health_regen` | 1 | Health per second refilled... |
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
| `hunger_seconds_per_point` | 20 | Seconds per point lost (100 points = about 33 minutes) |
| `hunger_run_multiplier` | 2 | Running (Shift) makes you hungry this much faster |
| `starve_damage`, `starve_interval` | 1, 3 | At 0 hunger: no health regen, and 1 damage every 3 seconds |

Spells, Fly included, don't make you hungry. With the world's Hunger option off, the bar
stays full.

## Food and berry bushes

- **Berries** (`data/items/berries.tres`, kind FOOD): left click while holding them to
  eat one: +10 hunger (`food_value`), +2 health (`heal_value`). You can't eat while
  both are full.
- **Berry bushes** grow on the grass like flowers. Right click (or E near) a ripe one
  to pick 2 to 4 berries; it grows them back in 3 to 5 minutes. Breaking the ground
  under a ripe bush drops its berries. Exports on the `Plants` node:

| Export | Default | What it does |
| --- | --- | --- |
| `bush_share` | 0.06 | Share of flower spots that are a berry bush |
| `berries_min`, `berries_max` | 2, 4 | Berries per picking |
| `regrow_min_seconds`, `regrow_max_seconds` | 180, 300 | Time until a picked bush is ripe again |
| `bush_grown_share` | 0.7 | Share of the world's bushes that start full grown; the rest are young |
| `bush_grow_min_seconds`, `bush_grow_max_seconds` | 300, 600 | Time for a young bush to grow full size |

Young bushes are small and give half the berries; full grown bushes are bigger. Art:
`assets/decor/berry_bush.png` / `berry_bush_bare.png` (full grown, 24x19) and
`berry_bush_young.png` / `berry_bush_young_bare.png` (14x12). Later: crops, and moving
bushes with special tools (a brief first).

## Dying and the magic bag

At 0 health you die. "You died" shows for `respawn_seconds` (3, on the `World`), then
you're back at the world spawn with full health, hunger and mana.

With the world option **On death: Drop items in a magic bag** (the default), everything
in your inventory goes into a **magic bag** (`ItemBag`, src/items/item_bag.gd) that's
tossed up where you died, then falls, bounces and settles like a Terraria tombstone.
Spell shortcuts, your equipped book and conduit, and the spells you know stay with you.
Right click or E on the bag opens it like a chest (Take all, Shift + click); it vanishes
once empty. Bags are saved with the world. Bag exports: `gravity`, `bounce`,
`settle_speed`, `ground_friction`. Art: `assets/objects/magic_bag.png` (12x12).

**On death: Keep items** keeps everything in your inventory.

## World options

Chosen on the New World page and saved with the world (`WorldInfo.hunger`,
`WorldInfo.death_drop`): **Hunger** on or off, **On death** bag or keep. Older worlds get
hunger on and the bag.

## Saving

Health and hunger are saved with the character, so you come back as hungry as you
left. A character saved while dead comes back full.

## Dev console

`god` (no damage), `hurt <n>`, `kill`, `heal` (full health and hunger), `hunger <n>`,
`mana` (infinite mana), `bush` / `bush young` (a ripe berry bush on the grass under the cursor), `grow` (also
makes picked bushes ripe and young bushes full grown).
