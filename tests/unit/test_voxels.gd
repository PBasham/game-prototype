extends GutTest
## Phase 52: the voxel layer (falling sand, water, Sand Bricks, the Bomb).

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World
var v: VoxelLayer


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	v = w.voxels


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


## A stone floor 6 wide high in the air, with its left end at `at`, and walls of stone
## at both ends 4 tall: a little basin.
func _basin(at: Vector2i) -> void:
	var stone := w.blocks.index_of(&"stone")
	for x in range(-1, 7):
		w.request_set_block(at + Vector2i(x, 0), stone)
	for y in range(1, 5):
		w.request_set_block(at + Vector2i(-1, -y), stone)
		w.request_set_block(at + Vector2i(6, -y), stone)


func _air_spot() -> Vector2i:
	var feet := w.world_to_tile(w.player.global_position)
	return Vector2i(feet.x + 10, feet.y - 30)


func _sand_total(lo: Vector2i, hi: Vector2i) -> int:
	var n := 0
	var sand := w.blocks.index_of(&"sand")
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var t := Vector2i(x, y)
			n += v.count_in(t, &"sand")
			if w.data.get_block(w.wrap_tile(t).x, y) == sand:
				n += VoxelLayer.CELLS
	return n


func _steps(n: int) -> void:
	for i in n:
		v.step()


func test_materials_load() -> void:
	assert_gt(v.code_of(&"sand"), 0)
	assert_gt(v.code_of(&"water"), 0)
	assert_gt(v.code_of(&"sand_bricks"), 0)
	assert_eq(w.blocks.def(w.blocks.index_of(&"sand")).voxel, &"sand")


func test_unsupported_sand_falls_and_settles_into_blocks() -> void:
	var floor := _air_spot()
	_basin(floor)
	var sand := w.blocks.index_of(&"sand")
	v.solidify_piles = true
	var top := floor + Vector2i(1, -7)
	for x in 4:
		for y in 2:
			w.request_set_block(top + Vector2i(x, y), sand)
	_steps(2)
	assert_eq(w.data.get_block(w.wrap_tile(top).x, top.y + 1), WorldData.AIR, "fell apart into cells")
	var lo := floor + Vector2i(-1, -9)
	var hi := floor + Vector2i(7, 0)
	assert_eq(_sand_total(lo, hi), 128, "every grain is still there")
	_steps(500)
	assert_eq(_sand_total(lo, hi), 128, "still there after landing")
	for t: Vector2i in v.tiles:
		assert_eq(w.data.get_block(t.x, t.y), WorldData.AIR, "cells only ever share a tile with air")
	var blocks := 0
	for x in range(0, 6):
		if w.data.get_block(w.wrap_tile(floor + Vector2i(x, -1)).x, floor.y - 1) == sand:
			blocks += 1
	assert_gt(blocks, 0, "resting full tiles became sand blocks again")


func test_supported_sand_stays_a_block() -> void:
	var floor := _air_spot()
	_basin(floor)
	var sand := w.blocks.index_of(&"sand")
	var t := floor + Vector2i(1, -1)
	w.request_set_block(t, sand)
	_steps(30)
	assert_eq(w.data.get_block(w.wrap_tile(t).x, t.y), sand)


func test_water_falls_and_levels() -> void:
	var floor := _air_spot()
	_basin(floor)
	var t := floor + Vector2i(0, -4)
	assert_eq(v.request_fill(t, &"water"), 16)
	_steps(300)
	var bottom := 0
	var total := 0
	for x in range(0, 6):
		for y in range(1, 6):
			total += v.count_in(floor + Vector2i(x, -y), &"water")
		bottom += v.count_in(floor + Vector2i(x, -1), &"water")
	assert_eq(total, 16, "no water lost")
	assert_eq(bottom, 16, "all of it on the floor of the basin")
	var spread := 0
	for x in range(0, 6):
		if v.count_in(floor + Vector2i(x, -1), &"water") > 0:
			spread += 1
	assert_gt(spread, 2, "spread out sideways")


func test_sand_sinks_through_water() -> void:
	var floor := _air_spot()
	_basin(floor)
	for x in 6:
		v.request_fill(floor + Vector2i(x, -1), &"water")
	w.request_set_block(floor + Vector2i(2, -3), w.blocks.index_of(&"sand"))
	_steps(600)
	assert_gt(v.count_in(floor + Vector2i(2, -1), &"sand") + v.count_in(floor + Vector2i(1, -1), &"sand")
		+ v.count_in(floor + Vector2i(3, -1), &"sand"), 0, "sand reached the bottom")
	var water := 0
	for x in 6:
		for y in range(1, 5):
			water += v.count_in(floor + Vector2i(x, -y), &"water")
	assert_eq(water, 96, "water pushed up, none lost")


func test_bomb_bites_sand_bricks_and_they_stay_put() -> void:
	var floor := _air_spot()
	_basin(floor)
	var bricks := w.blocks.index_of(&"sand_bricks")
	for x in range(0, 6):
		for y in range(1, 4):
			w.request_set_block(floor + Vector2i(x, -y), bricks)
	var t := floor + Vector2i(2, -3)
	var center := Vector2((t.x + 1) * World.TILE, (t.y) * World.TILE)  # a corner on the top edge
	var gone := v.explode(center, 1.2 * World.TILE)
	assert_gt(gone, 0)
	assert_eq(w.data.get_block(w.wrap_tile(t).x, t.y), WorldData.AIR, "bitten tile is cells now")
	var left := v.count_in(t, &"sand_bricks")
	assert_between(left, 1, 15, "part of it is left")
	assert_eq(w.data.get_block(w.wrap_tile(floor + Vector2i(0, -1)).x, floor.y - 1), bricks, "far tiles untouched")
	_steps(60)
	assert_eq(v.count_in(t, &"sand_bricks"), left, "static: doesn't fall")
	# Refilling takes only the missing bricks.
	var item := ItemData.find(&"sand_bricks")
	assert_eq(item.place_units, 16)
	assert_eq(w.place_cost(t, item), 16 - left)
	assert_true(w.request_place_block(t, bricks))
	assert_eq(v.count_in(t, &"sand_bricks"), 0)
	assert_eq(w.data.get_block(w.wrap_tile(t).x, t.y), bricks)


func test_mining_a_broken_brick_tile_gives_what_is_left() -> void:
	var floor := _air_spot()
	_basin(floor)
	var t := floor + Vector2i(2, -1)
	w.request_set_block(t, w.blocks.index_of(&"sand_bricks"))
	v.explode(w.tile_to_world(t), 0.5 * World.TILE)  # a nibble off one corner
	assert_true(v.has_minable(t))
	var left := v.count_in(t, &"sand_bricks")
	assert_between(left, 1, 15)
	w.teleport_player(w.tile_to_world(floor + Vector2i(4, -1)) + Vector2(4, 0))
	await wait_physics_frames(2)
	var inv := w.character.inventory
	var before := inv.count_of(&"sand_bricks")
	assert_true(w.request_damage_block(t, 1000.0))
	assert_false(v.has_minable(t))
	await wait_seconds(1.0)
	assert_eq(inv.count_of(&"sand_bricks") - before, left, "one brick a cell left")
	assert_eq(w.blocks.def(w.blocks.index_of(&"sand_bricks")).drop_count, 16, "a whole block gives 16")


func test_placing_sand_takes_grains() -> void:
	var floor := _air_spot()
	_basin(floor)
	var sand := ItemData.find(&"sand")
	assert_eq(sand.place_units, 16)
	var t := floor + Vector2i(1, -1)
	assert_eq(w.place_cost(t, sand), 16)
	assert_eq(w.place_cost(t, sand, true), 16, "a sand wall too")
	# A tile half full of loose sand only needs the other half.
	var code := v.code_of(&"sand")
	for i in 8:
		v._set_cell(Vector2i(t.x * 4 + i % 4, t.y * 4 + 2 + i / 4), code)
	assert_eq(w.place_cost(t, sand), 8)
	assert_true(w.request_place_block(t, w.blocks.index_of(&"sand")))
	assert_eq(v.count_in(t, &"sand"), 0, "the grains became the block")
	assert_eq(w.blocks.def(w.blocks.index_of(&"sand")).drop_count, 16, "mining gives the 16 back")


func test_mining_loose_sand_gives_grains() -> void:
	var floor := _air_spot()
	_basin(floor)
	var t := floor + Vector2i(1, -1)
	var code := v.code_of(&"sand")
	for i in 4:
		v._set_cell(Vector2i(t.x * 4 + i, t.y * 4 + 3), code)
	v._set_cell(Vector2i(t.x * 4 + 1, t.y * 4 + 2), code)  # held up on both sides
	w.teleport_player(w.tile_to_world(floor + Vector2i(3, -1)) + Vector2(4, 0))
	await wait_physics_frames(2)
	w.player.toggle_tool_spell(&"mining_spell")
	w.item_user.update_target(w.tile_to_world(t) + Vector2(4, 4))
	assert_false(w.item_user.valid.is_empty(), "the mining spell targets loose sand")
	var inv := w.character.inventory
	var before := inv.count_of(&"sand")
	assert_true(w.request_damage_block(t, 1000.0))
	await wait_seconds(1.0)
	assert_eq(inv.count_of(&"sand") - before, 5, "five grains")


func test_solid_cells_have_collision() -> void:
	var floor := _air_spot()
	_basin(floor)
	var t := floor + Vector2i(3, -1)
	var code := v.code_of(&"sand_bricks")
	var c := Vector2i(t.x * 4 + 1, t.y * 4 + 3)
	v._set_cell(c, code)
	await wait_physics_frames(3)
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(w.near_player_x(c.x * 2.0 + 1.0), c.y * 2.0 + 1.0)
	assert_gt(w.get_world_2d().direct_space_state.intersect_point(q).size(), 0, "a solid cell")
	assert_true(v.solid_at(Vector2(c.x * 2.0 + 1.0, c.y * 2.0 + 1.0)))
	v.request_fill(t + Vector2i.UP, &"water")
	await wait_physics_frames(3)
	q.position = Vector2(w.near_player_x(t.x * 8.0 + 4.0), (t.y - 1) * 8.0 + 4.0)
	assert_eq(w.get_world_2d().direct_space_state.intersect_point(q).size(), 0, "water has none")


func test_voxels_save_and_load() -> void:
	var t := _air_spot()
	v.request_fill(t, &"water")
	var code := v.code_of(&"sand_bricks")
	v._set_cell(Vector2i(t.x * 4, (t.y + 1) * 4), code)
	var d := v.to_dict()
	assert_eq((d["tiles"] as Dictionary).size(), 2)
	v.tiles.clear()
	v.from_dict(d)
	assert_eq(v.count_in(t, &"water"), 16)
	assert_eq(v.count_in(t + Vector2i.DOWN, &"sand_bricks"), 1)


func test_bomb_hurts_and_breaks_blocks() -> void:
	var bomb := ItemData.find(&"bomb")
	assert_eq(bomb.throw_effect, &"explosion")
	var floor := _air_spot()
	_basin(floor)
	var t := floor + Vector2i(2, 0)
	var stone := w.blocks.index_of(&"stone")
	assert_eq(w.data.get_block(w.wrap_tile(t).x, t.y), stone)
	var hp := w.player.health
	w.request_explode(w.tile_to_world(t) + Vector2(4, 0), bomb.explosion_radius_tiles, bomb.explosion_damage, bomb.explosion_power)
	assert_eq(w.data.get_block(w.wrap_tile(t).x, t.y), WorldData.AIR, "stone in the blast broke")
	assert_eq(w.player.health, hp, "too far away to be hurt")
	w.request_explode(w.player.chest(), bomb.explosion_radius_tiles, bomb.explosion_damage, 0)
	assert_lt(w.player.health, hp, "the bomb hurts you too")
