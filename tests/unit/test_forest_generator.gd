extends GutTest
## ForestGenerator: determinism, wrap, spawn, the brief's rules (forest only, copper only,
## hard floor), and that the settings file is valid.

const W := 1024
const H := 1024

var blocks: TileTypes
var walls: TileTypes
var settings: ForestGenSettings


func before_all() -> void:
	blocks = TileTypes.new(&"tiles")
	walls = TileTypes.new(&"walls")
	settings = ForestGenerator.default_settings()


func _gen(seed: int) -> ForestGenerator:
	return ForestGenerator.new(blocks, walls, W, H, seed, settings)


func test_settings_file_is_valid() -> void:
	assert_not_null(settings)
	assert_eq(settings.validate().size(), 0, "\n".join(settings.validate()))


func test_same_seed_same_world() -> void:
	var a := WorldData.new(W, H)
	var b := WorldData.new(W, H)
	a.generator = _gen(7).generate_chunk
	b.generator = _gen(7).generate_chunk
	for c: Vector2i in [Vector2i(0, 9), Vector2i(5, 11), Vector2i(31, 14)]:
		assert_eq(a.get_chunk(c).blocks, b.get_chunk(c).blocks)
		assert_eq(a.get_chunk(c).walls, b.get_chunk(c).walls)


func test_different_seeds_differ() -> void:
	var a := _gen(1)
	var b := _gen(2)
	var same := 0
	for x in range(0, W, 16):
		if a.surface_at(x) == b.surface_at(x):
			same += 1
	assert_lt(same, W / 16 / 2, "surfaces of two seeds should mostly differ")


func test_chunks_match_single_tile_lookups() -> void:
	var g := _gen(5)
	var d := WorldData.new(W, H)
	d.generator = g.generate_chunk
	var s := g.surface_at(100)
	for y in range(s - 4, s + 120, 3):
		assert_eq(d.get_block(100, y), g.block_at(100, y), "y=%d" % y)


func test_surface_is_seamless_across_the_wrap() -> void:
	for seed in [1, 2, 3]:
		var g := _gen(seed)
		var max_step := 0
		for x in range(-6, 6):
			max_step = maxi(max_step, absi(g.surface_at(posmod(x, W)) - g.surface_at(posmod(x - 1, W))))
		assert_lte(max_step, int(settings.cliff_height_max), "seed %d: no seam at x=0" % seed)


func test_spawn_is_flat_and_standable() -> void:
	for seed in [1, 42, 1337]:
		var g := _gen(seed)
		var s := g.spawn_tile()
		for dx in range(-settings.spawn_flat_radius, settings.spawn_flat_radius + 1, 5):
			assert_eq(g.surface_at(s.x + dx), s.y, "seed %d: flat at spawn %+d" % [seed, dx])
		assert_eq(g.block_at(s.x, s.y), blocks.index_of(&"grass"), "grass at spawn")
		for dy in range(1, 12):
			assert_eq(g.block_at(s.x, s.y - dy), WorldData.AIR, "room above spawn")


func test_no_caves_open_near_spawn() -> void:
	var g := _gen(9)
	var s := g.spawn_tile()
	for dx in range(-settings.spawn_safe_radius, settings.spawn_safe_radius + 1, 2):
		var x := posmod(s.x + dx, W)
		var top := g.surface_at(x)
		for y in range(top, top + 30):
			assert_ne(g.block_at(x, y), WorldData.AIR, "solid ground under spawn area at %+d, depth %d" % [dx, y - top])


func test_only_forest_blocks() -> void:
	var g := _gen(3)
	var allowed := [WorldData.AIR]
	for id: StringName in [&"dirt", &"grass", &"stone", &"copper_ore", &"iron_ore", &"clay",
			&"dark_forest_dirt", &"dark_forest_grass", &"dark_forest_stone"]:
		allowed.append(blocks.index_of(id))
	for x in range(0, W, 37):
		for y in range(0, H, 11):
			assert_has(allowed, g.block_at(x, y))


func test_copper_exists_and_never_at_the_surface() -> void:
	var g := _gen(4)
	var copper := blocks.index_of(&"copper_ore")
	var found := 0
	for x in range(0, W, 3):
		var top := g.surface_at(x)
		for y in range(top, top + settings.copper_min_depth):
			assert_ne(g.block_at(x, y), copper, "no copper above copper_min_depth")
		for y in range(top + 20, top + 200, 2):
			if g.block_at(x, y) == copper:
				found += 1
	assert_gt(found, 20, "copper shows up underground")


func test_bottom_rows_are_solid() -> void:
	var g := _gen(6)
	for x in range(0, W, 13):
		for y in range(H - settings.floor_rows, H):
			assert_true(g.block_at(x, y) in [blocks.index_of(&"stone"), blocks.index_of(&"dark_forest_stone")],
				"stone (Dark Forest Stone under the Dark Forest)")


func test_caves_exist() -> void:
	var g := _gen(8)
	var air := 0
	var total := 0
	for x in range(0, W, 5):
		var top := g.surface_at(x)
		for y in range(top + 40, mini(top + 400, H - 4), 5):
			total += 1
			if g.block_at(x, y) == WorldData.AIR:
				air += 1
	var frac := float(air) / total
	assert_between(frac, 0.02, 0.4, "underground is mostly solid with real caves (%.2f air)" % frac)


func test_trees_respect_spacing() -> void:
	var g := _gen(10)
	var last := -100
	for x in range(0, W):
		if g.tree_at(x) >= 0:
			assert_gte(x - last, 2, "trees at %d and %d" % [last, x])
			last = x
