class_name DevHeldItems
extends Node
## Debug builds only: placeholder items to test holding, using, aiming and putting away
## until real items arrive in Phase 4. Number keys pick one; H puts it away; left click
## uses it.
##
##   1  empty hands            6  sword (one-handed melee)
##   2  tool (pickaxe-like)    7  greatsword (two-handed melee)
##   3  two-handed tool        8  spell book (held upright, arm aims to cast)
##   4  wand (aims)            9  hand crossbow (one-handed ranged, aims)
##   5  dagger (at the hip)    0  bow (two-handed ranged, aims)
##
## Textures are drawn in code as rough placeholders, not content.

## [label, look] in key order (1..9, 0); index 0 is empty hands (null look).
static var _catalog: Array[Array] = []

var player: Player


func _process(_delta: float) -> void:
	# Polled (not _unhandled_input) so scripted runs (DevCli --tap) work too.
	var list := catalog()
	for i in list.size():
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			player.hold(list[i][1])


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
	it.hold_angle = -65.0
	return it


static func _big_tool() -> HeldItemLook:
	var img := _canvas(22)
	_line(img, Vector2i(1, 20), Vector2i(17, 4), Color("7a5a38"), Color("5a3e24"))
	_line(img, Vector2i(14, 0), Vector2i(21, 7), Color("8a9098"), Color("5e646c"))
	_line(img, Vector2i(15, 2), Vector2i(19, 6), Color("8a9098"), Color("5e646c"))
	var it := _look(img, Vector2(6, 15))
	it.hold_style = HeldItemLook.HoldStyle.TWO_HAND
	it.grip2 = Vector2(3, 18)
	it.hold_angle = -55.0
	it.use_time = 0.5
	return it


static func _wand() -> HeldItemLook:
	var img := _canvas(13)
	_line(img, Vector2i(1, 11), Vector2i(9, 3), Color("5a3a28"), Color("3e2618"))
	for p: Vector2i in [Vector2i(10, 1), Vector2i(11, 1), Vector2i(10, 2), Vector2i(11, 2), Vector2i(9, 2), Vector2i(11, 0)]:
		img.set_pixelv(p, Color("7fd4ff"))
	img.set_pixel(10, 1, Color("e8f8ff"))
	var it := _look(img, Vector2(2, 10))
	it.aim_when_held = true
	it.use_style = HeldItemLook.UseStyle.AIM
	it.stow_style = HeldItemLook.StowStyle.HIDDEN
	return it


static func _dagger() -> HeldItemLook:
	var img := _canvas(11)
	_line(img, Vector2i(4, 6), Vector2i(9, 1), Color("c8ccd2"), Color("eef2f6"))
	_line(img, Vector2i(2, 5), Vector2i(5, 8), Color("b08a3a"))
	_line(img, Vector2i(1, 9), Vector2i(3, 7), Color("6a4a30"))
	var it := _look(img, Vector2(2, 8))
	it.stow_style = HeldItemLook.StowStyle.HIP
	it.hold_angle = -30.0
	it.use_time = 0.22
	it.swing_from = -100.0
	it.swing_to = 20.0
	return it


static func _sword() -> HeldItemLook:
	var img := _canvas(18)
	_line(img, Vector2i(6, 11), Vector2i(16, 1), Color("c8ccd2"), Color("eef2f6"))
	img.set_pixel(17, 0, Color("eef2f6"))
	_line(img, Vector2i(3, 10), Vector2i(7, 14), Color("b08a3a"), Color("8a6a24"))
	_line(img, Vector2i(2, 15), Vector2i(4, 13), Color("6a4a30"))
	img.set_pixel(1, 16, Color("b08a3a"))
	var it := _look(img, Vector2(3, 14))
	it.stow_style = HeldItemLook.StowStyle.HIP
	it.hold_angle = -70.0
	it.use_time = 0.3
	it.swing_from = -150.0
	it.swing_to = 40.0
	return it


static func _greatsword() -> HeldItemLook:
	var img := _canvas(26)
	_line(img, Vector2i(9, 16), Vector2i(24, 1), Color("bcc0c8"), Color("e8ecf2"))
	_line(img, Vector2i(10, 16), Vector2i(24, 2), Color("9aa0a8"))
	_line(img, Vector2i(5, 14), Vector2i(11, 20), Color("8a6a24"), Color("6a4e1a"))
	_line(img, Vector2i(2, 23), Vector2i(7, 18), Color("5a3e28"), Color("3e2a1a"))
	img.set_pixel(1, 24, Color("8a6a24"))
	var it := _look(img, Vector2(6, 19))
	it.hold_style = HeldItemLook.HoldStyle.TWO_HAND
	it.grip2 = Vector2(3, 22)
	it.hold_angle = -60.0
	it.use_time = 0.55
	it.swing_from = -160.0
	it.swing_to = 50.0
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
	it.hold_angle = -45.0  # texture upright
	it.aim_rotates = false
	it.use_style = HeldItemLook.UseStyle.AIM
	it.stow_style = HeldItemLook.StowStyle.HIP
	return it


static func _crossbow() -> HeldItemLook:
	var img := _canvas(16)
	_line(img, Vector2i(2, 13), Vector2i(12, 3), Color("7a5a38"), Color("5a3e24"))
	_line(img, Vector2i(8, 1), Vector2i(14, 7), Color("4a4a50"))
	_line(img, Vector2i(8, 1), Vector2i(9, 6), Color("d8d0c0"))
	_line(img, Vector2i(14, 7), Vector2i(9, 6), Color("d8d0c0"))
	var it := _look(img, Vector2(4, 11))
	it.aim_when_held = true
	it.use_style = HeldItemLook.UseStyle.AIM
	it.stow_style = HeldItemLook.StowStyle.HIP
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
	it.hold_style = HeldItemLook.HoldStyle.TWO_HAND
	it.aim_when_held = true
	it.grip2 = (tip_a + tip_b) / 2.0  # middle of the string
	it.use_style = HeldItemLook.UseStyle.AIM
	it.stow_style = HeldItemLook.StowStyle.BACK
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
