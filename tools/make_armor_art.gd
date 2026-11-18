extends SceneTree
## Placeholder armor overlays for the paper doll (assets/armor/<item>_<part>.png): each
## is laid out like one row of the parts sheet (one 44x64 cell per frame) and is cut
## from the body part's own pixels, so it follows every frame. Shaded in copper from
## the art's brightness. Patrick replaces these with hand-drawn overlays (same layout,
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
	# [item, part, top fraction covered (0..1 of the part's height in that frame), rim]
	var pieces: Array[Array] = [
		["copper_helmet", "Head", 0.55, true],
		["copper_chestplate", "Torso", 0.42, false],
		["copper_chestplate", "Front Arm Upper", 0.5, false],
		["copper_chestplate", "Back Arm Upper", 0.5, false],
		["copper_greaves", "Front Leg Upper", 1.0, false],
		["copper_greaves", "Back Leg Upper", 1.0, false],
		["copper_greaves", "Front Leg Lower", 0.7, false],
		["copper_greaves", "Back Leg Lower", 0.7, false],
	]
	for p: Array in pieces:
		var strip := _overlay(String(p[1]), float(p[2]), bool(p[3]))
		var path := "%s/%s_%s.png" % [OUT, p[0], file_part(String(p[1]))]
		strip.save_png(ProjectSettings.globalize_path(path))
		print("make_armor_art: wrote %s" % path)
	quit()


static func file_part(part: String) -> String:
	return part.to_lower().replace(" ", "_")


## One overlay strip for a part: its pixels in the top `cover` of each frame, in copper.
## `rim` grows the shape by a pixel to the sides and top (a helmet sits on the head).
func _overlay(part: String, cover: float, rim: bool) -> Image:
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
		var mask: Dictionary[Vector2i, float] = {}  # pixel -> brightness
		for y in range(used.position.y, limit):
			for x in range(used.position.x, used.end.x):
				var c := src.get_pixel(x, y)
				if c.a > 0.5:
					mask[Vector2i(x, y)] = c.get_luminance()
		if rim:
			var grown: Dictionary[Vector2i, float] = mask.duplicate()
			for p: Vector2i in mask:
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
					var q := p + d
					if q.x >= 0 and q.y >= 0 and q.x < _frame.x and not grown.has(q):
						grown[q] = 0.35
			mask = grown
		for p: Vector2i in mask:
			var t := clampf((mask[p] - 0.2) / 0.6, 0.0, 1.0)
			var i := 1 + int(t * 1.99)  # the middle tones
			# Edges a step darker so the piece reads against the body.
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if not mask.has(p + d):
					i -= 1
					break
			# A highlight along the top.
			if not mask.has(p + Vector2i.UP) and mask.has(p + Vector2i.DOWN):
				i = 3
			out.set_pixel(f * _frame.x + p.x, p.y, COPPER[clampi(i, 0, 3)])
	return out
