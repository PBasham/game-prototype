class_name DollRig
extends RefCounted
## A character's paper doll data, read from the sheet tools/import_aseprite.gd writes:
## one row of frames per body layer (<base>_parts.png) plus <base>.json.
##
## Parts are sorted into channels by layer name, so each channel can play its own
## animation:
##   legs       layers with "Leg" in the name
##   front_arm  layers with "Arm" and "Front"
##   back_arm   layers with "Arm" and "Back"
##   body       everything else (Torso, Head, ...)
## An arm is two layers, "<Side> Arm Upper" and "<Side> Arm Lower"; code-posed arms
## rotate them separately around the shoulder and elbow.
##
## Tags: "legs/Jog", "arms/Hold1H", "body/Breath" apply to one channel; a tag with no
## prefix ("Jog") applies to every channel that has no prefixed tag of that name.
##
## Joints (shoulder, elbow, hand per arm) are measured from the art in the rest frame
## (first frame of "arms/Rest", else of "Idle Pose", else frame 0): shoulder = top of
## the upper arm, elbow = bottom of the upper arm, hand = bottom of the lower arm. A
## "Pivots" layer in the .aseprite overrides the shoulders and hands (see the importer).
##
## Rigs are cached per path and shared by every doll that uses them (read-only).

const CHANNELS: Array[StringName] = [&"legs", &"body", &"back_arm", &"front_arm"]

## The parts texture (one row per layer).
var texture: Texture2D
var frame_size: Vector2i
## Feet inside a frame (doll origin), from the frame's top-left.
var anchor: Vector2
var frame_count := 0
## Seconds per frame.
var durations := PackedFloat32Array()
## Tag name -> Vector2i(first frame, last frame).
var tags: Dictionary[String, Vector2i] = {}
## Part layer names, bottom to top (= texture rows).
var part_names: PackedStringArray = []
## Channel per part.
var part_channels: Array[StringName] = []
## Used rect of each part in each frame, frame-local: rects[part][frame].
var rects: Array[Array] = []
## Frame used to measure joints (arms hanging naturally).
var rest_frame := 0
## Per arm side (&"front" / &"back"): {upper: int part, lower: int part, shoulder,
## elbow, hand: Vector2 in rest-frame pixels}. Missing if the art has no such arm.
var arms: Dictionary[StringName, Dictionary] = {}
## Torso position per frame relative to the rest frame (how far the body bobs), so
## stowed items move with it.
var body_offset := PackedVector2Array()
## Shoulder per arm side per frame (frame-local pixels): where code-posed arms attach.
## Measured in every frame (top of that frame's upper arm), because poses differ: a 3/4
## standing pose has the shoulders far apart, a side-view run has them close together.
## A Pivots layer overrides it per frame.
var shoulders: Dictionary[StringName, PackedVector2Array] = {}
## Head top-left per frame (for hair and helmets).
var head_pos := PackedVector2Array()
## Pivots from the Pivots layer, per frame (may be empty).
var pivots: Array[Dictionary] = []

static var _cache: Dictionary[String, DollRig] = {}


static func load_from(base_path: String) -> DollRig:
	if _cache.has(base_path):
		return _cache[base_path]
	var rig := DollRig.new()
	rig._load(base_path)
	_cache[base_path] = rig
	return rig


## Frame range for an animation on a channel, or Vector2i(-1, -1) if there is none.
func tag_range(channel: StringName, anim: StringName) -> Vector2i:
	var prefix := "arms" if channel == &"front_arm" or channel == &"back_arm" else String(channel)
	var key := "%s/%s" % [prefix, anim]
	if tags.has(key):
		return tags[key]
	if tags.has(String(anim)):
		return tags[String(anim)]
	return Vector2i(-1, -1)


func has_tag(channel: StringName, anim: StringName) -> bool:
	return tag_range(channel, anim).x >= 0


## The parts texture region for one part in one frame.
func region(part: int, frame: int) -> Rect2:
	return Rect2(frame * frame_size.x, part * frame_size.y, frame_size.x, frame_size.y)


func part_index(part_name: String) -> int:
	return part_names.find(part_name)


func _load(base_path: String) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base_path + ".json"))
	texture = load(base_path + "_parts.png") as Texture2D
	frame_size = Vector2i(int(meta.frame_size[0]), int(meta.frame_size[1]))
	anchor = Vector2(float(meta.anchor[0]), float(meta.anchor[1]))
	var frame_list: Array = meta.frames
	frame_count = frame_list.size()
	for f: Dictionary in frame_list:
		durations.append(maxf(float(f.duration_ms) / 1000.0, 0.01))
		pivots.append(f.get("pivots", {}))
	for tag: String in meta.tags:
		var r: Array = meta.tags[tag]
		tags[tag] = Vector2i(int(r[0]), int(r[1]))
	for p: Dictionary in meta.get("parts", []):
		var n := String(p.name)
		part_names.append(n)
		part_channels.append(_channel_for(n))

	var img := texture.get_image()
	for pi in part_names.size():
		var per_frame: Array[Rect2i] = []
		for fi in frame_count:
			var cell := Rect2i(fi * frame_size.x, pi * frame_size.y, frame_size.x, frame_size.y)
			var used := img.get_region(cell).get_used_rect()
			per_frame.append(used)
		rects.append(per_frame)

	if tags.has("arms/Rest"):
		rest_frame = tags["arms/Rest"].x
	elif tags.has("Idle Pose"):
		rest_frame = tags["Idle Pose"].x
	for side: StringName in [&"front", &"back"]:
		var arm := _measure_arm(img, side)
		if not arm.is_empty():
			arms[side] = arm
			shoulders[side] = _measure_shoulders(img, side, arm)

	var torso := _first_part_with(["Torso", "Body", "Chest"])
	var head := _first_part_with(["Head"])
	for fi in frame_count:
		if torso >= 0 and _rect(torso, fi).size != Vector2i.ZERO and _rect(torso, rest_frame).size != Vector2i.ZERO:
			# Bob = how the torso's top edge moved; sideways = its center.
			var r := _rect(torso, fi)
			var r0 := _rect(torso, rest_frame)
			body_offset.append(Vector2(r.get_center().x - r0.get_center().x, r.position.y - r0.position.y))
		else:
			body_offset.append(Vector2.ZERO)
		head_pos.append(Vector2(_rect(head, fi).position) if head >= 0 else Vector2.ZERO)


func _channel_for(layer_name: String) -> StringName:
	var n := layer_name.to_lower()
	if n.contains("arm") or n.contains("hand"):
		return &"back_arm" if n.contains("back") else &"front_arm"
	if n.contains("leg") or n.contains("foot") or n.contains("feet"):
		return &"legs"
	return &"body"


func _rect(part: int, frame: int) -> Rect2i:
	return rects[part][frame]


func _first_part_with(words: Array[String]) -> int:
	for w in words:
		for i in part_names.size():
			if part_names[i].to_lower().contains(w.to_lower()):
				return i
	return -1


## Shoulder, elbow and hand of one arm in the rest frame.
func _measure_arm(img: Image, side: StringName) -> Dictionary:
	var upper := -1
	var lower := -1
	for i in part_names.size():
		var n := part_names[i].to_lower()
		if part_channels[i] != (&"front_arm" if side == &"front" else &"back_arm"):
			continue
		if n.contains("upper"):
			upper = i
		elif n.contains("lower"):
			lower = i
	if upper < 0 or lower < 0:
		return {}
	var f := rest_frame
	var ur := _rect(upper, f)
	var lr := _rect(lower, f)
	if ur.size == Vector2i.ZERO or lr.size == Vector2i.ZERO:
		return {}
	var shoulder := _row_center(img, upper, f, ur.position.y) + Vector2(0, 1)
	var elbow := _row_center(img, upper, f, ur.end.y - 1)
	var hand := _row_center(img, lower, f, lr.end.y - 1)
	var pv: Dictionary = pivots[f] if f < pivots.size() else {}
	if pv.has("%s_shoulder" % side):
		shoulder = Vector2(pv["%s_shoulder" % side][0], pv["%s_shoulder" % side][1])
	if pv.has("%s_hand" % side):
		hand = Vector2(pv["%s_hand" % side][0], pv["%s_hand" % side][1])
	return {"upper": upper, "lower": lower, "shoulder": shoulder, "elbow": elbow, "hand": hand}


func _measure_shoulders(img: Image, side: StringName, arm: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var key := "%s_shoulder" % side
	for f in frame_count:
		var pv: Dictionary = pivots[f] if f < pivots.size() else {}
		if pv.has(key):
			out.append(Vector2(pv[key][0], pv[key][1]))
			continue
		var upper := _pixels(img, arm.upper, f)
		var lower := _pixels(img, arm.lower, f)
		if upper.is_empty():
			out.append(arm.shoulder)
			continue
		if lower.is_empty():
			var r := _rect(arm.upper, f)
			out.append(_row_center(img, arm.upper, f, r.position.y) + Vector2(0, 1))
			continue
		# Elbow = the upper-arm pixel nearest the lower arm; shoulder = the upper-arm
		# pixel farthest from it. Works however the arm is swung in the frame.
		var elbow := upper[0]
		var best := INF
		for p in upper:
			for q in lower:
				var d := p.distance_squared_to(q)
				if d < best:
					best = d
					elbow = p
		var far := elbow
		var far_d := -1.0
		for p in upper:
			var d := p.distance_squared_to(elbow)
			if d > far_d:
				far_d = d
				far = p
		# One pixel in from the very end, toward the elbow.
		out.append(far + (elbow - far).normalized() + Vector2(0.5, 0.5))
	return out


## Opaque pixels of a part in a frame (frame-local).
func _pixels(img: Image, part: int, frame: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := _rect(part, frame)
	var x0 := frame * frame_size.x
	var y0 := part * frame_size.y
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if img.get_pixel(x0 + x, y0 + y).a > 0.5:
				out.append(Vector2(x, y))
	return out


## Center of the opaque pixels in one row of a part's frame (frame-local, pixel center).
func _row_center(img: Image, part: int, frame: int, y: int) -> Vector2:
	var x0 := frame * frame_size.x
	var y0 := part * frame_size.y
	var sum := 0.0
	var n := 0
	for x in frame_size.x:
		if img.get_pixel(x0 + x, y0 + y).a > 0.5:
			sum += x + 0.5
			n += 1
	return Vector2(sum / maxf(n, 1), y + 0.5)
