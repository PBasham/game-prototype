class_name TestWorldGenerator
extends RefCounted
## Phase 1 test world (forest only): rolling surface, caves, copper, trees, flowers,
## and a movement test course near spawn. Any chunk is generated on demand from a pure
## function of (x, y), so it's instant and seamless across the wrap.
## Replaced by the real generator in Phase 2.
##
## Units are tiles (8 px). The Scholar is about 3 tiles wide and 8 tall.

## Spawn column. Close to x = 0 so the world seam is a short run to the left.
const SPAWN_X := 200
## The hand-made course spans this many tiles either side of spawn.
const COURSE := 140

var width: int
var height: int
var seed: int
var ground: int  ## surface row at spawn

var _b := {}  ## block ids by name
var _w := {}  ## wall ids by name


func _init(tiles: TileTypes, walls: TileTypes, world_width: int, world_height: int, world_seed: int) -> void:
	width = world_width
	height = world_height
	seed = world_seed
	ground = int(height * 0.3)
	for id in ["dirt", "grass", "stone", "copper_ore", "wood_planks", "wood_platform", "rope"]:
		_b[id] = tiles.index_of(StringName(id))
	for id in ["dirt_wall", "stone_wall", "wood_wall"]:
		_w[id] = walls.index_of(StringName(id))


func spawn_tile() -> Vector2i:
	return Vector2i(SPAWN_X, ground)


func generate_chunk(chunk: ChunkData) -> void:
	var ox := chunk.coord.x * ChunkData.SIZE
	var oy := chunk.coord.y * ChunkData.SIZE
	for ly in ChunkData.SIZE:
		for lx in ChunkData.SIZE:
			var i := ChunkData.local_index(lx, ly)
			chunk.blocks[i] = block_at(ox + lx, oy + ly)
			chunk.walls[i] = wall_at(ox + lx, oy + ly)


## Signed distance from spawn, the short way around the wrapped world.
func rel_x(x: int) -> int:
	return posmod(x - SPAWN_X + width / 2, width) - width / 2


func _hills(x: int) -> float:
	return 18.0 * GenUtil.wrap_wave(x, width, 9, 0.3) \
		+ 8.0 * GenUtil.wrap_wave(x, width, 29, 1.7) \
		+ 3.0 * GenUtil.wrap_wave(x, width, 83, 4.1)


func surface_at(x: int) -> int:
	var rx := absi(rel_x(x))
	var s := ground + roundi(_hills(x) - _hills(SPAWN_X))
	# Flat test course, blending back into hills.
	if rx <= COURSE:
		return ground
	if rx <= COURSE + 40:
		return roundi(lerpf(ground, s, (rx - COURSE) / 40.0))
	return s


## One tree candidate every 16 columns, about half of them used. None on the course
## except a few for scale.
func tree_at(x: int) -> int:
	var rx := rel_x(x)
	if rx == -110 or rx == 132:
		return floori(GenUtil.hash01(x, 1, seed) * 12.0)
	if absi(rx) <= COURSE:
		return -1
	var cell := floori(x / 16.0)
	if posmod(x, 16) != 3 + floori(GenUtil.hash01(cell, 2, seed) * 10.0):
		return -1
	if GenUtil.hash01(cell, 3, seed) > 0.55:
		return -1
	return floori(GenUtil.hash01(cell, 1, seed) * 12.0)


func flower_at(x: int) -> int:
	if tree_at(x) >= 0 or GenUtil.hash01(x, 7, seed) > 0.08:
		return -1
	return floori(GenUtil.hash01(x, 8, seed) * 5.0)


func block_at(x: int, y: int) -> int:
	var feature := _course_block(x, y)
	if feature != -1:
		return feature
	var s := surface_at(x)
	if y < s:
		return WorldData.AIR
	var depth := y - s
	if depth > 30 and _cave(x, y):
		return WorldData.AIR
	if depth == 0:
		return _b.grass
	var dirt_depth := 18 + floori(GenUtil.hash01(x / 6, 0, seed + 5) * 8.0)
	if depth < dirt_depth:
		# Pockets of stone poking up into the dirt.
		if depth > 8 and GenUtil.hash01(x / 6, y / 6, seed + 3) < 0.06:
			return _b.stone
		return _b.dirt
	# Pockets of dirt down in the stone, and copper veins.
	if GenUtil.hash01(x / 7, y / 7, seed + 9) < 0.08:
		return _b.dirt
	if GenUtil.hash01(x / 3, y / 3, seed + 11) < 0.035:
		return _b.copper_ore
	return _b.stone


func wall_at(x: int, y: int) -> int:
	var rx := rel_x(x)
	if rx >= 101 and rx <= 121 and y >= ground - 13 and y < ground:
		return _w.wood_wall
	var depth := y - surface_at(x)
	if depth < 4:
		return WorldData.AIR
	return _w.dirt_wall if depth < 24 else _w.stone_wall


func _cave(x: int, y: int) -> bool:
	var v := GenUtil.wrap_wave(x, width, 61, seed * 0.13) * sin(y * 0.055 + seed * 0.7) \
		+ 0.5 * sin(TAU * x * 149.0 / width + y * 0.025 + seed * 0.3)
	return v > 1.0


## Hand-placed movement test course around spawn. Returns -1 when no feature here.
func _course_block(x: int, y: int) -> int:
	var rx := rel_x(x)
	if rx < -95 or rx > 125:
		return -1
	var g := ground
	# Steps up: five 1-tile steps, each 3 tiles wide, then a plateau.
	if rx >= 20 and rx <= 40 and y < g:
		var step := mini((rx - 20) / 3 + 1, 5)
		if y >= g - step:
			return _b.grass if y == g - step else _b.dirt
	# Walls: 4 tall (small hop) and 10 tall (near a full jump).
	if rx >= 48 and rx <= 51 and y >= g - 4 and y < g:
		return _b.stone
	if rx >= 60 and rx <= 63 and y >= g - 10 and y < g:
		return _b.stone
	# Pit: 16 wide, 20 deep.
	if rx >= 72 and rx <= 87 and y >= g and y < g + 20:
		return WorldData.AIR
	# Floating wood platforms, stepping up to the left.
	if y == g - 8 and rx >= -28 and rx <= -14:
		return _b.wood_platform
	if y == g - 16 and rx >= -44 and rx <= -30:
		return _b.wood_platform
	if y == g - 24 and rx >= -26 and rx <= -12:
		return _b.wood_platform
	# Deep shaft (fall damage test): 8 wide, 90 deep.
	if rx >= -84 and rx <= -77 and y >= g and y < g + 90:
		return WorldData.AIR
	# Rope shaft next to it, joined at the bottom by a tunnel.
	if rx >= -68 and rx <= -64 and y >= g and y < g + 90:
		return _b.rope if rx == -66 and y < g + 88 else WorldData.AIR
	if rx >= -84 and rx <= -64 and y >= g + 78 and y < g + 90:
		return WorldData.AIR
	# House: plank frame, a doorway on the left, a platform shelf inside.
	if rx >= 100 and rx <= 122 and y >= g - 15 and y < g:
		if y <= g - 14:
			return _b.wood_planks
		if rx == 122 or (rx == 100 and y < g - 10):
			return _b.wood_planks
		if y == g - 7 and rx >= 104 and rx <= 112:
			return _b.wood_platform
		return WorldData.AIR
	return -1
