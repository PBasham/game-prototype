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
##   Mining v2 to v8, Chopping (echo, comet)  the gathering spells with other phantom
##                    swings (speed, size, style), to compare with the real ones
##
## Put in the third inventory row; Dev Wide Beam and the style test spells are added
## to the known spells.

## Test spells for the phantom tools: the real spell with another swing, to compare
## with it (Mining itself stays as it is). [id, base, label, style, swing seconds,
## impact, tuning].
const STYLE_SPELLS: Array = [
	[&"dev_mining_v2", &"mining_spell", "Mining v2 (quick arc)", 0, 0.2, 0.7,
		{&"size_mult": 1.3, &"wind_up": 1.6, &"appear": 0.15, &"strike_from": 0.45}],
	[&"dev_mining_v3", &"mining_spell", "Mining v3 (heavy arc)", 0, 0.5, 0.85,
		{&"size_mult": 1.9, &"wind_up": 2.8, &"appear": 0.25, &"strike_from": 0.65, &"streak_alpha": 0.9}],
	[&"dev_mining_v4", &"mining_spell", "Mining v4 (echo)", 1, 0.3, 0.8, {}],
	[&"dev_mining_v5", &"mining_spell", "Mining v5 (rapid echo)", 1, 0.18, 0.75,
		{&"size_mult": 1.2, &"wind_up": 1.3, &"appear": 0.12, &"strike_from": 0.4}],
	[&"dev_mining_v6", &"mining_spell", "Mining v6 (comet)", 2, 0.3, 0.8, {}],
	[&"dev_mining_v7", &"mining_spell", "Mining v7 (slow comet)", 2, 0.45, 0.85,
		{&"size_mult": 1.6, &"comet_height": 6.0, &"glow_alpha": 0.75}],
	[&"dev_mining_v8", &"mining_spell", "Mining v8 (flick)", 0, 0.24, 0.6,
		{&"size_mult": 1.1, &"wind_up": 3.0, &"appear": 0.1, &"strike_from": 0.3, &"streak_alpha": 1.0}],
	[&"dev_chopping_echo", &"chopping_spell", "Chopping (echo, dev)", 1, 0.3, 0.8, {}],
	[&"dev_chopping_comet", &"chopping_spell", "Chopping (comet, dev)", 2, 0.3, 0.8, {}],
]

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
	for e: Array in STYLE_SPELLS:
		c.learn_spell(e[0])


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

	for e: Array in STYLE_SPELLS:
		var base := Registry.get_def(&"spells", e[1]) as SpellData
		if base == null:
			continue
		var s := base.duplicate() as SpellData
		s.id = e[0]
		s.display_name = e[2]
		s.phantom_style = e[3]
		s.phantom_swing_time = e[4]
		s.phantom_impact = e[5]
		# Its own dictionary: duplicate() shares the base spell's, and Mining must stay as it is.
		var tuning: Dictionary[StringName, float] = {}
		tuning.assign(e[6])
		s.phantom_tuning = tuning
		# As strong as the dev kit's fully empowered Mining and Chopping.
		s.reach_tiles += 6.0
		s.mining_power += 20
		s.mining_area_max += 2 if s.mining_damage > 0.0 else 0
		s.gather_rank = 2
		ItemData.register_runtime(s)

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
