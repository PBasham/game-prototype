extends GutTest
## Fists: a light push that doesn't pin enemies, punching with the item put away, and
## pickups leaving an empty hand empty. Right click: usable furniture is spotted.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

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


func test_punches_push_but_dont_stagger() -> void:
	var p := w.player
	var e := w.request_spawn_enemy(Registry.get_def(&"enemies", &"green_slime") as EnemyData,
		p.global_position + Vector2(20 * p.facing, 0))
	await wait_physics_frames(2)
	e._wait = 1.5
	e.knock_back(p.chest(), p.fist_item().knockback, p.fist_item().staggers)
	assert_eq(e._wait, 1.5, "a punch doesn't reset its hop")
	assert_ne(e.velocity.x, 0.0, "but pushes it")
	e.knock_back(p.chest(), 12.0, ItemData.find(&"wooden_sword").staggers)
	assert_eq(e._wait, 0.25, "a sword hit staggers")


func test_punch_with_the_item_put_away() -> void:
	var p := w.player
	w.character.inventory.set_slot(0, &"wood", 5)
	p.select_slot(0)
	assert_false(w.item_user.can_use(false), "holding wood: no punch")
	p.toggle_stowed()
	w.item_user.update_target(w.item_user.cursor())
	assert_true(w.item_user.can_use(false), "put away: fists")


func test_pickups_keep_an_empty_hand_empty() -> void:
	var p := w.player
	var inv := w.character.inventory
	for i in inv.size:
		inv.clear(i)
	p.select_slot(0)
	assert_eq(p.pick_up(&"berries", 3), 0)
	assert_true(inv.is_empty(0), "the empty slot in hand stays empty")
	assert_eq(inv.ids[1], &"berries")
	# Full otherwise: then it does go in your hand.
	for i in range(1, inv.size):
		inv.set_slot(i, &"dirt", inv.max_stack(&"dirt"))
	assert_eq(p.pick_up(&"stone", 2), 0)
	assert_eq(inv.ids[0], &"stone")


func test_usable_furniture_under_the_cursor() -> void:
	var feet := w.world_to_tile(w.player.global_position)
	var a := Vector2i(feet.x + 3, feet.y - 1)
	assert_true(w.request_place_object(a, w.objects.index_of(&"chest")))
	assert_true(w.usable_object_at(w.tile_to_world(a) + Vector2(4, 4)))
	assert_false(w.usable_object_at(w.tile_to_world(a + Vector2i(6, 0)) + Vector2(4, 4)))
