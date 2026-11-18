class_name MainMenu
extends Node2D
## Start screen. Play -> pick a character (or make one) -> pick a world (or make one).
## Any character can play any world. Debug builds add Test Course and Doll Viewer.
## Built in code; every page is a panel that replaces the previous one.
##
## Scripted runs (DevCli world or input arguments) skip the menu and go straight into a
## temporary world, so screenshot commands keep working. `-- --menu` stays here;
## `-- --menu=characters`, `new_character` or `worlds` opens that page.

const DOLL_VIEWER := "res://scenes/dev/doll_viewer.tscn"
const SHEET := "res://assets/sprites/scholar"
const PALETTE := "res://assets/sprites/scholar_palette.tres"
const NAME_MAX := 20

## Palette groups the creator lets you color, with their labels, in order.
const GROUPS: Array[Array] = [
	[&"skin", "Skin"], [&"hair", "Hair"], [&"tunic", "Tunic"], [&"trim", "Trim"],
	[&"pants", "Pants"], [&"leather", "Boots, belt"],
]
## Preset swatches per group (the clothes groups share one list).
const SKIN_PRESETS := ["ffe0c8", "f3d2b3", "e8b98f", "d49a6a", "b97a4f", "9a5f3a", "7a4529", "5c321e", "3f2214", "2c180e"]
const HAIR_PRESETS := ["1c1410", "3b2416", "5c3a22", "8a5a2b", "b8823d", "e0c070", "f0e6d0", "8c8c8c", "a83a2a", "3a4a8a"]
const CLOTH_PRESETS := ["2f5fbf", "3a7a3a", "8a2a2a", "6a3a8a", "c8a040", "2a2a2a", "d8d0c0", "8a5a3a", "3a8a8a", "c86a2a"]
const LEATHER_PRESETS := ["2a1e18", "3a2a20", "5a3a28", "7a5030", "2a2a2a", "4a4a4a", "6a2a20", "3a3a5a", "8a6a4a", "1a1a1a"]

var _ui: CanvasLayer
var _page: Control
var _camera: Camera2D
## The character picked on the character page (the world page plays it).
var _chosen: CharacterData
## Being made on the New Character page.
var _draft: CharacterData
var _draft_group: StringName = &"skin"
var _palette: CharacterPalette
var _rig: DollRig


func _ready() -> void:
	Game.set_state(Game.State.MAIN_MENU)
	if DevCli.scene_override == "doll":
		get_tree().change_scene_to_file.call_deferred(DOLL_VIEWER)
		return
	if DevCli.wants_world():
		Game.start_world.call_deferred(DevCli.world_info(), DevCli.character())
		return
	var backdrop := Backdrop.new()
	add_child(backdrop)
	_camera = Camera2D.new()
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(_camera)
	_camera.make_current()
	_ui = CanvasLayer.new()
	add_child(_ui)
	_palette = load(PALETTE) as CharacterPalette
	_rig = DollRig.load_from(SHEET)
	match DevCli.menu_page:
		"characters":
			_show_characters()
		"new_character":
			_show_new_character()
		"worlds":
			_chosen = _first_character()
			_show_worlds()
		"new_world":
			_chosen = _first_character()
			_show_new_world()
		_:
			_show_main()


func _physics_process(delta: float) -> void:
	if _camera:
		_camera.position.x += 12.0 * delta  # slow drift for the parallax backdrop


func _new_page(min_width: float = 180.0) -> VBoxContainer:
	if _page:
		_page.queue_free()
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_page)
	return UiKit.panel(_page, min_width)


func _show_main() -> void:
	var box := _new_page()
	box.add_child(UiKit.label("game-prototype", 18, UiKit.GOLD))
	box.add_child(UiKit.label("placeholder title", 8, UiKit.DIM))
	box.add_child(UiKit.button("Play", _show_characters))
	if OS.is_debug_build():
		box.add_child(UiKit.label("dev", 8, UiKit.DIM))
		box.add_child(UiKit.button("Test Course", func() -> void: Game.start_world(WorldInfo.test_course(), DevCli.character())))
		box.add_child(UiKit.button("Doll Viewer", func() -> void: get_tree().change_scene_to_file(DOLL_VIEWER)))
	box.add_child(UiKit.button("Quit", func() -> void: get_tree().quit()))
	(box.get_child(2) as Button).grab_focus.call_deferred()


# --- characters ------------------------------------------------------------------------

func _first_character() -> CharacterData:
	var all := CharacterData.list_saved()
	return all[0] if not all.is_empty() else CharacterData.create("Scholar")


func _show_characters() -> void:
	var box := _new_page(300)
	box.add_child(UiKit.label("Choose a character", 14, UiKit.GOLD))
	var all := CharacterData.list_saved()
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	box.add_child(body)
	var preview := _make_preview()
	body.add_child(preview[0])
	var doll: PaperDoll = preview[1]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(list)
	if all.is_empty():
		list.add_child(UiKit.label("No characters yet.", 10, UiKit.DIM))
		doll.visible = false
	else:
		doll.look = all[0].make_look()
	for c in all:
		var row := HBoxContainer.new()
		var play := UiKit.button(c.name, func() -> void:
			_chosen = c
			_show_worlds(), 150)
		play.mouse_entered.connect(func() -> void: doll.look = c.make_look())
		play.focus_entered.connect(func() -> void: doll.look = c.make_look())
		row.add_child(play)
		row.add_child(UiKit.button("Delete", func() -> void: _confirm_delete_character(c), 44))
		list.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_child(spacer)
	list.add_child(UiKit.button("New Character", _show_new_character, 150))
	list.add_child(UiKit.button("Back", _show_main, 150))


func _confirm_delete_character(c: CharacterData) -> void:
	var box := _new_page()
	box.add_child(UiKit.label("Delete \"%s\"?" % c.name, 12))
	box.add_child(UiKit.label("Their items and spells are lost. This can't be undone.", 8, UiKit.DIM))
	box.add_child(UiKit.button("Delete", func() -> void:
		CharacterData.delete(c.name)
		_show_characters()))
	box.add_child(UiKit.button("Cancel", _show_characters))


## A live, animated paper doll in a small viewport: [container, doll].
func _make_preview(scale_by: float = 2.0) -> Array:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(48, 76) * scale_by
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(holder.custom_minimum_size)
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	holder.add_child(vp)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0, 0, 0, 0.25)
	floor_rect.position = Vector2(8, vp.size.y - 8)
	floor_rect.size = Vector2(vp.size.x - 16, 3)
	vp.add_child(floor_rect)
	var doll := PaperDoll.new()
	vp.add_child(doll)
	doll.setup(_rig, _palette)
	doll.scale = Vector2(scale_by, scale_by)
	doll.position = Vector2(vp.size.x * 0.5, vp.size.y - 8)
	doll.play(&"Breath")
	return [holder, doll]


func _show_new_character() -> void:
	_draft = CharacterData.create(_unused_character_name())
	for g: Array in GROUPS:
		_draft.colors[g[0]] = _palette.mid_color(g[0])
	_draft_group = &"skin"
	_build_creator()


## The creator page (rebuilt when the active color group changes).
func _build_creator() -> void:
	var box := _new_page(420)
	box.add_child(UiKit.label("New Character", 14, UiKit.GOLD))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	box.add_child(body)
	var preview := _make_preview(2.5)
	body.add_child(preview[0])
	var doll: PaperDoll = preview[1]
	var refresh := func() -> void: doll.look = _draft.make_look()
	refresh.call()
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 2)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(form)
	# Name.
	var name_edit := UiKit.line_edit("Name", _draft.name)
	name_edit.max_length = NAME_MAX
	name_edit.text_changed.connect(func(t: String) -> void: _draft.name = t)
	form.add_child(UiKit.row("Name", name_edit))
	# Hairstyle.
	var styles := CharacterData.hairstyles()
	var hair_row := HBoxContainer.new()
	var hair_label := UiKit.label(_hair_name(_draft.hairstyle), 10)
	hair_label.custom_minimum_size = Vector2(80, 0)
	var cycle := func(step: int) -> void:
		var options: Array[StringName] = [&""]
		options.append_array(styles)
		var i := options.find(_draft.hairstyle)
		_draft.hairstyle = options[posmod(i + step, options.size())]
		hair_label.text = _hair_name(_draft.hairstyle)
		refresh.call()
	hair_row.add_child(UiKit.button("<", func() -> void: cycle.call(-1), 20))
	hair_row.add_child(hair_label)
	hair_row.add_child(UiKit.button(">", func() -> void: cycle.call(1), 20))
	form.add_child(UiKit.row("Hair", hair_row))
	# Color groups: label, preset swatches, the current color.
	for g: Array in GROUPS:
		var group: StringName = g[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var pick := UiKit.button(g[1], func() -> void:
			_draft_group = group
			_build_creator(), 58)
		pick.custom_minimum_size.y = 14
		pick.add_theme_font_size_override("font_size", 8)
		if group == _draft_group:
			pick.add_theme_color_override("font_color", UiKit.GOLD)
		row.add_child(pick)
		for hex: String in _presets(group):
			row.add_child(_swatch(Color(hex), func() -> void:
				_draft.colors[group] = Color(hex)
				_draft_group = group
				_build_creator()))
		var current := ColorRect.new()
		current.color = _draft.colors.get(group, _palette.mid_color(group))
		current.custom_minimum_size = Vector2(16, 12)
		row.add_child(current)
		form.add_child(row)
	# Fine tuning for the active group.
	var tune_label := UiKit.label("Adjust %s" % _group_label(_draft_group).to_lower(), 8, UiKit.DIM)
	tune_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	form.add_child(tune_label)
	var base: Color = _draft.colors.get(_draft_group, _palette.mid_color(_draft_group))
	var sliders: Array[HSlider] = []
	for part: String in ["Hue", "Color", "Light"]:
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01
		s.custom_minimum_size = Vector2(150, 10)
		s.value = {"Hue": base.h, "Color": base.s, "Light": base.v}[part]
		sliders.append(s)
		form.add_child(UiKit.row(part, s))
	for s in sliders:
		s.value_changed.connect(func(_v: float) -> void:
			_draft.colors[_draft_group] = Color.from_hsv(sliders[0].value, sliders[1].value, sliders[2].value)
			refresh.call())
	var error := UiKit.label("", 8, UiSkin.BAD)
	box.add_child(error)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 6)
	buttons.add_child(UiKit.button("Randomize", func() -> void:
		randomize_draft()
		_build_creator(), 80))
	buttons.add_child(UiKit.button("Create", func() -> void:
		var problem := create_draft()
		if problem != "":
			error.text = problem
			return
		_chosen = CharacterData.load_or_create(_draft.name.strip_edges())
		_show_worlds(), 80))
	buttons.add_child(UiKit.button("Back", _show_characters, 80))
	box.add_child(buttons)


## Saves the draft as a new character. Returns a problem to show, or "".
func create_draft() -> String:
	var char_name := _draft.name.strip_edges()
	if char_name.is_empty():
		return "Give your character a name."
	if CharacterData.exists(char_name):
		return "A character with that name already exists."
	_draft.name = char_name
	var err := _draft.save()
	return "" if err == OK else "Couldn't save: %s" % error_string(err)


func randomize_draft() -> void:
	for g: Array in GROUPS:
		var presets := _presets(g[0])
		_draft.colors[g[0]] = Color(presets[randi() % presets.size()])
	var styles := CharacterData.hairstyles()
	if not styles.is_empty() and randf() > 0.1:
		_draft.hairstyle = styles[randi() % styles.size()]


func _presets(group: StringName) -> Array:
	match group:
		&"skin":
			return SKIN_PRESETS
		&"hair":
			return HAIR_PRESETS
		&"leather":
			return LEATHER_PRESETS
	return CLOTH_PRESETS


func _group_label(group: StringName) -> String:
	for g: Array in GROUPS:
		if g[0] == group:
			return g[1]
	return String(group)


func _hair_name(style: StringName) -> String:
	return "Bald" if style == &"" else String(style).capitalize()


func _swatch(color: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(12, 12)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_border_width_all(1)
	sb.border_color = color.darkened(0.45)
	b.add_theme_stylebox_override("normal", sb)
	var hot := sb.duplicate() as StyleBoxFlat
	hot.border_color = UiSkin.GOLD
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.pressed.connect(on_press)
	return b


func _unused_character_name() -> String:
	var n := 1
	while CharacterData.exists("Scholar %d" % n if n > 1 else "Scholar"):
		n += 1
	return "Scholar %d" % n if n > 1 else "Scholar"


# --- worlds ----------------------------------------------------------------------------

func _show_worlds() -> void:
	var box := _new_page(260)
	box.add_child(UiKit.label("Playing as %s" % _chosen.name, 14, UiKit.GOLD))
	box.add_child(UiKit.label("Pick a world", 8, UiKit.DIM))
	var infos: Array[WorldInfo] = []
	for world_name in SaveManager.list_worlds():
		var info := WorldSave.read_info(SaveManager.world_path(world_name))
		if info:
			infos.append(info)
	infos.sort_custom(func(a: WorldInfo, b: WorldInfo) -> bool: return a.last_played_unix > b.last_played_unix)
	if infos.is_empty():
		box.add_child(UiKit.label("No saved worlds yet.", 10, UiKit.DIM))
	for info in infos:
		var row := HBoxContainer.new()
		row.add_child(UiKit.button("%s  (%s, seed %d)" % [info.name, info.size_name(), info.seed],
			func() -> void: Game.start_world(info, _chosen), 190))
		row.add_child(UiKit.button("Delete", func() -> void: _confirm_delete_world(info), 44))
		box.add_child(row)
	box.add_child(UiKit.button("New World", _show_new_world))
	box.add_child(UiKit.button("Back", _show_characters))


func _show_new_world() -> void:
	var box := _new_page()
	box.add_child(UiKit.label("New World", 14, UiKit.GOLD))
	var name_edit := UiKit.line_edit("World name", _unused_name())
	box.add_child(UiKit.row("Name", name_edit))
	var size_pick := OptionButton.new()
	size_pick.add_theme_font_size_override("font_size", 10)
	for s: String in ["Small", "Medium", "Large"]:
		size_pick.add_item(s, WorldData.Size.get(s.to_upper()))
	box.add_child(UiKit.row("Size", size_pick))
	var seed_edit := UiKit.line_edit("random")
	box.add_child(UiKit.row("Seed", seed_edit))
	box.add_child(UiKit.label("A seed can be any number or word. Blank = random.", 8, UiKit.DIM))
	var hunger := CheckButton.new()
	hunger.button_pressed = true
	hunger.text = "on"
	hunger.toggled.connect(func(on: bool) -> void: hunger.text = "on" if on else "off")
	box.add_child(UiKit.row("Hunger", hunger))
	var death := OptionButton.new()
	death.add_theme_font_size_override("font_size", 10)
	death.add_item("Drop items in a magic bag", WorldInfo.DeathDrop.BAG)
	death.add_item("Keep items", WorldInfo.DeathDrop.KEEP)
	box.add_child(UiKit.row("On death", death))
	var error := UiKit.label("", 8, UiSkin.BAD)
	box.add_child(error)
	var create := func() -> void:
		var world_name := name_edit.text.strip_edges()
		if world_name.is_empty():
			error.text = "Give the world a name."
			return
		var path := SaveManager.world_path(world_name)
		if FileAccess.file_exists(path):
			error.text = "A world with that name already exists."
			return
		var size: WorldData.Size = size_pick.get_selected_id() as WorldData.Size
		var info := WorldInfo.create(world_name, size, WorldInfo.seed_from_text(seed_edit.text))
		info.hunger = hunger.button_pressed
		info.death_drop = death.get_selected_id() as WorldInfo.DeathDrop
		info.path = path
		Game.start_world(info, _chosen)
	box.add_child(UiKit.button("Create", create))
	box.add_child(UiKit.button("Back", _show_worlds))
	name_edit.grab_focus.call_deferred()


func _confirm_delete_world(info: WorldInfo) -> void:
	var box := _new_page()
	box.add_child(UiKit.label("Delete \"%s\"?" % info.name, 12))
	box.add_child(UiKit.label("This can't be undone.", 8, UiKit.DIM))
	box.add_child(UiKit.button("Delete", func() -> void:
		WorldSave.delete(info.path)
		_show_worlds()))
	box.add_child(UiKit.button("Cancel", _show_worlds))


func _unused_name() -> String:
	var n := 1
	while FileAccess.file_exists(SaveManager.world_path("World %d" % n)):
		n += 1
	return "World %d" % n
