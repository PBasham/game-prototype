extends GutTest
## Debug builds keep the dev test spells (Mining v2...) and dev items in the save.


func test_dev_spells_and_items_survive_a_reload() -> void:
	if not OS.is_debug_build():
		pass_test("release build")
		return
	var c := CharacterData.create_dev("DevSave")
	assert_true(c.knows(&"dev_mining_v2"))
	c.set_quick(&"z", &"dev_mining_v3")
	var dev_items := c.inventory.ids.filter(func(i: StringName) -> bool: return i != &"" and ItemData.is_runtime(i))
	assert_gt(dev_items.size(), 0, "the dev kit has dev items")
	var spells := c.known_spells.size()
	var items := c.inventory.ids.filter(func(i: StringName) -> bool: return i != &"").size()
	assert_eq(c.save(), OK)
	var path := SaveManager.character_path(c.name)
	var back := CharacterData.load_file(path)
	DirAccess.remove_absolute(path)
	assert_eq(back.known_spells.size(), spells, "every spell, the test ones too")
	assert_true(back.knows(&"dev_mining_v2"))
	assert_eq(back.quick_spell(&"z"), &"dev_mining_v3", "and on its quick slot")
	assert_eq(back.inventory.ids.filter(func(i: StringName) -> bool: return i != &"").size(), items, "every item")
