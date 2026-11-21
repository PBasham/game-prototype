# Code map: where everything is, and how to change it

A cookbook. Find the thing you want to change, see which files hold it, and the usual
edits. The detailed docs explain every field; this page tells you where to go.

Two rules make most changes easy:

- **Content is data.** Items, spells, blocks, walls, furniture, recipes, enemies, spawn
  tables, bushes, forage, Empower nodes and world generation settings are `.tres` files
  under `data/<category>/`. Open one in the Godot editor (FileSystem panel, double click)
  and edit it in the Inspector, or edit the text. The `Registry` autoload loads every
  folder at startup; a new file in a folder is picked up on the next run.
- **Tunables are `@export`s.** Numbers on nodes made in code (Player, ItemUser,
  LightMap, Backdrop, EnemySpawner, WorldMap...) are `@export var x := ...` lines at the
  top of their script. Change the default there to keep it, or change it live: run the
  game (F5), Scene panel, **Remote**, select the node, edit in the Inspector (not saved).

Generators (`tools/make_*.gd`) write the default data and placeholder art. They never
overwrite a file that exists unless you pass `--force`, so your edits are safe. To make
one new file: `godot --headless --path . --script res://tools/make_items.gd -- --only=<id>`.

## Contents

1. [Project layout](#project-layout)
2. [Items](#items)
3. [Spells](#spells)
4. [Empower (spell upgrades)](#empower-spell-upgrades)
5. [Blocks and walls](#blocks-and-walls)
6. [Furniture, stations and storage](#furniture-stations-and-storage)
7. [Crafting and recipes](#crafting-and-recipes)
8. [Food, potions, buffs and coatings](#food-potions-buffs-and-coatings)
9. [Enemies and spawning](#enemies-and-spawning)
10. [Combat: weapons and armor](#combat-weapons-and-armor)
11. [Player movement and stats](#player-movement-and-stats)
12. [Survival: health, hunger, dying, day and night](#survival-health-hunger-dying-day-and-night)
13. [Trees, bushes, flowers and forage](#trees-bushes-flowers-and-forage)
14. [World generation and biomes](#world-generation-and-biomes)
15. [Lighting, backdrop and terrain look](#lighting-backdrop-and-terrain-look)
16. [The HUD, windows and the inventory](#the-hud-windows-and-the-inventory)
17. [World map](#world-map)
18. [Character art and the paper doll](#character-art-and-the-paper-doll)
19. [Sounds](#sounds)
20. [Keys](#keys)
21. [Saving](#saving)
22. [Dev tools and tests](#dev-tools-and-tests)

## Project layout

| Folder | What's there |
| --- | --- |
| `src/core/` | Autoloads (`Game`, `Registry`, `EventBus`, `Settings`, `Sounds`, `SaveManager`, `PerfStats`), `DevCli` (scripted runs), `data/game_data.gd` (base of every data file) |
| `src/world/` | The world: `world.gd` (the hub that owns every system), tiles and chunks (`world_data.gd`, `chunk_data.gd`, `tile_def.gd`, `tile_types.gd`), drawing (`chunk_renderer.gd`, `chunk_build_job.gd`, `terrain.gdshader`), objects (`object_def.gd`, `object_layer.gd`), plants and forage, light, backdrop, clock, saves, map |
| `src/world/generation/` | World generators: `forest_generator.gd`, its settings `forest_gen_settings.gd`, the test course |
| `src/items/` | Item and spell data classes, the inventory, crafting, `item_user.gd` (using whatever you hold: mining, placing, casting), drops, the character save |
| `src/player/` | `player.gd` (movement, health, mana, buffs, concentration) and `doll/` (the paper doll drawing) |
| `src/combat/` | Enemies, spawning, projectiles, spell effects (zones, wards, summons, light orbs), loot |
| `src/ui/` | `hud/` (inventory, crafting, chests, equipment, spells, map, dev items), `menu/` (main and pause menus), `dev/` (console, doll viewer), `ui_skin.gd`, `satchel_look.gd` |
| `data/` | All content (see each section) |
| `assets/` | Art and sounds; every placeholder is listed in `assets/ASSETS.md` |
| `art/` | Source art (Aseprite) and the Python scripts that make concept and placeholder art (`art/concepts/<topic>/`) |
| `tools/` | Generators and the world preview |
| `tests/unit/` | GUT tests, one file per area |
| `docs/` | These docs |

## Items

**Files:** `data/items/<id>.tres` (class `ItemData`, `src/items/item_data.gd`). Every
field has a comment in that script; [items-and-mining.md](items-and-mining.md) explains
them in tables. Defaults come from `tools/make_items.gd`.

| To... | Do this |
| --- | --- |
| Rename an item or change its tooltip | `display_name`, `description` in its `.tres` |
| Change how many stack | `max_stack` (blocks 9999, materials 999, tools 1) |
| Change its icon | `icon` (16x16, or 32x32 detailed); the file is `assets/items/icons/<id>.png` |
| Change how it looks in hand | `held` (a `HeldItemLook`: texture, grip point, item type) |
| Change how it swings | its item type in `data/item_types/<type>.tres` (animation curves; see [character-art.md](character-art.md)) |
| Make a tool mine harder or faster | `mining_damage` (per hit), `mining_power` (which blocks it can break), `reach_tiles` |
| Make it place a block or wall | `places_block`, `places_wall` (ids in `data/tiles`, `data/walls`) |
| Make it fit special storage | `storage_tags` (`lumber`, `potion`), and `shelf_color` for its color there |
| Add a new item | copy a similar `.tres`, change `id` (must match the file name), name, icon; or add it to `tools/make_items.gd` and run it with `--only=<id>` |

Code that uses items: `src/items/item_user.gd` (what left and right click do with the
held item, by `Mode`: MINE, CHOP, PLACE_BLOCK, CAST, EAT, THROW...), `src/items/inventory.gd`
(stacks, slots, `add`, `remove`), `src/items/item_drop.gd` (items lying in the world:
pickup, merging, the magnet), `src/items/character_data.gd` (what a character owns and
knows, saved).

## Spells

**Files:** `data/spells/<id>.tres` (class `SpellData`, `src/items/spell_data.gd`, which
extends ItemData). The full list with numbers is in [items-and-mining.md](items-and-mining.md)
(Spells); learning, scrolls and pages in [crafting.md](crafting.md).

| To... | Do this |
| --- | --- |
| Change mana cost | `mana_cost` (per cast) or `mana_per_second` (beams and concentration spells) |
| Change damage, speed, range | `damage`, `projectile_speed`, `projectile_range`, `reach_tiles` |
| Change cooldown | `cooldown` (seconds) |
| Change what it costs to learn | `learn_cost` (item id to count), `learnable_at_table` |
| Make it need items each cast | `reagents` |
| Change its tier (which book can cast it) | `tier` |
| Change its group (tab and filters) | `group`: ATTACK, MOVEMENT, TOOLS, UTILITY, BUFF... |
| Change Fly or Levitate speed | `move_speed`, `boost_speed_mult`, `hover_tiles` |
| Change Air Step or Bound | `air_jump_power`, `air_control_mult`, `air_speed_mult`, `leap_speed`, `leap_rise`, `mana_cost` |
| Change a summon (Familiar, Call Spirit) | `duration`, `damage`, `summon_interval`, `summon_charge`, `summon_tiles` |
| Change Tele Grab | `grab_tiles`, `grab_pull_speed`, `reach_tiles`, `mana_per_second` |
| Make a cursor spell ignore walls | `needs_sight` off |
| Add a spell | copy one with the same `cast` type, change `id` and numbers. A new `cast` type needs code (below) |

**Code:** `SpellData.Cast` lists the kinds (PROJECTILE, TOGGLE, GUST, SUMMON, GRAB...).
What each does when cast: `ItemUser.cast()` in `src/items/item_user.gd` (a `match` on
`spell.cast`). Concentration and readied spells (Fly, Levitate, Mend, Air Step, Bound)
run in `src/player/player.gd` (`toggle_concentration`, `_fly`, `_levitate`,
`_air_trigger`). Effects that live in the world are in `src/combat/` (`spell_projectile.gd`,
`spell_zone.gd`, `spell_ward.gd`, `familiar.gd`, `light_orb.gd`, `poison_cloud.gd`,
`conjured_platform.gd`, `ore_sense.gd`). Mana costs always go through
`Player.mana_cost_of()` (so Empower applies). The spell wheel, quick slots and the
Spells window are `src/ui/hud/hud.gd`, `spell_window.gd`, `equipment_window.gd`.

## Empower (spell upgrades)

**Files:** `data/empower/<id>.tres` (class `EmpowerNode`, `src/items/empower_node.gd`).
Bought at the Spell Weaving Table, Empower tab ([crafting.md](crafting.md)).

| To... | Do this |
| --- | --- |
| Change Efficient | `per_rank` (-0.05 = 5% cheaper), `max_rank`, `cost_per_rank` (rank n costs n times it) |
| Add a node after Efficient | new `.tres` with `requires = &"efficient"`, an `order`, and `groups` to limit which spells get it |
| Add a new kind of effect | add to `EmpowerNode.Stat`, then apply it where that number is used (mana is `CharacterData.mana_mult`) |

Ranks are saved per character in `CharacterData.empower`.

## Blocks and walls

**Files:** `data/tiles/<id>.tres` and `data/walls/<id>.tres` (class `TileDef`,
`src/world/tile_def.gd`). Art: `assets/terrain/<terrain>.png` (64x64, or 128x128
detailed). Collision shapes: one row per block in `assets/tiles/blocks.png` (`atlas_row`,
must be unique for blocks).

| To... | Do this |
| --- | --- |
| Make a block tougher | `health`, `min_mining_power` |
| Change what it drops | `drop_item`, `drop_count`, `bonus_drop_item`, `bonus_drop_chance` |
| Make it a platform or climbable | `collision` (SOLID, PLATFORM, NONE), `climbable` |
| Change its look | `terrain` (the texture name); `built` (placed blocks look tidy), `grass_cover`, `ore_overlay` |
| Add a block | a `.tres` here, a terrain texture, a new `atlas_row` (add a row to `blocks.png` and an entry to `GAME_BLOCKS` in `tools/generate_tiles.gd`), and an item that `places_block` it |

Code: `src/world/world.gd` (`request_set_block`, `request_damage_block`, mining and
breaking), drawing in `chunk_renderer.gd` and `terrain.gdshader`. Saves keep a palette
of ids, so adding blocks never breaks old worlds.

## Furniture, stations and storage

**Files:** `data/objects/<id>.tres` (class `ObjectDef`, `src/world/object_def.gd`), art
`assets/objects/<id>.png`. Each also has an item (`data/items/<id>.tres` with
`places_object`). [crafting.md](crafting.md) has every field.

| To... | Do this |
| --- | --- |
| Change a station's size | `width_tiles`, `height_tiles` (and the art) |
| Make a station upgrade | `upgrade_to` (the next object) and `upgrade_cost`; the next one has a higher `station_tier` |
| Make a recipe need the upgraded station | the recipe's `station_tier` |
| Change chest size | `container_slots` |
| Change special storage | `container_accepts` (a storage tag), `container_stack_cap` (0 = items' own), `fill_look` (FRAMES, BOTTLES, PILE) |
| Change a light | `light_radius`, `light_color` |
| Change the campfire's Cozy | `aura_radius`, `aura_health_regen`, `aura_name` |
| Change spawn safety around beds or campfires | `spawn_safe_tiles` |

Code: placing and removing in `world.gd` (`request_place_object`, `request_remove_object`),
drawing in `object_layer.gd` (fills: `_draw_bottles`, `_draw_pile`), chests and names in
`world.gd` (`containers`, `chest_names`), the chest window in `hud.gd`. Objects added to
`tools/make_items.gd` `_objects()` go at the **end** of its list (later lines refer to
entries by position).

## Crafting and recipes

**Files:** `data/recipes/<id>.tres` (class `RecipeData`, `src/items/recipe_data.gd`).
Recipes made in code: learning spells and Empower (`Crafting.learn_recipes`,
`Crafting.empower_recipes`) and scrolls (`Crafting.scroll_recipes`), all in
`src/items/crafting.gd`.

| To... | Do this |
| --- | --- |
| Change a recipe's cost or output | `inputs`, `output`, `output_count` |
| Change where it's made | `station` (empty = by hand), `station_tier` |
| Hide a recipe until something is found | `unlock_items` (shown once the character has had one) |
| Need a tool without using it up | `requires` |
| Put it on a station tab | `tab` (tab names: `STATION_TABS` in `hud.gd`) |
| Change scroll costs | `SCROLL_COSTS` in `tools/make_items.gd`, `World.scribe_cost_mult` |

Code: `crafting.gd` (what can be made, paying), `craft_stock.gd` (inventory plus nearby
chests), the window in `hud.gd` (`recipes()`, `craft()`, `learn()`, `empower()`).

## Food, potions, buffs and coatings

Food and potions are items (`kind` FOOD) with `food_value`, `heal_value`, and a buff:
`buff_name`, `buff_description`, `buff_seconds`, `buff_health_regen`,
`buff_move_speed`, `buff_poison_hits`; potions also `mana_value`, `sickness`; thrown
flasks `throw_speed`, `throw_effect`, `cloud_tiles`, `poison_dps`. Coatings: `src/items/coating.gd` (stored on the
weapon). Buffs on the player: `player.gd` (`add_buff`, `_item_buffs`). See
[survival.md](survival.md) for food, berries and cooking.

## Enemies and spawning

**Files:** `data/enemies/<id>.tres` (class `EnemyData`, `src/combat/enemy_data.gd`) and
`data/spawns/<id>.tres` (class `SpawnTable`). [combat.md](combat.md) has every field.

| To... | Do this |
| --- | --- |
| Change health, damage, knockback | `max_health`, `contact_damage`, `knockback`, `knockback_resist` |
| Change a slime's hops | `hop_*`, `aggro_tiles` |
| Change the Forest Spirit | `dart_speed`, `charge_seconds`, `shot_damage`, `shot_speed`, `shot_tiles`, `float_tiles`, `keep_tiles_min/max`, `glow_tiles` |
| Change loot | `loot` (each: `item`, `min_count`, `max_count`, `chance`) |
| Change where and how often they spawn | the spawn table: `biome`, `layer`, `day_seconds`, `night_seconds`, `max_day`, `max_night`, `entries` (enemy and weight), conditions (`kill_count_condition.gd`) |
| Make spawns slower everywhere | `EnemySpawner.rate_scale`, distances (`min_distance_tiles`...) in `src/combat/enemy_spawner.gd` |

Code: `enemy.gd` (AI: `_slime`, `_spirit`, hits, death and loot), `enemy_spawner.gd`
(where and when), `enemy_shot.gd` (the spirit's bolt). A new behavior is a new
`EnemyData.AI` value and a function in `enemy.gd`.

## Combat: weapons and armor

Weapons are items with the `Weapon` group: `melee_damage`, `melee_reach`, `knockback`,
`staggers`, `melee_aims`. Armor and accessories: `equip_slot`, `defense`, `stats`
(stat name to value: `move_speed`, `jump`, `mana_regen`...), `wear` (paper doll
overlays). Melee hits: `item_user.gd`; adding up equipment stats: `Player.stat()`;
armor art from `tools/make_armor_art.gd`. Beds: `ObjectDef.bed`. See [combat.md](combat.md).

## Player movement and stats

All in `src/player/player.gd`, as `@export`s at the top, grouped:

| To change... | Exports |
| --- | --- |
| Walking and running | `walk_speed`, `jog_speed`, `run_speed`, `ground_accel_time`, `ground_decel_time` |
| Jumping | `jump_height`, `time_to_apex`, `fall_gravity_multiplier`, `jump_cut`, `coyote_time`, `jump_buffer_time` |
| Air control | `air_accel_time`, `air_turn_time`, `air_drag_time` |
| Fall damage | `fall_damage_start` (tiles), `fall_damage_per_tile` |
| Steps and ledges | `max_step_tiles`, `ledge_assist_px`, `air_ledge_climb_px` |
| Health and mana | `max_health`, `health_regen`, `max_mana`, `mana_regen`, `mana_regen_delay` |
| Hunger | `max_hunger`, `hunger_full_days`, `starve_damage` |
| Flying | `fly_speed`, `fly_accel_time` (the spell's `move_speed` wins) |

[guide.md](guide.md) (Player movement) explains how they work together.

## Survival: health, hunger, dying, day and night

Day and night: `src/world/world_clock.gd` (`day_minutes`, `sunrise_hour`, `sunset_hour`,
colors). Dying: `world.gd` (`respawn_player`, `respawn_seconds`) and the world's death
option (`WorldInfo.DeathDrop`). The magic bag: `src/items/item_bag.gd`. Details in
[survival.md](survival.md).

## Trees, bushes, flowers and forage

| Thing | Files |
| --- | --- |
| Trees (pines, darkwood), saplings, chopping, falling | `src/world/plant_layer.gd`; art `assets/trees/`; placement rules in `forest_generator.gd` (`tree_at`, `_dark_tree_at`) |
| Berry bushes | `data/bushes/<id>.tres` (`BushData`: `fruit`, `weight`, textures, `save_index`); growth in `plant_layer.gd` |
| Sticks, rocks, mushrooms on the ground | `data/forage/<id>.tres` (`ForageData`), `src/world/forage_layer.gd` |

## World generation and biomes

**File:** `data/worldgen/forest.tres` (`ForestGenSettings`). Every value is explained in
[world-generation.md](world-generation.md). Code: `src/world/generation/forest_generator.gd`.

| To... | Do this |
| --- | --- |
| Change hills, caves, ores, trees | the groups in `forest.tres` |
| Change the Dark Forest's size or place | `dark_forest_share`, `dark_forest_patches`, `dark_forest_distance`, `dark_forest_spawn_clear` |
| Change dark tree density | `dark_tree_spacing`, `dark_tree_chance` |
| See the whole world | `godot --headless --path . --script res://tools/preview_world.gd -- --seed=42` |
| Regenerate in game | F6 (debug builds) |
| Add a biome | a `biome_at` answer in the generator, its tree and ground rules, a spawn table with that `biome`, and a backdrop look (see Dark Forest as the example). Needs a design brief first |

## Lighting, backdrop and terrain look

| Thing | Files and tunables |
| --- | --- |
| Light (sun, torches, caves) | `src/world/light_map.gd` (`sky_depth_tiles`, `ambient`, `dark_forest_shade`), `light_job.gd` (the spread, on a thread) |
| Sky, hills, sun and moon, Dark Forest backdrop | `src/world/backdrop.gd` (`DARK_LAYERS`, `dark_veil`, `dark_fade_speed`), art `assets/backdrop/` |
| Block textures and edges | `src/world/terrain.gdshader`, `chunk_renderer.gd`; art from `tools/generate_tiles.gd` |
| Day colors | `world_clock.gd` |

## The HUD, windows and the inventory

`src/ui/hud/hud.gd` draws the inventory, hotbar, crafting, chests, tooltips, the spell
wheel and pickup notes. Separate windows: `equipment_window.gd`, `spell_window.gd`,
`dev_items_window.gd`, `map_view.gd`. Look: `src/ui/ui_skin.gd` (wooden windows,
buttons) and `src/ui/satchel_look.gd` (the satchel inventory: colors are the consts at
its top). The trash slot is `CharacterData.trash`. Menus: `src/ui/menu/`.

## World map

`src/world/world_map.gd` (what's explored, the picture; `reveal_tiles`, `reveal_every`,
colors) and `src/ui/hud/map_view.gd` (the screen: `zoom`, markers). Key N.

## Character art and the paper doll

The player is drawn by `src/player/doll/paper_doll.gd` from Aseprite layers
(`art/Scholar-casual.aseprite`, imported to `assets/sprites/scholar` with
`tools/import_aseprite.gd`). Arms are posed in code (`arm_track.gd`, `doll_rig.gd`);
legs, body and head are frames. Held item motion: `data/item_types/`. Colors:
`tools/make_character_palette.gd`. Everything is in [character-art.md](character-art.md).

## Sounds

`src/core/sounds.gd` plays `assets/sounds/<id>.wav` when anything calls
`EventBus.sound_requested.emit(id, position)`. Placeholders come from
`tools/make_sounds.gd`. Replace a `.wav` with the same name to change a sound.

## Keys

Project Settings, **Input Map** (`project.godot`). Current: WASD move, Space jump, I
inventory, K crafting, P equipment, L spells, R spellbook (hold: wheel), Q and E wheels,
Z X C quick slots, F movement spell, H quick heal, M quick mana, B buffs, N map, Esc
pause.

## Saving

Worlds: `src/world/world_save.gd` (chunks plus "meta" sections: plants, chests, map,
clock...). Characters: `src/items/character_data.gd` (`to_dict`, `load_file`). Paths:
`src/core/save_manager.gd`. Each save starts with a header (`save_header.gd`). Adding
a saved field: write it in `to_dict` and read it with a default in the loader so old
saves still load.

## Dev tools and tests

| Tool | Where |
| --- | --- |
| Console (`~` in debug builds; `help` lists commands) | `src/ui/dev/dev_console.gd` |
| F3 overlay, F6 regenerate, F7 dev items | `debug_overlay.gd`, `world.gd`, `dev_items_window.gd` |
| Scripted runs and screenshots (`--shot`, `--tap`, `--console`, `--aim`) | `src/core/dev_cli.gd`, [README.md](../README.md) |
| Tests | `tests/unit/test_<area>.gd`; run all: `godot --headless --path . -s addons/gut/gut_cmdln.gd` |

[playtest.md](playtest.md) lists what to check after each phase;
[decisions.md](decisions.md) records why things are the way they are.
