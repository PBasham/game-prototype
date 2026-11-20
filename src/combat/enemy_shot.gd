class_name EnemyShot
extends Node2D
## A bolt an enemy shoots at the player (the Forest Spirit's): flies straight, hurts the
## player on touch, fizzles on solid blocks or at the end of its range. Lives under
## World.effects.

const TILE := float(World.TILE)

var world: World
var velocity := Vector2.ZERO
var damage := 0.0
var knockback := 0.0
var color := Color(0.6, 0.8, 1.0)
var _range := 0.0
var _travelled := 0.0
var _trail: PackedVector2Array = []
var _dying := 0.0


func setup(w: World, vel: Vector2, dmg: float, range_px: float, push: float, tint: Color) -> void:
	world = w
	velocity = vel
	damage = dmg
	_range = range_px
	knockback = push
	color = tint


func _ready() -> void:
	z_index = 15


func _physics_process(delta: float) -> void:
	if _dying > 0.0:
		_dying -= delta
		queue_redraw()
		if _dying <= 0.0:
			queue_free()
		return
	var step := velocity * delta
	var n := maxi(1, ceili(step.length() / 3.0))
	for i in n:
		global_position += step / n
		_travelled += step.length() / n
		if world.is_solid(world.world_to_tile(global_position)):
			_fizzle()
			return
		var p := world.player
		if p and not p.dead:
			var body := p.body_rect()
			var dx := world.near_player_x(global_position.x) - global_position.x
			if body.has_point(global_position + Vector2(dx, 0)):
				p.take_damage(damage, &"enemy", global_position + Vector2(dx, 0), knockback)
				_fizzle()
				return
	if _travelled >= _range:
		_fizzle()
		return
	_trail.append(global_position)
	if _trail.size() > 6:
		_trail.remove_at(0)
	queue_redraw()


func _fizzle() -> void:
	_dying = 0.15
	velocity = Vector2.ZERO


func _draw() -> void:
	if _dying > 0.0:
		draw_circle(Vector2.ZERO, 5.0 * (1.0 - _dying / 0.15) + 1.0, Color(color, _dying / 0.15))
		return
	for i in _trail.size():
		var a := float(i + 1) / _trail.size()
		draw_circle(_trail[i] - global_position, 1.0 + a * 1.5, Color(color, 0.25 * a))
	draw_circle(Vector2.ZERO, 4.0, Color(color, 0.35))
	draw_circle(Vector2.ZERO, 2.2, Color(0.95, 0.98, 1.0))
