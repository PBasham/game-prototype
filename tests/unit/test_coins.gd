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
	assert_eq(hud.take_coins(1), 1)
	assert_eq(hud.cursor_id, &"silver_coin")
	assert_eq(c.coins, 0)
	hud.deposit_cursor_coins()
	assert_eq(c.coins, 100)
	assert_eq(hud.cursor_count, 0)
	# Phase 78: the coin bag opens and closes it (Phase 92: between Catalog and the trash).
	assert_false(hud._pouch.visible, "closed until you click the bag")
	var bag := hud.coin_bag_rect()
	assert_gt(bag.position.x, hud._catalog_button_rect().end.x, "right of Catalog")
	assert_lt(bag.end.x, hud.trash_rect().position.x + 0.5, "left of the trash")
	assert_eq(hud.hit(bag.get_center())[0], Hud.Area.COIN_BAG)
	hud.click_coin_bag()
	assert_true(hud._pouch.visible)
	assert_gt(hud._pouch.position.y, hud._inv.position.y + hud._inv.size.y, "under the inventory")
	assert_almost_eq(hud._pouch.position.x + hud._pouch.size.x, hud._inv.position.x + hud._inv.size.x, 0.5,
		"at its right")
	hud.click_coin_bag()
	assert_false(hud._pouch.visible)
	# From the hotbar (inventory closed): opens both.
	hud.set_open(false)
	assert_gt(hud.coin_bag_rect().position.x, hud._cell(hud._grid_origin(), 9).end.x, "right of the hotbar")
	assert_eq(hud.hit(hud.coin_bag_rect().get_center())[0], Hud.Area.COIN_BAG)
	hud.click_coin_bag()
	assert_true(hud.open and hud._pouch.visible)


func test_enemies_drop_coins() -> void:
	var green := Catalog.loot_line(Registry.get_def(&"enemies", &"green_slime") as EnemyData, &"copper_coin")
	assert_eq([green.min_count, green.max_count, green.chance], [1, 3, 1.0])
	var blue := Catalog.loot_line(Registry.get_def(&"enemies", &"blue_slime") as EnemyData, &"copper_coin")
	assert_eq([blue.min_count, blue.max_count], [2, 5], "a small step up from green")
	var spirit := Catalog.loot_line(Registry.get_def(&"enemies", &"forest_spirit") as EnemyData, &"copper_coin")
	assert_eq([spirit.min_count, spirit.max_count], [10, 20])
	for id: StringName in [&"fish", &"crab", &"firefly"]:
		for l in (Registry.get_def(&"enemies", id) as EnemyData).loot:
			assert_false(Coins.is_coin(l.item), "critters drop no coins")


## Phase 78: "New recipe" shows as a banner at the top middle, then fades out.
func test_new_recipe_banner() -> void:
	var hud := w.hud
	w.character.recipe_discovered.emit("Test Thing")
	assert_true(hud._banner.visible)
	assert_eq(hud._banner.text, "New recipe: Test Thing")
	await wait_seconds(0.2)
	var view := hud._view_size()
	assert_almost_eq(hud._banner.position.x + hud._banner.size.x * 0.5, view.x * 0.5, 1.0, "centered")
	assert_lt(hud._banner.position.y, view.y * 0.3, "near the top")
	hud._update_banner(hud.banner_seconds + hud.banner_fade * 0.5 - 0.2)
	assert_lt(hud._banner.modulate.a, 0.9, "fading")
	hud._update_banner(1.0)
	assert_false(hud._banner.visible, "gone")
	# Several at once share one banner.
	for name in ["A", "B", "C", "D", "E"]:
		w.character.recipe_discovered.emit(name)
	assert_eq(hud._banner.text, "New recipes: A, B and 3 more")


## Phase 78: a recipe already known through another key item isn't announced again, and
## the banner uses the item's name.
func test_revealed_recipes_are_only_new_ones() -> void:
	var c := CharacterData.new()
	c.inventory.add(&"glass", 1)
	var potion := Registry.get_def(&"recipes", &"healing_potion") as RecipeData
	c.seen_items[&"red_cap"] = true
	c.seen_items[&"clay_flask"] = true
	var names := Crafting.revealed_by([&"clay_flask"] as Array[StringName], c)
	assert_false(names.has(ItemData.find(potion.output).display_name), "known already through the Red Cap")
	c.seen_items.erase(&"red_cap")
	names = Crafting.revealed_by([&"glass"] as Array[StringName], c)
	assert_has(names, "Alchemist's Bench", "the item's name")
