extends GutTest
## Phase 79: right-click water with an empty bottle to fill it (the water stays), and
## the Clay Bucket, which scoops up a tile of water and pours it back out.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const BOTTLES: Array[StringName] = [&"clay_flask", &"clay_bottle", &"clay_jug", &"glass_vial",
	&"glass_bottle", &"glass_flask"]

var w: World
var v: VoxelLayer
var floor_tile: Vector2i


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	v = w.voxels
	var feet := w.world_to_tile(w.player.global_position)
	floor_tile = Vector2i(feet.x + 12, feet.y - 30)


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


## A stone tank 10 wide high in the air, `depth` tiles of water, the player in it.
func _tank(depth: int) -> void:
	var stone := w.blocks.index_of(&"stone")
	for x in range(-1, 11):
		w.request_set_block(floor_tile + Vector2i(x, 0), stone)
	for y in range(1, 15):
		w.request_set_block(floor_tile + Vector2i(-1, -y), stone)
		w.request_set_block(floor_tile + Vector2i(10, -y), stone)
	for y in range(1, depth + 1):
		for x in 10:
			v.request_fill(floor_tile + Vector2i(x, -y), &"water")
	w.teleport_player(w.tile_to_world(floor_tile + Vector2i(2, 0)))
	await wait_physics_frames(3)


func _hold(id: StringName, count: int) -> void:
	w.character.inventory.set_slot(0, id, count)
	w.player.select_slot(0)


func _tank_water() -> int:
	return v.liquid_in(Rect2i(floor_tile + Vector2i(0, -14), Vector2i(10, 14)))


func test_every_empty_bottle_fills_into_its_water() -> void:
	for b in BOTTLES:
		var item := ItemData.find(b)
		assert_eq(item.fills_into, StringName("water_" + String(b)), String(b))
		assert_eq(item.fill_takes, 1, "a bottle takes one cell")
		assert_not_null(ItemData.find(item.fills_into))
	var iu := w.item_user
	assert_eq(iu._mode_for(ItemData.find(&"glass_vial"), true), ItemUser.Mode.FILL)
	assert_eq(iu._mode_for(ItemData.find(&"clay_bucket"), true), ItemUser.Mode.FILL)
	assert_eq(iu._mode_for(ItemData.find(&"clay_bucket_water"), false), ItemUser.Mode.POUR)


func test_filling_a_bottle_takes_a_cell() -> void:
	await _tank(2)
	_hold(&"glass_vial", 5)
	var before := _tank_water()
	var spot := floor_tile + Vector2i(4, -1)
	assert_eq(w.item_user.fill_held(spot), 1)
	assert_eq(w.character.inventory.count_of(&"water_glass_vial"), 1)
	assert_eq(w.character.inventory.count_of(&"glass_vial"), 4)
	assert_eq(_tank_water(), before - 1, "one cell")
	assert_eq(w.item_user.fill_held(spot, true), 4, "Shift fills the whole stack")
	assert_eq(_tank_water(), before - 5)
	assert_eq(w.character.inventory.count_of(&"water_glass_vial"), 5)
	assert_eq(w.character.inventory.count_of(&"glass_vial"), 0)


func test_shift_fills_as_far_as_the_water_goes() -> void:
	await _tank(0)
	var spot := floor_tile + Vector2i(4, -1)
	v.request_fill(spot, &"water")
	v.take_liquid(Rect2i(spot, Vector2i.ONE), 13)
	_hold(&"clay_jug", 10)
	assert_eq(w.item_user.fill_held(spot, true), 3, "three cells, three jugs")
	assert_eq(w.character.inventory.count_of(&"clay_jug"), 7)
	assert_eq(_tank_water(), 0)


func test_no_water_no_fill() -> void:
	await _tank(0)
	_hold(&"glass_vial", 2)
	assert_eq(w.item_user.fill_held(floor_tile + Vector2i(4, -1)), 0)
	assert_eq(w.character.inventory.count_of(&"glass_vial"), 2)


func test_bucket_scoops_and_pours_a_tile() -> void:
	await _tank(2)
	_hold(&"clay_bucket", 2)
	var before := _tank_water()
	var spot := floor_tile + Vector2i(4, -1)
	assert_eq(w.item_user.fill_held(spot), 1)
	assert_eq(_tank_water(), before - 16, "took a tile of water")
	assert_eq(w.character.inventory.count_of(&"clay_bucket_water"), 1)
	assert_eq(w.character.inventory.count_of(&"clay_bucket"), 1)
	w.character.inventory.remove(&"clay_bucket", 1)
	w.character.inventory.remove(&"clay_bucket_water", 1)
	_hold(&"clay_bucket_water", 1)
	assert_true(w.item_user.pour_held(floor_tile + Vector2i(6, -4)))
	await wait_physics_frames(2)
	assert_eq(_tank_water(), before, "poured back")
	assert_eq(w.character.inventory.count_of(&"clay_bucket_water"), 0)
	assert_eq(w.character.inventory.count_of(&"clay_bucket"), 1, "the empty bucket back")


func test_bucket_needs_a_full_tile() -> void:
	await _tank(0)
	var spot := floor_tile + Vector2i(4, -1)
	v.request_fill(spot, &"water")
	v.take_liquid(Rect2i(spot, Vector2i.ONE), 10)
	_hold(&"clay_bucket", 1)
	assert_eq(w.item_user.fill_held(spot), 0)
	assert_eq(_tank_water(), 6, "the water is left alone")
	assert_eq(w.character.inventory.count_of(&"clay_bucket"), 1)


func test_pouring_into_solid_or_full_fails() -> void:
	await _tank(0)
	_hold(&"clay_bucket_water", 1)
	assert_false(w.item_user.pour_held(floor_tile), "into the stone floor")
	assert_eq(w.character.inventory.count_of(&"clay_bucket_water"), 1)


func test_barrels_fill_bottles_and_buckets() -> void:
	await _tank(0)
	var spot := floor_tile + Vector2i(5, -1)
	assert_true(w.request_place_object(spot, w.objects.index_of(&"liquid_barrel")))
	w.request_barrel_water(spot, 20)
	_hold(&"clay_jug", 1)
	assert_eq(w.item_user.fill_held(spot), 1)
	assert_eq(w.barrel_water(spot), 19, "a bottle takes one cell")
	_hold(&"clay_bucket", 1)
	assert_eq(w.item_user.fill_held(spot), 1)
	assert_eq(w.barrel_water(spot), 3)
	_hold(&"clay_bucket_water", 1)
	assert_true(w.item_user.pour_held(spot))
	assert_eq(w.barrel_water(spot), 19, "poured back in")


func test_bucket_recipe() -> void:
	var r := Registry.get_def(&"recipes", &"clay_bucket") as RecipeData
	assert_not_null(r)
	assert_eq(r.station, &"furnace")
	assert_eq(r.tab, "Bottles")
	assert_eq(r.inputs, {&"clay": 5} as Dictionary[StringName, int])
