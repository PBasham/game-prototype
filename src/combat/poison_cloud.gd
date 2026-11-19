class_name PoisonCloud
extends Node2D
## A green cloud left by a Poison Flask: poisons every enemy inside it (and keeps
## re-poisoning them) until it fades.

var world: World
var item: ItemData
var _left := 0.0
var _size := Vector2.ZERO
var _tick := 0.0


func start(w: World, it: ItemData, at: Vector2) -> void:
	world = w
	item = it
	global_position = at
	_left = it.cloud_seconds
	_size = it.cloud_tiles * World.TILE
	z_index = 6
	_poison_inside()


func _process(delta: float) -> void:
	_left -= delta
	_tick += delta
	if _tick >= 0.5:
		_tick = 0.0
		_poison_inside()
	queue_redraw()
	if _left <= 0.0:
		queue_free()


func area() -> Rect2:
	return Rect2(global_position - Vector2(_size.x * 0.5, _size.y * 0.75), _size)


func _poison_inside() -> void:
	var r := area()
	for node in get_tree().get_nodes_in_group(&"damageable"):
		if node == world.player or not is_instance_valid(node) or not node.has_method(&"poison"):
			continue
		if r.intersects(node.call(&"hit_rect")):
			node.call(&"poison", item.poison_dps, item.poison_seconds)


func _draw() -> void:
	var r := area()
	r.position -= global_position
	var a := clampf(_left / maxf(item.cloud_seconds, 0.01), 0.0, 1.0) * 0.45
	var t := Time.get_ticks_msec() * 0.002
	for i in 9:
		var p := r.position + Vector2(fposmod(i * 0.37 + sin(t + i) * 0.05, 1.0) * r.size.x, fposmod(i * 0.61 + cos(t * 0.7 + i) * 0.05, 1.0) * r.size.y)
		draw_circle(p, r.size.y * 0.35, Color(0.45, 0.85, 0.3, a * 0.6))
