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
| Change Air Step or Bound | `air_jump_power`, `air_control_mult`, `air_speed_mult`, `leap_speed`, `leap_height`, `mana_cost` |
| Change a summon (Familiar, Summon Forest Spirit) | `duration`, `damage`, `summon_interval`, `summon_charge`, `summon_tiles` |
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
| Change what a node does to a spell | FIELDS nodes: `adds` / `scales` (SpellData field names), `rank_costs` per rank, `spells` / `casts` to pick spells |
| Give a spell a new tier | new FIELDS `.tres` (`mining_power.tres` is the pattern); nothing in code |
| How empowered spells reach the game | `CharacterData.empowered` / `apply_empower` put copies in `ItemData._empowered`, which `ItemData.find` checks first (world load and every rank bought) |
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
`creative_window.gd`, `map_view.gd`. Look: `src/ui/ui_skin.gd` (wooden windows,
buttons) and `src/ui/satchel_look.gd` (the satchel inventory: colors are the consts at
its top). The trash slot is `CharacterData.trash`. Menus: `src/ui/menu/`.

## Chat and emotes

`src/ui/hud/chat_box.gd` (the chat line and log; commands in `send()`), emotes in
`src/player/player.gd` (`EMOTES`, `start_emote`, `sit_on`, `_update_emote`), the poses
in `src/player/doll/paper_doll.gd` (`_sit_targets`, `_emote_arm_angle`, the "Poses"
exports). Chairs are objects with `seat` ([crafting.md](crafting.md)). Key: Enter
(`chat` in the Input Map).

## World map

`src/world/world_map.gd` (what's explored, the picture; `reveal_tiles`, `reveal_every`,
colors) and `src/ui/hud/map_view.gd` (the screen: `zoom`, markers). Key N.

## Character art and the paper doll

The player is drawn by `src/player/doll/paper_doll.gd` from Aseprite layers
(`art/Scholar-casual.aseprite`, imported to `assets/sprites/scholar` with
`tools/import_aseprite.gd`). Arms are posed in code (`arm_track.gd`, `doll_rig.gd`);
legs, body and head are frames, or legs can be posed in code too (`PaperDoll.leg_mode`,
console `legs`, see "Legs posed in code"). Held item motion: `data/item_types/`. Colors:
`tools/make_character_palette.gd`. Everything is in [character-art.md](character-art.md).

Render test (Phase 19, console `doll`): `src/player/doll/doll_canvas.gd` (own pixel
grid), `Player.set_doll_render` (picks the sheet and canvas), the "Motion extras"
exports and `land()` on the doll, `DollRig.art_scale` / `rect_base` (upscaled sheets),
`tools/upscale_doll.py` (makes `scholar@x2n`, `@x2s`, `@x4s`, `@x4ns`). Hand-drawn
key poses: `PaperDoll.DRAWN_POSE_TAGS`, `drawn_pose_frame()`. Inside a canvas, convert
with `doll_to_world` / `world_to_doll`, never `to_local` on the doll.

3D body (Phase 20, console `body`): `src/player/body3d/body_3d.gd` (the mannequin,
its canvas, IK, colors), `toon.gdshader` (banded shading), `trim.gdshader` (the light
edge). `Player.set_body`. On the doll: `joints_override`, `parts_hidden`, `pose_state`
and `posed`, `step_fps`, `arm_is_natural`. Blender models (style `model`): `_build_model`,
`_measure_model`, `_pose_model`, `BONE_NAMES` in `body_3d.gd`; the placeholder from
`tools/make_test_body.gd`; rules in [3d-character.md](3d-character.md). `hull.gdshader`
draws the tunic's trim line.

## Sounds

`src/core/sounds.gd` plays `assets/sounds/<id>.wav` when anything calls
`EventBus.sound_requested.emit(id, position)`. Placeholders come from
`tools/make_sounds.gd`. Replace a `.wav` with the same name to change a sound.

## Keys

Project Settings, **Input Map** (`project.godot`). Current: WASD move, Space jump, I
inventory, K crafting, P equipment, L spells, R spellbook (hold: wheel), Q and E wheels,
Z X C quick slots, F movement spell, H quick heal, M quick mana, B buffs, N map, Enter
chat, Esc pause.

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
| F3 overlay, F6 regenerate, F7 Creative window | `debug_overlay.gd`, `world.gd`, `creative_window.gd` |
| Scripted runs and screenshots (`--shot`, `--tap`, `--console`, `--aim`) | `src/core/dev_cli.gd`, [README.md](../README.md) |
| Tests | `tests/unit/test_<area>.gd`; run all: `godot --headless --path . -s addons/gut/gut_cmdln.gd` |

[playtest.md](playtest.md) lists what to check after each phase;
[decisions.md](decisions.md) records why things are the way they are.


## Phase 21: Dark Forest ground, biomes, bricks, Pendant

| Change | Where |
| --- | --- |
| Biome blocks and what ground they act as | `TileDef` group Ground (`kind`, `grows_to`, `bare_to`, `biome`), `TileTypes.is_grass/is_dirt/is_ground/grass_of/dirt_of/biome_of` (use these, never compare to the dirt or grass id) |
| Where the Dark Forest's ground is | `ForestGenerator.dark_forest_blocks_at`, settings `dark_forest_wobble_*`, `dark_forest_fringe_tiles` |
| Which biome a tile is in | `World.biome_at`, `biome_amount`, exports group "Biome detection" |
| Dark grass colors | `ChunkRenderer.dark_grass_colors`, `TileDef.dark_grass`, `terrain.gdshader` `gc()` |
| Terrain slots (textures the shader holds) | `ChunkRenderer.MAX_SLOTS` (32) and the arrays in `terrain.gdshader` |
| Trees on level ground, lean | `ForestGenerator._trunk_fits`, `PlantLayer.sapling_spot`, `tree_lean_degrees` |
| Smooth moving lights | `light_point()` on light sources, `LightJob._sources` (shared over 4 tiles), `LightMap.fade_seconds` + `light_map.gdshader` |
| Summon limit and damage | `World.request_spell_effect` (SUMMON), stats `summon_slots`, `summon_damage`, `Familiar.slot`, `SpellData.summon_tint` |
| Hold to keep casting | `Player._handle_use` (spells repeat past the combo window), `Player._repeat_quick` |
| Art placeholders | `tools/make_dark_forest_terrain.py`, `tools/make_brick_art.py` |


## Phase 22: summons

| Change | Where |
| --- | --- |
| A melee summon (an enemy fighting for you) | `SpellData.summon_enemy_ranks`, `World._summon_ally`, `Enemy.setup_summon`, `_summon_dir`, `_summon_tick` |
| Summon evolving through forms | `EmpowerNode.Stat.EVOLVE`, `data/empower/evolve.tres` (raise `max_rank` with more forms) |
| Summon unlocks | the spell's `learn_unlock_items` (its core) and `learn_cost`; the page item's `learns_spell` |


## Phase 23: the Catalog

| Change | Where |
| --- | --- |
| What's found, recipes making and using an item, station names, drops | `Catalog` (src/items/catalog.gd) |
| The window (tabs, pages, recipe slot) | `CatalogWindow` (src/ui/hud/catalog_window.gd), opened by `Hud.toggle_catalog`, `show_catalog_recipes` |
| Kills and seen drops (saved) | `CharacterData.slain`, `seen_drops`, `note_kill` (from `Enemy._die`) |
| Opening it | action `catalog` (J) in project.godot, the inventory's Catalog button (`Hud._catalog_button_rect`, `Area.CATALOG_BUTTON`) |
| Your slime's movement (aimed hops, sliding in) | `Enemy._summon_move`, `SpellData.summon_hop_wait`, `summon_ram_tiles`, `summon_hop_reach` |

## Phase 24: tools are spells

| Change | Where |
| --- | --- |
| Starting spells and items | `CharacterData.STARTING_SPELLS`, `STARTING_ITEMS`, `give_starting_kit` (old saves learn the spells in `load_file`) |
| Mining and Chopping numbers | `data/spells/mining_spell.tres`, `chopping_spell.tres` (free: no mana fields) |
| Their ranks | `data/empower/mining_power.tres`, `chopping_power.tres`, `gather_reach.tres` |
| More spell tiers | `data/empower/potency.tres`, `arc.tres`, `distance.tres`, `lasting.tres` |
| The phantom tool | `PhantomTool` (src/items/phantom_tool.gd); swing timing and hits in `ItemUser._process` (`_swing`, `_phantom`); SpellData `phantom_texture`, `phantom_swing_time`, `phantom_tints`, `gather_rank` |
| The Copper Dagger | `data/items/copper_dagger.tres`, recipe at the Anvil; art from `tools/make_dagger_art.py` |

## Phase 25: weapons and schools

| Change | Where |
| --- | --- |
| Schools, mark payoff, colors, mark names | `Schools` (src/combat/schools.gd); `ItemData.School` |
| Which school a spell is | `school` in `data/spells/<id>.tres` (`SCHOOLS` in tools/make_items.gd) |
| School damage from gear | stats `storm_damage`... (`CharacterData.STATS`), applied in `Player.school_mult`, used by `ItemUser._spell_power(spell)` |
| A weapon's school, mark, amp, skill | ItemData "School weapon" group (`data/items/dual_storm_axes.tres`) |
| Marks on enemies | `Enemy.mark`, `is_marked`, `_tick_mark`, `_tint_mark`; left by `ItemUser._leave_mark` (melee and slam) |
| Spells cashing marks in | `Schools.payoff` in `SpellProjectile`, `SpellWard`, `ItemUser.chain` and `gust` |
| Weapon skills (right click) | `Player.try_weapon_skill`, `_update_slam`, `weapon_slammed` -> `ItemUser.slam` |
| Dual wielding | `ItemTypeData.dual`, `data/item_types/dual_axes.tres` (`_dual_axes` in tools/make_item_types.gd), `PaperDoll._offhand_sprite`, `_place_offhand` |
| Console `hold <item>` | `src/ui/dev/dev_console.gd` |

## Phase 26: phantom swings

| Change | Where |
| --- | --- |
| The tool, its styles, the glowing box | `PhantomTool` (src/items/phantom_tool.gd): light layer (additive) + `_tools` child (solid) |
| When the hit lands, what drives it | `ItemUser._process` (`_swing`, `phantom_impact`), `ItemUser._update_phantom`, `_glow_box` |
| Per spell | SpellData `phantom_style`, `phantom_impact`, `phantom_grip`, `phantom_tip`, `phantom_swing_time`, `phantom_tints` |
| Test spells for the styles (Mining v2 to v8) | `DevMagic.STYLE_SPELLS` (debug builds); console `phantom`; per spell tuning `SpellData.phantom_tuning` -> `PhantomTool.apply_tuning` |

## Phase 30: book poses

| Change | Where |
| --- | --- |
| A spell's pose | SpellData `book_pose` (`BOOK_POSES` in tools/make_items.gd) |
| Which look a spell gets | `Player._look_for`, `_quick_weapon` (quick cast with a weapon out) |
| The hip book and its glow | `Player._update_hip_book`; `PaperDoll.book`, `book_on_hip`, `book_glow`, `_book_hip` |
| The weapon in the front hand during a quick cast | `PaperDoll.offhand`, `_offhand_front`, `offhand_angle` |
| The motions | `data/item_types/spell_float.tres`, `spell_hip.tres`, `spell_offhand.tres` (`_spell_float`... in tools/make_item_types.gd); `ItemTypeData.floats`, `shows_item` |

## Phase 31: fixes

| Change | Where |
| --- | --- |
| Tooltip width, text size, placement | `Hud.tooltip_max_width`, `tooltip_font_size`, `Hud._layout_tooltip`, `Hud.wrap_text` |
| "Already known" on pages | `Hud.tooltip_for` |
| A click with a spell on the mouse | `Hud._input` (`_press_on_ui`) |
| The dev kit's spells | `CharacterData.give_dev_kit` (DEV_SPELLS first, then every spell) |
| Hovering UI in scripted runs | DevCli `--mouse=X:Y` |

## Phase 32: dev things kept in saves

| Change | Where |
| --- | --- |
| Dev items and spells saved (debug builds) | `CharacterData.to_dict`, `Inventory.to_dict` (`OS.is_debug_build()`) |
| Registered before a character loads | `CharacterData.load_file` calls `DevMagic._register()` |

## Phase 33: the hovering tool

| Change | Where |
| --- | --- |
| Hover, pull into the swing, drift back | `PhantomTool._process`, `_hover_point`, `_pulled`, `_draw_hover`, `_draw_main`; set from `ItemUser._update_phantom` (`idle`, `anchor`, `facing`) |

## Phase 34: Creative window, quit confirmation

| Change | Where |
| --- | --- |
| The Creative window (F7), its tabs, spawning | `CreativeWindow` (src/ui/hud/creative_window.gd, was DevItemsWindow): `TABS`, `DEV_TAB`, `TEST_TAB`, `ENEMY_TAB`, `TEST_BOOKS`, `spawn`, `spawn_tiles`; `Hud.toggle_creative`; console `creative [tab]` |
| Quit Game asks first | `PauseMenu._show_quit`, `quit_game`; `World.skip_save` |

## Phase 35: bottles, glass, potion furniture

| Change | Where |
| --- | --- |
| Bottle shape and contents per item | `ItemData.BottleShape`, `bottle_shape`, `bottle_contents`; set in `tools/make_items.gd` (`BOTTLES`, `BOTTLE_CONTENTS`) |
| Bottles on shelves, spots | `ObjectLayer._draw_bottles`, `bottle_spots`, `draw_bottle`; shelves on `ObjectDef` (`bottle_shelves`, `bottles_per_shelf`, `bottle_x0`, `bottle_step`) |
| Stacking furniture | `ObjectDef.flat_top`; `World.is_flat_top`, `_resting_on`, `_can_place_furniture`, `request_remove_object` |
| Large Potion Cabinet, Potion Shelf, sand, glass, bottles | `data/items`, `data/objects`, `data/recipes` (from `tools/make_items.gd`); art `tools/make_potion_storage_art.py` |
| Console `freeplace` | `ItemUser.free_place` (checked in `_anchored`) |

## Phase 36: fixes

| Change | Where |
| --- | --- |
| Biome needs real ground | `World.biome_min_ground`, `biome_amount` |
| Brighter walls and torches | `LightMap.walled_sky`, `source_curve` (LightJob); `ChunkRenderer.wall_shade`, `built_wall_shade` (terrain.gdshader) |
| See-through Glass, Glass Wall, Clay Wall | `TileDef.see_through`; terrain.gdshader (`pane`), `LightMap` (`job.solid`, `clear_walls`); `data/tiles/glass.tres`, `data/walls/{glass,clay}_wall.tres`; art `tools/make_glass_clay_art.py` (also adds blocks.png row 19) |
| Shelf bottles from icons | `ObjectLayer._draw_bottles`, `shelf_texture`; `ItemData.shelf_sprite` |
| Right click takes one, hold repeats | `Hud.right_click_slot(slot, inv, half)`, `_start_take_repeat`, `_update_take_repeat`, `take_repeat_delay`, `take_repeat_fastest` |

## Phase 37: storage, filled bottles, torch, ropes, Catalog search

| Change | Where |
| --- | --- |
| Filled bottles | `tools/make_items.gd` (`FILLED_BOTTLES`, `FILLED_HERBS`, `_filled_name`); art `tools/make_phase37_art.py` |
| Food and book storage tags | `ItemData.has_storage_tag`; `Inventory.accepts` |
| Pantries, Bookshelf, Barrel, Crate, Nets, Liquid Barrels | `data/objects`, `data/items`, `data/recipes` (from `tools/make_items.gd`, object indexes 18 to 27); art `tools/make_phase37_art.py` |
| Book spines, net heaps, food on shelves | `ObjectLayer._draw_books`, `_draw_net`, `_shown`, `icon_color`, `shelf_texture`; `ObjectDef.FillLook` BOOKS, NET, `net_bag` |
| Contents behind glass / mesh | `ObjectDef.front_frame`, drawn in `ObjectLayer.draw_chunk`; cabinet art 2 frames (`tools/make_potion_storage_art.py`) |
| Hanging from a block | `ObjectDef.hang_points`; `World._can_place_furniture` |
| Liquid capacity (recorded only) | `ObjectDef.liquid_capacity` |
| Torch in hand | `ItemData.held_light_radius`, `held_light_color`; `HeldLight` (src/items/held_light.gd); `ItemUser._update_held_light`; item type `torch` (`tools/make_item_types.gd`) |
| Ropes join, rope on the bottom | `ObjectLayer.draw_chunk` (`ROPE_JOIN`); `ItemUser.rope_end` |
| Catalog search | `CatalogWindow.search`, `searching`, `search_key`, `_items`, `_enemies`; Hud key routing |
| Infinity sign | `Hud._draw_infinity` |
| Hold to place keeps going | `Player` (`placing_held`) |
| Blocks vs walls, continuous glass | terrain.gdshader (`built_block_shade`, `block_shadow`, `clear_slots`, `clear_walls`); `ChunkRenderer` |
| Hip book behind the arms | `PaperDoll` (`book_hip_offset`, BookHip moved before BackArmLower) |

## Phase 38: shelf fit

| Change | Where |
| --- | --- |
| Tall bottles shrunk to the room under the next shelf | `ObjectLayer.shelf_room`, `shelf_texture(it, max_h)` |

## Phase 41: the Empower tree

| Change | Where |
| --- | --- |
| One entry per spell, the picked node | `Crafting.empower_recipes(c, picks)`; `Hud.empower_picks` |
| The tree (layout, drawing, clicks) | `Hud._empower_layout`, `_draw_empower_detail`, `_pixel_circle`, `Area.EMPOWER_NODE` |
| Tree shape, next-rank lines | `EmpowerNode.parent_in`, `requires_any`, `icon`, `next_rank_lines`, `FIELD_NAMES` |
| Area and Limit nodes | `data/empower/mining_area.tres`, `limit.tres`; `SpellData.summon_bonus_slots` (World's summon limit) |
| Placing area follows Mining | `ItemUser.area_size` |
| Node icons | `assets/ui/empower/`, `tools/make_empower_icons.py` |
| Console `crafttab` | `DevConsole` |

## Phase 42: dev commands, logs, wall brightness

| Change | Where |
| --- | --- |
| `instant_placement`, `instant_break`, `no_drop` | `World.instant_place`, `instant_break`, `no_drop` (`_damage_tile`, `request_spawn_drop`, `PlantLayer.request_hit_tree`); `ItemUser._instant_use`; `DevConsole` |
| Upright logs, rounded log wall ends | terrain.gdshader (`upright`, `strip_t`, `turn_slots`, `overhang_walls`); `ChunkRenderer`; `data/walls/{log,darkwood_log}_wall.tres` `overhang_px` |
| Walls evened out against their blocks | `ChunkRenderer.wall_block_ratio`, `_wall_mults`, `_luminance`; shader `wall_mult` |

## Phase 43: station command

| Change | Where |
| --- | --- |
| Console `station <name> [tier]` | `DevConsole._station`; `Hud.virtual_station`, `open_virtual_station`, `_station_def` |

## Phase 44: log ends, upright log walls, no_los

| Change | Where |
| --- | --- |
| Outlined rounded log ends, upright log walls | terrain.gdshader (the overhang branches, `upright_wall`) |
| Console `no_los` | `World.no_los`, `player_sight` (used by `ItemUser` in place of `line_clear`) |

## Phase 45: liquid barrels, Siphon Liquid, nets, shelf spacing

| Change | Where |
| --- | --- |
| Liquid Barrel window | `LiquidWindow` (src/ui/hud/liquid_window.gd); `World.liquid_opened`; `Hud._on_liquid_opened` |
| Siphon Liquid | `tools/make_items.gd`; `data/spells/siphon_liquid.tres`; Reach and Area nodes list it |
| Nets, tap | `tools/make_phase37_art.py`; object index 28 (Long net) in `tools/make_items.gd` |
| Even shelves | `ObjectLayer._draw_bottles` |

## Phase 46: shelf spots, Creative tabs, wall pantry rack

| Change | Where |
| --- | --- |
| One spot per slot | `ObjectDef.slots_per_shelf`; `ObjectLayer._draw_sections`, `shelf_fit`; window: `Hud._shelf_cols`, `_store_cell`, `PLANK_H` |
| 4 stacks a slot | `ObjectDef.container_stack_mult`; `Inventory.stack_mult`, `cap_for` |
| Floor or wall | `ObjectDef.floor_or_wall`; `World._can_place_furniture` |
| Retired items | `ItemData.obsolete` (Creative, Catalog) |
| Creative tabs | `CreativeWindow.TABS`, `category_of` |

## Phase 47: bookshelves, fuller spots, right click fix

| Change | Where |
| --- | --- |
| Bookshelves | `ObjectLayer._draw_books`; object index 29 (`tall_bookshelf`) in `tools/make_items.gd`; art `bookcase()` in `tools/make_phase37_art.py` |
| Overlapping spots | `ObjectLayer._draw_sections` |
| Far furniture right click | `Player` (the right click branch) |

## Phase 48: Lumber Rack, storage capacity

| Change | Where |
| --- | --- |
| The rack's heap | `ObjectDef.pile_area`; `ObjectLayer._draw_pile`; art `lumber_rack()` in `tools/make_phase37_art.py` |
| Stacks a slot by space | `container_stack_mult` in `tools/make_items.gd` and the objects |

## Phase 49: plank section, Tele Grab forage

| Change | Where |
| --- | --- |
| Boards flat on the left | `ObjectDef.pile_boards`; `ObjectLayer._draw_pile` |
| Tele Grab lifts forage | `ForageLayer.request_lift_near`; `World.tele_grab` |

## Phase 62: fireflies

| Change | Where |
| --- | --- |
| Firefly AI, catching | `EnemyData.AI.FIREFLY`, `flies`, `drift_*`, `blink_seconds`, `catch_item`; `Enemy._firefly`, `blink`, `catch` |
| Bug Net | `ItemData.catches_critters`; `ItemUser.melee_hit` |
| Spawning in the air | `EnemySpawner.find_spot` (flyers lifted 2 to 6 tiles) |
| Data | `data/enemies/firefly.tres`, `data/objects/firefly_lamp.tres`, items `firefly`, `bug_net`, `firefly_lamp` (tools/make_items.gd), `data/spawns/dark_forest_surface.tres` |
| Art | `tools/make_firefly_art.py` |

## Phase 61: water fixes, critters, torches on trees

| Change | Where |
| --- | --- |
| Water over the player | `VoxelLayer.Z`, `World` (z of Voxels and SeaFlora) |
| Floating slimes | `EnemyData.floats`, `float_rise`; `Enemy._floating` in `_physics_process`, `_slime` |
| Critter cap | `EnemyData.is_critter`; `SpawnTable.critter_seconds`, `max_critters`, `pick(..., critters)`, `has_critters`; `EnemySpawner._process`, `try_spawn(table, critters)`; `World.enemy_count`, `critter_count` |
| Building against loose sand | `ItemUser._anchored` |
| Torches on trunks | `PlantLayer.trunk_at`, `trunk_share`, `_remove`; `World._supported`, `check_supports` |

## Phase 60: dark caves

| Change | Where |
| --- | --- |
| Daylight fades fast in caves | `LightMap.cave_air_decay`, `cave_air_below_tiles`; `LightJob` (sky pass `mult`) |

## Phase 59: turn log walls

| Change | Where |
| --- | --- |
| Wall turn (shape bit 6) | `ItemUser.shape_cycle` (value 4 in the wall nibble), `terrain.gdshader` `upright_wall`; console `wallshape` in `DevConsole` |

## Phase 58: drops in the ground

| Change | Where |
| --- | --- |
| Drops lifted out of solid ground | `World.out_of_ground` (used by `request_spawn_drop`); `ItemDrop._physics_process` (resting check) |

## Phase 56: sea life

| Change | Where |
| --- | --- |
| Crab and fish AI | `EnemyData.AI.CRAB`, `FISH`, `harmless_until_hit`, crab and fish exports; `Enemy._crab`, `_fish`, `_in_water`, `_critter_look` |
| Spawning | `data/spawns/ocean.tres`; `EnemySpawner._water_spot` |
| Enemies | `data/enemies/crab.tres`, `fish.tres` |
| Food | `raw_crab`, `crab_legs`, `raw_fish`, `cooked_fish` (tools/make_items.gd), cooking recipes |
| Sea plants | `WorldGenerator.sea_plant_at`, `ForestGenerator.sea_plant_at`; `SeaFlora` (src/world/sea_flora.gd), `World.sea_flora` |
| Art | `tools/make_sea_life_art.py` |

## Phase 55: ocean and ponds

| Change | Where |
| --- | --- |
| Ocean, beaches, ponds | `ForestGenerator` (`_place_ocean`, `_sea_floor`, `ocean_at`, `_place_ponds`, `water_at`, `_sandy`, `_land_surface`), "Ocean" and "Ponds" in `ForestGenSettings` |
| Generated water into the voxel layer | `ChunkData.water`, `WorldData.fresh_water`, `VoxelLayer.import_generated`, `_imported` (saved) |
| Water over rock edges | `VoxelLayer._fringe_rects`, `water_fringe` |
| Hard Sand | `data/tiles/hard_sand.tres`, `data/walls/hard_sand_wall.tres`, art `tools/make_voxel_art.py` (blocks.png row 22) |
| Ocean biome | `WorldGenerator.biome_at`, `ocean_at`; `TileDef.biome` on Sand and Hard Sand |
| Map preview | `tools/preview_world.gd` (water, sand) |

## Phase 54: water

| Change | Where |
| --- | --- |
| Swimming, breath, thirst | `Player` (`_update_water`, `_swim`, `_update_breath`, "Thirst" and "Swimming" exports), `BreathBar` (src/player/breath_bar.gd); `WorldInfo.thirst`, New World page; HUD status panel (4 bars) |
| Water bottles | `ItemData.thirst_value`, `leaves_item`; `ItemUser._give_back`; `WATER_BOTTLES` in tools/make_items.gd; art `tools/make_water_art.py` |
| Water in recipes | pseudo item `water`; `CraftStock.water_count`, `water_take`; `World.water_for_crafting`, `take_water_for_crafting`, `craft_water_tiles` |
| Siphon Liquid | `SpellData.siphons`, `liquid_capacity`, `siphon_rate`; `ItemUser.Mode.SIPHON`, `_siphon`; `CharacterData.water` |
| Liquid Barrels | `World.liquids`, `barrel_water`, `request_barrel_water`, `_spill_barrel`, `WorldSave.META_LIQUIDS`; `LiquidWindow` |
| Voxel water helpers | `VoxelLayer.liquid_at`, `liquid_in`, `take_liquid`, `pour_liquid` |

## Phase 52: voxels

| Change | Where |
| --- | --- |
| Voxel cells, simulation, drawing, collision, saving | `VoxelLayer` (src/world/voxel_layer.gd), `World.voxels`; `WorldSave.META_VOXELS` |
| Materials | `VoxelMaterial` (src/world/voxel_material.gd), `data/voxels/` |
| Blocks that become cells | `TileDef.voxel` (sand, sand_bricks) |
| Mining and placing cells | `World._damage_tile` (cells first), `World.request_place_block`, `World.place_cost`; `ItemUser` MINE targets, PLACE_BLOCK/WALL costs, `_limit_to_stack`; `ItemData.place_units`; `Player.take_held(count)`, `can_take_held` |
| Bomb | `ItemData.explosion_*`; `ThrownItem._shatter`; `World.request_explode` |
| Quiet block changes | `World.request_set_block(tile, id, quiet)` |
| Dev console | `water`, `boom`, `voxels` in `DevConsole` |
| Art | `tools/make_brick_art.py` (Sand Bricks), `tools/make_voxel_art.py` (Bomb, blocks.png row 21) |

## Phase 51: Shaping Spell, placing reach

| Change | Where |
| --- | --- |
| Shape byte per tile | `ChunkData.shapes`; `WorldData.get_shape`, `set_shape` (`set_block` / `set_wall` keep the other layer's bits) |
| Shapes drawn | `terrain.gdshader` `shape_of`, `in_shape` (B channel of the tile texture); `ChunkBuildJob.shape`; `ChunkRenderer._tile_color` |
| Shaped collision | `ChunkRenderer.SHAPE_POLYGONS`, `_shape_alt` (TileSet alternatives 1 to 6 on SOLID rows) |
| Saving | `WorldSave.META_SHAPES`; `World._shapes_to_dict`, load in `World` after `load_chunks` |
| Shaping Spell | `SpellData.shapes_blocks`; `ItemUser.Mode.SHAPE`, `shape_cycle`, `shape_step`; `World.request_set_shape`; Alt + R in `Player`; `Hud.dedicated_key`; `data/empower/gather_reach.tres` |
| Placing reach | `ItemUser.reach` (the Mining Spell's reach) |
| `shapes` console command | `DevConsole._shapes` |

## Phase 50: break dust, Glow Potion

| Change | Where |
| --- | --- |
| Break dust | `BreakDust` (src/world/break_dust.gd); `World._break_dust`; `ChunkRenderer.terrain_color` |
| Glow Potion | `ItemData.buff_light_radius`, `buff_light_color`; `Player.buff_light`; `ItemUser._update_held_light`; `tools/make_items.gd` |
