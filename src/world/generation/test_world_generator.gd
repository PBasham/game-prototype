class_name TestWorldGenerator
extends RefCounted
## Phase 1 test world: rolling surface, a few biome bands, caves, ores, and a
## movement test course near spawn. Generates any chunk on demand from a pure
## function of (x, y), so it's instant and seamless across the wrap.
## Replaced by the real generator in Phase 2.

## Spawn column. Close to x = 0 so the world seam is a short run to the left.
const SPAWN_X := 80

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
	for id in ["dirt", "grass", "stone", "sand", "snow", "ice", "mud", "clay", "wood_planks",
			"copper_ore", "iron_ore", "silver_ore", "gold_ore", "arcanite_ore", "wood_platform", "rope"]:
		_b[id] = tiles.index_of(StringName(id))
	for id in ["dirt_wall", "stone_wall", "wood_wall", "sandstone_wall"]:
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


func surface_at(x: int) -> int:
	var rx := rel_x(x)
	var s := ground + roundi(_hills(x) - _hills(SPAWN_X))
	# Flatten the test course, blending back to hills over 20 tiles.
	var flat := absi(rx)
	if flat <= 70:
		return ground
	if flat <= 90:
		return roundi(lerpf(ground, s, (flat - 70) / 20.0))
	return s


func _hills(x: int) -> float:
	return 9.0 * GenUtil.wrap_wave(x, width, 7, 0.3) \
		+ 4.0 * GenUtil.wrap_wave(x, width, 23, 1.7) \
		+ 1.5 * GenUtil.wrap_wave(x, width, 61, 4.1)


func biome_at(x: int) -> String:
	if x >= 200 and x < 420:
		return "desert"
	if x >= 600 and x < 800:
		return "snow"
	return "forest"


func block_at(x: int, y: int) -> int:
	var feature := _course_block(x, y)
	if feature != -1:
		return feature
	var s := surface_at(x)
	if y < s:
		return WorldData.AIR
	var depth := y - s
	if depth > 14 and _cave(x, y):
		return WorldData.AIR
	match biome_at(x):
		"desert":
			if depth < 12:
				return _b.sand
			if depth < 15:
				return _b.clay
		"snow":
			if depth < 4:
				return _b.snow
			if depth < 9:
				return _b.ice
		_:
			if depth == 0:
				return _b.grass
			if depth < 10:
				return _b.mud if GenUtil.hash01(x / 5, y / 5, seed + 3) < 0.04 else _b.dirt
	return _stone_or_ore(x, y, depth)


func wall_at(x: int, y: int) -> int:
	var rx := rel_x(x)
	if rx >= 51 and rx <= 58 and y >= ground - 7 and y < ground:
		return _w.wood_wall
	var depth := y - surface_at(x)
	if depth < 3:
		return WorldData.AIR
	if biome_at(x) == "desert" and depth < 15:
		return _w.sandstone_wall
	return _w.dirt_wall if depth < 12 else _w.stone_wall


func _stone_or_ore(x: int, y: int, depth: int) -> int:
	var r := GenUtil.hash01(x / 3, y / 3, seed + 11)
	if r < 0.035:
		if depth > 200 and r < 0.006:
			return _b.arcanite_ore
		if depth > 150:
			return _b.gold_ore
		if depth > 80:
			return _b.silver_ore
		return _b.copper_ore if r < 0.02 else _b.iron_ore
	return _b.stone


func _cave(x: int, y: int) -> bool:
	var v := GenUtil.wrap_wave(x, width, 41, seed * 0.13) * sin(y * 0.11 + seed * 0.7) \
		+ 0.5 * sin(TAU * x * 97.0 / width + y * 0.05 + seed * 0.3)
	return v > 1.0


## Hand-placed movement test course around spawn. Returns -1 when no feature here.
func _course_block(x: int, y: int) -> int:
	var rx := rel_x(x)
	if rx < -45 or rx > 66:
		return -1
	var g := ground
	# Steps up (1 tile each), then a plateau, then back down.
	if rx >= 10 and rx <= 18 and y < g:
		var step := mini(rx - 9, 5)
		if y >= g - step:
			return _b.grass if y == g - step else _b.dirt
	# Walls of height 2 and 5 (5 is a full jump).
	if rx >= 24 and rx <= 25 and y >= g - 2 and y < g:
		return _b.stone
	if rx >= 31 and rx <= 32 and y >= g - 5 and y < g:
		return _b.stone
	# Pit: 8 wide, 10 deep.
	if rx >= 38 and rx <= 45 and y >= g and y < g + 10:
		return WorldData.AIR
	# Floating wood platforms (stairs going up to the left).
	if y == g - 4 and rx >= -14 and rx <= -7:
		return _b.wood_platform
	if y == g - 8 and rx >= -21 and rx <= -15:
		return _b.wood_platform
	if y == g - 12 and rx >= -13 and rx <= -6:
		return _b.wood_platform
	# Deep shaft (fall damage test): 4 wide, 45 deep.
	if rx >= -42 and rx <= -39 and y >= g and y < g + 45:
		return WorldData.AIR
	# Rope shaft next to it, joined at the bottom by a tunnel.
	if rx >= -34 and rx <= -32 and y >= g and y < g + 45:
		return _b.rope if rx == -33 and y < g + 44 else WorldData.AIR
	if rx >= -42 and rx <= -32 and y >= g + 39 and y < g + 45:
		return WorldData.AIR
	# Small house: plank frame, door gap on the left, a platform shelf inside.
	if rx >= 50 and rx <= 59 and y >= g - 8 and y < g:
		if y == g - 8:
			return _b.wood_planks
		if rx == 59 or (rx == 50 and y < g - 4):
			return _b.wood_planks
		if y == g - 4 and rx >= 53 and rx <= 56:
			return _b.wood_platform
		return WorldData.AIR
	return -1
