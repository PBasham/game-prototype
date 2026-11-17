class_name DollViewer
extends Node2D
## Dev scene: the character holding and using every placeholder item, to check art and
## poses. Open from the main menu (Doll Viewer, debug builds), with `-- --scene=doll`,
## or run scenes/dev/doll_viewer.tscn directly (F6 in the editor).
##
## Top row: holding each item. Bottom row: its attacks, played as the full combo on a
## loop (aiming ones point at the mouse). The last column is unarmed punching (what
## empty hands do in game). Arms use hand-drawn frames where the art has
## them and code posing otherwise; "Code posing: forced" shows code posing everywhere,
## to compare once drawn frames exist.

const SHEET := "res://assets/sprites/scholar"
const PALETTE := "res://assets/sprites/scholar_palette.tres"
const LOOK := "res://assets/sprites/scholar_look.tres"
const ANIMS: Array[StringName] = [&"Breath", &"Jog", &"Jump", &"Idle Pose"]
const SKINS := ["eec39a", "c98e62", "8d5a3b", "f5d7c0", "5c3a28"]
const CLOTHES := ["2f68d9", "3c8a3c", "a83232", "6a4aa8", "c8a040", "444a52"]
const HAIRS := ["5c3a22", "1c1814", "c89a48", "a04020", "d8d0c0"]
const SPACING := 53.0

var _rig: DollRig
var _unarmed: ItemTypeData
var _palette: CharacterPalette
var _look: CharacterLook
var _held: Array[PaperDoll] = []
var _using: Array[PaperDoll] = []
var _anim := 0
var _facing := 1.0
var _time := 0.0
var _forced := false
var _stowed := false
var _info: Label
var _force_button: Button
var _stow_button: Button


func _ready() -> void:
	_rig = DollRig.load_from(SHEET)
	_palette = load(PALETTE) as CharacterPalette
	_look = (load(LOOK) as CharacterLook).duplicate() as CharacterLook
	var bg := ColorRect.new()
	bg.color = Color("5a6a78")
	bg.size = Vector2(640, 360)
	add_child(bg)
	var cam := Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(cam)

	var catalog := DevHeldItems.catalog()
	_unarmed = load("res://data/item_types/unarmed.tres") as ItemTypeData
	for i in catalog.size() + 1:
		var x := 30.0 + i * SPACING
		var it: HeldItemLook = catalog[i][1] if i < catalog.size() else null
		_held.append(_make_doll(Vector2(x, 168), it))
		_using.append(_make_doll(Vector2(x, 300), it))
		_label(String(catalog[i][0]) if i < catalog.size() else "Unarmed", Vector2(x, 306))
	_label("holding", Vector2(6, 46), true)
	_label("attacking (whole combo, looped; aimed ones follow the mouse)", Vector2(6, 186), true)

	var ui := CanvasLayer.new()
	add_child(ui)
	var bar := HBoxContainer.new()
	bar.position = Vector2(6, 6)
	bar.add_theme_constant_override("separation", 4)
	ui.add_child(bar)
	bar.add_child(UiKit.button("Animation", _next_anim, 62))
	_force_button = UiKit.button("", _toggle_forced, 112)
	bar.add_child(_force_button)
	_stow_button = UiKit.button("", _toggle_stowed, 58)
	bar.add_child(_stow_button)
	bar.add_child(UiKit.button("Flip", func() -> void: _facing = -_facing, 32))
	bar.add_child(UiKit.button("Colors", _random_colors, 44))
	bar.add_child(UiKit.button("Reset", _reset_colors, 40))
	bar.add_child(UiKit.button("Hair", _toggle_hair, 34))
	bar.add_child(UiKit.button("Reload", _reload, 40))
	bar.add_child(UiKit.button("Back", func() -> void: Game.quit_to_menu(), 36))
	_info = UiKit.label("", 8, UiKit.TEXT)
	_info.position = Vector2(6, 30)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ui.add_child(_info)
	_refresh()


func _make_doll(pos: Vector2, item: HeldItemLook) -> PaperDoll:
	var d := PaperDoll.new()
	add_child(d)
	d.setup(_rig, _palette)
	d.look = _look
	d.position = pos
	d.item = item
	return d


func _label(text: String, pos: Vector2, left: bool = false) -> void:
	var l := UiKit.label(text, 8, UiKit.TEXT)
	l.size = Vector2(SPACING if not left else 300, 12)
	l.position = pos - Vector2(0 if left else SPACING / 2.0, 0)
	if left:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(l)


func _process(delta: float) -> void:
	_time += delta
	var mouse := get_global_mouse_position()
	if DevCli.scene_override != "":
		# Scripted screenshots: aim at a point circling above the dolls.
		mouse = Vector2(320 + cos(_time * 1.5) * 220, 40 + sin(_time * 1.5) * 30)
	for i in _held.size():
		_drive(_held[i], false, mouse)
		_drive(_using[i], true, mouse)


## Sets one doll's state the way Player._animate_arms() would.
func _drive(d: PaperDoll, attacking: bool, mouse: Vector2) -> void:
	d.play(ANIMS[_anim])
	if ANIMS[_anim] == &"Breath" and d.has_animation(&"Stand") and (attacking or d.item != null):
		d.play(&"Stand")  # same as Player._show_stance()
	d.force_posed = _forced
	d.stowed = _stowed
	d.aim_global = mouse
	var item := d.item
	d.motion = null
	if attacking and not _stowed:
		if item:
			_play_chain(d, item.attacks())
		elif d == _using[_using.size() - 1]:
			_play_chain(d, _unarmed.attacks)  # empty hands do nothing; this column previews punches
	elif item != null and not _stowed:
		d.motion = item.hold_motion()
		d.motion_t = fposmod(_time, d.motion.duration) / d.motion.duration
	var facing := _facing
	if d.motion and (d.motion.aims or attacking):
		facing = 1.0 if mouse.x >= d.global_position.x else -1.0  # face the cursor
	d.scale.x = facing


## Plays a combo chain on a loop: each attack, a short pause, the next.
func _play_chain(d: PaperDoll, chain: Array[ItemMotion]) -> void:
	const GAP := 0.12
	var total := 0.4
	for m in chain:
		total += m.duration + GAP
	var t := fposmod(_time, total)
	for m in chain:
		if t < m.duration:
			d.motion = m
			d.motion_t = t / m.duration
			return
		t -= m.duration
		if t < GAP:
			d.motion = m
			d.motion_t = 1.0
			return
		t -= GAP
	d.motion = chain[chain.size() - 1] if not chain.is_empty() else null
	d.motion_t = 1.0


## Re-reads data/item_types after you edit and save one in the editor.
func _reload() -> void:
	HeldItemLook.reload_types()
	_unarmed = load("res://data/item_types/unarmed.tres") as ItemTypeData


func _toggle_forced() -> void:
	_forced = not _forced
	_refresh()


func _toggle_stowed() -> void:
	_stowed = not _stowed
	_refresh()


func _next_anim() -> void:
	_anim = (_anim + 1) % ANIMS.size()
	_refresh()


func _random_colors() -> void:
	_look.colors[&"skin"] = Color(SKINS[randi() % SKINS.size()])
	_look.colors[&"tunic"] = Color(CLOTHES[randi() % CLOTHES.size()])
	_look.colors[&"pants"] = Color(CLOTHES[randi() % CLOTHES.size()]).darkened(0.15)
	_look.colors[&"hair"] = Color(HAIRS[randi() % HAIRS.size()])
	_apply_look()


func _reset_colors() -> void:
	_look.colors.clear()
	_apply_look()


func _toggle_hair() -> void:
	_look.hair = null if _look.hair else (load(LOOK) as CharacterLook).hair
	_apply_look()


func _apply_look() -> void:
	for d in _held + _using:
		d.look = _look


func _refresh() -> void:
	_force_button.text = "Code posing: %s" % ("forced" if _forced else "auto")
	_stow_button.text = "Put away" if not _stowed else "Take out"
	var drawn := PackedStringArray()
	for tag: String in _rig.tags:
		if tag.begins_with("arms/"):
			drawn.append(tag.trim_prefix("arms/"))
	_info.text = "Legs: %s.  Hand-drawn arm frames: %s." % [ANIMS[_anim],
		", ".join(drawn) if drawn.size() > 0 else "none yet, so every arm pose here is code-posed"]
