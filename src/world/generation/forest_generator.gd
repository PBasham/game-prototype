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
	var s := settings
	var raw := _raw_surface(x)
	var d := absi(wrap_delta(x, s.spawn_x))
	if d < s.spawn_flat_radius + s.spawn_blend:
		var t := smoothstep(float(s.spawn_flat_radius), float(s.spawn_flat_radius + s.spawn_blend), float(d))
		raw = lerpf(_spawn_raw, raw, t)
	return roundi(raw)


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
			chunk.walls[i] = _wall(y, col)


## Block at one tile, for tests and tools. Slower than generate_chunk (no caching).
func block_at(x: int, y: int) -> int:
	x = posmod(x, width)
	return _block(x, y, _column(x), _entrances_near(x, 1))


func wall_at(x: int, y: int) -> int:
	return _wall(y, _column(posmod(x, width)))


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


func _wall(y: int, col: PackedFloat32Array) -> int:
	var depth := y - int(col[0])
	if depth < 4 or y >= height:
		return WorldData.AIR
	return _w[&"dirt_wall"] if depth < int(col[1]) + 2 else _w[&"stone_wall"]


# --- caves --------------------------------------------------------------------

func _carved(x: int, y: int, depth: int, col: PackedFloat32Array, entrances: Array[PackedFloat32Array]) -> bool:
	var s := settings
	if y >= height - s.floor_rows - 1:
		return false
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
	if dark_forest_at(x) >= 0.5:
		return _dark_tree_at(x)
	var cell := floori(x / float(s.tree_spacing))
	var spot := cell * s.tree_spacing + 1 + floori(GenUtil.hash01(cell, 2, seed) * (s.tree_spacing - 2))
	if x != spot:
		return -1
	var chance := lerpf(s.clearing_tree_chance, s.grove_tree_chance, groveness(x))
	if GenUtil.hash01(cell, 3, seed) >= chance:
		return -1
	if absi(surface_at(posmod(x - 2, width)) - surface_at(posmod(x + 2, width))) > s.tree_max_slope:
		return -1
	return floori(GenUtil.hash01(cell, 1, seed) * s.tree_variants)


## Dark Forest trees: close together, nearly every spot. Variants after the pines
## (tree_variants + n), so the plant layer draws darkwood trees for them.
func _dark_tree_at(x: int) -> int:
	var s := settings
	var cell := floori(x / float(s.dark_tree_spacing))
	var spot := cell * s.dark_tree_spacing + 1 + floori(GenUtil.hash01(cell, 22, seed) * (s.dark_tree_spacing - 2))
	if x != spot or GenUtil.hash01(cell, 23, seed) >= s.dark_tree_chance:
		return -1
	if absi(surface_at(posmod(x - 2, width)) - surface_at(posmod(x + 2, width))) > s.tree_max_slope + 1:
		return -1
	return s.tree_variants + floori(GenUtil.hash01(cell, 24, seed) * maxi(s.dark_tree_variants, 1))


func flower_at(x: int) -> int:
	var s := settings
	x = posmod(x, width)
	if tree_at(x) >= 0:
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
