extends GutTest
## Phase 62: fireflies in the Dark Forest, the Bug Net, the Firefly Lamp.

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


func _firefly(offset: Vector2) -> Enemy:
	return w.request_spawn_enemy(Registry.get_def(&"enemies", &"firefly") as EnemyData, w.player.chest() + offset)


func _hold(item_id: StringName) -> void:
	w.character.inventory.set_slot(0, item_id, 1)
	w.player.select_slot(0)


func test_fireflies_drift_in_the_air_and_glow() -> void:
	var f := _firefly(Vector2(60, -40))
	var start := f.global_position
	await wait_seconds(2.0)
	assert_true(is_instance_valid(f))
	assert_lt(absf(f.global_position.y - start.y), 5.0 * World.TILE, "drifts, doesn't fall")
	assert_lte(f.global_position.distance_to(start), (f.data.drift_tiles + 2.0) * World.TILE, "stays near home")
	assert_true(f.is_in_group(&"light_sources"), "it lights its surroundings")
	assert_true(f.data.is_critter())
	assert_between(f.blink(), 0.0, 1.0)


func test_a_bug_net_catches_one() -> void:
	_hold(&"bug_net")
	var f := _firefly(w.item_user.melee_rect(ItemData.find(&"bug_net")).get_center() - w.player.chest())
	await wait_physics_frames(2)
	var before := w.character.inventory.count_of(&"firefly")
	assert_eq(w.item_user.melee_hit(ItemData.find(&"bug_net")), 1)
	await wait_physics_frames(1)
	assert_false(is_instance_valid(f), "caught")
	assert_eq(w.character.inventory.count_of(&"firefly"), before + 1)


func test_a_sword_just_kills_it() -> void:
	_hold(&"wooden_sword")
	var f := _firefly(w.item_user.melee_rect(ItemData.find(&"wooden_sword")).get_center() - w.player.chest())
	await wait_physics_frames(2)
	var before := w.character.inventory.count_of(&"firefly")
	w.item_user.melee_hit(ItemData.find(&"wooden_sword"))
	await wait_physics_frames(1)
	assert_false(is_instance_valid(f))
	assert_eq(w.character.inventory.count_of(&"firefly"), before, "nothing to keep")


func test_the_lamp() -> void:
	var r := Registry.get_def(&"recipes", &"firefly_lamp") as RecipeData
	assert_eq(r.inputs[&"firefly"], 3)
	assert_eq(r.inputs[&"glass_bottle"], 1)
	var net := Registry.get_def(&"recipes", &"bug_net") as RecipeData
	assert_eq(net.station, &"workbench")
	var lamp := w.objects.def(w.objects.index_of(&"firefly_lamp")) as ObjectDef
	assert_gt(lamp.light_radius, 0.0)
	assert_true(lamp.needs_support)
	var feet := w.world_to_tile(w.player.global_position)
	var spot := Vector2i(feet.x + 4, feet.y - 1)
	assert_true(w.can_place_object(spot, lamp), "on the ground like a torch")
	assert_gt(ItemData.find(&"firefly_lamp").held_light_radius, 0.0, "lights your way held")


func test_they_spawn_in_the_dark_forest_up_in_the_air() -> void:
	var table := Registry.get_def(&"spawns", &"dark_forest_surface") as SpawnTable
	assert_eq(table.pick(false, 0.5, w, true).id, &"firefly")
	w.player.invincible = true
	w.teleport_player(w.player.global_position + Vector2(400, 0))
	await wait_physics_frames(20)
	var data := Registry.get_def(&"enemies", &"firefly") as EnemyData
	var found := false
	for i in 10:
		var at := w.spawner.find_spot(data)
		if at == Vector2.INF:
			continue
		found = true
		assert_false(w.is_solid(w.world_to_tile(at + Vector2(0, -2))), "in the air")
	assert_true(found)
