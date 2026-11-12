extends Node
## Autoload "Registry": central lookup for all content definitions.
##
## Every subfolder of res://data is a category (items, tiles, recipes, spells...).
## Every .tres inside it (recursively) that extends GameData is registered by its id.
##
##   var pick := Registry.get_def(&"items", &"copper_pickaxe") as ItemData
##
## Content is read-only at runtime. Per-instance state (stack count, enchantments,
## durability) lives in instance objects that reference a definition by id.

signal loaded

const DATA_ROOT := "res://data"

## When true, problems are not pushed as warnings (used by tests).
var quiet := false

var _defs: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	load_all(DATA_ROOT)


## Clears everything and loads every category under `root`.
func load_all(root: String) -> void:
	_defs.clear()
	if not DirAccess.dir_exists_absolute(root):
		_report("Registry: data root %s does not exist" % root)
		loaded.emit()
		return
	for category in DirAccess.get_directories_at(root):
		load_category(StringName(category), root.path_join(category))
	loaded.emit()


## Loads every GameData resource under `path` into `category`.
func load_category(category: StringName, path: String) -> void:
	if not _defs.has(category):
		_defs[category] = {}
	for file_path in list_resource_files(path):
		var res := load(file_path)
		if res is GameData:
			register(category, res as GameData)
		else:
			_report("Registry: %s is not a GameData resource, skipped" % file_path)


## Adds one definition. Returns false (and registers nothing) on an empty or duplicate id.
func register(category: StringName, data: GameData) -> bool:
	if data.id == &"":
		_report("Registry: %s has an empty id" % data.resource_path)
		return false
	if not _defs.has(category):
		_defs[category] = {}
	var bucket: Dictionary = _defs[category]
	if bucket.has(data.id):
		_report("Registry: duplicate id '%s' in category '%s' (%s)" % [data.id, category, data.resource_path])
		return false
	bucket[data.id] = data
	return true


func get_def(category: StringName, id: StringName) -> GameData:
	var bucket: Dictionary = _defs.get(category, {})
	return bucket.get(id) as GameData


func has_def(category: StringName, id: StringName) -> bool:
	var bucket: Dictionary = _defs.get(category, {})
	return bucket.has(id)


func get_all(category: StringName) -> Array[GameData]:
	var result: Array[GameData] = []
	var bucket: Dictionary = _defs.get(category, {})
	for data: GameData in bucket.values():
		result.append(data)
	return result


func get_categories() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_defs.keys())
	return result


func count(category: StringName) -> int:
	var bucket: Dictionary = _defs.get(category, {})
	return bucket.size()


## Recursively lists .tres/.res files. Handles the ".remap" names used in exported builds.
static func list_resource_files(path: String) -> PackedStringArray:
	var files := PackedStringArray()
	if not DirAccess.dir_exists_absolute(path):
		return files
	for file_name in DirAccess.get_files_at(path):
		var clean := file_name.trim_suffix(".remap")
		if clean.ends_with(".tres") or clean.ends_with(".res"):
			files.append(path.path_join(clean))
	for sub in DirAccess.get_directories_at(path):
		files.append_array(list_resource_files(path.path_join(sub)))
	return files


func _report(message: String) -> void:
	if not quiet:
		push_warning(message)
