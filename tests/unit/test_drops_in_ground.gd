extends GutTest
## Drops never start or stay buried in solid ground (Phase 58).

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


func test_a_drop_made_inside_the_ground_comes_out_on_top() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var spot := Vector2i(feet.x + 10, feet.y - 20)
	var stone := w.blocks.index_of(&"stone")
	for y in 3:
		w.request_set_block(spot + Vector2i(0, y), stone)  # a 3 tall pillar
	var inside := w.tile_to_world(spot + Vector2i(0, 2)) + Vector2(4, 6)
	var drop := w.request_spawn_drop(&"wood", 1, inside)
	assert_eq(drop.position.y, float(spot.y * World.TILE), "on top of the pillar")
	assert_ne(w.collision_at(drop.position + Vector2(0, -1)), TileDef.Collision.SOLID)


func test_open_air_is_left_alone() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var p := w.tile_to_world(Vector2i(feet.x + 10, feet.y - 20)) + Vector2(3, 5)
	assert_eq(w.out_of_ground(p), p)


func test_a_block_placed_on_a_drop_pushes_it_up() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var spot := Vector2i(feet.x + 6, feet.y - 1)
	var drop := w.request_spawn_drop(&"wood", 1, w.tile_to_world(spot) + Vector2(4, 0))
	w.player.global_position.x += 200.0  # out of magnet reach
	await wait_seconds(1.5)
	w.request_set_block(w.world_to_tile(drop.global_position + Vector2(0, -1)), w.blocks.index_of(&"stone"))
	await wait_seconds(drop.merge_every + 0.5)
	assert_ne(w.collision_at(drop.global_position + Vector2(0, -1)), TileDef.Collision.SOLID, "not buried")
