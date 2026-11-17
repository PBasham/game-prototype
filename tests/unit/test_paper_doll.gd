extends GutTest
## Paper doll: the rig reads the Scholar's layers and joints, arms reach their targets,
## items attach to the hand, and recoloring keeps shading.

var rig: DollRig
var palette: CharacterPalette


func before_all() -> void:
	rig = DollRig.load_from("res://assets/sprites/scholar")
	palette = load("res://assets/sprites/scholar_palette.tres") as CharacterPalette


func _doll() -> PaperDoll:
	var d := PaperDoll.new()
	add_child_autofree(d)
	d.setup(rig, palette)
	return d


func test_rig_has_parts_in_every_channel() -> void:
	assert_gt(rig.part_names.size(), 0)
	for ch in DollRig.CHANNELS:
		assert_has(rig.part_channels, ch, "channel %s has parts" % ch)
	assert_true(rig.has_tag(&"legs", &"Jog"))
	assert_eq(rig.tag_range(&"legs", &"Nope"), Vector2i(-1, -1))


func test_arm_joints_are_measured_top_to_bottom() -> void:
	for side: StringName in [&"front", &"back"]:
		assert_true(rig.arms.has(side), "%s arm found" % side)
		var arm: Dictionary = rig.arms[side]
		assert_lt((arm.shoulder as Vector2).y, (arm.elbow as Vector2).y, "%s shoulder above elbow" % side)
		assert_lt((arm.elbow as Vector2).y, (arm.hand as Vector2).y, "%s elbow above hand" % side)


func test_prefixed_tags_win_for_their_channel() -> void:
	var r := DollRig.new()
	r.tags = {"Jog": Vector2i(1, 4), "arms/Jog": Vector2i(10, 13)}
	assert_eq(r.tag_range(&"front_arm", &"Jog"), Vector2i(10, 13))
	assert_eq(r.tag_range(&"legs", &"Jog"), Vector2i(1, 4))


func test_code_posed_hand_reaches_the_hold_point() -> void:
	var d := _doll()
	d.item = DevHeldItems.make_items()[0]
	d.arm_mode = PaperDoll.ArmMode.HOLD
	d._update()
	var arm: Dictionary = rig.arms[&"front"]
	var shoulder: Vector2 = (arm.shoulder as Vector2) + rig.body_offset[d.frame] - rig.anchor
	var reach := shoulder + d.one_hand_reach
	assert_almost_eq(d.hands[&"front"].distance_to(reach), 0.0, 0.6, "hand at the hold point")


func test_aim_points_the_arm_at_the_target() -> void:
	var d := _doll()
	d.item = DevHeldItems.make_items()[2]
	d.arm_mode = PaperDoll.ArmMode.AIM
	for target: Vector2 in [Vector2(60, -40), Vector2(-50, -90), Vector2(40, 10)]:
		d.aim_global = d.to_global(target)
		d._update()
		var arm: Dictionary = rig.arms[&"front"]
		var shoulder: Vector2 = (arm.shoulder as Vector2) + rig.body_offset[rig.tag_range(&"legs", d.animation).x] - rig.anchor
		var dir := (d.hands[&"front"] - shoulder).normalized()
		assert_almost_eq(dir.angle_to((target - shoulder).normalized()), 0.0, 0.05, "aims at %s" % target)


func test_two_hand_hold_puts_the_back_hand_on_the_item() -> void:
	var d := _doll()
	var big := DevHeldItems.make_items()[1]
	d.item = big
	d.arm_mode = PaperDoll.ArmMode.HOLD
	d._update()
	var expected := d.hands[&"front"] + (big.grip2 - big.grip).rotated(deg_to_rad(big.hold_angle) + PI / 4.0)
	assert_almost_eq(d.hands[&"back"].distance_to(expected), 0.0, 1.0, "back hand on the second grip")


func test_stowing_moves_the_item_off_the_hand() -> void:
	var d := _doll()
	d.item = DevHeldItems.make_items()[0]
	assert_true(d.get_node("Item").visible)
	d.stowed = true
	assert_false(d.get_node("Item").visible)
	assert_true(d.get_node("StowBack").visible)
	d.item = DevHeldItems.make_items()[2]  # wand: hidden when put away
	assert_false(d.get_node("StowBack").visible)
	assert_false(d.get_node("StowHip").visible)


func test_recolor_keeps_relative_shading() -> void:
	var ref := Color("346ee1")
	var dark := Color("1f4fae")
	var target := Color("3c8a3c")
	var out := CharacterLook.shade_onto(dark, ref, target)
	assert_lt(out.v, target.v, "darker shade stays darker")
	assert_almost_eq(out.h, target.h + (dark.h - ref.h), 0.01)
	assert_eq(CharacterLook.shade_onto(ref, ref, target).to_html(false), target.to_html(false))


func test_palette_groups_cover_the_art() -> void:
	for g: StringName in [&"skin", &"tunic", &"pants", &"leather", &"hair"]:
		assert_true(palette.groups.has(g), "palette has %s" % g)


func test_one_handed_aim_uses_only_the_front_arm() -> void:
	var d := _doll()
	d.item = DevHeldItems.by_name("Crossbow")
	d.arm_mode = PaperDoll.ArmMode.AIM
	d.aim_global = d.to_global(Vector2(80, -100))
	d._update()
	var back_upper: int = rig.arms[&"back"].upper
	assert_eq(d._slots[back_upper].rotation, 0.0, "back arm not rotated toward the cursor")
	var front_upper: int = rig.arms[&"front"].upper
	assert_ne(d._slots[front_upper].rotation, 0.0, "front arm aims")


func test_bow_back_hand_on_the_string() -> void:
	var d := _doll()
	var bow := DevHeldItems.by_name("Bow")
	d.item = bow
	d.arm_mode = PaperDoll.ArmMode.AIM
	d.aim_global = d.to_global(Vector2(80, -40))
	d._update()
	var expected := d.hands[&"front"] + (bow.grip2 - bow.grip).rotated(d.item_angle() + PI / 4.0)
	assert_almost_eq(d.hands[&"back"].distance_to(expected), 0.0, 1.0)


func test_book_stays_upright_while_aiming() -> void:
	var d := _doll()
	var book := DevHeldItems.by_name("Book")
	d.item = book
	d.arm_mode = PaperDoll.ArmMode.AIM
	d.aim_global = d.to_global(Vector2(80, -100))
	d._update()
	assert_almost_eq(d.item_angle(), deg_to_rad(book.hold_angle), 0.001)
