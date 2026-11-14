class_name WorldData
extends RefCounted
## All tiles of a world, stored in chunks. Wraps horizontally: x = -1 is the last column.
##
## Chunks are created on first access by calling `generator` (a Callable taking a
## ChunkData). y < 0 is open sky; y >= height is out of bounds (treated as solid).

const CHUNK := ChunkData.SIZE
const AIR := 0
const OUT_OF_BOUNDS := -1

enum Size { TINY, SMALL, MEDIUM, LARGE }

## Width x height in tiles (8 px). Multiples of the chunk size. Scaled from Terraria's
## presets so a world feels as big relative to the player (the Scholar is ~8 tiles tall).
const SIZES := {
	Size.TINY: Vector2i(1024, 512),
	Size.SMALL: Vector2i(6400, 2048),
	Size.MEDIUM: Vector2i(9600, 2816),
	Size.LARGE: Vector2i(12800, 3584),
}

var width: int
var height: int
var chunks_x: int
var chunks_y: int
var generator: Callable

var _chunks: Dictionary[Vector2i, ChunkData] = {}


func _init(width_tiles: int, height_tiles: int) -> void:
	assert(width_tiles % CHUNK == 0 and height_tiles % CHUNK == 0, "world size must be a multiple of %d" % CHUNK)
	width = width_tiles
	height = height_tiles
	chunks_x = width / CHUNK
	chunks_y = height / CHUNK


func wrap_x(x: int) -> int:
	return posmod(x, width)


func in_bounds_y(y: int) -> bool:
	return y >= 0 and y < height


## Returns the chunk, generating it if needed. x is wrapped; y must be in range.
func get_chunk(chunk_coord: Vector2i) -> ChunkData:
	var c := Vector2i(posmod(chunk_coord.x, chunks_x), chunk_coord.y)
	var chunk: ChunkData = _chunks.get(c)
	if chunk == null:
		chunk = ChunkData.new(c)
		if generator.is_valid():
			generator.call(chunk)
		_chunks[c] = chunk
	return chunk


func has_chunk(chunk_coord: Vector2i) -> bool:
	return _chunks.has(Vector2i(posmod(chunk_coord.x, chunks_x), chunk_coord.y))


func generated_chunk_count() -> int:
	return _chunks.size()


func get_block(x: int, y: int) -> int:
	if y < 0:
		return AIR
	if y >= height:
		return OUT_OF_BOUNDS
	var wx := wrap_x(x)
	return get_chunk(Vector2i(wx / CHUNK, y / CHUNK)).blocks[ChunkData.local_index(wx % CHUNK, y % CHUNK)]


func set_block(x: int, y: int, id: int) -> bool:
	if not in_bounds_y(y):
		return false
	var wx := wrap_x(x)
	var chunk := get_chunk(Vector2i(wx / CHUNK, y / CHUNK))
	chunk.blocks[ChunkData.local_index(wx % CHUNK, y % CHUNK)] = id
	chunk.modified = true
	return true


func get_wall(x: int, y: int) -> int:
	if not in_bounds_y(y):
		return AIR
	var wx := wrap_x(x)
	return get_chunk(Vector2i(wx / CHUNK, y / CHUNK)).walls[ChunkData.local_index(wx % CHUNK, y % CHUNK)]


func set_wall(x: int, y: int, id: int) -> bool:
	if not in_bounds_y(y):
		return false
	var wx := wrap_x(x)
	var chunk := get_chunk(Vector2i(wx / CHUNK, y / CHUNK))
	chunk.walls[ChunkData.local_index(wx % CHUNK, y % CHUNK)] = id
	chunk.modified = true
	return true
