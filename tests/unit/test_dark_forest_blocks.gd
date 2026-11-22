extends GutTest
## Phase 21: Dark Forest Dirt, Grass and Stone (and walls) under the Dark Forest all the
## way down, biomes counted from blocks, bricks, the Forest Spirit Pendant, trees on
## level ground, and moving lights between tiles.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World


func after_each() -> void:
	if w:
		w.queue_free()
		await wait_physics_frames(2)
		w = null
	Game.world_info = null


func _gen() -> ForestGenerator:
	var settings := ForestGenerator.default_settings()
	return ForestGenerator.new(TileTypes.new(&"tiles"), TileTypes.new(&"walls"), 6400, 1200, 42, settings)


func _world() -> World:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	var world := WORLD_SCENE.instantiate() as World
	add_child(world)
	await wait_physics_frames(3)
	world.spawner.peaceful = true
	return world


func test_dark_forest_ground_goes_to_the_bottom_with_wobbly_sides() -> void:
	var g := _gen()
	var tiles := TileTypes.new(&"tiles")
	var p := g.dark_forests()[0]
	var x := roundi(p.x)
	var dark := 0
	var plain := 0
	for y in range(g.surface_at(x), g.height, 7):
		var b := g.block_at(x, y)
		if b <= 0:
			continue
		if tiles.biome_of(b) == &"dark_forest":
			dark += 1
		elif tiles.is_ground(b):
			plain += 1
	assert_gt(dark, 40, "the middle is Dark Forest ground from top to bottom")
	assert_eq(plain, 0, "no plain dirt or stone in the middle")
	var clay := tiles.index_of(&"clay")
	for cx in range(x - 200, x + 200, 9):
		for y in range(g.surface_at(posmod(cx, g.width)), g.surface_at(posmod(cx, g.width)) + 120, 3):
			assert_ne(g.block_at(posmod(cx, g.width), y), clay, "no clay under the Dark Forest")
	assert_false(g.dark_forest_blocks_at(g.settings.spawn_x, 300, g._column(g.settings.spawn_x)), "not at spawn")
	# The side wanders: where it is changes with depth.
	var edges: Array[int] = []
	for y in [200, 500, 800, 1100]:
		var col_x := roundi(p.x + p.y) - 80
		while col_x < roundi(p.x + p.y) + 80 and g.dark_forest_blocks_at(posmod(col_x, g.width), y, g._column(posmod(col_x, g.width))):
			col_x += 1
		edges.append(col_x)
	assert_gt(edges.max() - edges.min(), 4, "the edge isn't a straight line down")
	# Walls follow: the dirt and stone walls under it are the dark versions.
	var walls := TileTypes.new(&"walls")
	var found := false
	for y in range(g.surface_at(x) + 6, g.surface_at(x) + 200):
		var wl := g.wall_at(x, y)
		if wl > 0:
			assert_string_starts_with(String(walls.id_of(wl)), "dark_forest", "dark walls under it")
			found = true
	assert_true(found)


func test_ground_kinds_and_grass_pairs() -> void:
	var tiles := TileTypes.new(&"tiles")
	var dd := tiles.index_of(&"dark_forest_dirt")
	var dg := tiles.index_of(&"dark_forest_grass")
	assert_true(tiles.is_dirt(dd), "acts as dirt")
	assert_true(tiles.is_grass(dg), "acts as grass")
	assert_true(tiles.is_ground(tiles.index_of(&"dark_forest_stone")))
	assert_eq(tiles.grass_of(dd), dg, "grass spreading onto it makes Dark Forest Grass")
	assert_eq(tiles.dirt_of(dg), dd, "and covered, it goes back")
	assert_eq(tiles.grass_of(tiles.index_of(&"dirt")), tiles.index_of(&"grass"))
	assert_false(tiles.is_ground(tiles.index_of(&"stone_bricks")), "bricks are built, not ground")


func test_biome_is_counted_from_the_blocks_around_you() -> void:
	w = await _world()
	var feet := w.world_to_tile(w.player.global_position)
	assert_eq(w.biome_at(feet), &"forest")
	var dark := w.blocks.index_of(&"dark_forest_stone")
	for y in range(feet.y + 1, feet.y + 16):
		for x in range(feet.x - 24, feet.x + 24):
			w.data.set_block(x, y, dark)
	w._biome_cache.clear()
	assert_eq(w.biome_at(feet), &"dark_forest", "built from Dark Forest blocks: you're in it")


func test_bricks_from_stone_at_the_furnace() -> void:
	for pair: Array in [[&"stone_bricks", &"stone"], [&"dark_forest_stone_bricks", &"dark_forest_stone"]]:
		var r := Registry.get_def(&"recipes", pair[0]) as RecipeData
		assert_not_null(r)
		assert_eq(r.station, &"furnace")
		assert_eq(r.inputs, {pair[1]: 2} as Dictionary[StringName, int])
		var item := ItemData.find(pair[0])
		assert_eq(item.places_block, pair[0])
		assert_eq(item.places_wall, StringName(String(pair[0]) + "_wall"))


func test_pendant_adds_a_summon_and_summon_damage() -> void:
	w = await _world()
	var spell := ItemData.find(ItemData.spell_key(&"call_spirit")) as SpellData
	assert_eq(spell.display_name, "Summon Forest Spirit")
	w.request_spell_effect(spell, w.player.chest(), 1.0)
	var second := w.request_spell_effect(spell, w.player.chest(), 1.0) as Familiar
	await wait_physics_frames(1)
	assert_eq(w.summons_of(spell).size(), 1, "one at a time without it")
	w.character.equip(&"accessory_1", &"forest_spirit_pendant")
	await wait_physics_frames(2)
	assert_eq(w.player.stat(&"summon_slots"), 1.0)
	var third := w.request_spell_effect(spell, w.player.chest(), 1.0) as Familiar
	await wait_physics_frames(1)
	assert_eq(w.summons_of(spell).size(), 2, "two with the Pendant")
	assert_ne(third.slot, second.slot, "they float apart")
	assert_almost_eq(third.power, 1.2, 0.001, "+20% summon damage")
	var r := Registry.get_def(&"recipes", &"forest_spirit_pendant") as RecipeData
	assert_eq(r.inputs[&"spirit_core"], 1)


func test_trees_need_level_ground_under_the_trunk() -> void:
	var g := _gen()
	var checked := 0
	for x in range(0, g.width, 3):
		var t := g.tree_at(x)
		if t < 0:
			continue
		var half := 1 if t >= g.settings.tree_variants else 0
		var root := g.surface_at(x)
		for k in range(-half, half + 1):
			assert_lte(g.surface_at(posmod(x + k, g.width)), root, "no drop under the trunk at %d" % x)
		for k: int in [-half - 1, half + 1]:
			assert_lte(g.surface_at(posmod(x + k, g.width)), root + 1, "at most a tile at its edge")
		checked += 1
		if checked > 200:
			break
	assert_gt(checked, 20)


func test_moving_light_between_tiles_lights_both() -> void:
	var job := LightJob.new()
	var lit := func(at: Vector2) -> Array:
		job.extra = [[at, 6.0, Color.WHITE]]
		var solid := PackedByteArray()
		solid.resize(20 * 20)
		job.objects = []
		var res := job._sources(20, 20, 1, solid)
		var r: PackedFloat32Array = res[0]
		return [r[10 * 20 + 10], r[10 * 20 + 11]]
	var left: Array = lit.call(Vector2(10.5, 10.5))
	var mid: Array = lit.call(Vector2(11.0, 10.5))
	assert_gt(float(left[0]), float(left[1]), "on a tile: that tile is brightest")
	assert_almost_eq(float(mid[0]), float(mid[1]), 0.001, "half way: shared")


func test_one_of_each_accessory() -> void:
	var c := CharacterData.new()
	var pendant := ItemData.find(&"forest_spirit_pendant")
	assert_eq(c.equip_problem(&"accessory_1", pendant), "")
	c.equip(&"accessory_1", &"forest_spirit_pendant")
	assert_string_contains(c.equip_problem(&"accessory_2", pendant), "already wearing")
	assert_eq(c.equip_problem(&"accessory_1", pendant), "", "swapping in the same slot is fine")
	var r := Registry.get_def(&"recipes", &"forest_spirit_pendant") as RecipeData
	assert_eq(r.inputs[&"iron_bar"], 10)


func test_summon_slime_fights_for_you_and_evolves() -> void:
	w = await _world()
	var spell := ItemData.find(ItemData.spell_key(&"summon_slime")) as SpellData
	assert_not_null(spell)
	assert_eq(spell.learn_cost, {&"slime_core": 1, &"slime": 20, &"magic_essence": 5})
	var drops := {}
	for l in (Registry.get_def(&"enemies", &"green_slime") as EnemyData).loot:
		drops[l.item] = l.chance
	assert_almost_eq(float(drops[&"slime_core"]), 0.025, 0.0001, "a rare core")
	assert_lt(float(drops[&"page_summon_slime"]), float(drops[&"slime_core"]), "the page is rarer")
	var mine := w.request_spell_effect(spell, w.player.chest(), 1.0) as Enemy
	assert_not_null(mine)
	assert_true(mine.is_summon())
	assert_eq(mine.data.id, &"green_slime", "rank 0: a green slime")
	assert_false(mine.is_in_group(&"damageable"), "your hits don't hurt it")
	assert_false(w.enemies().has(mine), "not counted as an enemy")
	assert_eq(w.summons_of(spell).size(), 1)
	# It goes after an enemy and hits it.
	var slime := Registry.get_def(&"enemies", &"green_slime") as EnemyData
	var e := w.request_spawn_enemy(slime, w.player.global_position + Vector2(5 * World.TILE, 0))
	var hit := false
	for i in 1800:  # slimes hop at random: give it time
		await wait_physics_frames(1)
		if not is_instance_valid(e) or e.health < e.data.max_health:
			hit = true
			break
	assert_true(hit, "your slime hits the enemy")
	# Evolve: rank 1 makes a blue slime that hits harder.
	var node := Registry.get_def(&"empower", &"evolve") as EmpowerNode
	assert_true(node.fits(spell))
	assert_false(node.fits(ItemData.find(ItemData.spell_key(&"spark")) as SpellData), "only for evolving summons")
	w.character.empower[spell.id] = {&"evolve": 1}
	var blue := w.request_spell_effect(spell, w.player.chest(), 1.0) as Enemy
	assert_eq(blue.data.id, &"blue_slime")
	assert_gt(blue.summon_damage, mine.summon_damage if is_instance_valid(mine) else spell.damage, "hits harder")
	assert_eq(w.summons_of(spell).size(), 1, "one summon at a time: the new one replaced it")
