# Combat, enemies, equipment and beds (Phase 7)

**Status: built but not playtested yet.** Numbers below are first guesses.

## Enemies: `data/enemies/<id>.tres` (`EnemyData`, `src/combat/enemy_data.gd`)

An enemy is a `CharacterBody2D` (`src/combat/enemy.gd`) built from its data. It joins the
`damageable` and `enemies` groups, so swords and spells hit it the same way they hit the
training dummy.

| Field | Default | What it does |
|---|---|---|
| `ai` | `SLIME` | Behavior. Only the slime hop exists so far. |
| `texture`, `frame_size` | slime.png, 36x27 | Sheet with 3 frames: resting, squashed, in the air. Drawn pale; `tint` colors it. |
| `tint` | | Color applied to the sheet (green slime: pale green). |
| `size` | 30x20 px | Collision box. |
| `max_health` | 20 | |
| `defense` | 0 | Subtracted from each hit (minimum 1 damage). |
| `contact_damage` | 6 | Damage when it touches the player. |
| `knockback` | 10 | How hard it shoves the player on contact. |
| `knockback_resist` | 0 | 0 = full knockback from hits, 1 = none. |
| `hop_speed` | 9 | Horizontal speed of a hop, tiles/s. |
| `hop_tiles` | 5 | Hop height in tiles. |
| `hop_wait_min`, `hop_wait_max` | 0.8, 2.2 | Seconds resting between hops (random in range). |
| `aggro_tiles` | 30 | Hops toward the player inside this range; wanders randomly outside it. Once hit, it chases regardless. |
| `gravity` | 110 | Tiles/s². |
| `loot` | | `LootDrop` list: `item`, `min_count`, `max_count`, `chance` (0 to 1). |
| `day_weight`, `night_weight` | 1, 1 | Spawn weight by time of day (0 = never). |

A hurt enemy shows a small health bar. On death it pops ("*pop*") and rolls its loot
into item drops.

### Green Slime

20 health, 6 contact damage, hops about 5 tiles. Drops 1 to 2 **Slime**.

## Spawning (`EnemySpawner`, child of World, `src/combat/enemy_spawner.gd`)

| Export | Default | |
|---|---|---|
| `interval` | 3 s | Time between spawn attempts. |
| `max_day` / `max_night` | 2 / 5 | Cap on enemies alive near the player. |
| `min_distance_tiles` / `max_distance_tiles` | 44 / 60 tiles | Spawns off screen, on surface ground with room for the enemy. |
| `despawn_tiles` | 90 tiles | Enemies further than this vanish. |
| `peaceful` | false | No spawns. |

Never spawns indoors (a tile with a built back wall behind it). Picks an enemy weighted
by `day_weight` / `night_weight`.

## Melee

Weapons are items with `melee_damage > 0` (`ItemData`, Weapon group):

| Field | | |
|---|---|---|
| `melee_damage` | | Damage per swing. |
| `melee_reach` | 4.5 tiles | How far in front the hit box reaches. |
| `knockback` | 12 | Push on the enemy (reduced by its `knockback_resist`). |

The hit lands on the swing's impact frame. The hit box is in front of the player, on the
cursor's side, `melee_reach` tiles wide and 9 tiles tall around the chest. Every enemy
in it is hit once per swing.

| Item | Damage | Reach | Recipe |
|---|---|---|---|
| Wooden Sword | 8 | 4 | Workbench: 10 planks |
| Copper Sword | 13 | 4.5 | Anvil: 8 copper bars, 2 planks |

## Taking damage

- Enemy hits: `max(1, damage - defense * 0.5)`, then knockback away from the enemy.
- `hurt_cooldown` 0.66 s on the Player: invulnerable after a hit.
- Death by an enemy: "You were slain." (same magic bag rules as survival.md).

## Equipment

The inventory's right column: Head, Chest, Legs, three Accessory slots, plus the
existing Book and Conduit. Empty slots show a dim label. Shift-click equips (accessories
go to the first empty accessory slot). Items don't show on the character yet; only the
stats change.

Armor and accessories use the Equipment group on `ItemData`:

| Field | |
|---|---|
| `equip_slot` | `head`, `chest` or `legs` (armor only). |
| `defense` | Added to the player's defense. |
| `stats` | Dictionary of bonuses (see below). |

Stats (`CharacterData.STATS`), all summed across equipment:

| Stat | Effect |
|---|---|
| `max_health` | Flat bonus. |
| `max_mana` | Flat bonus. |
| `mana_regen` | Flat bonus per second. |
| `move_speed` | 0.2 = 20% faster. |
| `jump` | 0.15 = 15% higher. |
| `mining_speed` | Multiplies mining damage. |
| `magic_damage` | Multiplies spell power. |

The panel next to the spellbook lists Defense and every non-zero stat.

| Item | Slot | Defense | Recipe (Anvil) |
|---|---|---|---|
| Copper Helmet | head | 1 | 10 copper bars |
| Copper Chestplate | chest | 2 | 16 copper bars |
| Copper Greaves | legs | 1 | 12 copper bars |
| Dev Ring (dev only) | accessory | 2 | +20 health, +20% speed, +15% jump, +25% magic damage |

## Beds

Bed: furniture, 9x3 tiles, needs a floor. Workbench, 20 planks.

- Right click by day: sets your spawn point ("Spawn point set. You can only sleep at
  night.").
- Right click at night: sets the spawn point and sleeps. The screen fades, the clock
  jumps to an hour after sunrise, plants grow for the skipped time and hunger drains
  for it (at least 1).
- Can't sleep with an enemy within `sleep_enemy_tiles` (World export, 20 tiles).
- The spawn point is saved per character per world. If the bed is gone when you
  respawn, you go to the world spawn ("Your bed is gone").

## Slime uses

- Hand recipe: 1 Slime + 1 Stick = 5 Torches.

## Dev console

- `summon <enemy> [n]`: spawn at the cursor (`summon green_slime 3`).
- `peaceful`: toggle spawning.
- `butcher`: kill every enemy.
- `equip <item>`: equips into any slot (armor, accessories, book, conduit).
