class_name LightOrb
extends Node2D
## The Light Orb spell: a glowing orb that floats beside the player's head and lights
## the area (a moving light source for the LightMap) until its time runs out. One at a
## time; casting again refreshes it.

## Where it floats, relative to the player's feet (px; x flips with facing).
@export var offset := Vector2(-14.0, -74.0)
## How quickly it catches up (higher = snappier).
@export var follow := 6.0

var world: World
var radius := 10.0
var color := Color(1.0, 0.92, 0.75)
var time_left := 180.0
var _last_tile := Vector2i(1 << 30, 0)


func _ready() -> void:
	add_to_group(&"light_sources")
	z_index = 25


func setup(w: World, spell: SpellData) -> void:
	world = w
	radius = spell.light_radius
	color = spell.light_color
	time_left = spell.duration
	global_position = _target()


func _target() -> Vector2:
	var p := world.player
	return p.global_position + Vector2(offset.x * p.facing, offset.y)


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	time_left -= delta
	if time_left <= 0.0:
		world.lights.mark_dirty()
		queue_free()
		return
	global_position = global_position.lerp(_target(), minf(follow * delta, 1.0))
	var t := light_tile()
	if t != _last_tile:
		_last_tile = t
		world.lights.mark_dirty()
	queue_redraw()


## The tile it lights from.
func light_tile() -> Vector2i:
	return world.world_to_tile(global_position)


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
	# Fades out over its last 5 seconds.
	var fade := clampf(time_left / 5.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 4.5 * pulse, Color(color, 0.25 * fade))
	draw_circle(Vector2.ZERO, 2.5, Color(color.lightened(0.4), fade))
