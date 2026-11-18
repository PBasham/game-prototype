extends SceneTree
## Placeholder item art: inventory icons (assets/items/icons/<id>.png, 16x16) and the
## small sprites drawn in hand (assets/items/held/<id>.png). Block icons are cut from
## the terrain textures so they match the world; tools, seeds, wood and the spell are
## drawn here. Patrick replaces these with real art (same file names).
##
##   godot --headless --path . --script res://tools/make_item_art.gd

const ICONS := "res://assets/items/icons"
const HELD := "res://assets/items/held"
const TERRAIN := "res://assets/terrain"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICONS))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HELD))
	# Blocks: a 16x16 cut of the terrain texture as the icon, an 8x8 cut held in hand.
	_block("dirt", _terrain("dirt"))
	_block("stone", _terrain("stone"))
	var ore := _terrain("stone")
	ore.blend_rect(_terrain("ore_copper"), Rect2i(0, 0, 64, 64), Vector2i.ZERO)
	_block("copper_ore", ore)
	_block("wood_planks", _terrain("planks"))
	_save(_platform(), "wood_platform", true)
	_save(_rope(), "rope", true)
	_save(_log(), "wood", true)
	_save(_acorn(), "tree_seed", true)
	_save(_grass_seeds(), "grass_seeds", true)
	# Tools: the icon is also the held sprite (pointing up-right, handle bottom-left).
	_save(_pickaxe(), "copper_pickaxe", false)
	_save(_axe(), "copper_axe", false)
	_orb().save_png(ProjectSettings.globalize_path("%s/mining_spell.png" % ICONS))  # spell icon
	_save(_spellbook(), "basic_spellbook", false)
	_save(_torch_icon(), "torch", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/objects"))
	_rope_strip().save_png(ProjectSettings.globalize_path("res://assets/objects/rope.png"))
	_torch_strip().save_png(ProjectSettings.globalize_path("res://assets/objects/torch.png"))
	_spell_icon("chopping_spell", Color("7ac85a")).save_png(ProjectSettings.globalize_path("%s/chopping_spell.png" % ICONS))
	_spell_icon("fly", Color("cfe8ff")).save_png(ProjectSettings.globalize_path("%s/fly.png" % ICONS))
	_spell_icon("spark", Color("ffe066")).save_png(ProjectSettings.globalize_path("%s/spark.png" % ICONS))
	_phase5_art()
	_sapling().save_png(ProjectSettings.globalize_path("res://assets/decor/sapling.png"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/fx"))
	_cracks().save_png(ProjectSettings.globalize_path("res://assets/fx/cracks.png"))
	print("make_item_art: done")
	quit()


func _terrain(item_name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [TERRAIN, item_name]))
	img.convert(Image.FORMAT_RGBA8)
	return img


## Icon = 16x16 from the texture with a 1 px darker rim; held = 8x8 cut.
func _block(item_id: String, tex: Image) -> void:
	var icon := tex.get_region(Rect2i(8, 8, 16, 16))
	for i in 16:
		for p: Vector2i in [Vector2i(i, 0), Vector2i(i, 15), Vector2i(0, i), Vector2i(15, i)]:
			icon.set_pixelv(p, icon.get_pixelv(p).darkened(0.35))
	icon.save_png(ProjectSettings.globalize_path("%s/%s.png" % [ICONS, item_id]))
	var held := tex.get_region(Rect2i(8, 8, 7, 7))
	held.save_png(ProjectSettings.globalize_path("%s/%s.png" % [HELD, item_id]))


## Saves an icon; `small_held` also writes a half-size held sprite.
func _save(img: Image, item_id: String, small_held: bool) -> void:
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [ICONS, item_id]))
	var held := img.duplicate() as Image
	if small_held:
		held.resize(9, 9, Image.INTERPOLATE_NEAREST)
	held.save_png(ProjectSettings.globalize_path("%s/%s.png" % [HELD, item_id]))


func _canvas() -> Image:
	return Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)


func _line(img: Image, a: Vector2i, b: Vector2i, c: Color, shade: Color = Color.TRANSPARENT) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxf(n, 1)
		var p := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if shade.a > 0.0 and p.x + 1 < 16 and p.y + 1 < 16 and img.get_pixel(p.x + 1, p.y + 1).a == 0.0:
			img.set_pixel(p.x + 1, p.y + 1, shade)
		if p.x >= 0 and p.y >= 0 and p.x < 16 and p.y < 16:
			img.set_pixelv(p, c)


func _pickaxe() -> Image:
	var img := _canvas()
	_line(img, Vector2i(1, 14), Vector2i(11, 4), Color("8a6a44"), Color("5e4630"))
	# Copper head, curved across the top of the handle.
	var head := Color("c87a3e")
	var edge := Color("eaa868")
	for p: Vector2i in [Vector2i(6, 2), Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1), Vector2i(10, 2), Vector2i(11, 3),
			Vector2i(12, 4), Vector2i(13, 5), Vector2i(14, 7), Vector2i(14, 8), Vector2i(5, 3), Vector2i(4, 4)]:
		img.set_pixelv(p, head)
	for p: Vector2i in [Vector2i(8, 2), Vector2i(9, 2), Vector2i(12, 5), Vector2i(13, 6)]:
		img.set_pixelv(p, edge)
	return img


func _axe() -> Image:
	var img := _canvas()
	_line(img, Vector2i(1, 14), Vector2i(11, 4), Color("8a6a44"), Color("5e4630"))
	var head := Color("c87a3e")
	for y in range(1, 7):
		for x in range(10, 15):
			if x - 10 + absi(y - 3) < 5:
				img.set_pixel(x, y, head)
	for y in range(1, 7):
		img.set_pixel(14, y, Color("eaa868"))
	return img


func _orb() -> Image:
	var img := _canvas()
	var c := Vector2(8, 8)
	for y in 16:
		for x in 16:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d < 6.0:
				var k := 1.0 - d / 6.0
				img.set_pixel(x, y, Color(0.35 + 0.5 * k, 0.75 + 0.25 * k, 1.0, 0.35 + 0.65 * k))
	img.set_pixel(6, 5, Color.WHITE)
	img.set_pixel(7, 5, Color("e8f8ff"))
	return img


func _platform() -> Image:
	var img := _canvas()
	for x in range(1, 15):
		for y in range(6, 9):
			img.set_pixel(x, y, Color("8a6a3a") if y < 8 else Color("5e4626"))
	for x: int in [3, 12]:
		for y in range(9, 12):
			img.set_pixel(x, y, Color("5e4626"))
	return img


func _rope() -> Image:
	var img := _canvas()
	for y in range(1, 15):
		img.set_pixel(7 + (y / 2) % 2, y, Color("c8b080"))
		img.set_pixel(8 - (y / 2) % 2, y, Color("9a8456"))
	return img


func _log() -> Image:
	var img := _canvas()
	for y in range(5, 11):
		for x in range(2, 13):
			img.set_pixel(x, y, Color("7a5230") if y % 2 == 0 else Color("6a4626"))
	for y in range(5, 11):
		img.set_pixel(13, y, Color("c89a5c"))
		img.set_pixel(14, y, Color("c89a5c") if y > 5 and y < 10 else Color.TRANSPARENT)
	img.set_pixel(13, 7, Color("8a6236"))
	return img


func _acorn() -> Image:
	var img := _canvas()
	for y in range(6, 13):
		for x in range(5, 11):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 9)) < 3.6:
				img.set_pixel(x, y, Color("a87038"))
	for x in range(4, 12):
		img.set_pixel(x, 6, Color("5e4022"))
		img.set_pixel(x, 5, Color("6e4c2a") if x > 4 and x < 11 else Color.TRANSPARENT)
	img.set_pixel(8, 4, Color("4e3420"))
	img.set_pixel(7, 9, Color("d09858"))
	return img


func _grass_seeds() -> Image:
	var img := _canvas()
	for p: Vector2i in [Vector2i(5, 9), Vector2i(8, 7), Vector2i(10, 10), Vector2i(6, 12), Vector2i(11, 6), Vector2i(4, 6)]:
		img.set_pixelv(p, Color("c8b060"))
		img.set_pixel(p.x + 1, p.y, Color("8a7a40"))
	for p: Vector2i in [Vector2i(7, 3), Vector2i(7, 4), Vector2i(8, 2), Vector2i(6, 4)]:
		img.set_pixelv(p, Color("5aa83a"))
	return img


## A young tree planted from a seed: 9x14, stem at the bottom middle.
func _sapling() -> Image:
	var img := Image.create_empty(9, 14, false, Image.FORMAT_RGBA8)
	for y in range(6, 14):
		img.set_pixel(4, y, Color("6e4c2a"))
	var leaf := Color("3f8a2c")
	var light := Color("5cae3a")
	for p: Vector2i in [Vector2i(4, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(2, 3), Vector2i(3, 3),
			Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4),
			Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
			Vector2i(2, 7), Vector2i(1, 7), Vector2i(6, 8), Vector2i(7, 8)]:
		img.set_pixelv(p, leaf)
	for p: Vector2i in [Vector2i(4, 0), Vector2i(4, 2), Vector2i(3, 3), Vector2i(2, 5), Vector2i(6, 5)]:
		img.set_pixelv(p, light)
	return img


## Block damage overlay: 4 stages of 8x8 cracks side by side (32x8), lighter to heavier.
func _cracks() -> Image:
	var img := Image.create_empty(32, 8, false, Image.FORMAT_RGBA8)
	var c := Color(0.08, 0.06, 0.05, 0.75)
	var hi := Color(1, 1, 1, 0.18)
	var lines: Array = [
		[[3, 3], [4, 4], [5, 4], [5, 5]],
		[[2, 1], [3, 2], [3, 3], [1, 5], [2, 4], [6, 6], [6, 2], [7, 1]],
		[[0, 2], [1, 3], [4, 6], [4, 7], [6, 3], [7, 3], [5, 0]],
		[[1, 0], [0, 6], [1, 6], [2, 7], [7, 5], [7, 6], [3, 0], [6, 7]],
	]
	for stage in 4:
		for upto in stage + 1:
			for p: Array in lines[upto]:
				img.set_pixel(stage * 8 + int(p[0]), int(p[1]), c)
				var hx := stage * 8 + int(p[0]) + 1
				if int(p[0]) + 1 < 8 and img.get_pixel(hx, int(p[1])).a == 0.0:
					img.set_pixel(hx, int(p[1]), hi)
	return img


## The basic spellbook: 11x11, upright, spine on the left, grip at the bottom middle.
func _spellbook() -> Image:
	var img := Image.create_empty(11, 11, false, Image.FORMAT_RGBA8)
	for y in range(1, 10):
		for x in range(1, 10):
			img.set_pixel(x, y, Color("6a3e2a"))
		img.set_pixel(1, y, Color("4a2818"))
		img.set_pixel(9, y, Color("e8e0c8"))  # page edges
	for p: Vector2i in [Vector2i(5, 3), Vector2i(4, 4), Vector2i(6, 4), Vector2i(5, 5), Vector2i(5, 4)]:
		img.set_pixelv(p, Color("7fd4ff"))  # emblem
	return img


## Rope, 4 frames of 8x8: single, top (ties on above), middle, bottom (frayed end).
func _rope_strip() -> Image:
	var img := Image.create_empty(32, 8, false, Image.FORMAT_RGBA8)
	var a := Color("c8b080")
	var b := Color("9a8456")
	for f in 4:
		var y0 := 2 if f == 0 or f == 1 else 0
		var y1 := 6 if f == 0 or f == 3 else 8
		for y in range(y0, y1):
			img.set_pixel(f * 8 + 3 + (y / 2) % 2, y, a)
			img.set_pixel(f * 8 + 4 - (y / 2) % 2, y, b)
		if f == 0 or f == 1:  # knot at the top
			for x in range(2, 6):
				img.set_pixel(f * 8 + x, 1, b)
		if f == 0 or f == 3:  # frayed end
			img.set_pixel(f * 8 + 2, 6, b)
			img.set_pixel(f * 8 + 5, 6, a)
	return img


## Torch, 2 tiles tall: 4 frames of 8x16: standing, leaning on a block to the left,
## to the right, on a back wall (with a bracket).
func _torch_strip() -> Image:
	var img := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
	var stick := Color("7a5230")
	var stick_dark := Color("5e4022")
	var flame: Array[Color] = [Color("fff6c8"), Color("ffd45a"), Color("ff9a30"), Color("e8601c")]
	# frame: [stick bottom, stick top]
	var specs: Array = [[Vector2i(3, 15), Vector2i(3, 6)], [Vector2i(0, 13), Vector2i(3, 6)],
		[Vector2i(7, 13), Vector2i(4, 6)], [Vector2i(3, 13), Vector2i(3, 6)]]
	for f in 4:
		var from: Vector2i = specs[f][0]
		var to: Vector2i = specs[f][1]
		var n := maxi(absi(from.x - to.x), absi(from.y - to.y))
		for i in n + 1:
			var p := Vector2i(roundi(lerpf(from.x, to.x, float(i) / n)), roundi(lerpf(from.y, to.y, float(i) / n)))
			img.set_pixel(f * 8 + p.x, p.y, stick)
			if p.x + 1 < 8 and img.get_pixel(f * 8 + p.x + 1, p.y).a == 0.0:
				img.set_pixel(f * 8 + p.x + 1, p.y, stick_dark)
		if f == 3:  # wall bracket
			for x in range(2, 6):
				img.set_pixel(f * 8 + x, 12, stick_dark)
		# Head wrap and a flame about 5 px tall.
		img.set_pixel(f * 8 + to.x, to.y, Color("4a3020"))
		img.set_pixel(f * 8 + to.x + 1, to.y, Color("4a3020"))
		var fx := f * 8 + to.x
		for p: Array in [[0, -1, 3], [1, -1, 2], [-1, -1, 3], [0, -2, 1], [1, -2, 2], [0, -3, 0], [0, -4, 1],
				[1, -3, 1], [0, -5, 2]]:
			var x: int = fx + int(p[0])
			var y: int = to.y + int(p[1])
			if x >= f * 8 and x < f * 8 + 8 and y >= 0:
				img.set_pixel(x, y, flame[int(p[2])])
	return img


func _torch_icon() -> Image:
	var img := _canvas()
	_line(img, Vector2i(5, 14), Vector2i(9, 6), Color("7a5230"), Color("5e4022"))
	for p: Vector2i in [Vector2i(9, 5), Vector2i(10, 5), Vector2i(9, 4), Vector2i(10, 4), Vector2i(10, 3), Vector2i(9, 2)]:
		img.set_pixelv(p, Color("ffc94a"))
	img.set_pixel(9, 4, Color("fff2a8"))
	img.set_pixel(11, 4, Color("ff8a2a"))
	return img


## Placeholder spell icons: a glowing disc with a simple glyph.
func _spell_icon(kind: String, c: Color) -> Image:
	var img := _canvas()
	for y in 16:
		for x in 16:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			if d < 7.0:
				var k := 1.0 - d / 7.0
				img.set_pixel(x, y, Color(c.r * 0.35, c.g * 0.35, c.b * 0.45, 0.55 + 0.35 * k))
	var g := c.lightened(0.2)
	match kind:
		"chopping_spell":  # a little axe
			_line(img, Vector2i(5, 12), Vector2i(10, 5), Color("c8a070"))
			for p: Vector2i in [Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(11, 5), Vector2i(11, 6), Vector2i(10, 6), Vector2i(12, 5)]:
				img.set_pixelv(p, g)
		"fly":  # a wing
			for i in 7:
				_line(img, Vector2i(4 + i, 11 - i / 2), Vector2i(4 + i, 11), g)
			for p: Vector2i in [Vector2i(11, 7), Vector2i(12, 6), Vector2i(12, 8)]:
				img.set_pixelv(p, g)
		"spark":  # a star
			for p: Vector2i in [Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 11), Vector2i(8, 12),
					Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8), Vector2i(11, 8), Vector2i(12, 8),
					Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7), Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 8),
					Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9), Vector2i(6, 6), Vector2i(10, 10), Vector2i(10, 6), Vector2i(6, 10)]:
				img.set_pixelv(p, g)
			img.set_pixel(8, 8, Color.WHITE)
	return img



# --- Phase 5: early tools, materials, furniture, ground pickups --------------------

func _phase5_art() -> void:
	_save(_stick(), "stick", true)
	_save(_rock(Color("8a8a86"), Color("b4b4ae")), "rock", true)
	_save(_rock(Color("4a4a52"), Color("8a8a9a")), "flint", true)
	_save(_bar(), "copper_bar", true)
	_save(_hand_hammer(), "hand_hammer", true)
	_save(_stone_tool(false), "stone_pickaxe", false)
	_save(_stone_tool(true), "stone_axe", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/objects"))
	var objs := {
		"workbench": _workbench(), "furnace": _furnace(), "copper_anvil": _anvil(),
		"chest": _chest(), "door": _door(),
	}
	_door_open().save_png(ProjectSettings.globalize_path("res://assets/objects/door_open.png"))
	for key: String in objs:
		var img: Image = objs[key]
		img.save_png(ProjectSettings.globalize_path("res://assets/objects/%s.png" % key))
		# Icon: the object (first frame) scaled into 16x16.
		var w := img.get_width()
		var frame := img.get_region(Rect2i(0, 0, w, img.get_height()))
		var icon := _canvas()
		var scale := minf(14.0 / frame.get_width(), 14.0 / frame.get_height())
		var fw := maxi(1, roundi(frame.get_width() * scale))
		var fh := maxi(1, roundi(frame.get_height() * scale))
		frame.resize(fw, fh, Image.INTERPOLATE_NEAREST)
		icon.blit_rect(frame, Rect2i(0, 0, fw, fh), Vector2i((16 - fw) / 2, (16 - fh) / 2))
		icon.save_png(ProjectSettings.globalize_path("%s/%s.png" % [ICONS, key]))
		var held := frame.duplicate() as Image
		held.resize(maxi(1, fw / 2 + 1), maxi(1, fh / 2 + 1), Image.INTERPOLATE_NEAREST)
		held.save_png(ProjectSettings.globalize_path("%s/%s.png" % [HELD, key]))
	for kind: String in ["stick", "rock", "flint"]:
		_pickup(kind).save_png(ProjectSettings.globalize_path("res://assets/decor/pickup_%s.png" % kind))


func _stick() -> Image:
	var img := _canvas()
	_line(img, Vector2i(3, 13), Vector2i(12, 3), Color("8a6a44"), Color("5e4630"))
	img.set_pixel(7, 7, Color("6e5236"))
	img.set_pixel(8, 9, Color("8a6a44"))
	img.set_pixel(9, 10, Color("8a6a44"))
	return img


func _rock(dark: Color, light: Color) -> Image:
	var img := _canvas()
	for y in 16:
		for x in 16:
			var d := Vector2((x - 8.0) / 5.5, (y - 9.5) / 4.0).length()
			if d < 1.0:
				img.set_pixel(x, y, light if (x + y) < 15 and d < 0.7 else dark)
	return img


func _bar() -> Image:
	var img := _canvas()
	for y in range(6, 11):
		for x in range(2 + (10 - y) / 2, 14 - (y - 6) / 2):
			img.set_pixel(x, y, Color("e0904c") if y < 8 else Color("b86a32"))
	return img


func _hand_hammer() -> Image:
	var img := _canvas()
	_line(img, Vector2i(4, 13), Vector2i(10, 7), Color("8a6a44"), Color("5e4630"))
	for y in range(3, 8):
		for x in range(9, 14):
			if (x - 11) * (x - 11) + (y - 5) * (y - 5) <= 5:
				img.set_pixel(x, y, Color("9a9a94") if y < 5 else Color("6e6e6a"))
	img.set_pixel(10, 7, Color("c8b080"))  # binding
	return img


## Stone pickaxe / axe: a flint head lashed to a stick (tool layout like the copper ones).
func _stone_tool(axe: bool) -> Image:
	var img := _canvas()
	_line(img, Vector2i(1, 14), Vector2i(11, 4), Color("8a6a44"), Color("5e4630"))
	var head := Color("5a5a64")
	var edge := Color("9a9aaa")
	if axe:
		for y in range(1, 7):
			for x in range(10, 15):
				if x - 10 + absi(y - 3) < 4:
					img.set_pixel(x, y, head)
		for y in range(2, 6):
			img.set_pixel(14, y, edge)
	else:
		for p: Vector2i in [Vector2i(6, 2), Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2), Vector2i(10, 3), Vector2i(11, 3),
				Vector2i(12, 4), Vector2i(13, 5), Vector2i(13, 6), Vector2i(5, 3)]:
			img.set_pixelv(p, head)
		img.set_pixel(13, 7, edge)
		img.set_pixel(5, 4, edge)
	img.set_pixel(10, 5, Color("c8b080"))  # lashing
	img.set_pixel(11, 4, Color("c8b080"))
	return img


func _fill(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(r, c)


## Wood planks with grain, for furniture.
func _planks(img: Image, r: Rect2i, base: Color, horizontal: bool = true) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var along := x if horizontal else y
			var across := y - r.position.y if horizontal else x - r.position.x
			var c := base
			if across % 4 == 3:
				c = base.darkened(0.25)  # seam between boards
			elif (along * 7 + across * 13) % 11 == 0:
				c = base.darkened(0.1)  # grain
			elif across % 4 == 0:
				c = base.lightened(0.1)
			img.set_pixel(x, y, c)


## Workbench 5x4 tiles (40x32): a thick plank top at hip height, legs with a shelf,
## a saw and a hammer on top, a vise on the end.
func _workbench() -> Image:
	var img := Image.create_empty(40, 32, false, Image.FORMAT_RGBA8)
	var wood := Color("a07a4a")
	var dark := Color("6e5030")
	# Legs and the lower shelf.
	for x: int in [2, 34]:
		_planks(img, Rect2i(x, 12, 4, 20), Color("7a5a36"), false)
	_planks(img, Rect2i(4, 22, 32, 3), Color("8a6840"))
	_fill(img, Rect2i(4, 25, 32, 1), dark)
	_fill(img, Rect2i(8, 19, 6, 3), Color("b4b4ae"))  # a box of nails on the shelf
	_fill(img, Rect2i(8, 19, 6, 1), Color("d4d4ce"))
	# Top.
	_planks(img, Rect2i(0, 8, 40, 4), wood)
	_fill(img, Rect2i(0, 8, 40, 1), wood.lightened(0.2))
	_fill(img, Rect2i(0, 12, 40, 1), dark)
	# Vise on the right end.
	_fill(img, Rect2i(36, 5, 4, 3), Color("6a6a66"))
	_fill(img, Rect2i(37, 12, 2, 4), Color("6a6a66"))
	# Saw.
	_fill(img, Rect2i(6, 6, 12, 2), Color("c4c4be"))
	_fill(img, Rect2i(6, 6, 12, 1), Color("e4e4de"))
	_fill(img, Rect2i(17, 4, 4, 4), Color("8a5a30"))
	# Hammer.
	_fill(img, Rect2i(24, 3, 6, 3), Color("8a8a86"))
	_fill(img, Rect2i(26, 6, 2, 2), Color("7a5a36"))
	_fill(img, Rect2i(24, 3, 6, 1), Color("aaaaa6"))
	return img


## Furnace 4x5 tiles (32x40): a stone kiln with a chimney and a glowing mouth.
func _furnace() -> Image:
	var img := Image.create_empty(32, 40, false, Image.FORMAT_RGBA8)
	# Body: rounded stone, bricks in offset rows.
	for y in range(8, 40):
		for x in 32:
			var d := Vector2((x - 15.5) / 15.5, (y - 39.0) / 31.0).length()
			if d >= 1.0:
				continue
			var row := y / 4
			var brick := (x + (row % 2) * 3) / 6
			var c := Color("7a7a76") if (brick + row) % 2 == 0 else Color("6e6e6a")
			if y % 4 == 0 or (x + (row % 2) * 3) % 6 == 0:
				c = Color("56564f")  # mortar
			c = c.lightened(0.12 * (1.0 - float(x) / 32.0))  # light from the left
			img.set_pixel(x, y, c)
	# Chimney.
	for y in 10:
		for x in range(12, 20):
			img.set_pixel(x, y, Color("5a5a56") if (x + y) % 3 else Color("4a4a46"))
	_fill(img, Rect2i(11, 0, 10, 2), Color("6a6a66"))
	# Mouth.
	_fill(img, Rect2i(8, 24, 16, 14), Color("2a1a14"))
	_fill(img, Rect2i(9, 28, 14, 10), Color("c84a14"))
	_fill(img, Rect2i(10, 31, 12, 7), Color("e8801c"))
	_fill(img, Rect2i(12, 34, 8, 4), Color("ffd060"))
	_fill(img, Rect2i(7, 23, 18, 1), Color("8a8a86"))  # lintel
	_fill(img, Rect2i(6, 38, 20, 2), Color("4a4a46"))  # hearth
	return img


## Copper anvil 3x3 tiles (24x24) on a stump.
func _anvil() -> Image:
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	_planks(img, Rect2i(6, 13, 12, 11), Color("7a5a36"), false)  # stump
	_fill(img, Rect2i(5, 13, 14, 2), Color("a07a4a"))  # cut top
	_fill(img, Rect2i(7, 13, 10, 1), Color("c09a6a"))
	# Anvil.
	_fill(img, Rect2i(2, 4, 19, 4), Color("c87a3e"))
	_fill(img, Rect2i(0, 4, 4, 2), Color("c87a3e"))  # horn
	_fill(img, Rect2i(0, 6, 2, 1), Color("a8602c"))
	_fill(img, Rect2i(2, 4, 19, 1), Color("eaa868"))
	_fill(img, Rect2i(8, 8, 8, 3), Color("a8602c"))
	_fill(img, Rect2i(6, 11, 12, 2), Color("8a4e24"))
	return img


## Chest 3x3 tiles (24x24).
func _chest() -> Image:
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	_planks(img, Rect2i(1, 4, 22, 20), Color("8a5a30"))
	_planks(img, Rect2i(1, 4, 22, 7), Color("a06a38"))  # lid
	_fill(img, Rect2i(1, 4, 22, 1), Color("b88048"))
	_fill(img, Rect2i(1, 11, 22, 1), Color("4a3018"))
	for x: int in [1, 21]:
		_fill(img, Rect2i(x, 4, 2, 20), Color("9a9a96"))  # metal bands
		_fill(img, Rect2i(x, 4, 1, 20), Color("c4c4be"))
	_fill(img, Rect2i(10, 9, 4, 5), Color("c8a040"))  # latch
	_fill(img, Rect2i(11, 11, 2, 2), Color("4a3018"))
	return img


## Door 1x8 tiles (8x64), closed: vertical planks with three rails, iron hinges on the
## left and a brass handle on the right.
func _door() -> Image:
	var img := Image.create_empty(8, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 8:
			img.set_pixel(x, y, _door_pixel(x, y, 1.0))
	return img


## One pixel of the closed door at (x, y); `light` darkens the swung open panel.
func _door_pixel(x: int, y: int, light: float) -> Color:
	var c := Color("9a7448") if (x / 2) % 2 == 0 else Color("8c6a42")
	if (x * 13 + y * 7) % 19 == 0:
		c = c.darkened(0.08)  # grain
	if x == 0 or x == 7:
		c = Color("6e5030")  # frame
	for rail: int in [3, 31, 59]:
		if y >= rail - 1 and y <= rail + 1:
			c = Color("a8845a") if y < rail + 1 else Color("7a5a36")
	if y == 0 or y == 63:
		c = Color("6e5030")
	if (y >= 8 and y <= 10 or y >= 52 and y <= 54) and x <= 3:
		c = Color("5a5a5e") if y != 8 and y != 52 else Color("7a7a7e")  # hinges
	if x >= 5 and x <= 6 and y >= 33 and y <= 35:
		c = Color("e8c860") if y == 33 else Color("b08a3a")  # handle
	return c.darkened(1.0 - light)


## Open door, 2 frames of 16x64 (2x8 tiles): frame 0 swung to the right of the hinge,
## frame 1 mirrored (swung left). The panel is drawn in perspective: shorter at its far
## edge and in shade.
func _door_open() -> Image:
	var img := Image.create_empty(32, 64, false, Image.FORMAT_RGBA8)
	var frame := Image.create_empty(16, 64, false, Image.FORMAT_RGBA8)
	# The hinge side: the frame post the door hangs on.
	for y in 64:
		frame.set_pixel(0, y, Color("6e5030"))
		frame.set_pixel(1, y, Color("8a6a40"))
	# The panel from x 2 to 12, its top and bottom slanting in by 4 px at the far edge.
	var near := 2
	var far := 12
	for x in range(near, far + 1):
		var k := float(x - near) / float(far - near)
		var top := roundi(k * 4.0)
		var bottom := 63 - roundi(k * 4.0)
		var src_x := clampi(roundi(k * 7.0), 0, 7)
		for y in range(top, bottom + 1):
			var v := float(y - top) / float(bottom - top)
			frame.set_pixel(x, y, _door_pixel(src_x, roundi(v * 63.0), 0.82 - k * 0.12))
	# The door's edge (its thickness) at the far side.
	for y in range(4, 60):
		frame.set_pixel(far + 1, y, Color("6e5030"))
	img.blit_rect(frame, Rect2i(0, 0, 16, 64), Vector2i.ZERO)
	frame.flip_x()
	img.blit_rect(frame, Rect2i(0, 0, 16, 64), Vector2i(16, 0))
	return img


## Things lying on the grass, bottom-aligned, sized like the thing itself: a stick
## 12x5, a rock 9x7, a flint shard 7x6.
func _pickup(kind: String) -> Image:
	match kind:
		"stick":
			var img := Image.create_empty(12, 5, false, Image.FORMAT_RGBA8)
			for x in 12:
				var y := 3 - x / 5
				img.set_pixel(x, y, Color("9a7a50"))
				img.set_pixel(x, y + 1, Color("5e4630"))
			img.set_pixel(7, 1, Color("9a7a50"))  # a twig
			img.set_pixel(8, 0, Color("9a7a50"))
			return img
		"rock":
			var img := Image.create_empty(9, 7, false, Image.FORMAT_RGBA8)
			for y in 7:
				for x in 9:
					var d := Vector2((x - 4.0) / 4.5, (y - 6.0) / 6.0).length()
					if d < 1.0:
						var c := Color("8a8a86")
						if y < 3 and x < 6:
							c = Color("b4b4ae")
						elif y >= 5 or x >= 7:
							c = Color("6a6a66")
						img.set_pixel(x, y, c)
			return img
	# Flint: a sharp dark shard.
	var shard := Image.create_empty(7, 6, false, Image.FORMAT_RGBA8)
	var rows := [[3, 4], [2, 4], [2, 5], [1, 5], [1, 6], [0, 6]]
	for y in 6:
		for x in range(rows[y][0], rows[y][1] + 1):
			var c := Color("4a4a56")
			if x == rows[y][0] or y < 2:
				c = Color("8a8aa0")  # glinting edge
			elif y == 5:
				c = Color("34343c")
			shard.set_pixel(x, y, c)
	return shard
