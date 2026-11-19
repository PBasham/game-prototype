extends GutTest
## Items on display: on floors, tables and shelves (not stations), taken back with a
## right click, saved with the world, and falling off when the table goes.

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


func _point(t: Vector2i) -> Vector2:
	return w.tile_to_world(t) + Vector2(4, 4)


func test_place_and_take_back_on_the_floor() -> void:
	var p := w.player
	var inv := w.character.inventory
	inv.set_slot(0, &"healing_potion", 3)
	p.select_slot(0)
	var t := _floor_spot(3)
	assert_true(w.try_place_display(_point(t), p))
	assert_eq(inv.counts[0], 2, "one taken from the stack")
	assert_eq(w.displayed_item(t).id, &"healing_potion")
	assert_false(w.try_place_display(_point(t), p), "one per spot")
	assert_true(w.try_interact_at(_point(t), p), "right click takes it back")
	assert_eq(inv.counts[0], 3)
	assert_null(w.displayed_item(t))
	assert_eq(w.data.get_object(t.x, t.y), 0)


func test_what_can_be_displayed() -> void:
	var t := _floor_spot(3)
	assert_true(w.can_display_at(t, ItemData.find(&"copper_bar")))
	assert_false(w.can_display_at(t, ItemData.find(&"copper_pickaxe")), "no tools")
	assert_false(w.can_display_at(t, ItemData.find(&"copper_sword")), "no weapons")
	assert_false(w.can_display_at(t, ItemData.find(&"dirt")), "no blocks")
	assert_false(w.can_display_at(t, ItemData.find(&"chest")), "no furniture")
	assert_false(w.can_display_at(t + Vector2i(0, -2), ItemData.find(&"copper_bar")), "not in mid air")


func test_tables_and_shelves_but_not_stations() -> void:
	var table := _floor_spot(2)
	assert_true(w.request_place_object(table, w.objects.index_of(&"table")))
	var top := table + Vector2i(1, -3)
	assert_true(w.request_place_display(top, &"mana_potion"), "on the table top")
	var bench := _floor_spot(8)
	assert_true(w.request_place_object(bench, w.objects.index_of(&"workbench")))
	assert_false(w.can_display_at(bench + Vector2i(1, -4), ItemData.find(&"mana_potion")), "not on stations")
	# Shelf: needs a back wall.
	var shelf := _floor_spot(-6) + Vector2i(0, -3)
	assert_false(w.request_place_object(shelf, w.objects.index_of(&"shelf")), "no wall behind")
	for dx in 3:
		w.request_set_wall(shelf + Vector2i(dx, 0), w.walls.index_of(&"wood_wall"))
	assert_true(w.request_place_object(shelf, w.objects.index_of(&"shelf")))
	assert_true(w.request_place_display(shelf + Vector2i(1, -1), &"red_cap"), "on the shelf")
	# Saved and loaded back.
	var d := w._displays_to_dict()
	w.displays.clear()
	w._displays_from_dict(d)
	assert_eq(w.displayed_item(top).id, &"mana_potion")
	# The table goes: what's on it falls off as an item.
	var drops := w.drop_count()
	assert_true(w.request_remove_object(table))
	await wait_physics_frames(1)
	assert_null(w.displayed_item(top))
	assert_gt(w.drop_count(), drops, "dropped")


func test_detailed_stations() -> void:
	for id: StringName in [&"workbench", &"furnace", &"copper_anvil", &"campfire", &"alchemy_table", &"spell_weaving_table"]:
		var def := w.objects.def(w.objects.index_of(id)) as ObjectDef
		assert_eq(def.detail, 2, String(id))
		assert_eq(def.frames.get_width(), def.width_tiles * World.TILE * 2, String(id) + " art is 2x")
