class_name PaperDoll
extends Node2D
## The character drawn as separate body parts (a paper doll), each picking its own frame:
##
##   legs   play the movement animation (Breath, Jog, Jump...)
##   body   torso and head follow the legs' frame (or their own "body/" tags)
##   arms   follow the legs, unless a `motion` is playing: holding an item, or an
##          attack. A motion plays hand-drawn arm frames when the art has them, else
##          poses the arms in code from its curves (see ItemMotion, ArmTrack).
##
## "Code-posed" arms use the upper and lower arm layers as two bones (shoulder and elbow
## joints measured from the art) and bend them so the hand reaches a point. force_posed
## shows code posing even where drawn frames exist, to compare.
##
## The held item is drawn in the holding hand; stowed (put away) it sits on the back, at
## the hip, or is hidden. Colors come from CharacterLook via a palette-swap shader.
## Facing: set `scale.x` to 1 (right) or -1 (left); the art faces right. Origin = feet.
##
## Driven by setting properties each frame; see Player._animate().

const SWAP_SHADER := preload("res://src/player/doll/palette_swap.gdshader")

@export_group("Stowed item")
## Item on the back: position from the front shoulder (pixels) and angle (degrees).
@export var stow_back_offset := Vector2(-6, 9)
@export var stow_back_angle := -110.0
## Item at the hip.
@export var stow_hip_offset := Vector2(3, 20)
@export var stow_hip_angle := 105.0
@export_group("")
## Show code-posed arms even when drawn frames exist (to compare).
@export var force_posed := false

var rig: DollRig
var palette: CharacterPalette
var look: CharacterLook:
	set(v):
		look = v
		_apply_look()

## Held item, or null for empty hands.
var item: HeldItemLook:
	set(v):
		item = v
		_apply_item()
## Item put away (shown stowed, not in hand).
var stowed := false:
	set(v):
		stowed = v
		_apply_item()
## The arm motion playing (the item's hold, or an attack), or null for natural arms.
var motion: ItemMotion
## 0..1 through the motion.
var motion_t := 0.0
## Point the arms aim at when the motion aims, in global coordinates.
var aim_global := Vector2.ZERO
## Pixels the upper body drops (procedural landing squash).
var dip := 0.0

# Legs animation state.
var animation: StringName = &""
var frame := 0  ## index within the animation
var speed_scale := 1.0
## Play the legs backwards (walking backwards while aiming).
var reverse := false
var paused := false
var _time := 0.0

# Nodes.
var _slots: Array[Node2D] = []  ## per part
var _sprites: Array[Sprite2D] = []  ## per part (base layer)
var _overlays: Array[Array] = []  ## per part: overlay Sprite2Ds
var _hair: Sprite2D
var _item_sprite: Sprite2D
var _stow_back: Sprite2D
var _stow_hip: Sprite2D
var _material: ShaderMaterial
var _head_part := -1
## Hand positions (local) from the last update, for items, tests and debugging.
var hands: Dictionary[StringName, Vector2] = {}
## Item angle (radians) from the last update.
var item_rotation := 0.0


func setup(doll_rig: DollRig, doll_palette: CharacterPalette = null) -> void:
	rig = doll_rig
	palette = doll_palette
	_material = ShaderMaterial.new()
	_material.shader = SWAP_SHADER
	material = _material
	for child in get_children():
		child.queue_free()
	_slots.clear()
	_sprites.clear()
	_overlays.clear()

	_stow_back = _item_node("StowBack")
	var first_front_arm := -1
	for pi in rig.part_names.size():
		if rig.part_channels[pi] == &"front_arm" and first_front_arm < 0:
			first_front_arm = pi
			_stow_hip = _item_node("StowHip")
			_item_sprite = _item_node("Item")
		var slot := Node2D.new()
		slot.name = rig.part_names[pi].replace(" ", "")
		slot.use_parent_material = true
		add_child(slot)
		var s := Sprite2D.new()
		s.texture = rig.texture
		s.region_enabled = true
		s.centered = false
		s.use_parent_material = true
		slot.add_child(s)
		_slots.append(slot)
		_sprites.append(s)
		_overlays.append([])
		if rig.part_names[pi].to_lower().contains("head"):
			_head_part = pi
			_hair = Sprite2D.new()
			_hair.name = "Hair"
			_hair.centered = false
			_hair.use_parent_material = true
			add_child(_hair)
	if _item_sprite == null:
		_stow_hip = _item_node("StowHip")
		_item_sprite = _item_node("Item")
	_apply_look()
	_apply_item()
	play(&"Breath")
	_update()


## Starts a legs animation (no restart if it's already playing).
func play(anim: StringName) -> void:
	paused = false
	if anim == animation:
		return
	animation = anim
	frame = 0
	_time = 0.0


func pause() -> void:
	paused = true


func has_animation(anim: StringName) -> bool:
	return rig != null and rig.has_tag(&"legs", anim)


func frame_count(anim: StringName) -> int:
	var r := rig.tag_range(&"legs", anim)
	return r.y - r.x + 1 if r.x >= 0 else 0


## Adds armor or clothing over a part. `texture` has the same layout as one row of the
## parts sheet (one frame cell per frame) and follows the part's frames and poses.
func add_overlay(part_name: String, texture: Texture2D) -> Sprite2D:
	var pi := rig.part_index(part_name)
	if pi < 0:
		push_warning("PaperDoll: no part named %s" % part_name)
		return null
	var s := Sprite2D.new()
	s.texture = texture
	s.region_enabled = true
	s.centered = false
	s.use_parent_material = true
	_slots[pi].add_child(s)
	_overlays[pi].append(s)
	return s


func clear_overlays() -> void:
	for list in _overlays:
		for s: Sprite2D in list:
			s.queue_free()
		list.clear()


## The drawn arm tag this motion would play, or "" if the art has none (or force_posed).
func drawn_tag_for(m: ItemMotion) -> String:
	if m == null or force_posed:
		return ""
	var names := PackedStringArray()
	if item and m.name != "":
		names.append("arms/%s/%s" % [item.id, m.name])
		names.append("arms/%s/%s" % [item.type, m.name])
	if m.drawn_tag != "":
		names.append("arms/%s" % m.drawn_tag)
	for n in names:
		if rig.tags.has(n):
			return n
	return ""


func _item_node(node_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.centered = false
	s.visible = false
	add_child(s)
	return s


func _process(delta: float) -> void:
	if rig == null:
		return
	_advance(delta)
	_update()


func _advance(delta: float) -> void:
	var r := rig.tag_range(&"legs", animation)
	if r.x < 0 or paused:
		return
	var count := r.y - r.x + 1
	_time += delta * speed_scale
	var guard := 0
	while _time >= rig.durations[r.x + frame] and guard < 64:
		_time -= rig.durations[r.x + frame]
		frame = posmod(frame + (-1 if reverse else 1), count) if count > 1 else 0
		guard += 1


# --- per frame ------------------------------------------------------------------------

func _update() -> void:
	var legs_r := rig.tag_range(&"legs", animation)
	if legs_r.x < 0:
		legs_r = Vector2i(0, 0)
	var count := legs_r.y - legs_r.x + 1
	frame = clampi(frame, 0, count - 1)
	var legs_abs := legs_r.x + frame
	var body_abs := _follow(&"body", legs_abs)
	var shift := Vector2(motion.lunge_at(motion_t) if motion else 0.0, dip)
	hands.clear()

	for pi in rig.part_names.size():
		var ch := rig.part_channels[pi]
		if ch == &"legs":
			_show_frame(pi, legs_abs, Vector2.ZERO)
		elif ch == &"body":
			_show_frame(pi, body_abs, shift)
	_pose_arms(legs_abs, body_abs, shift)

	if _hair and _hair.texture and _head_part >= 0:
		_hair.position = rig.head_pos[body_abs] + look.hair_offset - rig.anchor + shift
	_place_stowed(body_abs, shift)


## The frame a channel shows: its own tag's frame at the same index if it has one,
## else the legs frame.
func _follow(channel: StringName, legs_abs: int) -> int:
	var r := rig.tag_range(channel, animation)
	if r.x < 0:
		return legs_abs
	return r.x + posmod(frame, r.y - r.x + 1)


func _show_frame(pi: int, abs_frame: int, shift: Vector2) -> void:
	var slot := _slots[pi]
	slot.position = shift
	slot.rotation = 0.0
	_set_region(pi, rig.region(pi, abs_frame), -rig.anchor)


func _set_region(pi: int, region: Rect2, offset: Vector2) -> void:
	_sprites[pi].region_rect = region
	_sprites[pi].offset = offset
	for s: Sprite2D in _overlays[pi]:
		s.region_rect = Rect2(region.position.x, 0, region.size.x, region.size.y)
		s.offset = offset


func _shoulder(side: StringName, body_abs: int, shift: Vector2) -> Vector2:
	if not rig.shoulders.has(side):
		return Vector2.ZERO
	return rig.shoulders[side][body_abs] - rig.anchor + shift


## Natural arms, drawn motion frames, or code-posed motion.
func _pose_arms(legs_abs: int, body_abs: int, shift: Vector2) -> void:
	var m := motion
	var in_hand := item != null and not stowed
	_item_sprite.visible = in_hand and m != null
	if m == null:
		for side: StringName in [&"front", &"back"]:
			_natural(side, legs_abs, body_abs, shift)
		return

	var tag := drawn_tag_for(m)
	if tag != "":
		var r: Vector2i = rig.tags[tag]
		var n := r.y - r.x + 1
		var f := r.x + mini(int(motion_t * n), n - 1)
		for side: StringName in [&"front", &"back"]:
			for pi in _parts_of(_channel(side)):
				_show_frame(pi, f, shift)
			if rig.arms.has(side):
				hands[side] = _drawn_hand(rig.arms[side], f, _shoulder(side, body_abs, shift))
		if in_hand:
			_place_item(m, _holding_side(), _shoulder(_holding_side(), body_abs, shift))
		return

	# Code-posed: the holding arm first, then the item, then the other arm (which may
	# grip the item).
	var holding := _holding_side()
	var other := &"back" if holding == &"front" else &"front"
	var aim_angle := 0.0
	if m.aims:
		aim_angle = (to_local(aim_global) - _shoulder(&"front", body_abs, shift)).angle()
	for side: StringName in [holding, other]:
		var track: ArmTrack = m.front if side == &"front" else m.back
		var shoulder := _shoulder(side, body_abs, shift)
		var arm: Dictionary = rig.arms.get(side, {})
		var mode := track.mode if track else ArmTrack.Mode.NATURAL
		if arm.is_empty() or mode == ArmTrack.Mode.NATURAL or (mode == ArmTrack.Mode.GRIP and not in_hand):
			_natural(side, legs_abs, body_abs, shift)
		elif mode == ArmTrack.Mode.POSE:
			var length := ((arm.hand as Vector2) - (arm.shoulder as Vector2)).length()
			var dir := Vector2.from_angle(aim_angle + deg_to_rad(track.angle_at(motion_t)))
			_reach(arm, _parts_of(_channel(side)), shoulder, shoulder + dir * length * track.reach_at(motion_t))
		else:  # GRIP: the item's other grip, pulled back along the item
			var axis := Vector2.from_angle(item_rotation)
			var target := _grip_point(item.grip2) - axis * track.pull_at(motion_t)
			_reach(arm, _parts_of(_channel(side)), shoulder, target)
		if side == holding and in_hand:
			_place_item(m, holding, shoulder, aim_angle)


func _holding_side() -> StringName:
	if item and item.item_type() and item.item_type().held_in == ItemTypeData.Hand.BACK:
		return &"back"
	return &"front"


func _channel(side: StringName) -> StringName:
	return &"front_arm" if side == &"front" else &"back_arm"


func _natural(side: StringName, legs_abs: int, body_abs: int, shift: Vector2) -> void:
	var channel := _channel(side)
	var f := _follow(channel, legs_abs)
	for pi in _parts_of(channel):
		_show_frame(pi, f, shift)
	if rig.arms.has(side):
		hands[side] = _drawn_hand(rig.arms[side], f, _shoulder(side, body_abs, shift))


func _parts_of(channel: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	for pi in rig.part_names.size():
		if rig.part_channels[pi] == channel:
			out.append(pi)
	return out


## Two-bone arm bent so the hand reaches `target` (clamped to the arm's length).
func _reach(arm: Dictionary, parts: PackedInt32Array, shoulder: Vector2, target: Vector2) -> void:
	var s0: Vector2 = arm.shoulder
	var e0: Vector2 = arm.elbow
	var h0: Vector2 = arm.hand
	var l1 := (e0 - s0).length()
	var l2 := (h0 - e0).length()
	var to := target - shoulder
	if to.length_squared() < 0.01:
		to = Vector2(0, 0.1)
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var base := to.angle()
	var bend := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	# The elbow always bends to the same side (clockwise of the shoulder-to-hand line):
	# below for a forward reach, behind for a downward one, in front when raised. Picking
	# the side by direction made it flip when the arm passed straight up or down.
	var a1 := base + bend
	var elbow := shoulder + Vector2.from_angle(a1) * l1
	var hand := shoulder + to.normalized() * d
	var a2 := (hand - elbow).angle()
	_bone(arm.upper, s0, shoulder, a1 - (e0 - s0).angle())
	_bone(arm.lower, e0, elbow, a2 - (h0 - e0).angle())
	for pi in parts:
		# Any extra layers in the arm channel follow the lower arm.
		if pi != arm.upper and pi != arm.lower:
			_bone(pi, e0, elbow, a2 - (h0 - e0).angle())
	hands[&"front" if rig.arms.get(&"front") == arm else &"back"] = hand


## Draws a part from the rest frame, rotated by `rot` around `joint_rest` placed at `at`.
func _bone(pi: int, joint_rest: Vector2, at: Vector2, rot: float) -> void:
	var slot := _slots[pi]
	slot.position = at
	slot.rotation = rot
	_set_region(pi, rig.region(pi, rig.rest_frame), -joint_rest)


## Hand position in a drawn frame: the end of the lower arm farthest from the shoulder.
func _drawn_hand(arm: Dictionary, abs_frame: int, shoulder: Vector2) -> Vector2:
	var r: Rect2i = rig.rects[arm.lower][abs_frame]
	var best := shoulder
	var best_d := -1.0
	for p: Vector2 in [Vector2(r.position), Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(r.end),
			Vector2(r.get_center().x, r.end.y), Vector2(r.end.x, r.get_center().y)]:
		var q := p - rig.anchor + Vector2(0, dip)
		var d := q.distance_squared_to(shoulder)
		if d > best_d:
			best_d = d
			best = q
	return best


# --- item -------------------------------------------------------------------------------

func _apply_item() -> void:
	if _item_sprite == null:
		return
	var tex := item.texture if item else null
	var stow := item.item_type().stow_style if item and item.item_type() else ItemTypeData.StowStyle.BACK
	for s: Sprite2D in [_item_sprite, _stow_back, _stow_hip]:
		s.texture = tex
		s.offset = -item.grip if item else Vector2.ZERO
	_item_sprite.visible = item != null and not stowed
	_stow_back.visible = item != null and stowed and stow == ItemTypeData.StowStyle.BACK
	_stow_hip.visible = item != null and stowed and stow == ItemTypeData.StowStyle.HIP


## Puts the item in the holding hand at the motion's angle.
func _place_item(m: ItemMotion, side: StringName, shoulder: Vector2, aim_angle: float = 0.0) -> void:
	var hand: Vector2 = hands.get(side, shoulder)
	var offset := deg_to_rad(m.item_angle_at(motion_t))
	match m.item_angle_mode:
		ItemMotion.ItemAngle.ARM:
			item_rotation = (hand - shoulder).angle() + offset
		ItemMotion.ItemAngle.AIM:
			item_rotation = ((to_local(aim_global) - hand).angle() if m.aims else aim_angle) + offset
		_:
			item_rotation = offset
	_item_sprite.position = hand
	# The texture points up-right (-45 degrees); turn that onto the item angle.
	_item_sprite.rotation = item_rotation + PI / 4.0


## A pixel of the item texture, in doll space, with the item where it is now.
func _grip_point(texture_px: Vector2) -> Vector2:
	return _item_sprite.position + (texture_px - item.grip).rotated(_item_sprite.rotation)


func _place_stowed(body_abs: int, shift: Vector2) -> void:
	if item == null:
		return
	var shoulder := _shoulder(&"front", body_abs, shift)
	_stow_back.position = shoulder + stow_back_offset
	_stow_back.rotation = deg_to_rad(stow_back_angle) + PI / 4.0
	_stow_hip.position = shoulder + stow_hip_offset
	_stow_hip.rotation = deg_to_rad(stow_hip_angle) + PI / 4.0


# --- look -------------------------------------------------------------------------------

func _apply_look() -> void:
	if _material == null:
		return
	var tex: ImageTexture = look.swap_texture(palette) if look and palette else null
	_material.set_shader_parameter(&"swap", tex)
	_material.set_shader_parameter(&"count", tex.get_width() if tex else 0)
	if _hair:
		_hair.texture = look.hair if look else null
