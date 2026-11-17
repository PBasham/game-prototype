class_name CharacterData
extends RefCounted
## A character, saved separately from worlds: user://characters/<name>.gpchar.
## Phase 4 keeps this minimal (name and inventory). Until character select exists
## (Phase 7) there is one automatic character, "default", made with the starting kit.
##
## File: SaveHeader (kind "character"), then one store_var Dictionary.

const DEFAULT_NAME := "default"

## [item id, count] given to a new character. Hotbar order.
const STARTING_KIT: Array = [
	[&"copper_pickaxe", 1], [&"copper_axe", 1], [&"mining_spell", 1], [&"wood_planks", 50],
	[&"wood_platform", 30], [&"wood_wall", 50], [&"rope", 30], [&"tree_seed", 5],
	[&"grass_seeds", 10], [&"dirt", 20],
]

var name := DEFAULT_NAME
var inventory := Inventory.new()
## Not saved (dev runs and tests use a throwaway character).
var temporary := false


static func create(char_name: String) -> CharacterData:
	var c := CharacterData.new()
	c.name = char_name
	for e: Array in STARTING_KIT:
		c.inventory.add(e[0], e[1])
	return c


## Loads the character, or makes a new one with the starting kit if there's no save.
static func load_or_create(char_name: String) -> CharacterData:
	var loaded := load_file(SaveManager.character_path(char_name))
	if loaded:
		return loaded
	var c := create(char_name)
	c.save()
	return c


static func load_file(path: String) -> CharacterData:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var header := SaveHeader.read(f)
	if not header.ok or header.kind != SaveHeader.KIND_CHARACTER:
		push_warning("CharacterData: can't read %s (%s)" % [path, header.error])
		return null
	var d: Variant = f.get_var()
	if not d is Dictionary:
		return null
	var c := CharacterData.new()
	c.name = String((d as Dictionary).get("name", DEFAULT_NAME))
	c.inventory.from_dict((d as Dictionary).get("inventory", {}))
	return c


func save() -> Error:
	if temporary:
		return OK
	var path := SaveManager.character_path(name)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	SaveHeader.write(f, SaveHeader.KIND_CHARACTER)
	f.store_var({"name": name, "inventory": inventory.to_dict()})
	f.close()
	return DirAccess.rename_absolute(tmp, path)
