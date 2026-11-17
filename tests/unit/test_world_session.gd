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


func test_attack_combo_and_bare_hands() -> void:
	var w := _start(WorldInfo.test_course())
	await wait_physics_frames(3)
	var p := w.player
	# Bare hands: clicking does nothing.
	Input.action_press("use_primary")
	await wait_physics_frames(2)
	Input.action_release("use_primary")
	assert_null(p._attack, "empty hands don't attack")
	# Sword: holding the button runs the combo Slash, Backslash, Thrust, Slash...
	p.hold(DevHeldItems.by_name("Sword"))
	var seen: Array[String] = []
	Input.action_press("use_primary")
	for i in 90:
		await wait_physics_frames(1)
		if p._attack and (seen.is_empty() or seen.back() != p._attack.name):
			seen.append(p._attack.name)
	Input.action_release("use_primary")
	assert_gte(seen.size(), 4, "combo kept going: %s" % [seen])
	assert_eq(seen.slice(0, 4), ["Slash", "Backslash", "Thrust", "Slash"] as Array[String])
	# Putting it away stops the attack.
	p.toggle_stowed()
	assert_null(p._attack)
	w.queue_free()
	await wait_physics_frames(2)
