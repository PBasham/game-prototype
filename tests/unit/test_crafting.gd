extends GutTest
## Crafting, stations, furniture, chests, doors, ground pickups and mana, in a running
## test-course world.

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


## A spot on the flat ground near the player: the tile just above the ground.
func _floor_spot(dx: int) -> Vector2i:
	var feet := w.world_to_tile(w.player.global_position)
	return Vector2i(feet.x + dx, feet.y - 1)


func test_every_recipe_is_valid() -> void:
	var all := Registry.get_all(&"recipes")
	assert_gt(all.size(), 10)
	var stations := [&"", &"workbench", &"furnace", &"anvil"]
	for d in all:
		var r := d as RecipeData
		assert_eq(r.validate(), PackedStringArray(), "%s valid" % r.id)
		assert_not_null(ItemData.find(r.output), "%s output exists" % r.id)
		for k: StringName in r.inputs:
			assert_not_null(ItemData.find(k), "%s input %s exists" % [r.id, k])
		for q in r.requires:
			assert_not_null(ItemData.find(q), "%s needs %s, which exists" % [r.id, q])
		assert_true(r.station in stations, "%s station %s" % [r.id, r.station])


func test_hand_crafting_and_required_tools() -> void:
	var inv := Inventory.new()
	var hammer := Registry.get_def(&"recipes", &"hand_hammer") as RecipeData
	var bench := Registry.get_def(&"recipes", &"workbench") as RecipeData
	assert_eq(Crafting.times_craftable(inv, hammer), 0)
	inv.add(&"rock", 2)
	inv.add(&"stick", 3)
	assert_eq(Crafting.times_craftable(inv, hammer), 2)
	assert_eq(Crafting.craft(inv, hammer, 1)[0], 1)
	assert_eq(inv.count_of(&"hand_hammer"), 1)
	assert_eq(inv.count_of(&"rock"), 1)
	inv.add(&"wood_planks", 10)
	inv.remove(&"hand_hammer", 1)
	assert_eq(Crafting.times_craftable(inv, bench), 0, "needs the Hand Hammer on you")
	assert_true("Hand Hammer (not used up)" in Crafting.missing(inv, bench))
	inv.add(&"hand_hammer", 1)
	assert_eq(Crafting.craft(inv, bench, 1)[0], 1)
	assert_eq(inv.count_of(&"hand_hammer"), 1, "the hammer isn't used up")
	assert_eq(inv.count_of(&"workbench"), 1)
	assert_true(Crafting.recipes_for(&"") .has(hammer))
	assert_false(Crafting.recipes_for(&"").has(Registry.get_def(&"recipes", &"copper_bar")), "smelting needs a furnace")


func test_furniture_footprint_floor_and_removal() -> void:
	var bench := w.objects.index_of(&"workbench")
	var def := w.objects.def(bench) as ObjectDef
	var a := _floor_spot(4)
	assert_true(w.request_place_object(a, bench))
	for t in World.footprint(a, def):
		assert_eq(w.object_anchor(t), w.wrap_tile(a), "every tile points at the anchor")
	assert_eq(w.object_def_at(a + Vector2i(2, -1)), def)
	assert_false(w.can_place_object(a + Vector2i(1, 0), def), "can't overlap")
	var floating := a + Vector2i(8, -5)
	assert_false(w.can_place_object(floating, def), "needs a floor")
	# Its floor can't be mined.
	assert_true(w.is_protected(a + Vector2i(1, 1)))
	assert_false(w.request_damage_block(a + Vector2i(1, 1), 10000.0))
	# Mining it (any of its tiles) picks it up.
	var drops := w.drop_count()
	assert_true(w.request_damage_block(a + Vector2i(2, -1), 1.0))
	for t in World.footprint(a, def):
		assert_eq(w.data.get_object(t.x, t.y), WorldData.AIR)
	assert_eq(w.drop_count(), drops + 1)


func test_stations_open_their_recipes() -> void:
	var a := _floor_spot(3)
	assert_true(w.request_place_object(a, w.objects.index_of(&"furnace")))
	var point := w.tile_to_world(a + Vector2i(1, -1)) + Vector2(4, 4)
	assert_true(w.try_interact_at(point, w.player))
	assert_eq(w.hud.station, w.wrap_tile(a))
	assert_true(w.hud.open)
	var names: Array[StringName] = []
	for r in w.hud.recipes():
		names.append(r.id)
	assert_eq(names, [&"copper_bar"] as Array[StringName], "the furnace's list")
	w.character.inventory.add(&"copper_ore", 7)
	var before := w.character.inventory.count_of(&"copper_bar")
	assert_eq(w.hud.craft(w.hud.recipes()[0], 10), 2, "7 ore makes 2 bars")
	assert_eq(w.character.inventory.count_of(&"copper_bar"), before + 2)
	w.hud.set_open(false)
	assert_eq(w.hud.station, World.NO_TILE)
	assert_eq(w.hud.recipes()[0].station, &"", "hand crafting again")


func test_doors_open_close_and_block() -> void:
	var a := _floor_spot(6)
	assert_true(w.request_place_object(a, w.objects.index_of(&"door")))
	assert_true((w.object_at(a)).blocks_movement)
	assert_true(w.request_toggle_object(a + Vector2i(0, -3)))
	assert_eq(w.object_at(a).id, &"door_open")
	assert_false(w.object_at(a).blocks_movement)
	assert_true(w.request_toggle_object(a))
	assert_eq(w.object_at(a).id, &"door")
	# A closed door stops the player walking through it.
	await wait_physics_frames(2)
	Input.action_press("move_right")
	await wait_seconds(1.0)
	Input.action_release("move_right")
	assert_lt(w.player.global_position.x, float((a.x) * World.TILE), "stopped at the door")


func test_chests_store_and_save() -> void:
	var a := _floor_spot(4)
	assert_true(w.request_place_object(a, w.objects.index_of(&"chest")))
	var store := w.container_at(a + Vector2i(1, -1))
	assert_not_null(store)
	store.add(&"stone", 42)
	assert_false(w.request_remove_object(a), "not while something's inside")
	var d := w._containers_to_dict()
	w.containers.clear()
	w._containers_from_dict(d)
	assert_eq(w.container_at(a).count_of(&"stone"), 42, "saved and loaded back")
	assert_true(w.try_interact_at(w.tile_to_world(a) + Vector2(4, 4), w.player))
	assert_eq(w.hud.chest, w.wrap_tile(a))
	w.container_at(a).remove(&"stone", 42)
	assert_true(w.request_remove_object(a), "empty: picks up")


func test_picking_things_up_off_the_grass() -> void:
	var plants := w.plants
	var g := _floor_spot(5) + Vector2i.DOWN
	plants._add(w.wrap_tile(g), PlantLayer.Kind.PICKUP, 2)  # flint
	var before := w.character.inventory.count_of(&"flint")
	assert_true(w.try_interact_at(w.tile_to_world(g + Vector2i.UP) + Vector2(4, 6), w.player))
	assert_eq(w.character.inventory.count_of(&"flint"), before + 1)
	assert_null(plants.plant_at(g), "gone from the grass")


func test_mana_costs_and_runs_out() -> void:
	var p := w.player
	p.mana = 100.0
	var fly := ItemData.find(&"spell:fly") as SpellData
	assert_eq(fly.mana_per_second, 10.0)
	p.toggle_concentration(fly)
	await wait_seconds(1.0)
	assert_lt(p.mana, 95.0, "flying drains")
	p.mana = 0.5
	await wait_seconds(0.2)
	assert_false(p.is_flying(), "out of mana: Fly ends")
	p.infinite_mana = true
	assert_true(p.spend_mana(1000.0))
	p.infinite_mana = false
	assert_false(p.spend_mana(1000.0))
