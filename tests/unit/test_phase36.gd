extends GutTest
## Phase 36: biome needs real ground, glass and clay walls, see-through glass, right
## click takes one, brighter walls.

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


func test_a_little_dark_stone_in_the_air_doesnt_turn_the_biome() -> void:
	var feet := w.world_to_tile(w.player.global_position) + Vector2i(0, -40)
	var dark := w.blocks.index_of(&"dark_forest_stone")
	for y in range(feet.y - 10, feet.y + 4):
		for x in range(feet.x - 6, feet.x - 3):
			w.data.set_block(x, y, dark)
	w._biome_cache.clear()
	assert_eq(w.biome_at(feet), &"forest", "a small pillar isn't a biome")


func test_clay_and_glass_place_walls() -> void:
	assert_eq(ItemData.find(&"clay").places_wall, &"clay_wall")
	var glass := ItemData.find(&"glass")
	assert_eq(glass.places_block, &"glass")
	assert_eq(glass.places_wall, &"glass_wall")
	assert_eq(glass.kind, ItemData.Kind.BLOCK)
	assert_true(w.blocks.def(w.blocks.index_of(&"glass")).see_through)
	assert_true(w.walls.def(w.walls.index_of(&"glass_wall")).see_through)
	assert_gt(w.walls.index_of(&"clay_wall"), 0)


func test_glass_is_solid_to_walk_on() -> void:
	var glass := w.blocks.index_of(&"glass")
	assert_eq(w.blocks.collision_table()[glass], TileDef.Collision.SOLID, "you can't walk through it")


func test_right_click_takes_one_and_shift_takes_half() -> void:
	var inv := w.character.inventory
	inv.set_slot(14, &"dirt", 10)
	inv.set_slot(15, &"", 0)
	w.hud.cursor_id = &""
	w.hud.cursor_count = 0
	w.hud.right_click_slot(14, inv)
	assert_eq(w.hud.cursor_count, 1)
	w.hud.right_click_slot(14, inv)
	assert_eq(w.hud.cursor_count, 2, "again: one more onto the mouse")
	assert_eq(inv.counts[14], 8)
	w.hud.right_click_slot(15, inv)
	assert_eq(inv.counts[15], 1, "into an empty slot: one put down")
	assert_eq(w.hud.cursor_count, 1)
	w.hud._clear_cursor()
	w.hud.right_click_slot(14, inv, true)
	assert_eq(w.hud.cursor_count, 4, "shift: half")
	w.hud._clear_cursor()
