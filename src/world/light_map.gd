class_name LightMap
extends Sprite2D
## Tile-level lighting over the loaded area, drawn as a smooth multiply overlay.
##
## Open sky (no block, no background wall) is fully lit. Light fades by `open_falloff`
## per tile through air and walls and by `solid_falloff` per tile through blocks, so
## sunlight soaks a few blocks into the ground and caves get dark. `ambient` keeps the
## darkest areas faintly visible. Recomputed (on a worker thread, see LightJob) when
## chunks load or a block changes.
## (Torches and other light sources come later.)

@export var ambient := 0.16
@export var open_falloff := 0.06
@export var solid_falloff := 0.1
## Minimum seconds between recomputes.
@export var min_interval := 0.12

var world: World
var _dirty := true
var _cooldown := 0.0
var _job: LightJob
var _texture: ImageTexture


func _ready() -> void:
	# Snaps to the loaded area when it changes; never slides between physics ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	centered = false
	scale = Vector2(World.TILE, World.TILE)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 50
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = mat


func mark_dirty() -> void:
	_dirty = true


func _process(delta: float) -> void:
	_cooldown -= delta
	if _job != null and WorkerThreadPool.is_task_completed(_job.task):
		WorkerThreadPool.wait_for_task_completion(_job.task)
		PerfStats.add("light rebuild (worker)", _job.usec)
		_apply(_job)
		_job = null
	if _dirty and _job == null and _cooldown <= 0.0:
		rebuild()


## Starts a recompute on a worker thread; the result shows a few frames later.
func rebuild() -> void:
	var job := _make_job()
	if job == null:
		return
	job.task = WorkerThreadPool.add_task(job.run, false, "light map")
	_job = job


## Recomputes on this thread and shows it immediately (used at spawn).
func rebuild_now() -> void:
	wait()
	var job := _make_job()
	if job == null:
		return
	job.run()
	PerfStats.add("light rebuild (main)", job.usec)
	_apply(job)


## Blocks until a running recompute is done (on world unload).
func wait() -> void:
	if _job != null:
		WorkerThreadPool.wait_for_task_completion(_job.task)
		_job = null


## Captures the loaded area's tile arrays (main thread, cheap: no per-tile work).
func _make_job() -> LightJob:
	_dirty = false
	_cooldown = min_interval
	var rect := world.renderer.loaded_tile_rect()
	if rect.size.x <= 0:
		return null
	var job := LightJob.new()
	job.rect = rect
	job.ambient = ambient
	job.open_falloff = open_falloff
	job.solid_falloff = solid_falloff
	var table := world.blocks.collision_table()
	job.solid.resize(table.size())
	for i in table.size():
		job.solid[i] = 1 if table[i] == TileDef.Collision.SOLID else 0
	var first := rect.position / ChunkData.SIZE
	var count := rect.size / ChunkData.SIZE
	for cy in count.y:
		for cx in count.x:
			var chunk := world.data.peek_chunk(first + Vector2i(cx, cy))
			job.blocks.append(chunk.blocks if chunk else PackedInt32Array())
			job.walls.append(chunk.walls if chunk else PackedInt32Array())
	return job


## Main thread: uploads the result and moves the overlay onto its rectangle.
func _apply(job: LightJob) -> void:
	var t := Time.get_ticks_usec()
	var w := job.rect.size.x
	var h := job.rect.size.y
	var image := Image.create_from_data(w, h, false, Image.FORMAT_L8, job.bytes)
	if _texture == null or _texture.get_size() != Vector2(w, h):
		_texture = ImageTexture.create_from_image(image)
		texture = _texture
	else:
		_texture.update(image)
	position = Vector2(job.rect.position * World.TILE)
	PerfStats.add("light apply (main)", Time.get_ticks_usec() - t)
