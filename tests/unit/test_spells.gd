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
