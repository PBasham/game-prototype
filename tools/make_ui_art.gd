extends SceneTree
## Writes the placeholder UI art (Scholar theme: leather, wood, brass and parchment) to
## assets/ui/. UiSkin (src/ui/ui_skin.gd) draws every panel, slot and button from these
## as nine-slice images, so real art can replace them file by file (keep the sizes, or
## change the margins in UiSkin).
##
##   godot --headless --path . --script res://tools/make_ui_art.gd

const OUT := "res://assets/ui"

const LEATHER := Color("2b1d15")
const LEATHER_LIGHT := Color("33241a")
const WOOD := Color("6b4a2e")
const WOOD_LIGHT := Color("8a6440")
const WOOD_DARK := Color("452e1c")
const BRASS := Color("c9a24a")
const BRASS_DARK := Color("8a6a2a")
const PARCHMENT := Color("dcc89c")
const PARCHMENT_DARK := Color("b49a6a")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_panel(), "panel")
	_save(_title(), "title")
	_save(_slot(LEATHER.darkened(0.3), false), "slot")
	_save(_slot(LEATHER_LIGHT.darkened(0.05), false), "slot_hot")
	_save(_slot(LEATHER.darkened(0.3), true), "slot_selected")
	_save(_slot(Color("1a1a2a"), false), "slot_magic")
	_save(_button(WOOD, WOOD_LIGHT, WOOD_DARK), "button")
	_save(_button(WOOD_LIGHT, WOOD_LIGHT.lightened(0.2), WOOD), "button_hot")
	_save(_button(WOOD_DARK, WOOD, WOOD_DARK.darkened(0.3)), "button_pressed")
	_save(_button(Color("4a3e34"), Color("5a4e44"), Color("3a3028")), "button_disabled")
	_save(_row(LEATHER_LIGHT), "row_hot")
	_save(_field(), "field")
	_save(_icon(HEART, {"r": Color("d83a3a"), "l": Color("ff8a7a"), "d": Color("8a1a1a")}), "icon_health")
	_save(_icon(DROP, {"r": Color("3a7ae0"), "l": Color("9ac8ff"), "d": Color("1a3a8a")}), "icon_mana")
	_save(_icon(FOOD, {"r": Color("c8803a"), "l": Color("f0b070"), "d": Color("7a4a1a"), "b": Color("e8e0d0")}), "icon_hunger")
	print("make_ui_art: wrote %s" % OUT)
	quit()


## 8x8 status icons: r = main color, l = light, d = dark, b = bone.
const HEART := [
	".rr..rr.",
	"rllrrrrd",
	"rlrrrrrd",
	"rrrrrrrd",
	".rrrrrd.",
	"..rrrd..",
	"...rd...",
	"........",
]
const DROP := [
	"...l....",
	"...rr...",
	"..rlrr..",
	".rlrrrr.",
	".rlrrrd.",
	".rrrrrd.",
	"..rrdd..",
	"........",
]
const FOOD := [
	"...rrr..",
	"..rllrr.",
	"..rlrrrd",
	"..rrrrrd",
	"...rrdd.",
	"..bb....",
	".bbb....",
	"bb.b....",
]


func _icon(rows: Array, colors: Dictionary) -> Image:
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		var row: String = rows[y]
		for x in 8:
			var k := row[x]
			if colors.has(k):
				img.set_pixel(x, y, colors[k])
	return img


func _save(img: Image, file_name: String) -> void:
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, file_name]))


## Panel 32x32, nine-slice margins 8: a wood frame with a brass inner line and brass
## corner studs around dark leather.
func _panel() -> Image:
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var edge := mini(mini(x, y), mini(31 - x, 31 - y))
			var c: Color
			if edge < 3:
				c = WOOD
				if edge == 0:
					c = WOOD_DARK
				elif x <= 1 or y <= 1:
					c = WOOD_LIGHT  # light from the top left
				elif x >= 30 or y >= 30:
					c = WOOD_DARK
			elif edge == 3:
				c = BRASS_DARK
			else:
				# Leather with a faint grain.
				c = LEATHER if (x * 3 + y * 5) % 7 != 0 else LEATHER_LIGHT
			img.set_pixel(x, y, c)
	for p: Vector2i in [Vector2i(1, 1), Vector2i(29, 1), Vector2i(1, 29), Vector2i(29, 29)]:
		img.fill_rect(Rect2i(p, Vector2i(2, 2)), BRASS)
		img.set_pixel(p.x, p.y, BRASS.lightened(0.3))
	return img


## Title strip 24x14, margins 6: parchment with darker, slightly ragged ends.
func _title() -> Image:
	var img := Image.create_empty(24, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 24:
			var c := PARCHMENT
			if y == 0 or y == 13 or x == 0 or x == 23:
				c = PARCHMENT_DARK
			elif y == 1 or (x * 7 + y * 3) % 13 == 0:
				c = PARCHMENT.lightened(0.08)
			elif y == 12:
				c = PARCHMENT.darkened(0.08)
			img.set_pixel(x, y, c)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(23, 0), Vector2i(0, 13), Vector2i(23, 13)]:
		img.set_pixel(p.x, p.y, Color.TRANSPARENT)
	return img


## Slot 20x20, margins 4: an inset well (dark top left, light bottom right). Selected:
## a brass frame.
func _slot(body: Color, selected: bool) -> Image:
	var img := Image.create_empty(20, 20, false, Image.FORMAT_RGBA8)
	for y in 20:
		for x in 20:
			var c := body
			if x == 0 or y == 0:
				c = body.darkened(0.45)
			elif x == 19 or y == 19:
				c = body.lightened(0.18)
			elif x == 1 or y == 1:
				c = body.darkened(0.2)
			if selected and (x <= 1 or y <= 1 or x >= 18 or y >= 18):
				c = BRASS if (x + y) % 2 == 0 or x == 0 or y == 0 or x == 19 or y == 19 else BRASS.lightened(0.25)
			img.set_pixel(x, y, c)
	return img


## Button 24x16, margins 5: a wood plank with a lit top edge and brass pins.
func _button(base: Color, light: Color, dark: Color) -> Image:
	var img := Image.create_empty(24, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 24:
			var c := base
			if y == 0 or x == 0:
				c = light
			elif y == 15 or x == 23:
				c = dark
			elif y == 14:
				c = base.darkened(0.12)
			elif (x * 5 + y * 11) % 17 == 0:
				c = base.darkened(0.08)
			img.set_pixel(x, y, c)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(23, 0), Vector2i(0, 15), Vector2i(23, 15)]:
		img.set_pixel(p.x, p.y, Color.TRANSPARENT)
	img.set_pixel(2, 2, BRASS)
	img.set_pixel(21, 2, BRASS)
	return img


## List row highlight 12x12, margins 3.
func _row(base: Color) -> Image:
	var img := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(base)
	img.fill_rect(Rect2i(0, 0, 12, 1), base.lightened(0.15))
	img.fill_rect(Rect2i(0, 11, 12, 1), base.darkened(0.3))
	return img


## Text field 16x16, margins 4: parchment well.
func _field() -> Image:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c := Color("1e140e")
			if x == 0 or y == 0:
				c = Color("120b07")
			elif x == 15 or y == 15:
				c = WOOD_DARK
			img.set_pixel(x, y, c)
	return img
