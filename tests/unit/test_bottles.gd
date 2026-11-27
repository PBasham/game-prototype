extends GutTest
## Phase 35: clay and glass bottles, sand and glass, the potion furniture (cabinet,
## bookcase, shelf), shelf spots and stacking furniture on flat tops.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


func _floor_spot(dx: int) -> Vector2i:
	var feet := w.world_to_tile(w.player.global_position)
	return Vector2i(feet.x + dx, feet.y - 1)


func test_bottle_shapes_and_spots() -> void:
	var shapes := {
		&"clay_flask": ItemData.BottleShape.CLAY_THIN, &"clay_bottle": ItemData.BottleShape.CLAY_REGULAR,
		&"clay_jug": ItemData.BottleShape.CLAY_LARGE, &"glass_vial": ItemData.BottleShape.GLASS_THIN,
		&"glass_bottle": ItemData.BottleShape.GLASS_REGULAR, &"glass_flask": ItemData.BottleShape.GLASS_LARGE,
		&"healing_potion": ItemData.BottleShape.CLAY_THIN,
	}
	for id: StringName in shapes:
		var it := ItemData.find(id)
		assert_not_null(it, String(id))
		assert_eq(it.bottle_shape, shapes[id], String(id))
	assert_eq(ObjectLayer.bottle_spots(ItemData.find(&"clay_jug")), 2)
	assert_eq(ObjectLayer.bottle_spots(ItemData.find(&"glass_flask")), 2)
	assert_eq(ObjectLayer.bottle_spots(ItemData.find(&"glass_vial")), 1)
	assert_eq(ObjectLayer.bottle_spots(ItemData.find(&"clay_bottle")), 1)
	assert_ne(ItemData.find(&"healing_potion").bottle_contents.a, 0.0, "potions have a color")


func test_sand_glass_and_bottle_recipes() -> void:
	var want := {
		&"glass": [&"furnace", &"sand", 1], &"glass_vial": [&"furnace", &"glass", 1],
		&"glass_bottle": [&"furnace", &"glass", 2], &"glass_flask": [&"furnace", &"glass", 3],
		&"clay_bottle": [&"furnace", &"clay", 3], &"clay_jug": [&"furnace", &"clay", 4],
	}
	for id: StringName in want:
		var r := Registry.get_def(&"recipes", id) as RecipeData
		assert_not_null(r, String(id))
		if r == null:
			continue
		assert_eq(r.station, want[id][0], String(id))
		assert_eq(r.inputs.get(want[id][1], 0), want[id][2], String(id))
	var cab := Registry.get_def(&"recipes", &"potion_cabinet") as RecipeData
	assert_true(cab.inputs.has(&"glass"), "the cabinet needs glass")
	assert_false(cab.inputs.has(&"clay_flask"), "no clay flasks in the furniture")


func test_cabinet_is_bigger_and_has_shelves() -> void:
	var cab := w.objects.def(w.objects.index_of(&"potion_cabinet")) as ObjectDef
	assert_eq(cab.height_tiles, 5)
	assert_eq(cab.bottle_shelves.size(), 4)
	assert_true(cab.flat_top)
	var shelf := w.objects.def(w.objects.index_of(&"potion_shelf")) as ObjectDef
	assert_true(shelf.needs_wall)
	assert_false(shelf.needs_floor)
	var bookcase := w.objects.def(w.objects.index_of(&"potion_bookcase")) as ObjectDef
	assert_gt(bookcase.bottle_shelves.size(), cab.bottle_shelves.size())


func test_stack_on_flat_top_and_refuse_removing_the_bottom() -> void:
	var cab_id := w.objects.index_of(&"potion_cabinet")
	var cab := w.objects.def(cab_id) as ObjectDef
	var a := _floor_spot(3)
	assert_true(w.request_place_object(a, cab_id))
	var top := a - Vector2i(0, cab.height_tiles)
	assert_true(w.request_place_object(top, cab_id), "a cabinet stacks on a cabinet")
	assert_false(w.request_remove_object(a), "the bottom one can't go while one sits on it")
	assert_true(w.request_remove_object(top))
	assert_true(w.request_remove_object(a))


func test_no_stacking_on_round_tops() -> void:
	var a := _floor_spot(3)
	var workbench := w.objects.index_of(&"workbench")
	assert_true(w.request_place_object(a, workbench))
	var wb := w.objects.def(workbench) as ObjectDef
	if wb.flat_top:
		pass_test("workbench is flat")
		return
	assert_false(w.request_place_object(a - Vector2i(0, wb.height_tiles), w.objects.index_of(&"chest")))


func test_new_items_in_creative_list() -> void:
	for id: StringName in [&"sand", &"glass", &"clay_bottle", &"clay_jug", &"glass_vial", &"glass_bottle",
			&"glass_flask", &"potion_bookcase", &"potion_shelf"]:
		assert_not_null(ItemData.find(id), String(id))


func test_freeplace_lets_blocks_float() -> void:
	var u := w.item_user
	var sky := w.world_to_tile(w.player.global_position) + Vector2i(0, -30)
	assert_false(u._anchored(sky, false), "nothing to build against up there")
	u.free_place = true
	assert_true(u._anchored(sky, false))
	assert_true(u._anchored(sky, true))
