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


func test_things_made_at_a_wrapped_spot_appear_next_to_the_player() -> void:
	var width := float(w.data.width * World.TILE)
	var p := w.player.global_position
	# The player walked left past x = 0: a slime or drop made at the wrapped x
	# (a whole world to the right) shows up beside them instead.
	w.player.global_position = Vector2(-80.0, p.y)
	var e := w.request_spawn_enemy(_slime(), Vector2(width - 40.0, p.y))
	assert_almost_eq(e.position.x, -40.0, 0.01)
	var d := w.request_spawn_drop(&"stone", 1, Vector2(width - 120.0, p.y))
	assert_almost_eq(d.position.x, -120.0, 0.01)
	w.player.global_position = p


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
	var table := w.spawner.table_here()
	assert_not_null(table, "the forest surface table")
	for i in 12:
		w.spawner.try_spawn(table)
	assert_gte(w.enemy_count(), table.cap(false))
	assert_eq(w.spawner.spawn_chance(table, 1.0), 0.0, "no chance at the cap")


func test_spawn_chance_and_weighted_picks() -> void:
	var t := w.spawner.table_here()
	w.clock.set_hour(12.0)
	# Empty area: catch up (12 s * 0.6 = 7.2 s average wait).
	assert_almost_eq(w.spawner.spawn_chance(t, 1.0), 1.0 / (t.day_seconds * 0.6), 0.0001)
	w.spawner.catch_up = false
	assert_almost_eq(w.spawner.spawn_chance(t, 1.0), 1.0 / t.day_seconds, 0.0001)
	w.clock.set_hour(23.0)
	assert_almost_eq(w.spawner.spawn_chance(t, 1.0), 1.0 / t.night_seconds, 0.0001, "more often at night")
	assert_gt(t.cap(true), t.cap(false), "a higher cap at night")
	# Blue Slime is locked until a Green Slime has been slain in this world.
	for i in 200:
		assert_eq(t.pick(false, i / 200.0, w).id, &"green_slime", "only green before the first kill")
	var e := w.request_spawn_enemy(_slime(), w.player.global_position + Vector2(80, -20))
	await wait_physics_frames(1)
	e.kill()
	assert_eq(w.kill_count(&"green_slime"), 1)
	# Weighted picks: now Blue Slime is the rare one.
	var blue := 0
	for i in 1000:
		if t.pick(false, i / 1000.0, w).id == &"blue_slime":
			blue += 1
	assert_almost_eq(blue, roundi(1000.0 * 12.0 / 112.0), 2.0, "about 11% Blue Slime")
	var only_night := SpawnTable.new()
	only_night.entries.append(SpawnEntry.make(_slime(), 1.0, false, true))
	assert_null(only_night.pick(false, 0.5, w), "nothing allowed by day")
	assert_eq(only_night.pick(true, 0.5, w), _slime())
	var needs_two := SpawnTable.new()
	needs_two.entries.append(SpawnEntry.make(_slime(), 1.0, true, true,
		[KillCountCondition.make(&"green_slime", 2)] as Array[SpawnCondition]))
	assert_null(needs_two.pick(false, 0.5, w), "1 of 2 kills: still locked")


func test_nothing_spawns_underground() -> void:
	var p := w.player
	var feet := w.world_to_tile(p.global_position)
	assert_not_null(w.spawner.table_here(), "the forest surface")
	var surface := w.generator.surface_at(w.wrap_tile(feet).x)
	p.global_position = w.tile_to_world(Vector2i(feet.x, surface + 40))
	assert_null(w.spawner.table_here(), "40 tiles down: no table")


func test_armor_is_drawn_on_the_character() -> void:
	var c := w.character
	var doll: PaperDoll = w.player._doll
	c.equip(&"chest", &"copper_chestplate")
	c.equip(&"head", &"copper_helmet")
	await wait_physics_frames(1)
	var torso := doll.rig.part_index("Torso")
	assert_eq(doll._overlays[torso].size(), 1, "chestplate over the torso")
	assert_true(doll.hair_hidden, "helmet hides the hair")
	c.equip(&"head", &"")
	c.equip(&"chest", &"")
	await wait_physics_frames(1)
	assert_eq(doll._overlays[torso].size(), 0)
	assert_false(doll.hair_hidden)


func test_butcher_kills_with_loot() -> void:
	var p := w.player
	w.request_spawn_enemy(_slime(), p.global_position + Vector2(60, -20))
	await wait_physics_frames(2)
	var before := w.drop_count()
	w.enemies()[0].kill()
	await wait_physics_frames(2)
	assert_eq(w.enemy_count(), 0)
	assert_gt(w.drop_count(), before, "dropped its loot")


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


func test_equipment_window_opens_centered_and_drags() -> void:
	var hud := w.hud
	assert_false(hud._equip.visible)
	hud.toggle_equipment()
	assert_true(hud.open, "the inventory opens too")
	assert_true(hud._equip.visible)
	var view := hud._view_size()
	var center := hud._equip.position + hud._equip.size * 0.5
	assert_almost_eq(center.x, view.x * 0.5, 2.0, "opens in the middle")
	# Layout: armor left of the character, trinkets right, book and conduit under it.
	var e := hud._equip
	var doll := e.doll_rect()
	assert_lt(e.slot_rect(0).end.x, doll.position.x, "head on the left")
	assert_gt(e.slot_rect(3).position.x, doll.end.x, "trinket on the right")
	assert_gt(e.slot_rect(6).position.y, doll.end.y, "book underneath")
	assert_not_null(e._doll, "a character preview")
	# Drag by the title bar.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(30, 8)
	e._gui_input(press)
	var move := InputEventMouseMotion.new()
	move.position = Vector2(30 - 50, 8 + 20)
	var before := e.position
	e._gui_input(move)
	assert_eq(e.position, before + Vector2(-50, 20))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	e._gui_input(release)
	# Kept when reopened; closing the inventory closes it.
	hud.set_open(false)
	assert_false(e.visible)
	hud.toggle_equipment()
	assert_eq(e.position, before + Vector2(-50, 20), "keeps its spot")
	# Folding the spells section makes it shorter.
	var tall := e.size.y
	var fold := InputEventMouseButton.new()
	fold.button_index = MOUSE_BUTTON_LEFT
	fold.pressed = true
	fold.position = e.fold_rect().get_center()
	e._gui_input(fold)
	assert_false(e.spells_shown)
	assert_lt(e.size.y, tall)
	hud.toggle_equipment()
	assert_false(hud.equipping)
	assert_true(hud.open, "closing equipment keeps the inventory open")


func test_spell_index_lists_spells_and_puts_them_in_the_book() -> void:
	var hud := w.hud
	var c := w.character
	hud.toggle_equipment()
	hud.toggle_spells()
	assert_true(hud._spells.visible)
	assert_gt(hud._spells.position.x, hud._equip.position.x, "opens beside the equipment window")
	assert_gt(c.known_spells.size(), 0, "the dev kit knows spells")
	# Pick the first known spell from the index and drop it in the first Q slot.
	c.set_quick(&"q_0", &"")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = hud._spells.row_rect(0).get_center()
	hud._spells._gui_input(click)
	assert_eq(hud.cursor_id, ItemData.spell_key(c.known_spells[0]))
	var book_click := InputEventMouseButton.new()
	book_click.button_index = MOUSE_BUTTON_LEFT
	book_click.pressed = true
	book_click.position = hud._equip.quick_rect(&"q_0").get_center()
	hud._equip._gui_input(book_click)
	assert_eq(c.quick_spell(&"q_0"), c.known_spells[0], "on the Q wheel")
	assert_eq(hud.cursor_count, 0)
	hud.set_open(false)
	assert_false(hud._spells.visible)


func test_spawns_ahead_when_moving_and_despawn_waits() -> void:
	var p := w.player
	var sp := w.spawner
	var slime := Registry.get_def(&"enemies", &"green_slime") as EnemyData
	assert_gt(slime.aggro_tiles, sp.max_distance_tiles, "slimes notice you from where they spawn")
	p.velocity.x = -20.0 * World.TILE  # running left
	var left := 0
	for i in 40:
		var spot := sp.find_spot(slime)
		if spot != Vector2.INF and spot.x < p.global_position.x:
			left += 1
	assert_gt(left, 26, "mostly ahead (about 80%)")
	p.velocity.x = 0.0
	# Far away: kept for despawn_seconds, then removed.
	var e := w.request_spawn_enemy(slime, p.global_position + Vector2(100 * World.TILE, -40))
	await wait_physics_frames(2)
	sp._despawn_far()
	assert_false(e.is_queued_for_deletion(), "not straight away")
	e.far_for = sp.despawn_seconds
	sp._despawn_far()
	assert_true(e.is_queued_for_deletion(), "after a while")


func test_slime_hops_over_a_one_block_step() -> void:
	var p := w.player
	p.invincible = true
	var feet := w.world_to_tile(p.global_position)
	var step_x := feet.x + 14
	var stone := w.blocks.index_of(&"stone")
	for dy in range(1, 3):
		w.request_set_block(Vector2i(step_x, feet.y - dy), stone if dy == 1 else WorldData.AIR)
	# Right next to the step, on the far side from the player (within aggro).
	var start := w.tile_to_world(Vector2i(step_x + 3, feet.y - 1)) + Vector2(0, World.TILE)
	var hopper := _slime().duplicate() as EnemyData
	hopper.slither_chance = 0.0
	var e := w.request_spawn_enemy(hopper, start)
	e._angry = true  # chasing
	await wait_seconds(8.0)
	assert_true(is_instance_valid(e))
	assert_lt(e.global_position.x, float(step_x) * World.TILE, "got over the step toward the player")
	# A slither steps up a 1-tile ledge too.
	var slider := _slime().duplicate() as EnemyData
	slider.slither_chance = 1.0
	slider.hop_wait_min = 0.1
	slider.hop_wait_max = 0.2
	e.queue_free()
	var e2 := w.request_spawn_enemy(slider, start)
	e2._angry = true
	await wait_seconds(6.0)
	assert_lt(e2.global_position.x, float(step_x) * World.TILE, "slithered up the ledge")


func test_slimes_wander_by_day_and_chase_at_night_or_when_hit() -> void:
	var p := w.player
	p.invincible = true
	var e := w.request_spawn_enemy(_slime(), p.global_position + Vector2(30 * World.TILE, -8))
	await wait_physics_frames(2)
	w.clock.time = 0.5  # noon
	assert_eq(e._target_dir(), 0.0, "by day it ignores you")
	e._angry = true
	assert_eq(e._target_dir(), -1.0, "once hit it comes at you")
	e._angry = false
	w.clock.time = 0.0  # midnight
	assert_true(w.spawner.is_night())
	assert_eq(e._target_dir(), -1.0, "at night it comes at you")


func test_fists_do_damage() -> void:
	var p := w.player
	var e := w.request_spawn_enemy(_slime(), p.global_position + Vector2(14 * p.facing, 0))
	await wait_physics_frames(2)
	w.item_user.cursor_override = p.chest() + Vector2(40 * p.facing, 0)
	# A punch with empty hands lands at fist_impact_at and hits like a weak sword.
	var empty := -1
	for i in Inventory.HOTBAR:
		if p.character.inventory.is_empty(i):
			empty = i
	if empty < 0:
		p.character.inventory.clear(Inventory.HOTBAR - 1)
		empty = Inventory.HOTBAR - 1
	p.select_slot(empty)
	assert_null(p.held_item)
	Input.action_press("use_primary")
	await wait_seconds(0.4)
	Input.action_release("use_primary")
	await wait_physics_frames(2)
	assert_lt(e.health, _slime().max_health, "punched")
	assert_eq(p.fist_item().melee_damage, p.fist_damage)
	w.item_user.cursor_override = Vector2.INF


func test_swings_reach_downhill_and_punches_aim() -> void:
	var p := w.player
	var u := w.item_user
	var feet := p.global_position
	var side := float(p.facing)
	# A slime-sized box 3 tiles out, sitting 2 tiles below your feet (downhill).
	var below := Rect2(Vector2(feet.x + side * 3.0 * World.TILE - 15.0, feet.y + 2.0 * World.TILE - 20.0), Vector2(30, 20))
	var sword := ItemData.find(&"copper_sword")
	u.cursor_override = p.chest() + Vector2(side * 40.0, 0.0)
	assert_true(u.melee_rect(sword).intersects(below), "the sword's arc reaches downhill")
	# Punches: toward the cursor, capped at 60 degrees.
	var fist := p.fist_item()
	u.cursor_override = Vector2(below.get_center().x, below.get_center().y)
	assert_true(u.melee_rect(fist).intersects(below), "punch aimed down the hill")
	u.cursor_override = p.chest() + Vector2(side * 40.0, -200.0)
	assert_false(u.melee_rect(fist).intersects(below), "punching up doesn't hit below")
	u.cursor_override = p.chest() + Vector2(side * 5.0, 300.0)
	var r := u.melee_rect(fist)
	var reach := fist.melee_reach * World.TILE
	var capped := p.chest().y + reach * sin(deg_to_rad(60.0)) + w.item_user.aimed_hit_width_tiles * 0.5 * World.TILE
	assert_almost_eq(r.end.y, capped, 0.6, "straight down is capped at 60 degrees")
	u.cursor_override = Vector2.INF


func test_melee_doesnt_hit_through_walls() -> void:
	var p := w.player
	var sword := ItemData.find(&"copper_sword")
	var e := w.request_spawn_enemy(_slime(), p.global_position + Vector2(36 * p.facing, 0))
	await wait_physics_frames(2)
	w.item_user.cursor_override = p.chest() + Vector2(40 * p.facing, 0)
	# A solid wall of blocks between you and the slime, floor to above your head.
	var feet := w.world_to_tile(p.global_position)
	var wall_x := feet.x + 2 * p.facing
	for dy in range(-12, 0):
		w.request_set_block(Vector2i(wall_x, feet.y + dy), w.blocks.index_of(&"stone"))
	assert_eq(w.item_user.melee_hit(sword), 0, "the wall is in the way")
	assert_eq(e.health, _slime().max_health)
	for dy in range(-12, 0):
		w.request_set_block(Vector2i(wall_x, feet.y + dy), WorldData.AIR)
	assert_eq(w.item_user.melee_hit(sword), 1, "clear again")
	e.queue_free()
	w.item_user.cursor_override = Vector2.INF


func test_swings_dont_reach_far_below_while_flying() -> void:
	var p := w.player
	var sword := ItemData.find(&"wooden_sword")
	p.toggle_concentration(Registry.get_def(&"spells", &"fly") as SpellData)
	p.global_position.y -= 9 * World.TILE
	p.reset_physics_interpolation()
	await wait_physics_frames(2)
	assert_false(p.is_on_floor())
	var e := w.request_spawn_enemy(_slime(), p.global_position + Vector2(-8, 4 * World.TILE))
	await wait_physics_frames(1)
	e.global_position = p.global_position + Vector2(-8, 4 * World.TILE)
	w.item_user.cursor_override = e.global_position
	assert_eq(w.item_user.melee_hit(sword), 0, "4 tiles under your feet in the air: out of reach")
	e.queue_free()
	p.toggle_concentration(Registry.get_def(&"spells", &"fly") as SpellData)
	w.item_user.cursor_override = Vector2.INF
