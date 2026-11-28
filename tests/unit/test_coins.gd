extends GutTest
## Phase 76: coins and the coin pouch.

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


func test_coin_values_and_text() -> void:
	assert_eq(Coins.value_of(&"copper_coin"), 1)
	assert_eq(Coins.value_of(&"silver_coin"), 100)
	assert_eq(Coins.value_of(&"gold_coin"), 10000)
	assert_eq(Coins.value_of(&"platinum_coin"), 1000000)
	assert_eq(Coins.split(3124005), [5, 40, 12, 3] as Array[int])
	assert_eq(Coins.text(3124005), "3p 12g 40s 5c")
	assert_eq(Coins.text(0), "0c")
	assert_eq(Coins.split(250000000)[3], 250, "platinum has no cap")
	for id in Coins.IDS:
		assert_eq(ItemData.find(id).coin_value, Coins.value_of(id))


func test_picked_up_coins_go_in_the_pouch_and_combine() -> void:
	var c := w.character
	c.coins = 0
	assert_eq(w.player.pick_up(&"copper_coin", 99), 0)
	assert_eq(c.inventory.count_of(&"copper_coin"), 0, "not in the inventory")
	w.player.pick_up(&"copper_coin", 1)
	assert_eq(Coins.split(c.coins), [0, 1, 0, 0] as Array[int], "100 copper: a silver")
	assert_eq(c.to_dict()["coins"], 100, "saved")
	# Out onto the mouse and back.
	var hud := w.hud
	hud.set_open(true)
	assert_true(hud._pouch.visible)
	assert_eq(hud.take_coins(1), 1)
	assert_eq(hud.cursor_id, &"silver_coin")
	assert_eq(c.coins, 0)
	hud.deposit_cursor_coins()
	assert_eq(c.coins, 100)
	assert_eq(hud.cursor_count, 0)
	# Fold it down to one line.
	var tall := hud._pouch.size.y
	c.coins_folded = true
	hud._layout()
	assert_lt(hud._pouch.size.y, tall)
	assert_gt(hud._pouch.position.y, hud._inv.position.y + hud._inv.size.y, "under the inventory")
	assert_almost_eq(hud._pouch.position.x + hud._pouch.size.x, hud._inv.position.x + hud._inv.size.x, 0.5, "at its right")


func test_enemies_drop_coins() -> void:
	var green := Catalog.loot_line(Registry.get_def(&"enemies", &"green_slime") as EnemyData, &"copper_coin")
	assert_eq([green.min_count, green.max_count, green.chance], [5, 15, 1.0])
	var blue := Catalog.loot_line(Registry.get_def(&"enemies", &"blue_slime") as EnemyData, &"copper_coin")
	assert_eq([blue.min_count, blue.max_count], [15, 40])
	var spirit := Catalog.loot_line(Registry.get_def(&"enemies", &"forest_spirit") as EnemyData, &"silver_coin")
	assert_not_null(spirit)
	for id: StringName in [&"fish", &"crab", &"firefly"]:
		for l in (Registry.get_def(&"enemies", id) as EnemyData).loot:
			assert_false(Coins.is_coin(l.item), "critters drop no coins")
