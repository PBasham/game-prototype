class_name ThrownItem
extends Node2D
## A thrown item (the Poison Flask) flying in an arc. It shatters on the first solid
## tile or enemy it touches and leaves its throw_effect there.

const TILE := World.TILE
## Gravity in tiles per second squared.
const GRAVITY := 60.0

var world: World
var item: ItemData
var velocity := Vector2.ZERO
var _life := 4.0
var _spin := 0.0


func launch(w: World, it: ItemData, from: Vector2, vel: Vector2) -> void:
	world = w
	item = it
	global_position = from
	velocity = vel
	z_index = 5


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * TILE * delta
	var steps := maxi(1, ceili(velocity.length() * delta / 2.0))
	for i in steps:
		global_position += velocity * delta / steps
		if world.blocks_hits(world.world_to_tile(global_position)) or world.voxels.solid_at(global_position) or _hits_enemy():
			_shatter()
			return
	_spin += delta * 12.0
	rotation = _spin
	_life -= delta
	if _life <= 0.0:
		_shatter()


func _hits_enemy() -> bool:
	for node in get_tree().get_nodes_in_group(&"damageable"):
		if node == world.player or not is_instance_valid(node):
			continue
		if (node.call(&"hit_rect") as Rect2).has_point(global_position):
			return true
	return false


func _shatter() -> void:
	if item.throw_effect == &"explosion":
		world.request_explode(global_position, item.explosion_radius_tiles, item.explosion_damage, item.explosion_power)
		queue_free()
		return
	EventBus.sound_requested.emit(&"block_break", global_position)
	if item.throw_effect == &"poison_cloud":
		var c := PoisonCloud.new()
		world.add_child(c)
		c.start(world, item, global_position)
	queue_free()


func _draw() -> void:
	if item and item.icon:
		draw_texture_rect(item.icon, Rect2(-8, -8, 16, 16), false)  # detailed icons too
