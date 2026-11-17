class_name DevHeldItems
extends RefCounted
## Debug builds only: placeholder weapons to test holding, using, aiming and putting
## away, until real weapons exist. They're runtime items (not content, never saved),
## put in the second inventory row when a world starts. H puts the held item away.
##
##   tool (pickaxe-like), two-handed tool, wand, dagger (stab combo), sword (3-hit
##   combo), two-handed sword, spell book, hand crossbow, bow (draws)
##
## Each points at an item type (data/item_types) for how it's held and its attacks.
## Textures are drawn in code as rough placeholders.

## Inventory slot of the first dev item (the second row).
const FIRST_SLOT := 10

## [label, look] in key order (1..9, 0); index 0 is empty hands (null look).
static var _catalog: Array[Array] = []

## Puts the dev items into the second inventory row (slots that are free).
static func add_to(inv: Inventory) -> void:
	var slot := FIRST_SLOT
	for item in items():
		if inv.count_of(item.id) > 0:
			continue
		while slot < Inventory.SIZE and not inv.is_empty(slot):
			slot += 1
		if slot >= Inventory.SIZE:
			return
		inv.set_slot(slot, item.id, 1)


## The dev weapons as runtime ItemData ("dev_sword"...), registered with ItemData.find.
static func items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for e in catalog():
		var look: HeldItemLook = e[1]
		if look == null:
			continue
		var item_id := StringName("dev_" + String(look.id))
		var item := ItemData.find(item_id)
		if item == null:
			item = ItemData.new()
			item.id = item_id
			item.display_name = "%s (dev)" % e[0]
			item.description = "Debug builds only: a placeholder to test animations."
			item.kind = ItemData.Kind.WEAPON
			item.max_stack = 1
			item.icon = look.texture
			item.held = look
			ItemData.register_runtime(item)
		out.append(item)
	return out


## All placeholder items: [short label, HeldItemLook or null].
static func catalog() -> Array[Array]:
	if _catalog.is_empty():
		_catalog = [
			["Empty", null], ["Tool", _tool()], ["2H tool", _big_tool()], ["Wand", _wand()],
			["Dagger", _dagger()], ["Sword", _sword()], ["2H sword", _greatsword()],
			["Book", _book()], ["Crossbow", _crossbow()], ["Bow", _bow()],
		]
	return _catalog


## Just the looks, without empty hands (tests use these).
static func make_items() -> Array[HeldItemLook]:
	var out: Array[HeldItemLook] = []
	for e in catalog():
		if e[1] != null:
			out.append(e[1])
	return out


static func by_name(label: String) -> HeldItemLook:
	for e in catalog():
		if e[0] == label:
			return e[1]
	return null


# --- the items --------------------------------------------------------------------------

static func _tool() -> HeldItemLook:
	var img := _canvas(16)
	_line(img, Vector2i(1, 14), Vector2i(12, 3), Color("8a6a44"), Color("6a4e30"))
	_line(img, Vector2i(10, 0), Vector2i(15, 5), Color("9aa0a8"), Color("6c7278"))
	var it := _look(img, Vector2(3, 12))
	it.id = &"tool"
	it.type = &"tool"
	return it


static func _big_tool() -> HeldItemLook:
	var img := _canvas(22)
	_line(img, Vector2i(1, 20), Vector2i(17, 4), Color("7a5a38"), Color("5a3e24"))
	_line(img, Vector2i(14, 0), Vector2i(21, 7), Color("8a9098"), Color("5e646c"))
	_line(img, Vector2i(15, 2), Vector2i(19, 6), Color("8a9098"), Color("5e646c"))
	var it := _look(img, Vector2(6, 15))
	it.grip2 = Vector2(3, 18)
	it.id = &"big_tool"
	it.type = &"big_tool"
	return it


static func _wand() -> HeldItemLook:
	var img := _canvas(13)
	_line(img, Vector2i(1, 11), Vector2i(9, 3), Color("5a3a28"), Color("3e2618"))
	for p: Vector2i in [Vector2i(10, 1), Vector2i(11, 1), Vector2i(10, 2), Vector2i(11, 2), Vector2i(9, 2), Vector2i(11, 0)]:
		img.set_pixelv(p, Color("7fd4ff"))
	img.set_pixel(10, 1, Color("e8f8ff"))
	var it := _look(img, Vector2(2, 10))
	it.id = &"wand"
	it.type = &"wand"
	return it


static func _dagger() -> HeldItemLook:
	var img := _canvas(11)
	_line(img, Vector2i(4, 6), Vector2i(9, 1), Color("c8ccd2"), Color("eef2f6"))
	_line(img, Vector2i(2, 5), Vector2i(5, 8), Color("b08a3a"))
	_line(img, Vector2i(1, 9), Vector2i(3, 7), Color("6a4a30"))
	var it := _look(img, Vector2(2, 8))
	it.id = &"dagger"
	it.type = &"dagger"
	return it


static func _sword() -> HeldItemLook:
	var img := _canvas(18)
	_line(img, Vector2i(6, 11), Vector2i(16, 1), Color("c8ccd2"), Color("eef2f6"))
	img.set_pixel(17, 0, Color("eef2f6"))
	_line(img, Vector2i(3, 10), Vector2i(7, 14), Color("b08a3a"), Color("8a6a24"))
	_line(img, Vector2i(2, 15), Vector2i(4, 13), Color("6a4a30"))
	img.set_pixel(1, 16, Color("b08a3a"))
	var it := _look(img, Vector2(3, 14))
	it.id = &"sword"
	it.type = &"sword"
	return it


static func _greatsword() -> HeldItemLook:
	var img := _canvas(26)
	_line(img, Vector2i(9, 16), Vector2i(24, 1), Color("bcc0c8"), Color("e8ecf2"))
	_line(img, Vector2i(10, 16), Vector2i(24, 2), Color("9aa0a8"))
	_line(img, Vector2i(5, 14), Vector2i(11, 20), Color("8a6a24"), Color("6a4e1a"))
	_line(img, Vector2i(2, 23), Vector2i(7, 18), Color("5a3e28"), Color("3e2a1a"))
	img.set_pixel(1, 24, Color("8a6a24"))
	var it := _look(img, Vector2(6, 19))
	it.grip2 = Vector2(3, 22)
	it.id = &"greatsword"
	it.type = &"greatsword"
	return it


static func _book() -> HeldItemLook:
	var img := _canvas(11)
	for y in range(1, 10):
		for x in range(1, 10):
			img.set_pixel(x, y, Color("5a3a8a"))
		img.set_pixel(1, y, Color("3a2260"))
		img.set_pixel(9, y, Color("e8e0c8"))  # page edges
	for p: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(5, 3), Vector2i(5, 5)]:
		img.set_pixelv(p, Color("d8b048"))  # emblem
	var it := _look(img, Vector2(5, 9))
	it.id = &"book"
	it.type = &"spell_book"
	return it


static func _crossbow() -> HeldItemLook:
	var img := _canvas(16)
	_line(img, Vector2i(2, 13), Vector2i(12, 3), Color("7a5a38"), Color("5a3e24"))
	_line(img, Vector2i(8, 1), Vector2i(14, 7), Color("4a4a50"))
	_line(img, Vector2i(8, 1), Vector2i(9, 6), Color("d8d0c0"))
	_line(img, Vector2i(14, 7), Vector2i(9, 6), Color("d8d0c0"))
	var it := _look(img, Vector2(4, 11))
	it.id = &"crossbow"
	it.type = &"crossbow"
	return it


static func _bow() -> HeldItemLook:
	var img := _canvas(20)
	var c := Vector2(10, 10)
	var fwd := Vector2(1, -1).normalized()
	var side := Vector2(1, 1).normalized()
	var prev := Vector2i(-1, -1)
	for i in range(-9, 10):
		var t := float(i)
		var p := c + side * t - fwd * (t * t / 20.0)
		var q := Vector2i(roundi(p.x), roundi(p.y))
		if prev.x >= 0:
			_line(img, prev, q, Color("7a5230"), Color("5a3a20"))
		prev = q
	var tip_a := c + side * -9.0 - fwd * (81.0 / 20.0)
	var tip_b := c + side * 9.0 - fwd * (81.0 / 20.0)
	_line(img, Vector2i(roundi(tip_a.x), roundi(tip_a.y)), Vector2i(roundi(tip_b.x), roundi(tip_b.y)), Color("d8d0c0"))
	var it := _look(img, c)
	it.grip2 = (tip_a + tip_b) / 2.0  # middle of the string
	it.id = &"bow"
	it.type = &"bow"
	return it


# --- drawing helpers --------------------------------------------------------------------

static func _canvas(size: int) -> Image:
	return Image.create_empty(size, size, false, Image.FORMAT_RGBA8)


static func _look(img: Image, grip: Vector2) -> HeldItemLook:
	var it := HeldItemLook.new()
	it.texture = ImageTexture.create_from_image(img)
	it.grip = grip
	return it


## A 1 px line; with `shade`, a second line one pixel below-right for thickness.
static func _line(img: Image, a: Vector2i, b: Vector2i, color: Color, shade: Color = Color.TRANSPARENT) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxf(n, 1)
		var p := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if shade.a > 0.0 and p.x + 1 < img.get_width() and p.y + 1 < img.get_height():
			if img.get_pixel(p.x + 1, p.y + 1).a == 0.0:
				img.set_pixel(p.x + 1, p.y + 1, shade)
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			img.set_pixelv(p, color)
