extends GutTest
## Items, inventory and the character file.

const CHAR_PATH_NAME := "test_character_items"


func after_all() -> void:
	var path := SaveManager.character_path(CHAR_PATH_NAME)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_every_item_is_valid_and_findable() -> void:
	var all := Registry.get_all(&"items")
	assert_gt(all.size(), 10, "items loaded")
	for d in all:
		var item := d as ItemData
		assert_not_null(item, "%s is ItemData" % d.id)
		assert_eq(item.validate(), PackedStringArray(), "%s valid" % item.id)
		assert_eq(ItemData.find(item.id), item)
		if item.held:
			assert_not_null(item.held.item_type(), "%s has an item type" % item.id)
	for e: Array in CharacterData.DEV_KIT:
		assert_not_null(ItemData.find(e[0]), "dev kit item %s exists" % e[0])


func test_tiles_drop_items_that_exist() -> void:
	for d in Registry.get_all(&"tiles"):
		var def := d as TileDef
		var drop := def.drop_item if def.drop_item != &"" else def.id
		assert_not_null(ItemData.find(drop), "%s drops %s" % [def.id, drop])


func test_inventory_stacks_and_fills_hotbar_first() -> void:
	var inv := Inventory.new()
	var full := Inventory.max_stack(&"dirt")  # blocks: 9999
	assert_eq(inv.add(&"dirt", full + 501), 0)
	assert_eq(inv.counts[0], full)
	assert_eq(inv.counts[1], 501)
	assert_eq(inv.add(&"copper_dagger", 2), 0)
	assert_eq(inv.ids[2], &"copper_dagger")
	assert_eq(inv.counts[3], 1, "weapons don't stack")
	assert_eq(inv.add(&"dirt", 10), 0)
	assert_eq(inv.counts[1], 511, "tops up the existing stack")
	assert_eq(inv.count_of(&"dirt"), full + 511)
	assert_eq(inv.take(1, 600), 511)
	assert_true(inv.is_empty(1))


func test_inventory_full() -> void:
	var inv := Inventory.new()
	for i in inv.size:
		inv.set_slot(i, &"copper_sword", 1)
	assert_eq(inv.room_for(&"dirt"), 0)
	assert_eq(inv.add(&"dirt", 5), 5, "nothing fits")


func test_character_save_and_load() -> void:
	var c := CharacterData.create_dev(CHAR_PATH_NAME)
	assert_eq(c.inventory.ids[0], &"copper_dagger", "starting dagger")
	c.inventory.set_slot(30, &"stone", 77)
	assert_true(ItemData.is_runtime(c.inventory.ids[DevHeldItems.FIRST_SLOT]), "dev items in row 2")
	assert_eq(c.save(), OK)
	var back := CharacterData.load_file(SaveManager.character_path(CHAR_PATH_NAME))
	assert_not_null(back)
	assert_eq(back.inventory.ids[30], &"stone")
	assert_eq(back.inventory.counts[30], 77)
	assert_eq(back.inventory.ids[DevHeldItems.FIRST_SLOT], c.inventory.ids[DevHeldItems.FIRST_SLOT],
		"dev items are kept in debug builds")
	assert_eq(back.inventory.count_of(&"wood"), c.inventory.count_of(&"wood"))


func test_new_characters_start_with_the_gathering_spells_and_a_dagger() -> void:
	var c := CharacterData.create("nobody")
	assert_eq(c.inventory.ids[0], &"copper_dagger", "first hotbar slot")
	c.inventory.clear(0)
	assert_true(c.inventory.is_all_empty(), "nothing else")
	assert_eq(c.known_spells, CharacterData.STARTING_SPELLS, "only the gathering spells (they lost the rest)")
