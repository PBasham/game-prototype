extends CanvasLayer
## Autoload "DebugOverlay": top-left stats panel, debug builds only. F3 toggles it.
##
## Any system can show a live value:
##   DebugOverlay.watch("seed", world.seed)
##   DebugOverlay.watch("chunks loaded", chunk_count)
## and remove it with DebugOverlay.unwatch("seed").

const REFRESH_SECONDS := 0.2

var _label: Label
var _watches: Dictionary[String, Variant] = {}
var _since_refresh := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := PanelContainer.new()
	panel.position = Vector2(4, 4)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)

	var wanted: bool = Settings.get_value("debug", "show_overlay")
	visible = OS.is_debug_build() and wanted


func watch(key: String, value: Variant) -> void:
	_watches[key] = value


func get_watch(key: String) -> Variant:
	return _watches.get(key)


func unwatch(key: String) -> void:
	_watches.erase(key)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug") and OS.is_debug_build():
		visible = not visible
		Settings.set_value("debug", "show_overlay", visible)
		Settings.save_settings()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_since_refresh += delta
	if _since_refresh < REFRESH_SECONDS:
		return
	_since_refresh = 0.0
	_label.text = _build_text()


func _build_text() -> String:
	var lines := PackedStringArray()
	lines.append("FPS %d  (%.1f ms)" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	lines.append("draw calls %d  nodes %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	])
	lines.append("mem %.1f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	lines.append("state %s%s" % [Game.state_name(), "  (net)" if Game.is_networked() else ""])
	for key in _watches:
		lines.append("%s: %s" % [key, str(_watches[key])])
	return "\n".join(lines)
