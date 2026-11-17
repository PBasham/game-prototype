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


func _shoulder(d: PaperDoll, side: StringName) -> Vector2:
	var arm: Dictionary = rig.arms[side]
	var f := rig.tag_range(&"legs", d.animation).x + d.frame
	return (arm.shoulder as Vector2) + rig.body_offset[f] - rig.anchor + Vector2(d.motion.lunge_at(d.motion_t) if d.motion else 0.0, 0)


func test_pose_track_puts_the_hand_at_angle_and_reach() -> void:
	var d := _doll()
	d.item = DevHeldItems.by_name("Tool")
	d.motion = d.item.hold_motion()
	d.motion_t = 0.0
	d._update()
	var track := d.motion.front
	var arm: Dictionary = rig.arms[&"front"]
	var length := ((arm.hand as Vector2) - (arm.shoulder as Vector2)).length()
	var expected := _shoulder(d, &"front") + Vector2.from_angle(deg_to_rad(track.angle_at(0.0))) * length * track.reach_at(0.0)
	assert_almost_eq(d.hands[&"front"].distance_to(expected), 0.0, 0.6)


func test_aiming_motion_points_the_arm_at_the_target() -> void:
	var d := _doll()
	d.item = DevHeldItems.by_name("Wand")
	d.motion = d.item.hold_motion()
	for target: Vector2 in [Vector2(60, -40), Vector2(-50, -90), Vector2(40, 10)]:
		d.aim_global = d.to_global(target)
		d._update()
		var shoulder := _shoulder(d, &"front")
		var dir := (d.hands[&"front"] - shoulder).normalized()
		assert_almost_eq(dir.angle_to((target - shoulder).normalized()), 0.0, 0.05, "aims at %s" % target)


func test_two_hand_hold_puts_the_back_hand_on_the_item() -> void:
	var d := _doll()
	var big := DevHeldItems.by_name("2H sword")
	d.item = big
	d.motion = big.hold_motion()
	d._update()
	var expected := d.hands[&"front"] + (big.grip2 - big.grip).rotated(d.item_rotation + PI / 4.0)
	assert_almost_eq(d.hands[&"back"].distance_to(expected), 0.0, 1.0, "back hand on the second grip")


func test_every_item_type_is_valid_and_has_attacks() -> void:
	for t: GameData in Registry.get_all(&"item_types"):
		var it := t as ItemTypeData
		assert_eq(it.validate().size(), 0, "\n".join(it.validate()))
		assert_gt(it.attacks.size(), 0, "%s has attacks" % it.id)


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
	d.motion = d.item.hold_motion()
	d.aim_global = d.to_global(Vector2(80, -100))
	d._update()
	assert_eq(d._slots[rig.arms[&"back"].upper].rotation, 0.0, "back arm not posed")
	assert_ne(d._slots[rig.arms[&"front"].upper].rotation, 0.0, "front arm aims")


func test_bow_draw_pulls_the_back_hand_back() -> void:
	var d := _doll()
	var bow := DevHeldItems.by_name("Bow")
	d.item = bow
	var draw := bow.attacks()[0]
	d.motion = draw
	d.aim_global = d.to_global(Vector2(80, -40))
	d.motion_t = 0.0
	d._update()
	var rest := d.hands[&"front"].distance_to(d.hands[&"back"])
	d.motion_t = 0.7
	d._update()
	assert_gt(d.hands[&"front"].distance_to(d.hands[&"back"]), rest + 3.0, "string drawn back")


func test_book_is_held_in_the_back_hand_and_stays_upright() -> void:
	var d := _doll()
	var book := DevHeldItems.by_name("Book")
	d.item = book
	d.motion = book.attacks()[0]
	d.aim_global = d.to_global(Vector2(80, -100))
	d.motion_t = 0.5
	d._update()
	assert_almost_eq(d.get_node("Item").position.distance_to(d.hands[&"back"]), 0.0, 0.01)
	assert_almost_eq(d.item_rotation, deg_to_rad(-45.0), 0.001)


func test_drawn_tag_lookup_prefers_item_then_type_then_generic() -> void:
	var d := _doll()
	d.item = DevHeldItems.by_name("Sword")
	var slash := d.item.attacks()[0]
	var saved := rig.tags.duplicate()
	rig.tags["arms/Use"] = Vector2i(0, 0)
	assert_eq(d.drawn_tag_for(slash), "arms/Use")
	rig.tags["arms/sword/Slash"] = Vector2i(0, 0)
	assert_eq(d.drawn_tag_for(slash), "arms/sword/Slash")
	d.force_posed = true
	assert_eq(d.drawn_tag_for(slash), "")
	rig.tags = saved
