class_name DollViewer
extends Node2D
## Dev scene: every arm mode side by side, to check art and compare drawn frames with
## code-posed arms. Open from the main menu (Doll Viewer, debug builds), with
## `-- --scene=doll`, or run scenes/dev/doll_viewer.tscn directly (F6 in the editor).
##
## Top row: drawn frames where the art has them (otherwise code-posed, labeled).
## Bottom row: always code-posed. Aiming dolls point at the mouse.
## Buttons: legs animation, facing, colors, hair. Re-import the .aseprite and reopen
## this scene to see new art.

const SHEET := "res://assets/sprites/scholar"
const PALETTE := "res://assets/sprites/scholar_palette.tres"
const LOOK := "res://assets/sprites/scholar_look.tres"
const COLUMNS := ["Empty", "Hold 1H", "Hold 2H", "Use 1H", "Use 2H", "Aim", "On back", "At hip"]
const ANIMS: Array[StringName] = [&"Breath", &"Jog", &"Jump", &"Idle Pose"]
const SKINS := ["eec39a", "c98e62", "8d5a3b", "f5d7c0", "5c3a28"]
const CLOTHES := ["2f68d9", "3c8a3c", "a83232", "6a4aa8", "c8a040", "444a52"]
const HAIRS := ["5c3a22", "1c1814", "c89a48", "a04020", "d8d0c0"]

var _rig: DollRig
var _palette: CharacterPalette
var _look: CharacterLook
var _items: Array[HeldItemLook]
var _dolls: Array[PaperDoll] = []
var _anim := 0
var _facing := 1.0
var _time := 0.0
var _info: Label


func _ready() -> void:
	_rig = DollRig.load_from(SHEET)
	_palette = load(PALETTE) as CharacterPalette
	_look = (load(LOOK) as CharacterLook).duplicate() as CharacterLook
	_items = DevHeldItems.make_items()
	var bg := ColorRect.new()
	bg.color = Color("5a6a78")
	bg.size = Vector2(640, 360)
	add_child(bg)
	var cam := Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(cam)

	for row in 2:
		for col in COLUMNS.size():
			var d := PaperDoll.new()
			add_child(d)
			d.setup(_rig, _palette)
			d.look = _look
			d.position = Vector2(48 + col * 78, 170 + row * 120)
			d.force_posed = row == 1
			_configure(d, col)
			_dolls.append(d)
			var label := UiKit.label(_column_label(col, row == 1), 8, UiKit.TEXT)
			label.position = Vector2(d.position.x - 38, d.position.y + 4)
			label.size = Vector2(76, 12)
			add_child(label)

	var ui := CanvasLayer.new()
	add_child(ui)
	var bar := HBoxContainer.new()
	bar.position = Vector2(6, 6)
	bar.add_theme_constant_override("separation", 4)
	ui.add_child(bar)
	bar.add_child(UiKit.button("Animation", _next_anim, 70))
	bar.add_child(UiKit.button("Flip", func() -> void: _facing = -_facing, 40))
	bar.add_child(UiKit.button("Colors", _random_colors, 50))
	bar.add_child(UiKit.button("Reset colors", _reset_colors, 76))
	bar.add_child(UiKit.button("Hair", _toggle_hair, 40))
	bar.add_child(UiKit.button("Back", func() -> void: Game.quit_to_menu(), 40))
	_info = UiKit.label("", 8, UiKit.TEXT)
	_info.position = Vector2(6, 30)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ui.add_child(_info)
	_update_info()


func _column_label(col: int, posed_row: bool) -> String:
	var name: String = COLUMNS[col]
	if posed_row:
		return name + " (code)"
	var tag := ""
	match col:
		1, 3:
			tag = "Hold1H" if col == 1 else "Use"
		2, 4:
			tag = "Hold2H" if col == 2 else "Use"
	if tag != "" and not _rig.tags.has("arms/" + tag):
		return name + " (no art)"
	return name


func _configure(d: PaperDoll, col: int) -> void:
	match col:
		0:
			d.item = null
		1:
			d.item = _items[0]
			d.arm_mode = PaperDoll.ArmMode.HOLD
		2:
			d.item = _items[1]
			d.arm_mode = PaperDoll.ArmMode.HOLD
		3:
			d.item = _items[0]
			d.arm_mode = PaperDoll.ArmMode.USE
		4:
			d.item = _items[1]
			d.arm_mode = PaperDoll.ArmMode.USE
		5:
			d.item = _items[2]
			d.arm_mode = PaperDoll.ArmMode.AIM
		6:
			d.item = _items[0]
			d.stowed = true
		7:
			d.item = _items[3]
			d.stowed = true


func _process(delta: float) -> void:
	_time += delta
	var mouse := get_global_mouse_position()
	if DevCli.wants_world() or DevCli.scene_override != "":
		# Scripted screenshots: aim at a point circling above the dolls.
		mouse = Vector2(320 + cos(_time * 2.0) * 200, 60 + sin(_time * 2.0) * 40)
	for d in _dolls:
		d.scale.x = _facing
		d.play(ANIMS[_anim])
		d.aim_global = mouse
		if d.arm_mode == PaperDoll.ArmMode.USE:
			var t := d.item.use_time if d.item else 0.4
			d.use_progress = fposmod(_time, t + 0.3) / t
			if d.use_progress > 1.0:
				d.use_progress = 1.0


func _next_anim() -> void:
	_anim = (_anim + 1) % ANIMS.size()
	_update_info()


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
	for d in _dolls:
		d.look = _look


func _update_info() -> void:
	_info.text = "Legs: %s   Top: drawn art where it exists. Bottom: code-posed. Aim follows the mouse." % ANIMS[_anim]
