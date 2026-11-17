extends SceneTree
## Writes the default item types (data/item_types/*.tres): how each kind of item is held
## and its placeholder attack animations, as curves you can edit in the Inspector.
##
##   godot --headless --path . --script res://tools/make_item_types.gd
##   godot --headless --path . --script res://tools/make_item_types.gd -- --force
##
## Without --force, existing files are left alone (so your Inspector edits are safe).
## With --force, every type is rewritten from the defaults below.
## With --update-holds, only each existing file's `hold` motion is replaced with the
## default below (attacks and everything else are kept).
## --only=<id> limits any of these to one type (e.g. --only=spell_book --force).
##
## Angles: degrees, 0 = forward, -90 = up, 90 = down, 180 = behind. For aiming motions
## they're relative to the direction of the cursor. Reach: hand distance from the
## shoulder as a fraction of arm length (1 = straight). Keys are [t, value] with t from
## 0 (start of the motion) to 1 (end).

const DIR := "res://data/item_types"

var _force := false


func _init() -> void:
	_force = OS.get_cmdline_user_args().has("--force")
	if OS.get_cmdline_user_args().has("--update-holds"):
		_update_holds()
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var written := 0
	for t: ItemTypeData in _types():
		var path := "%s/%s.tres" % [DIR, t.id]
		if not _selected(t):
			continue
		if FileAccess.file_exists(path) and not _force:
			print("make_item_types: %s exists, kept (use --force to overwrite)" % path)
			continue
		ResourceSaver.save(t, path)
		written += 1
		print("make_item_types: wrote %s" % path)
	print("make_item_types: %d written" % written)
	quit()


func _selected(t: ItemTypeData) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			return String(t.id) == a.trim_prefix("--only=")
	return true


func _update_holds() -> void:
	for t: ItemTypeData in _types():
		if not _selected(t):
			continue
		var path := "%s/%s.tres" % [DIR, t.id]
		var existing := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemTypeData
		if existing == null:
			ResourceSaver.save(t, path)
			print("make_item_types: wrote %s (new)" % path)
			continue
		existing.hold = t.hold
		ResourceSaver.save(existing, path)
		print("make_item_types: updated the hold in %s" % path)


func _types() -> Array[ItemTypeData]:
	return [_tool(), _big_tool(), _dagger(), _sword(), _greatsword(), _wand(), _spell_book(),
		_crossbow(), _bow(), _unarmed(), _block(), _spell()]


# --- types --------------------------------------------------------------------------------

func _tool() -> ItemTypeData:
	var t := _type(&"tool", "Tool (pickaxe, axe, hammer)")
	t.hold = _natural_hold(-65)
	t.attacks = [_attack("Swing", 0.35,
		_pose([[0, -140], [0.45, -60], [0.7, 20], [1, 35]], [[0, 0.9], [0.6, 1.0], [1, 0.9]]), null,
		[[0, 0]], [[0, 0], [0.6, 2], [1, 0]], "Use")]
	return t


func _big_tool() -> ItemTypeData:
	var t := _type(&"big_tool", "Two-handed tool (sledgehammer, big pick)")
	t.two_handed = true
	t.hold = _natural_hold(-55, "Hold2H")
	t.attacks = [_attack("Slam", 0.5,
		_pose([[0, -160], [0.3, -150], [0.65, 10], [0.8, 40], [1, 35]], [[0, 0.9], [0.65, 1.0], [1, 0.95]]), _grip(),
		[[0, 0]], [[0, -1], [0.65, 3], [1, 0]], "Use")]
	return t


func _dagger() -> ItemTypeData:
	var t := _type(&"dagger", "Dagger")
	t.stow_style = ItemTypeData.StowStyle.HIP
	t.combo_window = 0.3
	t.hold = _natural_hold(-20)
	t.attacks = [
		_attack("Stab", 0.2, _pose([[0, 40], [0.4, 5], [1, 30]], [[0, 0.5], [0.4, 1.0], [1, 0.6]]), null,
			[[0, 0]], [[0, 0], [0.4, 3], [1, 0]]),
		_attack("Stab2", 0.2, _pose([[0, 30], [0.4, -10], [1, 25]], [[0, 0.5], [0.4, 1.0], [1, 0.6]]), null,
			[[0, 0]], [[0, 0], [0.4, 3], [1, 0]]),
		_attack("Slash", 0.28, _pose([[0, -90], [0.6, 40], [1, 50]], [[0, 0.95]]), null,
			[[0, 0]], [[0, 0], [0.6, 2], [1, 0]]),
	]
	return t


func _sword() -> ItemTypeData:
	var t := _type(&"sword", "One-handed sword")
	t.stow_style = ItemTypeData.StowStyle.HIP
	t.hold = _natural_hold(-70)
	t.attacks = [
		_attack("Slash", 0.3, _pose([[0, -130], [0.55, 30], [1, 45]], [[0, 0.95]]), null,
			[[0, 0]], [[0, 0], [0.55, 2], [1, 0]], "Use"),
		_attack("Backslash", 0.3, _pose([[0, 50], [0.55, -100], [1, -115]], [[0, 0.95]]), null,
			[[0, 0]], [[0, 0], [0.55, 1], [1, 0]]),
		_attack("Thrust", 0.28, _pose([[0, 20], [0.35, 0], [1, 10]], [[0, 0.5], [0.35, 1.0], [1, 0.7]]), null,
			[[0, 0]], [[0, 0], [0.35, 4], [1, 0]]),
	]
	return t


func _greatsword() -> ItemTypeData:
	var t := _type(&"greatsword", "Two-handed sword")
	t.two_handed = true
	t.hold = _natural_hold(-60, "Hold2H")
	t.attacks = [
		_attack("Overhead", 0.55, _pose([[0, -165], [0.25, -160], [0.6, 25], [1, 40]], [[0, 0.95]]), _grip(),
			[[0, 0]], [[0, 0], [0.6, 3], [1, 0]], "Use"),
		_attack("Rising", 0.5, _pose([[0, 40], [0.5, -60], [1, -150]], [[0, 0.95]]), _grip(),
			[[0, 0]], [[0, 0], [0.5, 2], [1, 0]]),
	]
	return t


func _wand() -> ItemTypeData:
	var t := _type(&"wand", "Wand")
	t.stow_style = ItemTypeData.StowStyle.HIDDEN
	t.hold = _hold(_pose([[0, 0]], [[0, 0.95]]), null, ItemMotion.ItemAngle.AIM, [[0, 0]], "", true)
	t.attacks = [_attack("Flick", 0.25, _pose([[0, 0], [0.3, -14], [1, 0]], [[0, 0.95], [0.3, 1.0], [1, 0.95]]), null,
		[[0, 0]], null, "", true)]
	t.attacks[0].item_angle_mode = ItemMotion.ItemAngle.ARM
	return t


func _spell_book() -> ItemTypeData:
	var t := _type(&"spell_book", "Spell book")
	t.held_in = ItemTypeData.Hand.BACK
	t.stow_style = ItemTypeData.StowStyle.HIP
	# The back hand holds the book still in front at waist height (forearm out), while
	# running, jumping and casting alike.
	var book_arm := _pose([[0, 35]], [[0, 0.6]])
	book_arm.follows_aim = false  # the book stays put while the front hand aims
	t.hold = _hold(null, book_arm, ItemMotion.ItemAngle.FIXED, [[0, -45]], "")
	var cast := _attack("Cast", 0.4, _pose([[0, 0]], [[0, 0.6], [0.35, 1.0], [1, 0.85]]), book_arm.duplicate(true),
		[[0, -45]], [[0, 0], [0.35, 1], [1, 0]], "", true)
	cast.item_angle_mode = ItemMotion.ItemAngle.FIXED
	t.attacks = [cast]
	return t


func _crossbow() -> ItemTypeData:
	var t := _type(&"crossbow", "Hand crossbow")
	t.stow_style = ItemTypeData.StowStyle.HIP
	t.hold = _hold(_pose([[0, 0]], [[0, 0.9]]), null, ItemMotion.ItemAngle.AIM, [[0, 0]], "", true)
	var fire := _attack("Fire", 0.35, _pose([[0, 0], [0.12, -12], [1, 0]], [[0, 0.9], [0.12, 0.75], [1, 0.9]]), null,
		[[0, 0]], null, "", true)
	fire.item_angle_mode = ItemMotion.ItemAngle.ARM
	t.attacks = [fire]
	return t


func _bow() -> ItemTypeData:
	var t := _type(&"bow", "Bow")
	t.two_handed = true
	t.hold = _hold(_pose([[0, 0]], [[0, 1.0]]), _grip(), ItemMotion.ItemAngle.AIM, [[0, 0]], "", true)
	var draw := _attack("Draw", 0.6, _pose([[0, 0]], [[0, 1.0]]), _grip([[0, 0], [0.7, 7], [0.75, 0], [1, 0]]),
		[[0, 0]], null, "", true)
	draw.item_angle_mode = ItemMotion.ItemAngle.AIM
	t.attacks = [draw]
	return t


func _unarmed() -> ItemTypeData:
	var t := _type(&"unarmed", "Unarmed (punches)")
	t.stow_style = ItemTypeData.StowStyle.HIDDEN
	t.combo_window = 0.35
	t.hold = _hold(null, null, ItemMotion.ItemAngle.FIXED, [[0, 0]], "")
	t.attacks = [
		_attack("Jab", 0.18, _pose([[0, 20], [0.4, -5], [1, 15]], [[0, 0.45], [0.4, 1.0], [1, 0.5]]), null,
			[[0, 0]], [[0, 0], [0.4, 2], [1, 0]]),
		_attack("Cross", 0.22, null, _pose([[0, 25], [0.45, -5], [1, 20]], [[0, 0.45], [0.45, 1.0], [1, 0.5]]),
			[[0, 0]], [[0, 0], [0.45, 3], [1, 0]]),
		_attack("Uppercut", 0.3, _pose([[0, 60], [0.5, -60], [1, -40]], [[0, 0.5], [0.5, 0.9], [1, 0.6]]), null,
			[[0, 0]], [[0, 0], [0.5, 2], [1, 0]]),
	]
	return t


func _block() -> ItemTypeData:
	var t := _type(&"block", "Block, material or seed (held small, placed with a quick reach)")
	t.stow_style = ItemTypeData.StowStyle.HIDDEN
	t.hold = _natural_hold(-30)
	t.hold.drawn_tag = ""
	# A short reach toward the cursor; the block is placed at the end of it.
	var place := _attack("Place", 0.18, _pose([[0, -25], [0.5, 0], [1, 5]], [[0, 0.7], [0.5, 1.0], [1, 0.85]]), null,
		[[0, -30]], null, "", true)
	t.attacks = [place]
	return t


func _spell() -> ItemTypeData:
	var t := _type(&"spell", "Spell (the equipped book in the back hand, the front hand channels at the cursor)")
	t.held_in = ItemTypeData.Hand.BACK
	t.stow_style = ItemTypeData.StowStyle.HIDDEN
	# Same book hold as spell_book: held still in front at waist height.
	var book_arm := _pose([[0, 35]], [[0, 0.6]])
	book_arm.follows_aim = false
	t.hold = _hold(null, book_arm, ItemMotion.ItemAngle.FIXED, [[0, -45]], "")
	# Front arm straight at the cursor while the button is held; loops.
	var channel := _attack("Channel", 0.3, _pose([[0, 0]], [[0, 1.0]]), book_arm.duplicate(true), [[0, -45]], null, "", true)
	channel.item_angle_mode = ItemMotion.ItemAngle.FIXED
	t.attacks = [channel]
	t.combo_window = 0.2  # > 0 so holding the button chains straight into the next loop
	return t


# --- builders -----------------------------------------------------------------------------

func _type(type_id: StringName, label: String) -> ItemTypeData:
	var t := ItemTypeData.new()
	t.id = type_id
	t.display_name = label
	return t


func _hold(front: ArmTrack, back: ArmTrack, angle_mode: ItemMotion.ItemAngle, item_angle: Array,
		drawn: String, aims: bool = false) -> ItemMotion:
	var m := ItemMotion.new()
	m.name = "Hold"
	m.duration = 1.0
	m.aims = aims
	m.front = front if front else _natural()
	m.back = back if back else _natural()
	m.item_angle_mode = angle_mode
	m.item_angle = _curve(item_angle, -180, 180)
	m.drawn_tag = drawn
	return m


## Held in the arm as you drew it (it swings with the run); the item rides in the hand,
## pointing `angle` degrees (0 = forward, -90 = up) when the arm hangs straight down and
## tilting with the arm as it swings. Picking the item up doesn't change the arm.
func _natural_hold(angle: float, drawn: String = "Hold1H") -> ItemMotion:
	return _hold(null, null, ItemMotion.ItemAngle.ARM, [[0, angle - 90.0]], drawn)


func _attack(motion_name: String, duration: float, front: ArmTrack, back: ArmTrack, item_angle: Array,
		lunge: Variant, drawn: String = "", aims: bool = false) -> ItemMotion:
	var m := ItemMotion.new()
	m.name = motion_name
	m.duration = duration
	m.aims = aims
	m.front = front if front else _natural()
	m.back = back if back else _natural()
	m.item_angle_mode = ItemMotion.ItemAngle.ARM
	m.item_angle = _curve(item_angle, -180, 180)
	if lunge != null:
		m.lunge = _curve(lunge, -8, 8)
	m.drawn_tag = drawn
	return m


func _pose(angles: Array, reaches: Array) -> ArmTrack:
	var a := ArmTrack.new()
	a.mode = ArmTrack.Mode.POSE
	a.angle = _curve(angles, -180, 180)
	a.reach = _curve(reaches, 0, 1)
	return a


func _grip(pull: Array = []) -> ArmTrack:
	var a := ArmTrack.new()
	a.mode = ArmTrack.Mode.GRIP
	if not pull.is_empty():
		a.pull = _curve(pull, -4, 12)
	return a


func _natural() -> ArmTrack:
	return ArmTrack.new()


func _curve(keys: Array, lo: float, hi: float) -> Curve:
	var c := Curve.new()
	c.min_value = lo
	c.max_value = hi
	for k: Array in keys:
		c.add_point(Vector2(float(k[0]), float(k[1])), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return c
