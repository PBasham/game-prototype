extends GutTest
## Phase 51: the Shaping Spell (block shapes, collision, saving) and placing reach.

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


func _spot() -> Vector2i:
	var feet := w.world_to_tile(w.player.global_position)
	return Vector2i(feet.x + 3, feet.y - 3)


func test_everyone_starts_with_it_on_alt_r() -> void:
	assert_true(w.character.knows(&"shaping_spell"))
	var spell := ItemData.find(ItemData.spell_key(&"shaping_spell")) as SpellData
	assert_true(spell.shapes_blocks)
	assert_eq(Hud.dedicated_key(spell), "Ctrl + Shift + R")
	w.player.toggle_tool_spell(&"shaping_spell")
	assert_eq(w.player.use_item().id, spell.id)


func test_placed_blocks_cycle_through_halves_and_slopes() -> void:
	var t := _spot()
	w.request_set_block(t, w.blocks.index_of(&"wood_planks"))
	var u := w.item_user
	assert_eq(Array(u.shape_cycle(t, false)), [0, 1, 2, 3, 4, 5, 6])
	for want in [1, 2, 3, 4, 5, 6, 0]:
		u.shape_step(t, false, 1)
		assert_eq(w.data.get_shape(t.x, t.y) & 7, want, "step to %d" % want)
	u.shape_step(t, false, -1)
	assert_eq(w.data.get_shape(t.x, t.y) & 7, 6, "Shift steps back")


func test_only_placeable_blocks_can_be_shaped() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var grass := Vector2i(feet.x + 5, feet.y)
	assert_eq(w.data.get_block(grass.x, grass.y), w.blocks.index_of(&"grass"))
	assert_eq(w.item_user.shape_cycle(grass, false).size(), 0, "grass has no item that places it")
	assert_eq(w.item_user.shape_cycle(_spot(), false).size(), 0, "air")


func test_logs_can_be_turned() -> void:
	var t := _spot()
	w.request_set_block(t, w.blocks.index_of(&"log"))
	assert_eq(Array(w.item_user.shape_cycle(t, false)), [0, 1, 2, 3, 4, 5, 6, 8], "a log can be turned")


func test_walls_take_halves_and_keep_the_block_shape() -> void:
	var t := _spot()
	w.request_set_block(t, w.blocks.index_of(&"wood_planks"))
	w.request_set_wall(t, w.walls.index_of(&"log_wall"))
	w.item_user.shape_step(t, false, 1)  # bottom half block
	assert_eq(Array(w.item_user.shape_cycle(t, true)), [0, 1, 2, 4], "a log wall can be turned too")
	w.item_user.shape_step(t, true, 1)  # bottom half wall
	assert_eq(w.data.get_shape(t.x, t.y), 1 | (1 << 4))
	w.request_set_block(t, w.blocks.index_of(&"stone"))
	assert_eq(w.data.get_shape(t.x, t.y) >> 4, 1, "the wall shape survives a block change")


func test_shaped_blocks_get_sloped_collision() -> void:
	var t := _spot()
	w.request_set_block(t, w.blocks.index_of(&"wood_planks"))
	w.item_user.shape_step(t, false, 1)
	await wait_physics_frames(2)
	var view: ChunkRenderer.ChunkView = w.renderer._views[Vector2i(t.x / ChunkData.SIZE, t.y / ChunkData.SIZE)]
	var local := Vector2i(t.x % ChunkData.SIZE, t.y % ChunkData.SIZE)
	assert_eq(view.collision.get_cell_alternative_tile(local), 1, "bottom half collision")
	# Walking into a bottom half: the top half is open.
	var space := w.get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(t * World.TILE) + Vector2(4, 2)
	assert_eq(space.intersect_point(q).size(), 0, "top half is open")
	q.position = Vector2(t * World.TILE) + Vector2(4, 6)
	assert_gt(space.intersect_point(q).size(), 0, "bottom half is solid")


func test_placing_reach_follows_the_mining_spell() -> void:
	w.player.select_slot(3)
	w.item_user.update_target(w.player.chest())
	var mining := ItemData.find(ItemData.spell_key(&"mining_spell")) as SpellData
	assert_almost_eq(w.item_user.reach(), (mining.reach_tiles + w.character.spell_reach_bonus()) * World.TILE, 0.01)


func test_clicking_with_the_spell_shapes_the_block() -> void:
	var t := _spot()
	w.request_set_block(t, w.blocks.index_of(&"wood_planks"))
	w.player.toggle_tool_spell(&"shaping_spell")
	w.item_user.cursor_override = Vector2(t * World.TILE) + Vector2(4, 4)
	Input.action_press("use_primary")
	await wait_seconds(0.15)
	Input.action_release("use_primary")
	await wait_seconds(0.6)
	assert_eq(w.data.get_shape(t.x, t.y) & 7, 1, "one click, one step")


func test_log_walls_turn() -> void:
	var t := _spot()
	w.request_set_wall(t, w.walls.index_of(&"log_wall"))
	for i in 3:
		w.item_user.shape_step(t, true, 1)
	assert_eq(w.data.get_shape(t.x, t.y), 4 << 4, "turned: shape bit 6")
	w.item_user.shape_step(t, true, 1)
	assert_eq(w.data.get_shape(t.x, t.y), 0, "back to plain")
	var plain := _spot() + Vector2i(2, 0)
	w.request_set_wall(plain, w.walls.index_of(&"dirt_wall"))
	assert_eq(Array(w.item_user.shape_cycle(plain, true)), [0, 1, 2], "other walls only take halves")
