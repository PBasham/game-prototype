extends GutTest
## The 3D body test (Phase 20): it takes over a doll's body, bends to the doll's pose,
## takes the palette's colors, and the doll can pose in steps.

var rig: DollRig
var palette: CharacterPalette


func before_all() -> void:
	rig = DollRig.load_from("res://assets/sprites/scholar")
	palette = load("res://assets/sprites/scholar_palette.tres") as CharacterPalette


func _doll() -> PaperDoll:
	var d := PaperDoll.new()
	add_child_autofree(d)
	d.setup(rig, palette)
	d.look = load("res://assets/sprites/scholar_look.tres") as CharacterLook
	return d


func _body(d: PaperDoll, style: String = "fit") -> Body3D:
	var b := Body3D.new()
	b.style = style
	add_child_autofree(b)
	b.attach(d)
	return b


func test_takes_over_the_doll_and_gives_it_back() -> void:
	var d := _doll()
	var b := _body(d)
	assert_true(b.is_on())
	assert_true(d.parts_hidden, "the drawn body is hidden")
	assert_eq(d.joints_override, b.joints(), "the doll uses the 3D body's joints")
	d._update()
	for key: StringName in [&"hip_front", &"hip_back", &"foot_front", &"foot_back", &"shoulder_front", &"shoulder_back"]:
		assert_has(d.pose_state, key)
	assert_almost_eq(d.pose_state[&"shoulder_front"].y, -b.shoulder_height, 3.0, "shoulders where the 3D body has them")
	b.detach()
	assert_false(d.parts_hidden)
	assert_true(d.joints_override.is_empty())


func test_standing_feet_are_under_the_body_and_sitting_lowers_the_hips() -> void:
	var d := _doll()
	var b := _body(d)
	d.walked = 7.0  # mid stride, but standing still
	d._update()
	var f1: Vector2 = d.pose_state[&"foot_front"]
	d.walked = 12.0
	d._update()
	assert_eq(d.pose_state[&"foot_front"], f1, "standing: feet in the stance, not mid stride")
	var standing_hip: float = d.pose_state[&"hip_front"].y
	d.pose = &"sit_floor"
	d._update()
	assert_gt(d.pose_state[&"hip_front"].y, standing_hip + 20.0, "on the floor: hips come down")
	assert_gt(d.pose_state[&"foot_front"].x, d.pose_state[&"hip_front"].x + 10.0, "legs out in front")
	b.pose_from(d.pose_state)
	var shin: MeshInstance3D = b._parts[&"shin_front"]
	assert_lt(shin.position.y, 20.0, "the shin starts down near the floor")


func test_ik_keeps_bone_lengths() -> void:
	var root := Vector2(0, -50)
	var end := Vector2(12, -38)
	var mid := Body3D._ik(root, end, 10.5, 10.0, 1.0)
	assert_almost_eq(mid.distance_to(root), 10.5, 0.01)
	assert_almost_eq(mid.distance_to(end), 10.0, 0.05)
	var other := Body3D._ik(root, end, 10.5, 10.0, -1.0)
	assert_ne(mid, other, "bends the other way")


func test_posed_hand_is_where_the_3d_hand_is() -> void:
	var d := _doll()
	var b := _body(d)
	d.pose = &"wave"
	d._update()
	b.pose_from(d.pose_state)
	var target: Vector2 = d.pose_state[&"hand_front"]
	var sh: Vector2 = d.pose_state[&"shoulder_front"]
	var reach := b.upper_arm + b.forearm
	var want := sh + (target - sh).limit_length(reach - 0.01)
	var wrist := b._parts[&"hand_front"].position  # the fit hand starts at the wrist
	assert_almost_eq(Vector2(wrist.x, -wrist.y).distance_to(want), 1.5, 0.6, "the 3D hand is at the doll's hand")


func test_colors_come_from_the_palette_and_the_look() -> void:
	var d := _doll()
	var b := _body(d)
	var sh := b.shades(&"tunic")
	assert_eq(sh.size(), 4, "deep shadow, shadow, base, light")
	assert_lt(sh[0].v, sh[3].v, "dark to light")
	var red := CharacterLook.new()
	red.colors = {&"tunic": Color(0.8, 0.1, 0.1)}
	b.set_colors(palette, red)
	assert_gt(b.shades(&"tunic")[1].r, b.shades(&"tunic")[1].b, "recolored by the look")


func test_doll_can_pose_in_steps() -> void:
	var d := _doll()
	var count := [0]
	d.posed.connect(func() -> void: count[0] += 1)
	d.step_fps = 12.0
	for i in 60:
		d._process(1.0 / 60.0)
	assert_between(count[0], 10, 13, "about 12 poses a second")
	count[0] = 0
	d.step_fps = 0.0
	for i in 60:
		d._process(1.0 / 60.0)
	assert_eq(count[0], 60, "smooth: every frame")


func test_detail_renders_finer_pixels_at_the_same_size() -> void:
	var d := _doll()
	var b := _body(d)
	b.detail = 3
	assert_eq(b._vp.size, b.canvas_px * 3)
	assert_almost_eq(b._show.scale.x, 1.0 / 3.0, 0.001)
	b.detail = 9
	assert_eq(b.detail, 4, "at most 4x")


func test_model_style_loads_the_rig_and_poses_its_bones() -> void:
	var d := _doll()
	var b := _body(d, "model")
	assert_not_null(b._skel, "the placeholder model has a skeleton")
	for role: StringName in [&"hips", &"head", &"upper_arm_front", &"forearm_back", &"hand_front", &"thigh_back", &"shin_front"]:
		assert_has(b._bones, role, "found the %s bone" % role)
	assert_almost_eq(b.hip_height, 31.0, 1.5, "measured from the model")
	assert_almost_eq(b.shoulder_height, 50.5, 1.5)
	assert_almost_eq(b.thigh, 13.0, 1.0)
	assert_eq(d.joints_override, b.joints(), "the doll uses the model's joints")
	var thigh := b._bones[&"thigh_front"]
	d._update()
	var standing := b._skel.get_bone_pose_rotation(thigh)
	d.pose = &"sit"
	d._update()
	assert_ne(b._skel.get_bone_pose_rotation(thigh), standing, "sitting bends the thigh bone")
	# Its materials get the palette's shading, by name.
	var mi: MeshInstance3D = b._model_meshes[0]
	var groups := []
	for k in mi.mesh.get_surface_count():
		groups.append(b._group_of(mi.mesh.surface_get_material(k), mi.mesh.surface_get_name(k)))
	assert_has(groups, &"tunic")
	assert_has(groups, &"skin")
	assert_eq(Body3D.bone_key("upper_arm.R"), "upper_arm_r")
