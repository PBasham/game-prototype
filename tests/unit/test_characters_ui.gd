extends GutTest
## Phase 6: character saves and looks, inventory sizes, station sizes, and the crafting
## and chest windows.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const TEST_NAME := "gut test character"

var w: World


func after_each() -> void:
	if w:
		w.queue_free()
		await wait_physics_frames(2)
		w = null
	Game.world_info = null
	Game.character = null
	if CharacterData.exists(TEST_NAME):
		CharacterData.delete(TEST_NAME)


func _world() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)


func _floor_spot(dx: int) -> Vector2i:
	var feet := w.world_to_tile(w.player.global_position)
	return Vector2i(feet.x + dx, feet.y - 1)


func test_character_looks_save_and_load() -> void:
	var c := CharacterData.create(TEST_NAME)
	c.colors[&"tunic"] = Color("3a7a3a")
	c.colors[&"skin"] = Color("9a5f3a")
	c.hairstyle = &""
	assert_eq(c.save(), OK)
	assert_true(CharacterData.exists(TEST_NAME))
	var back := CharacterData.load_file(SaveManager.character_path(TEST_NAME))
	assert_not_null(back)
	assert_eq(back.colors[&"tunic"].to_html(false), "3a7a3a")
	assert_eq(back.colors[&"skin"].to_html(false), "9a5f3a")
	assert_eq(back.hairstyle, &"", "bald stays bald")
	var look := back.make_look()
	assert_null(look.hair)
	assert_eq(look.colors.size(), 2)
	var names: Array[String] = []
	for saved in CharacterData.list_saved():
		names.append(saved.name)
	assert_has(names, TEST_NAME, "listed on the character page")
	assert_eq(CharacterData.delete(TEST_NAME), OK)
	assert_false(CharacterData.exists(TEST_NAME))


func test_old_characters_get_the_default_look() -> void:
	var c := CharacterData.create(TEST_NAME)
	assert_eq(c.hairstyle, CharacterData.DEFAULT_HAIR)
	assert_has(CharacterData.hairstyles(), CharacterData.DEFAULT_HAIR)
	assert_not_null(c.make_look().hair, "the default hairstyle loads")


func test_inventory_size_is_data() -> void:
	var small := Inventory.new(20)
	assert_eq(small.size, 20)
	var full := Inventory.max_stack(&"dirt")
	small.add(&"dirt", full * 25)
	assert_eq(small.count_of(&"dirt"), full * 20, "only 20 slots")
	var d := small.to_dict()
	var back := Inventory.new()
	back.from_dict(d)
	assert_eq(back.size, 20, "the saved size wins")
	back.resize(30)
	assert_eq(back.size, 30)
	assert_eq(back.room_for(&"dirt"), full * 10, "a bag's worth of new slots")


func test_stations_are_hip_height() -> void:
	var bench := Registry.get_def(&"objects", &"workbench") as ObjectDef
	assert_eq(Vector2i(bench.width_tiles, bench.height_tiles), Vector2i(5, 4))
	assert_eq(bench.frames.get_height(), 4 * World.TILE * bench.detail)
	var furnace := Registry.get_def(&"objects", &"furnace") as ObjectDef
	assert_eq(Vector2i(furnace.width_tiles, furnace.height_tiles), Vector2i(4, 5))


func test_station_opens_its_own_window() -> void:
	await _world()
	var a := _floor_spot(3)
	assert_true(w.request_place_object(a, w.objects.index_of(&"workbench")))
	# Any tile of the 5 wide bench finds it.
	assert_eq(w.object_anchor(a + Vector2i(4, -3)), w.wrap_tile(a))
	assert_true(w.try_interact_at(w.tile_to_world(a + Vector2i(2, -1)) + Vector2(4, 4), w.player))
	assert_true(w.hud.open, "the inventory opens too")
	assert_true(w.hud.crafting)
	assert_true(w.hud._craft.visible)
	assert_false(w.hud._inv.get_rect().intersects(w.hud._craft.get_rect()), "a window apart from the inventory")
	assert_gt(w.hud._craft.position.x, 320.0, "on the right side")
	w.hud.close_window()
	assert_false(w.hud._craft.visible)
	assert_true(w.hud.open, "closing the window keeps the inventory open")
	assert_eq(w.hud.station, World.NO_TILE)


func test_hand_crafting_window_and_buttons() -> void:
	await _world()
	w.hud.toggle_crafting()
	assert_true(w.hud.open)
	assert_true(w.hud._craft.visible)
	var list := w.hud.recipes()
	var planks := list.find(list.filter(func(r: RecipeData) -> bool: return r.id == &"wood_platform")[0])
	w.character.inventory.remove(&"wood", w.character.inventory.count_of(&"wood"))
	w.character.inventory.add(&"wood", 5)
	var before := w.character.inventory.count_of(&"wood_platform")
	w.hud.selected_recipe = planks
	# Ctrl + click Craft: as many as you can.
	var b := w.hud._craft_button_rects()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.ctrl_pressed = true
	click.position = b[Hud.CraftBtn.CRAFT].get_center()
	w.hud._crafting_input(w.hud._craft, click)
	assert_eq(w.character.inventory.count_of(&"wood"), 0)
	assert_eq(w.character.inventory.count_of(&"wood_platform"), before + 10)
	w.hud.toggle_crafting()
	assert_false(w.hud.crafting)


func test_chest_window_take_and_deposit() -> void:
	await _world()
	var a := _floor_spot(4)
	assert_true(w.request_place_object(a, w.objects.index_of(&"chest")))
	assert_true(w.try_interact_at(w.tile_to_world(a) + Vector2(4, 4), w.player))
	assert_true(w.hud._chest.visible)
	assert_false(w.hud._craft.visible)
	var store := w.container_at(a)
	var inv := w.character.inventory
	inv.set_slot(Inventory.HOTBAR + 5, &"stone", 30)
	var hot := inv.ids[0]
	w.hud.deposit_all(store)
	assert_eq(store.count_of(&"stone"), 30, "below-hotbar items go in")
	assert_eq(inv.ids[0], hot, "the hotbar stays")
	for i in store.size:
		w.hud._move_stack(store, i, inv)
	assert_eq(inv.count_of(&"stone"), 30, "take all")
	assert_true(store.is_all_empty())


func test_doors_open_in_place_away_from_the_player() -> void:
	await _world()
	var right := _floor_spot(6)
	assert_true(w.request_place_object(right, w.objects.index_of(&"door")))
	assert_true(w.request_toggle_object(right + Vector2i(0, -3)))
	assert_eq(w.object_at(right).id, &"door_open", "player on the left: hinge on the left")
	assert_eq(w.data.get_object(right.x + 1, right.y), WorldData.AIR, "same 1x8 footprint")
	assert_false(w.object_at(right).blocks_movement)
	assert_true(w.request_toggle_object(right + Vector2i(0, -2)))
	assert_eq(w.object_at(right).id, &"door")
	var left := _floor_spot(-6)
	assert_true(w.request_place_object(left, w.objects.index_of(&"door")))
	assert_true(w.request_toggle_object(left))
	assert_eq(w.object_at(left).id, &"door_open_left", "player on the right: hinge on the right")
	assert_true(w.request_toggle_object(left))
	assert_eq(w.object_at(left).id, &"door")
	# Blocks where it would swing: it opens the other way; blocked both ways, it stays shut.
	for y in 8:
		w.request_set_block(left + Vector2i(-2, -y), w.blocks.index_of(&"dirt"))
	assert_true(w.request_toggle_object(left))
	assert_eq(w.object_at(left).id, &"door_open", "blocked on the left: swings right")
	assert_true(w.request_toggle_object(left))
	for y in 8:
		w.request_set_block(left + Vector2i(2, -y), w.blocks.index_of(&"dirt"))
	assert_false(w.request_toggle_object(left), "blocked both ways")
	assert_eq(w.object_at(left).id, &"door")


func test_drops_are_sized_by_item() -> void:
	var stick := ItemData.find(&"torch")
	var axe := ItemData.find(&"copper_sword")
	var bench := ItemData.find(&"workbench")
	assert_lt(stick.drop_pixels(), axe.drop_pixels())
	assert_lt(axe.drop_pixels(), bench.drop_pixels())
