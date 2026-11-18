extends GutTest
## Phase 7 spells: faster Fly with the Shift boost, Levitate, Hyper Drill, Air Push,
## Blink, Light Orb and Mend.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	w.spawner.peaceful = true


func after_each() -> void:
	for a: String in ["run", "move_right", "move_down", "jump"]:
		Input.action_release(a)
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


func _spell(id: StringName) -> SpellData:
	return ItemData.find(ItemData.spell_key(id)) as SpellData


func test_new_spells_exist() -> void:
	for id: StringName in [&"levitate", &"hyper_drill", &"air_push", &"blink", &"light_orb", &"mend"]:
		var s := _spell(id)
		assert_not_null(s, String(id))
		if s:
			assert_not_null(s.icon, "%s has an icon" % id)
	assert_eq(_spell(&"hyper_drill").tier, 3, "needs a tier 3 book")
	assert_true(&"levitate" in w.character.known_spells, "the dev kit knows them")


func test_fly_is_faster_and_shift_boosts_for_more_mana() -> void:
	var p := w.player
	var fly := _spell(&"fly")
	assert_eq(fly.move_speed, 34.0)
	p.toggle_concentration(fly)
	# Straight up (open sky on the course).
	Input.action_press("jump")
	await wait_seconds(0.25)
	assert_almost_eq(-p.velocity.y, 34.0 * World.TILE, 2.0, "faster cruise")
	assert_false(p.is_boosting())
	Input.action_press("run")
	await wait_seconds(0.25)
	assert_true(p.is_boosting())
	assert_almost_eq(-p.velocity.y, 68.0 * World.TILE, 4.0, "Shift doubles it")
	p.mana = 100.0
	await wait_seconds(0.5)
	assert_lt(p.mana, 100.0 - 15.0, "boosting drains about 40 mana a second")


func test_levitate_hovers_about_five_tiles_up_and_cant_climb() -> void:
	var p := w.player
	var ground := p.ground_below()
	assert_ne(ground, INF)
	p.toggle_concentration(_spell(&"levitate"))
	assert_true(p.is_levitating())
	Input.action_press("jump")
	await wait_seconds(1.2)
	Input.action_release("jump")
	var height := (p.ground_below() - p.global_position.y) / World.TILE
	assert_almost_eq(height, 5.0, 0.6, "hovers at 5 tiles, jump doesn't raise it")
	Input.action_press("move_down")
	await wait_seconds(1.0)
	Input.action_release("move_down")
	assert_almost_eq((p.ground_below() - p.global_position.y) / World.TILE, 0.0, 0.6, "Down lowers you")
	p.toggle_concentration(_spell(&"levitate"))
	assert_false(p.is_levitating())


func test_hyper_drill_area_is_round() -> void:
	var u := w.item_user
	u._item = _spell(&"hyper_drill")
	u.mode = ItemUser.Mode.MINE
	u.rect = Rect2i(Vector2i.ZERO, Vector2i(11, 11))
	var n := u._tiles().size()
	assert_lt(n, 121, "corners cut off")
	assert_gt(n, 85, "about a 5 tile radius")
	assert_false(Vector2i(0, 0) in u._tiles(), "no corner")
	assert_true(Vector2i(5, 5) in u._tiles(), "the middle")


func test_air_push_shoves_what_is_in_front() -> void:
	var p := w.player
	var push := _spell(&"air_push")
	var slime := Registry.get_def(&"enemies", &"green_slime") as EnemyData
	var front := w.request_spawn_enemy(slime, p.global_position + Vector2(5 * World.TILE * p.facing, 0))
	var behind := w.request_spawn_enemy(slime, p.global_position + Vector2(-5 * World.TILE * p.facing, 0))
	await wait_physics_frames(2)
	var from := p.chest()
	var hit := w.item_user.gust(push, from, Vector2(p.facing, 0))
	assert_eq(hit, 1, "only the one in the cone")
	assert_gt(front.velocity.x * p.facing, 10.0 * World.TILE, "pushed away")
	assert_lt(front.health, front.data.max_health, "a little damage")
	assert_eq(behind.health, behind.data.max_health)


func test_blink_moves_toward_the_cursor_but_not_into_ground() -> void:
	var p := w.player
	var start := p.global_position
	assert_true(p.blink_toward(p.global_position + Vector2(8 * World.TILE * p.facing, -30.0), 12.0))
	assert_almost_eq(absf(p.global_position.x - start.x), 8.0 * World.TILE, World.TILE * 0.6)
	assert_true(p.body_fits(p.global_position))
	# Straight down into the ground: nowhere to go.
	var before := p.global_position
	assert_false(p.blink_toward(p.global_position + Vector2(0, 20 * World.TILE), 12.0))
	assert_eq(p.global_position, before)
	# Far away: capped at 12 tiles.
	var s2 := p.global_position
	p.blink_toward(p.global_position + Vector2(100 * World.TILE * p.facing, -30.0), 12.0)
	assert_lte(p.global_position.distance_to(s2), 12.0 * World.TILE + 1.0)


func test_light_orb_follows_and_lights() -> void:
	var orb := w.summon_light_orb(_spell(&"light_orb"))
	assert_eq(w.dynamic_lights().size(), 1)
	w.summon_light_orb(_spell(&"light_orb"))
	await wait_physics_frames(1)
	assert_eq(w.dynamic_lights().size(), 1, "casting again replaces it")
	assert_false(is_instance_valid(orb) and not orb.is_queued_for_deletion(), "the old one is gone")


func test_mend_heals_while_on() -> void:
	var p := w.player
	p.health = 50.0
	p.toggle_concentration(_spell(&"mend"))
	await wait_seconds(1.0)
	assert_gt(p.health, 51.5, "about 3 health a second")
	p.toggle_concentration(_spell(&"mend"))


func test_cooldowns() -> void:
	var u := w.item_user
	var blink := _spell(&"blink")
	assert_eq(u.cooldown_left(blink), 0.0)
	u._ready_at[blink.id] = ItemUser._now() + blink.cooldown
	assert_gt(u.cooldown_left(blink), 0.5)


func _set_opt(key: String, on: bool) -> void:
	Settings.set_value("spells", key, on)


func test_wisp_follows_the_cursor_then_stays() -> void:
	var p := w.player
	var u := w.item_user
	var wisp := _spell(&"wisp")
	assert_true(wisp.light_placed)
	u.cursor_override = p.chest() + Vector2(60, -20)
	Input.action_press("use_primary")
	var orb := w.summon_light_orb(wisp)
	await wait_seconds(0.5)
	assert_lt(orb.global_position.distance_to(u.cursor_override), 6.0, "steered to the cursor")
	Input.action_release("use_primary")
	await wait_physics_frames(2)
	var spot := orb.global_position
	u.cursor_override = p.chest() + Vector2(-80, 0)
	await wait_seconds(0.3)
	assert_almost_eq(orb.global_position, spot, Vector2(1, 1), "stays where you let go")
	for i in 3:
		w.summon_light_orb(wisp)
	await wait_physics_frames(1)
	assert_eq(w.dynamic_lights().size(), 3, "three Wisps at most")
	u.cursor_override = Vector2.INF


func test_scrolls_teach_spells() -> void:
	var c := w.character
	var p := w.player
	c.known_spells.erase(&"blink")
	c.inventory.set_slot(0, &"scroll_blink", 2)
	p.select_slot(0)
	assert_eq(w.item_user._mode_for(p.held_item, false), ItemUser.Mode.LEARN)
	assert_true(w.item_user.read_scroll())
	assert_true(c.knows(&"blink"))
	assert_eq(c.inventory.counts[0], 1, "one scroll used")
	assert_false(w.item_user.read_scroll(), "already known: nothing used")
	assert_eq(c.inventory.counts[0], 1)
	var drill := Registry.get_def(&"recipes", &"scroll_hyper_drill") as RecipeData
	assert_eq(drill.inputs[&"copper_bar"], 10, "tier 3 costs 10 bars")
	assert_eq(drill.station, &"spell_weaving")


func test_movement_key_and_double_jump() -> void:
	var p := w.player
	_set_opt("movement_key", true)
	_set_opt("double_jump", true)
	w.character.put_in_book(3, &"levitate")  # movement spells must be in the book too
	assert_eq(p.movement_spell_id(), &"fly")
	assert_true(p.toggle_movement_spell())
	assert_true(p.is_flying())
	p.toggle_concentration(_spell(&"levitate"))
	assert_eq(w.character.movement_spell, &"levitate", "remembers the last movement spell")
	assert_true(p.toggle_movement_spell(), "F turns it off")
	assert_false(p.is_levitating())
	# Double jump: jump, then jump again in the air.
	Input.action_press("jump")
	await wait_physics_frames(2)
	Input.action_release("jump")
	await wait_seconds(0.25)
	Input.action_press("jump")
	await wait_physics_frames(2)
	Input.action_release("jump")
	assert_true(p.is_levitating(), "double jump starts the movement spell")
	p.toggle_concentration(_spell(&"levitate"))


func test_book_number_keys_and_quick_cast() -> void:
	var p := w.player
	var c := w.character
	_set_opt("book_numbers", true)
	_set_opt("quick_cast", true)
	c.put_in_book(3, &"spark")
	p.select_slot(2)
	p.ready_spell(c.book_loadout()[0])
	p._number_key(3)
	assert_eq(p.held_item.id, &"spark", "book out: number keys pick book slots")
	p.select_slot(2)
	var held_before := p.held_item
	# Quick cast (as if R is held): casts and goes back to the hotbar item.
	assert_true(p.quick_cast(&"spark"))
	assert_eq(p.held_item.id, &"spark")
	await wait_seconds(0.6)
	assert_eq(p.selected, 2, "back to the hotbar slot")
	assert_eq(p.held_item, held_before)
	_set_opt("book_numbers", false)
	p.ready_spell(&"spark")
	p._number_key(4)
	assert_eq(p.selected, 4, "option off: number keys pick hotbar slots")
	_set_opt("book_numbers", true)


func test_offhand_spell() -> void:
	var p := w.player
	var c := w.character
	c.put_in_book(0, &"spark")
	c.put_in_book(1, &"mend")
	_set_opt("two_hands", true)
	p.ready_spell(&"spark")
	assert_eq(p.offhand_spell(), &"mend")
	assert_true(p._offhand_cast())
	assert_eq(p.concentration, _spell(&"mend"), "right click cast the off-hand spell")
	assert_eq(p.held_item.id, &"spark", "still holding the main spell")
	p.toggle_concentration(_spell(&"mend"))
	p.ready_spell(&"mining_spell")
	assert_false(p._offhand_cast(), "mining spells keep right click for the back layer")
	_set_opt("two_hands", false)
	p.ready_spell(&"spark")
	assert_false(p._offhand_cast(), "option off")


func test_gel_cushion_needs_slime_and_saves_one_fall() -> void:
	var p := w.player
	var c := w.character
	var gel := _spell(&"gel_cushion")
	c.put_in_book(3, &"gel_cushion")
	c.inventory.remove(&"slime", c.inventory.count_of(&"slime"))
	assert_eq(c.cast_problem(gel), "Needs 5 Slime")
	c.inventory.add(&"slime", 7)
	assert_eq(c.cast_problem(gel), "")
	assert_true(c.take_reagents(gel))
	assert_eq(c.inventory.count_of(&"slime"), 2, "5 used")
	assert_false(c.take_reagents(gel), "not enough left: nothing taken")
	assert_eq(c.inventory.count_of(&"slime"), 2)
	# The buff: a big fall does no damage once, then the buff is gone.
	p.add_buff(gel)
	assert_true(p.has_buff(&"gel_cushion"))
	var used := [false]
	p.buff_ended.connect(func(effect: StringName, was_used: bool) -> void:
		used[0] = effect == &"gel_cushion" and was_used)
	p.invincible = false
	p.health = p.max_health
	p.global_position.y -= 60 * World.TILE
	p.reset_physics_interpolation()
	await wait_seconds(2.5)
	assert_true(p.is_on_floor())
	assert_eq(p.health, p.max_health, "no fall damage")
	assert_false(p.has_buff(&"gel_cushion"), "used up")
	assert_true(used[0], "ended as used")
	# A second fall hurts.
	p.global_position.y -= 60 * World.TILE
	p.reset_physics_interpolation()
	await wait_seconds(2.5)
	assert_lt(p.health, p.max_health, "the next fall hurts")


func test_buffs_run_out() -> void:
	var p := w.player
	var gel := _spell(&"gel_cushion")
	p.add_buff(gel)
	p.buffs[&"gel_cushion"] = 0.2
	await wait_seconds(0.4)
	assert_false(p.has_buff(&"gel_cushion"), "timed out")
