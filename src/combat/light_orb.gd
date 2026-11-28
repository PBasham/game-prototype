class_name LightOrb
extends Node2D
## A spell light (a moving light source for the LightMap) until its time runs out.
## Light Orb: floats beside the player's head; one at a time, casting again refreshes
## it. Wisp (`placed`): follows the cursor while the cast button is held (within
## `steer_reach` tiles of you), then stays where you let go.

## Where it floats, relative to the player's feet (px; x flips with facing).
@export var offset := Vector2(-14.0, -74.0)
## How quickly it catches up (higher = snappier).
@export var follow := 6.0

var world: World
var radius := 10.0
var color := Color(1.0, 0.92, 0.75)
var time_left := 180.0
## A Wisp: steered with the cursor, then left in place.
var placed := false
## Still being steered (the button hasn't been let go yet).
var steering := false
var steer_button: StringName = &"use_primary"
## How far from the player it can be steered (tiles).
@export var steer_reach := 24.0
## Drawn as a little torch (Floating Torch) instead of an orb.
var torch := false
## Which spell made it (Wisps of one spell count toward its light_max).
var spell_id: StringName = &""
var _last_tile := Vector2i(1 << 30, 0)


func _ready() -> void:
	add_to_group(&"light_sources")
	z_index = 25


func setup(w: World, spell: SpellData) -> void:
	world = w
	radius = spell.light_radius
	color = spell.light_color
	time_left = INF if spell.light_endless > 0 else spell.duration
	torch = spell.light_torch
	placed = spell.light_placed
	steering = placed
	spell_id = spell.id
	global_position = _target()


func _target() -> Vector2:
	var p := world.player
	if placed:
		if not steering:
			return global_position
		var to := world.item_user.cursor() - p.chest()
		return p.chest() + to.limit_length(steer_reach * World.TILE)
	return p.global_position + Vector2(offset.x * p.facing, offset.y)


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	time_left -= delta
	if time_left <= 0.0:
		world.lights.mark_dirty()
		queue_free()
		return
	if steering and not Input.is_action_pressed(steer_button):
		steering = false  # let go: it stays here
	global_position = global_position.lerp(_target(), minf((follow * 2.0 if placed else follow) * delta, 1.0))
	var t := Vector2i((light_point() * 4.0).floor())  # every quarter tile: it glides
	if t != _last_tile:
		_last_tile = t
		world.lights.mark_dirty()
	queue_redraw()


## The tile it lights from.
func light_point() -> Vector2:
	return global_position / World.TILE


func light_tile() -> Vector2i:
	return world.world_to_tile(global_position)


func _draw() -> void:
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
	# Fades out over its last 5 seconds.
	var fade := clampf(time_left / 5.0, 0.0, 1.0)
	if torch:
		_draw_torch(fade)
		return
	draw_circle(Vector2.ZERO, 4.5 * pulse, Color(color, 0.25 * fade))
	draw_circle(Vector2.ZERO, 2.5, Color(color.lightened(0.4), fade))
	if steering:
		draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, Color(color, 0.6), 1.0)


## The Floating Torch: a little wooden torch, bobbing, its flame flickering.
func _draw_torch(fade: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var bob := Vector2(0, sin(t * 2.2) * 1.2)
	draw_set_transform(bob, sin(t * 1.7) * 0.12)
	draw_rect(Rect2(-1, 1, 2, 7), Color(0.45, 0.28, 0.14, fade))  # the handle
	draw_rect(Rect2(-1, 1, 1, 7), Color(0.6, 0.4, 0.2, fade))
	draw_rect(Rect2(-1.5, 0, 3, 1.5), Color(0.3, 0.3, 0.32, fade))  # the band
	var flick := 1.0 + 0.18 * sin(t * 23.0) + 0.1 * sin(t * 37.0)
	draw_circle(Vector2(0, -2), 4.0 * flick, Color(color, 0.22 * fade))
	draw_circle(Vector2(0, -1.5), 2.2 * flick, Color(1.0, 0.55, 0.2, fade))
	draw_circle(Vector2(0, -2.2), 1.3 * flick, Color(1.0, 0.92, 0.6, fade))
	draw_set_transform(Vector2.ZERO)

