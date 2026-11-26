class_name PauseMenu
extends CanvasLayer
## Esc in game: pauses and offers Resume and Save & Quit (Quit for temporary worlds).
## Also shows short toasts for EventBus.debug_message ("World saved").

var world: World
var _root: Control
var _toast: Label
var _toast_left := 0.0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_show_main()

	_toast = UiKit.label("", 10)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 8
	_toast.visible = false
	add_child(_toast)
	EventBus.debug_message.connect(show_toast)


func _page() -> VBoxContainer:
	for c in _root.get_children():
		if c is CenterContainer:
			c.queue_free()
	return UiKit.panel(_root, 170)


func _show_main() -> VBoxContainer:
	var box := _page()
	box.add_child(UiKit.label("Paused", 14))
	box.add_child(UiKit.label(world.info.name, 8, UiKit.DIM))
	box.add_child(UiKit.button("Resume", toggle))
	if world.is_saved():
		box.add_child(UiKit.button("Save", func() -> void: world.save()))
	box.add_child(UiKit.button("Settings", _show_settings))
	box.add_child(UiKit.button("Save & Quit to Menu" if world.is_saved() else "Quit to Menu", Game.quit_to_menu))
	box.add_child(UiKit.button("Quit Game", _show_quit))
	return box


## Quit Game asks first: save and quit, quit without saving, or go back.
func _show_quit() -> void:
	var box := _page()
	box.add_child(UiKit.label("Quit Game?", 14))
	if world.is_saved():
		box.add_child(UiKit.label("Quit without saving?", 8, UiKit.DIM))
		box.add_child(UiKit.button("Save & Quit", quit_game.bind(true)))
		box.add_child(UiKit.button("Quit without saving", quit_game.bind(false)))
	else:
		box.add_child(UiKit.label("This world isn't saved.", 8, UiKit.DIM))
		box.add_child(UiKit.button("Quit", quit_game.bind(false)))
	var back := UiKit.button("Cancel", _show_main)
	box.add_child(back)
	back.grab_focus.call_deferred()


func quit_game(save_first: bool) -> void:
	if save_first:
		world.save()
	world.skip_save = true  # saved just now, or not wanted
	get_tree().quit()


func _show_settings() -> void:
	var box := _page()
	box.add_child(UiKit.label("Settings", 14))
	var value := UiKit.label("", 10)
	var slider := HSlider.new()
	slider.min_value = Settings.ZOOM_MIN
	slider.max_value = Settings.ZOOM_MAX
	slider.step = 0.25
	slider.custom_minimum_size = Vector2(140, 16)
	slider.value = float(Settings.get_value("display", "zoom"))
	var show_value := func(v: float) -> void: value.text = "Zoom: %.2fx%s" % [v, "  (default)" if is_equal_approx(v, 3.0) else ""]
	show_value.call(slider.value)
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_value("display", "zoom", v)
		show_value.call(v))
	box.add_child(value)
	box.add_child(slider)
	box.add_child(UiKit.label("Lower shows more of the world.", 8, UiKit.DIM))
	box.add_child(UiKit.button("Back", func() -> void:
		Settings.save_settings()
		_show_main()))


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.5, 0.0, 1.0)
		_toast.visible = _toast_left > 0.0


func _unhandled_input(event: InputEvent) -> void:
	# While paused the world doesn't get input, so Esc to resume is handled here.
	if _root.visible and event.is_action_pressed(&"ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_root.visible = not _root.visible
	get_tree().paused = _root.visible
	Game.set_state(Game.State.PAUSED if _root.visible else Game.State.PLAYING)
	if _root.visible:
		var box := _show_main()
		(box.find_children("*", "Button", true, false)[0] as Button).grab_focus.call_deferred()


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_left = 2.0
	_toast.visible = true
