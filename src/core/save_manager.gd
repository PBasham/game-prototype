extends Node
## Autoload "SaveManager": where saves live and how they're versioned.
##
## Characters and worlds are saved separately (one character can visit many worlds).
## Phase 0 only sets up folders; actual save/load lands in Phase 5. Every save file
## starts with a SaveHeader so old saves can be migrated when the format changes.

const CHARACTER_DIR := "user://characters"
const WORLD_DIR := "user://worlds"
const CHARACTER_EXT := ".gpchar"
const WORLD_EXT := ".gpworld"


func _ready() -> void:
	for dir in [CHARACTER_DIR, WORLD_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)


func character_path(slot_name: String) -> String:
	return CHARACTER_DIR.path_join(slot_name.validate_filename() + CHARACTER_EXT)


func world_path(world_name: String) -> String:
	return WORLD_DIR.path_join(world_name.validate_filename() + WORLD_EXT)


func list_characters() -> PackedStringArray:
	return _list(CHARACTER_DIR, CHARACTER_EXT)


func list_worlds() -> PackedStringArray:
	return _list(WORLD_DIR, WORLD_EXT)


func _list(dir: String, ext: String) -> PackedStringArray:
	var names := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return names
	for file_name in DirAccess.get_files_at(dir):
		if file_name.ends_with(ext):
			names.append(file_name.trim_suffix(ext))
	return names
