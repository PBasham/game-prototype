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


func test_pickaxe_mines_the_area_under_the_cursor() -> void:
	var u := w.item_user
	w.player.select_slot(0)
	assert_eq(w.player.held_item.id, &"copper_pickaxe")
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
	w.player.select_slot(2)
	var spell := w.player.held_item
	assert_eq(spell.id, &"mining_spell")
	var u := w.item_user
	assert_eq(u.area_size(spell), 2)
	w.player.area_scrolled.emit(1)
	assert_eq(u.area_size(spell), 3)
	w.player.area_scrolled.emit(1)
	assert_eq(u.area_size(spell), 3, "capped at mining_area_max")
	w.player.area_scrolled.emit(-1)
	w.player.area_scrolled.emit(-1)
	w.player.area_scrolled.emit(-1)
	assert_eq(u.area_size(spell), 1)


func test_blocks_need_something_to_touch() -> void:
	w.player.select_slot(3)
	assert_eq(w.player.held_item.id, &"wood_planks")
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
	assert_gt(w.drop_count(), drops + plants.wood_min, "wood and seeds dropped")


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
