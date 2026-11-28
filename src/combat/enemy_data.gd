class_name EnemyData
extends GameData
## An enemy type (data/enemies/<id>.tres): its look, stats, how it moves, what it drops
## and when it spawns. Enemy (src/combat/enemy.gd) brings one to life.

## How it moves.
enum AI { SLIME, SPIRIT, CRAB, FISH, FIREFLY }

@export_group("Look")
## Sprite sheet: frames side by side, each frame_size: 0 = resting, 1 = squashed (about
## to hop or just landed), 2 = in the air.
@export var texture: Texture2D
@export var frame_size := Vector2i(36, 27)
## Multiplies the sprite's color (a blue slime could reuse the green one's art).
@export var tint := Color.WHITE
## Hitbox in px (bottom-centered on its feet).
@export var size := Vector2(30, 20)

@export_group("Stats")
@export var max_health := 20.0
## Damage taken is reduced by half of this (at least 1 gets through).
@export var defense := 0
## Damage when it touches you.
@export var contact_damage := 6.0
## How hard it knocks you back (tiles/s).
@export var knockback := 10.0
## 0 = knocked back fully by hits, 1 = not at all.
@export_range(0.0, 1.0) var knockback_resist := 0.0

@export_group("Movement")
@export var ai := AI.SLIME
## Sideways speed of a hop (tiles/s).
@export var hop_speed := 9.0
## Each hop's height is random between these (tiles): small hops and big ones.
@export var hop_tiles_min := 2.0
@export var hop_tiles := 5.0
## Seconds it rests between moves (random in this range).
@export var hop_wait_min := 0.8
@export var hop_wait_max := 2.2
## Chance a move is a slither along the ground instead of a hop. Slithering steps up
## ledges 1 tile high.
@export_range(0.0, 1.0) var slither_chance := 0.3
## Slither speed (tiles/s) and how long one lasts (seconds, random in range).
@export var slither_speed := 3.5
@export var slither_seconds_min := 0.5
@export var slither_seconds_max := 1.2
## By day on the surface, a slime that hasn't been hit wanders and ignores you (like
## Terraria's). At night, underground, or once hit, it comes at you.
@export var wander_by_day := true
## While wandering: chance per move to turn around (it also turns when blocked).
@export_range(0.0, 1.0) var turn_chance := 0.15
## Within this many tiles (sideways) it comes at you when it's chasing...
@export var aggro_tiles := 64.0
## ...and only if you're within this many tiles up or down: a slime on the surface
## doesn't sense you through the ground in a cave below.
@export var aggro_tiles_vertical := 16.0
## Gravity in tiles/s².
@export var gravity := 110.0
## Slimes float: in water they bob at the surface (and can hop off it) instead of sinking.
@export var floats := false
## How fast a floating slime rises when pushed under (tiles per second).
@export var float_rise := 7.0
## Critters (crabs, fish): no touch damage until you hit it (a crab then pinches back).
@export var harmless_until_hit := false


## Critters (harmless until hit: crabs, fish) spawn under their own cap and rate
## (SpawnTable max_critters), apart from the enemies.
func is_critter() -> bool:
	return harmless_until_hit


## Which of the Catalog's Entities sub tabs it's under (Phase 77). Auto: Peaceful for
## critters, else Enemies.
enum CatalogGroup { AUTO, ENEMY, BOSS, NPC, PEACEFUL }
@export var catalog_group := CatalogGroup.AUTO


func group() -> CatalogGroup:
	if catalog_group != CatalogGroup.AUTO:
		return catalog_group
	return CatalogGroup.PEACEFUL if is_critter() else CatalogGroup.ENEMY
@export_group("Crab (scuttles on the ground)")
## Tiles per second sideways, and how long it scuttles or stops (seconds, random).
@export var scuttle_speed := 4.0
@export var scuttle_seconds_min := 0.4
@export var scuttle_seconds_max := 1.4
@export var rest_seconds_min := 0.6
@export var rest_seconds_max := 2.5
@export_group("Firefly (drifts in the air)")
## Flies: no gravity, spawns a few tiles up in the air.
@export var flies := false
## Tiles per second it drifts, and how far (tiles) it wanders from where it appeared.
@export var drift_speed := 1.6
@export var drift_tiles := 4.0
## Blinks: seconds per glow, on and off.
@export var blink_seconds := 2.2
@export_group("Catching")
## A Bug Net swing catches it (gone, this item in your bag) instead of hurting it.
@export var catch_item: StringName = &""
@export_group("Fish (swims in water)")
## Lives in water: spawns only in water, swims there, flops about out of it.
@export var swims := false
@export var swim_speed := 5.0
## Darts away this fast when you come within flee_tiles.
@export var flee_speed := 11.0
@export var flee_tiles := 5.0
## Seconds between new headings (random).
@export var turn_seconds_min := 1.0
@export var turn_seconds_max := 3.5

@export_group("Spirit (floats and shoots)")
## SPIRIT: darts to a spot near you (dart_speed tiles/s, for dart_seconds), stops,
## glows for charge_seconds, then shoots a bolt at you (shot_damage, shot_speed
## tiles/s, out to shot_tiles). Never more than float_tiles above the ground.
@export var dart_speed := 16.0
@export var dart_seconds_min := 0.5
@export var dart_seconds_max := 1.1
@export var charge_seconds := 1.0
@export var shot_damage := 15.0
@export var shot_speed := 22.0
@export var shot_tiles := 30.0
@export var float_tiles := 10.0
## How far from you (tiles, sideways) it likes to hover while fighting.
@export var keep_tiles_min := 6.0
@export var keep_tiles_max := 12.0
## Light it gives off (tiles; 0 = none) and its color.
@export var glow_tiles := 0.0
@export var glow_color := Color(0.5, 0.75, 1.0)
@export_group("Loot")
@export var loot: Array[LootDrop] = []
