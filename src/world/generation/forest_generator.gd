class_name ForestGenerator
extends WorldGenerator
## The forest world: rolling hills with a few big ones and rare cliffs, a flat spawn,
## dirt over stone, tunnels and deep caverns, surface cave entrances, copper blobs, and
## tree groves with flowery clearings.
##
## Every tunable lives in ForestGenSettings (data/worldgen/forest.tres). How each one
## works, and how to tweak them, is in docs/world-generation.md.
##
## Seamless wrap: all noise is sampled on a cylinder. Column x maps to an angle around a
## circle whose circumference is the world width (so 1 unit is about 1 tile), and y runs
## along the cylinder. Column width - 1 and column 0 are neighbors in the noise too.
##
## Thread safety: _init builds everything; afterwards only reads happen, so chunks can
## be generated on any number of worker threads at once.

var settings: ForestGenSettings

var _radius: float
var _spawn_raw: float  ## unflattened surface height at spawn

# Surface shape.
var _hills: FastNoiseLite
var _big: FastNoiseLite
var _cliff: FastNoiseLite
var _cliff_mask: FastNoiseLite
var _cliff_size: FastNoiseLite
# Layers.
var _dirt_depth: FastNoiseLite
var _dirt_edge: FastNoiseLite
var _dirt_pockets: FastNoiseLite
var _stone_pockets: FastNoiseLite
var _dark_wobble: FastNoiseLite
var _dark_fringe: FastNoiseLite
## Block and wall swaps inside the Dark Forest (plain id index -> dark id index).
var _dark_blocks: Dictionary[int, int] = {}
var _dark_walls: Dictionary[int, int] = {}
# Caves.
var _tunnels: FastNoiseLite
var _tunnel_mask: FastNoiseLite
var _caverns: FastNoiseLite
# Surface life.
var _groves: FastNoiseLite

# Precomputed thresholds and scales (see _init).
var _big_t: float
var _cliff_t: float
var _cliff_k: float
var _tunnel_t: float
var _tunnel_mask_t: float
var _tunnel_cut: FastNoiseLite
var _tunnel_cut_t: float
var _dirt_pocket_t: float
var _stone_pocket_t: float
var _grove_t: float
var _cavern_t_top: float
var _cavern_t_deep: float
var _entrance_cells: int
var _entrance_cell_w: float
## Dark Forest patches: [center x, half width] each.
var _dark: Array[Vector2] = []
# Ocean and ponds (Phase 55).
var _sea := 0  ## sea level row: water fills rows at or below it
var _ocean_c := -1  ## middle column, -1 = no ocean
var _ocean_half := 0.0  ## half the water's width at sea level
var _ocean_floor: FastNoiseLite
var _beach_mix: FastNoiseLite
## Ponds: [center x, half width, depth, water row] each.
var _ponds: Array[Vector4] = []


func _init(tiles: TileTypes, walls: TileTypes, world_width: int, world_height: int,
		world_seed: int, gen_settings: ForestGenSettings = null) -> void:
	super(tiles, walls, world_width, world_height, world_seed)
	settings = gen_settings if gen_settings != null else default_settings()
	var s := settings
	_radius = width / TAU

	_hills = _noise(1, 1.0 / s.hill_width, s.hill_detail)
	_big = _noise(2, 1.0 / s.big_hill_width)
	_cliff = _noise(3, 1.0 / s.cliff_spacing)
	_cliff_mask = _noise(4, 1.0 / (s.cliff_spacing * 3.0))
	_cliff_size = _noise(5, 1.0 / s.cliff_spacing)
	_dirt_depth = _noise(6, 1.0 / s.dirt_depth_width, 2)
	_dirt_edge = _noise(13, 1.0 / 7.0)
	_dirt_pockets = _noise(7, 1.0 / s.dirt_pocket_size, 2)
	_stone_pockets = _noise(8, 1.0 / 10.0, 2)
	_dark_wobble = _noise(15, 1.0 / maxf(s.dark_forest_wobble_length, 10.0), 2)
	_dark_fringe = _noise(16, 1.0 / 4.0)
	for pair: Array in [[&"dirt", &"dark_forest_dirt"], [&"grass", &"dark_forest_grass"], [&"stone", &"dark_forest_stone"]]:
		if _b.get(pair[0], -1) > 0 and _b.get(pair[1], -1) > 0:
			_dark_blocks[_b[pair[0]]] = _b[pair[1]]
	for pair: Array in [[&"dirt_wall", &"dark_forest_dirt_wall"], [&"stone_wall", &"dark_forest_stone_wall"]]:
		if _w.get(pair[0], -1) > 0 and _w.get(pair[1], -1) > 0:
			_dark_walls[_w[pair[0]]] = _w[pair[1]]
	_tunnels = _noise(9, 1.0 / s.tunnel_spacing, 2)
	_tunnel_mask = _noise(10, 1.0 / (s.tunnel_spacing * 2.0))
	_tunnel_cut = _noise(14, 1.0 / maxf(s.tunnel_length, 20.0), 2)
	_caverns = _noise(11, 1.0 / s.cavern_size, 3)
	_groves = _noise(12, 1.0 / s.grove_width, 2)

	_big_t = _calibrate(_big, s.big_hill_amount, false)
	_cliff_t = _calibrate(_cliff_mask, s.cliff_amount, false)
	# A cliff step completes over about cliff_face_width tiles.
	_cliff_k = s.cliff_spacing / (maxf(s.cliff_face_width, 0.5) * 2.5)
	# |noise| < t gives ribbons about tunnel_width tall.
	_tunnel_t = s.tunnel_width / s.tunnel_spacing * 0.9
	_tunnel_mask_t = _calibrate(_tunnel_mask, s.tunnel_coverage, true, 0.5)
	_tunnel_cut_t = _calibrate(_tunnel_cut, 1.0 - s.tunnel_breaks, true, 0.5)
	_dirt_pocket_t = _calibrate(_dirt_pockets, s.dirt_pocket_amount, true)
	_stone_pocket_t = _calibrate(_stone_pockets, s.stone_pocket_amount, true)
	_grove_t = _calibrate(_groves, s.grove_amount, false)
	_cavern_t_top = _calibrate(_caverns, s.cavern_amount_top, true)
	_cavern_t_deep = _calibrate(_caverns, s.cavern_amount_deep, true)
	_entrance_cells = maxi(1, roundi(float(width) / maxf(s.entrance_spacing, 50)))
	_entrance_cell_w = float(width) / _entrance_cells
	_spawn_raw = _raw_surface(s.spawn_x)
	_place_dark_forests()
	_place_ocean()
	_place_ponds()


## Spreads the Dark Forest patches evenly around the world (from the far side of spawn
## outward), each nudged a little by the seed, never within dark_forest_spawn_clear.
func _place_dark_forests() -> void:
	var s := settings
	_dark.clear()
	var total := s.dark_forest_share * width
	if total < 20.0:
		return
	var count := s.dark_forest_patches
	if count <= 0:
		count = maxi(1, roundi(total / maxf(s.dark_forest_patch_tiles, 50)))
	var half := total / count * 0.5
	var step := float(width) / count
	for i in count:
		var c := s.spawn_x + step * (i + 0.5)
		if count == 1:
			# One big region on one side of spawn (east or west by seed).
			var side := 1.0 if GenUtil.hash01(0, 25, seed) < 0.5 else -1.0
			c = s.spawn_x + side * s.dark_forest_distance * width
		else:
			c += (GenUtil.hash01(i, 21, seed) - 0.5) * maxf(step - half * 2.0, 0.0) * 0.5
		# Keep spawn clear: push the patch away from it if it came too close.
		var d := float(wrap_delta(roundi(c), s.spawn_x))
		var need := half + s.dark_forest_spawn_clear
		if absf(d) < need:
			c = s.spawn_x + signf(d if d != 0.0 else 1.0) * need
		_dark.append(Vector2(fposmod(c, width), half))


func dark_forest_at(x: int) -> float:
	if ocean_at(x) > 0.0:
		return 0.0
	var best := 0.0
	var edge := maxf(settings.dark_forest_edge_tiles, 1.0)
	for p in _dark:
		var d := absf(float(wrap_delta(x, roundi(p.x))))
		best = maxf(best, clampf((p.y - d) / edge + 0.5, 0.0, 1.0))
	return smoothstep(0.0, 1.0, best)


## The Dark Forest patches (center x, half width), for the world map preview.
func dark_forests() -> Array[Vector2]:
	return _dark.duplicate()


## The settings file, as saved on disk. `fresh` skips Godot's resource cache so edits
## saved in the editor while the game runs are picked up (F6 regenerate).
static func default_settings(fresh: bool = false) -> ForestGenSettings:
	const PATH := "res://data/worldgen/forest.tres"
	if fresh:
		return ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ForestGenSettings
	return load(PATH) as ForestGenSettings


func spawn_tile() -> Vector2i:
	return Vector2i(settings.spawn_x, surface_at(settings.spawn_x))


# --- surface ------------------------------------------------------------------

func surface_at(x: int) -> int:
	x = posmod(x, width)
	var land := _land_surface(x)
	if _ocean_c >= 0:
		var d := absf(float(wrap_delta(x, _ocean_c)))
		if d < _ocean_half:
			return _sea_floor(x, d)
		if d < _ocean_half + settings.beach_width:
			# The beach: from the water's edge (sea level) up to the land.
			var u := (d - _ocean_half) / float(settings.beach_width)
			# Never below sea level, so water can't spill out over a low beach.
			return mini(roundi(lerpf(float(_sea), float(land), smoothstep(0.0, 1.0, u))), _sea)
	var pond := _pond_index(x)
	if pond >= 0:
		var p := _ponds[pond]
		var t := absf(float(wrap_delta(x, roundi(p.x)))) / maxf(p.y, 1.0)
		var bottom := roundi(p.w + p.z * (1.0 - t * t))
		return maxi(land, bottom)
	return land


## The surface before the ocean and ponds are dug: hills, cliffs, the flat spawn.
func _land_surface(x: int) -> int:
	var s := settings
	var raw := _raw_surface(x)
	var d := absi(wrap_delta(x, s.spawn_x))
	if d < s.spawn_flat_radius + s.spawn_blend:
		var t := smoothstep(float(s.spawn_flat_radius), float(s.spawn_flat_radius + s.spawn_blend), float(d))
		raw = lerpf(_spawn_raw, raw, t)
	return roundi(raw)


# --- ocean and ponds ----------------------------------------------------------

func _place_ocean() -> void:
	var s := settings
	_sea = roundi(height * s.surface_level) + s.sea_level_below
	_ocean_floor = _noise(31, 1.0 / 24.0, 2)
	_beach_mix = _noise(32, 1.0 / 3.0)
	_ocean_c = -1
	if not s.ocean:
		return
	var w := maxf(s.ocean_share * width, float(s.ocean_min_width))
	# The ocean and both beaches must leave most of the world as land.
	if w + 2.0 * s.beach_width > width * 0.6:
		return
	_ocean_half = w * 0.5
	_ocean_c = posmod(s.spawn_x + roundi(s.ocean_distance * width), width)


## The sea floor row at distance d from the ocean's middle: a shallow shelf near each
## shore, then down to ocean_depth in the middle, with bumps.
func _sea_floor(x: int, d: float) -> int:
	var s := settings
	var t := d / maxf(_ocean_half, 1.0)  # 0 middle, 1 shore
	var shelf_start := 1.0 - s.ocean_shelf
	var depth: float
	if t > shelf_start:
		depth = s.ocean_shelf_depth * smoothstep(1.0, shelf_start + (1.0 - shelf_start) * 0.3, t)
	else:
		depth = lerpf(s.ocean_shelf_depth, s.ocean_depth, smoothstep(shelf_start, 0.0, t))
	var p := _cyl(x)
	depth += s.ocean_floor_bumps * _ocean_floor.get_noise_2d(p.x, p.y) / 0.6 * clampf((1.0 - t) * 4.0, 0.0, 1.0)
	return mini(roundi(_sea + maxf(depth, 1.0)), height - settings.floor_rows - 2)


## 0 away from the ocean, 1 over its water, fading to 0 across the beaches.
func ocean_at(x: int) -> float:
	if _ocean_c < 0:
		return 0.0
	var d := absf(float(wrap_delta(x, _ocean_c)))
	if d < _ocean_half:
		return 1.0
	var b := float(settings.beach_width)
	return clampf(1.0 - (d - _ocean_half) / maxf(b, 1.0), 0.0, 1.0) if d < _ocean_half + b else 0.0


func _place_ponds() -> void:
	var s := settings
	_ponds.clear()
	if s.pond_spacing < 20 or s.pond_chance <= 0.0:
		return
	var cells := floori(float(width) / s.pond_spacing)
	for i in cells:
		if GenUtil.hash01(i, 41, seed) >= s.pond_chance:
			continue
		var half := lerpf(s.pond_width_min, s.pond_width_max, GenUtil.hash01(i, 42, seed)) * 0.5
		var c := roundi(i * s.pond_spacing + half + 2 + GenUtil.hash01(i, 43, seed) * maxf(s.pond_spacing - half * 2.0 - 4.0, 0.0))
		c = posmod(c, width)
		if absi(wrap_delta(c, s.spawn_x)) < s.pond_spawn_clear + half:
			continue
		if _ocean_c >= 0 and absf(float(wrap_delta(c, _ocean_c))) < _ocean_half + s.beach_width + half + 10.0:
			continue
		if dark_forest_at(c) > 0.0:
			continue  # not under the dark trees
		var lo := 1000000
		var hi := -1000000
		for k in range(-ceili(half) - 1, ceili(half) + 2):
			var y := _land_surface(posmod(c + k, width))
			lo = mini(lo, y)
			hi = maxi(hi, y)
		if hi - lo > s.pond_max_slope:
			continue
		var depth := lerpf(s.pond_depth_min, s.pond_depth_max, GenUtil.hash01(i, 44, seed))
		# The water's top row: one below the lower bank, so it can't spill over.
		var left := _land_surface(posmod(c - ceili(half) - 1, width))
		var right := _land_surface(posmod(c + ceili(half) + 1, width))
		var water := maxi(left, right) + 1
		_ponds.append(Vector4(c, half, depth, water))


func _pond_index(x: int) -> int:
	for i in _ponds.size():
		if absf(float(wrap_delta(x, roundi(_ponds[i].x)))) < _ponds[i].y:
			return i
	return -1


## The ponds (center x, half width, depth, water row), for the world map preview.
func ponds() -> Array[Vector4]:
	return _ponds.duplicate()


## Middle and half width of the ocean's water (x = -1: none), for the world map preview.
func ocean() -> Vector2:
	return Vector2(_ocean_c, _ocean_half)


func water_at(x: int, y: int) -> bool:
	x = posmod(x, width)
	if y >= surface_at(x):
		return false
	if _ocean_c >= 0 and absf(float(wrap_delta(x, _ocean_c))) < _ocean_half + settings.beach_width:
		return y >= _sea
	var pond := _pond_index(x)
	return pond >= 0 and y >= int(_ponds[pond].w)


func sea_plant_at(x: int) -> Vector3i:
	var s := settings
	x = posmod(x, width)
	var ground := surface_at(x)
	var water_top := -1  # the water's top row over this column, -1 = dry
	var in_ocean := _ocean_c >= 0 and absf(float(wrap_delta(x, _ocean_c))) < _ocean_half + s.beach_width
	if in_ocean:
		if ground > _sea:
			water_top = _sea
	else:
		var pond := _pond_index(x)
		if pond < 0:
			return Vector3i.ZERO
		if ground > int(_ponds[pond].w):
			water_top = int(_ponds[pond].w)
	var roll := GenUtil.hash01(x, 51, seed)
	var variant := floori(GenUtil.hash01(x, 52, seed) * 3.0)
	if water_top < 0:
		# Dry: dune grass on beach sand.
		if in_ocean and _sandy(x, ground) and roll < s.dune_grass_chance:
			return Vector3i(3, variant % 2, ground)
		return Vector3i.ZERO
	var depth := ground - water_top
	if in_ocean and depth >= s.kelp_min_depth and roll < s.kelp_chance:
		var tall := 2 + floori(GenUtil.hash01(x, 53, seed) * float(mini(depth - 3, s.kelp_max_tiles) - 1))
		return Vector3i(2, clampi(tall, 2, depth - 2), ground)
	if GenUtil.hash01(x, 54, seed) < s.seagrass_chance:
		return Vector3i(1, variant, ground)
	return Vector3i.ZERO


## Sandy columns: the ocean's floor and beaches (the beach's land end mixes in clumps).
func _sandy(x: int, y: int) -> bool:
	var o := ocean_at(x)
	if o <= 0.0:
		return false
	if o >= 0.25:
		return true
	return _beach_mix.get_noise_2d(float(x), float(y)) * 0.5 + 0.5 < o / 0.25


## Surface height before the spawn area is flattened (float rows; smaller = higher).
func _raw_surface(x: int) -> float:
	var s := settings
	var p := _cyl(x)
	var lift := s.hill_height * _hills.get_noise_2d(p.x, p.y) / 0.6
	lift += s.big_hill_height * smoothstep(_big_t, _big_t + 0.35, _big.get_noise_2d(p.x, p.y))
	var cliff_on := smoothstep(_cliff_t - 0.05, _cliff_t + 0.1, _cliff_mask.get_noise_2d(p.x, p.y))
	if cliff_on > 0.0:
		var size := lerpf(s.cliff_height_min, s.cliff_height_max,
			clampf(_cliff_size.get_noise_2d(p.x, p.y) + 0.5, 0.0, 1.0))
		lift += cliff_on * size * clampf(_cliff.get_noise_2d(p.x, p.y) * _cliff_k, -0.5, 0.5)
	var y := height * s.surface_level - lift
	return clampf(y, height * s.surface_min, height * s.surface_max)


# --- chunks -------------------------------------------------------------------

func generate_chunk(chunk: ChunkData) -> void:
	var ox := chunk.coord.x * ChunkData.SIZE
	var oy := chunk.coord.y * ChunkData.SIZE
	var entrances := _entrances_near(ox, ChunkData.SIZE)
	for lx in ChunkData.SIZE:
		var x := posmod(ox + lx, width)
		var col := _column(x)
		for ly in ChunkData.SIZE:
			var y := oy + ly
			var i := ChunkData.local_index(lx, ly)
			chunk.blocks[i] = _block(x, y, col, entrances)
			chunk.walls[i] = _wall(x, y, col)
			if chunk.blocks[i] == WorldData.AIR and y >= _sea - 1 and water_at(x, y):
				if chunk.water.is_empty():
					chunk.water.resize(ChunkData.AREA)
				chunk.water[i] = 1


## Block at one tile, for tests and tools. Slower than generate_chunk (no caching).
func block_at(x: int, y: int) -> int:
	x = posmod(x, width)
	return _block(x, y, _column(x), _entrances_near(x, 1))


func wall_at(x: int, y: int) -> int:
	return _wall(x, y, _column(posmod(x, width)))


## Per-column values shared by every tile in the column: [surface, dirt depth, cyl x,
## cyl y, distance from spawn].
func _column(x: int) -> PackedFloat32Array:
	var s := settings
	var p := _cyl(x)
	var surface := surface_at(x)
	var n := _dirt_depth.get_noise_2d(p.x, p.y) / 0.6 * 0.5 + 0.5
	var dirt := lerpf(s.dirt_depth_min, s.dirt_depth_max, clampf(n, 0.0, 1.0))
	dirt += s.dirt_edge_jitter * _dirt_edge.get_noise_2d(p.x, p.y) / 0.6
	return PackedFloat32Array([surface, dirt, p.x, p.y, absi(wrap_delta(x, s.spawn_x))])


func _block(x: int, y: int, col: PackedFloat32Array, entrances: Array[PackedFloat32Array]) -> int:
	if _ocean_c >= 0 and y >= int(col[0]) and y < height - settings.floor_rows and _sandy(x, y):
		var depth := y - int(col[0])
		if depth < settings.ocean_sand_depth:
			return _b[&"sand"]
		if depth < settings.ocean_sand_depth + settings.ocean_hard_sand_depth:
			return _b[&"hard_sand"]
	var b := _plain_block(x, y, col, entrances)
	if not _ponds.is_empty() and y >= int(col[0]) and y <= int(col[0]) + 1 and _pond_index(x) >= 0:
		return _b[&"sand"]  # a sandy pond bed (no grass under water)
	if (_dark_blocks.has(b) or b == _b.get(&"clay", -1)) and dark_forest_blocks_at(x, y, col):
		if b == _b.get(&"clay", -1):
			return _dark_blocks.get(_b[&"dirt"], b)  # no clay under the Dark Forest
		return _dark_blocks[b]
	return b


## Whether tile (x, y) is in the Dark Forest's ground: the patch's width, its sides
## wandering with depth (dark_forest_wobble_tiles), the edge mixed in clumps.
func dark_forest_blocks_at(x: int, y: int, col: PackedFloat32Array) -> bool:
	if _dark.is_empty():
		return false
	var s := settings
	var depth := maxf(y - col[0], 0.0)
	var reach := s.dark_forest_wobble_tiles * clampf(depth / 60.0, 0.2, 1.0)
	var fr := maxf(s.dark_forest_fringe_tiles, 0.5)
	for i in _dark.size():
		var p := _dark[i]
		var d := float(wrap_delta(x, roundi(p.x)))
		var side := 1.0 if d >= 0.0 else -1.0
		var w := _dark_wobble.get_noise_2d(float(y), side * 5000.0 + i * 977.0) / 0.6 * reach
		var margin := p.y + w - absf(d)
		if margin > fr:
			return true
		if margin < -fr:
			continue
		var t := (margin + fr) / (2.0 * fr)
		if _dark_fringe.get_noise_3d(col[2], col[3], float(y)) * 0.5 + 0.5 < t:
			return true
	return false


func _plain_block(x: int, y: int, col: PackedFloat32Array, entrances: Array[PackedFloat32Array]) -> int:
	var s := settings
	if y < 0:
		return WorldData.AIR
	if y >= height - s.floor_rows:
		return _b[&"stone"]
	var surface := int(col[0])
	if y < surface:
		return WorldData.AIR
	var depth := y - surface
	if _carved(x, y, depth, col, entrances):
		return WorldData.AIR
	if depth == 0:
		return _b[&"grass"]
	var px := col[2]
	var py := col[3]
	var yy := y * s.cave_flatten
	var in_dirt := depth < int(col[1])
	var block: int
	if in_dirt:
		block = _b[&"dirt"]
		if depth >= s.stone_pocket_min_depth and _stone_pockets.get_noise_3d(px, py, yy) > _stone_pocket_t:
			block = _b[&"stone"]
	else:
		block = _b[&"stone"]
		if _dirt_pockets.get_noise_3d(px, py, yy) > _dirt_pocket_t:
			block = _b[&"dirt"]
	if block == _b[&"stone"] and _ore(x, y, depth, s.iron_min_depth, s.iron_chance_shallow,
			s.iron_chance_deep, s.iron_full_depth, s.iron_radius_min, s.iron_radius_max, 201):
		return _b[&"iron_ore"]
	if (block == _b[&"stone"] or s.copper_in_dirt) and _copper(x, y, depth):
		return _b[&"copper_ore"]
	if block == _b[&"dirt"] and _ore(x, y, depth, s.clay_min_depth, s.clay_chance_shallow,
			s.clay_chance_deep, s.clay_full_depth, s.clay_radius_min, s.clay_radius_max, 301):
		return _b[&"clay"]
	return block


func _wall(x: int, y: int, col: PackedFloat32Array) -> int:
	var depth := y - int(col[0])
	if depth < 4 or y >= height:
		return WorldData.AIR
	if _ocean_c >= 0 and _sandy(x, y):
		if depth < settings.ocean_sand_depth + 2:
			return _w[&"sand_wall"]
		if depth < settings.ocean_sand_depth + settings.ocean_hard_sand_depth + 2:
			return _w[&"hard_sand_wall"]
	var w: int = _w[&"dirt_wall"] if depth < int(col[1]) + 2 else _w[&"stone_wall"]
	if _dark_walls.has(w) and dark_forest_blocks_at(x, y, col):
		return _dark_walls[w]
	return w


# --- caves --------------------------------------------------------------------

func _carved(x: int, y: int, depth: int, col: PackedFloat32Array, entrances: Array[PackedFloat32Array]) -> bool:
	var s := settings
	if y >= height - s.floor_rows - 1:
		return false
	if (ocean_at(x) > 0.0 and depth < settings.ocean_sand_depth + settings.ocean_hard_sand_depth + settings.ocean_cave_crust) \
			or (_pond_index(x) >= 0 and depth < 12):
		return false  # a solid crust under the sea and ponds (the water would pour in)
	for e in entrances:
		if _in_entrance(x, depth, e):
			return true
	if depth < s.tunnel_min_depth:
		return false
	if col[4] < s.spawn_safe_radius and depth < 40:
		return false
	var px := col[2]
	var py := col[3]
	var yy := y * s.cave_flatten
	# Tunnels: thin ribbons where the noise crosses zero, only inside the coverage mask.
	var cover := smoothstep(_tunnel_mask_t, _tunnel_mask_t + 0.15, _tunnel_mask.get_noise_3d(px, py, yy * 0.5))
	if s.tunnel_breaks > 0.0:
		# Random gaps cut tunnels into runs of different lengths (tunnel_length).
		cover *= smoothstep(_tunnel_cut_t, _tunnel_cut_t + 0.12, _tunnel_cut.get_noise_3d(px, py, yy * 0.5))
	if cover > 0.0:
		# Tunnels fade in over their first few tiles of depth, and narrow (to
		# tunnel_taper of their height) where the coverage runs out, then end.
		var fade := clampf((depth - s.tunnel_min_depth) / 6.0, s.tunnel_taper, 1.0)
		var thick := lerpf(s.tunnel_taper, 1.0, cover) if cover > 0.15 else cover / 0.15 * s.tunnel_taper
		if absf(_tunnels.get_noise_3d(px, py, yy)) < _tunnel_t * thick * fade:
			return true
	# Caverns: big blobs, more common the deeper you go.
	if depth >= s.cavern_min_depth:
		var ramp := clampf(float(depth - s.cavern_min_depth) / maxf(s.cavern_full_depth - s.cavern_min_depth, 1), 0.0, 1.0)
		var t := lerpf(_cavern_t_top, _cavern_t_deep, ramp)
		if _caverns.get_noise_3d(px, py, yy) > t:
			return true
	return false


## Surface entrances near columns [x0, x0 + span), as [center x, depth, width, wobble
## phase, drift, chamber radius]. One candidate per stretch of entrance_spacing columns.
func _entrances_near(x0: int, span: int) -> Array[PackedFloat32Array]:
	var s := settings
	var out: Array[PackedFloat32Array] = []
	var reach := s.entrance_wobble + 0.35 * s.entrance_depth_max + s.entrance_width_max + s.entrance_chamber + 4
	var first := floori((x0 - reach) / _entrance_cell_w)
	var last := floori((x0 + span + reach) / _entrance_cell_w)
	for k in range(first, last + 1):
		var cell := posmod(k, _entrance_cells)
		if GenUtil.hash01(cell, 40, seed) >= s.entrance_chance:
			continue
		var ex := floori(cell * _entrance_cell_w + _entrance_cell_w * (0.15 + 0.7 * GenUtil.hash01(cell, 41, seed)))
		if absi(wrap_delta(ex, s.spawn_x)) < s.spawn_safe_radius + s.entrance_width_max + 10:
			continue
		var depth := lerpf(s.entrance_depth_min, s.entrance_depth_max, GenUtil.hash01(cell, 42, seed))
		var w := lerpf(s.entrance_width_min, s.entrance_width_max, GenUtil.hash01(cell, 43, seed))
		var phase := GenUtil.hash01(cell, 44, seed) * TAU
		var drift := (GenUtil.hash01(cell, 45, seed) - 0.5) * 0.7
		out.append(PackedFloat32Array([ex, depth, w, phase, drift, s.entrance_chamber]))
	return out


func _in_entrance(x: int, depth: int, e: PackedFloat32Array) -> bool:
	var dx := float(wrap_delta(x, int(e[0])))
	var edepth := e[1]
	if depth > edepth + e[5] + 1:
		return false
	var wob := settings.entrance_wobble
	if depth <= edepth:
		var center := wob * (sin(depth * 0.09 + e[3]) - sin(e[3])) + e[4] * depth
		var half := e[2] * 0.5 + maxf(0.0, 3.0 - depth)  # wider at the mouth
		if absf(dx - center) <= half:
			return true
	var bottom := wob * (sin(edepth * 0.09 + e[3]) - sin(e[3])) + e[4] * edepth
	var dy := (depth - edepth) * 1.4
	return (dx - bottom) * (dx - bottom) + dy * dy <= e[5] * e[5]


# --- copper -------------------------------------------------------------------

## Copper blobs: the world is cut into 8x8 cells; each cell may hold one small blob,
## more often deeper down. A tile is copper if it's inside any nearby cell's blob.
func _copper(x: int, y: int, depth: int) -> bool:
	var s := settings
	return _ore(x, y, depth, s.copper_min_depth, s.copper_chance_shallow, s.copper_chance_deep,
		s.copper_full_depth, s.copper_radius_min, s.copper_radius_max, 101)


## Ore blobs (copper, iron): one possible blob per 8x8 cell, the chance ramping from
## `shallow` at `min_depth` to `deep` at `full_depth`. `salt` keeps ores apart.
func _ore(x: int, y: int, depth: int, min_depth: int, shallow: float, deep: float, full_depth: int,
		r_min: float, r_max: float, salt: int) -> bool:
	if depth < min_depth:
		return false
	var ramp := clampf(float(depth - min_depth) / maxf(full_depth - min_depth, 1), 0.0, 1.0)
	var chance := lerpf(shallow, deep, ramp)
	const CELL := 8
	var cells_x := width / CELL
	var cx := floori(x / float(CELL))
	var cy := floori(y / float(CELL))
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var kx := posmod(cx + ox, cells_x)
			var ky := cy + oy
			if GenUtil.hash01(kx, ky, seed + salt) >= chance:
				continue
			var bx := (cx + ox) * CELL + GenUtil.hash01(kx, ky, seed + salt + 1) * CELL
			var by := ky * CELL + GenUtil.hash01(kx, ky, seed + salt + 2) * CELL
			var r := lerpf(r_min, r_max, GenUtil.hash01(kx, ky, seed + salt + 3))
			var stretch := lerpf(0.7, 1.4, GenUtil.hash01(kx, ky, seed + salt + 4))
			var dx := (x + 0.5 - bx) / (r * stretch)
			var dy := (y + 0.5 - by) * stretch / r
			if dx * dx + dy * dy < 1.0:
				return true
	return false


# --- trees and flowers ----------------------------------------------------------

## 0 = deep in a clearing, 1 = deep in a grove.
func groveness(x: int) -> float:
	var p := _cyl(x)
	return smoothstep(_grove_t - 0.12, _grove_t + 0.12, _groves.get_noise_2d(p.x, p.y))


func tree_at(x: int) -> int:
	var s := settings
	x = posmod(x, width)
	if absi(wrap_delta(x, s.spawn_x)) < 3:
		return -1  # keep the spawn point itself clear
	if ocean_at(x) > 0.0 or _pond_index(x) >= 0 or _pond_index(x - 2) >= 0 or _pond_index(x + 2) >= 0:
		return -1
	if dark_forest_at(x) >= 0.5:
		return _dark_tree_at(x)
	var cell := floori(x / float(s.tree_spacing))
	var spot := cell * s.tree_spacing + 1 + floori(GenUtil.hash01(cell, 2, seed) * (s.tree_spacing - 2))
	if x != spot:
		return -1
	var chance := lerpf(s.clearing_tree_chance, s.grove_tree_chance, groveness(x))
	if GenUtil.hash01(cell, 3, seed) >= chance:
		return -1
	if not _trunk_fits(x, 0):  # pine trunks are under a tile wide
		return -1
	return floori(GenUtil.hash01(cell, 1, seed) * s.tree_variants)


## Whether a trunk stands on ground: within `half` tiles of x no column is lower than
## the root (it would hang over a drop); one tile further out (the trunk's edge) one
## tile lower is fine. None more than 2 higher.
func _trunk_fits(x: int, half: int) -> bool:
	var root := surface_at(posmod(x, width))
	for k in range(-half - 1, half + 2):
		var sk := surface_at(posmod(x + k, width))
		var drop := 0 if absi(k) <= half else 1
		if sk > root + drop or root - sk > 2:
			return false
	return true


## Dark Forest trees: close together, nearly every spot. Variants after the pines
## (tree_variants + n), so the plant layer draws darkwood trees for them.
func _dark_tree_at(x: int) -> int:
	var s := settings
	var cell := floori(x / float(s.dark_tree_spacing))
	var spot := cell * s.dark_tree_spacing + 1 + floori(GenUtil.hash01(cell, 22, seed) * (s.dark_tree_spacing - 2))
	if x != spot or GenUtil.hash01(cell, 23, seed) >= s.dark_tree_chance:
		return -1
	if not _trunk_fits(x, 1):  # darkwood trunks are about 2.5 tiles wide
		return -1
	return s.tree_variants + floori(GenUtil.hash01(cell, 24, seed) * maxi(s.dark_tree_variants, 1))


func flower_at(x: int) -> int:
	var s := settings
	x = posmod(x, width)
	if tree_at(x) >= 0 or ocean_at(x) > 0.0 or _pond_index(x) >= 0:
		return -1
	var chance := lerpf(s.clearing_flower_chance, s.grove_flower_chance, groveness(x))
	if dark_forest_at(x) >= 0.5:
		chance = s.dark_flower_chance
	if GenUtil.hash01(x, 7, seed) >= chance:
		return -1
	return floori(GenUtil.hash01(x, 8, seed) * s.flower_variants)


# --- helpers ------------------------------------------------------------------

func _noise(salt: int, frequency: float, octaves: int = 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed * 7919 + salt * 104729
	n.frequency = frequency
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n


## Column x as a point on the wrap cylinder (about 1 unit per tile).
func _cyl(x: int) -> Vector2:
	var a := TAU * x / width
	return Vector2(cos(a), sin(a)) * _radius


## The noise value that `amount` (0 to 1) of the world lies above, measured by sampling
## the noise itself, so "0.3" really means about 30%. Sampled the same way the generator
## reads it: on the cylinder, and (for 3D noise) over the world's depth.
func _calibrate(n: FastNoiseLite, amount: float, three_d: bool, y_scale: float = 1.0) -> float:
	if amount <= 0.0:
		return 9.0
	if amount >= 1.0:
		return -9.0
	const SAMPLES := 4096
	var values := PackedFloat32Array()
	values.resize(SAMPLES)
	for i in SAMPLES:
		var p := _cyl(floori(GenUtil.hash01(i, 90, seed) * width))
		if three_d:
			var y := GenUtil.hash01(i, 91, seed) * height * settings.cave_flatten * y_scale
			values[i] = n.get_noise_3d(p.x, p.y, y)
		else:
			values[i] = n.get_noise_2d(p.x, p.y)
	values.sort()
	return values[clampi(roundi((1.0 - amount) * SAMPLES), 0, SAMPLES - 1)]
