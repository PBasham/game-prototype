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

## Render pixels per art pixel: 1 = the Scholar's pixel size, 2 = the detailed art size
## (like the 128x128 terrain and 32x32 icons), 3 or 4 finer still. Same size on screen.
@export_range(1, 4) var detail := 2:
	set(v):
		detail = clampi(v, 1, 4)
		_apply_detail()

## Shape style (console `body style`): "fit" (shaped like a fit body: muscle profiles
## along each limb and the torso, smooth), "blocky" (4-sided panels, flat faces), "soft"
## (8-sided, flat faces), "round" (simple tubes with ball joints).
## "model": your Blender character (model_path), see docs/3d-character.md.
@export_enum("model", "fit", "blocky", "soft", "round") var style := "model":
	set(v):
		style = v
		if _root:
			_rebuild()

## Your character, exported from Blender as glTF (.glb). If it isn't there yet, the
## placeholder mannequin (made by tools/make_test_body.gd) is used.
@export_file("*.glb", "*.gltf") var model_path := "res://assets/body3d/scholar.glb"
const PLACEHOLDER_MODEL := "res://assets/body3d/mannequin.glb"
## How tall the model is drawn (art pixels, the Scholar is 63).
@export var model_height := 63.0

@export_group("Look")
## Shading bands: 2 (shadow, light), 3 (shadow, base, light), 4 (deep shadow too).
@export_range(2, 4) var bands := 3:
	set(v):
		bands = v
		_apply_colors()
## A light edge around the picture, in the trim color (0 = none).
@export_range(0.0, 1.0) var trim := 0.0:
	set(v):
		trim = v
		if _show:
			(_show.material as ShaderMaterial).set_shader_parameter(&"strength", v)
## The light line around the tunic (art pixels; 0 = none), like the drawn trim.
@export_range(0.0, 2.0) var trim_width := 0.55:
	set(v):
		trim_width = v
		_apply_colors()
## Direction toward the light, seen from the camera (x forward, y up, z toward you).
@export var light_dir := Vector3(0.3, 0.85, 0.2):
	set(v):
		light_dir = v
		_apply_colors()
## How much the far arm and leg are darkened (they're in the body's shadow).
@export_range(0.5, 1.0) var far_shade := 0.82
## Hue shift (0..1 of the color wheel, 0.04 is about 14 degrees): shadows turn toward
## cool violet, the light shade toward warm yellow, like hand-shaded pixel art.
@export_range(0.0, 0.15) var hue_shift := 0.02:
	set(v):
		hue_shift = v
		_apply_colors()
## The deep shadow: the palette's darkest shade times this.
@export_range(0.4, 1.0) var deep_shadow := 0.72:
	set(v):
		deep_shadow = v
		_apply_colors()
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
@export var head_radius := 4.2
## Robe: how far below the hips it hangs (along the thighs).
@export var robe_length := 12.0
@export_group("")

@export_group("Motion")
## Swing of free-hanging arms while walking (degrees at full stride).
@export var arm_swing := 28.0
## How far the body turns toward you (degrees): standing (3/4, like the drawn idle) and
## moving or sitting (closer to side on, like the drawn run). It eases between them.
@export var turn_idle := 45.0
@export var turn_moving := 15.0
## How fast it turns between the two (per second).
@export var turn_speed := 6.0
## Half the shoulders' and hips' width, and the torso's width and depth (radius scale).
@export var shoulder_half := 5.2
@export var hip_half := 2.6
## How far apart the feet stand in the 3/4 idle (art pixels).
@export var stance_apart := 12.0
@export var torso_width := 1.0
@export var torso_depth := 0.62
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
var _cam: Camera3D
# The loaded model (style "model"): its root (turned and scaled), skeleton, bones by
# role (see BONE_NAMES), rest joints in art pixels (facing +Z), and its meshes.
var _model: Node3D
var _skel: Skeleton3D
var _bones: Dictionary[StringName, int] = {}
var _rest: Dictionary[StringName, Vector3] = {}
var _model_meshes: Array[MeshInstance3D] = []
var model_file := ""  ## the file actually loaded
## The turn right now (degrees), between turn_moving and turn_idle.
var turn := 50.0

const TOON := preload("res://src/player/body3d/toon.gdshader")
const TRIM := preload("res://src/player/body3d/trim.gdshader")
const HULL := preload("res://src/player/body3d/hull.gdshader")
const GROUPS: Array[StringName] = [&"skin", &"hair", &"tunic", &"pants", &"leather", &"trim"]
## Hues shadows and light lean toward (cool violet, warm yellow).
const COOL_HUE := 0.70
const WARM_HUE := 0.14


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.name = "Body3DCanvas"
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
	_cam = cam
	var m := ShaderMaterial.new()
	m.shader = TRIM
	m.set_shader_parameter(&"strength", trim)
	_show.material = m
	_anchor.add_child(_show)
	_build()
	_apply_colors()
	_apply_detail()


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
## Turned toward you, the near shoulder and hip (+z) move back on screen (-x) and the
## far ones forward, as in the drawn 3/4 idle.
func joints() -> Dictionary[StringName, Vector2]:
	if _skel:
		return _model_joints()
	var out: Dictionary[StringName, Vector2] = {}
	var st := sin(deg_to_rad(turn))
	for side: StringName in [&"front", &"back"]:
		var k := -1.0 if side == &"front" else 1.0
		var hx := 1.5 + hip_half * st * k
		out[StringName("hip_" + side)] = Vector2(hx, -hip_height)
		out[StringName("knee_" + side)] = Vector2(hx, -hip_height + thigh)
		# Standing 3/4, the feet are apart like the drawn idle (near one out to the back).
		out[StringName("foot_" + side)] = Vector2(hx + (-stance_apart if side == &"front" else stance_apart * 0.3) * st, 0.0)
		out[StringName("shoulder_" + side)] = Vector2(1.2 + shoulder_half * st * k, -shoulder_height)
	return out


## How far a near (+1) or far (-1) joint sits toward you.
func _depth(half: float, near: bool) -> float:
	return half * cos(deg_to_rad(turn)) * (1.0 if near else -1.0)


## The colors: each group's dark, middle and light shades from the palette, recolored
## by the look (so the character creator's colors work).
func set_colors(palette: CharacterPalette, look: CharacterLook) -> void:
	_palette = palette
	_look = look
	_apply_colors()


## A group's four shades (deep shadow, shadow, base, light): the palette's darkest,
## middle and lightest colors (recolored by the look), hue shifted, plus a deeper shadow.
func shades(group: StringName) -> PackedColorArray:
	var cols := PackedColorArray()
	if _palette and _palette.groups.has(group):
		cols = _palette.groups[group].duplicate()
	if cols.is_empty():
		cols = PackedColorArray([Color(0.5, 0.5, 0.5)])
	if _look and _look.colors.has(group) and _palette:
		var ref := _palette.mid_color(group)
		for i in cols.size():
			cols[i] = CharacterLook.shade_onto(cols[i], ref, _look.colors[group])
	var sorted := Array(cols)
	sorted.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	var darkest: Color = sorted[0]
	var lightest: Color = sorted[-1]
	var base: Color = sorted[sorted.size() / 2]
	if _palette and _palette.groups.has(group):
		base = _palette.mid_color(group)
		if _look and _look.colors.has(group):
			base = CharacterLook.shade_onto(base, base, _look.colors[group])
	if sorted.size() < 3:
		# One or two colors (trim): make a shadow and a light from them.
		darkest = Color.from_hsv(base.h, base.s, base.v * 0.82, base.a)
		lightest = Color.from_hsv(base.h, base.s * 0.85, minf(base.v * 1.08, 1.0), base.a)
	var shadow := _shift(darkest, COOL_HUE, hue_shift * 0.6, 1.05)
	var deep := _shift(Color.from_hsv(darkest.h, darkest.s, darkest.v * deep_shadow, darkest.a), COOL_HUE, hue_shift, 1.1)
	var light := _shift(lightest, WARM_HUE, hue_shift, 0.92)
	if group == &"hair":
		light = base.lerp(lightest, 0.4)  # the drawn hair is dark with a soft highlight
	return PackedColorArray([deep, shadow, base, light])


## Turns a color's hue toward `target` (the short way round) by at most `amount`, and
## scales its saturation.
static func _shift(c: Color, target: float, amount: float, sat: float) -> Color:
	var d := wrapf(target - c.h, -0.5, 0.5)
	var h := fposmod(c.h + clampf(d, -amount, amount), 1.0)
	return Color.from_hsv(h, clampf(c.s * sat, 0.0, 1.0), c.v, c.a)


func _process(delta: float) -> void:
	if doll == null:
		return
	var moving := absf(doll.velocity.x) > 12.0 or doll.airborne or doll.pose in [&"sit", &"sit_floor"]
	var want := turn_moving if moving else turn_idle
	if not is_equal_approx(turn, want):
		turn = move_toward(turn, want, absf(turn_idle - turn_moving) * turn_speed * delta)
		doll.joints_override = joints()
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
# Shapes, in art pixels. "prism" is a 4-sided tapered box (flat panels, like the drawn
# tunic), "tube" a 6-sided tapered limb, from a to b (half width at a, at b).

func _mesh_part(part: StringName, mesh: Mesh, group: StringName) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = String(part)
	mi.mesh = mesh
	mi.set_meta(&"group", group)
	_root.add_child(mi)
	_parts[part] = mi
	return mi


## Sides for panels (tunic, head) and limbs, per style.
const PANEL_SIDES := {"blocky": 4, "soft": 8, "round": 20, "fit": 8}
const LIMB_SIDES := {"blocky": 6, "soft": 8, "round": 16}


func _tube(part: StringName, r_a: float, r_b: float, group: StringName, segments: int = -1) -> void:
	if segments < 0:
		segments = LIMB_SIDES.get(style, 8)
	var m := CylinderMesh.new()
	m.bottom_radius = r_a
	m.top_radius = r_b
	m.height = 1.0
	m.radial_segments = segments
	m.rings = 1
	_mesh_part(part, m, group)


## A 4-sided box from half widths (bottom, top); posed with _box_between.
func _prism(part: StringName, half_a: float, half_b: float, group: StringName) -> void:
	var sides: int = PANEL_SIDES.get(style, 8)
	# The corner radius that puts the flat faces at the half width; round: a bit fuller.
	var k := 1.0 / cos(PI / float(sides)) if sides < 12 else 1.12
	_tube(part, half_a * k, half_b * k, group, sides)
	_parts[part].set_meta(&"prism", sides)


## Builds the mannequin again (after a style change).
func _rebuild() -> void:
	for mi: MeshInstance3D in _parts.values():
		mi.free()
	_parts.clear()
	if _model:
		_model.free()
		_model = null
	_skel = null
	_bones.clear()
	_model_meshes.clear()
	_build()
	_apply_colors()
	if doll:
		pose_from(doll.pose_state)


## Muscle profiles for the "fit" style: (t along the bone 0..1, radius in art pixels).
## Shoulders and forearms bulge, elbows and wrists narrow, the calf swells, the leg ends
## in a point; the torso is broad at the chest and narrow at the waist.
const FIT := {
	&"upper_arm": [Vector2(0, 2.6), Vector2(0.12, 3.05), Vector2(0.35, 2.85), Vector2(0.6, 2.5), Vector2(0.85, 2.05), Vector2(1, 1.9)],
	&"forearm": [Vector2(0, 1.9), Vector2(0.2, 2.3), Vector2(0.45, 2.1), Vector2(0.8, 1.6), Vector2(1, 1.45)],
	&"hand": [Vector2(0, 1.45), Vector2(0.35, 1.8), Vector2(0.8, 1.55), Vector2(1, 0.5)],
	&"thigh": [Vector2(0, 3.7), Vector2(0.25, 3.6), Vector2(0.6, 3.1), Vector2(0.9, 2.55), Vector2(1, 2.45)],
	&"shin": [Vector2(0, 2.45), Vector2(0.2, 2.85), Vector2(0.45, 2.6), Vector2(0.8, 1.9), Vector2(1, 1.6)],
	&"tip": [Vector2(0, 1.65), Vector2(0.5, 0.95), Vector2(1, 0.05)],
	&"torso": [Vector2(0, 5.0), Vector2(0.22, 4.5), Vector2(0.5, 5.3), Vector2(0.75, 6.1), Vector2(0.9, 6.3), Vector2(0.97, 5.5), Vector2(1, 3.4)],
	&"belt": [Vector2(0, 4.85), Vector2(1, 4.85)],
	&"neck": [Vector2(0, 2.1), Vector2(0.6, 1.85), Vector2(1, 1.9)],
	&"skirt": [Vector2(0, 4.2), Vector2(0.7, 3.75), Vector2(1, 3.6)],
	&"hem": [Vector2(0, 4.35), Vector2(1, 4.35)],
	&"head": [Vector2(0, 1.2), Vector2(0.1, 2.7), Vector2(0.35, 3.2), Vector2(0.72, 3.3), Vector2(0.92, 2.8), Vector2(1, 0.6)],
	&"hair": [Vector2(0, 3.5), Vector2(0.45, 3.65), Vector2(0.85, 2.9), Vector2(1, 0.6)],
	&"hair_back": [Vector2(0, 2.9), Vector2(0.5, 3.2), Vector2(1, 3.1)],
	&"fringe": [Vector2(0, 3.15), Vector2(1, 3.2)],
}


## A smooth shape turned around its axis from a profile (unit length along +Y, from
## y = 0 at t = 0 to y = 1), with ends closed.
static func lathe(profile: Array, sides: int = 16) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	var rings: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	for i in n:
		var p: Vector2 = profile[i]
		var prev: Vector2 = profile[maxi(i - 1, 0)]
		var next: Vector2 = profile[mini(i + 1, n - 1)]
		var slope := (next.y - prev.y) / maxf(next.x - prev.x, 0.001)  # dr / dt
		var ring := PackedVector3Array()
		var nr := PackedVector3Array()
		for k in sides + 1:
			var a := TAU * float(k) / float(sides)
			var dir := Vector3(sin(a), 0.0, cos(a))
			ring.append(dir * p.y + Vector3(0, p.x, 0))
			nr.append((dir - Vector3(0, slope, 0)).normalized())
		rings.append(ring)
		norms.append(nr)
	for i in n - 1:
		for k in sides:
			var q := [[i, k], [i + 1, k], [i + 1, k + 1], [i, k], [i + 1, k + 1], [i, k + 1]]
			for v: Array in q:
				st.set_normal(norms[v[0]][v[1]])
				st.add_vertex(rings[v[0]][v[1]])
	# Caps.
	for end: int in [0, n - 1]:
		var c := Vector3(0, (profile[end] as Vector2).x, 0)
		var nn := Vector3(0, -1 if end == 0 else 1, 0)
		for k in sides:
			var a2: Vector3 = rings[end][k]
			var b2: Vector3 = rings[end][k + 1]
			for v: Vector3 in ([c, b2, a2] if end == 0 else [c, a2, b2]):
				st.set_normal(nn)
				st.add_vertex(v)
	return st.commit()


func _lathe_part(part: StringName, profile: StringName, group: StringName, sides: int = 16) -> void:
	_mesh_part(part, lathe(FIT[profile], sides), group).set_meta(&"lathe", true)


func _build_fit() -> void:
	for side: String in ["front", "back"]:
		_lathe_part(StringName("thigh_" + side), &"thigh", &"pants")
		_lathe_part(StringName("shin_" + side), &"shin", &"pants")
		_lathe_part(StringName("tip_" + side), &"tip", &"leather")
		_lathe_part(StringName("skirt_" + side), &"skirt", &"tunic")
		_lathe_part(StringName("hem_" + side), &"hem", &"trim")
		_lathe_part(StringName("upper_arm_" + side), &"upper_arm", &"skin")
		_lathe_part(StringName("forearm_" + side), &"forearm", &"skin")
		_lathe_part(StringName("hand_" + side), &"hand", &"skin", 10)
	_lathe_part(&"torso", &"torso", &"tunic", 20)
	_lathe_part(&"belt", &"belt", &"leather", 20)
	_prism(&"buckle", 0.9, 0.9, &"leather")
	_prism(&"placket", 0.45, 0.45, &"trim")
	_lathe_part(&"neck", &"neck", &"skin")
	_lathe_part(&"head", &"head", &"skin")
	_lathe_part(&"hair", &"hair", &"hair")
	_lathe_part(&"hair_back", &"hair_back", &"hair", 12)
	_lathe_part(&"fringe", &"fringe", &"hair", 12)


func _build() -> void:
	if style == "model":
		_build_model()
		return
	if style == "fit":
		_build_fit()
		return
	for side: String in ["front", "back"]:
		# Legs: wide pants tapering to a point (by design), the tip in leather.
		_tube(StringName("thigh_" + side), 3.5, 3.1, &"pants")
		_tube(StringName("shin_" + side), 3.1, 1.8, &"pants")
		_tube(StringName("tip_" + side), 1.75, 0.1, &"leather")
		# The tunic's skirt: a panel over each thigh (it parts at the slit as you walk).
		_prism(StringName("skirt_" + side), 3.4, 3.9, &"tunic")
		_prism(StringName("hem_" + side), 4.0, 4.0, &"trim")
		# Arms: bare, thick and even like the drawn ones.
		_tube(StringName("upper_arm_" + side), 2.7, 2.5, &"skin")
		_tube(StringName("forearm_" + side), 2.5, 2.2, &"skin")
		_prism(StringName("hand_" + side), 1.7, 1.5, &"skin")
	# The tunic: a box, wider at the shoulders, flat across the top, belted.
	_prism(&"torso", 5.0, 5.9, &"tunic")
	_prism(&"belt", 5.15, 5.15, &"leather")
	_prism(&"buckle", 0.9, 0.9, &"leather")
	_prism(&"placket", 0.45, 0.45, &"trim")
	_prism(&"neck", 2.0, 1.9, &"skin")
	# Head: a blank face, square like the drawn one. Hair: a cap, the back, a fringe.
	_prism(&"head", 2.95, 3.0, &"skin")
	_prism(&"hair", 3.3, 3.2, &"hair")
	_prism(&"hair_back", 3.1, 3.2, &"hair")
	_prism(&"fringe", 3.15, 3.15, &"hair")
	if style == "round":
		# Rounder: ball joints, and the head and hair as rounded shapes.
		for side: String in ["front", "back"]:
			_joint(StringName("deltoid_" + side), 2.75, &"skin")
			_joint(StringName("elbow_" + side), 2.4, &"skin")
			_joint(StringName("knee_" + side), 3.05, &"pants")
		_round(&"head", 3.3)
		_round(&"hair", 3.65)


func _joint(part: StringName, r: float, group: StringName) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	var mi := _mesh_part(part, m, group)
	mi.set_meta(&"joint", true)


## Swaps a prism for a sphere of the same box (posed the same way).
func _round(part: StringName, r: float) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 20
	m.rings = 10
	_parts[part].mesh = m
	_parts[part].set_meta(&"sphere", r)


func _apply_colors() -> void:
	if _parts.is_empty() and _model_meshes.is_empty():
		return
	for g: StringName in GROUPS:
		var sh := shades(g)
		for far in [false, true]:
			var m := ShaderMaterial.new()
			m.shader = TOON
			var k: float = far_shade if far else 1.0
			m.set_shader_parameter(&"deep", _dim(sh[0], k))
			m.set_shader_parameter(&"dark", _dim(sh[1], k))
			m.set_shader_parameter(&"mid", _dim(sh[2], k))
			m.set_shader_parameter(&"light", _dim(sh[3], k))
			m.set_shader_parameter(&"light_dir", light_dir)
			m.set_shader_parameter(&"bands", bands)
			m.set_shader_parameter(&"flat_faces", style in ["blocky", "soft"])
			if g == &"tunic" and trim_width > 0.0:
				# The light line around the tunic, as on the drawn Scholar.
				var hull := ShaderMaterial.new()
				hull.shader = HULL
				hull.set_shader_parameter(&"color", _dim(shades(&"trim")[2], 1.0))
				hull.set_shader_parameter(&"width", trim_width)
				m.next_pass = hull
			if far:
				_far_mats[g] = m
			else:
				_mats[g] = m
	for mi: MeshInstance3D in _model_meshes:
		for k in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(k)
			var g := _group_of(src, mi.mesh.surface_get_name(k))
			mi.set_surface_override_material(k, _mats[g] if g != &"" else _own_color(src))
	for part: StringName in _parts:
		var mi := _parts[part]
		var g: StringName = mi.get_meta(&"group")
		mi.material_override = _far_mats[g] if String(part).ends_with("_back") and part != &"hair_back" else _mats[g]
	if _show:
		(_show.material as ShaderMaterial).set_shader_parameter(&"trim_color", shades(&"trim")[3])
	_dirty = true


## The canvas renders detail x the art size; the picture is shown at 1 / detail, so the
## body stays the same size with finer pixels. The camera still spans the same art area.
func _apply_detail() -> void:
	if _vp == null:
		return
	_vp.size = canvas_px * detail
	_show.scale = Vector2.ONE / float(detail)
	_dirty = true


## A material with a name outside the color groups (a metal buckle, a gem): shaded in
## the same bands from its own Base Color, not recolored by the character creator.
func _own_color(src: Material) -> ShaderMaterial:
	var c := Color(0.6, 0.6, 0.6)
	if src is BaseMaterial3D:
		c = (src as BaseMaterial3D).albedo_color
	var m := ShaderMaterial.new()
	m.shader = TOON
	var dark := _shift(Color.from_hsv(c.h, c.s, c.v * 0.72, 1.0), COOL_HUE, hue_shift * 0.6, 1.05)
	m.set_shader_parameter(&"deep", _dim(Color.from_hsv(dark.h, dark.s, dark.v * deep_shadow), 1.0))
	m.set_shader_parameter(&"dark", _dim(dark, 1.0))
	m.set_shader_parameter(&"mid", _dim(c, 1.0))
	m.set_shader_parameter(&"light", _dim(_shift(Color.from_hsv(c.h, c.s * 0.9, minf(c.v * 1.15, 1.0)), WARM_HUE, hue_shift, 0.92), 1.0))
	m.set_shader_parameter(&"light_dir", light_dir)
	m.set_shader_parameter(&"bands", bands)
	m.set_shader_parameter(&"flat_faces", false)
	return m


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


## The way the body faces (+x), turned toward the camera by `turn`.
func _front() -> Vector3:
	var t := deg_to_rad(turn)
	return Vector3(cos(t), 0.0, sin(t))


## Bends the mannequin to a PaperDoll pose_state.
func pose_from(st: Dictionary[StringName, Vector2]) -> void:
	if not st.has(&"shoulder_front"):
		return
	if _skel:
		_pose_model(st)
		return
	var shift: Vector2 = st.get(&"shift", Vector2.ZERO)
	var hip_f: Vector2 = st.get(&"hip_front", Vector2(1, -hip_height) + shift)
	var hip_b: Vector2 = st.get(&"hip_back", Vector2(2, -hip_height) + shift)
	var hips := (hip_f + hip_b) * 0.5
	var shoulders := (st[&"shoulder_front"] + st[&"shoulder_back"]) * 0.5
	var up := (shoulders - hips).normalized()  # doll space, y down
	var up3 := to3(up).normalized()
	var front3 := _front()
	front3 = (front3 - up3 * front3.dot(up3)).normalized()  # facing, square to the spine
	var depth := torso_depth
	var width := torso_width

	# Tunic: from the hips to just above the shoulders (flat top), belt at the waist.
	var t_bot := to3(hips + up * -1.0)
	var t_top := to3(shoulders + up * 0.4)
	_box_between(&"torso", t_bot, t_top, front3, Vector3(depth, 1.0, width))
	var waist := to3(hips + up * 3.0)
	_box_between(&"belt", waist - up3 * 0.8, waist + up3 * 0.8, front3, Vector3(depth, 1.0, width))
	var face := front3 * (5.15 * depth + 0.25)
	_box_between(&"buckle", waist - up3 * 1.0 + face, waist + up3 * 1.0 + face, front3, Vector3(0.6, 1.0, 1.0))
	var pk := front3 * (5.5 * depth + 0.2)
	_box_between(&"placket", waist + up3 * 1.0 + pk, t_top - up3 * 0.2 + pk, front3, Vector3(0.5, 1.0, 1.0))
	# Neck and head, turned with the body.
	var neck_a := to3(shoulders - up * 0.5)
	var neck_b := to3(shoulders + up * 3.4)
	_box_between(&"neck", neck_a, neck_b, front3, Vector3(0.95, 1.0, 1.0))
	var head_a := neck_b - up3 * 0.6
	var head_b := head_a + up3 * (head_radius * 2.05)
	_box_between(&"head", head_a, head_b, front3, Vector3(1.0, 1.0, 1.0))
	var top := head_b
	_box_between(&"hair", top - up3 * 2.0 - front3 * 0.2, top + up3 * 1.0 - front3 * 0.2, front3, Vector3(1.0, 1.0, 1.0))
	_box_between(&"hair_back", top - up3 * 6.5 - front3 * 2.3, top - up3 * 0.5 - front3 * 2.3, front3, Vector3(0.36, 1.0, 1.02))
	_box_between(&"fringe", top - up3 * 3.6 + front3 * 2.55, top - up3 * 1.5 + front3 * 2.55, front3, Vector3(0.3, 1.0, 1.0))

	var t := 0.0
	if doll:
		t = doll.walked / maxf(doll.stride_px * 2.0, 1.0) * TAU
	for side: StringName in [&"front", &"back"]:
		var near := side == &"front"
		var z := _depth(hip_half, near)
		var sfx := "_" + side
		# Legs: hip to knee to the point, knee forward.
		var hip: Vector2 = st.get(StringName("hip" + sfx), hips)
		var foot: Vector2 = st.get(StringName("foot" + sfx), hip + Vector2(0, hip_height))
		var knee := _ik(hip, foot, thigh, shin, -1.0)
		_tube_at(StringName("thigh" + sfx), to3(hip, z), to3(knee, z))
		_joint_at(StringName("knee" + sfx), to3(knee, z))
		var shin_dir := (foot - knee).normalized()
		var tip_start := foot - shin_dir * 4.0
		_tube_at(StringName("shin" + sfx), to3(knee, z), to3(tip_start, z))
		_tube_at(StringName("tip" + sfx), to3(tip_start, z), to3(foot, z))
		# The skirt panel over this thigh, down past the hips.
		var dir := (knee - hip).normalized()
		var zs := z * 0.55
		_box_between(StringName("skirt" + sfx), to3(hip + dir * robe_length, zs), to3(hip - dir * 1.5, zs), front3, Vector3(depth * 1.1, 1.0, 1.0))
		_box_between(StringName("hem" + sfx), to3(hip + dir * (robe_length + 0.4), zs), to3(hip + dir * (robe_length - 0.8), zs), front3, Vector3(depth * 1.1, 1.0, 1.0))
		# Arms: shoulder to hand, elbow back. Free arms swing with the walk.
		var sh: Vector2 = st[StringName("shoulder" + sfx)]
		var hand: Vector2
		var reach := upper_arm + forearm
		if (doll and doll.arm_is_natural(side)) or not st.has(StringName("hand" + sfx)):
			var swing := 0.0
			if doll and not doll.airborne:
				swing = sin(t + (0.0 if near else PI)) * deg_to_rad(arm_swing) * clampf(absf(doll.velocity.x) / 60.0, 0.0, 1.0)
			hand = sh + Vector2(0.5, reach * 0.97).rotated(-swing)
		else:
			hand = st[StringName("hand" + sfx)]
		var elbow := _ik(sh, hand, upper_arm, forearm, 1.0)
		var az := _depth(shoulder_half, near)
		var hand_at := sh + (hand - sh).limit_length(reach - 0.01)
		var wrist := hand_at - (hand_at - elbow).normalized() * 1.5
		_tube_at(StringName("upper_arm" + sfx), to3(sh + Vector2(0, 0.5), az), to3(elbow, az))
		_joint_at(StringName("deltoid" + sfx), to3(sh + Vector2(0, 1.6), az))
		_joint_at(StringName("elbow" + sfx), to3(elbow, az))
		_tube_at(StringName("forearm" + sfx), to3(elbow, az), to3(wrist, az))
		_box_between(StringName("hand" + sfx), to3(wrist, az), to3(hand_at + (hand_at - wrist), az), front3, Vector3(0.8, 1.0, 0.75))


## A prism (or tube) from a to b, faces squared to `front`; `size` scales its depth
## (toward front), length (ignored: set by a and b) and width.
func _box_between(part: StringName, a: Vector3, b: Vector3, front: Vector3, size: Vector3) -> void:
	var mi := _parts[part]
	var len := maxf(a.distance_to(b), 0.05)
	if mi.get_meta(&"lathe", false):
		# Unit length from a (t = 0) to b (t = 1).
		var yv := b - a
		var yn := yv / len
		var xl := front - yn * front.dot(yn)
		if xl.length() < 0.01:
			xl = yn.cross(Vector3(0, 0, 1))
		xl = xl.normalized()
		var zl := xl.cross(yn)
		mi.transform = Transform3D(Basis(xl * size.x, yv, zl * size.z), a)
		return
	var y_scale := 1.0
	if mi.mesh is CylinderMesh:
		(mi.mesh as CylinderMesh).height = len
	else:
		y_scale = len / (float(mi.get_meta(&"sphere", 1.0)) * 2.0)
	var y := (b - a) / len
	var x := front - y * front.dot(y)
	if x.length() < 0.01:
		x = y.cross(Vector3(0, 0, 1))
	x = x.normalized()
	var z := x.cross(y)
	var basis := Basis(x * size.x, y * y_scale, z * size.z)
	var sides: int = mi.get_meta(&"prism", 0)
	if sides > 0 and sides < 12:
		basis = basis * Basis(Vector3.UP, PI / float(sides))  # a face to the front
	mi.transform = Transform3D(basis, (a + b) * 0.5)


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


## Puts a ball joint (round style only) at a point.
func _joint_at(part: StringName, at: Vector3) -> void:
	if _parts.has(part):
		_parts[part].position = at


## A tapered tube from a to b (radius r_a at a, r_b at b).
func _tube_at(part: StringName, a: Vector3, b: Vector3) -> void:
	var mi := _parts[part]
	if mi.get_meta(&"lathe", false):
		_box_between(part, a, b, _front(), Vector3.ONE)
		return
	(mi.mesh as CylinderMesh).height = maxf(a.distance_to(b), 0.05)
	mi.transform = _along(a, b, 1.0)




# --- your model (style "model") ------------------------------------------------------

## Bone roles and the names they're found by (lowercase, "." and "-" and " " read as
## "_"; Godot's importer turns "upper_arm.R" into "upper_arm_R"). R is the near side
## (facing right, the character's right side is toward you), L the far side.
const BONE_NAMES := {
	&"hips": ["hips", "pelvis", "root"],
	&"neck": ["neck"],
	&"head": ["head"],
	&"upper_arm_front": ["upper_arm_r", "upperarm_r", "arm_r"],
	&"forearm_front": ["forearm_r", "lower_arm_r", "lowerarm_r"],
	&"hand_front": ["hand_r"],
	&"upper_arm_back": ["upper_arm_l", "upperarm_l", "arm_l"],
	&"forearm_back": ["forearm_l", "lower_arm_l", "lowerarm_l"],
	&"hand_back": ["hand_l"],
	&"thigh_front": ["thigh_r", "upper_leg_r", "upperleg_r", "leg_r"],
	&"shin_front": ["shin_r", "lower_leg_r", "lowerleg_r", "calf_r"],
	&"foot_front": ["foot_r"],
	&"thigh_back": ["thigh_l", "upper_leg_l", "upperleg_l", "leg_l"],
	&"shin_back": ["shin_l", "lower_leg_l", "lowerleg_l", "calf_l"],
	&"foot_back": ["foot_l"],
}


static func bone_key(bone_name: String) -> String:
	return bone_name.to_lower().replace(".", "_").replace("-", "_").replace(" ", "_")


## A surface's color group from its material (or surface) name: skin, hair, tunic,
## pants, leather or trim (Blender's ".001" endings are ignored). &"" = keep its own.
func _group_of(mat: Material, surface_name: String) -> StringName:
	for n: String in [mat.resource_name if mat else "", surface_name]:
		var k := n.to_lower().get_slice(".", 0).strip_edges()
		if StringName(k) in GROUPS:
			return StringName(k)
	return &""


func _build_model() -> void:
	model_file = model_path if ResourceLoader.exists(model_path) else PLACEHOLDER_MODEL
	var ps := load(model_file) as PackedScene
	if ps == null:
		push_warning("Body3D: no model at %s" % model_file)
		return
	_model = Node3D.new()
	_model.name = "Model"
	_root.add_child(_model)
	var inst := ps.instantiate()
	_model.add_child(inst)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		_model_meshes.append(m as MeshInstance3D)
	if skels.is_empty():
		push_warning("Body3D: %s has no skeleton (armature)" % model_file)
		return
	_skel = skels[0]
	var by_key := {}
	for i in _skel.get_bone_count():
		by_key[bone_key(_skel.get_bone_name(i))] = i
	for role: StringName in BONE_NAMES:
		for n: String in BONE_NAMES[role]:
			if by_key.has(n):
				_bones[role] = by_key[n]
				break
	# Size: the meshes' height becomes model_height art pixels.
	var aabb := AABB()
	var first := true
	for mi in _model_meshes:
		var box := mi.transform * mi.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	var k := model_height / maxf(aabb.size.y, 0.001)
	_model.scale = Vector3.ONE * k
	_measure_model(k)


## Rest joints (art pixels, facing +Z, feet at y = 0) and bone lengths from the model.
func _measure_model(k: float) -> void:
	_rest.clear()
	var base := inst_transform()
	for role: StringName in _bones:
		_rest[role] = base * _skel.get_bone_global_rest(_bones[role]).origin * k
	var get := func(role: StringName, fallback: Vector3) -> Vector3:
		return _rest.get(role, fallback)
	for side: String in ["front", "back"]:
		var hip: Vector3 = get.call(StringName("thigh_" + side), Vector3(0, hip_height, 0))
		var knee: Vector3 = get.call(StringName("shin_" + side), hip - Vector3(0, thigh, 0))
		var ankle: Vector3 = get.call(StringName("foot_" + side), Vector3(knee.x, 0, knee.z))
		var sh: Vector3 = get.call(StringName("upper_arm_" + side), Vector3(0, shoulder_height, 0))
		var el: Vector3 = get.call(StringName("forearm_" + side), sh - Vector3(0, upper_arm, 0))
		var wr: Vector3 = get.call(StringName("hand_" + side), el - Vector3(0, forearm, 0))
		if side == "front":
			hip_height = hip.y
			thigh = hip.distance_to(knee)
			shin = knee.distance_to(ankle)
			shoulder_height = sh.y
			upper_arm = sh.distance_to(el)
			forearm = el.distance_to(wr)


## The skeleton's place inside the model scene (without our turn and scale).
func inst_transform() -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = _skel
	while n and n != _model:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## Turns a rest point (art px, facing +Z) the way the model faces now: toward +X (the
## game's right), turned `turn` degrees toward you.
func _turned(p: Vector3) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(90.0 - turn)) * p


func _model_joints() -> Dictionary[StringName, Vector2]:
	var out: Dictionary[StringName, Vector2] = {}
	var st := sin(deg_to_rad(turn))
	for side: StringName in [&"front", &"back"]:
		var hip := _turned(_rest.get(StringName("thigh_" + side), Vector3(0, hip_height, 0)))
		var sh := _turned(_rest.get(StringName("upper_arm_" + side), Vector3(0, shoulder_height, 0)))
		out[StringName("hip_" + side)] = Vector2(hip.x, -hip.y)
		out[StringName("knee_" + side)] = Vector2(hip.x, -hip.y + thigh)
		out[StringName("foot_" + side)] = Vector2(hip.x + (-stance_apart if side == &"front" else stance_apart * 0.3) * st, 0.0)
		out[StringName("shoulder_" + side)] = Vector2(sh.x, -sh.y)
	return out


## Poses the model's skeleton: each bone turned (the least it can, from its rest) to
## point at its next joint, worked out like the other styles.
func _pose_model(st: Dictionary[StringName, Vector2]) -> void:
	_model.rotation = Vector3(0, deg_to_rad(90.0 - turn), 0)
	var shift: Vector2 = st.get(&"shift", Vector2.ZERO)
	var jo := _model_joints()
	var hips := ((st.get(&"hip_front", jo[&"hip_front"] + shift) as Vector2) + (st.get(&"hip_back", jo[&"hip_back"] + shift) as Vector2)) * 0.5
	var shoulders: Vector2 = (st[&"shoulder_front"] + st[&"shoulder_back"]) * 0.5
	var up := to3(shoulders - hips).normalized()
	# Targets in our 3D space (art px), and the direction each bone should point.
	var dirs: Dictionary[StringName, Vector3] = {&"spine": up, &"neck": up, &"head": up}
	var t := 0.0
	if doll:
		t = doll.walked / maxf(doll.stride_px * 2.0, 1.0) * TAU
	for side: StringName in [&"front", &"back"]:
		var sfx := "_" + side
		var hip: Vector2 = st.get(StringName("hip" + sfx), hips)
		var foot: Vector2 = st.get(StringName("foot" + sfx), hip + Vector2(0, hip_height))
		var knee := _ik(hip, foot, thigh, shin, -1.0)
		dirs[StringName("thigh" + sfx)] = to3(knee - hip).normalized()
		dirs[StringName("shin" + sfx)] = to3(foot - knee).normalized()
		var sh: Vector2 = st[StringName("shoulder" + sfx)]
		var hand: Vector2
		var reach := upper_arm + forearm
		if (doll and doll.arm_is_natural(side)) or not st.has(StringName("hand" + sfx)):
			var swing := 0.0
			if doll and not doll.airborne:
				swing = sin(t + (0.0 if side == &"front" else PI)) * deg_to_rad(arm_swing) * clampf(absf(doll.velocity.x) / 60.0, 0.0, 1.0)
			hand = sh + Vector2(0.5, reach * 0.97).rotated(-swing)
		else:
			hand = st[StringName("hand" + sfx)]
		var elbow := _ik(sh, hand, upper_arm, forearm, 1.0)
		dirs[StringName("upper_arm" + sfx)] = to3(elbow - sh).normalized()
		dirs[StringName("forearm" + sfx)] = to3(hand - elbow).normalized()
		dirs[StringName("hand" + sfx)] = dirs[StringName("forearm" + sfx)]

	# Walk the bones parent first, keeping their global poses (skeleton space).
	var to_skel := _skel.global_transform.affine_inverse()
	var role_of := {}
	for role: StringName in _bones:
		role_of[_bones[role]] = role
	var globals := {}
	for i in _skel.get_bone_count():
		var parent := _skel.get_bone_parent(i)
		var rest := _skel.get_bone_rest(i)
		var pg: Transform3D = globals[parent] if parent >= 0 else Transform3D.IDENTITY
		var local := rest
		var role: StringName = role_of.get(i, &"")
		if role == &"hips":
			# The hips go where the doll's hips are.
			var want := to_skel * to3(hips)
			local.origin = pg.affine_inverse() * want
		var g := pg * local
		var dir_role := role
		if role == &"" and _is_spine(i):
			dir_role = &"spine"
		if dirs.has(dir_role) or (role == &"hips" and false):
			var want_dir := (to_skel.basis * dirs[dir_role]).normalized()
			var cur := g.basis.y.normalized()
			var turn_q := Quaternion(cur, want_dir) if cur.dot(want_dir) > -0.999 else Quaternion(g.basis.x.normalized(), PI)
			g.basis = Basis(turn_q) * g.basis
			local.basis = pg.basis.inverse() * g.basis
		_skel.set_bone_pose_position(i, local.origin)
		_skel.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		globals[i] = g


## Spine bones between the hips and the neck ("spine", "spine.001", "chest"...).
func _is_spine(i: int) -> bool:
	var k := bone_key(_skel.get_bone_name(i))
	return k.begins_with("spine") or k.begins_with("chest") or k.begins_with("torso")
