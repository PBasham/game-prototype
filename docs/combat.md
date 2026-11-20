# Combat, enemies, equipment and beds (Phase 7)

**Status: built but not playtested yet.** Numbers below are first guesses.

## Enemies: `data/enemies/<id>.tres` (`EnemyData`, `src/combat/enemy_data.gd`)

An enemy is a `CharacterBody2D` (`src/combat/enemy.gd`) built from its data. It joins the
`damageable` and `enemies` groups, so swords and spells hit it the same way they hit the
training dummy.

| Field | Default | What it does |
|---|---|---|
| `ai` | `SLIME` | Behavior. Only the slime exists so far (see "How slimes move" below). |
| `texture`, `frame_size` | slime.png, 36x27 | Sheet with 3 frames: resting, squashed, in the air. Drawn pale; `tint` colors it. |
| `tint` | | Color applied to the sheet (green slime: pale green). |
| `size` | 30x20 px | Collision box. |
| `max_health` | 20 | |
| `defense` | 0 | Half of it is subtracted from each hit (minimum 1 damage). |
| `contact_damage` | 6 | Damage when it touches the player. |
| `knockback` | 10 | How hard it shoves the player on contact. |
| `knockback_resist` | 0 | 0 = full knockback from hits, 1 = none. |
| `hop_speed` | 9 | Horizontal speed of a hop, tiles/s. |
| `hop_tiles_min`, `hop_tiles` | 2, 5 | Each hop's height is random in this range (tiles): small hops and big ones. A slime that got stuck hops the full `hop_tiles`. |
| `hop_wait_min`, `hop_wait_max` | 0.8, 2.2 | Seconds resting between moves (random in range). |
| `slither_chance` | 0.3 | Chance a move is a slither along the ground instead of a hop. Slithering steps up ledges 1 tile high. |
| `slither_speed` | 3.5 | Tiles/s while slithering. |
| `slither_seconds_min`, `slither_seconds_max` | 0.5, 1.2 | How long one slither lasts. |
| `wander_by_day` | on | By day on the surface, a slime that hasn't been hit ignores you and wanders (like Terraria's). |
| `turn_chance` | 0.15 | While wandering, chance per move to turn around. It also turns after 2 moves in a row that got nowhere. |
| `aggro_tiles` | 64 | When it's chasing (night, underground, or once hit), it comes at you inside this range sideways... |
| `aggro_tiles_vertical` | 16 | ...and only if you're within this many tiles up or down. A slime on the surface doesn't sense you in a cave below. |
| `gravity` | 110 | Tiles/s². |
| `loot` | | `LootDrop` list: `item`, `min_count`, `max_count`, `chance` (0 to 1). |

### How slimes move

- **By day on the surface, not hit:** it wanders. It keeps a direction for several moves,
  turns around now and then (`turn_chance`) or after 2 moves that got nowhere (a wall),
  and ignores you, so slimes sometimes hop right past.
- **At night, underground (more than 20 tiles below the surface), or once hit:** it
  heads toward you each move while you're within `aggro_tiles`.
- **Each move** is a hop of random height (`hop_tiles_min` to `hop_tiles`) or, now and
  then, a short slither that steps up 1-tile ledges. In the air it keeps its sideways
  speed, so it slides up a wall it touches at takeoff and over a low step.

### Where melee hits (`ItemUser` exports, group Melee)

- **Swings** (swords): an arc in front of you toward the cursor, from
  `swing_above_chest_tiles` (6) above your chest to `swing_below_feet_tiles` (3) below
  your feet, like Terraria's sweep, so they reach an enemy downhill. Off the ground
  (flying, levitating, jumping) it stops at your feet (`swing_below_feet_airborne_tiles`,
  0), so you can't hit a slime far below you.
- **Aimed** (punches; `melee_aims` on the item): in front of you (head to knees) plus a
  line toward the cursor, at most `aimed_hit_limit_degrees` (60) up or down,
  `aimed_hit_width_tiles` (3) wide. The jab, cross and uppercut also turn the arm toward
  the cursor (`aims` and `aim_limit_degrees` 60 on the motions in
  `data/item_types/unarmed.tres`).
- **Walls stop hits:** an enemy is only hit when there's a clear line from your chest to
  its middle or its nearest edge. Solid blocks and closed doors block it
  (`World.line_clear`, `World.blocks_hits`), so no hitting through a door or a wall.

A hurt enemy shows a small health bar. On death it pops ("*pop*") and rolls its loot
into item drops.

### Green Slime

20 health, 6 contact damage, hops about 5 tiles. Drops 1 to 2 **Slime**. The common one.

### Blue Slime

The rare one (about 1 in 9 forest spawns), and only after a Green Slime has been slain
in this world. 35 health, 1 defense, 9 contact damage,
hops about 7 tiles and more often (waits 0.6 to 1.8 s). Drops 2 to 4 **Slime**. Same
sheet as the Green Slime, tinted blue.

### Forest Spirit (Dark Forest)

`ai` SPIRIT: a glowing blue ball that floats (no gravity), never more than
`float_tiles` (10) above the ground. It darts to a spot beside you (`dart_speed` 16
tiles/s, `keep_tiles_min/max` 6 to 12 tiles away, 3 to 10 up), stops, charges for
`charge_seconds` (1 s: sparks close in on it), then shoots a bolt at where you are
(`shot_damage` 15, `shot_speed` 22 tiles/s, out to `shot_tiles` 30; `EnemyShot`,
`src/combat/enemy_shot.gd`, stops at blocks). It only shoots when it can see you. 30
health, 6 contact damage, lights its surroundings (`glow_tiles` 8). Day and night.
Drops 1 to 2 **Magic Essence**, and a **Spirit Core** 1 time in 20. Sheet:
`assets/enemies/forest_spirit.png` (24x24 frames: drifting, charging, shooting).

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
| `day_seconds` / `night_seconds` | 10 / 6 | Average seconds between spawns. Lower = more often. |
| `max_day` / `max_night` | 5 / 6 | Most enemies around the player before spawning stops. |
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

Forest: Blue Slime needs 1 Green Slime slain. Dark Forest (`dark_forest_surface`):
Forest Spirit 70, Green Slime 30, day and night, cap 5 by day and 7 at night. New kinds (time, rain, depth, a boss
beaten) are a small script each, extending `SpawnCondition` with `met(world)` and
`describe(world)`.

**Kills** are counted per world (`World.kills`, saved with it), by anyone, including
`butcher`. Enemies that despawn don't count.

### Despawning

Enemies more than `despawn_tiles` (90) away from you sideways, or `despawn_tiles_vertical` (50) up or down, for
`despawn_seconds` (6) in a row, are removed without loot and don't count as kills.

### The spawner (`EnemySpawner`, child of World, `src/combat/enemy_spawner.gd`)

| Export | Default | |
|---|---|---|
| `rate_scale` | 1 | Multiplies every table's rate (2 = twice as often). |
| `catch_up` | on | Spawn faster when few enemies are around: below 20% of the cap the average wait is x0.6, below 40% x0.7, below 60% x0.8 (Terraria's numbers). |
| `min_distance_tiles` / `max_distance_tiles` | 44 / 60 tiles | Spawns off screen, on ground with room for the enemy. |
| `despawn_tiles`, `despawn_tiles_vertical`, `despawn_seconds` | 90 sideways, 50 up or down, 6 s | Enemies farther than this for 6 s in a row vanish (no loot). Terraria spawns 62 to 84 tiles to the side and at most 47 up or down, and despawns after 12.5 s out of range. |
| `view_margin_tiles` | 6 | Never spawn inside the view plus this margin; when zoomed out, spawn and despawn distances grow to the screen edge plus this. |
| `ahead_bias`, `ahead_speed_tiles` | 0.8, 6 tiles/s | While you move sideways faster than this, 80% of spawns appear ahead of you, so travelling isn't empty. |
| `peaceful` | false | No spawns. |

Never spawns indoors (a tile with a built back wall behind it, like Terraria's player
walls; natural cave walls don't count) or within a small ring around a **bed** (14
tiles) or **campfire** (12 tiles), so an open-air camp is safe without making a whole
area spawn-free (`ObjectDef.spawn_safe_tiles`, `World.near_spawn_safe`). Enemies you
`summon` count toward the cap.

**Swords and spells need a clear line:** walls and closed doors stop melee hits,
projectiles, thrown flasks and Chain Spark (and its jumps). Spells made at the cursor
(Healing Circle, wards, familiars, Conjure Platform) need a clear line from you to the
cursor ("Out of sight"); `SpellData.needs_sight` (on) is there for a later upgrade.
A coated weapon shows its coating and hits left under the hotbar.

## Melee

Weapons are items with `melee_damage > 0` (`ItemData`, Weapon group):

| Field | | |
|---|---|---|
| `melee_damage` | | Damage per swing. |
| `melee_reach` | 4.5 tiles | How far in front the hit box reaches. |
| `knockback` | 12 | Push on the enemy (reduced by its `knockback_resist`). |
| `staggers` | on | The hit cuts the enemy's hop or slither short so it starts over. Fists don't: a light push it shrugs off, so punching can't pin an enemy down. |

The hit lands on the swing's impact frame. The hit box is in front of the player, on the
cursor's side, `melee_reach` tiles wide and 9 tiles tall around the chest. Every enemy
in it is hit once per swing.

| Item | Damage | Reach | Recipe |
|---|---|---|---|
| Wooden Sword | 8 | 4 | Workbench: 10 wood |
| Copper Sword | 13 | 4.5 | Anvil: 8 copper bars, 2 wood |
| Iron Sword | 18 | 4.75 | Anvil: 10 iron bars, 2 wood |
| Fists (empty hands) | 3 | 4 | `fist_damage`, `fist_reach_tiles`, `fist_impact_at` (0.4 of the punch) on the Player. Light knockback, no stagger. Also with the held item put away (H); pressing its hotbar number again takes it back out. Pickups don't go into an empty slot in your hand unless nothing else has room, so an empty hand stays free for punching. |

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
| Iron Helmet | head | 2 | 12 iron bars |
| Iron Chestplate | chest | 3 | 20 iron bars |
| Iron Greaves | legs | 2 | 15 iron bars |
| Dev Ring (dev only) | accessory | 2 | +20 health, +20% speed, +15% jump, +25% magic damage |

## Beds

Bed: furniture, 9x3 tiles, needs a floor. Workbench, 20 wood.

- Right click by day: sets your spawn point ("Spawn point set. You can only sleep at
  night.").
- Right click at night: sets the spawn point and sleeps. The screen fades, the clock
  jumps to an hour after sunrise, plants grow for the skipped time and hunger drains
  for it (at least 1).
- Can't sleep with an enemy within `sleep_enemy_tiles` (World export, 20 tiles).
- The spawn point is saved per character per world. If the bed is gone when you
  respawn, you go to the world spawn ("Your bed is gone").

## Poison

- **Enemies** can be poisoned (`Enemy.poison(dps, seconds)`): they take the damage once a
  second in green numbers and tint green. A stronger poison replaces a weaker one; the
  longer time wins.
- **Poison Coating** goes on a weapon: pick it up (inventory open), then right click a
  weapon's slot. That weapon's next 10 melee hits poison for 2 per second over 4 s, with
  no time limit. A coated weapon shows the coating's drop badge in its slot's bottom
  right corner, and its tooltip says how many hits are left. A new coating replaces the
  old one. It can't be drunk. With a Poison Coating on Z, X or C, the key coats the
  weapon in your hand. The coating belongs to that one weapon: it's kept in its slot's
  data (`Inventory.metas`, `Coating`), moves with it (mouse, chests, the death bag) and
  is saved. Item fields `buff_poison_hits`, `poison_dps`, `poison_seconds`. The training
  dummy can be poisoned too.
- **Poison Flask**: left click throws it toward the cursor in an arc (`throw_speed`
  22 tiles/s, plus a small lift). It shatters on a block or an enemy into a green cloud
  (`throw_effect` `poison_cloud`, `cloud_tiles` 4x3, `cloud_seconds` 4) that poisons
  every enemy inside for 2 per second over 3 s, again every half second.
  `src/combat/thrown_item.gd`, `src/combat/poison_cloud.gd`.

## Slime uses

- Hand recipe: 1 Slime + 1 Wood = 5 Torches.
- Alchemy: 1 Slime in each pair of Poison Flasks.

## Dev console

- `summon <enemy> [n]`: spawn at the cursor (`summon green_slime 3`, `summon blue_slime`).
- `peaceful`: toggle natural spawning (summon still works).
- `butcher`: kill every enemy; they drop their loot.
- `spawns`: the spawn table here (or that nothing spawns here), how many enemies are
  around against the cap, the current chance per second, each enemy's share, why a
  locked one is locked, and how many have spawned this session.
- `kills`: enemies slain in this world.
- `equip <item>`: equips into any slot (armor, accessories, book, conduit).
