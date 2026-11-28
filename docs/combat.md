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

20 health, 6 contact damage, hops about 5 tiles. Drops 1 to 2 **Slime**, rarely a
**Slime Core** (1 in 40) or **Spell Page: Summon Slime** (1 in 250, Phase 82); 1 in 10 a **Magic
Essence**, and 1 in 100 a **Spell Page: Floating Torch** (Phase 75). The common one.

### Blue Slime

The rare one (about 1 in 9 forest spawns), and only after a Green Slime has been slain
in this world. 35 health, 1 defense, 9 contact damage,
hops about 7 tiles and more often (waits 0.6 to 1.8 s). Drops 2 to 4 **Slime**, and the
same rare core and Summon Slime page as the Green Slime, and 1 in 10 a Magic Essence. Same sheet as the Green Slime, tinted blue.

### Your slime (Summon Slime)

A melee summon (`SpellData.summon_enemy_ranks`): a real slime that fights for you
(`Enemy.setup_summon`, `_summon_move`). It goes after the nearest enemy within 18
tiles (`summon_tiles`), never hopping at random: every `summon_hop_wait` (0.35 s) it
hops aimed to land on the enemy (sideways speed up to `summon_hop_reach` (1.6) times
its hop speed), and within `summon_ram_tiles` (2.5) on the same level it slides
straight into it. It hits on contact for `damage` (8) every 0.6 s
(`SUMMON_HIT_EVERY`), knocking it back; with no enemy near it hops after you and rests a few tiles
behind you, and if it's 40 tiles away (`SUMMON_LEASH_TILES`) it hops back to you. Your hits
don't touch it and it isn't counted as an enemy; it lasts 90 s, with a gold cross over
it. **Evolve** (Empower tab, `data/empower/evolve.tres`: 15 Slime + 6 Magic Essence)
makes it a Blue Slime, hitting harder by as much as a Blue Slime does (9 vs 6: 12).
More forms as more slimes are added (add them to `summon_enemy_ranks`, raise the
node's `max_rank`). It shares the summon limit with the Forest Spirit (one, two with
the Pendant).

**Command** (Phase 73, `data/spells/command.tres`, `SpellData.Cast.COMMAND`): everyone
knows it and it starts on the **middle mouse** quick slot (`CharacterData.MIDDLE`; old
characters get it once, if the slot is free). Cast it at an enemy (within 2 tiles of the
cursor): "Target!", a red reticle over it, and every summon goes after it instead of the
nearest (`World.command_summons`, `summon_target`, `commanded_target`; the slime while
it's within `SUMMON_LEASH_TILES` of it, familiars within twice their `summon_tiles`).
Even a critter, if you point at it. It ends when the enemy dies; cast it at nothing to
clear it. Free, no cooldown.

Phase 72: no summon (slime or familiar) goes after **critters** (fish, crabs, fireflies)
unless they've turned on you (`Enemy.summon_should_attack`). In water the slime floats
as usual, but with an enemy in the water it **dives**: it swims straight at it at
`summon_swim_speed` (9 tiles a second, on the spell) with no gravity
(`Enemy._summon_dive`), then floats back up when there's nothing left to chase.

### Forest Spirit (Dark Forest)

`ai` SPIRIT: a glowing blue ball that floats (no gravity), never more than
`float_tiles` (10) above the ground. It darts to a spot beside you (`dart_speed` 16
tiles/s, `keep_tiles_min/max` 6 to 12 tiles away, 3 to 10 up), stops, charges for
`charge_seconds` (1 s: sparks close in on it), then shoots a bolt at where you are
(`shot_damage` 15, `shot_speed` 22 tiles/s, out to `shot_tiles` 30; `EnemyShot`,
`src/combat/enemy_shot.gd`, stops at blocks). It only shoots when it can see you. 30
health, 6 contact damage, lights its surroundings (`glow_tiles` 8). Day and night.
Drops 1 to 2 **Magic Essence**, a **Spirit Core** 1 time in 20, and its **Spell Page:
Summon Forest Spirit** 1 time in 50 (crafting.md: discovered recipes). It glows: drawn
over the lighting with a soft halo (`GlowHalo`, `src/combat/glow_halo.gd`: `rest` 0.35,
`full` 0.85) that brightens while it charges and shoots, so it never looks faded; the
summoned one too. Its light follows it smoothly (see "Moving lights" in items-and-mining.md). Yours, from the spell, leans
a little teal (`SpellData.summon_tint`) with a small gold cross over it
(`summon_marker`), so you can tell them apart. Sheet:
`assets/enemies/forest_spirit.png` (24x24 frames: drifting, charging, shooting).

### Crab and Fish (the ocean, Phase 56)

Critters: `harmless_until_hit` (no touch damage, and they don't chase, until you hit
them).

- **Crab** (`AI.CRAB`, 8 health): scuttles sideways for `scuttle_seconds_min`/`max`
  (0.4 to 1.4 s) at `scuttle_speed` 4 tiles/s, rests `rest_seconds_min`/`max` (0.6 to
  2.5 s), turns with `turn_chance` 0.4. Hit it and it comes after you faster and
  pinches (3 damage). Drops a Raw Crab. Lives on the beach and the sea floor.
- **Fish** (`AI.FISH`, 5 health, `swims`): no gravity in water; swims at `swim_speed` 5
  tiles/s toward a new heading every `turn_seconds_min`/`max` (1 to 3.5 s), turns back at
  the water's edge and surface, and darts away at `flee_speed` 11 when you come within
  `flee_tiles` 5. Out of water it flops about. Drops a Raw Fish. Spawns only in tiles
  full of water (`EnemySpawner._water_spot`).

### Firefly (the Dark Forest, Phase 62)

A critter (`AI.FIREFLY`, 1 health, `flies`: no gravity, spawns 2 to 6 tiles up in the
air): drifts at `drift_speed` 1.6 tiles/s within `drift_tiles` 4 of where it appeared,
blinks every `blink_seconds` 2.2 and glows (`glow_tiles` 3, a soft green). A **Bug Net**
swing catches it (`EnemyData.catch_item` firefly, `ItemData.catches_critters`): gone,
a Firefly in your bag. Any other hit just kills it. Dark Forest table: Firefly as a
critter, one every 1.5 s, at most 10, day and night.

## Spawning

Chance based, like Terraria: there's a small chance every frame, so on average one
enemy arrives every `day_seconds` (or `night_seconds`), but the gaps are random and
enemies pile up if you leave them alone, up to the cap. Killing them makes room.

### Spawn tables: `data/spawns/<id>.tres` (`SpawnTable`, `src/combat/spawn_table.gd`)

One table per biome and layer. Only `forest_surface` exists so far.

| Field | forest_surface | |
|---|---|---|
| `biome`, `layer` | forest, SURFACE | Where it applies. The biome is counted from the ground around the player (`World.biome_at`, world-generation.md), so Dark Forest blocks decide it. |
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

**Critters** (`EnemyData.is_critter`, the harmless-until-hit ones: crabs, fish) spawn
apart from enemies, under their own cap: each table's `critter_seconds` and
`max_critters` (Critters group), and they don't count toward `max_day`/`max_night`
(`World.enemy_count` leaves them out; `critter_count`).

The **Ocean** table (`data/spawns/ocean.tres`, biome `ocean`): Crab 40, Fish 60, a critter
every 2 s, at most 14. The forest table has Fish too (critters every 2 s, at most 6):
they only find room in ponds (`EnemySpawner._water_spot`).

**Slimes float** (`EnemyData.floats`, `float_rise` 7): in water they're pushed up while
more than a third under, splash down hard, bob at the surface and hop off it.

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
| Copper Dagger | 8 | 3.5 | Anvil: 4 copper bars (everyone starts with one) |
| Wooden Sword | 8 | 4 | Workbench: 10 wood |
| Copper Sword | 13 | 4.5 | Anvil: 8 copper bars, 2 wood |
| Iron Sword | 18 | 4.75 | Anvil: 10 iron bars, 2 wood |
| Dual Storm Axes | 7 per chop | 3.75 | Anvil: 10 iron bars, 8 Magic Essence (a Storm weapon, below) |
| Fists (empty hands) | 3 | 4 | `fist_damage`, `fist_reach_tiles`, `fist_impact_at` (0.4 of the punch) on the Player. Light knockback, no stagger. Also with the held item put away (H); pressing its hotbar number again takes it back out. Pickups don't go into an empty slot in your hand unless nothing else has room, so an empty hand stays free for punching. |

## Schools and school weapons (Phase 25)

Two playstyles share one system: pure magic, or a weapon that feeds your magic. Every
spell has a **school** (`ItemData.school`): Storm (Spark, Chain Spark, Spark Ward),
Arcane (Arcane Bolt, Arcane Edge, Barrier, Blink, Recall, Tele Grab, Conjure Platform),
Air (Air Push, Air Step, Bound, Fly, Levitate, Gel Cushion), Spirit (Wisp, Familiar,
Summon Forest Spirit, Summon Slime, Light Orb), Life (Mend, Healing Circle). The
gathering spells, Seek Ore and Hyper Drill have none. The tooltip says "Storm spell".

- **Gear** raises a school: stats `storm_damage`, `arcane_damage`, `air_damage`,
  `spirit_damage`, `life_damage` (0.15 = +15%). The **Storm Charm** (accessory, Scribe's
  Desk: 6 copper bars, 6 Magic Essence) is the first: +15% Storm damage.
- **A school weapon** (`school` on a weapon) does three things:
  1. **Its hits mark** the enemy with its school (`mark_damage` every
     `Schools.MARK_TICK` (0.5 s) for `mark_seconds`). Storm's mark is **shocked**: the
     enemy flickers blue and takes a few ticks of damage. One mark at a time.
  2. **That school's spells cash the mark in:** they do `Schools.MARK_PAYOFF` (1.25,
     +25%) to a marked enemy (projectiles, Chain Spark, gusts, wards). The weapon never
     casts the spell itself: it sets up, the spell finishes.
  3. **In hand, it amplifies its school** (`school_amp`): +20% for the axes. It counts
     while you quick cast or ready a spell too (the weapon in your hotbar slot,
     `Player.weapon_in_hand`).
- **Weapon skills** (right click, `skill`): `LEAP_SLAM` leaps toward the cursor
  (`skill_leap_speed`, `skill_leap_height`), falls hard (`Player.slam_fall_gravity` 2)
  and slams where you land: `skill_damage` to everything within `skill_radius_tiles`,
  strong knockback, and the weapon's mark. `skill_cooldown` seconds between uses. No
  fall damage from the leap.

Spell power for a spell: book and conduit x (1 + magic damage) x `Player.school_mult`
(1 + the school's gear stat + a same-school weapon's `school_amp`).

**Dual Storm Axes:** 7 per chop (alternating hands, then a crossing chop), shocked for
3 s (2 every 0.5 s), Storm spells +20% while held. Right click: a long leap (`skill_leap_speed`
48 tiles/s, `skill_leap_height` 7: about 18 tiles on flat ground) and slam, 14 damage
in 4 tiles, 5 s cooldown. Held one in each hand (`dual_axes` item type, `dual`: the
second axe rides in the back hand, `PaperDoll._offhand_sprite`).

Ideas not built yet: weapons that cast a spell on their skill, more schools' weapons
and charms, armor sets with school bonuses.

## Spells against enemies

Spark (projectile) and Air Push (gust: shoves everything in a cone, light damage) hit
enemies through the same `damageable` group. See items-and-mining.md, Magic.

## Taking damage

- Enemy hits: `max(1, damage - defense * 0.5)`, then knockback away from the enemy.
- `hurt_cooldown` 0.66 s on the Player: invulnerable after a hit.
- Death by an enemy: "You were slain." (same magic bag rules as survival.md).

## Equipment

**Forest Spirit Pendant** (accessory, Phase 21): +1 summon at a time
(`stats.summon_slots`) and +20% summon damage (`stats.summon_damage`). Made at the
Spell Weaving Table from 1 Spirit Core, 10 Magic Essence and 10 Iron Bars (the recipe shows once you
have a Spirit Core). Without it, one summon at a time (casting again replaces it);
with it, two (the oldest goes past that), floating one behind the other
(`Familiar.slot`). Placeholder icon from `tools/make_brick_art.py`.

You can wear only one of each accessory (`CharacterData.equip_problem`).

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

- **Bomb** (Phase 52, the voxel test item: Creative or `give bomb`, no recipe yet):
  thrown like the flask (`throw_speed` 20) and blows up on the first block, sand cell or
  enemy it touches (`throw_effect` `explosion`). Radius `explosion_radius_tiles` 3,
  `explosion_damage` 30 at the middle (down to a quarter at the edge of 1.25x the
  radius), to enemies and to you. Blocks in the radius break whole with their drops if
  `explosion_power` (40) is enough; sand and Sand Bricks lose exactly the round bite
  instead (voxel cells, see items-and-mining.md). Walls are left. `World.request_explode`.

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
