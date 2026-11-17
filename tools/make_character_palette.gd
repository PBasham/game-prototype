extends SceneTree
## Builds a CharacterPalette (recolorable color groups) from a character's parts sheet,
## so CharacterLook can recolor skin, clothes and hair. Re-run after changing colors in
## the .aseprite (and re-importing it). Groups are guessed from each color and the layer
## it's on; check and fix the result in the Inspector if a color lands in the wrong group.
##
##   godot --headless --path . --script res://tools/make_character_palette.gd -- \
##       --sheet=res://assets/sprites/scholar --out=res://assets/sprites/scholar_palette.tres
##
## Also writes the placeholder hairstyle (assets/sprites/hair/short.png) and adds its
## colors as the "hair" group.
##
## Rules: skin = warm light colors on head or arm layers; leather = dark browns (boots,
## belt); blue on the torso = tunic, low-saturation blue = trim, blue on legs = pants.
## Anything else is left out (never recolored).

const HAIR_PATH := "res://assets/sprites/hair/short.png"
## Placeholder hairstyle, 9x6: d = dark, m = mid, l = light. Faces right.
const HAIR := [
	"..ddddd..",
	".dmmmmml.",
	"dmmmlmmml",
	"dmmddmmd.",
	"dd.......",
	"d........",
]
const HAIR_COLORS := {"d": "3b2416", "m": "5c3a22", "l": "7d5533"}


func _init() -> void:
	var sheet := "res://assets/sprites/scholar"
	var out := "res://assets/sprites/scholar_palette.tres"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):
			sheet = a.trim_prefix("--sheet=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sheet + ".json"))
	var img := Image.load_from_file(ProjectSettings.globalize_path(sheet + "_parts.png"))
	var fh := int(meta.frame_size[1])
	var groups: Dictionary[StringName, PackedColorArray] = {}
	for p: Dictionary in meta.parts:
		var layer := String(p.name).to_lower()
		var row := int(p.row)
		for y in range(row * fh, row * fh + fh):
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var g := _group(c, layer)
				if g == &"":
					continue
				if not groups.has(g):
					groups[g] = PackedColorArray()
				if not _has(groups[g], c):
					groups[g].append(c)

	var hair := _make_hair()
	hair.save_png(ProjectSettings.globalize_path(HAIR_PATH))
	var hair_colors := PackedColorArray()
	for k: String in ["d", "m", "l"]:
		hair_colors.append(Color(HAIR_COLORS[k]))
	groups[&"hair"] = hair_colors

	var palette := CharacterPalette.new()
	for g: StringName in groups:
		var colors := groups[g]
		var sorted := Array(colors)
		sorted.sort_custom(func(a: Color, b: Color) -> bool: return a.v < b.v)
		palette.groups[g] = PackedColorArray(sorted)
	ResourceSaver.save(palette, out)
	for g: StringName in palette.groups:
		print("make_character_palette: %s: %d colors" % [g, palette.groups[g].size()])
	print("-> %s, %s" % [out, HAIR_PATH])
	quit()


func _group(c: Color, layer: String) -> StringName:
	var hue := c.h * 360.0
	var warm := hue < 50.0 or hue > 340.0
	if warm and c.v < 0.5:
		return &"leather"
	if warm and (layer.contains("head") or layer.contains("arm") or layer.contains("torso")) and c.v > 0.55 and c.s < 0.6:
		return &"skin"
	if hue > 190.0 and hue < 260.0:
		if c.s < 0.35:
			return &"trim"
		if layer.contains("leg"):
			return &"pants"
		return &"tunic"
	return &""


func _has(list: PackedColorArray, c: Color) -> bool:
	for o in list:
		if o.is_equal_approx(c):
			return true
	return false


func _make_hair() -> Image:
	var img := Image.create_empty(HAIR[0].length(), HAIR.size(), false, Image.FORMAT_RGBA8)
	for y in HAIR.size():
		var row: String = HAIR[y]
		for x in row.length():
			var ch := row[x]
			if HAIR_COLORS.has(ch):
				img.set_pixel(x, y, Color(HAIR_COLORS[ch]))
	return img
