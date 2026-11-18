class_name SpellZone
extends Node2D
## A ZONE spell's circle on the ground (Healing Circle): heals the player by
## `heal_per_second` (times spell power) while they stand in it, until its time runs out.

var world: World
var spell: SpellData
var power := 1.0
var radius := 40.0
var time_left := 10.0


func setup(w: World, s: SpellData, at: Vector2, spell_power: float) -> void:
	world = w
	spell = s
	power = spell_power
	radius = s.zone_tiles * World.TILE
	time_left = s.duration
	global_position = at
	z_index = 20


## Whether a point is inside the circle.
func covers(p: Vector2) -> bool:
	return p.distance_to(global_position) <= radius


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	var p := world.player
	if p and not p.dead and covers(p.chest()) and spell.heal_per_second > 0.0:
		p.heal(spell.heal_per_second * power * delta)
	queue_redraw()


func _draw() -> void:
	var c := spell.projectile_color
	var fade := clampf(time_left / 1.0, 0.0, 1.0)
	var t := Time.get_ticks_msec() * 0.002
	draw_circle(Vector2.ZERO, radius, Color(c, 0.08 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(c, 0.7 * fade), 1.0)
	draw_arc(Vector2.ZERO, radius * (0.55 + 0.1 * sin(t * 3.0)), 0.0, TAU, 32, Color(c, 0.3 * fade), 1.0)
	# Little motes rising.
	for i in 6:
		var a := TAU * i / 6.0 + t
		var y := fmod(t * 20.0 + i * 13.0, radius)
		draw_rect(Rect2(Vector2(cos(a) * radius * 0.6, -y + radius * 0.3), Vector2(1.5, 1.5)), Color(c, 0.8 * fade))
