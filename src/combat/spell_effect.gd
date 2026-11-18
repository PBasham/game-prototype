class_name SpellEffect
extends Node2D
## A short spell flash drawn in the world, then gone: BURST (a ring and sparks, Blink),
## GUST (streaks fanning out in a cone, Air Push), SPLAT (gel blobs flying out sideways
## from the feet, Gel Cushion), ZAP (jagged lightning through `points`, Chain Spark),
## RITUAL (a ring closing in on `follow` over the ritual's time, Recall) or SHIELD (a
## bubble around `follow`, Barrier). Placeholder look.

enum Kind { BURST, GUST, SPLAT, ZAP, RITUAL, SHIELD }

@export var lifetime := 0.3

var kind := Kind.BURST
## GUST: direction and length of the cone (px), and its half angle (degrees).
var reach := Vector2.ZERO
var angle := 35.0
var color := Color.WHITE
## ZAP: the path, in world space.
var points := PackedVector2Array()
## RITUAL and SHIELD: stays on this node.
var follow: Node2D
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
	if k == Kind.SPLAT:
		e.lifetime = 0.6
	e.global_position = at
	e.z_index = 30
	for i in 12:
		e._seeds.append(randf())
	parent.add_child(e)
	return e


func _process(delta: float) -> void:
	_age += delta
	if follow:
		if not is_instance_valid(follow):
			queue_free()
			return
		global_position = follow.global_position + Vector2(0, -30)
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
		Kind.ZAP:
			for i in points.size() - 1:
				var a := to_local(points[i])
				var b := to_local(points[i + 1])
				var prev := a
				for k in range(1, 7):
					var q := a.lerp(b, k / 6.0)
					if k < 6:
						q += (b - a).orthogonal().normalized() * (_seeds[(i + k) % _seeds.size()] - 0.5) * 6.0
					draw_line(prev, q, c, 1.0)
					draw_line(prev, q, Color(1, 1, 1, c.a * 0.8), 0.5)
					prev = q
		Kind.RITUAL:
			var r := lerpf(26.0, 8.0, t)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(color, 0.8), 1.0)
			draw_arc(Vector2.ZERO, 30.0, -PI * 0.5, -PI * 0.5 + TAU * t, 36, Color(color, 0.5), 1.0)
		Kind.SHIELD:
			var pulse := 0.7 + 0.3 * sin(_age * 6.0)
			draw_circle(Vector2.ZERO, 22.0, Color(color, 0.08 * pulse))
			draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 40, Color(color, 0.6 * pulse), 1.0)
		Kind.SPLAT:
			# A flattened puddle, then blobs thrown out and falling.
			var w := 10.0 + 10.0 * t
			draw_rect(Rect2(-w, -2.0, w * 2.0, 2.0), c)
			for i in _seeds.size():
				var side := -1.0 if i % 2 == 0 else 1.0
				var vx := side * (20.0 + 40.0 * _seeds[i])
				var vy := -(30.0 + 30.0 * _seeds[(i + 3) % _seeds.size()])
				var tt := t * lifetime
				var at := Vector2(vx * tt, vy * tt + 160.0 * tt * tt)
				draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), c)
		Kind.GUST:
			for i in _seeds.size():
				var a := deg_to_rad(lerpf(-angle, angle, float(i) / (_seeds.size() - 1)))
				var dir := reach.rotated(a)
				var head := dir * clampf(t * 1.4 + _seeds[i] * 0.2, 0.0, 1.0)
				var tail := dir * clampf(t * 1.4 - 0.25 + _seeds[i] * 0.2, 0.0, 1.0)
				draw_line(tail, head, c, 1.0)
