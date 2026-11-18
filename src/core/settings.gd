extends Node
## Autoload "Settings": player settings stored in user://settings.cfg.
##
## Read with Settings.get_value("display", "fullscreen"); write with set_value, then
## save_settings(). Unknown keys fall back to DEFAULTS, so adding a setting never
## breaks an old settings file.

const PATH := "user://settings.cfg"

const DEFAULTS := {
	"display": {
		"fullscreen": false,
		"vsync": true,
		## How big the world is drawn: screen pixels per world pixel at 1080p-ish window
		## sizes. 3 = the original view; smaller shows more of the world.
		"zoom": 3.0,
	},
	"audio": {
		"master_volume": 1.0,
		## Sound effects (Sounds autoload), 0 to 1.
		"sfx_volume": 0.8,
	},
	"debug": {
		"show_overlay": true,
	},
	## Spell control options (being tried out; see docs/items-and-mining.md, Spell controls).
	"spells": {
		## F turns your movement spell (Fly or Levitate) on and off.
		"movement_key": true,
		## Jumping again in the air turns your movement spell on.
		"double_jump": true,
		## With the spellbook out, number keys pick the book's spells.
		"book_numbers": true,
		## Hold R and tap a number: cast that book slot once, then back to what you held.
		"quick_cast": true,
		## With the spellbook out, right click casts the off-hand spell (book slot 2, or 1
		## when slot 2 is in hand). Not for mining and chopping spells (right click = back layer).
		"two_hands": false,
	},
}

## Zoom range for the settings slider.
const ZOOM_MIN := 1.5
const ZOOM_MAX := 4.0

## Emitted after set_value (section, key, value).
signal changed(section: String, key: String, value: Variant)

var _cfg := ConfigFile.new()


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	_cfg = ConfigFile.new()
	var err := _cfg.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Settings: could not read %s (error %d), using defaults" % [PATH, err])


func save_settings() -> void:
	var err := _cfg.save(PATH)
	if err != OK:
		push_warning("Settings: could not save %s (error %d)" % [PATH, err])


func get_value(section: String, key: String) -> Variant:
	var default: Variant = null
	if DEFAULTS.has(section):
		default = (DEFAULTS[section] as Dictionary).get(key)
	if not _cfg.has_section_key(section, key):
		return default
	return _cfg.get_value(section, key)


func set_value(section: String, key: String, value: Variant) -> void:
	_cfg.set_value(section, key, value)
	changed.emit(section, key, value)


## Camera zoom for the current zoom setting (the game renders at 640x360 shown at 3x,
## so zoom 3 = camera zoom 1).
func camera_zoom() -> float:
	return clampf(float(get_value("display", "zoom")), ZOOM_MIN, ZOOM_MAX) / 3.0


## Pushes current values to the engine (window mode, vsync, volume).
func apply() -> void:
	if DisplayServer.get_name() != "headless":
		var fullscreen: bool = get_value("display", "fullscreen")
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		)
		var vsync: bool = get_value("display", "vsync")
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		)
	var volume: float = get_value("audio", "master_volume")
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(volume, 0.0, 1.0)))
