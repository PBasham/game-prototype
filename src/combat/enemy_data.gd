class_name EnemyData
extends GameData
## An enemy type (data/enemies/<id>.tres): its look, stats, how it moves, what it drops
## and when it spawns. Enemy (src/combat/enemy.gd) brings one to life.

## How it moves.
enum AI { SLIME }

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
## Within this many tiles it comes at you when it's chasing.
@export var aggro_tiles := 64.0
## Gravity in tiles/s².
@export var gravity := 110.0

@export_group("Loot")
@export var loot: Array[LootDrop] = []
