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
## Called with a fresh ChunkData to fill it. Must be a pure function of the chunk's
## coordinate (no shared state written): it runs on worker threads.
var generator: Callable

var _chunks: Dictionary[Vector2i, ChunkData] = {}
var _gen_jobs: Dictionary[Vector2i, GenJob] = {}


## Generates one chunk on a worker thread. Holds everything it touches, so it never
## reads WorldData itself.
class GenJob:
	extends RefCounted
	var chunk: ChunkData
	var generator: Callable
	var task := -1
	var usec := 0

	func run() -> void:
		var t := Time.get_ticks_usec()
		generator.call(chunk)
		usec = Time.get_ticks_usec() - t


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


## Returns the chunk, generating it now if needed (waiting for its background job if one
## is running). x is wrapped; y must be in range. Gameplay queries use this; streaming
## uses request_chunk() so the main thread never generates.
func get_chunk(chunk_coord: Vector2i) -> ChunkData:
	var c := Vector2i(posmod(chunk_coord.x, chunks_x), chunk_coord.y)
	var chunk: ChunkData = _chunks.get(c)
	if chunk != null:
		return chunk
	if _gen_jobs.has(c):
		_finish_job(c)
		return _chunks[c]
	chunk = ChunkData.new(c)
	if generator.is_valid():
		var t := Time.get_ticks_usec()
		generator.call(chunk)
		PerfStats.add("chunk generate (main)", Time.get_ticks_usec() - t)
	_chunks[c] = chunk
	return chunk


## The chunk if it's already generated, else null. Never generates.
func peek_chunk(chunk_coord: Vector2i) -> ChunkData:
	return _chunks.get(Vector2i(posmod(chunk_coord.x, chunks_x), chunk_coord.y))


## True if the chunk is ready. Otherwise starts generating it on a worker thread (once)
## and returns false; call collect_generated() each frame to pick results up.
func request_chunk(chunk_coord: Vector2i) -> bool:
	var c := Vector2i(posmod(chunk_coord.x, chunks_x), chunk_coord.y)
	if _chunks.has(c):
		return true
	if not _gen_jobs.has(c) and in_bounds_y(c.y * CHUNK):
		var job := GenJob.new()
		job.chunk = ChunkData.new(c)
		job.generator = generator
		job.task = WorkerThreadPool.add_task(job.run, false, "generate chunk")
		_gen_jobs[c] = job
	return false


## Main thread: stores chunks whose background generation finished. Returns how many.
func collect_generated() -> int:
	var done: Array[Vector2i] = []
	for c: Vector2i in _gen_jobs:
		if WorkerThreadPool.is_task_completed(_gen_jobs[c].task):
			done.append(c)
	for c in done:
		_finish_job(c)
	return done.size()


func pending_generation_count() -> int:
	return _gen_jobs.size()


## Blocks until every background job is done (on world unload).
func wait_all() -> void:
	for c: Vector2i in _gen_jobs.keys():
		_finish_job(c)


func _finish_job(c: Vector2i) -> void:
	var job: GenJob = _gen_jobs[c]
	_gen_jobs.erase(c)
	WorkerThreadPool.wait_for_task_completion(job.task)
	if not _chunks.has(c):
		_chunks[c] = job.chunk
	PerfStats.add("chunk generate (worker)", job.usec)


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
	chunk.revision += 1
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
	chunk.revision += 1
	return true
