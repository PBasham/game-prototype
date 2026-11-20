extends GutTest
## Spellbooks, conduits, spells and tomes.

const NAME := "test_character_magic"


func before_all() -> void:
	DevMagic._register()


func after_all() -> void:
	var path := SaveManager.character_path(NAME)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_dev_character_knows_mining_and_has_quick_spells() -> void:
	var c := CharacterData.create_dev(NAME)
	assert_true(c.knows(&"mining_spell"))
	assert_eq(c.wheel(&"q").size(), CharacterData.WHEEL_SIZE, "a full Q wheel to try")
	assert_false(c.buff_set().is_empty())
	var spell := ItemData.find(&"spell:mining_spell") as SpellData
	assert_not_null(spell)
	assert_eq(c.cast_problem(spell), "")
	assert_eq(c.book().id, CharacterData.DEFAULT_BOOK, "the basic book when the slot is empty")


func test_known_spells_cast_unknown_ones_dont() -> void:
	var c := CharacterData.create_dev(NAME)
	var spell := ItemData.find(&"spell:mining_spell") as SpellData
	assert_eq(c.cast_problem(spell), "", "known: castable, from anywhere")
	c.known_spells.erase(&"mining_spell")
	assert_ne(c.cast_problem(spell), "", "not known")
	assert_eq(c.cast_problem(spell, true), "", "a tome doesn't need you to know it")


func test_books_power_every_spell() -> void:
	var c := CharacterData.create_dev(NAME)
	assert_eq(c.spell_power(), 1.0)
	c.equip(CharacterData.SLOT_BOOK, &"dev_grimoire")
	assert_almost_eq(c.spell_power(), 1.5, 0.001)
	assert_eq(c.max_spell_tier(), 3)


func test_conduit_requirements_and_bonuses() -> void:
	var c := CharacterData.create_dev(NAME)
	DevMagic.add_to(c)
	var wide := ItemData.find(&"spell:dev_wide_beam") as SpellData
	assert_string_contains(c.cast_problem(wide), "tier", "tier 2: too strong for the Basic Spellbook")
	c.equip(CharacterData.SLOT_BOOK, &"dev_grimoire")
	assert_string_contains(c.cast_problem(wide), "focus", "the Dev Grimoire handles tier 3")
	assert_true(CharacterData.fits(CharacterData.SLOT_CONDUIT, ItemData.find(&"dev_focus")))
	assert_false(CharacterData.fits(CharacterData.SLOT_BOOK, ItemData.find(&"dev_focus")))
	c.equip(CharacterData.SLOT_CONDUIT, &"dev_focus")
	assert_eq(c.cast_problem(wide), "")
	assert_almost_eq(c.spell_power(), 1.5 * 1.25, 0.001)
	assert_eq(c.spell_reach_bonus(), 4.0)


func test_magic_saves_without_dev_things() -> void:
	var c := CharacterData.create_dev(NAME)
	c.equip(CharacterData.SLOT_CONDUIT, &"dev_focus")
	c.set_quick(&"z", &"spark")
	c.toggle_quick_mode(&"z")
	c.wheel_last[&"e"] = &"e_2"
	assert_eq(c.save(), OK)
	var back := CharacterData.load_file(SaveManager.character_path(NAME))
	assert_true(back.knows(&"mining_spell"))
	assert_false(back.knows(&"dev_wide_beam"), "dev spells aren't saved")
	assert_eq(back.quick_spell(&"z"), &"spark")
	assert_true(back.quick_casts(&"z"), "Spark goes in hand by default; flipped to cast")
	assert_eq(back.wheel_last[&"e"], &"e_2")
	assert_eq(back.quick_spell(&"q_0"), c.quick_spell(&"q_0"))
	assert_eq(back.equipment[CharacterData.SLOT_CONDUIT], &"", "dev conduit isn't saved")


func test_wheel_segments() -> void:
	# Segment 0 is at the top, then clockwise.
	assert_eq(Hud.wheel_index(-PI * 0.5, 4), 0)
	assert_eq(Hud.wheel_index(0.0, 4), 1)
	assert_eq(Hud.wheel_index(PI * 0.5, 4), 2)
	assert_eq(Hud.wheel_index(PI, 4), 3)
	assert_eq(Hud.wheel_index(-PI * 0.5 + 0.3, 4), 0)


func test_quick_slots_move_within_their_group() -> void:
	var c := CharacterData.create(NAME)
	c.learn_spell(&"spark")
	c.learn_spell(&"blink")
	c.learn_spell(&"arcane_edge")
	assert_false(c.set_quick(&"q_0", &"fly"), "not known")
	assert_true(c.set_quick(&"q_0", &"spark"))
	assert_true(c.set_quick(&"q_3", &"spark"))
	assert_eq(c.quick_spell(&"q_0"), &"", "moved within the Q wheel")
	assert_true(c.set_quick(&"e_0", &"spark"), "the E wheel can have it too")
	assert_true(c.set_quick(&"z", &"spark"))
	assert_eq(c.wheel(&"q"), [&"q_3"] as Array[StringName])
	assert_false(c.set_quick(&"buff_0", &"spark"), "the buff set is for timed effects on you")
	assert_true(c.set_quick(&"buff_0", &"arcane_edge"))
	assert_eq(c.buff_set(), [&"arcane_edge"] as Array[StringName])


func test_quick_modes_default_by_spell() -> void:
	var c := CharacterData.create(NAME)
	for id: StringName in [&"spark", &"blink", &"mining_spell", &"wisp", &"light_orb", &"arcane_edge"]:
		c.learn_spell(id)
	c.set_quick(&"q_0", &"spark")
	c.set_quick(&"q_1", &"blink")
	c.set_quick(&"q_2", &"mining_spell")
	c.set_quick(&"q_3", &"wisp")
	c.set_quick(&"q_4", &"light_orb")
	c.set_quick(&"buff_0", &"arcane_edge")
	assert_false(c.quick_casts(&"q_0"), "bolts go in hand")
	assert_true(c.quick_casts(&"q_1"), "blink casts right away")
	assert_false(c.quick_casts(&"q_2"), "tools go in hand")
	assert_false(c.quick_casts(&"q_3"), "steered lights go in hand")
	assert_true(c.quick_casts(&"q_4"), "a following light casts right away")
	assert_true(c.quick_casts(&"buff_0"))
	c.toggle_quick_mode(&"q_0")
	assert_true(c.quick_casts(&"q_0"), "flipped")
	c.toggle_quick_mode(&"buff_0")
	assert_true(c.quick_casts(&"buff_0"), "the buff set always casts")


func test_old_saves_move_book_and_shortcuts_to_the_wheels() -> void:
	var c := CharacterData.create(NAME)
	c.learn_spell(&"spark")
	c.learn_spell(&"mining_spell")
	c.learn_spell(&"blink")
	c.inventory.set_slot(2, &"spell:blink", 1)
	c._migrate_spell_slots(["spark", "", "mining_spell"])
	assert_eq(c.quick_spell(&"q_0"), &"spark")
	assert_eq(c.quick_spell(&"q_1"), &"mining_spell")
	assert_eq(c.quick_spell(&"e_0"), &"blink", "the hotbar shortcut")
	assert_true(c.inventory.is_empty(2), "shortcuts are gone from the hotbar")
