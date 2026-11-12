extends Node2D
## Phase 0 boot screen: proves the project, autoloads and placeholder assets load.
## Replaced by the real main menu in Phase 12.

const ATLAS_PATH := "res://assets/tiles/placeholder_tiles.png"


func _ready() -> void:
	Game.set_state(Game.State.MAIN_MENU)

	var layer := CanvasLayer.new()
	add_child(layer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)

	box.add_child(_label("game-prototype", 24))
	box.add_child(_label("Phase 0: foundation", 12))

	if ResourceLoader.exists(ATLAS_PATH):
		var atlas := TextureRect.new()
		atlas.texture = load(ATLAS_PATH) as Texture2D
		atlas.custom_minimum_size = atlas.texture.get_size() * 2
		atlas.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		atlas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		box.add_child(atlas)
		box.add_child(_label("placeholder tile atlas (16 px tiles, shown at 2x)", 8))

	var categories := Registry.get_categories()
	box.add_child(_label("content categories loaded: %d" % categories.size(), 8))
	box.add_child(_label("F3 toggles the debug overlay", 8))

	DebugOverlay.watch("godot", Engine.get_version_info().string)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l
