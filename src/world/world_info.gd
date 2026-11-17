class_name WorldInfo
extends RefCounted
## What a world is (name, generator kind, seed, size) and where it's saved. The menu
## builds one, Game.start_world() hands it to the World scene, WorldSave stores it at the
## top of the world file.

var name := "World"
## Generator kind (WorldGenerator.KINDS): &"forest" for real worlds, &"course" for the
## dev test course.
var kind: StringName = &"forest"
var seed := 0
var size: WorldData.Size = WorldData.Size.SMALL
## Not saved when true (the test course, DevCli runs).
var temporary := false
var created_unix := 0
var last_played_unix := 0
## Save file (user://worlds/<name>.gpworld); empty for temporary worlds.
var path := ""


static func create(world_name: String, world_size: WorldData.Size, world_seed: int) -> WorldInfo:
	var info := WorldInfo.new()
	info.name = world_name
	info.size = world_size
	info.seed = world_seed
	info.created_unix = int(Time.get_unix_time_from_system())
	return info


## The dev-only movement test course. Fixed seed, never saved.
static func test_course() -> WorldInfo:
	var info := WorldInfo.create("Test Course", WorldData.Size.SMALL, 1337)
	info.kind = &"course"
	info.temporary = true
	return info


## A seed from text: numbers are used as is, anything else is hashed, empty is random.
static func seed_from_text(text: String) -> int:
	text = text.strip_edges()
	if text.is_empty():
		return randi() & 0x7fffffff
	if text.is_valid_int():
		return absi(text.to_int()) & 0x7fffffff
	return text.hash() & 0x7fffffff


func dimensions() -> Vector2i:
	return WorldData.SIZES[size]


func size_name() -> String:
	return String(WorldData.Size.keys()[size]).capitalize()


func to_dict() -> Dictionary:
	return {
		"name": name, "kind": String(kind), "seed": seed,
		"size": String(WorldData.Size.keys()[size]),
		"created": created_unix, "last_played": last_played_unix,
	}


static func from_dict(d: Dictionary) -> WorldInfo:
	var info := WorldInfo.new()
	info.name = str(d.get("name", "World"))
	info.kind = StringName(str(d.get("kind", "forest")))
	info.seed = int(d.get("seed", 0))
	info.size = WorldData.Size.get(str(d.get("size", "SMALL")), WorldData.Size.SMALL)
	info.created_unix = int(d.get("created", 0))
	info.last_played_unix = int(d.get("last_played", 0))
	return info
