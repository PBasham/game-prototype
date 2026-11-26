extends GutTest
## Mining, placing, drops and plants, in a running test-course world.

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


## A solid tile a few tiles below the player's feet.
func _ground_tile() -> Vector2i:
	var t := w.world_to_tile(w.player.global_position)
	return Vector2i(t.x + 3, t.y + 2)


func test_blocks_take_damage_break_and_drop() -> void:
	var t := _ground_tile()
	var id := w.data.get_block(t.x, t.y)
	assert_gt(id, 0, "ground is solid")
	var def := w.blocks.def(id)
	assert_false(w.request_damage_block(t, def.health * 0.5), "half damage: still there")
	assert_almost_eq(w.block_damage(t), 0.5, 0.01)
	var drops := w.drop_count()
	assert_true(w.request_damage_block(t, def.health * 0.5), "breaks at its health")
	assert_eq(w.data.get_block(t.x, t.y), WorldData.AIR)
	assert_eq(w.drop_count(), drops + 1, "dropped an item")


func test_damage_heals() -> void:
	var t := _ground_tile()
	w.block_heal_seconds = 0.1
	w.request_damage_block(t, 1.0)
	assert_gt(w.block_damage(t), 0.0)
	await wait_seconds(0.3)
	assert_eq(w.block_damage(t), 0.0, "healed")


func test_drops_fly_to_the_player_and_are_picked_up() -> void:
	var inv := w.character.inventory
	var before := inv.count_of(&"stone")
	w.request_spawn_drop(&"stone", 3, w.player.chest() + Vector2(12, 0))
	await wait_seconds(1.0)
	assert_eq(inv.count_of(&"stone"), before + 3)
	assert_eq(w.drop_count(), 0)


func test_mining_spell_mines_the_area_under_the_cursor() -> void:
	var u := w.item_user
	w.player.toggle_tool_spell(&"mining_spell")
	assert_eq(w.player.held_item.id, &"mining_spell")
	var t := _ground_tile()
	var cursor := Vector2(t * World.TILE) + Vector2(World.TILE, World.TILE)  # a tile corner
	u.update_target(cursor)
	assert_eq(u.mode, ItemUser.Mode.MINE)
	assert_eq(u.rect.size, Vector2i(2, 2), "2x2")
	assert_eq(u.rect.position, t, "the 2x2 nearest the cursor")
	# Out of reach: nothing valid.
	u.update_target(cursor + Vector2(40 * World.TILE, 0))
	assert_eq(u.valid.size(), 0)


func test_spell_area_toggle() -> void:
	w.player.toggle_tool_spell(&"mining_spell")
	var spell := w.player.held_item
	assert_eq(spell.id, &"mining_spell")
	var u := w.item_user
	assert_eq(u.area_size(spell), 2)
	w.player.area_scrolled.emit(1)
	assert_eq(u.area_size(spell), 3)
	w.player.area_scrolled.emit(1)
	assert_eq(u.area_size(spell), 4, "the dev kit's Power 2/2: up to 4x4")
	w.player.area_scrolled.emit(1)
	assert_eq(u.area_size(spell), 4, "capped at mining_area_max")
	for i in 4:
		w.player.area_scrolled.emit(-1)
	assert_eq(u.area_size(spell), 1)


func test_blocks_need_something_to_touch() -> void:
	w.player.select_slot(3)
	assert_eq(w.player.held_item.id, &"wood")
	var u := w.item_user
	var feet := w.world_to_tile(w.player.global_position)
	# Floating in the air above the player's head: nothing to touch.
	var high := Vector2(Vector2i(feet.x + 4, feet.y - 9) * World.TILE) + Vector2(4, 4)
	u.update_target(high)
	assert_eq(u.valid.size(), 0, "can't place in mid-air")
	# On the ground next to the player: fine.
	var low := Vector2(Vector2i(feet.x + 4, feet.y - 1) * World.TILE) + Vector2(4, 4)
	u.update_target(low)
	assert_eq(u.valid.size(), 1)
	# Inside the player: no.
	u.update_target(w.player.chest())
	assert_eq(u.valid.size(), 0, "not inside the player")


func test_placing_takes_from_the_stack() -> void:
	w.player.select_slot(3)
	var inv := w.character.inventory
	var before := inv.counts[3]
	var feet := w.world_to_tile(w.player.global_position)
	var t := Vector2i(feet.x + 4, feet.y - 1)
	w.item_user.cursor_override = (Vector2(t * World.TILE) + Vector2(4, 4))
	w.player.use_impact.emit(w.player.held_item)
	assert_eq(w.data.get_block(t.x, t.y), w.blocks.index_of(&"wood_planks"))
	assert_eq(inv.counts[3], before - 1)


func test_trees_fall_and_drop_wood_and_seeds() -> void:
	var plants := w.plants
	# Plant one next to the player and grow it now.
	var feet := w.world_to_tile(w.player.global_position)
	var g := Vector2i(-1, -1)
	for dx in range(6, 30):
		var spot := plants.sapling_spot(Vector2i(feet.x + dx, feet.y - 1))
		if spot != PlantLayer.NONE:
			g = spot
			break
	assert_ne(g, Vector2i(-1, -1), "found a spot")
	assert_true(plants.request_plant_tree(g))
	assert_eq(plants.plant_at(g).kind, PlantLayer.Kind.SAPLING)
	plants.plant_at(g).grow_left = 0.0
	await wait_seconds(0.2)  # _process frames (physics frames can outpace them in tests)
	assert_eq(plants.plant_at(g).kind, PlantLayer.Kind.TREE, "grew")
	var drops := w.drop_count()
	for i in 3:
		assert_true(plants.request_hit_tree(g, 25.0, w.player.global_position.x))
	assert_not_null(plants.plant_at(g), "still standing after 3 hits")
	plants.request_hit_tree(g, 25.0, w.player.global_position.x)
	assert_null(plants.plant_at(g), "felled")
	await wait_seconds(plants.fall_time + 0.3)
	assert_gt(w.drop_count(), drops + plants.logs_for(14.0), "logs and seeds dropped")


func test_removing_the_ground_breaks_a_plant() -> void:
	var plants := w.plants
	var feet := w.world_to_tile(w.player.global_position)
	var g := PlantLayer.NONE
	for dx in range(6, 30):
		g = plants.sapling_spot(Vector2i(feet.x + dx, feet.y - 1))
		if g != PlantLayer.NONE:
			break
	plants.request_plant_tree(g)
	w.request_set_block(g, WorldData.AIR)
	assert_null(plants.plant_at(g))


func test_grass_spreads_to_exposed_dirt() -> void:
	var plants := w.plants
	var feet := w.world_to_tile(w.player.global_position)
	var grass := w.blocks.index_of(&"grass")
	var dirt := w.blocks.index_of(&"dirt")
	var t := Vector2i(feet.x + 5, feet.y)
	assert_eq(w.data.get_block(t.x, t.y), grass, "course ground is grass")
	w.request_set_block(t, dirt)
	plants.grass_spread_checks_per_second = 4000000.0
	await wait_seconds(0.2)
	assert_eq(w.data.get_block(t.x, t.y), grass, "grass grew back over it")


func test_plants_save_with_the_world() -> void:
	var plants := w.plants
	var feet := w.world_to_tile(w.player.global_position)
	var g := PlantLayer.NONE
	for dx in range(6, 30):
		g = plants.sapling_spot(Vector2i(feet.x + dx, feet.y - 1))
		if g != PlantLayer.NONE:
			break
	plants.request_plant_tree(g)
	var d := plants.to_dict([])
	var fresh := PlantLayer.new()
	fresh.world = w
	fresh.from_dict(d)
	assert_eq(fresh._plants.get(g).kind, PlantLayer.Kind.SAPLING)
	fresh.free()


func test_right_click_places_blocks_as_back_walls() -> void:
	w.player.select_slot(3)
	var u := w.item_user
	var inv := w.character.inventory
	var before := inv.counts[3]
	var feet := w.world_to_tile(w.player.global_position)
	var t := Vector2i(feet.x + 4, feet.y - 1)
	var at := Vector2(t * World.TILE) + Vector2(4, 4)
	u.cursor_override = at
	u.update_target(at, true)
	assert_eq(u.mode, ItemUser.Mode.PLACE_WALL)
	assert_eq(u.valid.size(), 1, "touches the ground")
	w.player.use_back = true
	w.player.use_impact.emit(w.player.held_item)
	assert_eq(w.data.get_wall(t.x, t.y), w.walls.index_of(&"wood_wall"))
	assert_eq(w.data.get_block(t.x, t.y), WorldData.AIR, "front layer untouched")
	assert_eq(inv.counts[3], before - 1)


func test_back_walls_mine_behind_blocks_and_drop_their_block() -> void:
	var t := _ground_tile()
	w.request_set_wall(t, w.walls.index_of(&"stone_wall"))
	assert_gt(w.data.get_block(t.x, t.y), 0, "a block in front")
	var drops := w.drop_count()
	assert_true(w.request_damage_wall(t, 1000.0))
	assert_eq(w.data.get_wall(t.x, t.y), WorldData.AIR)
	assert_gt(w.data.get_block(t.x, t.y), 0, "the block in front stays")
	assert_eq(w.drop_count(), drops + 1)
	var drop := w._drops.get_child(w._drops.get_child_count() - 1) as ItemDrop
	assert_eq(drop.item_id, &"stone", "stone walls drop stone")


func test_mining_spell_right_click_targets_walls() -> void:
	w.player.toggle_tool_spell(&"mining_spell")
	var u := w.item_user
	var t := _ground_tile()
	w.request_set_wall(t, w.walls.index_of(&"dirt_wall"))
	var at := Vector2(t * World.TILE) + Vector2(4, 4)
	u.update_target(at, true)
	assert_eq(u.mode, ItemUser.Mode.MINE)
	assert_true(t in u.valid, "the wall is a target")


func test_spell_shortcuts_are_never_thrown_into_the_world() -> void:
	assert_null(w.request_spawn_drop(&"spell:mining_spell", 1, w.player.chest()))


func test_tome_and_wheel_spells_cast_with_book_and_conduit() -> void:
	var c := w.character
	var u := w.item_user
	# Dev tome in row 3 (debug builds): casts the wide beam without a book slot, but
	# still needs the focus conduit.
	var tome_slot := c.inventory.ids.find(&"dev_tome")
	assert_gt(tome_slot, -1)
	c.inventory.set_slot(4, &"dev_tome", 1)
	w.player.select_slot(4)
	assert_eq(w.player.use_item().id, &"dev_wide_beam")
	var t := Vector2i(w.world_to_tile(w.player.global_position).x + 3, w.world_to_tile(w.player.global_position).y + 1)
	var at := Vector2(t * World.TILE) + Vector2(4, 4)
	u.update_target(at)
	assert_string_contains(u.problem, "focus")
	c.equip(CharacterData.SLOT_CONDUIT, &"dev_focus")
	u.update_target(at)
	assert_eq(u.problem, "")
	assert_eq(u.rect.size, Vector2i(3, 3))
	assert_almost_eq(u.damage(), 30.0 * 1.25, 0.01, "tome power x conduit power")
	# The wheel readies a book spell; the book's look goes in the hand.
	w.player.ready_spell(&"mining_spell")
	assert_eq(w.player.selected, -1)
	assert_eq(w.player.held_item.id, &"mining_spell")
	assert_eq(w.player.held.type, &"spell")
	assert_eq(w.player.held.id, CharacterData.DEFAULT_BOOK)
	c.equip(CharacterData.SLOT_BOOK, &"dev_grimoire")
	assert_eq(w.player.held.id, &"dev_grimoire", "the hand shows the new book")
	u.update_target(at)
	assert_almost_eq(u.damage(), 45.0 * 1.6 * 1.5 * 1.25, 0.01, "empowered damage x book power x conduit power")
	w.player.select_slot(0)
	assert_eq(w.player.held_item.id, &"copper_dagger")


func test_drops_at_your_feet_are_picked_up() -> void:
	var inv := w.character.inventory
	var before := inv.count_of(&"dirt")
	# On the ground two tiles to the side: level with the feet, far below the chest.
	w.request_spawn_drop(&"dirt", 2, w.player.global_position + Vector2(2 * World.TILE, -1))
	await wait_seconds(1.0)
	assert_eq(inv.count_of(&"dirt"), before + 2)


func test_drops_dont_fly_off_when_the_player_leaves() -> void:
	var drop := w.request_spawn_drop(&"stone", 1, w.player.global_position + Vector2(40 * World.TILE, -8))
	await wait_physics_frames(2)
	drop._magnetized = true
	drop.velocity = Vector2(-300.0 * World.TILE, 0)  # absurdly fast, then out of range
	await wait_seconds(1.0)
	assert_lt(absf(drop.velocity.x), drop.max_loose_speed * World.TILE + 1.0)
	var moved := absf(drop.global_position.x - (w.player.global_position.x + 40 * World.TILE))
	assert_lt(moved, 6.0 * World.TILE, "slid at most a few tiles")


func test_building_uses_the_spellbook_reach_and_shared_area() -> void:
	var u := w.item_user
	w.player.select_slot(3)  # planks
	u.update_target(w.player.chest())
	assert_almost_eq(u.reach(), 12.0 * World.TILE, 0.01, "the book's build reach")
	var planks := w.player.held_item
	w.player.area_scrolled.emit(1)
	w.player.area_scrolled.emit(1)
	assert_eq(u.area_size(planks), 3, "up to the book's build_area_max")
	w.player.toggle_tool_spell(&"mining_spell")  # R
	assert_eq(u.area_size(w.player.use_item()), 3, "the spell shares the area")
	w.player.select_slot(0)  # the dagger
	assert_eq(u.area_size(w.player.held_item), 1, "other items keep their own")


func test_placing_the_last_block_of_a_stack_doesnt_crash() -> void:
	var inv := w.character.inventory
	inv.set_slot(3, &"wood", 1)
	w.player.select_slot(3)
	var feet := w.world_to_tile(w.player.global_position)
	var t := Vector2i(feet.x + 4, feet.y - 1)
	w.item_user.cursor_override = Vector2(t * World.TILE) + Vector2(4, 4)
	Input.action_press("use_primary")
	await wait_seconds(0.4)
	Input.action_release("use_primary")
	assert_true(inv.is_empty(3), "used up")
	assert_eq(w.data.get_block(t.x, t.y), w.blocks.index_of(&"wood_planks"))
	assert_null(w.player.held_item, "empty hands now")


func test_blocks_under_trees_cant_be_mined() -> void:
	var plants := w.plants
	var feet := w.world_to_tile(w.player.global_position)
	var g := PlantLayer.NONE
	for dx in range(6, 30):
		g = plants.sapling_spot(Vector2i(feet.x + dx, feet.y - 1))
		if g != PlantLayer.NONE:
			break
	plants.request_plant_tree(g)
	plants.grow_all()
	await wait_seconds(0.2)
	assert_eq(plants.plant_at(g).kind, PlantLayer.Kind.TREE)
	assert_false(w.request_damage_block(g, 10000.0), "the tree holds it")
	assert_gt(w.data.get_block(g.x, g.y), 0)
	assert_true(w.is_protected(g))


func test_quick_equip_swaps() -> void:
	var c := w.character
	var slot := c.inventory.ids.find(&"dev_grimoire")
	assert_gt(slot, -1)
	w.hud.quick_equip(slot)
	assert_eq(c.equipment[CharacterData.SLOT_BOOK], &"dev_grimoire")
	assert_true(c.inventory.is_empty(slot))
	c.inventory.set_slot(slot, &"basic_spellbook", 1)
	w.hud.quick_equip(slot)
	assert_eq(c.equipment[CharacterData.SLOT_BOOK], &"basic_spellbook")
	assert_eq(c.inventory.ids[slot], &"dev_grimoire", "swapped back into the slot")
	w.hud.quick_unequip(CharacterData.SLOT_BOOK)
	assert_eq(c.equipment[CharacterData.SLOT_BOOK], &"")


func test_dev_console() -> void:
	var con := w.console
	var inv := w.character.inventory
	var before := inv.count_of(&"stone")
	assert_true(con.run("give stone 25"))
	assert_eq(inv.count_of(&"stone"), before + 25)
	con.run("give Copper Ore 3")
	assert_gte(inv.count_of(&"copper_ore"), 3, "by display name")
	assert_eq(con.find_item("copper_d").id, &"copper_dagger", "unique prefix")
	assert_null(con.find_item("copper"), "ambiguous")
	con.run("forget mining spell")
	assert_false(w.character.knows(&"mining_spell"))
	con.run("learn mining_spell")
	assert_true(w.character.knows(&"mining_spell"))
	assert_false(con.run("nonsense"))


func test_down_jump_drops_one_platform_at_a_time() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var plat := w.blocks.index_of(&"wood_platform")
	# Two platform floors 8 and 9 tiles up, 5 wide, under the player.
	for x in range(feet.x - 2, feet.x + 3):
		w.request_set_block(Vector2i(x, feet.y - 9), plat)
		w.request_set_block(Vector2i(x, feet.y - 8), plat)
	w.teleport_player(w.tile_to_world(Vector2i(feet.x, feet.y - 9)) + Vector2(4, -1))
	await wait_seconds(0.3)
	assert_almost_eq(w.player.global_position.y, float((feet.y - 9) * World.TILE), 1.0, "standing on the top one")
	Input.action_press("move_down")
	Input.action_press("jump")
	await wait_physics_frames(2)
	Input.action_release("jump")
	Input.action_release("move_down")
	await wait_seconds(0.5)
	assert_almost_eq(w.player.global_position.y, float((feet.y - 8) * World.TILE), 1.0, "caught by the one below")


func test_torches_need_support_and_pop_off() -> void:
	var torch := w.objects.index_of(&"torch")
	var def := w.objects.def(torch) as ObjectDef
	var feet := w.world_to_tile(w.player.global_position)
	var t := Vector2i(feet.x + 4, feet.y - 1)  # on the ground
	assert_true(w.can_place_object(t, def), "standing on the ground")
	var high := Vector2i(feet.x + 4, feet.y - 6)
	assert_false(w.can_place_object(high, def), "nothing to hold it in mid-air")
	w.request_set_wall(high, w.walls.index_of(&"wood_wall"))
	assert_true(w.can_place_object(high, def), "on a back wall")
	assert_true(w.request_set_object(high, torch))
	var drops := w.drop_count()
	w.request_damage_wall(high, 1000.0)
	assert_eq(w.data.get_object(high.x, high.y), WorldData.AIR, "popped off with the wall")
	assert_eq(w.drop_count(), drops + 2, "the wall's planks and the torch")


func test_placing_a_torch_with_the_item() -> void:
	var inv := w.character.inventory
	var slot := inv.ids.find(&"torch")
	assert_gt(slot, -1, "torches in the kit")
	w.player.select_slot(slot)
	var feet := w.world_to_tile(w.player.global_position)
	var t := Vector2i(feet.x + 4, feet.y - 1)
	w.item_user.cursor_override = Vector2(t * World.TILE) + Vector2(4, 4)
	var before := inv.counts[slot]
	w.player.use_impact.emit(w.player.held_item)
	assert_eq(w.data.get_object(t.x, t.y), w.objects.index_of(&"torch"))
	assert_eq(inv.counts[slot], before - 1)
	# Mining it takes it back in one hit.
	assert_true(w.request_damage_block(t, 1.0))
	assert_eq(w.data.get_object(t.x, t.y), WorldData.AIR)


func test_rope_goes_through_platforms_and_is_climbable() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var t := Vector2i(feet.x + 4, feet.y - 1)
	w.request_set_block(t, w.blocks.index_of(&"wood_platform"))
	var rope := w.objects.def(w.objects.index_of(&"rope")) as ObjectDef
	assert_true(w.can_place_object(t, rope), "rope can share a tile with a platform")
	w.request_set_object(t, w.objects.index_of(&"rope"))
	assert_true(w.is_climbable_at(Vector2(t * World.TILE) + Vector2(4, 4)))
	assert_eq(w.data.get_block(t.x, t.y), w.blocks.index_of(&"wood_platform"), "platform still there")
	assert_false(w.can_place_object(feet + Vector2i(0, 2), rope), "not inside a solid block")


func test_fly_toggles_and_floats() -> void:
	var p := w.player
	p.ready_spell(&"fly")
	p.toggle_concentration(ItemData.find(&"spell:fly") as SpellData)
	assert_true(p.is_flying())
	var y := p.global_position.y
	Input.action_press("jump")
	await wait_seconds(0.4)
	Input.action_release("jump")
	assert_lt(p.global_position.y, y - 3 * World.TILE, "went up")
	await wait_seconds(0.3)  # coasts to a stop
	var hover := p.global_position.y
	await wait_seconds(0.4)
	assert_almost_eq(p.global_position.y, hover, 2.0, "no gravity while flying")
	p.toggle_concentration(ItemData.find(&"spell:fly") as SpellData)
	assert_false(p.is_flying())


func test_spark_hits_a_dummy() -> void:
	var d := DevDummy.new()
	d.position = w.player.global_position + Vector2(10 * World.TILE, 0)
	w.effects.add_child(d)
	var spark := ItemData.find(&"spell:spark") as SpellData
	var from := w.player.chest()
	var target := d.hit_rect().get_center()
	w.request_spawn_projectile(spark, from, (target - from).normalized(), 1.0, w.player)
	await wait_seconds(0.6)
	assert_almost_eq(d.health, d.max_health - spark.damage, 0.01, "hit once")


func test_chopping_spell_fells_trees() -> void:
	var plants := w.plants
	var feet := w.world_to_tile(w.player.global_position)
	var g := PlantLayer.NONE
	for dx in range(5, 12):
		g = plants.sapling_spot(Vector2i(feet.x + dx, feet.y - 1))
		if g != PlantLayer.NONE:
			break
	plants.request_plant_tree(g)
	plants.grow_all()
	await wait_seconds(0.2)
	w.player.ready_spell(&"chopping_spell")
	var base := plants.ground_position(g, w.player.global_position)
	w.item_user.cursor_override = base + Vector2(0, -2 * World.TILE)
	Input.action_press("use_primary")
	await wait_seconds(2.5)
	Input.action_release("use_primary")
	assert_null(plants.plant_at(g), "felled by the beam")


func test_holding_down_jump_keeps_dropping() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var plat := w.blocks.index_of(&"wood_platform")
	for x in range(feet.x - 2, feet.x + 3):
		for dy in [10, 8, 6]:
			w.request_set_block(Vector2i(x, feet.y - dy), plat)
	w.teleport_player(w.tile_to_world(Vector2i(feet.x, feet.y - 10)) + Vector2(4, -1))
	await wait_seconds(0.3)
	Input.action_press("move_down")
	Input.action_press("jump")
	await wait_seconds(1.2)
	Input.action_release("jump")
	Input.action_release("move_down")
	assert_gt(w.player.global_position.y, float((feet.y - 6) * World.TILE) + 1.0, "through all three")


func test_pickup_notes_add_up() -> void:
	for i in 5:
		EventBus.item_picked_up.emit(&"dirt", 1)
	EventBus.item_picked_up.emit(&"stone", 2)
	assert_eq(w.hud._note_labels.size(), 2, "one line per item")
	assert_eq(w.hud._note_labels[&"dirt"].text, "+5 Dirt")


func test_grass_under_a_block_turns_to_dirt() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var t := Vector2i(feet.x + 5, feet.y)
	assert_eq(w.data.get_block(t.x, t.y), w.blocks.index_of(&"grass"))
	w.request_set_block(t + Vector2i.UP, w.blocks.index_of(&"wood_planks"))
	assert_eq(w.data.get_block(t.x, t.y), w.blocks.index_of(&"dirt"))


func test_feet_follow_the_slope_over_a_step() -> void:
	var p := w.player
	var feet := w.world_to_tile(p.global_position)
	# A 1-tile step up to the right of the column we stand on.
	w.request_set_block(Vector2i(feet.x + 1, feet.y - 1), w.blocks.index_of(&"dirt"))
	await wait_physics_frames(2)
	p.global_position.y = feet.y * World.TILE  # exactly on the ground (no step offset noise)
	# One foot point: the middle of our column is flat; the edge is halfway up the step.
	p.foot_spread_px = 0.0
	p.global_position.x = feet.x * World.TILE + 4.0
	assert_almost_eq(p._slope_offset(), 0.0, 0.05)
	p.global_position.x = (feet.x + 1) * World.TILE
	assert_almost_eq(p._slope_offset(), -4.0, 0.05)
	# Two feet 4 px each side: drawn for the higher foot, so neither sinks in.
	p.foot_spread_px = 4.0
	p.global_position.x = feet.x * World.TILE + 4.0
	assert_almost_eq(p._slope_offset(), -4.0, 0.05, "front foot at the step's edge")


func test_dev_reach() -> void:
	w.player.toggle_tool_spell(&"mining_spell")
	var u := w.item_user
	var far := w.player.chest() + Vector2(60 * World.TILE, 20 * World.TILE)
	u.update_target(far)
	assert_eq(u.valid.size(), 0)
	w.console.run("reach")
	u.update_target(far)
	assert_gt(u.valid.size(), 0, "anything on screen")
	w.console.run("reach")


func test_walking_under_platforms_doesnt_lift_you_onto_them() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var plat := w.blocks.index_of(&"wood_platform")
	# A stack of platforms at head height, 1 to 4 tiles up, to the right.
	for x in range(feet.x + 2, feet.x + 12):
		for dy in [1, 2, 3, 4]:
			w.request_set_block(Vector2i(x, feet.y - dy), plat)
	var y0 := w.player.global_position.y
	Input.action_press("move_right")
	await wait_seconds(0.8)
	Input.action_release("move_right")
	assert_almost_eq(w.player.global_position.y, y0, 1.0, "still on the ground")


func test_jumping_onto_a_platform_with_tucked_legs() -> void:
	var p := w.player
	var feet := w.world_to_tile(p.global_position)
	var plat := w.blocks.index_of(&"wood_platform")
	for x in range(feet.x - 3, feet.x + 4):
		w.request_set_block(Vector2i(x, feet.y - 3), plat)
	# Falling with the box's bottom 6 px below the platform's top (the drawn feet are above it).
	p.global_position.y = (feet.y - 3) * World.TILE + 6.0
	p.velocity = Vector2(0, 20)
	await wait_physics_frames(3)
	assert_almost_eq(p.global_position.y, float((feet.y - 3) * World.TILE), 1.0, "landed on it")


func test_materials_dont_swing() -> void:
	var inv := w.character.inventory
	inv.set_slot(4, &"copper_bar", 10)
	w.player.select_slot(4)
	assert_false(w.item_user.can_use(false), "bars have no use")
	w.player.select_slot(0)
	assert_true(w.item_user.can_use(false), "the dagger swings")


func test_thrown_items_stop_quickly() -> void:
	var d := w.request_spawn_drop(&"stone", 5, w.player.chest() + Vector2(0, -2 * World.TILE),
		Vector2(8.0 * World.TILE, -6.0 * World.TILE), true)
	d.magnet_tiles = 0.0  # don't fly back to the player for this test
	await wait_seconds(1.5)
	var x := d.global_position.x
	await wait_seconds(0.5)
	assert_almost_eq(d.global_position.x, x, 0.5, "stopped")


func test_rope_climbs_through_platforms() -> void:
	var p := w.player
	var feet := w.world_to_tile(p.global_position)
	var rope := w.objects.index_of(&"rope")
	var plat := w.blocks.index_of(&"wood_platform")
	for dy in range(1, 15):
		w.request_set_object(Vector2i(feet.x, feet.y - dy), rope)
	w.request_set_block(Vector2i(feet.x, feet.y - 9), plat)
	w.request_set_block(Vector2i(feet.x - 1, feet.y - 9), plat)
	w.request_set_block(Vector2i(feet.x + 1, feet.y - 9), plat)
	p.global_position.x = feet.x * World.TILE + 4.0
	Input.action_press("move_up")
	await wait_seconds(1.5)
	Input.action_release("move_up")
	assert_lt(p.global_position.y, float((feet.y - 9) * World.TILE), "climbed up past the platform")


func test_tall_torches_need_room_above() -> void:
	var torch := w.objects.def(w.objects.index_of(&"torch")) as ObjectDef
	assert_eq(torch.height_tiles, 2)
	var feet := w.world_to_tile(w.player.global_position)
	var t := Vector2i(feet.x + 4, feet.y - 1)
	w.request_set_block(t + Vector2i.UP, w.blocks.index_of(&"stone"))
	assert_false(w.can_place_object(t, torch), "a block right above")
	w.request_set_block(t + Vector2i.UP, WorldData.AIR)
	assert_true(w.request_set_object(t, w.objects.index_of(&"torch")))
	w.request_set_block(t + Vector2i.UP, w.blocks.index_of(&"stone"))
	assert_eq(w.data.get_object(t.x, t.y), WorldData.AIR, "popped off")


func test_mining_power_gates_hard_blocks() -> void:
	var u := w.item_user
	var t := _ground_tile() + Vector2i(-1, -1)  # in Mining I's reach
	for dx in 2:
		for dy in 2:
			w.data.set_block(t.x + dx, t.y + dy, w.blocks.index_of(&"iron_ore"))
	var iron := w.blocks.def(w.blocks.index_of(&"iron_ore"))
	assert_gt(iron.min_mining_power, 0, "iron ore needs some mining power")
	assert_gt(iron.health, w.blocks.def(w.blocks.index_of(&"copper_ore")).health, "and takes longer than copper")
	var cursor := Vector2(t * World.TILE) + Vector2(World.TILE, World.TILE)
	# A new character's Mining I can't mine iron.
	var c := w.character
	c.empower.erase(&"mining_spell")
	c.apply_empower()
	w.player.toggle_tool_spell(&"mining_spell")
	u.update_target(cursor)
	assert_eq(u.valid.size(), 0)
	assert_string_contains(u.problem, "Too hard")
	# Empower's Power rank 1 (10 copper bars) can.
	var power := Registry.get_def(&"empower", &"mining_power") as EmpowerNode
	var spell := Registry.get_def(&"spells", &"mining_spell") as SpellData
	assert_string_contains(c.empower_problem(spell, power), "Copper Bar")
	c.inventory.add(&"copper_bar", 10)
	assert_true(c.buy_empower(spell, power))
	assert_eq(c.inventory.count_of(&"copper_bar"), 0, "paid")
	assert_string_contains(c.empower_problem(spell, power), "Iron Bar", "rank 2 takes iron")
	assert_eq(w.player.use_item().mining_power, spell.mining_power + 10)
	u.update_target(cursor)
	assert_gt(u.valid.size(), 0, "copper rank mines iron")
	assert_eq(u.problem, "")


func test_iron_generates_deeper_than_copper() -> void:
	var gen := w.generator as ForestGenerator
	if gen == null:
		var registry_blocks := w.blocks
		var settings := load("res://data/worldgen/forest.tres") as ForestGenSettings
		gen = ForestGenerator.new(registry_blocks, w.walls, 2048, 1024, 42, settings)
	var iron := w.blocks.index_of(&"iron_ore")
	var shallow := 0
	var deep := 0
	for x in range(0, 600):
		var top := gen.surface_at(x)
		for d in range(0, 40):
			if gen.block_at(x, top + d) == iron:
				shallow += 1
		for d in range(150, 250):
			if gen.block_at(x, top + d) == iron:
				deep += 1
	assert_eq(shallow, 0, "none in the first 40 tiles")
	assert_gt(deep, 20, "some deeper down")


func test_placeable_stack_on_the_mouse_places_with_the_inventory_open() -> void:
	var hud := w.hud
	var p := w.player
	hud.set_open(true)
	hud.cursor_id = &"dirt"
	hud.cursor_count = 2
	await wait_process_frames(3)
	if hud._over_pane() != null:
		pending("the headless mouse sits over a window")
		return
	assert_eq(p.mouse_stack, ItemData.find(&"dirt"), "the hand holds the mouse stack")
	assert_eq(p.held_item, ItemData.find(&"dirt"))
	assert_false(p.input_blocked, "clicks reach the world")
	var u := w.item_user
	var feet := w.world_to_tile(p.global_position)
	var t := Vector2i(feet.x + 4, feet.y - 1)
	var at := Vector2(t * World.TILE) + Vector2(4, 4)
	u.cursor_override = at
	u.update_target(at, false)
	assert_eq(u.mode, ItemUser.Mode.PLACE_BLOCK, "the preview shows")
	var slot_counts := w.character.inventory.counts.duplicate()
	p.use_back = false
	p.use_impact.emit(p.held_item)
	assert_eq(w.data.get_block(t.x, t.y), w.blocks.index_of(&"dirt"))
	assert_eq(hud.cursor_count, 1, "taken from the mouse stack")
	assert_eq(w.character.inventory.counts, slot_counts, "not from the hotbar")
	# Any item on the mouse is held and used (a sword swings); a spell shortcut isn't.
	hud.cursor_id = &"copper_sword"
	hud.cursor_count = 1
	await wait_process_frames(3)
	assert_eq(p.mouse_stack, ItemData.find(&"copper_sword"))
	assert_false(p.input_blocked)
	hud.cursor_id = &"spell:spark"
	await wait_process_frames(3)
	assert_null(p.mouse_stack)
	assert_true(p.input_blocked)
	# Right click on the world throws the stack.
	hud.cursor_id = &"stone"
	hud.cursor_count = 4
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	var drops := w.drop_count()
	hud._unhandled_input(e)
	assert_eq(hud.cursor_count, 0)
	assert_eq(w.drop_count(), drops + 1, "thrown")
	hud.cursor_count = 0
	hud.cursor_id = &""
	hud.set_open(false)
	await wait_process_frames(3)
	assert_null(p.mouse_stack)


func test_mouse_stack_places_with_an_empty_hotbar_slot_selected() -> void:
	var hud := w.hud
	var p := w.player
	var inv := w.character.inventory
	inv.set_slot(9, &"", 0)
	p.select_slot(9)
	hud.set_open(true)
	hud.cursor_id = &"wood_platform"
	hud.cursor_count = 3
	await wait_process_frames(3)
	if hud._over_pane() != null:
		pending("the headless mouse sits over a window")
		return
	var u := w.item_user
	var feet := w.world_to_tile(p.global_position)
	var t := Vector2i(feet.x + 4, feet.y - 1)
	var at := Vector2(t * World.TILE) + Vector2(4, 4)
	u.cursor_override = at
	u.update_target(at, false)
	assert_eq(u.valid.size(), 1, "not limited by the empty hotbar slot")
	p.use_impact.emit(p.held_item)
	assert_eq(w.data.get_block(t.x, t.y), w.blocks.index_of(&"wood_platform"))
	assert_eq(hud.cursor_count, 2)
	hud.cursor_count = 0
	hud.cursor_id = &""
	hud.set_open(false)
	u.cursor_override = Vector2.INF


func test_air_ledge_climb_onto_a_floor_edge() -> void:
	var p := w.player
	var feet := w.world_to_tile(p.global_position)
	# A ledge 6 tiles up to the right: a slab of stone, open above.
	var top_row := feet.y - 6
	for x in range(feet.x + 3, feet.x + 9):
		for y in range(top_row, top_row + 2):
			w.request_set_block(Vector2i(x, y), w.blocks.index_of(&"stone"))
		for y in range(top_row - 12, top_row):
			w.request_set_block(Vector2i(x, y), WorldData.AIR)
	await wait_physics_frames(2)
	# In the air, feet 6 px below the ledge top, right up against it.
	var top_y := float(top_row * World.TILE)
	p.global_position = Vector2(p.global_position.x, top_y + 6.0)
	while not p.test_move(p.global_transform, Vector2(2, 0)):
		p.global_position.x += 1.0
	p.velocity = Vector2.ZERO
	p._air_ledge_climb(1.0, 1.0 / 60.0)
	assert_lte(p.global_position.y, top_y + 0.01, "lifted onto the ledge")
	assert_false(p.test_move(p.global_transform, Vector2(2, 0)), "free to step on")


func test_resting_drops_merge_and_are_capped() -> void:
	var p := w.player
	var at := p.global_position + Vector2(12 * World.TILE, -8)
	var a := w.request_spawn_drop(&"stone", 3, at)
	var b := w.request_spawn_drop(&"stone", 4, at + Vector2(4, 0))
	var c := w.request_spawn_drop(&"wood", 2, at + Vector2(2, 0))
	await wait_seconds(2.0)
	var stones := 0
	var stacks := 0
	for d in w._drops.get_children():
		var drop := d as ItemDrop
		if drop and drop.item_id == &"stone" and not drop.is_queued_for_deletion():
			stones += drop.count
			stacks += 1
	assert_eq(stones, 7)
	assert_eq(stacks, 1, "merged into one")
	assert_true(is_instance_valid(c) and not c.is_queued_for_deletion(), "other items stay apart")
	var keep := w.max_drops
	w.max_drops = w.drop_count() + 2
	for i in 5:
		w.request_spawn_drop(&"dirt", 1, at + Vector2(0, -40 - i * 10))
	assert_lte(w._drops.get_child_count(), w.max_drops, "capped")
	w.max_drops = keep
	for d in w._drops.get_children():
		d.queue_free()
	if is_instance_valid(a):
		pass
	if is_instance_valid(b):
		pass
