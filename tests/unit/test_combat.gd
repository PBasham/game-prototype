extends GutTest
## Phase 7: enemies (green slime), melee, defense, equipment stats, beds and sleeping.

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
	Game.world_info = null


func _slime() -> EnemyData:
	return Registry.get_def(&"enemies", &"green_slime") as EnemyData


func _floor_spot(dx: int) -> Vector2i:
	var feet := w.world_to_tile(w.player.global_position)
	return Vector2i(feet.x + dx, feet.y - 1)


func test_slime_data_and_loot() -> void:
	var d := _slime()
	assert_not_null(d)
	assert_lt(d.contact_damage, 10.0, "doesn't do a ton of damage")
	var drops := LootDrop.roll(d.loot)
	assert_between(drops.get(&"slime", 0), 1, 2, "slimes drop slime")
	assert_not_null(ItemData.find(&"slime"))


func test_sword_kills_a_slime_and_it_drops_slime() -> void:
	var p := w.player
	var sword := ItemData.find(&"copper_sword")
	var e := w.request_spawn_enemy(_slime(), p.global_position + Vector2(20 * p.facing, 0))
	await wait_physics_frames(2)
	w.item_user.cursor_override = p.chest() + Vector2(40 * p.facing, 0)
	assert_eq(w.item_user.melee_hit(sword), 1, "in reach")
	assert_almost_eq(e.health, _slime().max_health - sword.melee_damage, 0.01)
	assert_ne(e.velocity.x, 0.0, "knocked back")
	var drops_before := w.drop_count()
	w.item_user.melee_hit(sword)
	await wait_physics_frames(1)
	assert_false(is_instance_valid(e) and not e.is_queued_for_deletion(), "two hits: dead")
	assert_gt(w.drop_count(), drops_before, "dropped its loot")
	# Behind you: missed.
	var e2 := w.request_spawn_enemy(_slime(), p.global_position + Vector2(-40 * p.facing, 0))
	await wait_physics_frames(2)
	assert_eq(w.item_user.melee_hit(sword), 0, "only in front, toward the cursor")
	e2.queue_free()


func test_touching_a_slime_hurts_less_with_armor() -> void:
	var p := w.player
	var d := _slime()
	p.take_damage(d.contact_damage, &"enemy", p.global_position + Vector2(10, 0), d.knockback)
	assert_almost_eq(p.health, p.max_health - d.contact_damage, 0.01, "no armor: full damage")
	assert_lt(p.velocity.x, 0.0, "knocked away from it")
	var c := w.character
	c.equip(&"head", &"copper_helmet")
	c.equip(&"chest", &"copper_chestplate")
	c.equip(&"legs", &"copper_greaves")
	assert_eq(p.defense, 4)
	p.health = p.max_health
	p.reset_hurt_cooldown()
	p.take_damage(d.contact_damage, &"enemy")
	assert_almost_eq(p.health, p.max_health - (d.contact_damage - 2.0), 0.01, "defense 4 takes off 2")
	p.reset_hurt_cooldown()
	p.take_damage(1.0, &"enemy")
	assert_almost_eq(p.health, p.max_health - (d.contact_damage - 2.0) - 1.0, 0.01, "at least 1 gets through")


func test_a_slime_touching_you_hurts() -> void:
	var p := w.player
	w.request_spawn_enemy(_slime(), p.global_position)
	await wait_physics_frames(3)
	assert_lt(p.health, p.max_health)


func test_equipment_slots_and_stats() -> void:
	var c := w.character
	var p := w.player
	assert_true(CharacterData.fits(&"head", ItemData.find(&"copper_helmet")))
	assert_false(CharacterData.fits(&"legs", ItemData.find(&"copper_helmet")), "a helmet only goes on your head")
	assert_false(CharacterData.fits(&"accessory_1", ItemData.find(&"copper_helmet")))
	var ring := ItemData.find(&"dev_ring")
	if ring == null:
		pass_test("no dev ring outside debug builds")
		return
	assert_true(CharacterData.fits(&"accessory_2", ring))
	var base_health := p.max_health
	var base_speed := p._current_speed()
	c.equip(&"accessory_1", &"dev_ring")
	assert_eq(p.max_health, base_health + 20.0)
	assert_almost_eq(p._current_speed(), base_speed * 1.2, 0.01)
	assert_eq(p.defense, 2)
	c.equip(&"accessory_1", &"")
	assert_eq(p.max_health, base_health, "taking it off removes the bonus")
	# Saved with the character.
	c.equip(&"chest", &"copper_chestplate")
	var back := CharacterData.load_file(SaveManager.character_path(c.name)) if c.save() == OK else null
	if back:
		assert_eq(back.equipment[&"chest"], &"copper_chestplate")
		DirAccess.remove_absolute(SaveManager.character_path(c.name))


func test_quick_equip_fills_empty_accessory_slots() -> void:
	var c := w.character
	if ItemData.find(&"dev_ring") == null:
		pass_test("debug only")
		return
	c.inventory.set_slot(39, &"dev_ring", 1)
	w.hud.quick_equip(39)
	assert_eq(c.equipment[&"accessory_1"], &"dev_ring")
	c.inventory.set_slot(39, &"dev_ring", 1)
	w.hud.quick_equip(39)
	assert_eq(c.equipment[&"accessory_2"], &"dev_ring", "the next empty one")


func test_spawner_spawns_on_the_surface_not_indoors() -> void:
	w.spawner.peaceful = false
	var spot := w.spawner.find_spot(_slime())
	assert_ne(spot, Vector2.INF)
	var t := w.world_to_tile(spot)
	assert_true(w.is_solid(t), "standing on ground")
	assert_false(w.is_solid(t + Vector2i.UP), "with room above")
	var dx := absf(spot.x - w.player.global_position.x)
	assert_gt(dx, w.spawner.min_distance_tiles * 8.0 - 8.0, "off screen")
	w.clock.set_hour(12.0)
	w.spawner.max_day = 1
	for i in 5:
		w.spawner._timer = 0.0
		w.spawner._process(0.01)
	assert_lte(w.enemy_count(), 1, "capped by day")


func test_beds_set_the_respawn_point_and_sleep_through_the_night() -> void:
	var a := _floor_spot(4)
	assert_true(w.request_place_object(a, w.objects.index_of(&"bed")))
	w.clock.set_hour(12.0)
	w.use_bed(a)
	assert_eq(w.spawn_points[w.character.name], w.wrap_tile(a), "spawn point set by day")
	assert_almost_eq(w.clock.hour(), 12.0, 0.01, "no sleeping by day")
	w.clock.set_hour(23.0)
	var day := w.clock.day
	w.use_bed(a)
	assert_almost_eq(w.clock.hour(), w.clock.sunrise_hour + 1.0, 0.05, "slept till morning")
	assert_eq(w.clock.day, day + 1)
	var near := w.respawn_position()
	assert_lt(near.distance_to(w.tile_to_world(a)), 9 * 8.0, "respawn at the bed")
	# Enemies nearby keep you awake.
	w.clock.set_hour(23.0)
	var e := w.request_spawn_enemy(_slime(), w.player.global_position + Vector2(40, 0))
	w.use_bed(a)
	assert_almost_eq(w.clock.hour(), 23.0, 0.05, "can't sleep with enemies nearby")
	e.queue_free()
	# No bed: back to the world spawn.
	w.request_remove_object(a)
	var spawn := w.respawn_position()
	assert_eq(spawn, w.tile_to_world(w.generator.spawn_tile()) + Vector2(4, 0), "the world spawn")
	assert_false(w.spawn_points.has(w.character.name))
