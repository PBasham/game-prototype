class_name SeaFlora
extends Node2D
## Plants of the sea and its shore (Phase 56): seagrass and swaying kelp on the sea and
## pond floors, dune grass on dry beach sand. Decoration only: where they are comes from
## the world generator (WorldGenerator.sea_plant_at), and a plant shows while its ground
## is still there with room above it (dig the sand out and it's gone). Drawn over the
## water, tinted `underwater_tint` where they stand in it.

const TILE := World.TILE

## How far kelp tips sway (world pixels at the top), and how fast.
@export var kelp_sway_px := 2.5
@export var kelp_sway_speed := 1.3
@export var grass_sway_px := 0.6
## Plants under water are drawn this color (the water over them).
@export var underwater_tint := Color(0.55, 0.78, 0.95, 0.9)

var world: World
var _kelp: Texture2D
var _kelp_top: Texture2D
var _seagrass: Array[Texture2D] = []
var _dune: Array[Texture2D] = []
## Column -> generator plant (cached: the generator's answer never changes).
var _cache: Dictionary[int, Vector3i] = {}


func setup(w: World) -> void:
	world = w
	_kelp = load("res://assets/decor/kelp.png") as Texture2D
	_kelp_top = load("res://assets/decor/kelp_top.png") as Texture2D
	for i in 3:
		_seagrass.append(load("res://assets/decor/seagrass_%d.png" % i) as Texture2D)
	for i in 2:
		_dune.append(load("res://assets/decor/dune_grass_%d.png" % i) as Texture2D)


func plant_at(x: int) -> Vector3i:
	var wx := world.data.wrap_x(x)
	if not _cache.has(wx):
		_cache[wx] = world.generator.sea_plant_at(wx) if world.generator else Vector3i.ZERO
	return _cache[wx]


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null or world.player == null or world.generator == null:
		return
	var vp := get_viewport()
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var x0 := floori(view.position.x / TILE) - 1
	var x1 := ceili(view.end.x / TILE) + 1
	var y0 := floori(view.position.y / TILE) - 1
	var y1 := ceili(view.end.y / TILE) + 24
	var t := Time.get_ticks_msec() / 1000.0
	for x in range(x0, x1 + 1):
		var p := plant_at(x)
		if p.x == 0 or p.z < y0 or p.z > y1:
			continue
		var wx := world.data.wrap_x(x)
		if not world.is_solid(Vector2i(wx, p.z)) or world.is_solid(Vector2i(wx, p.z - 1)):
			continue
		var base := Vector2(x * TILE, p.z * TILE)
		var phase := t * kelp_sway_speed + x * 0.7
		match p.x:
			1:
				_draw_tuft(_seagrass[p.y % _seagrass.size()], base, Vector2(TILE, TILE), sin(phase) * grass_sway_px, _tint(base + Vector2(4, -4)))
			3:
				_draw_tuft(_dune[p.y % _dune.size()], base, Vector2(TILE, TILE * 1.5), sin(phase * 0.6) * grass_sway_px)
			2:
				for i in p.y:
					var ty := p.z - 1 - i
					if world.is_solid(Vector2i(wx, ty)):
						break
					var k := float(i + 1) / float(p.y)
					var sway := sin(phase - i * 0.35) * kelp_sway_px * k
					var tex := _kelp_top if i == p.y - 1 else _kelp
					draw_texture_rect(tex, Rect2(Vector2(base.x + sway, ty * TILE), Vector2(TILE, TILE)), false,
						_tint(Vector2(base.x + 4.0, ty * TILE + 4.0)))


func _draw_tuft(tex: Texture2D, base: Vector2, size: Vector2, sway: float, tint := Color.WHITE) -> void:
	# Lean the top: two halves, the upper one shifted by the sway.
	var half := size.y * 0.5
	draw_texture_rect_region(tex, Rect2(base + Vector2(sway, -size.y), Vector2(size.x, half)),
		Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height() * 0.5)), tint)
	draw_texture_rect_region(tex, Rect2(base + Vector2(0.0, -half), Vector2(size.x, half)),
		Rect2(Vector2(0.0, tex.get_height() * 0.5), Vector2(tex.get_width(), tex.get_height() * 0.5)), tint)


func _tint(p: Vector2) -> Color:
	return underwater_tint if world.voxels.liquid_at(Vector2(world.near_player_x(p.x), p.y)) else Color.WHITE
