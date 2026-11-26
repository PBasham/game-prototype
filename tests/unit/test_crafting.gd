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
	var bench := Registry.get_def(&"recipes", &"workbench") as RecipeData
	assert_true(bench.requires.is_empty(), "no Hand Hammer any more: wood is enough")
	# Older saves: Rock items load as Stone.
	var old := Inventory.new()
	old.from_dict({"slots": [["rock", 4], ["flint", 2], ["stick", 3], ["wood_planks", 5]]})
	assert_eq(old.count_of(&"stone"), 6, "rocks and flint load as Stone")
	assert_eq(old.count_of(&"wood"), 8, "sticks and planks load as Wood")
	# A recipe that needs a tool on you (not used up).
	var r := RecipeData.new()
	r.id = &"test_needs_dagger"
	r.inputs = {&"wood": 2}
	r.output = &"wood_platform"
	r.requires.append(&"copper_dagger")
	inv.add(&"wood", 10)
	assert_eq(Crafting.times_craftable(inv, r), 0, "needs the dagger on you")
	assert_true("Copper Dagger (not used up)" in Crafting.missing(inv, r))
	inv.add(&"copper_dagger", 1)
	assert_eq(Crafting.craft(inv, r, 1)[0], 1)
	assert_eq(inv.count_of(&"copper_dagger"), 1, "the dagger isn't used up")
	inv.add(&"wood", 10)
	assert_eq(Crafting.craft(inv, bench, 1)[0], 1)
	assert_eq(inv.count_of(&"workbench"), 1)
	assert_true(Crafting.recipes_for(&"").has(bench))
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
	assert_eq(names, [&"clay_flask", &"copper_bar", &"dark_forest_stone_bricks", &"iron_bar", &"stone_bricks"] as Array[StringName], "the furnace's list")
	w.character.inventory.add(&"copper_ore", 7)
	var before := w.character.inventory.count_of(&"copper_bar")
	assert_eq(w.hud.craft(w.hud.recipes()[1], 10), 2, "7 ore makes 2 bars")
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
	assert_eq(f.defs.size(), 6)
	assert_eq(f._pick(ChunkBuildJob.FLOOR_CAVE, 0.0).id, &"duskcap", "sorted by id")
	for i in 200:
		assert_ne(f._pick(ChunkBuildJob.FLOOR_CAVE, randf()).id, &"stick", "no sticks in caves")
		var surface := f._pick(ChunkBuildJob.FLOOR_GRASS, randf()).id
		assert_false(surface in [&"duskcap", &"glowcap"], "purple and glowing ones only underground")
	assert_gt((Registry.get_def(&"forage", &"glowcap") as ForageData).light_radius, 0.0, "the glowcap glows")
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
	assert_eq(hud.craft_amount, 1, "the amount resets after crafting")
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


func test_build_against_a_door() -> void:
	var a := _floor_spot(5)
	assert_true(w.request_place_object(a, w.objects.index_of(&"door")))
	var u := w.item_user
	var top := a + Vector2i(0, -8)  # just above the door (a lintel)
	var side := a + Vector2i(1, -4)  # beside it, mid height, nothing else around
	for t in [top, side]:
		assert_eq(w.data.get_block(t.x, t.y), WorldData.AIR)
		assert_eq(w.data.get_wall(t.x, t.y), WorldData.AIR)
	assert_true(u._anchored(top, false), "a block on top of the door")
	assert_true(u._anchored(side, false), "a block next to the door")
	assert_true(u._anchored(side, true), "a wall next to the door")
	assert_true(u._anchored(a + Vector2i(0, -4), true), "a wall behind the door")
	assert_false(u._anchored(a + Vector2i(3, -6), false), "not out in the open")
	# Opened, it still counts.
	assert_true(w.request_toggle_object(a))
	assert_true(u._anchored(top, false))


func test_crafting_uses_nearby_chests_after_the_inventory() -> void:
	var hud := w.hud
	var inv := w.character.inventory
	inv.remove(&"wood", 99999)
	var a := _floor_spot(4)
	assert_true(w.request_place_object(a, w.objects.index_of(&"chest")))
	var chest := w.container_at(a)
	chest.add(&"wood", 10)
	inv.add(&"wood", 3)
	var r := RecipeData.new()
	r.inputs = {&"wood": 4}
	r.output = &"torch"
	r.output_count = 1
	assert_eq(hud._times(r), 3, "13 wood across the inventory and the chest")
	assert_eq(hud.craft(r, 1), 1)
	assert_eq(inv.count_of(&"wood"), 0, "the inventory is used first")
	assert_eq(chest.count_of(&"wood"), 9, "then the chest")
	# Far chests don't count.
	w.player.global_position.x += 40 * World.TILE
	w.player.reset_physics_interpolation()
	await wait_physics_frames(2)
	assert_eq(hud._times(r), 0, "the chest is too far")


func test_freecraft_needs_no_materials() -> void:
	var hud := w.hud
	var inv := w.character.inventory
	inv.remove(&"wood", 99999)
	var r := RecipeData.new()
	r.inputs = {&"wood": 4}
	r.output = &"torch"
	r.output_count = 1
	assert_eq(hud._times(r), 0)
	w.free_crafting = true
	assert_gt(hud._times(r), 100)
	var torches := inv.count_of(&"torch")
	assert_eq(hud.craft(r, 2), 2)
	assert_eq(inv.count_of(&"torch"), torches + 2)
	w.free_crafting = false


func test_furniture_faces_the_way_you_placed_it() -> void:
	var bed := w.objects.index_of(&"bed")
	var a := _floor_spot(4)
	assert_true(w.request_place_object(a, bed, true))
	assert_true(w.is_flipped(a), "placed facing left: mirrored")
	assert_true(w._flipped_to_dict().has("%d,%d" % [w.wrap_tile(a).x, w.wrap_tile(a).y]), "saved")
	assert_true(w.request_remove_object(a))
	assert_false(w.is_flipped(a), "cleared when picked up")
	assert_false(World.can_flip(w.objects.def(w.objects.index_of(&"door")) as ObjectDef), "doors don't flip")
	assert_true(w.request_place_object(a, bed, false))
	assert_false(w.is_flipped(a))


func test_creative_window_gives_stacks() -> void:
	var hud := w.hud
	hud.toggle_creative()
	assert_true(hud.creative_open)
	var win := hud._creative
	assert_gt(win.all_items().size(), 50)
	assert_false(win.all_items().any(func(it: ItemData) -> bool: return it.is_spell()), "no spells")
	win.search = "wood platform"
	assert_eq(win.shown().map(func(it: ItemData) -> StringName: return it.id), [&"wood_platform"] as Array)
	hud.give_cursor(&"wood_platform", 99999)
	assert_eq(hud.cursor_count, Inventory.max_stack(&"wood_platform"), "a full stack")
	hud.give_cursor(&"wood_platform", 1)
	assert_eq(hud.cursor_count, Inventory.max_stack(&"wood_platform"), "never past a stack")
	hud.cursor_count = 0
	hud.cursor_id = &""
	# Clicks: 1, Shift 10, Ctrl a stack; right click an infinite stack.
	var cell := win.cell(0).get_center()
	var click := func(button: MouseButton, shift: bool, ctrl: bool) -> void:
		var mb := InputEventMouseButton.new()
		mb.button_index = button
		mb.pressed = true
		mb.position = cell
		mb.shift_pressed = shift
		mb.ctrl_pressed = ctrl
		win.body_click(mb)
	click.call(MOUSE_BUTTON_LEFT, false, false)
	assert_eq(hud.cursor_count, 1)
	click.call(MOUSE_BUTTON_LEFT, true, false)
	assert_eq(hud.cursor_count, 11)
	click.call(MOUSE_BUTTON_LEFT, false, true)
	assert_eq(hud.cursor_count, Inventory.max_stack(&"wood_platform"))
	hud.cursor_count = 0
	click.call(MOUSE_BUTTON_RIGHT, false, false)
	assert_true(hud.cursor_meta.get("infinite", false), "infinite stack")
	var p := w.player
	var before := hud.cursor_count
	p.mouse_stack = ItemData.find(&"wood_platform")
	p.mouse_take = hud._take_cursor_one
	p.mouse_left = func() -> int: return hud.cursor_count
	p.mouse_meta = func() -> Dictionary: return hud.cursor_meta
	assert_true(p.take_held())
	assert_eq(hud.cursor_count, before, "never used up")
	p.mouse_stack = null
	hud.cursor_count = 0
	hud.cursor_id = &""
	hud.cursor_meta = {}
	hud.toggle_creative()
	hud.set_open(false)


func test_chest_names_and_quick_stack() -> void:
	var hud := w.hud
	var inv := w.character.inventory
	var a := _floor_spot(4)
	assert_true(w.request_place_object(a, w.objects.index_of(&"chest")))
	assert_eq(w.container_name(a), "Chest")
	w.request_rename_chest(a, "Ores")
	assert_eq(w.container_name(a), "Ores")
	assert_true(w._names_to_dict().values().has("Ores"), "saved")
	var store := w.container_at(a)
	store.add(&"stone", 1)
	inv.remove(&"stone", 99999)
	inv.remove(&"wood", 99999)
	inv.set_slot(20, &"stone", 30)
	inv.set_slot(21, &"wood", 10)
	inv.set_slot(3, &"stone", 5)
	hud.chest = a
	hud.quick_stack(store)
	assert_eq(store.count_of(&"stone"), 31, "stone it already had")
	assert_eq(inv.count_of(&"wood"), 10, "not wood")
	assert_eq(inv.counts[3], 5, "hotbar stays")
	hud.chest = World.NO_TILE
	assert_true(w.request_remove_object(a) or true)


func test_special_storage_takes_only_its_kind_and_fills_up() -> void:
	var rack_id := w.objects.index_of(&"lumber_rack")
	var a := _floor_spot(4)
	assert_true(w.request_place_object(a, rack_id))
	var rack := w.container_at(a)
	assert_eq(rack.size, 10)
	assert_eq(rack.add(&"stone", 10), 10, "stone doesn't go in")
	# Any logs and wood, in full stacks.
	var full := Inventory.max_stack(&"wood")
	assert_eq(full, 9999)
	assert_eq(rack.add(&"wood", full * 5), 0, "full stacks")
	assert_eq(rack.add(&"dark_log", full * 3), 0)
	assert_eq(rack.add(&"reinforced_darkwood", full * 2), 0)
	assert_eq(rack.add(&"log", 10), 10, "10 stacks in all")
	assert_almost_eq(rack.fill(), 1.0, 0.001)
	rack.remove(&"wood", full * 5)
	assert_almost_eq(rack.fill(), 0.5, 0.001, "half full by stacks")
	assert_eq(w.object_layer.frame_for(w.objects.def(rack_id) as ObjectDef, a, rack_id), 5, "half full: frame 5")
	# Darkwood logs build blocks like logs do.
	var dl := ItemData.find(&"dark_log")
	assert_eq(dl.display_name, "Darkwood Log")
	assert_eq(dl.places_block, &"darkwood_log")
	assert_gt(w.blocks.index_of(&"darkwood_log"), 0)
	assert_gt(w.walls.index_of(&"darkwood_log_wall"), 0)
	assert_eq(w.blocks.def(w.blocks.index_of(&"darkwood_log")).drop_item, &"dark_log")
	# The mouse can't drop stone in, either.
	var hud := w.hud
	hud.cursor_id = &"stone"
	hud.cursor_count = 5
	hud.click_slot(1, rack)
	assert_eq(hud.cursor_count, 5)
	hud.cursor_count = 0
	hud.cursor_id = &""
	# Potion Cabinet: potions only; their color shows.
	var cab := ItemData.find(&"healing_potion")
	assert_true(&"potion" in cab.storage_tags)
	assert_eq(ObjectLayer.shelf_color(cab), cab.shelf_color)


func test_trash_slot_keeps_the_last_thing_thrown_away() -> void:
	var hud := w.hud
	var c := w.character
	var inv := c.inventory
	hud.set_open(true)
	inv.set_slot(30, &"stone", 12)
	hud.trash_slot(30)
	assert_eq(inv.counts[30], 0)
	assert_eq(c.trash.ids[0], &"stone")
	assert_eq(c.trash.counts[0], 12)
	# Something else trashed from the mouse replaces it.
	hud.give_cursor(&"dirt", 5)
	hud.click_trash()
	assert_eq(hud.cursor_count, 0)
	assert_eq(c.trash.ids[0], &"dirt")
	# Click with an empty mouse: take it back.
	hud.click_trash()
	assert_eq(hud.cursor_id, &"dirt")
	assert_eq(hud.cursor_count, 5)
	assert_eq(c.trash.counts[0], 0)
	hud.click_trash()
	# Saved with the character.
	var d := c.to_dict()
	assert_eq(d["trash"], c.trash.to_dict())
	assert_true(hud.trash_rect().size.x > 0.0)
	hud.set_open(false)


func test_darkwood_workbench_upgrade_makes_reinforced_wood() -> void:
	var bench := Registry.get_def(&"objects", &"workbench") as ObjectDef
	assert_eq(bench.upgrade_to, &"darkwood_workbench")
	assert_eq(bench.upgrade_cost, {&"darkwood": 20, &"iron_bar": 3})
	var dark := Registry.get_def(&"objects", &"darkwood_workbench") as ObjectDef
	assert_eq(dark.station, &"workbench")
	assert_eq(dark.station_tier, 2)
	var ids := func(tier: int) -> Array: return Crafting.recipes_for(&"workbench", tier).map(
		func(r: RecipeData) -> StringName: return r.id)
	assert_false(ids.call(1).has(&"reinforced_wood"), "not at a plain Workbench")
	assert_true(ids.call(2).has(&"reinforced_wood"))
	assert_true(ids.call(2).has(&"reinforced_darkwood"))
	assert_true(ids.call(2).has(&"chest"), "still makes everything a Workbench does")
	for id: StringName in [&"reinforced_wood", &"reinforced_darkwood"]:
		var it := ItemData.find(id)
		assert_eq(it.places_block, id)
		assert_eq(it.places_wall, StringName(String(id) + "_wall"))
		assert_gt(w.blocks.index_of(id), 0)
		assert_gt(w.walls.index_of(StringName(String(id) + "_wall")), 0)
		assert_gt(w.blocks.def(w.blocks.index_of(id)).health, w.blocks.def(w.blocks.index_of(&"wood_planks")).health)


func test_creative_window_dev_test_and_enemy_tabs() -> void:
	var hud := w.hud
	hud.toggle_creative()
	var win := hud._creative
	assert_eq(win.title, "Creative", "a creative mode window, not dev items")
	win.tab = CreativeWindow.DEV_TAB
	var dev := win.shown().map(func(it: ItemData) -> StringName: return it.id)
	assert_has(dev, &"dev_grimoire")
	assert_does_not_have(dev, &"spellbook_t1")
	win.tab = CreativeWindow.TEST_TAB
	var test := win.shown().map(func(it: ItemData) -> StringName: return it.id)
	assert_has(test, &"spellbook_t1", "test books")
	assert_has(test, &"dev_mining_v2", "test spells")
	assert_false(test.has(&"dev_grimoire"))
	# A test spell goes on the mouse, for a quick slot.
	var i := win.shown().find(ItemData.find(ItemData.spell_key(&"dev_mining_v2")))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = win.cell(i).get_center()
	win.body_click(click)
	assert_eq(hud.cursor_id, ItemData.spell_key(&"dev_mining_v2"))
	hud._clear_cursor()
	# Enemies: click spawns one in front of you.
	win.tab = CreativeWindow.ENEMY_TAB
	var enemies := win.shown()
	assert_eq(enemies.size(), Registry.get_all(&"enemies").size())
	w.spawner.peaceful = true
	var before := w.enemies().size()
	click.position = win.cell(0).get_center()
	win.body_click(click)
	assert_eq(w.enemies().size(), before + 1, "spawned")
	click.shift_pressed = true
	win.body_click(click)
	assert_eq(w.enemies().size(), before + 6, "Shift: 5")
	for t in CreativeWindow.TABS.size():
		assert_ne(win.tab_rect(t), Rect2(), "tab %d laid out" % t)
		assert_lte(win.tab_rect(t).end.x, win.search_rect().end.x + 0.5, "tabs wrap inside the window")


func test_quit_game_asks_first() -> void:
	var menu := w._pause_menu
	menu.toggle()
	menu._show_quit()
	await wait_process_frames(2)
	var labels := menu._root.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	assert_has(labels, "Cancel", "a way back")
	assert_true(labels.has("Quit") or labels.has("Quit without saving"), "quit without saving")
	menu.toggle()
