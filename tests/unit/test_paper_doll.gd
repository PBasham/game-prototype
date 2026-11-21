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
	d.blend_time = 0.0  # tests check poses directly, without the slide between them
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
	var f := rig.tag_range(&"legs", d.animation).x + d.frame
	return rig.shoulders[side][f] - rig.anchor + Vector2(d.motion.lunge_at(d.motion_t) if d.motion else 0.0, 0)


func test_melee_hold_keeps_the_drawn_arm() -> void:
	var d := _doll()
	d.play(&"Jog")
	d._update()
	var before: Vector2 = d.hands[&"front"]
	d.item = DevHeldItems.by_name("Sword")
	d.motion = d.item.hold_motion()
	d._update()
	assert_almost_eq(d.hands[&"front"].distance_to(before), 0.0, 0.01, "same arm with or without the sword")
	assert_eq(d._slots[rig.arms[&"front"].upper].rotation, 0.0, "drawn, not posed")
	assert_almost_eq(d.get_node("Item").position.distance_to(before), 0.0, 0.01, "sword in that hand")


func test_switching_poses_slides_the_hand() -> void:
	var d := _doll()
	d.blend_time = 0.1
	d.item = DevHeldItems.by_name("Wand")
	d.motion = null
	d._update()
	var start: Vector2 = d.hands[&"front"]
	d.motion = d.item.hold_motion()
	d.aim_global = d.to_global(Vector2(80, -60))
	d._update()  # blend starts: still at the old hand position
	assert_almost_eq(d.hands[&"front"].distance_to(start), 0.0, 0.5)
	d._process(0.05)
	var mid: Vector2 = d.hands[&"front"]
	d._process(0.1)
	var done: Vector2 = d.hands[&"front"]
	assert_gt(mid.distance_to(start), 0.5, "moving")
	assert_gt(done.distance_to(start), mid.distance_to(start), "arrives")


func test_shoulders_follow_each_frames_art() -> void:
	# Breath is a 3/4 pose (shoulders far apart); Jog is side view (close together).
	var breath := rig.tag_range(&"legs", &"Breath").x
	var jog := rig.tag_range(&"legs", &"Jog").x
	var spread_breath := absf(rig.shoulders[&"front"][breath].x - rig.shoulders[&"back"][breath].x)
	var spread_jog := absf(rig.shoulders[&"front"][jog].x - rig.shoulders[&"back"][jog].x)
	assert_gt(spread_breath, spread_jog + 5.0)


func test_elbow_does_not_flip_as_the_arm_sweeps() -> void:
	var d := _doll()
	d.item = DevHeldItems.by_name("Wand")
	d.motion = d.item.hold_motion()
	var upper: int = rig.arms[&"front"].upper
	var last := INF
	for i in range(0, 361, 5):
		var a := deg_to_rad(float(i))
		d.aim_global = d.to_global(_shoulder(d, &"front") + Vector2.from_angle(a) * 40.0)
		d._update()
		var rot := wrapf(d._slots[upper].rotation - a, -PI, PI)
		if last != INF:
			assert_lt(absf(wrapf(rot - last, -PI, PI)), 0.6, "no elbow flip at %d degrees" % i)
		last = rot


func test_pose_track_puts_the_hand_at_angle_and_reach() -> void:
	var d := _doll()
	d.item = DevHeldItems.by_name("Tool")
	d.motion = d.item.attacks()[0]
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


func test_two_hand_swing_puts_the_back_hand_on_the_item() -> void:
	var d := _doll()
	var big := DevHeldItems.by_name("2H sword")
	d.item = big
	d.motion = big.attacks()[0]
	d.motion_t = 0.5
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


func test_reload_types_updates_items_in_place() -> void:
	var sword := DevHeldItems.by_name("Sword")
	var t := sword.item_type()
	var original := t.attacks[0].duration
	t.attacks[0].duration = 9.0  # pretend: a stale value in memory
	HeldItemLook.reload_types()
	assert_eq(sword.item_type(), t, "same object")
	assert_almost_eq(sword.item_type().attacks[0].duration, original, 0.0001, "re-read from disk")


func test_back_arm_borrows_front_arm_pieces_until_arms_rest_exists() -> void:
	var d := _doll()
	d.item = DevHeldItems.by_name("2H sword")
	d.motion = d.item.attacks()[0]
	d.motion_t = 0.5
	d._update()
	var back_upper: int = rig.arms[&"back"].upper
	var front_upper: int = rig.arms[&"front"].upper
	assert_eq(d._sprites[back_upper].region_rect, rig.region(front_upper, rig.rest_frame))
	assert_lt(d._slots[back_upper].modulate.r, 1.0, "darkened")
	d.back_arm_from_front = false
	d._update()
	assert_eq(d._sprites[back_upper].region_rect, rig.region(back_upper, rig.rest_frame))


func test_book_stays_still_in_front_while_running() -> void:
	var d := _doll()
	d.item = DevHeldItems.by_name("Book")
	d.motion = d.item.hold_motion()
	d.play(&"Jog")
	var offsets: Array[Vector2] = []
	for f in d.frame_count(&"Jog"):
		d.frame = f
		d._update()
		offsets.append(d.hands[&"back"] - _shoulder(d, &"back"))
	for o in offsets:
		assert_almost_eq(o.distance_to(offsets[0]), 0.0, 0.5, "same hold every frame")
	assert_gt(offsets[0].x, 3.0, "held out in front")


func test_book_stays_put_while_casting_at_different_angles() -> void:
	var d := _doll()
	d.item = DevHeldItems.by_name("Book")
	d.motion = d.item.attacks()[0]
	d.motion_t = 0.5
	var spots: Array[Vector2] = []
	for target: Vector2 in [Vector2(80, -100), Vector2(80, 40), Vector2(-60, -80)]:
		d.aim_global = d.to_global(target)
		d._update()
		spots.append(d.hands[&"back"])
	assert_almost_eq(spots[0].distance_to(spots[1]), 0.0, 0.01)
	assert_almost_eq(spots[0].distance_to(spots[2]), 0.0, 0.01)


func test_legs_are_measured_and_can_be_posed_in_code() -> void:
	for side: StringName in [&"front", &"back"]:
		assert_true(rig.legs.has(side), "%s leg split upper / lower" % side)
		var leg: Dictionary = rig.legs[side]
		assert_lt(leg.hip.y, leg.knee.y, "hip above knee")
		assert_lt(leg.knee.y, leg.foot.y, "knee above foot")
		assert_eq(rig.drawn_feet[side].size(), rig.frame_count)
	var d := _doll()
	d.play(&"Breath")
	# PLANTED, standing on a step: the back foot's ground is 6 px lower.
	d.leg_mode = PaperDoll.LegMode.PLANTED
	var back: Dictionary = rig.legs[&"back"]
	var front: Dictionary = rig.legs[&"front"]
	var mid: float = (front.foot.x + back.foot.x) * 0.5 - rig.anchor.x
	d.ground_probe = func(x: float) -> float: return 6.0 if x < mid else 0.0
	d._update()
	var feet := d._foot_targets(rig.tag_range(&"legs", &"Breath").x, rig.tag_range(&"body", &"Breath").x)
	for side: StringName in [&"front", &"back"]:
		var want := 6.0 if feet[side].x < mid else 0.0
		assert_almost_eq(feet[side].y, want, 0.01, "%s foot on the ground under it" % side)
	assert_ne(feet[&"front"].y, feet[&"back"].y, "one up a step, one down")
	assert_gt(feet[&"drop"], 0.0, "hips lower a little so it reaches")
	assert_ne(d._slots[back.lower].rotation, 0.0, "the leg is bent to reach, not a frame")
	# POSED: walking moves the feet in turns; one is lifted while the other is down.
	d.leg_mode = PaperDoll.LegMode.POSED
	d.ground_probe = func(_x: float) -> float: return 0.0
	d.walked = d.stride_px * 0.5  # mid step: the back foot swings
	var f := d._foot_targets(0, 0)
	assert_lt(f[&"back"].y, f[&"front"].y, "the swinging foot is lifted")
	d.walked += d.stride_px
	var g := d._foot_targets(0, 0)
	assert_lt(g[&"front"].y, g[&"back"].y, "then the other one")
	d.walked += d.stride_px * 0.5
	assert_ne(f[&"front"].x, d._foot_targets(0, 0)[&"front"].x, "the feet travel")
	# DRAWN: legs are the frames again.
	d.leg_mode = PaperDoll.LegMode.DRAWN
	d._update()
	assert_eq(d._slots[front.lower].rotation, 0.0)
