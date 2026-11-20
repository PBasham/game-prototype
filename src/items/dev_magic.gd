class_name DevMagic
extends RefCounted
## Debug builds only: placeholder magic to test books, conduits, spell requirements,
## the spell wheel and tomes. Runtime items and spells, never saved, not content.
##
##   Dev Grimoire     book, 8 slots, spell power x1.5, holds spells up to tier 3
##   Dev Focus        conduit of type "focus", spell power x1.25, +4 reach
##   Dev Wide Beam    spell (tier 2): a wider, weaker beam that needs a "focus" conduit
##   Dev Tome         tome of Dev Wide Beam (no book needed, still needs the focus)
##   Dev Ring         accessory: defense 2, +20 max health, +20% speed, +15% jump,
##                    +25% magic damage (to test equipment stats)
##
## Put in the third inventory row; Dev Wide Beam is added to the known spells.

const FIRST_SLOT := 20


static func add_to(c: CharacterData) -> void:
	_register()
	var inv := c.inventory
	var slot := FIRST_SLOT
	for item_id: StringName in [&"dev_grimoire", &"dev_focus", &"dev_tome", &"dev_ring"]:
		if inv.count_of(item_id) > 0 or c.equipment.values().has(item_id):
			continue
		while slot < inv.size and not inv.is_empty(slot):
			slot += 1
		if slot >= inv.size:
			break
		inv.set_slot(slot, item_id, 1)
	c.learn_spell(&"dev_wide_beam")


static func _register() -> void:
	if ItemData.find(&"dev_grimoire") != null:
		return
	var book := _item(&"dev_grimoire", "Dev Grimoire (dev)", "A test book.", ItemData.Kind.BOOK)
	book.spell_power = 1.5
	book.max_spell_tier = 3
	book.icon = _book_texture(Color("2a5a8a"), Color("f2d27a"))
	book.held = _look(&"dev_grimoire", book.icon)
	ItemData.register_runtime(book)

	var focus := _item(&"dev_focus", "Dev Focus (dev)", "", ItemData.Kind.CONDUIT)
	focus.conduit_type = &"focus"
	focus.spell_power = 1.25
	focus.spell_reach_bonus = 4.0
	focus.icon = _crystal()
	ItemData.register_runtime(focus)

	var wide := SpellData.new()
	wide.id = &"dev_wide_beam"
	wide.display_name = "Dev Wide Beam (dev)"
	wide.description = "A wide, weaker mining beam. Needs a focus conduit."
	wide.kind = ItemData.Kind.SPELL
	wide.max_stack = 1
	wide.beam = true
	wide.mining_damage = 30.0
	wide.mining_area = 3
	wide.mining_area_max = 5
	wide.reach_tiles = 10.0
	wide.requires_conduit = &"focus"
	wide.tier = 2  # the Basic Spellbook can't hold it: the Dev Grimoire can
	wide.icon = _crystal(Color("ff9a5a"))
	ItemData.register_runtime(wide)

	var ring := _item(&"dev_ring", "Dev Ring (dev)", "Accessory to test stats.", ItemData.Kind.ACCESSORY)
	ring.defense = 2
	ring.stats = {&"max_health": 20.0, &"move_speed": 0.2, &"jump": 0.15, &"magic_damage": 0.25}
	ring.icon = _crystal(Color("ffd27a"))
	ItemData.register_runtime(ring)

	var tome := _item(&"dev_tome", "Dev Tome (dev)", "Casts Dev Wide Beam without a spellbook slot.", ItemData.Kind.TOME)
	tome.tome_spell = &"dev_wide_beam"
	tome.spell_power = 1.0
	tome.icon = _book_texture(Color("8a2a2a"), Color("ff9a5a"))
	tome.held = _look(&"dev_tome", tome.icon)
	ItemData.register_runtime(tome)


static func _item(item_id: StringName, label: String, text: String, kind: ItemData.Kind) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = label
	item.description = text
	item.kind = kind
	item.max_stack = 1
	return item


static func _look(look_id: StringName, tex: Texture2D) -> HeldItemLook:
	var look := HeldItemLook.new()
	look.id = look_id
	look.type = &"spell"
	look.texture = tex
	look.grip = Vector2(5, 9)
	return look


static func _book_texture(cover: Color, emblem: Color) -> Texture2D:
	var img := Image.create_empty(11, 11, false, Image.FORMAT_RGBA8)
	for y in range(1, 10):
		for x in range(1, 10):
			img.set_pixel(x, y, cover)
		img.set_pixel(1, y, cover.darkened(0.4))
		img.set_pixel(9, y, Color("e8e0c8"))
	for p: Vector2i in [Vector2i(5, 3), Vector2i(4, 4), Vector2i(6, 4), Vector2i(5, 5), Vector2i(5, 4)]:
		img.set_pixelv(p, emblem)
	return ImageTexture.create_from_image(img)


static func _crystal(c: Color = Color("9a7aff")) -> Texture2D:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(2, 14):
		var w := 4 - absi(y - 7) / 2
		for x in range(8 - w, 8 + w):
			img.set_pixel(x, y, c.lightened(0.3) if x < 8 else c)
	return ImageTexture.create_from_image(img)
