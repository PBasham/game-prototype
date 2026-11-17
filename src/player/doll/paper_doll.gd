class_name PaperDoll
extends Node2D
## The character drawn as separate body parts (a paper doll), each picking its own frame:
##
##   legs       play the movement animation (Breath, Jog, Jump...)
##   body       torso and head follow the legs' frame (or their own "body/" tags)
##   arms       depend on the arm mode:
##                SWING  follow the legs (or "arms/<anim>" tags)
##                HOLD   "arms/Hold1H" / "arms/Hold2H" if drawn, else code-posed
##                USE    "arms/Use" if drawn, else the arm swings in an arc (code)
##                AIM    arms rotate around the shoulder toward aim_point (code)
##
## "Code-posed" arms use the upper and lower arm layers as two bones (shoulder and
## elbow joints measured from the art) and bend them to reach a point. force_posed
## shows code posing even where drawn frames exist, to compare.
##
## The held item is drawn in the front hand; stowed (put away) it sits on the back,
## at the hip, or is hidden, per its HeldItemLook. Colors come from CharacterLook via a
## palette-swap shader. Facing: set `scale.x` to 1 (right) or -1 (left); the art faces
## right. Origin = feet.
##
## Everything is driven by setting properties each frame; see Player._animate().

enum ArmMode { SWING, HOLD, USE, AIM }

const SWAP_SHADER := preload("res://src/player/doll/palette_swap.gdshader")

@export_group("Code-posed arms")
## Show code-posed arms even when drawn hold/use frames exist (to compare).
@export var force_posed := false
## Where the front hand goes when holding one-handed, from the shoulder (pixels).
@export var one_hand_reach := Vector2(6, 13)
## Where the front hand goes when holding two-handed, from the shoulder.
@export var two_hand_reach := Vector2(8, 11)
## Elbows bend downward (true) or upward.
@export var elbow_down := true
@export_group("Stowed item")
## Item on the back: position from the front shoulder (pixels) and angle (degrees).
@export var stow_back_offset := Vector2(-6, 9)
@export var stow_back_angle := -110.0
## Item at the hip.
@export var stow_hip_offset := Vector2(3, 20)
@export var stow_hip_angle := 105.0
@export_group("")

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
var arm_mode := ArmMode.SWING
## Point the arms aim at (AIM mode), in global coordinates.
var aim_global := Vector2.ZERO
## 0..1 through a use (swing) in USE mode.
var use_progress := 0.0
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
var _overlays: Array[Array] = []  ## per part: [Sprite2D, follow_frames: bool]
var _hair: Sprite2D
var _item_sprite: Sprite2D
var _stow_back: Sprite2D
var _stow_hip: Sprite2D
var _material: ShaderMaterial
var _head_part := -1
## Last computed hand positions (local), for debugging and tests.
var hands: Dictionary[StringName, Vector2] = {}


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


# --- per frame ------------------------------------------------------------------

func _update() -> void:
	var legs_r := rig.tag_range(&"legs", animation)
	if legs_r.x < 0:
		legs_r = Vector2i(0, 0)
	var count := legs_r.y - legs_r.x + 1
	frame = clampi(frame, 0, count - 1)
	var legs_abs := legs_r.x + frame
	var body_abs := _follow(&"body", legs_abs)
	var up := Vector2(0, dip)
	hands.clear()

	for pi in rig.part_names.size():
		var ch := rig.part_channels[pi]
		if ch == &"legs":
			_show_frame(pi, legs_abs, Vector2.ZERO)
		elif ch == &"body":
			_show_frame(pi, body_abs, up)
	# Front first: a two-handed item's second grip depends on where the front hand is.
	for side: StringName in [&"front", &"back"]:
		_pose_arm(side, legs_abs, body_abs)

	if _hair and _hair.texture and _head_part >= 0:
		_hair.position = rig.head_pos[body_abs] + look.hair_offset - rig.anchor + up
	_place_item(body_abs)


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


## Draws one arm for the current mode.
func _pose_arm(side: StringName, legs_abs: int, body_abs: int) -> void:
	var channel := &"front_arm" if side == &"front" else &"back_arm"
	var parts := _parts_of(channel)
	var up := Vector2(0, dip)
	var arm: Dictionary = rig.arms.get(side, {})
	var shoulder := Vector2.ZERO
	if not arm.is_empty():
		shoulder = (arm.shoulder as Vector2) + rig.body_offset[body_abs] - rig.anchor + up

	var mode := arm_mode
	if item == null or stowed:
		if mode != ArmMode.AIM and mode != ArmMode.USE:
			mode = ArmMode.SWING
	var two_hand := item != null and not stowed and item.hold_style == HeldItemLook.HoldStyle.TWO_HAND

	# Drawn frames win unless force_posed.
	var drawn_tag := &""
	match mode:
		ArmMode.HOLD:
			drawn_tag = &"Hold2H" if two_hand else &"Hold1H"
		ArmMode.USE:
			drawn_tag = &"Use"
	if mode == ArmMode.SWING or arm.is_empty() or (drawn_tag != &"" and not force_posed and _has_arm_tag(drawn_tag)):
		var abs_frame := _follow(channel, legs_abs)
		if drawn_tag != &"" and mode != ArmMode.SWING and _has_arm_tag(drawn_tag):
			var r := rig.tag_range(channel, drawn_tag)
			var n := r.y - r.x + 1
			var t := use_progress if mode == ArmMode.USE else 0.0
			abs_frame = r.x + mini(int(t * n), n - 1)
		for pi in parts:
			_show_frame(pi, abs_frame, up)
		if not arm.is_empty():
			hands[side] = _drawn_hand(arm, abs_frame, shoulder)
		return

	# Code-posed.
	var front_shoulder := shoulder
	if side == &"back" and rig.arms.has(&"front"):
		front_shoulder = (rig.arms[&"front"].shoulder as Vector2) + rig.body_offset[body_abs] - rig.anchor + up
	match mode:
		ArmMode.AIM:
			var target := to_local(aim_global)
			if side == &"back" and two_hand and _item_sprite.visible:
				_reach(arm, parts, shoulder, _second_grip())
			else:
				_rigid(arm, parts, shoulder, (target - shoulder).angle())
		ArmMode.USE:
			var a := deg_to_rad(lerpf(item.swing_from if item else -140.0, item.swing_to if item else 30.0, _ease(use_progress)))
			if side == &"front" or not two_hand:
				if side == &"front":
					_rigid(arm, parts, shoulder, a)
				else:
					var abs_frame := _follow(channel, legs_abs)
					for pi in parts:
						_show_frame(pi, abs_frame, up)
					hands[side] = _drawn_hand(arm, abs_frame, shoulder)
			else:
				_reach(arm, parts, shoulder, _second_grip_for(front_shoulder, a))
		ArmMode.HOLD:
			if side == &"front":
				_reach(arm, parts, shoulder, shoulder + (two_hand_reach if two_hand else one_hand_reach))
			elif two_hand:
				_reach(arm, parts, shoulder, _second_grip_for_hold(front_shoulder))
			else:
				var abs_frame := _follow(channel, legs_abs)
				for pi in parts:
					_show_frame(pi, abs_frame, up)
				hands[side] = _drawn_hand(arm, abs_frame, shoulder)


func _has_arm_tag(tag: StringName) -> bool:
	return rig.tags.has("arms/%s" % tag)


func _parts_of(channel: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	for pi in rig.part_names.size():
		if rig.part_channels[pi] == channel:
			out.append(pi)
	return out


## Whole arm rotated stiffly around the shoulder so it points along `angle` (radians,
## 0 = forward, positive = downward).
func _rigid(arm: Dictionary, parts: PackedInt32Array, shoulder: Vector2, angle: float) -> void:
	var s0: Vector2 = arm.shoulder
	var e0: Vector2 = arm.elbow
	var h0: Vector2 = arm.hand
	var rot := angle - (h0 - s0).angle()
	_bone(arm.upper, s0, shoulder, rot)
	var elbow := shoulder + (e0 - s0).rotated(rot)
	_bone(arm.lower, e0, elbow, rot)
	_hide_other(parts, arm)
	hands[_side_of(arm)] = elbow + (h0 - e0).rotated(rot)


## Two-bone arm bent so the hand reaches `target` (clamped to the arm's length).
func _reach(arm: Dictionary, parts: PackedInt32Array, shoulder: Vector2, target: Vector2) -> void:
	var s0: Vector2 = arm.shoulder
	var e0: Vector2 = arm.elbow
	var h0: Vector2 = arm.hand
	var l1 := (e0 - s0).length()
	var l2 := (h0 - e0).length()
	var to := target - shoulder
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var base := to.angle()
	var bend := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	# Elbow below the shoulder-hand line: bend toward +y.
	var a1 := base + (bend if elbow_down == (cos(base) >= 0.0) else -bend)
	var elbow := shoulder + Vector2.from_angle(a1) * l1
	var hand := shoulder + to.normalized() * d
	var a2 := (hand - elbow).angle()
	_bone(arm.upper, s0, shoulder, a1 - (e0 - s0).angle())
	_bone(arm.lower, e0, elbow, a2 - (h0 - e0).angle())
	_hide_other(parts, arm)
	hands[_side_of(arm)] = hand


## Draws a part from the rest frame, rotated by `rot` around `joint_rest` placed at `at`.
func _bone(pi: int, joint_rest: Vector2, at: Vector2, rot: float) -> void:
	var slot := _slots[pi]
	slot.position = at
	slot.rotation = rot
	_set_region(pi, rig.region(pi, rig.rest_frame), -joint_rest)


func _hide_other(parts: PackedInt32Array, arm: Dictionary) -> void:
	# Any extra layers in the arm channel (not upper/lower) follow the lower arm.
	for pi in parts:
		if pi != arm.upper and pi != arm.lower:
			_slots[pi].position = _slots[arm.lower].position
			_slots[pi].rotation = _slots[arm.lower].rotation
			_set_region(pi, rig.region(pi, rig.rest_frame), _sprites[arm.lower].offset)


func _side_of(arm: Dictionary) -> StringName:
	return &"front" if rig.arms.get(&"front") == arm else &"back"


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


# --- item ---------------------------------------------------------------------------

func _apply_item() -> void:
	if _item_sprite == null:
		return
	var tex := item.texture if item else null
	for s: Sprite2D in [_item_sprite, _stow_back, _stow_hip]:
		s.texture = tex
		s.offset = -item.grip if item else Vector2.ZERO
	_item_sprite.visible = item != null and not stowed
	_stow_back.visible = item != null and stowed and item.stow_style == HeldItemLook.StowStyle.BACK
	_stow_hip.visible = item != null and stowed and item.stow_style == HeldItemLook.StowStyle.HIP


## Item axis angle (radians): which way the item points right now.
func item_angle() -> float:
	if item == null:
		return 0.0
	match arm_mode:
		ArmMode.USE:
			return deg_to_rad(lerpf(item.swing_from, item.swing_to, _ease(use_progress)))
		ArmMode.AIM:
			if hands.has(&"front") and rig.arms.has(&"front"):
				return (to_local(aim_global) - hands[&"front"]).angle()
	return deg_to_rad(item.hold_angle)


func _place_item(body_abs: int) -> void:
	if item == null:
		return
	# Texture points up-right (-45 degrees); rotate that onto the item angle.
	var rot := item_angle() + PI / 4.0
	if _item_sprite.visible:
		_item_sprite.position = hands.get(&"front", Vector2.ZERO)
		_item_sprite.rotation = rot
	var shoulder := Vector2.ZERO
	if rig.arms.has(&"front"):
		shoulder = (rig.arms[&"front"].shoulder as Vector2) + rig.body_offset[body_abs] - rig.anchor + Vector2(0, dip)
	_stow_back.position = shoulder + stow_back_offset
	_stow_back.rotation = deg_to_rad(stow_back_angle) + PI / 4.0
	_stow_hip.position = shoulder + stow_hip_offset
	_stow_hip.rotation = deg_to_rad(stow_hip_angle) + PI / 4.0


## Where the back hand goes on a two-handed item held by a front hand at `hand`,
## pointing along `angle`.
func _grip2_at(hand: Vector2, angle: float) -> Vector2:
	return hand + (item.grip2 - item.grip).rotated(angle + PI / 4.0)


func _second_grip() -> Vector2:
	return _grip2_at(hands.get(&"front", Vector2.ZERO), item_angle())


func _second_grip_for(front_shoulder: Vector2, arm_angle: float) -> Vector2:
	var arm: Dictionary = rig.arms[&"front"]
	var reach := ((arm.hand as Vector2) - (arm.shoulder as Vector2)).length()
	var hand := front_shoulder + Vector2.from_angle(arm_angle) * reach
	return _grip2_at(hand, arm_angle)


func _second_grip_for_hold(front_shoulder: Vector2) -> Vector2:
	return _grip2_at(front_shoulder + two_hand_reach, deg_to_rad(item.hold_angle))


static func _ease(t: float) -> float:
	# Fast through the middle of the swing, like a real swing.
	return 0.5 - 0.5 * cos(PI * clampf(t, 0.0, 1.0))


# --- look -----------------------------------------------------------------------------

func _apply_look() -> void:
	if _material == null:
		return
	var tex: ImageTexture = look.swap_texture(palette) if look and palette else null
	_material.set_shader_parameter(&"swap", tex)
	_material.set_shader_parameter(&"count", tex.get_width() if tex else 0)
	if _hair:
		_hair.texture = look.hair if look else null
