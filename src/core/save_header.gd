class_name SaveHeader
extends RefCounted
## The header every save file starts with: magic bytes, format version, file kind.
##
## The version lets us migrate old saves when the format changes instead of
## breaking them. Bump FORMAT_VERSION and add a migration step in SaveManager
## whenever the layout of a save changes.

const MAGIC := "GPSV"
const FORMAT_VERSION := 1

const KIND_CHARACTER := "character"
const KIND_WORLD := "world"


static func write(file: FileAccess, kind: String, version: int = FORMAT_VERSION) -> void:
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_32(version)
	file.store_pascal_string(kind)


## Returns {ok: bool, version: int, kind: String, error: String}.
static func read(file: FileAccess) -> Dictionary:
	var result := {"ok": false, "version": 0, "kind": "", "error": ""}
	if file.get_length() - file.get_position() < MAGIC.length() + 4:
		result.error = "file too short"
		return result
	var magic := file.get_buffer(MAGIC.length()).get_string_from_ascii()
	if magic != MAGIC:
		result.error = "not a save file (bad magic)"
		return result
	result.version = file.get_32()
	if result.version > FORMAT_VERSION:
		result.error = "save is from a newer version (%d > %d)" % [result.version, FORMAT_VERSION]
		return result
	result.kind = file.get_pascal_string()
	result.ok = true
	return result
