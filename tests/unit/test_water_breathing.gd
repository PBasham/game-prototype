extends GutTest
## Phase 66: 20 s of breath, the breath row on the status panel, Water Breathing potions,
## and kelp you can mine.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const BOTTLES := {&"clay_flask": 2, &"glass_vial": 2, &"clay_bottle": 4, &"glass_bottle": 4,
	&"glass_flask": 6, &"clay_jug": 8}

var w: World


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


func test_twenty_seconds_of_breath() -> void:
	var p := w.player
	assert_eq(p.max_breath, 20.0)
	p.head_under = true
	p._update_breath(19.0)
	assert_almost_eq(p.breath, 1.0, 0.01)
	assert_eq(p.health, p.max_health, "no drowning yet")


func test_water_breathing_in_every_bottle() -> void:
	for bottle: StringName in BOTTLES:
		var id := StringName("water_breathing_" + String(bottle))
		var item := ItemData.find(id)
		assert_not_null(item, String(id))
		assert_true(item.buff_water_breathing)
		assert_eq(item.buff_seconds, 60.0 * BOTTLES[bottle], "%s lasts %d minutes" % [id, BOTTLES[bottle]])
		var r: RecipeData = null
		for d in Registry.get_all(&"recipes"):
			if d.id == id:
				r = d as RecipeData
		assert_not_null(r)
		assert_eq(r.station, &"alchemy")
		assert_eq(r.inputs, {StringName("water_" + String(bottle)): 1, &"kelp": 2} as Dictionary[StringName, int])


func test_water_breathing_keeps_your_breath() -> void:
	var p := w.player
	p.consume(ItemData.find(&"water_breathing_glass_vial"))
	assert_almost_eq(p.water_breathing_left(), 120.0, 0.5)
	p.head_under = true
	p._update_breath(60.0)
	assert_eq(p.breath, p.max_breath, "breath never runs out")
	p.end_buff(&"item_water_breathing_glass_vial")
	p._update_breath(5.0)
	assert_lt(p.breath, p.max_breath, "it ran out")


func test_breath_row_shows_under_water() -> void:
	var p := w.player
	assert_false(Hud._shows_breath(p))
	p.breath = 12.0
	assert_true(Hud._shows_breath(p))


## Kelp on the sea floor: mining it drops Kelp, and it grows back after a day.
func test_kelp_can_be_mined_and_grows_back() -> void:
	var floor_tile := w.world_to_tile(w.player.global_position) + Vector2i(14, -30)
	var stone := w.blocks.index_of(&"stone")
	w.request_set_block(floor_tile, stone)
	# Stand a kelp plant there (the generator's answer, cached in SeaFlora).
	w.sea_flora._cache[w.data.wrap_x(floor_tile.x)] = Vector3i(2, 6, floor_tile.y)
	var t := floor_tile + Vector2i(0, -3)
	assert_true(w.sea_flora.kelp_at(t))
	var before := w._drops.get_child_count()
	assert_true(w.request_damage_block(t, 1.0), "cut in one hit")
	assert_eq(w._drops.get_child_count(), before + 1)
	var drop := w._drops.get_child(w._drops.get_child_count() - 1) as ItemDrop
	assert_eq(drop.item_id, &"kelp")
	assert_eq(drop.count, 2, "one per 3 tiles of it")
	assert_false(w.sea_flora.kelp_at(t), "gone")
	assert_eq(w.sea_flora.to_dict().size(), 1, "saved")
	w.clock.advance(w.clock.days(1.05))
	assert_true(w.sea_flora.kelp_at(t), "grew back")
