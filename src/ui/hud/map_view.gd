class_name MapView
extends Control
## The full screen world map (N): what you've explored (WorldMap), centered on you when
## it opens. Mouse wheel zooms at the cursor, drag pans, N or Esc closes. Markers: you,
## your respawn point (a bed, else the world spawn). Sideways it wraps like the world.

## Screen pixels per map cell, its range, and the step per wheel notch.
@export var zoom := 3.0
@export var zoom_min := 0.5
@export var zoom_max := 16.0
@export var zoom_step := 1.25

var world: World
## The map cell at the middle of the screen.
var center := Vector2.ZERO
var _tex: ImageTexture
var _dragging := false
var _explored := 0.0


func _init(w: World) -> void:
	world = w
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		center = _player_cell()
		_refresh()
		_explored = world.world_map.explored_share() if world.world_map else 0.0
	queue_redraw()


func _player_cell() -> Vector2:
	var t := world.world_to_tile(world.player.chest())
	return Vector2(posmod(t.x, world.data.width), t.y) / float(WorldMap.CELL)


func _refresh() -> void:
	var m := world.world_map
	if m == null:
		return
	if _tex == null:
		_tex = ImageTexture.create_from_image(m.image)
	elif m.dirty:
		_tex.update(m.image)
	m.dirty = false


func _process(_delta: float) -> void:
	if visible:
		_refresh()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var before := screen_to_cell(mb.position)
		zoom = clampf(zoom * (zoom_step if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / zoom_step), zoom_min, zoom_max)
		center += before - screen_to_cell(mb.position)  # keep the cell under the cursor
		accept_event()
	elif mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		accept_event()
	var mm := event as InputEventMouseMotion
	if mm and _dragging:
		center -= mm.relative / zoom
		accept_event()


## The map cell under a point on the screen.
func screen_to_cell(p: Vector2) -> Vector2:
	return center + (p - size * 0.5) / zoom


func cell_to_screen(c: Vector2) -> Vector2:
	var w := float(world.world_map.size.x)
	var dx := wrapf(c.x - center.x, -w * 0.5, w * 0.5)
	return size * 0.5 + Vector2(dx, c.y - center.y) * zoom


func _draw() -> void:
	var m := world.world_map
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.97))
	if m == null or _tex == null:
		return
	var w := float(m.size.x)
	center.x = fposmod(center.x, w)
	center.y = clampf(center.y, 0.0, float(m.size.y))
	# Drawn up to three times sideways so the wrap never shows a gap.
	for k in [-1, 0, 1]:
		var origin := size * 0.5 - Vector2(center.x - k * w, center.y) * zoom
		var r := Rect2(origin, Vector2(m.size) * zoom)
		if r.end.x < 0.0 or r.position.x > size.x:
			continue
		draw_texture_rect(_tex, r, false)
	# You, and where you respawn.
	var spawn := world.world_to_tile(world.respawn_position())
	var sp := cell_to_screen(Vector2(posmod(spawn.x, world.data.width), spawn.y) / WorldMap.CELL)
	draw_rect(Rect2(sp - Vector2(3, 3), Vector2(6, 6)), Color(0.95, 0.8, 0.35))
	draw_rect(Rect2(sp - Vector2(3, 3), Vector2(6, 6)), Color(0.2, 0.12, 0.05), false, 1.0)
	var me := cell_to_screen(_player_cell())
	var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	draw_circle(me, 4.5, Color(0.1, 0.1, 0.2, 0.9))
	draw_circle(me, 3.0, Color(0.55, 0.8, 1.0, blink))
	var font := ThemeDB.fallback_font
	var text := "Map (N)   Explored %.1f%%   Wheel: zoom   Drag: move   N or Esc: close" % (_explored * 100.0)
	draw_string(font, Vector2(8, size.y - 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.85, 0.85, 0.9))
