class_name ItemDrop
extends Node2D
## An item stack lying in the world. Pops out, falls, lands on blocks (and platforms),
## and slides to the player once they're within magnet_tiles; touching them picks it up.
## Spawn through World.request_spawn_drop (host-authoritative).

const TILE := float(World.TILE)

## Tiles: the drop flies to the player inside this distance (from the player's body,
## not a single point, so drops at your feet count).
@export var magnet_tiles := 3.0
## Multiplies every item's drop size (ItemData.drop_size or its kind's default).
@export var drop_scale := 1.0
## Tiles: picked up when this close to the body.
@export var pickup_tiles := 0.6
## Tiles/s: fastest it flies toward the player.
@export var magnet_speed := 30.0
## Tiles/s^2 it accelerates toward the player while magnetized.
@export var magnet_accel := 260.0
@export var gravity := 160.0
## Tiles/s^2 it slows down sliding on the ground / flying through the air.
@export var ground_friction := 80.0
@export var air_friction := 4.0
## Tiles/s: fastest it can still be moving sideways after the player walks out of the
## magnet range (so it doesn't fly off).
@export var max_loose_speed := 6.0
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
var _magnetized := false
var _sprite: Sprite2D
## Drawn size in px (from the item's drop_pixels()).
var _size := 10.0


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
	_size = (item.drop_pixels() if item else 10.0) * drop_scale
	# Icons are 16x16, or bigger for detailed art: shown the same size either way.
	var icon_px := float(item.icon.get_width()) if item and item.icon else 16.0
	_sprite.scale = Vector2.ONE * (_size / icon_px)
	_sprite.position = Vector2(0, -_size * 0.5)
	add_child(_sprite)
	z_index = 2


func _physics_process(delta: float) -> void:
	_age += delta
	_pickup_delay = maxf(_pickup_delay - delta, 0.0)
	if despawn_minutes > 0.0 and _age > despawn_minutes * 60.0:
		queue_free()
		return
	var player := world.player if world else null
	var center := global_position + Vector2(0, -4)
	var gap := INF
	var to_player := Vector2.ZERO
	if player:
		# Distance to the nearest point of the player's body.
		var body := player.body_rect()
		var nearest := center.clamp(body.position, body.end)
		gap = center.distance_to(nearest)
		to_player = body.get_center() - center
	var magnet := player != null and _pickup_delay <= 0.0 and gap < magnet_tiles * TILE \
		and player.character and player.character.inventory.room_for(item_id) > 0
	if magnet:
		_magnetized = true
		velocity = velocity.move_toward(to_player.normalized() * magnet_speed * TILE, magnet_accel * TILE * delta)
		global_position += velocity * delta
		if gap < pickup_tiles * TILE:
			_pick_up(player)
		return
	if _magnetized:
		# Lost the player (walked away, inventory full): don't keep the flying speed.
		_magnetized = false
		velocity = velocity.limit_length(max_loose_speed * TILE)
	# On the ground? (checked before gravity, which makes velocity.y non-zero again)
	var grounded := _on_ground()
	velocity.y = minf(velocity.y + gravity * TILE * delta, max_fall * TILE)
	velocity.x = move_toward(velocity.x, 0.0, (ground_friction if grounded else air_friction) * TILE * delta)
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
	_sprite.position.y = -_size * 0.5 - (absf(sin(_bob)) * 1.0 if _on_ground() else 0.0)


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
