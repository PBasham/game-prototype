extends GutTest
## Phase 14: the Dark Forest (patches, darkwood trees, darkness) and the Forest Spirit.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World


func after_each() -> void:
	if w:
		w.queue_free()
		await wait_physics_frames(2)
		w = null
	Game.world_info = null


func _gen(width: int) -> ForestGenerator:
	var settings := ForestGenerator.default_settings()
	return ForestGenerator.new(TileTypes.new(&"tiles"), TileTypes.new(&"walls"), width, 512, 42, settings)


func test_patches_scale_with_the_world_and_keep_spawn_clear() -> void:
	var s := ForestGenerator.default_settings()
	for size: Array in [[1024, 1], [6400, 2]]:
		var g := _gen(size[0])
		var patches := g.dark_forests()
		assert_eq(patches.size(), size[1], "%d wide: %d patches" % size)
		var covered := 0.0
		for p in patches:
			covered += p.y * 2.0
			var gap := absf(float(g.wrap_delta(roundi(p.x), s.spawn_x))) - p.y
			assert_gte(gap, float(s.dark_forest_spawn_clear) - 1.0, "spawn stays clear")
		assert_almost_eq(covered, s.dark_forest_share * size[0], 2.0)
		assert_eq(g.dark_forest_at(s.spawn_x), 0.0)
		assert_eq(g.biome_at(s.spawn_x), &"forest")


func test_dark_trees_grow_close_together_inside_a_patch() -> void:
	var g := _gen(6400)
	var s := g.settings
	var p := g.dark_forests()[0]
	var inside := 0
	var dark_trees := 0
	for x in range(roundi(p.x - p.y * 0.5), roundi(p.x + p.y * 0.5)):
		var t := g.tree_at(posmod(x, g.width))
		inside += 1
		if t >= 0:
			assert_gte(t, s.tree_variants, "darkwood variants come after the pines")
			dark_trees += 1
	assert_gt(dark_trees, inside / s.tree_spacing, "denser than a pine grove")
	assert_eq(g.biome_at(roundi(p.x)), &"dark_forest")
	# Outside: only pines.
	for x in range(s.spawn_x - 100, s.spawn_x + 100):
		assert_lt(g.tree_at(x), s.tree_variants)


func test_darkwood_trees_drop_dark_logs_and_logs_make_darkwood() -> void:
	w = await _world()
	var feet := w.world_to_tile(w.player.global_position)
	var ground := w.wrap_tile(Vector2i(feet.x + 5, feet.y))
	var tree := w.plants._add(ground, PlantLayer.Kind.TREE, 12)
	assert_eq(w.plants.log_of(tree), &"dark_log")
	assert_gt(w.plants._height_tiles(tree), 20.0, "taller than the pines")
	w.plants._break(ground, tree)
	var dark := 0
	for d in w._drops.get_children():
		if (d as ItemDrop).item_id == &"dark_log":
			dark += (d as ItemDrop).count
	assert_gt(dark, 0)
	var recipe := Registry.get_def(&"recipes", &"darkwood") as RecipeData
	assert_eq(recipe.inputs, {&"dark_log": 1})
	assert_eq(recipe.output_count, 4)
	assert_eq(ItemData.find(&"darkwood").places_block, &"darkwood_planks")
	assert_true(w.blocks.index_of(&"darkwood_planks") > 0)
	assert_true(w.walls.index_of(&"darkwood_wall") > 0)


func test_forest_spirit_charges_and_shoots_you() -> void:
	w = await _world()
	var spirit_data := Registry.get_def(&"enemies", &"forest_spirit") as EnemyData
	assert_eq(spirit_data.shot_damage, 15.0)
	var p := w.player
	var start := p.health
	var e := w.request_spawn_enemy(spirit_data, p.global_position + Vector2(9 * World.TILE, -5 * World.TILE))
	var charged := false
	for i in 480:
		await wait_physics_frames(1)
		if e._state == Enemy.SpiritState.CHARGE and not charged:
			charged = true
			start = p.health  # bumping into you also hurts; count only the shot
		if charged and p.health < start:
			break
	assert_true(charged, "it stopped to charge")
	assert_lt(p.health, start, "and the shot hit")
	assert_gt(e.global_position.y, p.global_position.y - 12.0 * World.TILE, "floats near the ground")
	# Loot: Magic Essence always, a Spirit Core rarely.
	var odds := {}
	for l in spirit_data.loot:
		odds[l.item] = l.chance
	assert_eq(odds[&"magic_essence"], 1.0)
	assert_between(float(odds[&"spirit_core"]), 0.01, 0.2)


func test_dark_forest_spawns_spirits() -> void:
	var t := Registry.get_def(&"spawns", &"dark_forest_surface") as SpawnTable
	assert_eq(t.biome, &"dark_forest")
	var ids: Array[StringName] = []
	for e in t.entries:
		ids.append(e.enemy.id)
	assert_has(ids, &"forest_spirit")


func _world() -> World:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	var world := WORLD_SCENE.instantiate() as World
	add_child(world)
	await wait_physics_frames(3)
	world.spawner.peaceful = true
	return world
