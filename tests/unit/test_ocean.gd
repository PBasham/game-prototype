extends GutTest
## Phase 55: the ocean (sand, Hard Sand, deep water) and ponds.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const PATH := "user://test_ocean_world.tres"

var tiles: TileTypes
var walls: TileTypes


func before_all() -> void:
	tiles = TileTypes.new(&"tiles")
	walls = TileTypes.new(&"walls")


func _gen(width: int = 2048, height: int = 1024, seed: int = 42) -> ForestGenerator:
	var settings := ForestGenerator.default_settings().duplicate() as ForestGenSettings
	return ForestGenerator.new(tiles, walls, width, height, seed, settings)


func test_there_is_one_ocean_far_from_spawn() -> void:
	var g := _gen()
	var o := g.ocean()
	assert_gte(o.x, 0.0, "an ocean")
	assert_gte(o.y * 2.0, float(g.settings.ocean_min_width))
	assert_gt(absi(g.wrap_delta(roundi(o.x), g.settings.spawn_x)), g.width / 3, "far from spawn")
	assert_eq(g.biome_at(roundi(o.x)), &"ocean")
	assert_eq(g.biome_at(g.settings.spawn_x), &"forest")


func test_the_ocean_is_deep_water_over_sand_and_hard_sand() -> void:
	var g := _gen()
	# Off to the side of the chasm, which opens the floor in the middle.
	var c := roundi(g.ocean().x - g.ocean().y * 0.3)
	var floor_y := g.surface_at(c)
	var sea := floor_y
	while sea > 0 and g.water_at(c, sea - 1):
		sea -= 1
	assert_gt(floor_y - sea, 40, "deep in the middle")
	assert_true(g.water_at(c, floor_y - 1))
	assert_false(g.water_at(c, sea - 1), "nothing above sea level")
	assert_eq(g.block_at(c, floor_y), tiles.index_of(&"sand"))
	assert_eq(g.block_at(c, floor_y + g.settings.ocean_sand_depth + 2), tiles.index_of(&"hard_sand"))
	assert_eq(g.block_at(c, floor_y - 3), WorldData.AIR, "water tiles are air blocks")
	assert_eq(g.wall_at(c, floor_y + 5), walls.index_of(&"sand_wall"))
	assert_eq(g.tree_at(c), -1)


## Every water tile has water or something solid below and to both sides, all the way
## across the ocean and the ponds: nothing leaks out when it first moves.
func test_water_is_contained() -> void:
	var g := _gen()
	var spans: Array[Vector2i] = []
	var o := g.ocean()
	var b := g.settings.beach_width
	spans.append(Vector2i(roundi(o.x - o.y) - b, roundi(o.x + o.y) + b))
	for p in g.ponds():
		spans.append(Vector2i(roundi(p.x - p.y) - 2, roundi(p.x + p.y) + 2))
	assert_gt(g.ponds().size(), 0, "some ponds")
	var leaks := 0
	var checked := 0
	for span in spans:
		for x in range(span.x, span.y + 1):
			var top := g.surface_at(x)
			for y in range(maxi(top - 120, 0), top):
				if not g.water_at(x, y):
					continue
				checked += 1
				for n: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y + 1)]:
					var solid := g.block_at(n.x, n.y) != WorldData.AIR
					if not solid and not g.water_at(n.x, n.y):
						leaks += 1
	assert_gt(checked, 1000, "lots of water")
	assert_eq(leaks, 0, "no water tile next to open air at its sides or below")


func test_no_ocean_on_worlds_too_small() -> void:
	var g := _gen(300, 512)
	assert_eq(g.ocean().x, -1.0)


func test_ocean_off() -> void:
	var settings := ForestGenerator.default_settings().duplicate() as ForestGenSettings
	settings.ocean = false
	var g := ForestGenerator.new(tiles, walls, 2048, 1024, 42, settings)
	assert_eq(g.ocean().x, -1.0)


func test_generated_water_fills_the_voxel_layer_once() -> void:
	WorldSave.delete(PATH)
	var info := WorldInfo.create("Ocean", WorldData.Size.TINY, 7)
	info.path = PATH
	Game.world_info = info
	Game.character = null
	var w := WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	var g := w.generator as ForestGenerator
	var o := g.ocean()
	assert_gte(o.x, 0.0)
	var c := roundi(o.x)
	var y := g.surface_at(c) - 2
	w.data.get_chunk(Vector2i(c / ChunkData.SIZE, y / ChunkData.SIZE))
	w.voxels.import_generated()
	var t := Vector2i(c, y)
	assert_eq(w.voxels.count_in(t, &"water"), 16, "the sea is full of water cells")
	assert_false(w.voxels._active.has(t), "at rest: not simulated")
	# Take that tile's water away: the generator mustn't put it back after a reload.
	assert_eq(w.voxels.take_liquid(Rect2i(t, Vector2i.ONE), 16), 16)
	w.queue_free()
	await wait_physics_frames(2)
	# Load it again: the saved water, not a second helping from the generator.
	var again := WorldSave.read_info(PATH)
	Game.world_info = again
	var w2 := WORLD_SCENE.instantiate() as World
	add_child(w2)
	await wait_physics_frames(3)
	w2.data.get_chunk(Vector2i(c / ChunkData.SIZE, y / ChunkData.SIZE))
	w2.voxels.import_generated()
	var near := w2.voxels.count_in(t, &"water") + w2.voxels.count_in(t + Vector2i.DOWN, &"water")
	assert_lt(near, 32, "the taken water didn't come back (it was refilled from the sides at most)")
	assert_eq(w2.voxels.count_in(Vector2i(c, y + 1), &"water"), 16, "the rest of the sea is there")
	w2.queue_free()
	await wait_physics_frames(2)
	WorldSave.delete(PATH)
	Game.world_info = null


## Phase 64: the chasm, the Deep's flooded caves, the arena, and sunlight in the sea.
func test_the_chasm_drops_to_the_arena() -> void:
	var g := _gen()
	var c := roundi(g.ocean().x)
	var deep := g.deep_layout()
	var arena: Rect2 = deep["arena"]
	assert_gt(float(deep["chasm_half"]), 20.0, "a wide chasm")
	assert_gt(arena.position.y, g.height - 80.0, "the arena is near the bottom of the world")
	var mouth := g.surface_at(c)
	var sea := g.surface_at(c - roundi(g.ocean().y) + 3)
	assert_gt(mouth - sea, 180, "the upper sea floor is deep")
	var off := 0
	var widths := {}
	for y in range(mouth + 2, roundi(arena.position.y), 11):
		var m := g.chasm_center(y)
		assert_true(g.water_at(m, y), "open water all the way down (row %d)" % y)
		off = maxi(off, absi(g.wrap_delta(m, c)))
		var w := 0
		while g.chasm_open(m + w, y):
			w += 1
		widths[w / 2] = true
	assert_gt(off, 10, "the chasm winds")
	assert_gt(widths.size(), 4, "its walls are uneven")
	assert_true(g.water_at(c, roundi(arena.position.y)), "it opens into the arena")


func test_the_deep_is_flooded_caves_with_scene_caverns() -> void:
	var g := _gen()
	var deep := g.deep_layout()
	var scenes: Array = deep["scenes"]
	assert_eq(scenes.size(), g.settings.scene_caverns)
	for r: Rect2 in scenes:
		var x := roundi(r.position.x)
		var y := roundi(r.position.y)
		assert_true(g.deep_open(x, y), "the scene cavern is open")
		assert_true(g.water_at(x, y), "and full of water")
		assert_eq(g.block_at(x, y), WorldData.AIR)
	# A good share of the Deep is open, the rest rock.
	var o := g.ocean()
	var open := 0
	var total := 0
	for x in range(roundi(o.x - o.y * 0.7), roundi(o.x + o.y * 0.7), 9):
		for y in range(g.surface_at(x) + 40, g.height - 20, 9):
			total += 1
			if g.deep_open(x, y):
				open += 1
	assert_between(float(open) / total, 0.15, 0.6, "caverns and rock")


func test_no_deep_away_from_the_ocean() -> void:
	var g := _gen()
	var s := g.settings.spawn_x
	for y in range(g.surface_at(s) + 10, g.height - 10, 13):
		assert_false(g.deep_open(s, y))


func test_sunlight_stops_a_little_way_down() -> void:
	var g := _gen()
	var c := roundi(g.ocean().x)
	var sea := g.surface_at(c - roundi(g.ocean().y) + 5)
	assert_lt(g.light_floor_at(c), g.surface_at(c), "the deep water isn't open sky")
	assert_lte(g.light_floor_at(c) - sea, g.settings.sunlit_water_tiles + 1)
	assert_eq(g.light_floor_at(g.settings.spawn_x), g.surface_at(g.settings.spawn_x), "land is unchanged")


## Every water tile in a small world's whole ocean (sea, chasm and Deep) has water or
## something solid beside and below it: nothing leaks.
func test_the_whole_ocean_is_contained() -> void:
	var g := _gen(1024, 512, 7)
	var o := g.ocean()
	assert_gte(o.x, 0.0)
	var leaks := 0
	var count := 0
	var b := g.settings.beach_width
	for x in range(roundi(o.x - o.y) - b, roundi(o.x + o.y) + b):
		for y in range(0, g.height - 3):
			if not g.water_at(x, y):
				continue
			count += 1
			for n: Vector2i in [Vector2i(x - 1, y), Vector2i(x + 1, y), Vector2i(x, y + 1)]:
				if g.block_at(n.x, n.y) == WorldData.AIR and not g.water_at(n.x, n.y):
					leaks += 1
	assert_gt(count, 10000)
	assert_eq(leaks, 0)


## Phase 65: the Abyssal Stone shell: nothing below sea level inside it connects to the
## land outside without going through it (a flood fill through every other tile).
func test_abyssal_stone_shuts_the_sea_in() -> void:
	var g := _gen(1024, 512, 7)
	var o := g.ocean()
	var s := g.settings
	var abyss := tiles.index_of(&"abyssal_stone")
	var sea := g.surface_at(roundi(o.x - o.y) + 2)
	var reach := roundi(o.y) + s.beach_width
	var c := roundi(o.x)
	var start := Vector2i(c, sea + 2)
	assert_true(g.water_at(start.x, start.y))
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	var escaped := 0
	while not todo.is_empty():
		var t: Vector2i = todo.pop_back()
		if absi(t.x - c) > reach:
			escaped += 1
			continue
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := t + d
			if n.y < sea or n.y >= g.height or seen.has(n) or g.block_at(n.x, n.y) == abyss:
				continue
			seen[n] = true
			todo.append(n)
	assert_gt(seen.size(), 20000, "the whole sea and the Deep")
	assert_eq(escaped, 0, "nothing gets past the Abyssal Stone")


## Its layer follows the beach under the sand, ends above sea level under the surface,
## and the walls down the Deep's sides reach the world's floor.
func test_abyssal_stone_follows_the_beach() -> void:
	var g := _gen()
	var o := g.ocean()
	var s := g.settings
	var abyss := tiles.index_of(&"abyssal_stone")
	var sea := g.surface_at(roundi(o.x - o.y) + 2)
	for side in [-1, 1]:
		# Mid beach: under the sand and Hard Sand.
		var x := roundi(o.x + side * (o.y + s.beach_width * 0.3))
		var under := g.surface_at(x) + s.ocean_sand_depth + s.ocean_hard_sand_depth
		assert_eq(g.block_at(x, under + 1), abyss, "under the beach's sand")
		assert_eq(g.block_at(x, under - 2), tiles.index_of(&"hard_sand"))
		# The beach's end: just above sea level, still covered.
		var e := roundi(o.x + side * (o.y + s.beach_width - 1))
		var top := g.surface_at(e)
		while g.block_at(e, top) != abyss and top < g.height:
			top += 1
		assert_lt(top, sea, "its top is above sea level")
		assert_gte(top - g.surface_at(e), s.abyss_cover, "under the surface")
		# The Deep's side: down to the floor.
		var wx := roundi(o.x + side * (o.y - s.deep_margin + 1))
		var wy := g.surface_at(wx) + s.ocean_sand_depth + s.ocean_hard_sand_depth + 2
		for y in range(wy, g.height):
			if g.block_at(wx, y) != abyss:
				fail_test("a gap in the wall at row %d" % y)
				return
		assert_true(g.sea_at(roundi(o.x), sea + 5), "inside is sea")
		assert_false(g.sea_at(x, under + 10), "under the layer isn't")
	pass_test("ok")
