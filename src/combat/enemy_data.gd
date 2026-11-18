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
## Sideways speed of a hop (tiles/s) and its height (tiles).
@export var hop_speed := 9.0
@export var hop_tiles := 5.0
## Seconds it rests between hops (random in this range).
@export var hop_wait_min := 0.8
@export var hop_wait_max := 2.2
## Within this many tiles it hops toward you (otherwise it wanders).
@export var aggro_tiles := 30.0
## Gravity in tiles/s².
@export var gravity := 110.0

@export_group("Loot")
@export var loot: Array[LootDrop] = []
