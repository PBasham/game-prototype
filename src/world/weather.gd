class_name Weather
extends Node2D
## Rain (Phase 81). Showers start at random on the surface, a few a day, and fade in and
## out. Rain darkens the sky a little (WorldClock.overcast), falls as streaks that stop on
## the first block below the top of the screen (so roofs keep it off), and fills Rain
## Catchers (ObjectDef.catches_rain) that have open sky above them. It adds no water to
## the world itself.

## Chance a shower starts in any in-game hour without one.
@export_range(0.0, 1.0) var rain_chance_per_hour := 0.07
## How long a shower lasts, in real minutes, picked between these.
@export var rain_minutes_min := 1.0
@export var rain_minutes_max := 3.0
## Seconds rain takes to fade in or out.
@export var fade_seconds := 5.0
## How much darker the sky light gets in full rain (0 = none, 1 = black).
@export_range(0.0, 1.0) var overcast := 0.3
## Streaks on screen in full rain, and how they look.
@export var drops := 500
@export var drop_speed := 520.0  ## px a second
@export var drop_length := 10.0
@export var drop_slant := 0.18  ## sideways px per px down
@export var drop_color := Color(0.74, 0.82, 0.96, 0.6)
## How often Rain Catchers are checked (seconds).
@export var catch_interval := 1.0

var raining := false
var rain_left := 0.0  ## seconds of this shower left
var intensity := 0.0  ## 0 dry, 1 full rain (fades)

var world: World
var _drops: PackedVector2Array = PackedVector2Array()
var _catch_t := 0.0
var _catch_carry: Dictionary[Vector2i, float] = {}  ## fractions of a cell per catcher
var _column_floor: Dictionary[int, float] = {}  ## rain's bottom per tile column (px), refreshed
var _floor_t := 0.0


func _ready() -> void:
	z_index = 50
	for i in drops:
		_drops.append(Vector2(randf(), randf()))


func _process(delta: float) -> void:
	if world == null or world.clock == null:
		return
	var game_delta := delta * world.clock.speed
	if raining:
		rain_left -= delta
		if rain_left <= 0.0:
			raining = false
	elif randf() < rain_chance_per_hour * game_delta / _seconds_per_hour():
		start_rain()
	intensity = move_toward(intensity, 1.0 if raining else 0.0, delta / maxf(fade_seconds, 0.01))
	world.clock.overcast = intensity * overcast
	_catch_t += delta
	if _catch_t >= catch_interval:
		fill_catchers(_catch_t)
		_catch_t = 0.0
	visible = intensity > 0.0
	if visible:
		_floor_t -= delta
		if _floor_t <= 0.0:
			_floor_t = 0.25
			_refresh_floors()
		for i in _drops.size():
			_drops[i].y += delta * drop_speed / 600.0
			if _drops[i].y > 1.0:
				_drops[i] = Vector2(randf(), _drops[i].y - 1.0)
		queue_redraw()


func _seconds_per_hour() -> float:
	return maxf(world.clock.days(1.0 / 24.0), 0.001)


## Starts a shower now (the dev console's `rain on` too).
func start_rain(minutes: float = -1.0) -> void:
	raining = true
	if minutes <= 0.0:
		minutes = randf_range(rain_minutes_min, rain_minutes_max)
	rain_left = minutes * 60.0


func stop_rain() -> void:
	raining = false
	rain_left = 0.0


## Adds water to every Rain Catcher under open sky, for `seconds` of rain at the
## current intensity. Returns the cells added (all catchers).
func fill_catchers(seconds: float) -> int:
	if intensity <= 0.0:
		return 0
	var added := 0
	for a: Vector2i in world.liquids.keys():
		var def := world.object_at(a)
		if def == null or def.catches_rain <= 0.0:
			continue
		if world.liquids.get(a, 0) >= def.liquid_capacity or not sky_open(a, def):
			continue
		var amount: float = _catch_carry.get(a, 0.0) + def.catches_rain / 60.0 * seconds * intensity
		var whole := floori(amount)
		_catch_carry[a] = amount - whole
		if whole > 0:
			added += world.request_barrel_water(a, whole)
	return added


## True when nothing solid is above the object's top, up to the top of the world (parts
## of the world not loaded count as open).
func sky_open(anchor: Vector2i, def: ObjectDef) -> bool:
	for dx in def.width_tiles:
		var x := world.data.wrap_x(anchor.x + dx)
		for y in range(anchor.y - def.height_tiles, -1, -1):
			var chunk := world.data.peek_chunk(Vector2i(x >> 5, y >> 5))
			if chunk == null:
				break
			if world.data.get_block(x, y) != WorldData.AIR:
				return false
	return true


## For each column on screen: the first solid tile at or below the screen's top (where
## the rain stops). Columns whose screen top is underground get no rain.
func _refresh_floors() -> void:
	_column_floor.clear()
	var view := _view_rect()
	var gen := world.generator
	var top := floori(view.position.y / World.TILE)
	var bottom := ceili(view.end.y / World.TILE)
	for x in range(floori(view.position.x / World.TILE) - 2, ceili(view.end.x / World.TILE) + 3):
		var wx := world.data.wrap_x(x)
		if gen and top > gen.surface_at(wx) + 2:
			_column_floor[x] = -INF  # underground: no sky here
			continue
		var stop := float(view.end.y) + 8.0
		for y in range(maxi(top, 0), bottom + 1):
			if world.data.get_block(wx, y) != WorldData.AIR:
				stop = y * World.TILE
				break
		_column_floor[x] = stop


func _view_rect() -> Rect2:
	var vp := get_viewport()
	var cam := vp.get_camera_2d()
	var size := vp.get_visible_rect().size
	if cam:
		size /= cam.zoom
		return Rect2(cam.get_screen_center_position() - size * 0.5, size)
	return Rect2(Vector2.ZERO, size)


func _draw() -> void:
	if intensity <= 0.0:
		return
	var view := _view_rect()
	var count := int(_drops.size() * intensity)
	var col := drop_color
	var step := Vector2(drop_slant, 1.0).normalized() * drop_length
	for i in count:
		var d := _drops[i]
		var p := view.position + Vector2(d.x * (view.size.x + 40.0) - 20.0, d.y * view.size.y)
		var floor_y: float = _column_floor.get(floori(p.x / World.TILE), view.end.y + 8.0)
		if p.y + step.y > floor_y:
			continue
		draw_line(p, p + step, col, 1.0)


func to_dict() -> Dictionary:
	return {"raining": raining, "left": rain_left}


func from_dict(d: Dictionary) -> void:
	raining = bool(d.get("raining", false))
	rain_left = float(d.get("left", 0.0))
	intensity = 1.0 if raining else 0.0
