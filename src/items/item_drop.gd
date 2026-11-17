class_name ItemDrop
extends Node2D
## An item stack lying in the world. Pops out, falls, lands on blocks (and platforms),
## and slides to the player once they're within magnet_tiles; touching them picks it up.
## Spawn through World.request_spawn_drop (host-authoritative).

const TILE := float(World.TILE)

## Tiles: the drop flies to the player inside this distance.
@export var magnet_tiles := 3.0
## Tiles/s^2 it accelerates toward the player while magnetized.
@export var magnet_accel := 260.0
@export var gravity := 160.0
## Tiles/s.
@export var max_fall := 60.0
## Seconds before a stack the player threw can be picked up again.
@export var thrown_pickup_delay := 1.0
## Minutes before an untouched drop disappears. 0 = never.
@export var despawn_minutes := 10.0

var world: World
var item_id: StringName
var count := 1
var velocity := Vector2.ZERO
var _pickup_delay := 0.0
var _age := 0.0
var _bob := 0.0
var _sprite: Sprite2D


func setup(w: World, id: StringName, n: int, vel: Vector2, thrown: bool) -> void:
	world = w
	item_id = id
	count = n
	velocity = vel
	_pickup_delay = thrown_pickup_delay if thrown else 0.15
	_bob = randf() * TAU


func _ready() -> void:
	var item := ItemData.find(item_id)
	_sprite = Sprite2D.new()
	_sprite.texture = item.icon if item else null
	_sprite.scale = Vector2(0.5, 0.5)  # 16 px icons drawn 8 px (one tile)
	_sprite.position = Vector2(0, -4)
	add_child(_sprite)
	z_index = 2


func _physics_process(delta: float) -> void:
	_age += delta
	_pickup_delay = maxf(_pickup_delay - delta, 0.0)
	if despawn_minutes > 0.0 and _age > despawn_minutes * 60.0:
		queue_free()
		return
	var player := world.player if world else null
	var to_player := (player.chest() + Vector2(0, 12)) - global_position if player else Vector2.INF
	var magnet := player != null and _pickup_delay <= 0.0 and to_player.length() < magnet_tiles * TILE \
		and player.character and player.character.inventory.room_for(item_id) > 0
	if magnet:
		velocity = velocity.move_toward(to_player.normalized() * 40.0 * TILE, magnet_accel * TILE * delta)
		global_position += velocity * delta
		if to_player.length() < TILE * 1.5:
			_pick_up(player)
		return
	velocity.y = minf(velocity.y + gravity * TILE * delta, max_fall * TILE)
	velocity.x = move_toward(velocity.x, 0.0, (6.0 if _on_ground() else 1.5) * TILE * delta)
	var next := global_position + velocity * delta
	# Sideways: stop at solid blocks.
	if world.collision_at(Vector2(next.x, global_position.y - 2.0)) == TileDef.Collision.SOLID:
		velocity.x = 0.0
		next.x = global_position.x
	# Down: land on solid blocks and on platforms (from above).
	if velocity.y > 0.0:
		var c := world.collision_at(next)
		var was_above := floori(global_position.y / TILE) < floori(next.y / TILE)
		if c == TileDef.Collision.SOLID or (c == TileDef.Collision.PLATFORM and was_above):
			next.y = floorf(next.y / TILE) * TILE
			velocity.y = 0.0
	elif world.collision_at(next + Vector2(0, -7.0)) == TileDef.Collision.SOLID:
		velocity.y = 0.0
		next.y = global_position.y
	global_position = next
	_bob += delta * 3.0
	_sprite.position.y = -4.0 - (absf(sin(_bob)) * 1.0 if _on_ground() else 0.0)


func _on_ground() -> bool:
	return velocity.y == 0.0 and world.collision_at(global_position + Vector2(0, 1)) != TileDef.Collision.NONE


func _pick_up(player: Player) -> void:
	var left := player.character.inventory.add(item_id, count)
	if left < count:
		EventBus.item_picked_up.emit(item_id, count - left)
	count = left
	if count <= 0:
		queue_free()
	else:
		_pickup_delay = 0.5
