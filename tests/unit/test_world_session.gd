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
	assert_true(w.request_set_shape(tile, 4 | (2 << 4)), "a slope, top half wall")
	var torch_tile := Vector2i(s.x + 3, s.y - 1)
	assert_true(w.request_set_object(torch_tile, w.objects.index_of(&"torch")))
	assert_false(w.request_set_block(Vector2i(0, w.data.height - 1), WorldData.AIR), "floor row is locked")
	w.record_kill(&"green_slime")
	w.record_kill(&"green_slime")
	w.queue_free()
	await wait_physics_frames(2)
	assert_true(FileAccess.file_exists(PATH), "leaving the world saved it")

	var again := WorldSave.read_info(PATH)
	assert_eq(again.name, "Session")
	assert_eq(again.seed, 31)
	var w2 := _start(again)
	await wait_physics_frames(3)
	assert_eq(w2.data.get_block(tile.x, tile.y), copper, "edit loaded back")
	assert_eq(w2.data.get_shape(tile.x, tile.y), 4 | (2 << 4), "shape loaded back")
	assert_eq(w2.data.get_object(torch_tile.x, torch_tile.y), w2.objects.index_of(&"torch"), "torch loaded back")
	assert_eq(w2.kill_count(&"green_slime"), 2, "kills saved with the world")
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
	w.character.inventory.set_slot(0, &"", 0)  # empty hands (slot 0 is selected)
	# Bare hands punch (jab first)...
	Input.action_press("use_primary")
	await wait_physics_frames(2)
	Input.action_release("use_primary")
	assert_not_null(p._attack, "empty hands punch")
	assert_eq(p._attack.name, "Jab")
	await wait_physics_frames(20)
	# ...unless the debug brush is on (its clicks dig).
	w.brush.active = true
	Input.action_press("use_primary")
	await wait_physics_frames(2)
	Input.action_release("use_primary")
	assert_null(p._attack, "no punching while the brush is on")
	w.brush.active = false
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


func test_running_down_steps_and_into_walls_keeps_a_steady_animation() -> void:
	var w := _start(WorldInfo.test_course())
	await wait_physics_frames(3)
	var p := w.player
	var g: int = (w.generator as CourseGenerator).ground
	# Top of the 1-tile steps (course x = spawn + 39), then run left down them.
	w.teleport_player(w.tile_to_world(Vector2i(CourseGenerator.SPAWN_X + 39, g - 5)) + Vector2(4, 0))
	await wait_physics_frames(10)
	var start_y := p.global_position.y
	Input.action_press("move_left")
	Input.action_press("run")
	var anims: Array[StringName] = []
	for i in 50:
		await wait_physics_frames(1)
		anims.append(p._doll.animation)
	Input.action_release("move_left")
	Input.action_release("run")
	assert_gt(p.global_position.y - start_y, World.TILE * 3.5, "went down the steps")
	assert_false(anims.has(&"Jump"), "no falling frames running down 1-tile steps: %s" % [anims])
	# Push into the 4-tall wall: the animation settles instead of flickering.
	w.teleport_player(w.tile_to_world(Vector2i(CourseGenerator.SPAWN_X + 45, g)))
	await wait_physics_frames(10)
	Input.action_press("move_right")
	var changes := 0
	var last: StringName = p._doll.animation
	for i in 60:
		await wait_physics_frames(1)
		if p._doll.animation != last:
			changes += 1
			last = p._doll.animation
	Input.action_release("move_right")
	assert_lte(changes, 2, "jog then stand, no flicker")
	w.queue_free()
	await wait_physics_frames(2)


func test_you_come_back_where_you_stood() -> void:
	const SPOT_PATH := "user://test_worlds/spot.gpworld"
	WorldSave.delete(SPOT_PATH)
	var info := WorldInfo.create("Spot", WorldData.Size.TINY, 31)
	info.path = SPOT_PATH
	var w := _start(info)
	await wait_physics_frames(3)
	var s := w.generator.spawn_tile()
	var spot := w.tile_to_world(Vector2i(s.x + 20, w.generator.surface_at(s.x + 20))) + Vector2(4, 0)
	w.teleport_player(spot)
	await wait_physics_frames(3)
	var stood := w.player.global_position
	w.queue_free()
	await wait_physics_frames(2)
	var w2 := _start(WorldSave.read_info(SPOT_PATH))
	await wait_physics_frames(3)
	assert_almost_eq(w2.player.global_position.x, stood.x, 1.0, "back where you stood")
	# Build over the spot: next time you're at the world spawn (or your bed) instead.
	var t := w2.world_to_tile(stood)
	for y in range(t.y - 8, t.y):
		for x in range(t.x - 2, t.x + 3):
			w2.request_set_block(Vector2i(x, y), w2.blocks.index_of(&"stone"))
	w2.player_spots[w2.character.name] = stood
	var blocked_save := w2.player_spots.duplicate()
	w2.teleport_player(w2.respawn_position())  # stand somewhere else, then put the old spot back
	await wait_physics_frames(2)
	w2.player_spots = blocked_save
	w2._place_at_saved_spot()
	assert_almost_eq(w2.player.global_position.x, w2.respawn_position().x, 1.0, "blocked: at spawn / bed")
	w2.queue_free()
	await wait_physics_frames(2)
	WorldSave.delete(SPOT_PATH)


func test_the_world_map_fills_in_around_you_and_is_saved() -> void:
	var info := WorldInfo.create("MapTest", WorldData.Size.TINY, 31)
	info.temporary = true
	var w := _start(info)
	await wait_physics_frames(3)
	var m := w.world_map
	assert_not_null(m)
	var t := w.world_to_tile(w.player.chest())
	m.reveal_around(t, 20.0)
	var c := Vector2i(posmod(t.x, w.data.width), t.y) / WorldMap.CELL
	assert_true(m.is_explored(c.x, c.y), "around you")
	assert_false(m.is_explored(posmod(c.x + m.size.x / 2, m.size.x), c.y), "far away: not yet")
	# Dig a hole: the map shows it the next time it looks.
	var below := t + Vector2i(0, 12)
	assert_ne(m.cell_color(below.x / WorldMap.CELL, below.y / WorldMap.CELL), WorldMap.CAVE)
	# Saved and loaded as the picture.
	var back := WorldMap.new()
	back.setup(w)
	back.from_dict(m.to_dict())
	assert_true(back.is_explored(c.x, c.y))
	assert_eq(back.image.get_pixel(c.x, c.y), m.image.get_pixel(c.x, c.y))
	back.free()
	# The map screen opens and closes.
	w.hud.toggle_map()
	assert_true(w.hud.map_view.visible)
	w.hud.toggle_map()
	assert_false(w.hud.map_view.visible)
	w.queue_free()
	await wait_physics_frames(2)


func test_emotes_chat_and_sitting_on_a_chair() -> void:
	var info := WorldInfo.test_course()
	var w := _start(info)
	await wait_physics_frames(5)
	var p := w.player
	var hud := w.hud
	# The chat: /sit sits on the floor, moving stands you up.
	hud.chat.send("/sit")
	assert_eq(p.emote, &"sit_floor")
	await wait_physics_frames(10)
	assert_eq(p.emote, &"sit_floor", "stays sitting")
	assert_eq(p.get_node("Doll").pose, &"sit_floor")
	Input.action_press("move_right")
	await wait_physics_frames(3)
	Input.action_release("move_right")
	assert_eq(p.emote, &"", "moving stands you up")
	# /wave ends by itself; an unknown emote says what there is.
	hud.chat.send("/wave")
	assert_eq(p.emote, &"wave")
	hud.chat.send("/dance")
	assert_string_contains(hud.chat._lines[-1][0], "/sit")
	hud.chat.send("/stand")
	assert_eq(p.emote, &"")
	# Saying something: in the log and over your head.
	hud.chat.send("hello there")
	assert_string_contains(hud.chat._lines[-1][0], "hello there")
	assert_gt(hud.chat._bubble_left, 0.0)
	# A chair: sit on it, facing away from the back; take it away and you stand.
	await wait_physics_frames(5)
	var feet := w.world_to_tile(p.global_position)
	var spot := Vector2i(feet.x + 6, feet.y)
	var chair := w.objects.index_of(&"chair")
	assert_true(w.request_place_object(spot, chair), "a chair on the floor")
	assert_true(w.try_interact_at(w.tile_to_world(spot), p))
	assert_eq(p.emote, &"sit")
	assert_eq(p.seat, spot)
	assert_eq(p.facing, 1)
	await wait_physics_frames(5)
	assert_eq(p.emote, &"sit")
	w.request_remove_object(spot)
	await wait_physics_frames(3)
	assert_eq(p.emote, &"", "no chair, no sitting")
	w.queue_free()
	await wait_physics_frames(2)


func test_doll_render_modes_switch_sheets_and_canvas() -> void:
	var info := WorldInfo.test_course()
	var w := _start(info)
	await wait_physics_frames(5)
	var p := w.player
	var d := p.doll()
	var aim := p.global_position + Vector2(40, -20)
	var hand_before := d.doll_to_world(Vector2(5, -10))
	assert_string_contains(p.set_doll_render(true, "2x_smooth", "basic"), "grid on")
	assert_eq(d.rig.art_scale, 2, "the smoothed 2x sheet")
	assert_eq(d.rig.upscale_steps, PackedStringArray(["s"]))
	assert_true(p._canvas.is_on(), "the doll is on its canvas")
	assert_ne(d.get_parent(), p, "drawn inside the canvas")
	await wait_physics_frames(2)
	assert_almost_eq(d.doll_to_world(Vector2(5, -10)).x, hand_before.x, 0.6, "same place in the world")
	assert_almost_eq(d.doll_to_world(Vector2(5, -10)).y, hand_before.y, 0.6)
	var back := d.world_to_doll(aim)
	assert_almost_eq(d.doll_to_world(back).x, aim.x, 0.01, "world <-> doll round trip")
	p.set_doll_render(false, "1x", "rotsprite")
	assert_eq(d.rig.art_scale, 4, "rotsprite draws a 4x sheet")
	assert_true(p.doll_grid, "rotsprite needs the grid")
	p.set_doll_render(false, "1x", "basic")
	assert_eq(d.rig.art_scale, 1)
	assert_false(p._canvas.is_on())
	assert_eq(d.get_parent(), p, "back on the player")
	w.queue_free()
	await wait_physics_frames(2)


func test_body_3d_switches_on_and_off() -> void:
	var info := WorldInfo.test_course()
	var w := _start(info)
	await wait_physics_frames(5)
	var p := w.player
	assert_string_contains(p.set_body("3d", 12.0), "3d")
	assert_true(p.body3d().is_on())
	assert_eq(p.doll().step_fps, 12.0)
	assert_lt(p.body3d().get_index(), p.doll().get_index(), "drawn under the held item")
	assert_string_contains(p.set_doll_render(true, "2x", "basic"), "3D body is on")
	await wait_physics_frames(5)
	p.set_body("doll", 0.0)
	assert_false(p.body3d().is_on())
	assert_false(p.doll().parts_hidden)
	w.queue_free()
	await wait_physics_frames(2)
