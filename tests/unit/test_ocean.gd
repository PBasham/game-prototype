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
	var c := roundi(g.ocean().x)
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
