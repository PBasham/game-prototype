extends GutTest
## Spellbooks, conduits, spells and tomes.

const NAME := "test_character_magic"


func before_all() -> void:
	DevMagic._register()


func after_all() -> void:
	var path := SaveManager.character_path(NAME)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_new_character_knows_mining_and_has_a_shortcut() -> void:
	var c := CharacterData.create_dev(NAME)
	assert_true(c.knows(&"mining_spell"))
	assert_true(c.in_book(&"mining_spell"))
	assert_eq(c.inventory.ids[2], &"spell:mining_spell", "hotbar shortcut in slot 3")
	var spell := ItemData.find(&"spell:mining_spell") as SpellData
	assert_not_null(spell)
	assert_eq(c.cast_problem(spell), "")
	assert_eq(c.book().id, CharacterData.DEFAULT_BOOK, "the basic book when the slot is empty")
	assert_eq(c.book_slot_count(), 4)


func test_spells_must_be_in_the_book() -> void:
	var c := CharacterData.create_dev(NAME)
	var spell := ItemData.find(&"spell:mining_spell") as SpellData
	c.put_in_book(0, &"")
	assert_ne(c.cast_problem(spell), "", "not in the book")
	assert_eq(c.cast_problem(spell, true), "", "a tome doesn't need the book")


func test_books_change_slots_and_power() -> void:
	var c := CharacterData.create_dev(NAME)
	assert_eq(c.spell_power(), 1.0)
	c.equip(CharacterData.SLOT_BOOK, &"dev_grimoire")
	assert_eq(c.book_slot_count(), 8)
	assert_almost_eq(c.spell_power(), 1.5, 0.001)
	assert_true(c.in_book(&"mining_spell"), "the loadout carries over")
	c.put_in_book(6, &"mining_spell")
	assert_eq(c.book_loadout()[6], &"mining_spell")
	assert_eq(c.book_loadout()[0], &"", "moved, not copied")
	c.equip(CharacterData.SLOT_BOOK, &"")
	assert_false(c.in_book(&"mining_spell"), "slot 7 doesn't exist in the basic book")


func test_conduit_requirements_and_bonuses() -> void:
	var c := CharacterData.create_dev(NAME)
	DevMagic.add_to(c)
	var wide := ItemData.find(&"spell:dev_wide_beam") as SpellData
	assert_false(c.put_in_book(1, &"dev_wide_beam"), "tier 2: too strong for the Basic Spellbook")
	c.equip(CharacterData.SLOT_BOOK, &"dev_grimoire")
	assert_true(c.put_in_book(5, &"dev_wide_beam"), "the Dev Grimoire holds tier 3")
	assert_string_contains(c.cast_problem(wide), "focus")
	assert_true(CharacterData.fits(CharacterData.SLOT_CONDUIT, ItemData.find(&"dev_focus")))
	assert_false(CharacterData.fits(CharacterData.SLOT_BOOK, ItemData.find(&"dev_focus")))
	c.equip(CharacterData.SLOT_CONDUIT, &"dev_focus")
	assert_eq(c.cast_problem(wide), "")
	assert_almost_eq(c.spell_power(), 1.5 * 1.25, 0.001)
	assert_eq(c.spell_reach_bonus(), 4.0)


func test_magic_saves_without_dev_things() -> void:
	var c := CharacterData.create_dev(NAME)
	c.equip(CharacterData.SLOT_CONDUIT, &"dev_focus")
	c.put_in_book(3, &"mining_spell")
	assert_eq(c.save(), OK)
	var back := CharacterData.load_file(SaveManager.character_path(NAME))
	assert_true(back.knows(&"mining_spell"))
	assert_false(back.knows(&"dev_wide_beam"), "dev spells aren't saved")
	assert_eq(back.book_loadout()[3], &"mining_spell")
	assert_eq(back.equipment[CharacterData.SLOT_CONDUIT], &"", "dev conduit isn't saved")
	assert_eq(back.inventory.ids[2], &"spell:mining_spell", "shortcut saved")


func test_wheel_segments() -> void:
	# Segment 0 is at the top, then clockwise.
	assert_eq(Hud.wheel_index(-PI * 0.5, 4), 0)
	assert_eq(Hud.wheel_index(0.0, 4), 1)
	assert_eq(Hud.wheel_index(PI * 0.5, 4), 2)
	assert_eq(Hud.wheel_index(PI, 4), 3)
	assert_eq(Hud.wheel_index(-PI * 0.5 + 0.3, 4), 0)
