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
	# A wall between: the gust stops there.
	var wall_x := w.world_to_tile(from).x + 3 * p.facing
	var feet := w.world_to_tile(p.global_position)
	for y in range(feet.y - 10, feet.y):
		w.request_set_block(Vector2i(wall_x, y), w.blocks.index_of(&"stone"))
	var hp := front.health
	front.global_position = p.global_position + Vector2(5 * World.TILE * p.facing, 0)
	await wait_physics_frames(1)
	assert_eq(w.item_user.gust(push, from, Vector2(p.facing, 0)), 0, "blocked by the wall")
	assert_eq(front.health, hp)
	# Aimed down on the ground: a gust jump.
	if p.is_on_floor():
		w.item_user.gust(push, from, Vector2(0, 1))
		assert_lt(p.velocity.y, -10.0 * World.TILE, "lifted")


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


func test_tele_grab_pulls_loose_items_to_you() -> void:
	var p := w.player
	var u := w.item_user
	var c := w.character
	c.learn_spell(&"tele_grab")
	p.ready_spell(&"tele_grab")
	assert_eq(p.held_item.id, &"tele_grab")
	var before := c.inventory.count_of(&"copper_ore")
	# A drop 14 tiles away, far past the pickup magnet, in the open above the player.
	var spot := p.chest() + Vector2(14 * World.TILE, -3 * World.TILE)
	var d := w.request_spawn_drop(&"copper_ore", 3, spot)
	u.cursor_override = spot
	p.mana = p.max_mana
	Input.action_press("use_primary")
	await wait_seconds(1.5)
	Input.action_release("use_primary")
	assert_eq(c.inventory.count_of(&"copper_ore"), before + 3, "pulled through and picked up")
	assert_false(is_instance_valid(d) and not d.is_queued_for_deletion())
	assert_lt(p.mana, p.max_mana, "costs mana while held")
	# Out of reach: the portal stops at the spell's reach.
	u.cursor_override = p.chest() + Vector2(200 * World.TILE, 0)
	u.update_target(u.cursor(), false)
	assert_almost_eq(u.grab_point().distance_to(p.chest()), u.reach(), 0.5)
	u.cursor_override = Vector2.INF


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


func test_spell_weaving_table_teaches_spells() -> void:
	var c := w.character
	var p := w.player
	c.known_spells.erase(&"blink")
	c.known_spells.erase(&"hyper_drill")
	# Scrolls are one-use casts now: no learning by right click.
	c.inventory.set_slot(0, &"scroll_blink", 2)
	p.select_slot(0)
	assert_eq(w.item_user._mode_for(p.held_item, true), ItemUser.Mode.NONE)
	assert_eq(w.item_user._mode_for(p.held_item, false), ItemUser.Mode.SCROLL, "left click casts")
	c.inventory.clear(0)  # no scroll: learning uses bars
	# The table's tabs.
	var a := w.world_to_tile(p.global_position) + Vector2i(4, -1)
	assert_true(w.request_place_object(a, w.objects.index_of(&"spell_weaving_table")))
	assert_true(w.try_interact_at(w.tile_to_world(a + Vector2i(1, -1)) + Vector2(4, 4), p))
	assert_eq(w.hud._tabs(), [], "just learning (scrolls are at the Scribe's Desk)")
	w.hud.craft_tab = 0
	var learn := w.hud.recipes()
	var names := learn.map(func(r: RecipeData) -> StringName: return r.teaches)
	assert_has(names, &"blink", "unknown spells are listed")
	assert_does_not_have(names, &"spark", "known ones aren't")
	assert_lt(names.find(&"blink"), names.find(&"hyper_drill"), "cheapest tier first")
	var blink: RecipeData = learn[names.find(&"blink")]
	assert_eq(blink.inputs, {&"copper_bar": 4} as Dictionary[StringName, int], "the learn cost, no scroll")
	c.inventory.remove(&"copper_bar", c.inventory.count_of(&"copper_bar"))
	assert_eq(w.hud.craft(blink, 1), 0, "can't afford it")
	c.inventory.add(&"copper_bar", 6)
	assert_eq(w.hud.planned_crafts(blink), 1, "learning is once")
	assert_eq(w.hud.craft(blink, 5), 1)
	assert_true(c.knows(&"blink"))
	assert_eq(c.inventory.count_of(&"copper_bar"), 2, "4 bars used")
	assert_does_not_have(w.hud.recipes().map(func(r: RecipeData) -> StringName: return r.teaches), &"blink")
	# A spell the table doesn't teach isn't listed (it comes from a Spell Page), and a
	# carried scroll doesn't teach.
	var drill_spell := _spell(&"hyper_drill")
	drill_spell.learnable_at_table = false
	c.inventory.set_slot(5, &"scroll_hyper_drill", 1)
	w.hud._recipe_key = ""  # spell data changed under the cache
	assert_does_not_have(w.hud.recipes().map(func(r: RecipeData) -> StringName: return r.teaches), &"hyper_drill",
		"not learnable at the table, scroll or not")
	drill_spell.learnable_at_table = true
	c.inventory.clear(5)
	c.learn_spell(&"hyper_drill")
	# Group buttons and search narrow every tab.
	w.hud.weave_group = SpellData.Group.MOVEMENT
	assert_true(w.hud.recipes().all(func(r: RecipeData) -> bool: return Hud.recipe_spell(r).group == SpellData.Group.MOVEMENT))
	w.hud.weave_group = -1
	# The Scribe's Desk scribes scrolls, with the same filters.
	w.hud.close_window()
	var desk := w.world_to_tile(p.global_position) + Vector2i(-8, -1)
	assert_true(w.request_place_object(desk, w.objects.index_of(&"scribes_desk")))
	assert_true(w.try_interact_at(w.tile_to_world(desk + Vector2i(1, -1)) + Vector2(4, 4), p))
	w.hud.weave_search = "blin"
	assert_eq(w.hud.recipes().map(func(r: RecipeData) -> StringName: return r.output), [&"scroll_blink"] as Array)
	w.hud.weave_search = ""
	var drill := Registry.get_def(&"recipes", &"scroll_hyper_drill") as RecipeData
	assert_eq(drill.inputs[&"copper_bar"], 10, "tier 3 costs 10 bars")
	assert_eq(drill.station, &"scribing")


func test_scrolls_tab_scribes_known_spells_at_full_cost() -> void:
	var c := w.character
	var p := w.player
	c.known_spells.erase(&"hyper_drill")
	var list := Crafting.scroll_recipes(c, [100.0, 200.0, 300.0] as Array[float])
	var outs := list.map(func(r: RecipeData) -> StringName: return r.output)
	assert_does_not_have(outs, &"scroll_hyper_drill", "unknown spells can't be scribed")
	var with_scrolls := c.known_spells.filter(func(id: StringName) -> bool:
		return ItemData.find(StringName("scroll_" + String(id))) != null)
	assert_eq(list.size(), with_scrolls.size(), "one per known spell (that has a scroll item)")
	c.learn_spell(&"hyper_drill")
	list = Crafting.scroll_recipes(c, [100.0, 200.0, 300.0] as Array[float])
	var drill: RecipeData = list.filter(func(r: RecipeData) -> bool: return r.output == &"scroll_hyper_drill")[0]
	assert_eq(drill.inputs[&"copper_bar"], 10, "full cost")
	assert_eq(drill.inputs[&"blank_scroll"], 1)
	assert_eq(drill.requires_max_mana, 300.0, "tier 3")
	var plain := Registry.get_def(&"recipes", &"scroll_hyper_drill") as RecipeData
	assert_eq(plain.inputs[&"copper_bar"], 10, "the real recipe is untouched")
	# A skill could lower the cost later.
	var half := Crafting.scroll_recipes(c, [100.0, 200.0, 300.0] as Array[float], 0.5)
	var cheap: RecipeData = half.filter(func(r: RecipeData) -> bool: return r.output == &"scroll_hyper_drill")[0]
	assert_eq(cheap.inputs[&"copper_bar"], 5)
	assert_eq(cheap.inputs[&"blank_scroll"], 1, "still one Blank Scroll")
	var spark: RecipeData = list.filter(func(r: RecipeData) -> bool: return r.output == &"scroll_spark")[0]
	assert_eq(spark.requires_max_mana, 100.0, "tier 1")
	c.inventory.add(&"blank_scroll", 5)
	c.inventory.add(&"copper_bar", 50)
	assert_eq(Crafting.times_craftable(c.inventory, drill, 100.0), 0, "too weak a mage for tier 3")
	p.mana = 40.0
	var before := c.inventory.count_of(&"scroll_spark")
	assert_eq(w.hud.craft(spark, 2), 2)
	assert_eq(c.inventory.count_of(&"scroll_spark"), before + 2)
	assert_eq(p.mana, 40.0, "no mana used")


func test_spell_pages_teach_for_good() -> void:
	var c := w.character
	var p := w.player
	var page := ItemData.find(&"page_hyper_drill")
	assert_not_null(page)
	assert_eq(page.learns_spell, &"hyper_drill")
	c.known_spells.erase(&"hyper_drill")
	c.inventory.set_slot(0, &"page_hyper_drill", 2)
	p.select_slot(0)
	assert_eq(w.item_user._mode_for(p.held_item, false), ItemUser.Mode.PAGE)
	assert_true(w.item_user.read_page())
	assert_true(c.knows(&"hyper_drill"))
	assert_eq(c.inventory.counts[0], 1, "one page used up")
	assert_false(w.item_user.read_page(), "already known: the page is kept")
	assert_eq(c.inventory.counts[0], 1)
	# Scrolls only cast.
	assert_eq(ItemData.find(&"scroll_spark").learns_spell, &"")


func test_every_known_spell_casts_with_the_book_power() -> void:
	var c := w.character
	var p := w.player
	var u := w.item_user
	var spark := _spell(&"spark")
	assert_eq(c.cast_problem(spark), "", "known: castable from anywhere")
	c.known_spells.erase(&"blink")
	assert_eq(c.cast_problem(_spell(&"blink")), "You don't know this spell")
	# Tier still counts: a tier 3 spell needs a tier 3 book.
	assert_ne(c.cast_problem(_spell(&"hyper_drill")), "", "the basic book can't handle tier 3")
	# Full price, whatever slot it comes from.
	p.ready_spell(&"spark")
	p.mana = 100.0
	p.infinite_mana = false
	await wait_seconds(0.2)
	u.cursor_override = p.chest() + Vector2(40, 0)
	u._on_impact(spark)
	assert_almost_eq(p.mana, 100.0 - spark.mana_cost, 0.01, "normal mana")
	u.cursor_override = Vector2.INF


func test_scroll_casts_share_the_cooldown() -> void:
	var c := w.character
	var p := w.player
	var u := w.item_user
	c.inventory.set_slot(0, &"scroll_blink", 3)
	p.select_slot(0)
	u.cursor_override = p.chest() + Vector2(6 * World.TILE * p.facing, 0)
	assert_true(u.cast_scroll())
	assert_gt(u.cooldown_left(_spell(&"blink")), 0.5, "the spell is now cooling down")
	assert_false(u.cast_scroll(), "a second scroll waits for it")
	assert_eq(c.inventory.counts[0], 2)
	u.cursor_override = Vector2.INF


func test_movement_key() -> void:
	var p := w.player
	assert_eq(p.movement_spell_id(), &"fly")
	assert_true(p.toggle_movement_spell())
	assert_true(p.is_flying())
	p.toggle_concentration(_spell(&"levitate"))
	assert_eq(p.movement_spell_id(), &"fly", "the Movement slot decides, not the last one used")
	assert_true(p.toggle_movement_spell(), "F swaps back to Fly")
	assert_true(p.is_flying())


func test_quick_slots_cast_or_equip() -> void:
	var p := w.player
	var c := w.character
	p.select_slot(2)
	var held_before := p.held_item
	c.set_quick(&"q_1", &"spark")
	assert_false(c.quick_casts(&"q_1"))
	assert_true(p.use_quick(&"q_1"))
	assert_eq(p.held_item.id, &"spark", "in hand")
	assert_eq(p.selected, -1)
	assert_eq(c.wheel_last[&"q"], &"q_1", "the wheel remembers it")
	p.put_spell_away()
	assert_eq(p.selected, 2)
	assert_true(p.tap_wheel(&"q"), "tapping Q uses the last pick")
	assert_eq(p.held_item.id, &"spark")
	p.select_slot(2)
	# Cast mode: casts once and goes back to what you held.
	c.toggle_quick_mode(&"q_1")
	w.item_user.cursor_override = p.chest() + Vector2(40 * p.facing, 0)
	assert_true(p.use_quick(&"q_1"))
	await wait_seconds(0.6)
	assert_eq(p.selected, 2, "back to the hotbar slot")
	assert_eq(p.held_item, held_before)
	# A toggle just toggles.
	c.set_quick(&"z", &"mend")
	assert_true(c.quick_casts(&"z"))
	assert_true(p.use_quick(&"z"))
	assert_eq(p.concentration, _spell(&"mend"))
	p.use_quick(&"z")
	assert_null(p.concentration)
	c.set_quick(&"x", &"")
	assert_false(p.use_quick(&"x"), "empty")
	w.item_user.cursor_override = Vector2.INF


func test_r_takes_out_the_mining_spell_and_ctrl_r_chopping() -> void:
	var p := w.player
	p.select_slot(1)
	p.toggle_tool_spell(&"mining_spell")
	assert_eq(p.held_item.id, &"mining_spell")
	p.toggle_tool_spell(&"chopping_spell")
	assert_eq(p.held_item.id, &"chopping_spell", "switches straight over")
	p.toggle_tool_spell(&"chopping_spell")
	assert_eq(p.selected, 1, "again: put away, back to the hotbar")


func test_buff_set_casts_them_all() -> void:
	var p := w.player
	var c := w.character
	for i in CharacterData.BUFF_SET_SIZE:
		c.set_quick(CharacterData.buff_slot(i), &"")
	c.set_quick(&"buff_0", &"arcane_edge")
	assert_false(c.set_quick(&"buff_1", &"light_orb"), "Buff spells only")
	c.set_quick(&"buff_2", &"barrier")
	p.mana = 1000.0
	assert_eq(p.cast_buff_set(), 2)
	assert_true(p.has_buff(&"arcane_edge"))
	assert_true(p.has_buff(&"barrier"))
	assert_eq(p.cast_buff_set(), 0, "already on: skipped")
	p.end_buff(&"arcane_edge")
	p.infinite_mana = false
	p.mana = 0.0
	assert_eq(p.cast_buff_set(), 0, "no mana: nothing")
	assert_false(p.has_buff(&"arcane_edge"))


func test_gel_cushion_needs_slime_and_saves_one_fall() -> void:
	var p := w.player
	var c := w.character
	var gel := _spell(&"gel_cushion")
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


func _slime_at(offset: Vector2) -> Enemy:
	var slime := Registry.get_def(&"enemies", &"green_slime") as EnemyData
	return w.request_spawn_enemy(slime, w.player.global_position + offset)


func test_arcane_bolt_grows_with_charge() -> void:
	var u := w.item_user
	var p := w.player
	p.ready_spell(&"arcane_bolt")
	await wait_seconds(0.2)  # a few idle frames (several physics steps can run first)
	assert_eq(u.mode, ItemUser.Mode.CHARGE)
	p.mana = 100.0
	u.charge = 0.0
	var tap := u.release_charge()
	assert_not_null(tap)
	assert_almost_eq(tap.size, 0.6, 0.01)
	assert_almost_eq(p.mana, 100.0 - 15.0 * 0.27, 0.1, "a tap is cheap")
	u._ready_at.clear()
	u.charge = 1.5
	var full := u.release_charge()
	assert_almost_eq(full.size, 1.8, 0.01, "full charge: big bolt")
	assert_gt(full.power, tap.power * 4.0, "and five times the damage")


func test_healing_circle_heals_inside() -> void:
	var p := w.player
	p.health = 40.0
	var z := w.request_spell_effect(_spell(&"healing_circle"), p.chest(), 1.0) as SpellZone
	assert_not_null(z)
	await wait_seconds(1.0)
	assert_gt(p.health, 43.0, "about 4 a second")
	z.global_position += Vector2(200, 0)
	var h := p.health
	await wait_seconds(0.5)
	assert_almost_eq(p.health, h, 0.6, "not outside it (only regen)")


func test_spark_ward_zaps_the_first_enemy() -> void:
	var p := w.player
	var ward := w.request_spell_effect(_spell(&"spark_ward"), p.chest() + Vector2(6 * World.TILE, 0), 1.0) as SpellWard
	assert_not_null(ward, "found ground under the cursor")
	var e := _slime_at(Vector2(6 * World.TILE, -30))
	e.data = e.data.duplicate()
	e.data.max_health = 100.0
	e.health = 100.0
	await wait_seconds(1.2)
	assert_almost_eq(e.health, 80.0, 0.1, "zapped for 20")
	assert_false(is_instance_valid(ward) and not ward.is_queued_for_deletion(), "spent")
	for i in 4:
		w.request_spell_effect(_spell(&"spark_ward"), p.chest() + Vector2(-(i + 3) * 3 * World.TILE, 0), 1.0)
	await wait_physics_frames(1)
	assert_eq(get_tree().get_nodes_in_group(&"spell_wards").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size(), 3, "3 at most")


func test_familiar_shoots_enemies() -> void:
	var fam := w.request_spell_effect(_spell(&"familiar"), Vector2.ZERO, 1.0) as Familiar
	assert_not_null(fam)
	var e := _slime_at(Vector2(8 * World.TILE * w.player.facing, -10))
	await wait_seconds(2.0)
	assert_lt(e.health, e.data.max_health, "shot")


func test_conjured_platform_holds_you_then_fades() -> void:
	var p := w.player
	var at := p.global_position + Vector2(0, -12 * World.TILE)
	var plat := w.request_spell_effect(_spell(&"conjure_platform"), at, 1.0) as ConjuredPlatform
	assert_not_null(plat)
	assert_eq(w.collision_at(at), TileDef.Collision.PLATFORM)
	p.global_position = at + Vector2(0, -4 * World.TILE)
	p.reset_physics_interpolation()
	await wait_seconds(0.8)
	assert_true(p.is_on_floor(), "standing on it")
	assert_almost_eq(p.global_position.y, float(w.world_to_tile(at).y * World.TILE), 2.0)
	assert_null(w.request_spell_effect(_spell(&"conjure_platform"), at, 1.0), "no room where one already is")
	plat.time_left = 0.01
	await wait_physics_frames(3)
	assert_ne(w.collision_at(at), TileDef.Collision.PLATFORM, "gone")


func test_arcane_edge_boosts_melee() -> void:
	var p := w.player
	var sword := ItemData.find(&"copper_sword")
	var e := _slime_at(Vector2(2 * World.TILE * p.facing, 0))
	e.data = e.data.duplicate()
	e.data.max_health = 1000.0
	e.health = 1000.0
	await wait_physics_frames(2)
	w.item_user.cursor_override = e.hit_rect().get_center()
	w.item_user.melee_hit(sword)
	var plain := 1000.0 - e.health
	p.add_buff(_spell(&"arcane_edge"))
	var before := e.health
	w.item_user.melee_hit(sword)
	assert_almost_eq(before - e.health, plain * 1.5, 0.1, "+50%")
	w.item_user.cursor_override = Vector2.INF


func test_barrier_pops_a_shield() -> void:
	var p := w.player
	p.invincible = false
	p.health = 100.0
	p.add_buff(_spell(&"barrier"))
	p.reset_hurt_cooldown()
	p.take_damage(50.0, &"enemy")
	assert_almost_eq(p.health, 50.0, 1.0, "still above a quarter: no pop")
	assert_true(p.has_buff(&"barrier"))
	p.reset_hurt_cooldown()
	p.take_damage(40.0, &"fall")
	assert_false(p.has_buff(&"barrier"), "popped")
	assert_almost_eq(p.health, 40.0, 0.1, "the shield soaked 30 of the 40")
	assert_eq(p.shield, 0.0, "used up")
	p.reset_hurt_cooldown()
	p.take_damage(10.0, &"fall")
	assert_almost_eq(p.health, 30.0, 0.1, "then damage goes through")
	# A fresh barrier: a small shield left over lasts until its time runs out.
	p.health = 100.0
	p.add_buff(_spell(&"barrier"))
	p.reset_hurt_cooldown()
	p.take_damage(80.0, &"fall")
	assert_almost_eq(p.health, 50.0, 0.1, "30 soaked, 50 through")


func test_chain_spark_jumps() -> void:
	var p := w.player
	var a := _slime_at(Vector2(5 * World.TILE * p.facing, -20))
	var b := _slime_at(Vector2(9 * World.TILE * p.facing, -20))
	var c := _slime_at(Vector2(13 * World.TILE * p.facing, -20))
	var far := _slime_at(Vector2(40 * World.TILE * p.facing, -20))
	await wait_physics_frames(1)
	w.item_user.cursor_override = a.global_position
	var n := w.item_user.chain(_spell(&"chain_spark"), p.chest())
	assert_eq(n, 3, "hit three, not the far one")
	assert_eq(far.health, far.data.max_health)
	assert_gt(a.data.max_health - a.health, b.data.max_health - b.health, "weaker each jump")
	w.item_user.cursor_override = Vector2.INF


func test_chain_spark_fires_without_a_target() -> void:
	var p := w.player
	var u := w.item_user
	var chain := _spell(&"chain_spark")
	u.cursor_override = p.chest() + Vector2(8 * World.TILE * p.facing, -2 * World.TILE)
	p.mana = 100.0
	p.infinite_mana = false
	assert_eq(u.chain(chain, p.casting_hand_position()), 0, "nothing there: a miss")
	assert_true(u.cast(chain), "but it still goes off")
	u.cursor_override = Vector2.INF


func test_summon_and_light_timers_show() -> void:
	var p := w.player
	var wisp := _spell(&"wisp")
	assert_eq(w.summon_time_left(wisp), 0.0)
	w.summon_light_orb(wisp)
	w.summon_light_orb(wisp)
	await wait_physics_frames(1)
	assert_eq(w.summons_of(wisp).size(), 2)
	assert_gt(w.summon_time_left(wisp), 0.0)
	var shown := w.hud.buff_entries().filter(func(e: Array) -> bool: return e[1] == wisp)
	assert_eq(shown.size(), 1)
	assert_eq(shown[0][4], "2/3", "how many are out")
	assert_true(p.is_spell_active(wisp))
	# Right click in the buff row sends them away.
	assert_true(w.hud.dismiss_buff(shown[0]))
	await wait_physics_frames(1)
	assert_eq(w.summons_of(wisp).size(), 0)


func test_right_click_ends_buffs_but_not_sickness() -> void:
	var p := w.player
	p.add_buff(_spell(&"arcane_edge"))
	var entry: Array = w.hud.buff_entries().filter(func(e: Array) -> bool: return e[0] == &"arcane_edge")[0]
	assert_true(w.hud.dismiss_buff(entry))
	assert_false(p.has_buff(&"arcane_edge"))
	p._timed_buff(&"sick_healing", "Healing Sickness", "", 30.0, null)
	entry = w.hud.buff_entries().filter(func(e: Array) -> bool: return e[0] == &"sick_healing")[0]
	assert_false(w.hud.dismiss_buff(entry))
	assert_true(p.has_buff(&"sick_healing"))


func test_recall_ritual() -> void:
	var p := w.player
	var home := w.respawn_position()
	p.global_position += Vector2(30 * World.TILE, -20)
	p.reset_physics_interpolation()
	await wait_seconds(1.0)
	var recall := _spell(&"recall")
	p.mana = 100.0
	assert_true(p.start_ritual(recall))
	Input.action_press("move_right")
	await wait_physics_frames(3)
	Input.action_release("move_right")
	assert_null(p.ritual, "moving breaks it")
	assert_eq(p.mana, 100.0, "no mana spent")
	await wait_seconds(0.5)
	assert_true(p.start_ritual(recall))
	await wait_seconds(3.4)
	assert_null(p.ritual)
	assert_lt(p.global_position.distance_to(home), 3 * World.TILE, "home")
	assert_almost_eq(p.mana, 60.0, 2.0, "paid at the end")


func test_seek_ore_finds_copper() -> void:
	var p := w.player
	var copper := w.blocks.index_of(&"copper_ore")
	var t := w.world_to_tile(p.chest()) + Vector2i(10, 6)
	w.data.set_block(t.x, t.y, copper)
	var sense := w.request_spell_effect(_spell(&"seek_ore"), p.chest(), 1.0) as OreSense
	assert_not_null(sense)
	assert_true(t in sense.found or w.wrap_tile(t) in sense.found, "the ore we put there")


func test_sounds_play_and_throttle() -> void:
	assert_not_null(Sounds.stream_for(&"enemy_hit"), "placeholder exists")
	assert_null(Sounds.stream_for(&"no_such_sound"), "missing is silent")
	Sounds._last.clear()
	assert_true(Sounds.play(&"enemy_hit", w.player.chest()))
	assert_false(Sounds.play(&"enemy_hit", w.player.chest()), "not twice in a row")
	assert_true(Sounds.play(&"craft"))



func test_scroll_left_click_casts_free() -> void:
	var p := w.player
	var c := w.character
	var u := w.item_user
	# Blink from a scroll: no mana, the scroll is used.
	c.inventory.set_slot(0, &"scroll_blink", 2)
	p.select_slot(0)
	p.mana = 0.0
	u.cursor_override = p.chest() + Vector2(8 * World.TILE * p.facing, 0)
	var start := p.global_position
	assert_true(u.cast_scroll())
	assert_gt(absf(p.global_position.x - start.x), 4.0 * World.TILE, "blinked")
	assert_eq(p.mana, 0.0, "free")
	assert_eq(c.inventory.counts[0], 1, "one scroll used")
	# A cast that can't happen keeps the scroll.
	c.inventory.set_slot(1, &"scroll_conjure_platform", 1)
	p.select_slot(1)
	u.cursor_override = p.global_position + Vector2(0, 2 * World.TILE)  # in the ground
	assert_false(u.cast_scroll())
	assert_eq(c.inventory.counts[1], 1, "not used")
	u.cursor_override = Vector2.INF


func test_scroll_fly_runs_free_then_stops() -> void:
	var p := w.player
	var c := w.character
	c.inventory.set_slot(0, &"scroll_fly", 1)
	p.select_slot(0)
	p.mana = 50.0
	assert_true(w.item_user.cast_scroll())
	assert_true(p.is_flying())
	assert_true(p.is_free_spell(_spell(&"fly")))
	assert_true(c.inventory.is_empty(0), "used")
	await wait_seconds(0.6)
	assert_gte(p.mana, 50.0, "no drain while free")
	p.buffs[&"scroll_fly"] = 0.05
	await wait_seconds(0.2)
	assert_false(p.is_flying(), "stops when the time is up")


func test_scroll_beam_then_back_to_the_hotbar() -> void:
	var p := w.player
	var c := w.character
	c.known_spells.erase(&"hyper_drill")  # a beam you don't know is put away after
	c.inventory.set_slot(2, &"scroll_hyper_drill", 1)
	p.select_slot(2)
	assert_true(w.item_user.cast_scroll())
	assert_eq(p.held_item.id, &"hyper_drill", "ready to use, without a tier 3 book")
	await wait_seconds(0.2)
	assert_eq(w.item_user.problem, "", "no book or mana problem")
	p.buffs[&"scroll_hyper_drill"] = 0.05
	await wait_seconds(0.2)
	assert_eq(p.selected, 2, "put away when the time is up")


func test_z_x_c_take_item_shortcuts() -> void:
	var p := w.player
	var c := w.character
	var inv := c.inventory
	inv.remove(&"berries", 999)
	inv.remove(&"wood_platform", 999)
	inv.set_slot(25, &"berries", 3)
	inv.set_slot(26, &"wood_platform", 5)
	assert_false(c.set_quick_item(&"q_0", &"berries"), "wheels are spells only")
	assert_true(c.set_quick_item(&"z", &"berries"))
	assert_eq(c.quick_spell(&"z"), &"", "an item, not a spell")
	assert_eq(c.quick_item(&"z"), &"berries")
	p.hunger = 10.0
	assert_true(p.use_quick(&"z"), "food is eaten right away")
	assert_eq(inv.count_of(&"berries"), 2)
	# A block from the backpack goes in your hand and places from there.
	assert_true(c.set_quick_item(&"x", &"wood_platform"))
	assert_true(p.use_quick(&"x"))
	assert_eq(p.held_item.id, &"wood_platform")
	assert_eq(p.held_count(), 5)
	assert_true(p.take_held())
	assert_eq(inv.counts[26], 4)
	# Saved and loaded.
	var d := c.to_dict()
	assert_eq(String(d["quick"]["z"]), "item:berries")
	# Used up: the hand empties.
	inv.set_slot(26, &"", 0)
	assert_null(p.held_item)


func test_movement_slot_picks_the_movement_spell() -> void:
	var p := w.player
	var c := w.character
	assert_true(c.knows(&"fly") and c.knows(&"levitate"))
	c.set_movement_spell(&"")
	assert_eq(p.movement_spell_id(), &"fly", "default")
	assert_true(c.set_movement_spell(&"levitate"))
	assert_eq(p.movement_spell_id(), &"levitate")
	assert_false(c.set_movement_spell(&"blink"), "not a movement toggle")
	p.toggle_concentration(_spell(&"fly"))
	p.toggle_concentration(_spell(&"fly"))
	assert_eq(p.movement_spell_id(), &"levitate", "using Fly doesn't change the choice")


func test_wheel_pick_doesnt_cast() -> void:
	var p := w.player
	var c := w.character
	c.set_quick(&"q_2", &"mend")
	assert_true(c.quick_casts(&"q_2"))
	p.pick_wheel(&"q_2")
	assert_null(p.concentration, "picking didn't cast")
	assert_eq(c.wheel_last[&"q"], &"q_2", "it's the tap spell now")
	assert_true(p.tap_wheel(&"q"))
	assert_eq(p.concentration, _spell(&"mend"), "tapping casts it")
	p.toggle_concentration(_spell(&"mend"))


func test_healing_circle_moves_instead_of_stacking() -> void:
	var circle := _spell(&"healing_circle")
	assert_eq(circle.max_active, 1)
	var at := w.player.chest()
	w.request_spell_effect(circle, at, 1.0)
	w.request_spell_effect(circle, at + Vector2(16, 0), 1.0)
	await wait_physics_frames(1)
	var zones := w.effects.get_children().filter(func(n: Node) -> bool: return n is SpellZone)
	assert_eq(zones.size(), 1, "the first one went")
	assert_eq((zones[0] as SpellZone).global_position, at + Vector2(16, 0))


func test_book_tooltip_layout() -> void:
	var book := ItemData.find(&"basic_spellbook")
	assert_eq(Hud.tooltip_right(book), "Tier 1")
	var text := Hud.tooltip_for(book)
	assert_true(text.begins_with("Basic Spellbook\nSpell power x1"))
	assert_false("Holds" in text)
	assert_eq(Hud.tooltip_right(ItemData.find(&"wood")), "")


func test_dev_books_for_each_tier() -> void:
	DevMagic._register()
	for t in range(1, 4):
		var b := ItemData.find(StringName("spellbook_t%d" % t))
		assert_not_null(b)
		assert_eq(b.max_spell_tier, t)
		assert_eq(b.kind, ItemData.Kind.BOOK)


func test_tooltips_say_which_spells_have_their_own_key() -> void:
	assert_string_contains(Hud.spell_tooltip(_spell(&"mining_spell")), "own key (R)")
	assert_string_contains(Hud.spell_tooltip(_spell(&"chopping_spell")), "own key (Ctrl + R)")
	assert_string_contains(Hud.spell_tooltip(_spell(&"fly")), "Movement slot")
	assert_false(Hud.spell_tooltip(_spell(&"spark")).contains("own key"))


func test_readied_jump_spells_trigger_once_in_the_air_and_land_safe() -> void:
	var p := w.player
	var c := w.character
	for id: StringName in [&"air_step", &"bound"]:
		c.learn_spell(id)
		assert_true(_spell(id).fits_movement_slot(), "%s goes in the Movement slot" % id)
	p.invincible = false
	p.health = p.max_health
	# Air Step: off, Jump in the air does nothing.
	p.global_position.y -= 40 * World.TILE
	p.reset_physics_interpolation()
	await wait_physics_frames(5)
	assert_false(p.is_on_floor())
	p.mana = p.max_mana
	Input.action_press("jump")
	await wait_physics_frames(2)
	Input.action_release("jump")
	assert_gt(p.velocity.y, 0.0, "nothing readied: still falling")
	# Readied: on, costs nothing until it fires.
	p.toggle_concentration(_spell(&"air_step"))
	assert_eq(p.mana, p.max_mana)
	Input.action_press("jump")
	await wait_physics_frames(2)
	Input.action_release("jump")
	assert_lt(p.velocity.y, 0.0, "a second jump")
	assert_almost_eq(p.mana, p.max_mana - 8.0, 1.0, "8 mana once")
	await wait_physics_frames(2)
	var mana := p.mana
	Input.action_press("jump")
	await wait_physics_frames(2)
	Input.action_release("jump")
	assert_almost_eq(p.mana, mana, 1.0, "only once per time in the air")
	await wait_seconds(3.0)
	assert_true(p.is_on_floor())
	assert_eq(p.health, p.max_health, "a 40 tile fall, but the landing was safe")
	# Bound: a leap forward.
	p.toggle_concentration(_spell(&"bound"))
	p.global_position.y -= 40 * World.TILE
	p.reset_physics_interpolation()
	await wait_physics_frames(15)  # past the coyote time
	var x := p.global_position.x
	Input.action_press("jump")
	await wait_physics_frames(2)
	Input.action_release("jump")
	assert_gt(absf(p.velocity.x), 20.0 * World.TILE, "leaps forward")
	assert_lt(p.velocity.y, 0.0, "in an arc")
	await wait_physics_frames(20)
	assert_gt(absf(p.global_position.x - x), 6.0 * World.TILE, "keeps the momentum")
	p.toggle_concentration(_spell(&"bound"))
