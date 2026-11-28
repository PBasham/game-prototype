extends GutTest
## Phase 94: the C++ water step (addons/voxel_native) and the rules both steps share:
## water levels out, air under water rises as a bubble, and every active tile gets its
## turn even when the time budget runs out. Each test runs on both steps.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World
var v: VoxelLayer
var floor_tile: Vector2i
var stone: int


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	v = w.voxels
	v.set_physics_process(false)  # the tests step it by hand
	stone = w.blocks.index_of(&"stone")
	var feet := w.world_to_tile(w.player.global_position)
	floor_tile = Vector2i(feet.x + 12, feet.y - 30)


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


## A stone tank 10 wide, 14 tall; water `depth` tiles deep.
func _tank(depth: int) -> void:
	for x in range(-1, 11):
		w.request_set_block(floor_tile + Vector2i(x, 0), stone)
	for y in range(1, 15):
		w.request_set_block(floor_tile + Vector2i(-1, -y), stone)
		w.request_set_block(floor_tile + Vector2i(10, -y), stone)
	for y in range(1, depth + 1):
		for x in 10:
			v.request_fill(floor_tile + Vector2i(x, -y), &"water")


func _water_in_tank() -> int:
	var n := 0
	for y in range(1, 15):
		for x in 10:
			n += v.count_in(floor_tile + Vector2i(x, -y), &"water")
	return n


func _steps(n: int) -> void:
	for i in n:
		v.step()


## The top water cell's row in each cell column of the tank (cells, from the floor).
func _heights() -> Array[int]:
	var out: Array[int] = []
	var base := floor_tile.y * VoxelLayer.N
	for cx in 10 * VoxelLayer.N:
		var x := floor_tile.x * VoxelLayer.N + cx
		var h := 0
		for k in range(1, 14 * VoxelLayer.N):
			if v.material_of(v.cell(Vector2i(x, base - k))) != null:
				h = k
		out.append(h)
	return out


func _backends() -> Array[bool]:
	return [true, false] if v._native != null else [false]


func test_native_step_loads() -> void:
	assert_true(ClassDB.class_exists(&"VoxelStep"), "addons/voxel_native loaded")
	assert_true(v.native_on())


func test_water_levels_out_flat() -> void:
	for native in _backends():
		v.use_native = native
		v.tiles.clear()
		v._active.clear()
		v.reset_pass()
		_tank(0)
		for y in range(1, 9):
			for x in 2:
				v.request_fill(floor_tile + Vector2i(x, -y), &"water")
		var before := _water_in_tank()
		_steps(600)
		assert_eq(_water_in_tank(), before, "no water lost (native %s)" % native)
		var hs := _heights()
		assert_lte(hs.max() - hs.min(), 1, "flat to a cell (native %s): %s" % [native, hs])


func test_air_rises_as_a_bubble_under_a_ceiling() -> void:
	for native in _backends():
		v.use_native = native
		v.tiles.clear()
		v._active.clear()
		v.reset_pass()
		_tank(0)
		for x in range(2, 8):
			w.request_set_block(floor_tile + Vector2i(x, -8), stone)  # a ceiling
		w.request_set_block(floor_tile + Vector2i(5, -4), stone)  # a block under it
		for y in range(1, 13):
			for x in 10:
				v.request_fill(floor_tile + Vector2i(x, -y), &"water")
		_steps(60)
		var before := _water_in_tank()
		w.request_set_block(floor_tile + Vector2i(5, -4), WorldData.AIR)  # mine it
		_steps(2)
		assert_eq(v.count_in(floor_tile + Vector2i(5, -4), &"water"), VoxelLayer.CELLS,
			"the hole filled at once (native %s)" % native)
		assert_eq(v.count_in(floor_tile + Vector2i(5, -6), &"water"), VoxelLayer.CELLS,
			"no air left in the column (native %s)" % native)
		_steps(40)
		var under := 0
		for x in range(2, 8):
			under += VoxelLayer.CELLS - v.count_in(floor_tile + Vector2i(x, -7), &"water")
		assert_eq(under, VoxelLayer.CELLS, "all the air sits under the ceiling (native %s)" % native)
		assert_eq(_water_in_tank(), before, "no water made or lost (native %s)" % native)


func test_every_tile_gets_a_turn_on_a_tiny_budget() -> void:
	for native in _backends():
		v.use_native = native
		v.tiles.clear()
		v._active.clear()
		v.reset_pass()
		_tank(12)
		var drop := floor_tile + Vector2i(14, -14)  # high up, outside the tank: last in a pass
		v.request_fill(drop, &"water")
		v.step_budget_ms = 0.0001
		_steps(8)
		v.step_budget_ms = 5.0
		assert_lt(v.count_in(drop, &"water"), VoxelLayer.CELLS, "the top tile moved (native %s)" % native)
