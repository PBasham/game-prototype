extends GutTest
## Phase 37: filled bottles, pantries, bookshelf, barrel, crate, hanging nets, liquid
## barrels, torch light in hand, rope joins and extend, the Catalog search.

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


func test_bigger_bottles_are_stronger_and_glass_beats_clay() -> void:
	var heal := func(id: StringName) -> float: return ItemData.find(id).heal_value
	var mana := func(id: StringName) -> float: return ItemData.find(id).mana_value
	assert_gt(heal.call(&"healing_clay_bottle"), heal.call(&"healing_potion"))
	assert_gt(heal.call(&"healing_clay_jug"), heal.call(&"healing_clay_bottle"))
	assert_gt(heal.call(&"healing_glass_vial"), heal.call(&"healing_potion"), "glass beats clay, same size")
	assert_gt(heal.call(&"healing_glass_bottle"), heal.call(&"healing_clay_bottle"))
	assert_gt(heal.call(&"healing_glass_flask"), heal.call(&"healing_clay_jug"))
	assert_gt(mana.call(&"mana_glass_flask"), mana.call(&"mana_clay_jug"))
	assert_gt(ItemData.find(&"healing_clay_jug").sickness_seconds, ItemData.find(&"healing_potion").sickness_seconds, "bigger: sick longer")
	var r := Registry.get_def(&"recipes", &"healing_glass_flask") as RecipeData
	assert_eq(r.station, &"alchemy")
	assert_eq(r.inputs.get(&"glass_flask", 0), 1, "brewed in its empty bottle")
	assert_true(ItemData.find(&"mana_clay_bottle").has_storage_tag(&"potion"))


func test_food_and_book_storage_take_only_their_kind() -> void:
	var food := Inventory.new(4)
	food.accepts_tag = &"food"
	assert_true(food.accepts(&"berries"))
	assert_true(food.accepts(&"mushroom_stew"))
	assert_false(food.accepts(&"healing_potion"), "potions go in the potion cabinet")
	assert_false(food.accepts(&"poison_coating"))
	assert_false(food.accepts(&"wood"))
	var books := Inventory.new(4)
	books.accepts_tag = &"book"
	for id: StringName in [&"basic_spellbook", &"scroll_spark", &"page_spark", &"paper", &"blank_scroll"]:
		assert_true(books.accepts(id), String(id))
	assert_false(books.accepts(&"berries"))


func test_storage_furniture_sizes_and_slots() -> void:
	var want := {&"pantry_rack": [3, 3, 8], &"food_pantry": [3, 4, 14], &"bookshelf": [3, 4, 12],
		&"barrel": [2, 2, 10], &"crate": [2, 2, 12], &"hanging_net_small": [3, 2, 6],
		&"hanging_net_medium": [2, 3, 8], &"hanging_net_large": [6, 4, 16]}
	for id: StringName in want:
		var d := w.objects.def(w.objects.index_of(id)) as ObjectDef
		assert_not_null(d, String(id))
		assert_eq([d.width_tiles, d.height_tiles, d.container_slots], want[id], String(id))
		assert_not_null(d.frames, "%s has art" % id)
	for id: StringName in [&"potion_cabinet", &"potion_bookcase", &"hanging_net_small", &"hanging_net_large"]:
		assert_eq((w.objects.def(w.objects.index_of(id)) as ObjectDef).front_frame, 1, "%s: glass / mesh over what's inside" % id)
	var iron := w.objects.def(w.objects.index_of(&"iron_liquid_barrel")) as ObjectDef
	var wood := w.objects.def(w.objects.index_of(&"liquid_barrel")) as ObjectDef
	assert_gt(iron.liquid_capacity, wood.liquid_capacity, "the iron one holds more")
	for id: StringName in [&"liquid_barrel", &"iron_liquid_barrel"]:
		assert_true((Registry.get_def(&"recipes", id) as RecipeData).inputs.has(&"iron_bar"), "%s needs iron" % id)


func test_nets_hang_from_a_block_above() -> void:
	var id := w.objects.index_of(&"hanging_net_small")
	var def := w.objects.def(id) as ObjectDef
	var a := _floor_spot(3) + Vector2i(0, -6)
	assert_false(w.can_place_object(a, def), "nothing to hang from")
	var above := a + Vector2i(def.hang_points[0], -def.height_tiles)
	w.data.set_block(above.x, above.y, w.blocks.index_of(&"stone"))
	assert_true(w.can_place_object(a, def), "hangs from the block")
	assert_true(w.request_place_object(a, id))
	assert_not_null(w.container_at(a), "it's storage")


func test_holding_a_torch_lights_around_you() -> void:
	w.character.inventory.set_slot(0, &"torch", 5)
	w.player.select_slot(0)
	w.item_user._update_held_light()  # (what ItemUser does every frame)
	var lit := w.dynamic_lights().filter(func(l: Array) -> bool: return float(l[1]) == ItemData.find(&"torch").held_light_radius)
	assert_eq(lit.size(), 1, "the torch in hand is a light")
	w.character.inventory.set_slot(0, &"wood", 5)
	w.player.select_slot(1)
	w.item_user._update_held_light()
	lit = w.dynamic_lights().filter(func(l: Array) -> bool: return float(l[1]) == ItemData.find(&"torch").held_light_radius)
	assert_eq(lit.size(), 0, "put away: dark")


func test_clicking_a_rope_adds_to_its_bottom() -> void:
	var rope := w.objects.index_of(&"rope")
	var top := _floor_spot(4) + Vector2i(0, -10)
	w.data.set_block(top.x, top.y - 1, w.blocks.index_of(&"stone"))
	for k in 3:
		w.data.set_object(top.x, top.y + k, rope)
	assert_eq(w.item_user.rope_end(top, rope), top + Vector2i(0, 3), "below the last one")
	assert_eq(w.item_user.rope_end(top + Vector2i(0, 2), rope), top + Vector2i(0, 3))


func test_catalog_search_shows_only_found_matches() -> void:
	var cat := w.hud._catalog
	w.character.inventory.add(&"berries", 1)
	cat.search = "berr"
	var names := cat._items().map(func(it: ItemData) -> StringName: return it.id)
	assert_has(names, &"berries")
	assert_does_not_have(names, &"raspberries", "not found yet: hidden from the search")
	cat.search = ""
	assert_eq(cat._items().size(), Catalog.all_items().size())


func test_tall_bottles_fit_under_the_shelf_above() -> void:
	var cab := w.objects.def(w.objects.index_of(&"potion_cabinet")) as ObjectDef
	var room := ObjectLayer.shelf_room(cab, 0)
	assert_eq(room, 13.0, "16 px apart, less the plank and 1 px of air")
	var jug := ObjectLayer.shelf_texture(ItemData.find(&"healing_clay_jug"), int(room))
	assert_lte(jug.get_height(), 13)


func test_freecraft_empowers_for_nothing() -> void:
	var c := w.character
	var spell := ItemData.find(ItemData.spell_key(&"mining_spell")) as SpellData
	var node := Registry.get_def(&"empower", &"mining_power") as EmpowerNode
	c.empower.erase(&"mining_spell")
	for id: StringName in [&"copper_bar", &"iron_bar"]:
		c.inventory.remove(id, c.inventory.count_of(id))
	assert_ne(c.empower_problem(spell, node), "", "no bars: can't")
	assert_eq(c.empower_problem(spell, node, true), "", "freecraft: can")
	var before := c.empower_rank(&"mining_spell", &"mining_power")
	assert_true(c.buy_empower(spell, node, true))
	assert_eq(c.empower_rank(&"mining_spell", &"mining_power"), before + 1)
