extends GutTest
## Cooking at the campfire, the Alchemy Table, potions, sickness, food buffs, poison
## coatings and thrown poison flasks, in a running test-course world.

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


func _slime() -> EnemyData:
	return Registry.get_def(&"enemies", &"green_slime") as EnemyData


func _hold(id: StringName, count: int) -> void:
	w.character.inventory.set_slot(0, id, count)
	w.player.select_slot(0)


func _open_station(id: StringName) -> void:
	var a := _floor_spot(3)
	assert_true(w.request_place_object(a, w.objects.index_of(id)))
	assert_true(w.try_interact_at(w.tile_to_world(a + Vector2i(1, -1)) + Vector2(4, 4), w.player))
	assert_true(w.hud.open)


func _names() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in w.hud.recipes():
		out.append(r.id)
	return out


func test_campfire_cooks() -> void:
	_open_station(&"campfire")
	var names := _names()
	for id: StringName in [&"roasted_berries", &"cooked_mushroom", &"mushroom_stew"]:
		assert_has(names, id)
	var inv := w.character.inventory
	inv.add(&"berries", 6)
	var berries := inv.count_of(&"berries")
	var made := w.hud.craft(w.hud.recipes()[names.find(&"roasted_berries")], 99)
	assert_eq(made, berries / 3, "3 berries each")
	assert_eq(inv.count_of(&"roasted_berries"), made)


func test_alchemy_table_tabs() -> void:
	_open_station(&"alchemy_table")
	assert_eq(w.hud._tabs(), ["Potions", "Coatings", "Flasks"])
	w.hud.craft_tab = 0
	assert_eq(_names(), [&"healing_potion", &"mana_potion"] as Array[StringName])
	w.hud.craft_tab = 1
	assert_eq(_names(), [&"poison_coating"] as Array[StringName])
	w.hud.craft_tab = 2
	assert_eq(_names(), [&"poison_flask"] as Array[StringName])


func test_potions_and_sickness() -> void:
	var p := w.player
	_hold(&"healing_potion", 2)
	p.health = 10.0
	assert_true(w.item_user.eat_held())
	assert_almost_eq(p.health, 40.0, 0.01)
	assert_true(p.has_buff(&"sick_healing"))
	p.health = 10.0
	assert_false(w.item_user.eat_held(), "sick: can't drink another yet")
	assert_eq(w.character.inventory.counts[0], 1)
	_hold(&"mana_potion", 1)
	p.mana = 0.0
	assert_true(w.item_user.eat_held(), "different sickness")
	assert_almost_eq(p.mana, minf(40.0, p.max_mana), 0.01)


func test_stew_well_fed() -> void:
	var p := w.player
	var speed := p.stat(&"move_speed")
	_hold(&"mushroom_stew", 1)
	p.hunger = 10.0
	assert_true(w.item_user.eat_held())
	assert_almost_eq(p.hunger, 50.0, 0.01)
	assert_true(p.has_buff(&"item_mushroom_stew"))
	assert_almost_eq(p.stat(&"move_speed"), speed + 0.1, 0.001)
	assert_almost_eq(p._food_regen(), 0.5, 0.001)


func test_poison_coating_poisons_on_hit() -> void:
	var p := w.player
	_hold(&"poison_coating", 1)
	assert_false(w.item_user.eat_held(), "not drunk: it goes on a weapon")
	# Coat the sword: coating on the mouse, right click the sword's slot.
	var c := w.character
	c.inventory.set_slot(12, &"wooden_sword", 1)
	w.hud.cursor_id = &"poison_coating"
	w.hud.cursor_count = 2
	w.hud.right_click_slot(12)
	assert_eq(w.hud.cursor_count, 1, "one coating used")
	assert_eq(c.coating_on(&"wooden_sword")[1], 10)
	w.hud.cursor_count = 0
	w.hud.cursor_id = &""
	assert_string_contains(Hud.tooltip_for(ItemData.find(&"wooden_sword"), c), "Poison Coating: 10 hits left")
	var e := w.request_spawn_enemy(_slime(), p.global_position + Vector2(20 * p.facing, 0))
	e.health = 999.0
	await wait_physics_frames(2)
	w.item_user.cursor_override = p.chest() + Vector2(40 * p.facing, 0)
	assert_eq(w.item_user.melee_hit(ItemData.find(&"wooden_sword")), 1)
	assert_true(e.is_poisoned())
	assert_eq(c.coating_on(&"wooden_sword")[1], 9, "no timer: just hits")
	# Other weapons aren't coated; the dummy can be poisoned too.
	assert_true(c.coating_on(&"copper_sword").is_empty())
	var dummy := DevDummy.new()
	w.add_child(dummy)
	dummy.poison(2.0, 3.0)
	assert_true(dummy.is_poisoned())
	dummy.queue_free()
	var before := e.health
	e._tick_poison(1.0)
	assert_almost_eq(e.health, before - 2.0, 0.01, "2 per second")


func test_poison_flask_cloud() -> void:
	var p := w.player
	var e := w.request_spawn_enemy(_slime(), p.global_position + Vector2(6 * World.TILE * p.facing, 0))
	e.health = 999.0
	await wait_physics_frames(2)
	var c := PoisonCloud.new()
	w.add_child(c)
	c.start(w, ItemData.find(&"poison_flask"), e.global_position)
	assert_true(e.is_poisoned(), "inside the cloud")
	_hold(&"poison_flask", 2)
	w.item_user.cursor_override = p.chest() + Vector2(40 * p.facing, 0)
	assert_true(w.item_user.throw_held())
	assert_eq(w.character.inventory.counts[0], 1)
