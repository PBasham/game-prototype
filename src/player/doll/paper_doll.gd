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
## Code-posed back arm uses the front arm's pieces (darkened by back_arm_shade). The
## rest pose is the 3/4 idle, where the back arm is drawn thin at the top for
## perspective; rotated into a side pose that reads as a swapped bicep and forearm. An
## "arms/Rest" tag drawn in side view fixes the source instead; then turn this off.
@export var back_arm_from_front := true
## Brightness of the back arm when it borrows the front arm's pieces (1 = same).
@export_range(0.3, 1.0) var back_arm_shade := 0.82
## Seconds the hands take to slide to a new pose when the motion changes (picking up,
## attacking, aiming, between combo hits), instead of jumping there.
@export var blend_time := 0.07

@export_group("Motion extras (render test)")
## Squash and stretch: a landing squashes the body (up to squash_land of its height,
## springing back over squash_time); rising fast stretches it a little.
@export var squash := false
@export var squash_land := 0.12
@export var squash_time := 0.2
@export var stretch_rise := 0.05
## Sway: hair (and an item on your back) swing behind your movement and settle, like a
## spring: stiffness, damping, and the most it swings (degrees).
@export var sway := false
@export var sway_stiffness := 90.0
@export var sway_damping := 9.0
@export var sway_max := 18.0
@export_group("")

@export_group("Poses (emotes)")
## Sitting on a chair: how high the seat is above the floor (px; the chair sets it).
@export var seat_height := 12.0
## Sitting on the floor: how high the hips rest (px), and how far out the near and far
## feet reach (share of the leg's length; the far leg bends its knee up).
@export var floor_hip_height := 3.0
@export var floor_reach := Vector2(0.92, 0.55)
## Waving: the arm's angle (degrees, 0 = ahead, -90 = up), how far it swings, how fast.
@export var wave_angle := -70.0
@export var wave_swing := 25.0
@export var wave_speed := 9.0
## Cheering: both arms up (degrees) and the hop (px).
@export var cheer_angles := Vector2(-105.0, -75.0)
@export var cheer_bounce := 2.0
@export_group("")

@export_group("Legs (rig test)")
## How the legs are drawn. DRAWN: the Aseprite frames as they are. PLANTED: standing,
## each foot is set on the ground under it (steps and slopes), the leg bent at the knee
## to reach (inverse kinematics, like the arms); running, the drawn frames, each leg
## nudged up or down to the ground under its foot. POSED: no leg frames at all: a walk
## cycle made in code (stride, lift), feet planted on the ground.
enum LegMode { DRAWN, PLANTED, POSED }
@export var leg_mode := LegMode.DRAWN
## POSED: how far a foot travels per step (px), how high it lifts, and how far apart
## the feet stand (px, front foot ahead).
@export var stride_px := 10.0
@export var step_lift_px := 3.0
@export var stance_px := 5.0
## PLANTED while running: the most a drawn leg is moved up or down (px).
@export var max_leg_nudge := 4.0
## In the air (POSED): how far the feet tuck up and forward.
@export var air_tuck := Vector2(2.0, -4.0)
## The most the hips may drop (px) so a foot can reach a lower step.
@export var max_hip_drop := 6.0
@export_group("")

## The ground under a point: called with a doll-local x (px, before the facing flip),
## returns the doll-local y of the ground there (0 = level with the feet), or INF if
## there's none. Set by the Player; without it, the ground is flat.
var ground_probe: Callable
## For POSED legs: how far the doll has walked (px, set by the Player each frame), and
## whether it's in the air.
var walked := 0.0
var airborne := false
## An emote pose (Player.emote): &"sit" (a chair), &"sit_floor", &"wave", &"cheer", or
## &"" for none. Sitting poses the legs in code whatever leg_mode is.
var pose: StringName = &""
## Drawn on its own pixel grid (DollCanvas): the node standing where the doll stands in
## the world (world positions go through it), and how big the doll is drawn there
## (sheet pixels per art pixel). Null and 1 when drawn straight into the world.
var world_node: Node2D
var draw_scale := 1.0
## Which way it faces (1 right, -1 left); the doll sets its own scale from this, the
## draw scale and squash and stretch.
var facing := 1
## How fast its owner is moving (world px per second), for squash, stretch and sway.
var velocity := Vector2.ZERO
var _squash_left := 0.0
var _squash_k := 0.0
var _sway_angle := 0.0
var _sway_speed := 0.0
var _pose_time := 0.0

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
## Overlay textures by group (an armor piece) and part index. A code-posed arm drawn
## with another part's pixels (back arm from the front arm) shows that part's overlay.
var _overlay_tex: Dictionary[StringName, Dictionary] = {}
## Hide the hair (a helmet is on).
var hair_hidden := false:
	set(v):
		hair_hidden = v
		if _hair:
			_hair.visible = not v
var _hair: Sprite2D
var _item_sprite: Sprite2D
var _stow_back: Sprite2D
var _stow_hip: Sprite2D
var _material: ShaderMaterial
var _head_part := -1
var _last_motion: ItemMotion
var _last_in_hand := false
var _blend_left := 0.0
var _from_hands: Dictionary[StringName, Vector2] = {}
## Hand positions (local) from the last update, for items, tests and debugging.
var hands: Dictionary[StringName, Vector2] = {}
## Item angle (radians) from the last update.
var item_rotation := 0.0


func setup(doll_rig: DollRig, doll_palette: CharacterPalette = null) -> void:
	rig = doll_rig
	palette = doll_palette
	# The doll moves its parts every frame (_process), not on physics ticks, so physics
	# interpolation would blend between stale part positions (items drawn at the feet,
	# arms in between poses). The Player body around it is still interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
## `group` ties together the overlays of one piece (an item id), so a code-posed arm
## that borrows another part's pixels also borrows that part's overlay.
func add_overlay(part_name: String, texture: Texture2D, group: StringName = &"") -> Sprite2D:
	var pi := rig.part_index(part_name)
	if pi < 0:
		push_warning("PaperDoll: no part named %s" % part_name)
		return null
	texture = upscaled(texture, rig.art_scale, rig.upscale_steps)
	var s := Sprite2D.new()
	s.texture = texture
	s.region_enabled = true
	s.centered = false
	s.use_parent_material = true
	s.set_meta(&"overlay_group", group)
	_slots[pi].add_child(s)
	_overlays[pi].append(s)
	if not _overlay_tex.has(group):
		_overlay_tex[group] = {}
	_overlay_tex[group][pi] = texture
	return s


func clear_overlays() -> void:
	for list in _overlays:
		for s: Sprite2D in list:
			s.queue_free()
		list.clear()
	_overlay_tex.clear()


## Dresses the doll in worn items (armor): each item's `wear` overlays, in order, and
## hides the hair under a helmet that `hides_hair`.
func wear(items: Array[ItemData]) -> void:
	clear_overlays()
	var hide := false
	for it in items:
		if it == null:
			continue
		for part: String in it.wear:
			add_overlay(part, it.wear[part], it.id)
		hide = hide or it.hides_hair
	hair_hidden = hide


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
	_pose_time += delta
	_blend_left = maxf(_blend_left - delta, 0.0)
	_update_extras(delta)
	_update()


## A landing (fall in tiles): squash, if squash is on.
func land(fall_tiles: float) -> void:
	if squash and fall_tiles >= 1.0:
		_squash_k = squash_land * clampf(fall_tiles / 8.0, 0.35, 1.0)
		_squash_left = squash_time


## Squash and stretch on the doll's scale, and the sway spring.
func _update_extras(delta: float) -> void:
	var sq := Vector2.ONE
	if squash:
		_squash_left = maxf(_squash_left - delta, 0.0)
		if _squash_left > 0.0:
			var t := _squash_left / maxf(squash_time, 0.01)
			var s := _squash_k * t * t
			sq = Vector2(1.0 + s * 0.6, 1.0 - s)
		elif velocity.y < -40.0:
			var st := clampf(-velocity.y / 400.0, 0.0, 1.0) * stretch_rise
			sq = Vector2(1.0 - st * 0.5, 1.0 + st)
	scale = Vector2(float(facing), 1.0) * draw_scale * sq
	if sway:
		# Swings back against the way you move (and up when falling), springing back.
		var target := clampf(-velocity.x * float(facing) * 0.03 + velocity.y * 0.01, -sway_max, sway_max)
		_sway_speed += ((target - _sway_angle) * sway_stiffness - _sway_speed * sway_damping) * delta
		_sway_angle = clampf(_sway_angle + _sway_speed * delta, -sway_max * 1.5, sway_max * 1.5)
	else:
		_sway_angle = 0.0
		_sway_speed = 0.0


## Sheet tag names for hand-drawn key poses. When the sheet has one (plain or "legs/"),
## that frame is shown for the pose instead of the code-posed legs.
const DRAWN_POSE_TAGS: Dictionary[StringName, String] = {
	&"sit": "Sit", &"sit_floor": "SitFloor",
}

## Use hand-drawn pose frames when the sheet has them (off to compare with code poses).
@export var use_drawn_poses := true


## The sheet frame drawn for the current pose, or -1 when the pose is code-posed.
func drawn_pose_frame() -> int:
	if not use_drawn_poses or pose == &"" or not DRAWN_POSE_TAGS.has(pose):
		return -1
	return rig.tag_range(&"legs", StringName(DRAWN_POSE_TAGS[pose])).x


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
	var drawn_pose := drawn_pose_frame()
	if drawn_pose >= 0:
		# Patrick drew this pose (tag "Sit" or "SitFloor"): show it as is.
		legs_abs = drawn_pose
		body_abs = drawn_pose
	var shift := Vector2(motion.lunge_at(motion_t) if motion else 0.0, dip)
	var in_hand := item != null and not stowed
	if motion != _last_motion or in_hand != _last_in_hand:
		# The pose changed: slide the hands from where they were.
		if not hands.is_empty() and blend_time > 0.0:
			_from_hands = hands.duplicate()
			_blend_left = blend_time
		_last_motion = motion
		_last_in_hand = in_hand
	hands.clear()

	var sitting := pose in [&"sit", &"sit_floor"] and rig.legs.size() == 2 and drawn_pose < 0
	if pose == &"cheer":
		shift.y -= absf(sin(_pose_time * 6.0)) * cheer_bounce
	var posed_legs := (leg_mode != LegMode.DRAWN or sitting) and rig.legs.size() == 2
	var nudge := {}
	if posed_legs and leg_mode == LegMode.PLANTED and (airborne or animation in [&"Jog", &"Jump"]):
		posed_legs = false  # running or jumping: the drawn frames (nudged onto the ground)
		if not airborne and ground_probe.is_valid() and rig.legs.size() == 2:
			for side: StringName in [&"front", &"back"]:
				var g: float = ground_probe.call((rig.drawn_feet[side][legs_abs] - rig.anchor).x)
				nudge[rig.legs[side].upper] = clampf(g, -max_leg_nudge, max_leg_nudge) if not is_inf(g) else 0.0
				nudge[rig.legs[side].lower] = nudge[rig.legs[side].upper]
	var feet := {}
	if sitting:
		feet = _sit_targets(body_abs)
		shift.y += feet[&"drop"]
	elif posed_legs:
		feet = _foot_targets(legs_abs, body_abs)
		shift.y += feet.get(&"drop", 0.0)  # hips lower so the low foot reaches its step
	for pi in rig.part_names.size():
		var ch := rig.part_channels[pi]
		if ch == &"legs":
			if not posed_legs:
				_show_frame(pi, legs_abs, Vector2(0.0, nudge.get(pi, 0.0)))
		elif ch == &"body":
			_show_frame(pi, body_abs, shift)
	if posed_legs:
		for side: StringName in [&"back", &"front"]:
			_pose_leg(side, body_abs, shift, feet[side])
	_pose_arms(legs_abs, body_abs, shift)

	if _hair and _hair.texture and _head_part >= 0:
		# Turned around the top middle of the hair (sway), drawn at 1 / art_scale.
		var hw := float(_hair.texture.get_width()) / rig.art_scale
		_hair.position = rig.head_pos[body_abs] + look.hair_offset - rig.anchor + shift + Vector2(hw * 0.5, 0.0)
		_hair.offset = Vector2(-_hair.texture.get_width() * 0.5, 0.0)
		_hair.rotation = deg_to_rad(_sway_angle)
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
	slot.modulate = Color.WHITE
	_set_region(pi, rig.region(pi, abs_frame), -rig.anchor)


func _set_region(pi: int, region: Rect2, offset: Vector2, source: int = -1) -> void:
	# `offset` is in art pixels; an upscaled sheet is drawn at 1 / art_scale.
	var k := float(rig.art_scale)
	offset *= k
	_sprites[pi].region_rect = region
	_sprites[pi].offset = offset
	_sprites[pi].scale = Vector2.ONE / k
	var src := source if source >= 0 else pi
	for s: Sprite2D in _overlays[pi]:
		if src != pi:
			var group: StringName = s.get_meta(&"overlay_group", &"")
			var tex: Texture2D = _overlay_tex.get(group, {}).get(src, null)
			s.visible = tex != null
			if tex:
				s.texture = tex
		else:
			var group: StringName = s.get_meta(&"overlay_group", &"")
			s.texture = _overlay_tex.get(group, {}).get(pi, s.texture)
			s.visible = true
		s.region_rect = Rect2(region.position.x, 0, region.size.x, region.size.y)
		s.offset = offset
		s.scale = Vector2.ONE / k


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
			var angle := _emote_arm_angle(side)
			if is_nan(angle) or not rig.arms.has(side):
				_natural(side, legs_abs, body_abs, shift)
				continue
			var arm: Dictionary = rig.arms[side]
			var shoulder := _shoulder(side, body_abs, shift)
			var length := ((arm.hand as Vector2) - (arm.shoulder as Vector2)).length()
			_reach(arm, _parts_of(_channel(side)), shoulder, shoulder + Vector2.from_angle(deg_to_rad(angle)) * length * 0.97)
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
		aim_angle = (world_to_doll(aim_global) - _shoulder(&"front", body_abs, shift)).angle()
		if m.aim_limit_degrees < 180.0:
			var lim := deg_to_rad(m.aim_limit_degrees)
			aim_angle = clampf(wrapf(aim_angle, -PI, PI), -lim, lim)
	for side: StringName in [holding, other]:
		var track: ArmTrack = m.front if side == &"front" else m.back
		var shoulder := _shoulder(side, body_abs, shift)
		var arm: Dictionary = rig.arms.get(side, {})
		var mode := track.mode if track else ArmTrack.Mode.NATURAL
		if arm.is_empty() or mode == ArmTrack.Mode.NATURAL or (mode == ArmTrack.Mode.GRIP and not in_hand):
			_natural(side, legs_abs, body_abs, shift)
		elif mode == ArmTrack.Mode.POSE:
			var length := ((arm.hand as Vector2) - (arm.shoulder as Vector2)).length()
			var base := aim_angle if track.follows_aim else 0.0
			var dir := Vector2.from_angle(base + deg_to_rad(track.angle_at(motion_t)))
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
	if not rig.arms.has(side):
		for pi in _parts_of(channel):
			_show_frame(pi, f, shift)
		return
	var shoulder := _shoulder(side, body_abs, shift)
	var hand := _drawn_hand(rig.arms[side], f, shoulder)
	if _blending(side):
		# Mid-blend: a code-posed arm sliding toward where the drawn arm's hand is.
		_reach(rig.arms[side], _parts_of(channel), shoulder, hand)
		return
	for pi in _parts_of(channel):
		_show_frame(pi, f, shift)
	hands[side] = hand


func _blending(side: StringName) -> bool:
	return _blend_left > 0.0 and _from_hands.has(side) and not force_posed


func _parts_of(channel: StringName) -> PackedInt32Array:
	var out := PackedInt32Array()
	for pi in rig.part_names.size():
		if rig.part_channels[pi] == channel:
			out.append(pi)
	return out


## Two-bone arm bent so the hand reaches `target` (clamped to the arm's length).
func _reach(arm: Dictionary, parts: PackedInt32Array, shoulder: Vector2, target: Vector2) -> void:
	var side := &"front" if rig.arms.get(&"front") == arm else &"back"
	if _blending(side):
		var k := 1.0 - _blend_left / blend_time
		target = _from_hands[side].lerp(target, k * k * (3.0 - 2.0 * k))
	var src := _bone_source(side)
	var s0: Vector2 = src.shoulder
	var e0: Vector2 = src.elbow
	var h0: Vector2 = src.hand
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
	var tint := Color(back_arm_shade, back_arm_shade, back_arm_shade) if src != arm else Color.WHITE
	_bone(arm.upper, s0, shoulder, a1 - (e0 - s0).angle(), src.upper, tint)
	_bone(arm.lower, e0, elbow, a2 - (h0 - e0).angle(), src.lower, tint)
	for pi in parts:
		# Any extra layers in the arm channel follow the lower arm.
		if pi != arm.upper and pi != arm.lower:
			_bone(pi, e0, elbow, a2 - (h0 - e0).angle())
	hands[side] = hand


## Draws a part from the rest frame, rotated by `rot` around `joint_rest` placed at `at`.
## `source` is the part whose pixels to draw (default: the part itself).
func _bone(pi: int, joint_rest: Vector2, at: Vector2, rot: float, source: int = -1, tint: Color = Color.WHITE) -> void:
	var slot := _slots[pi]
	slot.position = at
	slot.rotation = rot
	slot.modulate = tint
	_set_region(pi, rig.region(source if source >= 0 else pi, rig.rest_frame), -joint_rest, source)


## Which arm's pieces and joints a posed arm is drawn with.
func _bone_source(side: StringName) -> Dictionary:
	if side == &"back" and back_arm_from_front and rig.arms.has(&"front") and not rig.tags.has("arms/Rest"):
		return rig.arms[&"front"]
	return rig.arms[side]


## Hand position in a drawn frame: the end of the lower arm farthest from the shoulder.
func _drawn_hand(arm: Dictionary, abs_frame: int, shoulder: Vector2) -> Vector2:
	var r := rig.rect_base(arm.lower, abs_frame)
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
		s.scale = Vector2.ONE / float(item.detail if item else 1)
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
			item_rotation = ((world_to_doll(aim_global) - hand).angle() if m.aims else aim_angle) + offset
		_:
			item_rotation = offset
	_item_sprite.position = hand
	# The texture points up-right (-45 degrees); turn that onto the item angle.
	_item_sprite.rotation = item_rotation + PI / 4.0


## Where the held item is, in world space (the beam starts here).
func item_global_position() -> Vector2:
	return doll_to_world(_item_sprite.position) if _item_sprite else doll_to_world(Vector2.ZERO)


## A doll-space point (art pixels from the feet, facing right) in the world.
func doll_to_world(p: Vector2) -> Vector2:
	return world_node.to_global(p) if world_node else to_global(p)


## A world point in doll space.
func world_to_doll(p: Vector2) -> Vector2:
	return world_node.to_local(p) if world_node else to_local(p)


## A pixel of the item texture, in doll space, with the item where it is now.
func _grip_point(texture_px: Vector2) -> Vector2:
	return _item_sprite.position + ((texture_px - item.grip) / float(item.detail)).rotated(_item_sprite.rotation)


func _place_stowed(body_abs: int, shift: Vector2) -> void:
	if item == null:
		return
	var shoulder := _shoulder(&"front", body_abs, shift)
	_stow_back.position = shoulder + stow_back_offset
	_stow_back.rotation = deg_to_rad(stow_back_angle + _sway_angle * 0.5) + PI / 4.0
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
		_hair.texture = upscaled(look.hair, rig.art_scale, rig.upscale_steps) if look else null
		_hair.scale = Vector2.ONE / float(rig.art_scale)
		_hair.visible = not hair_hidden


# --- Legs posed in code (rig test) ---------------------------------------------------

## Where each foot goes (doll-local, the sole's middle), plus "drop": how much to lower
## the hips so both feet reach.
func _foot_targets(legs_abs: int, body_abs: int) -> Dictionary:
	var out := {}
	var lowest := 0.0
	for side: StringName in [&"front", &"back"]:
		var leg: Dictionary = rig.legs[side]
		var target: Vector2
		var lift := 0.0
		if leg_mode == LegMode.PLANTED:
			# Standing: the rest pose's foot, a little apart, set on the ground.
			target = Vector2(leg.foot) - rig.anchor
			target.x += stance_px * (0.5 if side == &"front" else -0.5)
		else:
			var rest: Vector2 = Vector2(leg.foot) - rig.anchor
			rest.x += stance_px * (0.5 if side == &"front" else -0.5)
			if airborne:
				target = rest + Vector2(air_tuck.x * (1.0 if side == &"front" else -0.5), air_tuck.y)
				out[side] = target
				continue
			# A two beat walk: each foot is on the ground half the cycle, sliding back,
			# then swings forward in an arc. Standing still, both feet stay put.
			var cycle := fposmod(walked / (stride_px * 2.0) + (0.0 if side == &"front" else 0.5), 1.0)
			if cycle < 0.5:
				target = rest + Vector2(lerpf(stride_px * 0.5, -stride_px * 0.5, cycle * 2.0), 0.0)
			else:
				var k := (cycle - 0.5) * 2.0
				lift = -sin(k * PI) * step_lift_px
				target = rest + Vector2(lerpf(-stride_px * 0.5, stride_px * 0.5, k), 0.0)
		if ground_probe.is_valid() and not airborne:
			var g: float = ground_probe.call(target.x)
			if not is_inf(g):
				target.y = g + lift
				lowest = maxf(lowest, g)
		else:
			target.y += 0.0
		out[side] = target
	out[&"drop"] = minf(lowest * 0.5, max_hip_drop) if lowest > 0.0 else 0.0
	return out


## Draws one leg bent at the knee to put its foot on `foot` (doll-local): hip from the
## rest frame, following the body's bob. The knee bends forward.
func _pose_leg(side: StringName, body_abs: int, shift: Vector2, foot: Vector2) -> void:
	var leg: Dictionary = rig.legs[side]
	var h0 := Vector2(leg.hip)
	var k0 := Vector2(leg.knee)
	var f0 := Vector2(leg.foot)
	var bob: Vector2 = rig.body_offset[body_abs] if body_abs < rig.body_offset.size() else Vector2.ZERO
	var hip := h0 - rig.anchor + Vector2(0.0, bob.y) + shift
	var l1 := (k0 - h0).length()
	var l2 := (f0 - k0).length()
	var to := foot - hip
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var bend := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var a1 := to.angle() - bend  # knee forward (counterclockwise of hip-to-foot)
	var knee := hip + Vector2.from_angle(a1) * l1
	var sole := hip + to.normalized() * d
	_bone(leg.upper, h0, hip, a1 - (k0 - h0).angle())
	_bone(leg.lower, k0, knee, (sole - knee).angle() - (f0 - k0).angle())


# --- Emote poses -----------------------------------------------------------------------

## Where an arm points for the current emote (degrees), or NAN to leave it natural.
func _emote_arm_angle(side: StringName) -> float:
	match pose:
		&"wave":
			return wave_angle + sin(_pose_time * wave_speed) * wave_swing if side == &"front" else NAN
		&"cheer":
			return cheer_angles.x if side == &"front" else cheer_angles.y
	return NAN


## Sitting: the hips come down to the seat (or the floor), and the feet go out ahead:
## on a chair, thighs level and shins down to the floor; on the floor, the near leg out
## long and the far one with its knee up. "drop" is how far the body comes down.
func _sit_targets(body_abs: int) -> Dictionary:
	var out := {}
	var hip_y := 0.0
	var l1 := 0.0
	var l2 := 0.0
	for side: StringName in [&"front", &"back"]:
		var leg: Dictionary = rig.legs[side]
		hip_y += (Vector2(leg.hip) - rig.anchor).y * 0.5
		l1 = maxf(l1, (Vector2(leg.knee) - Vector2(leg.hip)).length())
		l2 = maxf(l2, (Vector2(leg.foot) - Vector2(leg.knee)).length())
	var bob: Vector2 = rig.body_offset[body_abs] if body_abs < rig.body_offset.size() else Vector2.ZERO
	var seat := seat_height if pose == &"sit" else floor_hip_height
	var drop := maxf(-seat - (hip_y + bob.y), 0.0)
	out[&"drop"] = drop
	for side: StringName in [&"front", &"back"]:
		var leg: Dictionary = rig.legs[side]
		var hip_x := (Vector2(leg.hip) - rig.anchor).x
		var near := side == &"front"
		if pose == &"sit":
			out[side] = Vector2(hip_x + l1 * 0.95 + (1.0 if near else -1.0), 0.0)
		else:
			var reach := floor_reach.x if near else floor_reach.y
			out[side] = Vector2(hip_x + (l1 + l2) * reach, -1.0)
	return out


static var _upscaled: Dictionary = {}


## An overlay (armor, hair) drawn for an upscaled sheet: each pixel a k x k block (fast,
## at load). The sheet itself may be smoothed (Scale2x); overlays stay blocky for now.
static func upscaled(tex: Texture2D, k: int, steps: PackedStringArray = PackedStringArray()) -> Texture2D:
	if tex == null or k <= 1:
		return tex
	var key := "%s|%d|%s" % [tex.get_rid(), k, ",".join(steps)]
	if _upscaled.has(key):
		return _upscaled[key]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if steps.is_empty():
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	else:
		# The same steps as the body sheet (tools/upscale_doll.py): "n" doubles, "s" Scale2x.
		for step in steps:
			img = scale2x(img) if step == "s" else _nearest2x(img)
	var out := ImageTexture.create_from_image(img)
	_upscaled[key] = out
	return out


static func _nearest2x(img: Image) -> Image:
	var out := img.duplicate() as Image
	out.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return out


## Scale2x (EPX): doubles an image, rounding diagonals, using only its own colors (so the
## palette swap still works). Same rules as tools/upscale_doll.py.
static func scale2x(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := img.get_pixel(x, y)
			var a := img.get_pixel(x, y - 1) if y > 0 else Color(0, 0, 0, 0)  # outside: clear
			var b := img.get_pixel(x + 1, y) if x < w - 1 else Color(0, 0, 0, 0)
			var c := img.get_pixel(x - 1, y) if x > 0 else Color(0, 0, 0, 0)
			var d := img.get_pixel(x, y + 1) if y < h - 1 else Color(0, 0, 0, 0)
			var e0 := p
			var e1 := p
			var e2 := p
			var e3 := p
			if a != d and c != b:
				if c == a:
					e0 = a
				if a == b:
					e1 = b
				if d == c:
					e2 = c
				if b == d:
					e3 = d
			out.set_pixel(x * 2, y * 2, e0)
			out.set_pixel(x * 2 + 1, y * 2, e1)
			out.set_pixel(x * 2, y * 2 + 1, e2)
			out.set_pixel(x * 2 + 1, y * 2 + 1, e3)
	return out
