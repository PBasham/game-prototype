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
| `defense` | 0 | Half of it is subtracted from each hit (minimum 1 damage). |
| `contact_damage` | 6 | Damage when it touches the player. |
| `knockback` | 10 | How hard it shoves the player on contact. |
| `knockback_resist` | 0 | 0 = full knockback from hits, 1 = none. |
| `hop_speed` | 9 | Horizontal speed of a hop, tiles/s. |
| `hop_tiles` | 5 | Hop height in tiles. |
| `hop_wait_min`, `hop_wait_max` | 0.8, 2.2 | Seconds resting between hops (random in range). |
| `aggro_tiles` | 30 | Hops toward the player inside this range; wanders randomly outside it. Once hit, it chases regardless. |
| `gravity` | 110 | Tiles/s². |
| `loot` | | `LootDrop` list: `item`, `min_count`, `max_count`, `chance` (0 to 1). |

A hurt enemy shows a small health bar. On death it pops ("*pop*") and rolls its loot
into item drops.

### Green Slime

20 health, 6 contact damage, hops about 5 tiles. Drops 1 to 2 **Slime**. The common one.

### Blue Slime

The rare one (about 1 in 9 forest spawns), and only after a Green Slime has been slain
in this world. 35 health, 1 defense, 9 contact damage,
hops about 7 tiles and more often (waits 0.6 to 1.8 s). Drops 2 to 4 **Slime**. Same
sheet as the Green Slime, tinted blue.

## Spawning

Chance based, like Terraria: there's a small chance every frame, so on average one
enemy arrives every `day_seconds` (or `night_seconds`), but the gaps are random and
enemies pile up if you leave them alone, up to the cap. Killing them makes room.

### Spawn tables: `data/spawns/<id>.tres` (`SpawnTable`, `src/combat/spawn_table.gd`)

One table per biome and layer. Only `forest_surface` exists so far.

| Field | forest_surface | |
|---|---|---|
| `biome`, `layer` | forest, SURFACE | Where it applies. |
| `max_depth_tiles` | 20 | SURFACE: the player and each spawn spot must be no deeper than this below the world's natural surface. Deeper, nothing spawns (no underground tables yet). |
| `day_seconds` / `night_seconds` | 12 / 6 | Average seconds between spawns. Lower = more often. |
| `max_day` / `max_night` | 4 / 7 | Most enemies around the player before spawning stops. |
| `entries` | | `SpawnEntry` list: `enemy`, `weight`, `day`, `night`, `conditions`. |

**Which enemy:** each entry's chance is its weight divided by the total weight of the
entries allowed right now (right time of day, every condition met). Before the first
Green Slime kill, Blue is locked, so every spawn is Green. Forest: Green Slime 100, Blue Slime 12, so
Blue is 12 / 112, about 11%. A rarer enemy is just a smaller weight; a night-only enemy
has `day` off. Later biomes and layers (underground, caves) get their own tables, with
their own rates and caps.

### Spawn conditions (`SpawnCondition`, `src/combat/spawn_condition.gd`)

An entry's `conditions` must all be met for it to spawn. Add one in the Inspector on a
spawn entry. Kinds so far:

| Condition | Fields | Met when |
|---|---|---|
| `KillCountCondition` | `enemy` (id), `count` | at least `count` of that enemy have been slain in this world |

Forest: Blue Slime needs 1 Green Slime slain. New kinds (time, rain, depth, a boss
beaten) are a small script each, extending `SpawnCondition` with `met(world)` and
`describe(world)`.

**Kills** are counted per world (`World.kills`, saved with it), by anyone, including
`butcher`. Enemies that despawn don't count.

### Despawning

Enemies more than `despawn_tiles` (90) away from you, sideways or up and down, are
removed without loot and don't count as kills. That's about two and a half screens.

### The spawner (`EnemySpawner`, child of World, `src/combat/enemy_spawner.gd`)

| Export | Default | |
|---|---|---|
| `rate_scale` | 1 | Multiplies every table's rate (2 = twice as often). |
| `catch_up` | on | Spawn faster when few enemies are around: below 20% of the cap the average wait is x0.6, below 40% x0.7, below 60% x0.8 (Terraria's numbers). |
| `min_distance_tiles` / `max_distance_tiles` | 44 / 60 tiles | Spawns off screen, on ground with room for the enemy. |
| `despawn_tiles` | 90 tiles | Enemies farther than this vanish (no loot). |
| `peaceful` | false | No spawns. |

Never spawns indoors (a tile with a built back wall behind it). Enemies you `summon`
count toward the cap.

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

## Spells against enemies

Spark (projectile) and Air Push (gust: shoves everything in a cone, light damage) hit
enemies through the same `damageable` group. See items-and-mining.md, Magic.

## Taking damage

- Enemy hits: `max(1, damage - defense * 0.5)`, then knockback away from the enemy.
- `hurt_cooldown` 0.66 s on the Player: invulnerable after a hit.
- Death by an enemy: "You were slain." (same magic bag rules as survival.md).

## Equipment

Its own window: press **P** or the **Equip (P)** button in the inventory. It opens in
the middle of the screen, can be dragged by its title bar, and keeps its spot until you
quit. Your character is in the middle (wearing your armor), armor on the left
(Head, Chest, Legs), trinkets on the right (three Accessory slots), Book and Conduit
underneath, stats on the far right. Below that, **Equipped spells** (fold it away by
clicking its header) and the **Spell Index (L)** button (see items-and-mining.md). Empty slots show a dim label. Ctrl + right click an inventory item
equips it (accessories go to the first empty accessory slot); click with an item on the
mouse to put it in a slot. Armor is drawn on the character
(placeholder copper overlays, see character-art.md); accessories aren't drawn.

Armor and accessories use the Equipment group on `ItemData`:

| Field | |
|---|---|
| `equip_slot` | `head`, `chest` or `legs` (armor only). |
| `defense` | Added to the player's defense. |
| `stats` | Dictionary of bonuses (see below). |
| `wear` | How it looks on the character: overlay textures by doll part name (see character-art.md). |
| `hides_hair` | A helmet that hides the hair. |

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

The equipment window lists Defense and every non-zero stat.

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

- `summon <enemy> [n]`: spawn at the cursor (`summon green_slime 3`, `summon blue_slime`).
- `peaceful`: toggle natural spawning (summon still works).
- `butcher`: kill every enemy; they drop their loot.
- `spawns`: the spawn table here (or that nothing spawns here), how many enemies are
  around against the cap, the current chance per second, each enemy's share, and why a
  locked one is locked.
- `kills`: enemies slain in this world.
- `equip <item>`: equips into any slot (armor, accessories, book, conduit).
