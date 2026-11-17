extends SceneTree
## Imports an Aseprite file into a sprite sheet + metadata the game reads at runtime.
##
##   godot --headless --path . --script res://tools/import_aseprite.gd -- \
##       --in=/path/to/Scholar-casual.aseprite --out=res://assets/sprites/scholar
##
## Writes:
##   <out>.png        all frames side by side, flattened, cropped to the union of their
##                    bounds (the classic one-piece sheet)
##   <out>_parts.png  the same frames, one row per body layer (paper doll parts),
##                    bottom layer in row 0
##   <out>.json       frame size, foot anchor, per-frame durations, animation tags,
##                    the part list (name, row) and pivot points per frame
##
## Hidden layers, group layers and layers named in SKIP_LAYERS are left out.
## A layer named "Pivots" is never drawn: single pixels on it mark joints, by color
## (PIVOT_COLORS). Each becomes a per-frame point in the JSON ("pivots"), relative to
## the frame's top-left. Optional; the game falls back to measured joints without it.
## Supports RGBA (32-bit) files with raw, compressed and linked cels.

const SKIP_LAYERS := ["backdrop", "Ref"]
const PIVOT_LAYER := "Pivots"
## Marker colors on the Pivots layer (exact RGB) and the joint each one marks.
const PIVOT_COLORS := {
	"ff0000": "front_shoulder",
	"ff8000": "front_hand",
	"0000ff": "back_shoulder",
	"0080ff": "back_hand",
	"00ff00": "neck",
}

var _data := PackedByteArray()


func _init() -> void:
	var in_path := ""
	var out := "res://assets/sprites/scholar"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--in="):
			in_path = arg.trim_prefix("--in=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if in_path.is_empty():
		push_error("usage: -- --in=<file.aseprite> [--out=res://assets/sprites/name]")
		quit(1)
		return
	var err := _import(in_path, out)
	quit(0 if err == OK else 1)


func _u8(o: int) -> int:
	return _data[o]


func _u16(o: int) -> int:
	return _data.decode_u16(o)


func _s16(o: int) -> int:
	return _data.decode_s16(o)


func _u32(o: int) -> int:
	return _data.decode_u32(o)


func _import(in_path: String, out: String) -> Error:
	_data = FileAccess.get_file_as_bytes(in_path)
	if _data.is_empty() or _u16(4) != 0xA5E0:
		push_error("not an Aseprite file: %s" % in_path)
		return ERR_FILE_UNRECOGNIZED
	var frame_count := _u16(6)
	var w := _u16(8)
	var h := _u16(10)
	if _u16(12) != 32:
		push_error("only RGBA Aseprite files are supported (this one is %d-bit)" % _u16(12))
		return ERR_UNAVAILABLE
	var layers: Array[Dictionary] = []
	var tags: Dictionary = {}
	var frames: Array[Dictionary] = []
	var pos := 128
	for fi in frame_count:
		var fsize := _u32(pos)
		var duration := _u16(pos + 8)
		var chunks := _u32(pos + 12)
		if chunks == 0:
			chunks = _u16(pos + 6)
		var p := pos + 16
		var cels: Array[Dictionary] = []
		for _c in chunks:
			var csize := _u32(p)
			var ctype := _u16(p + 4)
			var b := p + 6
			match ctype:
				0x2004:
					var name_len := _u16(b + 16)
					layers.append({
						"visible": (_u16(b) & 1) == 1,
						"type": _u16(b + 2),
						"opacity": _u8(b + 12),
						"name": _data.slice(b + 18, b + 18 + name_len).get_string_from_utf8(),
					})
				0x2005:
					var cel := {"layer": _u16(b), "x": _s16(b + 2), "y": _s16(b + 4), "opacity": _u8(b + 6)}
					var kind := _u16(b + 7)
					var rest := b + 16
					if kind == 1:
						cel.link = _u16(rest)
					elif kind == 0 or kind == 2:
						var cw := _u16(rest)
						var ch := _u16(rest + 2)
						var px := _data.slice(rest + 4, p + csize)
						if kind == 2:
							px = px.decompress(cw * ch * 4, FileAccess.COMPRESSION_DEFLATE)
						cel.image = Image.create_from_data(cw, ch, false, Image.FORMAT_RGBA8, px)
					else:
						p += csize
						continue
					cels.append(cel)
				0x2018:
					var count := _u16(b)
					var q := b + 10
					for _t in count:
						var from := _u16(q)
						var to := _u16(q + 2)
						var name_len := _u16(q + 17)
						tags[_data.slice(q + 19, q + 19 + name_len).get_string_from_utf8()] = [from, to]
						q += 19 + name_len
			p += csize
		frames.append({"duration": duration, "cels": cels})
		pos += fsize

	# Body layers (paper doll parts), bottom to top, and the pivots layer.
	var part_layers: Array[int] = []
	var pivot_layer := -1
	for li in layers.size():
		var layer: Dictionary = layers[li]
		if layer.name == PIVOT_LAYER:
			pivot_layer = li
		elif layer.visible and layer.type == 0 and not SKIP_LAYERS.has(layer.name):
			part_layers.append(li)

	# Each frame: one image per part layer, plus the flattened composite.
	var images: Array[Image] = []
	var part_images: Array[Array] = []  # [frame][part] -> Image
	var pivot_images: Array[Image] = []
	for fi in frame_count:
		var canvas := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		var parts: Array[Image] = []
		for li in part_layers:
			var img := _layer_image(frames, fi, li, w, h)
			parts.append(img)
			canvas.blend_rect(img, Rect2i(0, 0, w, h), Vector2i.ZERO)
		images.append(canvas)
		part_images.append(parts)
		pivot_images.append(_layer_image(frames, fi, pivot_layer, w, h) if pivot_layer >= 0 else null)

	# Crop all frames to the union of their used areas.
	var union := Rect2i()
	for img in images:
		var used := img.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		union = used if union.size == Vector2i.ZERO else union.merge(used)
	var first := images[0].get_used_rect()
	var sheet := Image.create_empty(union.size.x * frame_count, union.size.y, false, Image.FORMAT_RGBA8)
	var parts_sheet := Image.create_empty(union.size.x * frame_count, union.size.y * part_layers.size(), false, Image.FORMAT_RGBA8)
	var frame_meta: Array = []
	for fi in frame_count:
		sheet.blit_rect(images[fi], union, Vector2i(fi * union.size.x, 0))
		for pi in part_layers.size():
			parts_sheet.blit_rect(part_images[fi][pi], union, Vector2i(fi * union.size.x, pi * union.size.y))
		var fm := {"x": fi * union.size.x, "duration_ms": frames[fi].duration}
		if pivot_images[fi] != null:
			fm.pivots = _pivots(pivot_images[fi], union)
		frame_meta.append(fm)
	var part_meta: Array = []
	for pi in part_layers.size():
		part_meta.append({"name": layers[part_layers[pi]].name, "row": pi})
	var meta := {
		"source": in_path.get_file(),
		"frame_size": [union.size.x, union.size.y],
		# Feet: bottom of the union, horizontally centered on the first frame's body.
		"anchor": [first.position.x + first.size.x / 2 - union.position.x, union.size.y],
		"frames": frame_meta,
		"tags": tags,
		"parts": part_meta,
	}
	parts_sheet.save_png(out + "_parts.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	sheet.save_png(out + ".png")
	var f := FileAccess.open(out + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "  "))
	f.close()
	print("import_aseprite: %d frames, %s, tags %s, %d parts -> %s.png" % [frame_count, union.size, tags.keys(), part_layers.size(), out])
	return OK


## One layer of one frame on a full-canvas image (follows linked cels).
func _layer_image(frames: Array[Dictionary], fi: int, li: int, w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for cel: Dictionary in frames[fi].cels:
		if cel.layer != li:
			continue
		var src := cel
		if src.has("link"):
			for other: Dictionary in frames[src.link].cels:
				if other.layer == li:
					src = other
					break
		if src.has("image"):
			var part: Image = src.image
			img.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(src.x, src.y))
	return img


func _pivots(img: Image, union: Rect2i) -> Dictionary:
	var out := {}
	for y in range(union.position.y, union.end.y):
		for x in range(union.position.x, union.end.x):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var key: String = c.to_html(false)
			if PIVOT_COLORS.has(key):
				out[PIVOT_COLORS[key]] = [x - union.position.x, y - union.position.y]
	return out
