extends SceneTree
## Placeholder armor overlays for the paper doll (assets/armor/<item>_<part>.png): each
## is laid out like one row of the parts sheet (one 44x64 cell per frame) and takes
## its shape from the body part's own pixels, so it follows every frame. Only the shape
## is used: the plate is solid copper with its own shading (a highlight along the top,
## darker sides and bottom, an optional seam), nothing from the clothes underneath. Patrick replaces these with hand-drawn overlays (same layout,
## see docs/character-art.md, "Hair, helmets, armor").
##
##   godot --headless --path . --script res://tools/make_armor_art.gd
##
## Run make_items afterwards only if new files were added (the items point at them).

const SHEET := "res://assets/sprites/scholar"
const OUT := "res://assets/armor"

## Copper tones, dark to light.
const COPPER: Array[Color] = [Color("4e200e"), Color("8a3c1c"), Color("b05a2a"), Color("de8448")]

var _img: Image
var _frame := Vector2i(44, 64)
var _frames := 0
var _rows: Dictionary[String, int] = {}


func _init() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHEET + ".json"))
	_frame = Vector2i(int(meta.frame_size[0]), int(meta.frame_size[1]))
	_frames = (meta.frames as Array).size()
	for p: Dictionary in meta.parts:
		_rows[String(p.name)] = int(p.row)
	_img = Image.load_from_file(ProjectSettings.globalize_path(SHEET + "_parts.png"))
	_img.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# [item, part, top fraction covered (0..1 of the part's height in that frame), rim,
	#  seam (fraction down the piece for a darker line, -1 = none)]
	# The helmet stops above where the eyes would be (about 40% down the head).
	var pieces: Array[Array] = [
		["copper_helmet", "Head", 0.38, true, -1.0],
		["copper_chestplate", "Torso", 0.42, false, 0.62],
		["copper_chestplate", "Front Arm Upper", 0.5, false, -1.0],
		["copper_chestplate", "Back Arm Upper", 0.5, false, -1.0],
		["copper_greaves", "Front Leg Upper", 1.0, false, -1.0],
		["copper_greaves", "Back Leg Upper", 1.0, false, -1.0],
		["copper_greaves", "Front Leg Lower", 0.7, false, 0.45],
		["copper_greaves", "Back Leg Lower", 0.7, false, 0.45],
	]
	for p: Array in pieces:
		var strip := _overlay(String(p[1]), float(p[2]), bool(p[3]), float(p[4]))
		var path := "%s/%s_%s.png" % [OUT, p[0], file_part(String(p[1]))]
		strip.save_png(ProjectSettings.globalize_path(path))
		print("make_armor_art: wrote %s" % path)
	quit()


static func file_part(part: String) -> String:
	return part.to_lower().replace(" ", "_")


## One overlay strip for a part: its shape in the top `cover` of each frame, as a solid
## copper plate. `rim` grows the shape by a pixel to the sides and top (a helmet sits
## on the head). `seam` draws a darker line that far down the piece (-1 = none).
func _overlay(part: String, cover: float, rim: bool, seam: float) -> Image:
	var out := Image.create_empty(_frame.x * _frames, _frame.y, false, Image.FORMAT_RGBA8)
	if not _rows.has(part):
		push_warning("make_armor_art: no part %s" % part)
		return out
	var row: int = _rows[part]
	for f in _frames:
		var cell := Rect2i(f * _frame.x, row * _frame.y, _frame.x, _frame.y)
		var src := _img.get_region(cell)
		var used := src.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var limit := used.position.y + maxi(1, int(ceil(used.size.y * cover)))
		var mask: Dictionary[Vector2i, bool] = {}
		for y in range(used.position.y, limit):
			for x in range(used.position.x, used.end.x):
				if src.get_pixel(x, y).a > 0.5:
					mask[Vector2i(x, y)] = true
		if rim:
			var grown: Dictionary[Vector2i, bool] = mask.duplicate()
			for p: Vector2i in mask:
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
					var q := p + d
					if q.x >= 0 and q.y >= 0 and q.x < _frame.x:
						grown[q] = true
			mask = grown
		if mask.is_empty():
			continue
		var top := _frame.y
		var bottom := 0
		for p: Vector2i in mask:
			top = mini(top, p.y)
			bottom = maxi(bottom, p.y)
		var height := maxf(bottom - top, 1.0)
		var seam_y := top + int(round(seam * height)) if seam >= 0.0 else -1
		for p: Vector2i in mask:
			var k := (p.y - top) / height  # 0 at the top, 1 at the bottom
			var i := 2 if k < 0.45 else 1  # lit upper half, shaded lower half
			if p.y == seam_y:
				i = 0
			var left := not mask.has(p + Vector2i.LEFT)
			var right := not mask.has(p + Vector2i.RIGHT)
			if not mask.has(p + Vector2i.DOWN) or right:
				i = 0  # bottom edge and the side away from the light
			elif left:
				i = maxi(i - 1, 0)
			if not mask.has(p + Vector2i.UP):
				i = 3  # highlight along the top
			out.set_pixel(f * _frame.x + p.x, p.y, COPPER[i])
	return out
