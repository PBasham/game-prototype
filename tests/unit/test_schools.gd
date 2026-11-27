extends GutTest
## Phase 25: schools and school weapons. Spells have a school; gear raises it; a school
## weapon marks enemies (Storm: shocked) and its school's spells cash the mark in; the
## Dual Storm Axes amplify Storm spells in hand and leap and slam on right click.

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
	w.queue_free()
	await wait_physics_frames(2)
	w = null
	Game.world_info = null


func _slime(dx: float) -> Enemy:
	var slime := Registry.get_def(&"enemies", &"green_slime") as EnemyData
	return w.request_spawn_enemy(slime, w.player.global_position + Vector2(dx, 0))


func _hold(item_id: StringName) -> void:
	w.character.inventory.set_slot(0, item_id, 1)
	w.player.select_slot(0)


func test_every_spell_has_a_school() -> void:
	var expect := {&"spark": ItemData.School.STORM, &"chain_spark": ItemData.School.STORM,
		&"arcane_bolt": ItemData.School.ARCANE, &"air_push": ItemData.School.AIR,
		&"wisp": ItemData.School.SPIRIT, &"mend": ItemData.School.LIFE, &"mining_spell": ItemData.School.NONE}
	for id: StringName in expect:
		assert_eq((Registry.get_def(&"spells", id) as SpellData).school, expect[id], String(id))
	assert_string_contains(Hud.spell_tooltip(Registry.get_def(&"spells", &"spark") as SpellData), "Storm spell")
	assert_eq(Schools.damage_stat(ItemData.School.STORM), &"storm_damage")
	assert_has(CharacterData.STATS, &"storm_damage")


func test_gear_and_a_storm_weapon_raise_storm_spells() -> void:
	var p := w.player
	assert_eq(p.school_mult(ItemData.School.STORM), 1.0)
	w.character.equip(&"accessory_1", &"storm_charm")
	await wait_physics_frames(1)
	assert_almost_eq(p.school_mult(ItemData.School.STORM), 1.15, 0.001, "Storm Charm")
	assert_almost_eq(p.school_mult(ItemData.School.ARCANE), 1.0, 0.001, "only Storm")
	_hold(&"dual_storm_axes")
	assert_almost_eq(p.school_mult(ItemData.School.STORM), 1.35, 0.001, "axes in hand: +20%")
	# Quick casting a spell keeps the axes' boost (they're still your hotbar weapon).
	p.ready_spell(&"spark")
	assert_eq(p.weapon_in_hand().id, &"dual_storm_axes")
	assert_almost_eq(p.school_mult(ItemData.School.STORM), 1.35, 0.001)


func test_axe_hits_shock_and_storm_spells_cash_it_in() -> void:
	var e := _slime(3 * World.TILE)
	var spark := Registry.get_def(&"spells", &"spark") as SpellData
	assert_eq(Schools.payoff(e, spark), 1.0, "not marked yet")
	_hold(&"dual_storm_axes")
	w.item_user.cursor_override = e.hit_rect().get_center()
	assert_gt(w.item_user.melee_hit(w.player.held_item), 0)
	assert_true(e.is_marked(ItemData.School.STORM), "shocked")
	assert_false(e.is_marked(ItemData.School.ARCANE))
	assert_eq(Schools.payoff(e, spark), Schools.MARK_PAYOFF, "Storm spells hit it harder")
	assert_eq(Schools.payoff(e, Registry.get_def(&"spells", &"arcane_bolt") as SpellData), 1.0, "other schools don't")
	var hp := e.health
	await wait_seconds(Schools.MARK_TICK * 2.5)
	assert_lt(e.health, hp, "the shock ticks")
	await wait_seconds(3.5)
	assert_false(e.is_marked(ItemData.School.STORM), "and wears off")


func test_storm_axes_leap_far() -> void:
	var p := w.player
	_hold(&"dual_storm_axes")
	w.item_user.cursor_override = p.global_position + Vector2(400, 0)
	var start := p.global_position
	assert_true(p.try_weapon_skill())
	for i in 240:
		await wait_physics_frames(1)
		if not p.is_slamming():
			break
	assert_gt(p.global_position.x - start.x, 15.0 * World.TILE, "a long leap (about 18 tiles on flat ground)")


func test_right_click_leaps_and_slams() -> void:
	var p := w.player
	_hold(&"dual_storm_axes")
	var e := _slime(6 * World.TILE)
	w.item_user.cursor_override = e.global_position
	# A short leap, so it lands on the slime (the axes' own leap goes much farther).
	var axes := ItemData.find(&"dual_storm_axes")
	var leap := [axes.skill_leap_speed, axes.skill_leap_height]
	axes.skill_leap_speed = 26.0
	axes.skill_leap_height = 3.5
	var hp := e.health
	var start := p.global_position
	assert_true(p.try_weapon_skill())
	assert_true(p.is_slamming())
	assert_lt(p.velocity.y, 0.0, "up")
	assert_gt(p.velocity.x, 0.0, "toward the cursor")
	for i in 120:
		await wait_physics_frames(1)
		if not p.is_slamming():
			break
	axes.skill_leap_speed = leap[0]
	axes.skill_leap_height = leap[1]
	assert_false(p.is_slamming(), "landed")
	assert_gt(p.global_position.x, start.x + 2 * World.TILE, "leapt forward")
	assert_lt(e.health, hp, "the slam hit it")
	assert_true(e.is_marked(ItemData.School.STORM))
	assert_gt(p.skill_cooldown_left(&"dual_storm_axes"), 0.0, "on cooldown")
	assert_true(p.try_weapon_skill(), "right click is used up...")
	assert_false(p.is_slamming(), "...but nothing happens until it's ready")


func test_dual_axes_show_one_in_each_hand() -> void:
	_hold(&"dual_storm_axes")
	await wait_physics_frames(3)
	var doll := w.player.doll()
	assert_true(doll._dual())
	assert_true(doll._offhand_sprite.visible, "the second axe")
	assert_eq(doll._offhand_sprite.texture, doll._item_sprite.texture)
	w.player.select_slot(1)  # the copper sword: one hand
	await wait_physics_frames(3)
	assert_false(doll._offhand_sprite.visible)
	var tip := Hud.tooltip_for(ItemData.find(&"dual_storm_axes"))
	assert_string_contains(tip, "Storm weapon")
	assert_string_contains(tip, "shocked")
	assert_string_contains(tip, "Right click")
