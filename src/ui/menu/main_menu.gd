class_name MainMenu
extends Node2D
## Start screen: New World, Load World, Test Course (debug builds), Quit.
## Built in code; every page is a panel that replaces the previous one.
##
## Scripted runs (DevCli world or input arguments) skip the menu and go straight into a
## temporary world, so screenshot commands keep working. `-- --menu` stays here.

var _ui: CanvasLayer
var _page: Control
var _camera: Camera2D


func _ready() -> void:
	Game.set_state(Game.State.MAIN_MENU)
	if DevCli.wants_world():
		Game.start_world.call_deferred(DevCli.world_info())
		return
	var backdrop := Backdrop.new()
	add_child(backdrop)
	_camera = Camera2D.new()
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(_camera)
	_camera.make_current()
	_ui = CanvasLayer.new()
	add_child(_ui)
	_show_main()


func _physics_process(delta: float) -> void:
	if _camera:
		_camera.position.x += 12.0 * delta  # slow drift for the parallax backdrop


func _new_page() -> VBoxContainer:
	if _page:
		_page.queue_free()
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_page)
	return UiKit.panel(_page)


func _show_main() -> void:
	var box := _new_page()
	box.add_child(UiKit.label("game-prototype", 18))
	box.add_child(UiKit.label("placeholder title", 8, UiKit.DIM))
	box.add_child(UiKit.button("New World", _show_new_world))
	var load := UiKit.button("Load World", _show_load_world)
	load.disabled = SaveManager.list_worlds().is_empty()
	box.add_child(load)
	if OS.is_debug_build():
		box.add_child(UiKit.label("dev", 8, UiKit.DIM))
		box.add_child(UiKit.button("Test Course", func() -> void: Game.start_world(WorldInfo.test_course())))
	box.add_child(UiKit.button("Quit", func() -> void: get_tree().quit()))
	(box.get_child(2) as Button).grab_focus.call_deferred()


func _show_new_world() -> void:
	var box := _new_page()
	box.add_child(UiKit.label("New World", 14))
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
	var error := UiKit.label("", 8, Color("e08070"))
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
		info.path = path
		Game.start_world(info)
	box.add_child(UiKit.button("Create", create))
	box.add_child(UiKit.button("Back", _show_main))
	name_edit.grab_focus.call_deferred()


func _show_load_world() -> void:
	var box := _new_page()
	box.add_child(UiKit.label("Load World", 14))
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
		var play := UiKit.button("%s  (%s, seed %d)" % [info.name, info.size_name(), info.seed],
			func() -> void: Game.start_world(info), 170)
		row.add_child(play)
		var del := UiKit.button("Delete", func() -> void: _confirm_delete(info), 44)
		row.add_child(del)
		box.add_child(row)
	box.add_child(UiKit.button("Back", _show_main))


func _confirm_delete(info: WorldInfo) -> void:
	var box := _new_page()
	box.add_child(UiKit.label("Delete \"%s\"?" % info.name, 12))
	box.add_child(UiKit.label("This can't be undone.", 8, UiKit.DIM))
	box.add_child(UiKit.button("Delete", func() -> void:
		WorldSave.delete(info.path)
		_show_load_world()))
	box.add_child(UiKit.button("Cancel", _show_load_world))


func _unused_name() -> String:
	var n := 1
	while FileAccess.file_exists(SaveManager.world_path("World %d" % n)):
		n += 1
	return "World %d" % n
