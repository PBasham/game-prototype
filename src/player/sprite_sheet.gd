class_name SpriteSheet
extends RefCounted
## Loads a sheet made by tools/import_aseprite.gd into SpriteFrames.
## Each Aseprite tag becomes an animation; per-frame durations are kept.

var frames: SpriteFrames
## Feet position inside a frame, in pixels from the frame's top-left.
var anchor: Vector2
var frame_size: Vector2i


static func load_from(base_path: String) -> SpriteSheet:
	var sheet := SpriteSheet.new()
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base_path + ".json"))
	sheet.frame_size = Vector2i(int(meta.frame_size[0]), int(meta.frame_size[1]))
	sheet.anchor = Vector2(float(meta.anchor[0]), float(meta.anchor[1]))
	sheet.frames = SpriteFrames.new()
	sheet.frames.remove_animation(&"default")
	sheet.add_tags_from(base_path)
	return sheet


## Adds the tags from another sheet with the same frame size (placeholder or extra art).
## Tags this sheet already has are kept, so real art always wins over a placeholder.
func add_tags_from(base_path: String) -> void:
	if not FileAccess.file_exists(base_path + ".json"):
		return
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base_path + ".json"))
	var texture := load(base_path + ".png") as Texture2D
	var frame_list: Array = meta.frames
	var tags: Dictionary = meta.tags
	for tag: String in tags:
		var range_: Array = tags[tag]
		var anim := StringName(tag)
		if frames.has_animation(anim):
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 1.0)
		frames.set_animation_loop(anim, int(range_[1]) > int(range_[0]))
		for fi in range(int(range_[0]), int(range_[1]) + 1):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(float(frame_list[fi].x), 0, frame_size.x, frame_size.y)
			frames.add_frame(anim, atlas, float(frame_list[fi].duration_ms) / 1000.0)
