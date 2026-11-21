class_name Body3D
extends Node2D
## The 3D body (Phase 20 prototype, console `body 3d`): a character made of 3D parts,
## rendered small with hard shading into its own pixel canvas and shown in the world
## like a sprite, the way Dead Cells draws its characters.
##
## The PaperDoll still does the thinking: it is given this body's joints
## (`joints_override`), works out where the hands, the held item and the feet go, and
## draws the item; this node bends the 3D arms and legs to those points (two-bone IK in
## the side plane) and draws everything else. So every item, swing, spell and emote
## works on this body too.
##
## The placeholder is a mannequin built in code from simple shapes (`_build`), sized
## from the Scholar. A modeled character (Blender, glTF) replaces it later.
## Coordinates: doll space (art pixels from the feet, facing right, y down) maps to 3D
## as (x, -y), one unit per art pixel; the near side of the body is +z.

## Canvas size and where the feet are in it (art pixels).
@export var canvas_px := Vector2i(96, 96)
@export var origin_px := Vector2i(48, 84)

@export_group("Look")
## Shading bands: 2 (dark, light) or 3 (dark, middle, light).
@export_range(2, 3) var bands := 3:
	set(v):
		bands = v
		_apply_colors()
## A light edge around the picture, in the trim color (0 = none).
@export_range(0.0, 1.0) var trim := 0.55:
	set(v):
		trim = v
		if _show:
			(_show.material as ShaderMaterial).set_shader_parameter(&"strength", v)
## Direction toward the light, seen from the camera (x forward, y up, z toward you).
@export var light_dir := Vector3(0.55, 0.7, 0.3):
	set(v):
		light_dir = v
		_apply_colors()
## How much the far arm and leg are darkened (they're in the body's shadow).
@export_range(0.5, 1.0) var far_shade := 0.8
## How colors are handed to the 3D renderer so they come out as the palette's: "auto"
## picks by renderer (Compatibility: "srgb", Forward+ / Mobile: "as_is"). If the body's
## colors look too dark or washed out next to the world, try another (console
## `body colors as_is|srgb|linear`).
@export_enum("auto", "as_is", "srgb", "linear") var color_space := "auto":
	set(v):
		color_space = v
		_apply_colors()
@export_group("")

@export_group("Shape (art pixels)")
@export var hip_height := 31.0
@export var shoulder_height := 50.5
@export var thigh := 13.0
@export var shin := 17.5
@export var upper_arm := 10.5
@export var forearm := 10.0
@export var head_radius := 4.4
## How far apart the near and far limbs are, front to back.
@export var limb_depth := 4.0
## Robe: how far below the hips it hangs (along the thighs).
@export var robe_length := 10.0
@export_group("")

@export_group("Motion")
## Swing of free-hanging arms while walking (degrees at full stride).
@export var arm_swing := 28.0
## Turn the whole body a little toward the camera (degrees), for a 3/4 look.
@export var turn := 18.0
@export_group("")

var doll: PaperDoll
var _vp: SubViewport
var _root: Node3D
var _anchor: Node2D
var _show: Sprite2D
var _parts: Dictionary[StringName, MeshInstance3D] = {}
var _mats: Dictionary[StringName, ShaderMaterial] = {}  # per color group
var _far_mats: Dictionary[StringName, ShaderMaterial] = {}
var _palette: CharacterPalette
var _look: CharacterLook
var _dirty := true

const TOON := preload("res://src/player/body3d/toon.gdshader")
const TRIM := preload("res://src/player/body3d/trim.gdshader")
const GROUPS: Array[StringName] = [&"skin", &"hair", &"tunic", &"pants", &"leather", &"trim"]


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.name = "Body3DCanvas"
	_vp.size = canvas_px
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_vp.use_taa = false
	_vp.scaling_3d_scale = 1.0
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = float(canvas_px.y)
	# The feet (3D origin) land on origin_px.
	cam.position = Vector3(float(canvas_px.x) * 0.5 - origin_px.x, origin_px.y - float(canvas_px.y) * 0.5, 200.0)
	cam.far = 400.0
	_vp.add_child(cam)
	_anchor = Node2D.new()
	_anchor.name = "Body3DAnchor"
	add_child(_anchor)
	_show = Sprite2D.new()
	_show.name = "Body3DPicture"
	_show.centered = false
	_show.texture = _vp.get_texture()
	_show.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_show.position = -Vector2(origin_px)
	var m := ShaderMaterial.new()
	m.shader = TRIM
	m.set_shader_parameter(&"strength", trim)
	_show.material = m
	_anchor.add_child(_show)
	_build()
	_apply_colors()


## Follows a doll: takes over its body (the doll keeps drawing the held item).
func attach(d: PaperDoll) -> void:
	doll = d
	doll.joints_override = joints()
	doll.parts_hidden = true
	if not doll.posed.is_connected(_on_posed):
		doll.posed.connect(_on_posed)
	set_colors(doll.palette, doll.look)
	visible = true
	_on_posed()


## Gives the doll its own body back.
func detach() -> void:
	if doll:
		doll.joints_override = {}
		doll.parts_hidden = false
		if doll.posed.is_connected(_on_posed):
			doll.posed.disconnect(_on_posed)
	doll = null
	visible = false


func is_on() -> bool:
	return doll != null


## This body's joints at rest (doll space), for PaperDoll.joints_override.
func joints() -> Dictionary[StringName, Vector2]:
	var out: Dictionary[StringName, Vector2] = {}
	for side: StringName in [&"front", &"back"]:
		var near := side == &"front"
		var hx := 1.0 if near else 2.0
		out[StringName("hip_" + side)] = Vector2(hx, -hip_height)
		out[StringName("knee_" + side)] = Vector2(hx, -hip_height + thigh)
		out[StringName("foot_" + side)] = Vector2(hx + (1.0 if near else -1.0), 0.0)
		out[StringName("shoulder_" + side)] = Vector2(0.5 if near else 2.0, -shoulder_height)
	return out


## The colors: each group's dark, middle and light shades from the palette, recolored
## by the look (so the character creator's colors work).
func set_colors(palette: CharacterPalette, look: CharacterLook) -> void:
	_palette = palette
	_look = look
	_apply_colors()


func shades(group: StringName) -> PackedColorArray:
	var cols := PackedColorArray()
	if _palette and _palette.groups.has(group):
		cols = _palette.groups[group].duplicate()
	if cols.is_empty():
		cols = PackedColorArray([Color(0.5, 0.5, 0.5)])
	if _look and _look.colors.has(group):
		var ref := _palette.mid_color(group)
		for i in cols.size():
			cols[i] = CharacterLook.shade_onto(cols[i], ref, _look.colors[group])
	var n := cols.size()
	return PackedColorArray([cols[int((n - 1) * 0.15)], cols[n / 2], cols[int(round((n - 1) * 0.85))]])


func _process(_delta: float) -> void:
	if doll == null:
		return
	position = doll.position
	_anchor.scale = doll.scale
	_show.self_modulate = doll.modulate
	if _dirty:
		_dirty = false
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _on_posed() -> void:
	if doll == null:
		return
	pose_from(doll.pose_state)
	_dirty = true


# --- the mannequin -------------------------------------------------------------------

func _build() -> void:
	var capsule := func(r: float, group: StringName) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = r
		cm.height = r * 2.0 + 1.0
		cm.radial_segments = 12
		cm.rings = 4
		mi.mesh = cm
		mi.set_meta(&"group", group)
		mi.set_meta(&"r", r)
		return mi
	var add := func(part: StringName, mi: MeshInstance3D) -> void:
		mi.name = String(part)
		_root.add_child(mi)
		_parts[part] = mi
	for side: String in ["front", "back"]:
		add.call(StringName("thigh_" + side), capsule.call(2.5, &"pants"))
		add.call(StringName("shin_" + side), capsule.call(2.0, &"pants"))
		var boot := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(6.0, 3.0, 3.6)
		boot.mesh = bm
		boot.set_meta(&"group", &"leather")
		add.call(StringName("boot_" + side), boot)
		# The robe hangs over each thigh, so it follows the legs (walking, sitting).
		var robe := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 4.6
		rm.bottom_radius = 5.4
		rm.height = robe_length
		rm.radial_segments = 12
		robe.mesh = rm
		robe.set_meta(&"group", &"tunic")
		add.call(StringName("robe_" + side), robe)
		add.call(StringName("upper_arm_" + side), capsule.call(1.9, &"skin"))
		add.call(StringName("forearm_" + side), capsule.call(1.7, &"skin"))
		var hand := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 1.9
		hm.height = 3.8
		hm.radial_segments = 8
		hm.rings = 4
		hand.mesh = hm
		hand.set_meta(&"group", &"skin")
		add.call(StringName("hand_" + side), hand)
		var sleeve := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 2.8
		sm.height = 5.6
		sm.radial_segments = 10
		sm.rings = 5
		sleeve.mesh = sm
		sleeve.set_meta(&"group", &"tunic")
		add.call(StringName("sleeve_" + side), sleeve)
	var torso := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 5.0
	tm.bottom_radius = 4.4
	tm.height = 1.0  # stretched to the spine in pose_from
	tm.radial_segments = 14
	torso.mesh = tm
	torso.set_meta(&"group", &"tunic")
	add.call(&"torso", torso)
	var belt := MeshInstance3D.new()
	var blm := CylinderMesh.new()
	blm.top_radius = 4.7
	blm.bottom_radius = 4.7
	blm.height = 2.0
	blm.radial_segments = 14
	belt.mesh = blm
	belt.set_meta(&"group", &"leather")
	add.call(&"belt", belt)
	var neck: MeshInstance3D = capsule.call(1.5, &"skin")
	add.call(&"neck", neck)
	var head := MeshInstance3D.new()
	var hd := SphereMesh.new()
	hd.radius = head_radius
	hd.height = head_radius * 2.3
	hd.radial_segments = 16
	hd.rings = 8
	head.mesh = hd
	head.set_meta(&"group", &"skin")
	add.call(&"head", head)
	var hair := MeshInstance3D.new()
	var hr := SphereMesh.new()
	hr.radius = head_radius + 0.5
	hr.height = (head_radius + 0.5) * 1.5
	hr.radial_segments = 16
	hr.rings = 8
	hair.mesh = hr
	hair.set_meta(&"group", &"hair")
	add.call(&"hair", hair)
	var eye := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(0.6, 1.4, 1.0)
	eye.mesh = em
	eye.set_meta(&"group", &"eye")
	add.call(&"eye", eye)


func _apply_colors() -> void:
	if _parts.is_empty():
		return
	for g: StringName in GROUPS + [&"eye"]:
		for far in [false, true]:
			var m := ShaderMaterial.new()
			m.shader = TOON
			var sh := shades(g)
			if g == &"eye":
				sh = PackedColorArray([shades(&"leather")[0], shades(&"leather")[0], shades(&"leather")[0]])
			var k := far_shade if far else 1.0
			m.set_shader_parameter(&"dark", _dim(sh[0], k))
			m.set_shader_parameter(&"mid", _dim(sh[1], k))
			m.set_shader_parameter(&"light", _dim(sh[2], k))
			m.set_shader_parameter(&"light_dir", light_dir)
			m.set_shader_parameter(&"bands", bands)
			if far:
				_far_mats[g] = m
			else:
				_mats[g] = m
	for part: StringName in _parts:
		var mi := _parts[part]
		var g: StringName = mi.get_meta(&"group")
		mi.material_override = _far_mats[g] if String(part).ends_with("_back") else _mats[g]
	if _show:
		var t := shades(&"trim")
		(_show.material as ShaderMaterial).set_shader_parameter(&"trim_color", t[2])
	_dirty = true


func _dim(c: Color, k: float) -> Color:
	var out := Color(c.r * k, c.g * k, c.b * k, c.a)
	match color_mode():
		"srgb":
			return out.linear_to_srgb()
		"linear":
			return out.srgb_to_linear()
	return out


## The color_space in use ("auto" resolved by the renderer).
func color_mode() -> String:
	if color_space != "auto":
		return color_space
	return "srgb" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "as_is"


# --- posing --------------------------------------------------------------------------

## Doll space to 3D, at a depth.
static func to3(p: Vector2, z: float = 0.0) -> Vector3:
	return Vector3(p.x, -p.y, z)


## Bends the mannequin to a PaperDoll pose_state.
func pose_from(st: Dictionary[StringName, Vector2]) -> void:
	if not st.has(&"shoulder_front"):
		return
	var shift: Vector2 = st.get(&"shift", Vector2.ZERO)
	var hip_f: Vector2 = st.get(&"hip_front", Vector2(1, -hip_height) + shift)
	var hip_b: Vector2 = st.get(&"hip_back", Vector2(2, -hip_height) + shift)
	var hips := (hip_f + hip_b) * 0.5
	var shoulders := (st[&"shoulder_front"] + st[&"shoulder_back"]) * 0.5
	# The body: a tapered tube from the hips to the shoulders, belt, neck and head.
	_segment(&"torso", to3(hips + Vector2(0, -1.5)), to3(shoulders + Vector2(0, -1.0)), true)
	var belt := _parts[&"belt"]
	belt.transform = _along(to3(hips + Vector2(0, -2.5)), to3(shoulders), 1.0)
	belt.position = to3(hips + Vector2(0, -2.5))
	var neck_top := shoulders + Vector2(0.6, -3.2)
	_segment(&"neck", to3(shoulders), to3(neck_top))
	var head_c := neck_top + Vector2(0.4, -head_radius * 0.95)
	var head := _parts[&"head"]
	head.position = to3(head_c)
	head.rotation = Vector3(0, deg_to_rad(turn), 0)
	var hair := _parts[&"hair"]
	hair.position = to3(head_c + Vector2(-1.0, -1.7))
	hair.rotation = Vector3(0, deg_to_rad(turn), deg_to_rad(12.0))
	_parts[&"eye"].position = to3(head_c + Vector2(head_radius * 0.72, -0.2), head_radius * 0.62)

	var t := 0.0
	if doll:
		t = doll.walked / maxf(doll.stride_px * 2.0, 1.0) * TAU
	for side: StringName in [&"front", &"back"]:
		var near := side == &"front"
		var z := limb_depth * (1.0 if near else -1.0)
		# Legs: hip to foot, knee forward.
		var hip: Vector2 = st.get(StringName("hip_" + side), hips)
		var foot: Vector2 = st.get(StringName("foot_" + side), hip + Vector2(0, hip_height))
		var knee := _ik(hip, foot, thigh, shin, -1.0)
		_segment(StringName("thigh_" + side), to3(hip, z * 0.6), to3(knee, z * 0.6))
		_segment(StringName("shin_" + side), to3(knee, z * 0.6), to3(foot + Vector2(0, -1.5), z * 0.6))
		var boot := _parts[StringName("boot_" + side)]
		boot.position = to3(foot + Vector2(1.2, -1.5), z * 0.6)
		boot.rotation = Vector3.ZERO
		# The robe over the thigh, a little longer than it.
		var dir := (knee - hip).normalized()
		_segment_fixed(StringName("robe_" + side), to3(hip + Vector2(0, -1.0), z * 0.25), to3(hip + dir * robe_length, z * 0.25))
		# Arms: shoulder to hand, elbow back. Free arms swing with the walk.
		var sh: Vector2 = st[StringName("shoulder_" + side)]
		var hand: Vector2
		var reach := upper_arm + forearm
		if doll and doll.arm_is_natural(side) or not st.has(StringName("hand_" + side)):
			var swing := 0.0
			if doll and not doll.airborne:
				swing = sin(t + (0.0 if near else PI)) * deg_to_rad(arm_swing) * clampf(absf(doll.velocity.x) / 60.0, 0.0, 1.0)
			hand = sh + Vector2(0, reach * 0.96).rotated(-swing)
			hand.x += 1.0
		else:
			hand = st[StringName("hand_" + side)]
		var elbow := _ik(sh, hand, upper_arm, forearm, 1.0)
		var zz := z * 1.25
		_segment(StringName("upper_arm_" + side), to3(sh, zz), to3(elbow, zz))
		var hand_at := sh + (hand - sh).limit_length(reach - 0.01)
		_segment(StringName("forearm_" + side), to3(elbow, zz), to3(hand_at, zz))
		_parts[StringName("hand_" + side)].position = to3(hand_at, zz)
		_parts[StringName("sleeve_" + side)].position = to3(sh + Vector2(0, 1.0), zz * 0.8)


## Two-bone IK in the side plane: the middle joint, bent toward `bend` (-1 forward /
## counterclockwise of root-to-end on screen, like the knee; 1 the other way, the elbow).
static func _ik(root: Vector2, end: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var to := end - root
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var ang := to.angle() + (a if bend > 0.0 else -a)
	return root + Vector2.from_angle(ang) * l1


## A transform whose Y axis runs from a to b (length scaled by `stretch` / mesh height).
static func _along(a: Vector3, b: Vector3, y_scale: float) -> Transform3D:
	var y := b - a
	var len := maxf(y.length(), 0.001)
	var yd := y / len
	var zd := Vector3(0, 0, 1)
	var xd := yd.cross(zd)
	if xd.length() < 0.001:
		xd = Vector3(1, 0, 0)
	xd = xd.normalized()
	zd = xd.cross(yd).normalized()
	return Transform3D(Basis(xd, yd * y_scale, zd), (a + b) * 0.5)


## A capsule (or the torso tube) stretched from a to b.
func _segment(part: StringName, a: Vector3, b: Vector3, tube: bool = false) -> void:
	var mi := _parts[part]
	var len := a.distance_to(b)
	if tube:
		(mi.mesh as CylinderMesh).height = maxf(len, 0.5)
		mi.transform = _along(a, b, 1.0)
		mi.rotate_object_local(Vector3.UP, deg_to_rad(turn))
		return
	var r: float = mi.get_meta(&"r", 1.0)
	(mi.mesh as CapsuleMesh).height = maxf(len + r * 2.0, r * 2.0 + 0.01)
	mi.transform = _along(a, b, 1.0)


## A mesh of fixed length placed along a to b (b sets the direction only).
func _segment_fixed(part: StringName, a: Vector3, b: Vector3) -> void:
	_parts[part].transform = _along(a, b, 1.0)
