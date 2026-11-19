class_name WorldSave
extends RefCounted
## Reads and writes world files (user://worlds/<name>.gpworld).
##
## Layout, in order:
##   SaveHeader (magic, format version, kind "world")
##   meta: Dictionary (WorldInfo.to_dict() plus "blocks" and "walls" id palettes)
##   chunk count: u32
##   per chunk: x u32, y u32, blocks, walls, objects (each a zstd-compressed
##              PackedInt32Array: u32 raw byte size, then the compressed bytes via
##              store_var). Format version 1 files have no objects.
##
## Only chunks changed by the player are stored; everything else is regenerated from the
## seed. Tile numbers are saved with an id palette (index -> id) and remapped on load,
## so adding or removing tile types never scrambles old worlds. A tile id that no
## longer exists loads as empty.

const META_BLOCKS := "blocks"
const META_WALLS := "walls"
const META_OBJECTS := "objects"
## Extra world state saved in meta (plants).
const META_PLANTS := "plants"
## Sticks, rocks and flint lying around (ForageLayer), same layout.
const META_FORAGE := "forage"
## Chest contents.
const META_CONTAINERS := "containers"
## Magic bags left where characters died: {"list": [ItemBag.to_dict()...]}.
const META_BAGS := "bags"
## The clock: {"time": fraction of the day, "day": n}.
const META_TIME := "time"
## Respawn points set by beds: {character name: [x, y] (the bed's anchor tile)}.
const META_SPAWNS := "spawns"
## Enemies slain in this world, by enemy id (spawn conditions read these).
const META_KILLS := "kills"


static func save(path: String, info: WorldInfo, chunks: Array[ChunkData], blocks: TileTypes, walls: TileTypes,
		extra: Dictionary = {}, objects: TileTypes = null) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	SaveHeader.write(f, SaveHeader.KIND_WORLD)
	var meta := info.to_dict()
	meta[META_BLOCKS] = _palette(blocks)
	meta[META_WALLS] = _palette(walls)
	if objects:
		meta[META_OBJECTS] = _palette(objects)
	meta.merge(extra)
	f.store_var(meta)
	f.store_32(chunks.size())
	for c in chunks:
		f.store_32(c.coord.x)
		f.store_32(c.coord.y)
		_store_array(f, c.blocks)
		_store_array(f, c.walls)
		_store_array(f, c.objects)
	f.close()
	# Write to a temp file first so a crash mid-save never destroys the old save.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path)


## Just the WorldInfo (for the world list). Null if the file is missing or unreadable.
static func read_info(path: String) -> WorldInfo:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var header := SaveHeader.read(f)
	if not header.ok or header.kind != SaveHeader.KIND_WORLD:
		return null
	var meta: Variant = f.get_var()
	if not meta is Dictionary:
		return null
	var info := WorldInfo.from_dict(meta)
	info.path = path
	return info


## The saved chunks, keyed by chunk coordinate, with tile numbers remapped to the
## current content. Empty if there's no file.
static func load_chunks(path: String, blocks: TileTypes, walls: TileTypes,
		objects: TileTypes = null) -> Dictionary[Vector2i, ChunkData]:
	var out: Dictionary[Vector2i, ChunkData] = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var header := SaveHeader.read(f)
	if not header.ok:
		push_warning("WorldSave: %s: %s" % [path, header.error])
		return out
	var meta: Dictionary = f.get_var()
	var block_map := _remap(meta.get(META_BLOCKS, []), blocks)
	var wall_map := _remap(meta.get(META_WALLS, []), walls)
	var object_map := _remap(meta.get(META_OBJECTS, []), objects) if objects else PackedInt32Array()
	var has_objects: bool = header.version >= 2
	var count := f.get_32()
	for i in count:
		var c := ChunkData.new(Vector2i(f.get_32(), f.get_32()))
		c.blocks = _apply_map(_load_array(f), block_map)
		c.walls = _apply_map(_load_array(f), wall_map)
		if has_objects:
			var objs := _load_array(f)
			c.objects = _apply_map(objs, object_map) if objects else PackedInt32Array()
			c.objects.resize(ChunkData.AREA)
		c.modified = true
		out[c.coord] = c
	return out


## One extra entry from a world file's meta (plants...); empty if missing.
static func read_extra(path: String, key: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var header := SaveHeader.read(f)
	if not header.ok or header.kind != SaveHeader.KIND_WORLD:
		return {}
	var meta: Variant = f.get_var()
	if not meta is Dictionary:
		return {}
	var v: Variant = (meta as Dictionary).get(key, {})
	return v if v is Dictionary else {}


static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _palette(types: TileTypes) -> PackedStringArray:
	var ids := PackedStringArray()
	for i in types.size():
		ids.append(String(types.id_of(i)))
	return ids


## Saved index -> current index.
static func _remap(saved_ids: Variant, types: TileTypes) -> PackedInt32Array:
	var map := PackedInt32Array()
	for id: String in saved_ids:
		var now := types.index_of(StringName(id)) if not id.is_empty() else 0
		if now < 0:
			push_warning("WorldSave: tile '%s' no longer exists, loading it as empty" % id)
			now = 0
		map.append(now)
	return map


static func _apply_map(arr: PackedInt32Array, map: PackedInt32Array) -> PackedInt32Array:
	for i in arr.size():
		var v := arr[i]
		arr[i] = map[v] if v >= 0 and v < map.size() else 0
	return arr


static func _store_array(f: FileAccess, arr: PackedInt32Array) -> void:
	var raw := arr.to_byte_array()
	f.store_32(raw.size())
	f.store_var(raw.compress(FileAccess.COMPRESSION_ZSTD))


static func _load_array(f: FileAccess) -> PackedInt32Array:
	var size := f.get_32()
	var packed: PackedByteArray = f.get_var()
	return packed.decompress(size, FileAccess.COMPRESSION_ZSTD).to_int32_array()
