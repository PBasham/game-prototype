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
	_block("wood_wall", _terrain("planks_wall"))
	_save(_platform(), "wood_platform", true)
	_save(_rope(), "rope", true)
	_save(_log(), "wood", true)
	_save(_acorn(), "tree_seed", true)
	_save(_grass_seeds(), "grass_seeds", true)
	# Tools: the icon is also the held sprite (pointing up-right, handle bottom-left).
	_save(_pickaxe(), "copper_pickaxe", false)
	_save(_axe(), "copper_axe", false)
	_save(_orb(), "mining_spell", false)
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
	for x in [3, 12]:
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
