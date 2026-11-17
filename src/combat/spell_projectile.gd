class_name SpellProjectile
extends Node2D
## A spell bolt (Spark): flies straight, hurts the first damageable thing it touches,
## fizzles on solid blocks or at the end of its range. Spawn with
## World.request_spawn_projectile (host-authoritative).
##
## Damageable things are nodes in the "damageable" group with `hit_rect() -> Rect2`
## (world space) and `take_damage(amount: float, from: Node)`. Nothing has health yet
## except the dev training dummy (console: `dummy`).

const TILE := float(World.TILE)

var world: World
var spell: SpellData
var direction := Vector2.RIGHT
var power := 1.0
var source: Node
var _travelled := 0.0
var _trail: PackedVector2Array = []
var _dying := 0.0


func _ready() -> void:
	z_index = 15


func _physics_process(delta: float) -> void:
	if _dying > 0.0:
		_dying -= delta
		queue_redraw()
		if _dying <= 0.0:
			queue_free()
		return
	var step := spell.projectile_speed * TILE * delta
	# Sub-steps so a fast bolt can't skip through a 1-tile wall or a thin target.
	var n := maxi(1, ceili(step / 3.0))
	for i in n:
		global_position += direction * (step / n)
		_travelled += step / n
		if world.is_solid(world.world_to_tile(global_position)):
			_fizzle()
			return
		for node in get_tree().get_nodes_in_group(&"damageable"):
			if node != source and (node.call(&"hit_rect") as Rect2).has_point(global_position):
				node.call(&"take_damage", spell.damage * power, source)
				_fizzle()
				return
	if _travelled >= spell.projectile_range * TILE:
		_fizzle()
		return
	_trail.append(global_position)
	if _trail.size() > 6:
		_trail.remove_at(0)
	queue_redraw()


func _fizzle() -> void:
	_dying = 0.15


func _draw() -> void:
	var c := spell.projectile_color
	if _dying > 0.0:
		var k := _dying / 0.15
		draw_circle(Vector2.ZERO, 3.0 * (1.5 - k), Color(c, 0.6 * k))
		return
	for i in _trail.size():
		var a := float(i + 1) / _trail.size()
		draw_circle(to_local(_trail[i]), 0.6 + a, Color(c, 0.35 * a))
	draw_circle(Vector2.ZERO, 2.5, Color(c, 0.35))
	draw_circle(Vector2.ZERO, 1.2, Color(1, 1, 1, 0.95))
