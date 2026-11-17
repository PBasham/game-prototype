extends GutTest
## End to end: start a saved world, edit a tile, leave (saves), load it again, and the
## edit is still there. Also checks the bottom row can't be changed.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const PATH := "user://test_worlds/session.gpworld"


func after_all() -> void:
	WorldSave.delete(PATH)
	Game.world_info = null


func _start(info: WorldInfo) -> World:
	Game.world_info = info
	var w := WORLD_SCENE.instantiate() as World
	add_child(w)
	return w


func test_edits_survive_save_and_load() -> void:
	WorldSave.delete(PATH)
	var info := WorldInfo.create("Session", WorldData.Size.TINY, 31)
	info.path = PATH
	var w := _start(info)
	await wait_physics_frames(3)
	var s := w.generator.spawn_tile()
	var tile := Vector2i(s.x + 5, s.y + 2)
	var copper := w.blocks.index_of(&"copper_ore")
	assert_true(w.request_set_block(tile, copper))
	assert_false(w.request_set_block(Vector2i(0, w.data.height - 1), WorldData.AIR), "floor row is locked")
	w.queue_free()
	await wait_physics_frames(2)
	assert_true(FileAccess.file_exists(PATH), "leaving the world saved it")

	var again := WorldSave.read_info(PATH)
	assert_eq(again.name, "Session")
	assert_eq(again.seed, 31)
	var w2 := _start(again)
	await wait_physics_frames(3)
	assert_eq(w2.data.get_block(tile.x, tile.y), copper, "edit loaded back")
	w2.queue_free()
	await wait_physics_frames(2)


func test_temporary_worlds_are_not_saved() -> void:
	var info := WorldInfo.test_course()
	var w := _start(info)
	await wait_physics_frames(2)
	assert_false(w.is_saved())
	assert_eq(w.save(), OK)
	w.queue_free()
	await wait_physics_frames(2)
