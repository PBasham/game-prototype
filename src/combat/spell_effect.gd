class_name SpellEffect
extends Node2D
## A short spell flash drawn in the world, then gone: BURST (a ring and sparks, Blink)
## or GUST (streaks fanning out in a cone, Air Push). Placeholder look.

enum Kind { BURST, GUST }

@export var lifetime := 0.3

var kind := Kind.BURST
## GUST: direction and length of the cone (px), and its half angle (degrees).
var reach := Vector2.ZERO
var angle := 35.0
var color := Color.WHITE
var _age := 0.0
var _seeds := PackedFloat32Array()


static func spawn(parent: Node, k: Kind, at: Vector2, cone: Vector2, c: Color, half_angle: float = 35.0) -> SpellEffect:
	if parent == null:
		return null
	var e := SpellEffect.new()
	e.kind = k
	e.reach = cone
	e.angle = half_angle
	e.color = c
	e.global_position = at
	e.z_index = 30
	for i in 12:
		e._seeds.append(randf())
	parent.add_child(e)
	return e


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / lifetime
	var c := color
	c.a = 1.0 - t
	match kind:
		Kind.BURST:
			draw_arc(Vector2.ZERO, 4.0 + 18.0 * t, 0.0, TAU, 24, c, 1.5)
			for i in _seeds.size():
				var dir := Vector2.from_angle(TAU * float(i) / _seeds.size() + _seeds[i])
				draw_rect(Rect2(dir * (6.0 + 22.0 * t * (0.6 + _seeds[i])), Vector2(1.5, 1.5)), c)
		Kind.GUST:
			for i in _seeds.size():
				var a := deg_to_rad(lerpf(-angle, angle, float(i) / (_seeds.size() - 1)))
				var dir := reach.rotated(a)
				var head := dir * clampf(t * 1.4 + _seeds[i] * 0.2, 0.0, 1.0)
				var tail := dir * clampf(t * 1.4 - 0.25 + _seeds[i] * 0.2, 0.0, 1.0)
				draw_line(tail, head, c, 1.0)
