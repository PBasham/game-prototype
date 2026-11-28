extends GutTest
## Phase 56: crabs, fish, the ocean spawn table, sea plants, crab and fish cooking.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World
var floor_tile: Vector2i


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	var feet := w.world_to_tile(w.player.global_position)
	floor_tile = Vector2i(feet.x + 12, feet.y - 30)
	w.spawner.peaceful = true


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


## A stone tank 16 wide and 10 tall high in the air, `depth` tiles of water in it.
func _tank(depth: int) -> void:
	var stone := w.blocks.index_of(&"stone")
	for x in range(-1, 17):
		w.request_set_block(floor_tile + Vector2i(x, 0), stone)
	for y in range(1, 11):
		w.request_set_block(floor_tile + Vector2i(-1, -y), stone)
		w.request_set_block(floor_tile + Vector2i(16, -y), stone)
	for y in range(1, depth + 1):
		for x in 16:
			w.voxels.request_fill(floor_tile + Vector2i(x, -y), &"water")


func _enemy(id: StringName) -> EnemyData:
	return Registry.get_def(&"enemies", id) as EnemyData


func test_crabs_scuttle_and_leave_you_alone_until_hit() -> void:
	_tank(0)
	var crab := w.request_spawn_enemy(_enemy(&"crab"), w.tile_to_world(floor_tile + Vector2i(8, 0)))
	await wait_seconds(3.0)
	assert_ne(crab.global_position.x, w.tile_to_world(floor_tile + Vector2i(8, 0)).x + 4.0, "it moved")
	# Stand on it: no pinch.
	w.teleport_player(crab.global_position)
	var hp := w.player.health
	await wait_physics_frames(10)
	assert_eq(w.player.health, hp, "harmless until hit")
	crab.take_damage(1.0, w.player)
	w.teleport_player(crab.global_position)
	await wait_seconds(0.5)
	assert_lt(w.player.health, hp, "pinches once hit")


func test_crab_drops_raw_crab() -> void:
	var data := _enemy(&"crab")
	assert_eq(data.ai, EnemyData.AI.CRAB)
	assert_eq(data.loot[0].item, &"raw_crab")


func test_fish_swim_in_water_and_stay_there() -> void:
	_tank(6)
	var fish := w.request_spawn_enemy(_enemy(&"fish"), w.tile_to_world(floor_tile + Vector2i(8, -3)) + Vector2(4, 4))
	var start := fish.global_position
	var far := 0.0
	for i in 6:
		await wait_seconds(0.5)
		far = maxf(far, fish.global_position.distance_to(start))
	assert_true(is_instance_valid(fish))
	assert_gt(far, 4.0, "it swims (it may wander back, so the farthest it got)")
	assert_true(fish._in_water(), "still in the water")
	assert_eq(_enemy(&"fish").loot[0].item, &"raw_fish")


func test_fish_flee_from_you() -> void:
	_tank(6)
	var fish := w.request_spawn_enemy(_enemy(&"fish"), w.tile_to_world(floor_tile + Vector2i(8, -3)) + Vector2(4, 4))
	await wait_physics_frames(3)
	w.teleport_player(fish.global_position + Vector2(-20, 30))
	var before := absf(fish.global_position.x - w.player.global_position.x)
	await wait_seconds(0.6)
	assert_gt(absf(fish.global_position.x - w.player.global_position.x), before, "darted away")


func test_fish_out_of_water_flop() -> void:
	_tank(0)
	var fish := w.request_spawn_enemy(_enemy(&"fish"), w.tile_to_world(floor_tile + Vector2i(8, -4)))
	await wait_seconds(1.0)
	assert_false(fish._in_water())
	assert_lt(fish.global_position.y, w.tile_to_world(floor_tile).y + 1.0, "fell to the floor")


func test_fish_spawn_in_water() -> void:
	_tank(5)
	w.player.invincible = true
	w.teleport_player(w.tile_to_world(floor_tile + Vector2i(160, -20)))
	await wait_physics_frames(30)
	var spot := w.spawner._water_spot(floor_tile.x + 5, floor_tile.y, _enemy(&"fish"))
	assert_ne(spot, Vector2.INF, "found water")
	assert_true(w.voxels.liquid_at(spot + Vector2(0, -3)))


func test_ocean_spawn_table() -> void:
	var table := Registry.get_def(&"spawns", &"ocean") as SpawnTable
	assert_eq(table.biome, &"ocean")
	var seen := {}
	for i in 40:
		seen[table.pick(false, float(i) / 40.0, w).id] = true
	assert_true(seen.has(&"crab") and seen.has(&"fish"))


func test_cooking_crab_and_fish() -> void:
	for pair: Array in [[&"crab_legs", &"raw_crab"], [&"cooked_fish", &"raw_fish"]]:
		var r := Registry.get_def(&"recipes", pair[0]) as RecipeData
		assert_eq(r.station, &"cooking")
		assert_eq(r.inputs[pair[1]], 1)
		assert_gt((ItemData.find(pair[0])).food_value, 0.0)
	assert_eq(ItemData.find(&"raw_crab").food_value, 0.0, "cook it first")


func test_sea_plants_only_by_the_sea() -> void:
	var g := ForestGenerator.new(TileTypes.new(&"tiles"), TileTypes.new(&"walls"), 2048, 1024, 42,
		ForestGenerator.default_settings())
	var o := g.ocean()
	var kinds := {}
	for x in range(roundi(o.x - o.y) - 45, roundi(o.x + o.y) + 45):
		var p := g.sea_plant_at(x)
		kinds[p.x] = true
		if p.x == 2:
			var top := p.z
			while top > 0 and g.water_at(x, top - 1):
				top -= 1
			assert_lte(p.y, p.z - top - 2, "kelp stays under the surface")
		if p.x != 0:
			assert_eq(p.z, g.surface_at(x))
	assert_true(kinds.has(1) and kinds.has(2) and kinds.has(3), "seagrass, kelp and dune grass")
	assert_eq(g.sea_plant_at(g.settings.spawn_x).x, 0, "none at spawn")


func test_slimes_float_at_the_surface() -> void:
	_tank(6)
	var slime := w.request_spawn_enemy(_enemy(&"green_slime"), w.tile_to_world(floor_tile + Vector2i(8, -1)) + Vector2(4, 0))
	await wait_seconds(2.0)
	var surface_y := float((floor_tile.y - 6) * World.TILE)
	var lowest := -INF
	for i in 30:
		await wait_physics_frames(3)
		lowest = maxf(lowest, slime.global_position.y)
	assert_lt(lowest, surface_y + 16.0, "stays up at the surface (it may hop off it), never sinks to the bottom")


func test_critters_have_their_own_cap() -> void:
	_tank(6)
	for i in 5:
		w.request_spawn_enemy(_enemy(&"fish"), w.tile_to_world(floor_tile + Vector2i(2 + i * 2, -3)))
	await wait_physics_frames(2)
	assert_eq(w.critter_count(), 5)
	assert_eq(w.enemy_count(), 0, "fish don't count against the enemy cap")
	var table := Registry.get_def(&"spawns", &"forest_surface") as SpawnTable
	assert_true(table.has_critters(), "fish in the forest (ponds)")
	assert_eq(table.pick(false, 0.5, w, true).id, &"fish")
	assert_ne(table.pick(false, 0.5, w, false).id, &"fish")


func test_you_can_build_against_loose_sand() -> void:
	_tank(0)
	var t := floor_tile + Vector2i(4, -1)
	var code := w.voxels.code_of(&"sand")
	for i in 4:
		w.voxels._set_cell(Vector2i(t.x * 4 + i, t.y * 4 + 3), code)
	w.request_set_block(floor_tile + Vector2i(4, 0), WorldData.AIR)  # nothing under it but sand cells... and stone around
	var above := t + Vector2i.UP + Vector2i.UP
	assert_false(w.item_user._anchored(above + Vector2i.UP, false), "open air two above isn't")
	assert_true(w.item_user._anchored(t + Vector2i.UP, false), "right on top of loose sand is")
	assert_true(w.item_user._anchored(t, false), "a tile of loose sand itself can be topped up")


func test_water_is_drawn_over_you() -> void:
	assert_gt(w.voxels.z_index, w.player.z_index)
	assert_gt(w.voxels.z_index, 2, "over enemies and drops too")


func test_torches_hang_on_tree_trunks() -> void:
	# A pine on flat ground right of spawn.
	var feet := w.world_to_tile(w.player.global_position)
	var g := Vector2i(feet.x + 14, feet.y)
	while w.data.get_block(g.x, g.y) == WorldData.AIR:
		g.y += 1
	w.plants._add(w.wrap_tile(g), PlantLayer.Kind.TREE, 0)
	assert_not_null(w.plants.plant_at(g))
	var torch := w.objects.index_of(&"torch")
	var def := w.objects.def(torch) as ObjectDef
	var spot := g + Vector2i(0, -3)
	if w.data.get_wall(spot.x, spot.y) > 0:
		pending("a wall behind this tree")
		return
	assert_true(w.plants.trunk_at(spot))
	assert_true(w.can_place_object(spot, def), "on the trunk")
	assert_true(w.request_set_object(spot, torch))
	assert_false(w.plants.trunk_at(spot + Vector2i(3, 0)), "not beside it")
	for i in 20:
		w.plants.request_hit_tree(g, 1000.0, float(g.x * World.TILE - 40))
		if w.plants.plant_at(g) == null:
			break
	assert_eq(w.data.get_object(spot.x, spot.y), 0, "the torch came off with the tree")


## Phase 72: your summoned slime leaves critters alone, but dives after an enemy in water.
func test_summons_skip_critters_and_dive_after_enemies() -> void:
	_tank(9)
	# You stand on a ledge beside the tank (summons stay within reach of you).
	for x in range(17, 24):
		w.request_set_block(floor_tile + Vector2i(x, 0), w.blocks.index_of(&"stone"))
	w.teleport_player(w.tile_to_world(floor_tile + Vector2i(20, -1)) + Vector2(4, 0))
	var spell := ItemData.find(ItemData.spell_key(&"summon_slime")) as SpellData
	var fish := w.request_spawn_enemy(_enemy(&"fish"), w.tile_to_world(floor_tile + Vector2i(8, -2)) + Vector2(4, 0))
	assert_false(fish.summon_should_attack(), "a fish minding its own business")
	var mine := w.request_spell_effect(spell, w.tile_to_world(floor_tile + Vector2i(8, -9)), 1.0) as Enemy
	mine.global_position = w.tile_to_world(floor_tile + Vector2i(8, -9))
	assert_false(mine.summon_should_attack(), "not your own summons either")
	await wait_seconds(1.0)
	assert_eq(fish.health, fish.data.max_health, "it left the fish alone")
	var top := mine.global_position.y
	assert_lt(top, w.tile_to_world(floor_tile + Vector2i(0, -6)).y, "floating near the top")
	fish.take_damage(0.01, w.player)  # now it's angry: fair game
	assert_true(fish.summon_should_attack())
	var dived := false
	for i in 240:
		await wait_physics_frames(1)
		if not is_instance_valid(fish) or fish.health < fish.data.max_health - 0.01 or mine.global_position.y > top + 3.0 * World.TILE:
			dived = true
			break
	assert_true(dived, "it swims down after it")


## Phase 86: a floating slime holds steady at the surface (no jitter) between hops.
func test_slimes_bob_steadily() -> void:
	_tank(6)
	var slime := w.request_spawn_enemy(_enemy(&"green_slime"), w.tile_to_world(floor_tile + Vector2i(8, -1)) + Vector2(4, 0))
	slime.data = slime.data.duplicate()
	slime.data.water_hop_wait_min = 100.0  # no hops while we watch
	slime.data.water_hop_wait_max = 100.0
	slime.data.hop_wait_min = 100.0
	slime.data.hop_wait_max = 100.0
	slime.data.aggro_tiles = 0.0
	await wait_seconds(3.0)
	var ys: Array[float] = []
	for i in 40:
		await wait_physics_frames(2)
		ys.append(slime.global_position.y)
	var lo: float = ys.min()
	var hi: float = ys.max()
	assert_lt(hi - lo, 4.0, "bobs gently, not jittering (%.1f px)" % (hi - lo))
	var surface_y := float((floor_tile.y - 6) * World.TILE)
	assert_almost_eq(lo, surface_y + slime.data.size.y * slime.data.float_sink, 4.0, "sits in the surface")


## Phase 86: fish keep off the bottom of deep water.
func test_fish_keep_off_the_bottom() -> void:
	_tank(9)
	var fish := w.request_spawn_enemy(_enemy(&"fish"), w.tile_to_world(floor_tile + Vector2i(8, -2)) + Vector2(4, 4))
	w.teleport_player(w.tile_to_world(floor_tile + Vector2i(-30, -12)))
	var near_bottom := 0
	var samples := 0
	for i in 60:
		await wait_physics_frames(6)
		samples += 1
		if fish.global_position.y > (floor_tile.y - 1) * World.TILE:
			near_bottom += 1
	assert_lt(near_bottom, samples / 3, "mostly off the bottom (%d of %d near it)" % [near_bottom, samples])


## Phase 86: the ocean is a biome again (crabs and fish spawn there); salt water counts
## as water for fish; land creatures don't spawn under water.
func test_ocean_biome_and_salt_water_spots() -> void:
	var g := ForestGenerator.new(TileTypes.new(&"tiles"), TileTypes.new(&"walls"), 2048, 1024, 42,
		ForestGenerator.default_settings())
	assert_eq(g.biome_at(roundi(g.ocean().x)), &"ocean")
	_tank(6)
	for y in range(1, 7):
		for x in 16:
			w.voxels.take_liquid(Rect2i(floor_tile + Vector2i(x, -y), Vector2i.ONE), 16)
			w.voxels.request_fill(floor_tile + Vector2i(x, -y), &"salt_water")
	var found := false
	w.teleport_player(w.tile_to_world(floor_tile + Vector2i(-200, 0)))  # so the spot is off screen
	await wait_physics_frames(2)
	for k in 10:
		if w.spawner._water_spot(floor_tile.x + 8, floor_tile.y - 3, _enemy(&"fish")) != Vector2.INF:
			found = true
	assert_true(found, "fish find salt water")
	var c := w.character
	c.water = 50
	c.water_kind = &"salt_water"
	assert_eq(w.water_for_crafting(w.tile_to_world(floor_tile + Vector2i(100, -40))), 0, "a reservoir of salt water doesn't count for crafting")
