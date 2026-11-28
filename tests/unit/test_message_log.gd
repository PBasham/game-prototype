extends GutTest
## Phase 84: the message log (the Catalog's Log tab).

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


func test_keeps_the_last_200_and_saves_them() -> void:
	var c := CharacterData.new()
	c.name = "LogTest"
	for i in 250:
		c.log_message("line %d" % i, "Day 1, 6:%02d" % (i % 60))
	assert_eq(c.messages.size(), CharacterData.LOG_MAX)
	assert_eq(c.messages[0]["text"], "line 50", "the oldest went")
	assert_eq(c.save(), OK)
	var back := CharacterData.load_file(SaveManager.character_path("LogTest"))
	CharacterData.delete("LogTest")
	assert_not_null(back)
	assert_eq(back.messages.size(), 200)
	assert_eq(back.messages[199]["text"], "line 249")
	assert_eq(back.messages[199]["t"], "Day 1, 6:09")


func test_unlocks_are_logged_with_the_time() -> void:
	var c := w.character
	var before := c.messages.size()
	w.hud.show_new_recipe("Glass Bottle")
	assert_eq(c.messages.size(), before + 1)
	assert_eq(c.messages[-1]["text"], "New recipe: Glass Bottle")
	assert_eq(c.messages[-1]["t"], w.clock.label())
	var sp := ItemData.find(ItemData.spell_key(&"floating_torch")) as SpellData
	c.known_spells.erase(sp.id)
	c.learn_spell(sp.id)
	assert_eq(c.messages[-1]["text"], "Learned: %s" % sp.display_name)


func test_log_tab_lists_newest_first_and_searches() -> void:
	var c := w.character
	c.messages.clear()
	c.log_message("New recipe: Glass", "Day 1, 7:00")
	c.log_message("Learned: Floating Torch", "Day 1, 8:00")
	var cat := w.hud._catalog
	cat.tab = 3
	assert_eq(CatalogWindow.TABS[3], "Log")
	assert_eq(cat._log()[0]["text"], "Learned: Floating Torch", "newest first")
	cat.search = "glass"
	assert_eq(cat._log().size(), 1)
	cat.search = ""
	assert_eq(cat.title_right(), "2 messages")
