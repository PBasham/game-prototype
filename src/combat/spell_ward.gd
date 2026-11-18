class_name SpellWard
extends Node2D
## A WARD spell's rune on the ground (Spark Ward): the first enemy to touch it takes
## `damage` (times spell power) and `knockback`, then the rune is spent. Fades when its
## time runs out.

var world: World
var spell: SpellData
var power := 1.0
var time_left := 120.0
var _armed := 0.3  # a moment before it can trigger


func setup(w: World, s: SpellData, ground: Vector2, spell_power: float) -> void:
	world = w
	spell = s
	power = spell_power
	time_left = s.duration
	global_position = ground
	z_index = 4
	add_to_group(&"spell_wards")


## The trigger area (world space): two tiles wide, a little above the ground.
func trigger_rect() -> Rect2:
	return Rect2(global_position + Vector2(-8.0, -10.0), Vector2(16.0, 10.0))


func _process(delta: float) -> void:
	time_left -= delta
	_armed -= delta
	if time_left <= 0.0:
		queue_free()
		return
	if _armed <= 0.0 and Game.is_authority():
		for e in world.enemies():
			if trigger_rect().intersects(e.hit_rect()):
				_trigger(e)
				return
	queue_redraw()


func _trigger(e: Enemy) -> void:
	e.take_damage(spell.damage * power, world.player)
	e.knock_back(global_position + Vector2(0, 8), spell.knockback)
	SpellEffect.spawn(world.effects, SpellEffect.Kind.BURST, global_position + Vector2(0, -4), Vector2.ZERO,
		spell.projectile_color)
	EventBus.sound_requested.emit(&"ward_trigger", global_position)
	queue_free()


func _draw() -> void:
	var c := spell.projectile_color
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
	var a := (0.5 + 0.5 * pulse) * clampf(time_left / 2.0, 0.0, 1.0)
	# A flat rune: a diamond with a ring.
	var pts := PackedVector2Array([Vector2(-7, -1), Vector2(0, -4), Vector2(7, -1), Vector2(0, 2), Vector2(-7, -1)])
	draw_polyline(pts, Color(c, a), 1.0)
	draw_arc(Vector2(0, -1), 3.0, 0.0, TAU, 12, Color(c, a * 0.8), 1.0)
