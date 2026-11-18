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
	assert_eq(w.item_user._mode_for(p.held_item, true), ItemUser.Mode.LEARN, "right click learns")
	assert_eq(w.item_user._mode_for(p.held_item, false), ItemUser.Mode.SCROLL, "left click casts")
	# Away from a Spell Weaving Table: can't learn, nothing used.
	assert_eq(w.item_user.learn_problem(_spell(&"blink")), "Learn it at a Spell Weaving Table")
	assert_false(w.item_user.read_scroll())
	assert_eq(c.inventory.counts[0], 2)
	# At a table, without the bars, then with them.
	var a := w.world_to_tile(p.global_position) + Vector2i(4, -1)
	assert_true(w.request_place_object(a, w.objects.index_of(&"spell_weaving_table")))
	c.inventory.remove(&"copper_bar", c.inventory.count_of(&"copper_bar"))
	assert_eq(w.item_user.learn_problem(_spell(&"blink")), "Learning Blink needs 4 Copper Bar")
	assert_false(w.item_user.read_scroll())
	c.inventory.add(&"copper_bar", 6)
	assert_true(w.item_user.read_scroll())
	assert_true(c.knows(&"blink"))
	assert_eq(c.inventory.counts[0], 1, "one scroll used")
	assert_eq(c.inventory.count_of(&"copper_bar"), 2, "4 bars used")
	assert_false(w.item_user.read_scroll(), "already known: nothing used")
	assert_eq(c.inventory.counts[0], 1)
	var drill := Registry.get_def(&"recipes", &"scroll_hyper_drill") as RecipeData
	assert_eq(drill.inputs[&"copper_bar"], 10, "tier 3 costs 10 bars")
	assert_eq(drill.station, &"spell_weaving")


func test_known_spells_craft_cheaper_and_copy_for_mana() -> void:
	var c := w.character
	var p := w.player
	var plain := Registry.get_def(&"recipes", &"scroll_hyper_drill") as RecipeData
	c.known_spells.erase(&"hyper_drill")
	assert_eq(Crafting.for_crafter(plain, c, 0.5), plain, "unknown: full price")
	c.learn_spell(&"hyper_drill")
	var cheap := Crafting.for_crafter(plain, c, 0.5)
	assert_eq(cheap.inputs[&"copper_bar"], 5, "known: half of 10")
	assert_eq(cheap.inputs[&"blank_scroll"], 1, "still a Blank Scroll")
	assert_ne(cheap.note, "")
	assert_eq(plain.inputs[&"copper_bar"], 10, "the real recipe is untouched")
	var other := Registry.get_def(&"recipes", &"wooden_sword") as RecipeData
	assert_eq(Crafting.for_crafter(other, c, 0.5), other, "not a scroll: unchanged")
	# Copy tab: every known spell (not only the book), for a Blank Scroll and mana.
	c.book_spells.erase(&"hyper_drill")
	var copies := Crafting.copy_recipes(c, 3.0, 10.0, 60.0)
	var with_scrolls := c.known_spells.filter(func(id: StringName) -> bool:
		return ItemData.find(StringName("scroll_" + String(id))) != null)
	assert_eq(copies.size(), with_scrolls.size(), "one per known spell that has a scroll")
	var drill: RecipeData = copies.filter(func(r: RecipeData) -> bool: return r.output == &"scroll_hyper_drill")[0]
	assert_eq(drill.inputs, {&"blank_scroll": 1} as Dictionary[StringName, int])
	assert_eq(drill.mana, 60.0, "30/s x 2 s x 3, capped at 60")
	var spark: RecipeData = copies.filter(func(r: RecipeData) -> bool: return r.output == &"scroll_spark")[0]
	assert_eq(spark.mana, 10.0, "2 x 3 = 6, at least 10")
	# Making copies spends mana and is limited by it.
	c.inventory.add(&"blank_scroll", 5)
	p.infinite_mana = false
	p.mana = 130.0
	assert_eq(Crafting.times_craftable(c.inventory, drill, p.mana), 2, "two copies' worth of mana")
	var hud := w.hud
	hud.station = w.world_to_tile(p.global_position)  # no station: crafting needs only the recipe here
	assert_eq(hud.craft(drill, 5), 2)
	assert_almost_eq(p.mana, 10.0, 0.01, "60 per copy")
	assert_eq(c.inventory.count_of(&"scroll_hyper_drill"), 2)


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


func _slime_at(offset: Vector2) -> Enemy:
	var slime := Registry.get_def(&"enemies", &"green_slime") as EnemyData
	return w.request_spawn_enemy(slime, w.player.global_position + offset)


func test_arcane_bolt_grows_with_charge() -> void:
	var u := w.item_user
	var p := w.player
	w.character.put_in_book(3, &"arcane_bolt")
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
	# Blink from a scroll: no mana, not in the book, the scroll is used.
	c.put_in_book(0, &"mining_spell")
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
	c.book_spells.erase(&"hyper_drill")
	c.inventory.set_slot(2, &"scroll_hyper_drill", 1)
	p.select_slot(2)
	assert_true(w.item_user.cast_scroll())
	assert_eq(p.held_item.id, &"hyper_drill", "ready to use, without a tier 3 book")
	await wait_seconds(0.2)
	assert_eq(w.item_user.problem, "", "no book or mana problem")
	p.buffs[&"scroll_hyper_drill"] = 0.05
	await wait_seconds(0.2)
	assert_eq(p.selected, 2, "put away when the time is up")
