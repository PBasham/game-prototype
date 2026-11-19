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
	# Hand crafting, plus every station some furniture provides.
	var stations: Array[StringName] = [&""]
	for o in Registry.get_all(&"objects"):
		var def := o as ObjectDef
		if def and def.station != &"" and not def.station in stations:
			stations.append(def.station)
	assert_true(&"spell_weaving" in stations, "the Spell Weaving Table is a station")
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
	inv.add(&"stone", 2)
	inv.add(&"wood", 3)
	assert_eq(Crafting.times_craftable(inv, hammer), 2)
	assert_eq(Crafting.craft(inv, hammer, 1)[0], 1)
	assert_eq(inv.count_of(&"hand_hammer"), 1)
	assert_eq(inv.count_of(&"stone"), 1)
	# Older saves: Rock items load as Stone.
	var old := Inventory.new()
	old.from_dict({"slots": [["rock", 4], ["flint", 2], ["stick", 3], ["wood_planks", 5]]})
	assert_eq(old.count_of(&"stone"), 6, "rocks and flint load as Stone")
	assert_eq(old.count_of(&"wood"), 8, "sticks and planks load as Wood")
	inv.add(&"wood", 10)
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
	# Open, any visible part of the swung face closes it with a click.
	assert_true(w.request_toggle_object(a))
	var open_at := w.object_anchor(a + Vector2i(0, -3))
	var face := World.sprite_tiles(open_at, w.object_at(open_at))
	assert_gt(face.size(), 0)
	assert_eq(w.object_anchor_visual(face[0]), open_at)
	var near := face[0]
	for t in face:
		if Vector2(t * World.TILE).distance_to(w.player.chest()) < Vector2(near * World.TILE).distance_to(w.player.chest()):
			near = t
	assert_true(w.try_interact_at(Vector2(near) * World.TILE + Vector2(4, 4), w.player))
	assert_eq(w.object_def_at(a + Vector2i(0, -1)).id, &"door", "closed again")
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
	var forage := w.forage
	var g := _floor_spot(5) + Vector2i.DOWN
	forage._add(w.wrap_tile(g), _forage(&"stick"))
	var before := w.character.inventory.count_of(&"wood")
	assert_true(w.try_interact_at(w.tile_to_world(g + Vector2i.UP) + Vector2(4, 6), w.player))
	assert_eq(w.character.inventory.count_of(&"wood"), before + 1, "a stick gives Wood")
	assert_null(forage.at(g), "gone from the grass")
	# E picks up the nearest one.
	for t in forage._items.keys():
		forage._remove(t)
	forage._add(w.wrap_tile(g), _forage(&"stick"))
	var sticks := w.character.inventory.count_of(&"wood")
	assert_true(w.try_interact_near(w.player))
	assert_eq(w.character.inventory.count_of(&"wood"), sticks + 1)
	# A loose rock gives Stone.
	forage._add(w.wrap_tile(g), _forage(&"rock"))
	var stone := w.character.inventory.count_of(&"stone")
	assert_true(w.try_interact_near(w.player))
	assert_eq(w.character.inventory.count_of(&"stone"), stone + 1)
	# Digging out the ground under one drops it.
	forage._add(w.wrap_tile(g), _forage(&"rock"))
	w.request_set_block(g, WorldData.AIR)
	assert_null(forage.at(g), "dropped when its ground went away")


func test_logs_make_wood_and_build_log_cabins() -> void:
	var inv := Inventory.new()
	var r := Registry.get_def(&"recipes", &"wood") as RecipeData
	inv.add(&"log", 2)
	assert_eq(Crafting.craft(inv, r, 2)[0], 2)
	assert_eq(inv.count_of(&"wood"), 8, "1 log = 4 wood")
	var log := ItemData.find(&"log")
	assert_eq(log.places_block, &"log")
	assert_eq(log.places_wall, &"log_wall")
	assert_eq(w.blocks.def(w.blocks.index_of(&"log")).drop_item, &"", "a log block gives the log back")
	assert_eq((w.walls.def(w.walls.index_of(&"log_wall")) as TileDef).drop_item, &"log")
	# Bigger trees, more logs.
	assert_eq(w.plants.logs_for(13.8), 2)
	assert_eq(w.plants.logs_for(18.1), 3)
	assert_eq(w.plants.logs_for(24.4), 4)
	# Torches need slime.
	for t in Crafting.recipes_for(&""):
		if t.output == &"torch":
			assert_true(t.inputs.has(&"slime"), "%s needs slime" % t.id)


func _forage(id: StringName) -> ForageData:
	return Registry.get_def(&"forage", id) as ForageData


func test_forage_types_are_data_and_old_saves_move_over() -> void:
	var f := w.forage
	assert_eq(f.defs.size(), 2)
	assert_eq(f._pick(ChunkBuildJob.FLOOR_CAVE, 0.0).id, &"rock", "sorted by id: rock, stick")
	for i in 50:
		assert_ne(f._pick(ChunkBuildJob.FLOOR_CAVE, randf()).id, &"stick", "no sticks in caves")
	# A pre-Forage save: plants held the sticks, rocks and flint.
	var g := w.wrap_tile(_floor_spot(-6) + Vector2i.DOWN)
	var wc := f._chunk_of(g)
	f._seeded.erase(wc)
	w.plants.from_dict({"%d,%d" % [wc.x, wc.y]: [[g.x, g.y, PlantLayer.Kind.PICKUP, 2, 0.0, 0.0]]}, false)
	assert_eq(f.at(g).id, &"rock", "moved to the Forage node (old flint is a rock now)")
	assert_null(w.plants.plant_at(g))
	assert_true(f._seeded.has(wc), "not seeded twice")
	# Saved and loaded back.
	var d := f.to_dict([])
	f._remove(g)
	f.from_dict(d)
	assert_eq(f.at(g).id, &"rock")


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


## Open ground away from the player (off screen): grass, dirt or stone with air above,
## no wall or object there, and room for a few neighbors on the same row.
func _open_ground() -> Vector2i:
	var feet := w.world_to_tile(w.player.global_position)
	for dx in range(150, 600):
		for dy in range(-30, 30):
			var g := w.wrap_tile(Vector2i(feet.x + dx, feet.y + dy))
			var ok := true
			for i in range(-3, 6):
				var t := g + Vector2i(i, 0)
				var id := w.blocks.id_of(w.data.get_block(t.x, t.y))
				if not id in [&"grass", &"dirt", &"stone"] or w.data.get_block(t.x, t.y - 1) != WorldData.AIR \
						or w.data.get_wall(t.x, t.y - 1) != WorldData.AIR:
					ok = false
					break
			if ok:
				return g
	return Vector2i.ZERO


func test_loose_pickups_come_back_but_not_crowded_or_indoors() -> void:
	var plants := w.forage
	var g := _open_ground()
	for p in plants._items.keys():
		plants._remove(p)
	assert_true(plants.try_regrow(g, 1.0), "open floor, sure chance: something appears")
	assert_not_null(plants.at(g))
	plants._remove(g)
	# Crowded: crowd_cap items nearby block it.
	var near: Array[Vector2i] = []
	for i in plants.crowd_cap:
		var t := w.wrap_tile(g + Vector2i(i - 3, 0))
		if t != g:
			plants._add(t, _forage(&"rock"))
			near.append(t)
	plants._add(w.wrap_tile(g + Vector2i(5, 0)), _forage(&"rock"))
	near.append(w.wrap_tile(g + Vector2i(5, 0)))
	for i in 20:
		assert_false(plants.try_regrow(g, 1.0), "crowded")
	for t in near:
		plants._remove(t)
	# Indoors: a background wall behind the spot.
	var above := g + Vector2i.UP
	w.data.set_wall(above.x, above.y, w.walls.index_of(&"wood_wall"))
	assert_false(plants.try_regrow(g, 1.0), "not in houses")


func test_pickups_regrow_off_screen_over_days() -> void:
	var plants := w.forage
	await wait_physics_frames(5)
	assert_gt(plants.floor_tile_count(), 0)
	for p in plants._items.keys():
		plants._remove(p)
	var before := plants.regrown_total
	plants.regrow_for_days(30.0)
	assert_gt(plants.regrown_total, before, "30 days bring some back")
	var screen := plants._screen_tiles()
	assert_gt(screen.size.x, 0, "a screen rect exists")
	for c: Vector2i in plants._floor_spots:
		var spots: PackedInt32Array = plants._floor_spots[c]
		for i in range(0, spots.size(), 2):
			var t := c * ChunkData.SIZE + Vector2i(spots[i], spots[i + 1])
			if screen.has_point(t):
				assert_null(plants.at(t), "nothing appears on screen")


func test_craft_amount_field_shift_and_ctrl() -> void:
	var hud := w.hud
	w.character.inventory.add(&"wood", 200)
	hud.toggle_crafting()
	var i := -1
	for j in hud.recipes().size():
		if hud.recipes()[j].output == &"wood_platform":
			i = j
	assert_gt(i, -1, "platforms are craftable by hand")
	hud.selected_recipe = i
	hud.set_craft_amount(3)
	var before := w.character.inventory.count_of(&"wood_platform")
	assert_eq(hud.craft_selected(), 3, "crafts the amount in the field")
	assert_eq(hud.craft_selected(true), 10, "Shift: 10")
	var r: RecipeData = hud.recipes()[i]
	var left := hud._times(r)
	var stack := ItemData.find(r.output).max_stack / r.output_count
	assert_eq(hud.craft_selected(false, true), mini(left, stack), "Ctrl: as many as you can, up to a stack")
	assert_gt(w.character.inventory.count_of(&"wood_platform") + 0, before)
	hud.set_craft_amount(0)
	assert_eq(hud.craft_amount, 1, "never below 1")
	# Typing into the field.
	hud._amount_typing = true
	hud._amount_fresh = true
	for k in [KEY_4, KEY_2]:
		var e := InputEventKey.new()
		e.keycode = k
		e.pressed = true
		hud._amount_key(e)
	assert_eq(hud.craft_amount, 42)


func test_hover_outline_on_interactables_in_reach() -> void:
	var a := _floor_spot(3)
	assert_true(w.request_place_object(a, w.objects.index_of(&"chest")))
	w.item_user.cursor_override = Vector2(a * World.TILE) + Vector2(4, -2)
	await wait_seconds(0.2)
	assert_not_null(w.hover_outline.hovered(), "chest outlined")
	w.item_user.cursor_override = Vector2(_floor_spot(40) * World.TILE)
	await wait_seconds(0.2)
	assert_null(w.hover_outline.hovered(), "nothing usable there (or out of reach)")
	# A stick lying on the grass.
	var g := w.wrap_tile(_floor_spot(-3) + Vector2i.DOWN)
	w.forage._add(g, _forage(&"stick"))
	w.item_user.cursor_override = Vector2((g + Vector2i.UP) * World.TILE) + Vector2(4, 4)
	await wait_seconds(0.2)
	assert_not_null(w.hover_outline.hovered(), "stick outlined")
	w.item_user.cursor_override = Vector2.INF
