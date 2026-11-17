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
	var box := UiKit.panel(_root, 150)
	box.add_child(UiKit.label("Paused", 14))
	box.add_child(UiKit.label(world.info.name, 8, UiKit.DIM))
	box.add_child(UiKit.button("Resume", toggle))
	if world.is_saved():
		box.add_child(UiKit.button("Save", func() -> void: world.save()))
	box.add_child(UiKit.button("Save & Quit to Menu" if world.is_saved() else "Quit to Menu", Game.quit_to_menu))
	box.add_child(UiKit.button("Quit Game", func() -> void: get_tree().quit()))

	_toast = UiKit.label("", 10)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 8
	_toast.visible = false
	add_child(_toast)
	EventBus.debug_message.connect(show_toast)


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
		(_root.find_children("*", "Button", true, false)[0] as Button).grab_focus()


func show_toast(text: String) -> void:
	_toast.text = text
	_toast_left = 2.0
	_toast.visible = true
