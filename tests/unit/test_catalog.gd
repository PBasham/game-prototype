extends GutTest
## Phase 23: the Catalog (what's found, recipes making and using an item, the window).

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World


func after_each() -> void:
	if w:
		w.queue_free()
		await wait_physics_frames(2)
		w = null
	Game.world_info = null


func _round_trip(c: CharacterData) -> CharacterData:
	c.name = "CatalogTest"
	assert_eq(c.save(), OK)
	var path := SaveManager.character_path(c.name)
	var back := CharacterData.load_file(path)
	DirAccess.remove_absolute(path)
	return back


func test_the_catalog_is_a_panel_not_an_item() -> void:
	assert_null(ItemData.find(&"catalog"), "no book to carry")
	assert_eq(CharacterData.create("Test").inventory.count_of(&"catalog"), 0)


func test_found_items_enemies_and_drops_are_saved() -> void:
	var c := CharacterData.new()
	assert_false(Catalog.item_found(c, &"slime"))
	c.inventory.add(&"slime", 1)
	assert_true(Catalog.item_found(c, &"slime"))
	assert_false(Catalog.enemy_found(c, &"green_slime"))
	c.note_kill(&"green_slime", [&"slime"])
	assert_true(Catalog.enemy_found(c, &"green_slime"))
	var drops := Catalog.drops_of(c, Registry.get_def(&"enemies", &"green_slime") as EnemyData)
	var seen := drops.filter(func(p: Array) -> bool: return p[1]).map(func(p: Array) -> StringName: return (p[0] as ItemData).id)
	assert_eq(seen, [&"slime"], "only the drops you've seen")
	assert_gt(drops.size(), 1, "the others are listed, hidden")
	assert_eq(Catalog.dropped_by(c, &"slime").size(), 1)
	var back := _round_trip(c)
	assert_eq(int(back.slain[&"green_slime"]), 1)
	assert_true(back.seen_drops[&"green_slime"].has(&"slime"))
	var p := Catalog.enemy_progress(back)
	assert_eq(p.x, 1)
	assert_eq(p.y, Registry.get_all(&"enemies").size())


func test_recipes_making_and_using_an_item_and_which_are_known() -> void:
	var c := CharacterData.new()
	var using := Catalog.recipes_using(&"slime").map(func(r: RecipeData) -> StringName: return r.id)
	assert_has(using, &"torch_from_slime")
	var making := Catalog.recipes_making(&"stone_bricks")
	assert_eq(making.size(), 1)
	assert_eq(Catalog.station_name(making[0].station), "Furnace")
	assert_eq(Catalog.station_name(&""), "By hand")
	var pendant := Registry.get_def(&"recipes", &"forest_spirit_pendant") as RecipeData
	assert_false(Catalog.recipe_known(c, pendant), "hidden until a core turns up")
	c.inventory.add(&"spirit_core", 1)
	assert_true(Catalog.recipe_known(c, pendant))


func test_enemy_kills_fill_the_catalog_and_j_opens_it() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	w.spawner.peaceful = true
	var slime := Registry.get_def(&"enemies", &"green_slime") as EnemyData
	var e := w.request_spawn_enemy(slime, w.player.global_position + Vector2(40, 0))
	e.kill()
	assert_eq(int(w.character.slain.get(&"green_slime", 0)), 1, "slain: on its page")
	assert_false(w.hud.catalog_open)
	Input.action_press("catalog")
	await wait_process_frames(2)
	Input.action_release("catalog")
	assert_true(w.hud.catalog_open, "J opens it")
	w.hud.toggle_catalog()
	w.hud.set_open(true)
	var b: Rect2 = w.hud._catalog_button_rect()
	assert_eq(w.hud.hit(b.get_center())[0], Hud.Area.CATALOG_BUTTON, "a button in the inventory")
	assert_false(b.intersects(w.hud.trash_rect()), "beside the trash")
	w.hud.show_catalog_recipes(ItemData.find(&"slime"))
	assert_eq(w.hud._catalog.tab, 2)
	assert_gt(w.hud._catalog._recipes().size(), 0)


## Phase 68: drop chances as text, and links between an item's "Dropped by" and the
## enemy's page (and back from its drops).
func test_drop_chances_and_links() -> void:
	assert_eq(Catalog.chance_text(1.0), "100%")
	assert_eq(Catalog.chance_text(0.025), "2.5%")
	assert_eq(Catalog.chance_text(0.01), "1%")
	assert_eq(Catalog.chance_text(0.0025), "0.25%")
	var slime := Registry.get_def(&"enemies", &"green_slime") as EnemyData
	assert_eq(Catalog.loot_text(Catalog.loot_line(slime, &"page_summon_slime")), "1%")
	assert_eq(Catalog.loot_text(Catalog.loot_line(slime, &"slime")), "1-2, 100%")
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	var c := w.character
	c.seen_items[&"page_summon_slime"] = true
	c.seen_drops[&"green_slime"] = {&"page_summon_slime": true}
	c.slain[&"green_slime"] = 1
	w.hud.toggle_catalog()
	var cat := w.hud._catalog
	cat.follow(ItemData.find(&"page_summon_slime"))
	cat.queue_redraw()
	await wait_process_frames(2)
	assert_eq(cat._links.size(), 1, "Green Slime is a link on the page's Dropped by")
	cat.follow(cat._links[0][1])
	assert_eq(cat.tab, 1)
	assert_eq(cat.picked_enemy, slime, "it opens the slime's page")
	cat.queue_redraw()
	await wait_process_frames(2)
	assert_eq(cat._links.size(), 1, "only the seen drop links back")
	cat.follow(cat._links[0][1])
	assert_eq(cat.picked_item.id, &"page_summon_slime")


## Phase 74: the Creatures tab: enemies first, then the passive ones (critters).
func test_creatures_tab_lists_passive_ones_last() -> void:
	var list := Catalog.all_enemies()
	var seen_passive := false
	for e in list:
		if e.is_critter():
			seen_passive = true
		else:
			assert_false(seen_passive, "%s (hostile) comes before the passive ones" % e.display_name)
	var ids := list.map(func(e: EnemyData) -> StringName: return e.id)
	for id: StringName in [&"fish", &"crab", &"firefly"]:
		assert_has(ids, id)
		assert_true((Registry.get_def(&"enemies", id) as EnemyData).is_critter(), "%s is passive" % id)
	assert_eq(CatalogWindow.TABS[1], "Creatures")
