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
	},
	"audio": {
		"master_volume": 1.0,
	},
	"debug": {
		"show_overlay": true,
	},
}

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
