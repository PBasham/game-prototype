class_name ChunkRenderer
extends Node2D
## Draws loaded chunks. Each chunk is:
## - a terrain sprite drawn by terrain.gdshader (smooth edges, blending, grass, walls),
## - a hidden TileMapLayer that only provides collision,
## - a visible TileMapLayer for thin tiles (platforms, ropes),
## - decorations (trees, flowers) on grassy surfaces.
## Only chunks near the camera exist, so cost stays flat however big the world is.
##
## Chunk coordinates here are UNWRAPPED: they keep counting past the world's edges.
## The data behind them wraps, so the seam is invisible.

## Emitted when the set of loaded chunks changes (lighting listens).
signal chunks_changed

const TILE := 8
const BORDER := 2
const TEX_SIZE := ChunkData.SIZE + BORDER * 2
const PIECES := 64
const MATERIAL_TEX := 64
const BLOCKS_ATLAS := "res://assets/tiles/blocks.png"
const TERRAIN_DIR := "res://assets/terrain"
const SHADER := preload("res://src/world/terrain.gdshader")
const NEIGHBORS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # mask bits 1, 2, 4, 8
## Grass palette from Patrick's reference art (darkest to lightest).
const GRASS_COLORS := ["1f5212", "2b7018", "349a20", "42a628", "4fb52f", "5cbf3a"]

class ChunkView:
	var node: Node2D
	var terrain: Sprite2D
	var tile_image: Image
	var tile_texture: ImageTexture
	var collision: TileMapLayer
	var props: TileMapLayer
	var decor: Node2D
	var dirty := false

## Chunks loaded around the camera, in each direction.
var load_radius := Vector2i(2, 2)
## Max finished chunks turned into nodes per frame (spreads the main-thread cost).
var chunks_per_frame := 1

var _world: World
var _data: WorldData
var _views: Dictionary[Vector2i, ChunkView] = {}
## Chunks being built on worker threads, and built ones waiting to be applied.
var _building: Dictionary[Vector2i, ChunkBuildJob] = {}
var _built: Dictionary[Vector2i, ChunkBuildJob] = {}
var _chunk_px := float(ChunkData.SIZE * TILE)
var _collision_table := PackedInt32Array()
var _atlas_rows := PackedInt32Array()
var _grass_id := -1
var _block_slot := PackedInt32Array()
var _wall_slot := PackedInt32Array()
var _stone_slot := 0
var _material: ShaderMaterial
var _collision_set: TileSet
var _props_set: TileSet
var _trees: Array[Texture2D] = []
var _flowers: Array[Texture2D] = []


func setup(world: World) -> void:
	_world = world
	_data = world.data
	# Chunks are placed, never moved: no physics interpolation for them.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_collision_table = world.blocks.collision_table()
	_atlas_rows = world.blocks.atlas_row_table()
	_grass_id = world.blocks.index_of(&"grass")
	_build_terrain_material()
	_collision_set = _build_tileset(true)
	_props_set = _build_tileset(false)
	for kind in ["green", "olive", "teal", "gold"]:
		for i in 3:
			_trees.append(load("res://assets/trees/pine_%s_%d.png" % [kind, i]) as Texture2D)
	for i in 5:
		_flowers.append(load("res://assets/decor/flower_%d.png" % i) as Texture2D)


func loaded_count() -> int:
	return _views.size()


## Tile rectangle (unwrapped coords) covered by loaded chunks.
func loaded_tile_rect() -> Rect2i:
	if _views.is_empty():
		return Rect2i()
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for c: Vector2i in _views:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Rect2i(lo * ChunkData.SIZE, (hi - lo + Vector2i.ONE) * ChunkData.SIZE)


## Streams chunks around `center` (world pixels). Each frame: pick up generated data and
## finished builds, start builds for chunks whose 3x3 data is ready (on worker threads),
## and turn at most `chunks_per_frame` finished builds into nodes. The chunk under the
## camera and its direct neighbors are built immediately if missing (after a teleport),
## so the player never stands on missing collision.
func update(center: Vector2) -> void:
	_data.collect_generated()
	var cc := _chunk_at(center)
	var changed := false
	for c: Vector2i in _views.keys():
		if not _in_range(c, cc, 1):
			_unload(c)
			changed = true
	_collect_builds(cc)

	var wanted: Array[Vector2i] = []
	for dy in range(-load_radius.y, load_radius.y + 1):
		for dx in range(-load_radius.x, load_radius.x + 1):
			var c := cc + Vector2i(dx, dy)
			if c.y >= 0 and c.y < _data.chunks_y and not _views.has(c):
				wanted.append(c)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - cc).length_squared() < (b - cc).length_squared())
	for c in wanted:
		if absi(c.x - cc.x) <= 1 and absi(c.y - cc.y) <= 1 and not _built.has(c):
			_build_now(c)
			changed = true
		elif not _building.has(c) and not _built.has(c) and _neighborhood_ready(c):
			_start_build(c)

	var applied := 0
	for c in wanted:
		if applied >= chunks_per_frame:
			break
		if _built.has(c):
			_apply(_built[c])
			_built.erase(c)
			applied += 1
			changed = true
	for view: ChunkView in _views.values():
		if view.dirty:
			view.tile_texture.update(view.tile_image)
			view.dirty = false
	if changed:
		chunks_changed.emit()


## Loads everything around `center` right now, on this thread (used at spawn).
func load_all_now(center: Vector2) -> void:
	var cc := _chunk_at(center)
	for dy in range(-load_radius.y, load_radius.y + 1):
		for dx in range(-load_radius.x, load_radius.x + 1):
			var c := cc + Vector2i(dx, dy)
			if c.y >= 0 and c.y < _data.chunks_y and not _views.has(c):
				_build_now(c)
	chunks_changed.emit()


func clear() -> void:
	for c: Vector2i in _views.keys():
		_unload(c)
	wait_all()
	_built.clear()


## Blocks until no build is running (on world unload).
func wait_all() -> void:
	for job: ChunkBuildJob in _building.values():
		WorkerThreadPool.wait_for_task_completion(job.task)
	_building.clear()


func pending_count() -> int:
	return _building.size() + _built.size()


## Redraws a tile everywhere it appears (including neighbors' borders).
func refresh_tile(tile: Vector2i) -> void:
	if not _data.in_bounds_y(tile.y):
		return
	var wx := _data.wrap_x(tile.x)
	for c: Vector2i in _views:
		var view: ChunkView = _views[c]
		var lx := posmod(wx - c.x * ChunkData.SIZE + BORDER, _data.width) - BORDER
		var ly := tile.y - c.y * ChunkData.SIZE
		if lx < -BORDER or lx >= ChunkData.SIZE + BORDER or ly < -BORDER or ly >= ChunkData.SIZE + BORDER:
			continue
		var world_tile := c * ChunkData.SIZE + Vector2i(lx, ly)
		view.tile_image.set_pixel(lx + BORDER, ly + BORDER, _tile_color(world_tile))
		view.dirty = true
		if lx >= 0 and lx < ChunkData.SIZE and ly >= 0 and ly < ChunkData.SIZE:
			_paint_cells(view, Vector2i(lx, ly), world_tile)
		for d: Vector2i in NEIGHBORS:
			var n := Vector2i(lx, ly) + d
			if n.x >= 0 and n.x < ChunkData.SIZE and n.y >= 0 and n.y < ChunkData.SIZE:
				_paint_cells(view, n, c * ChunkData.SIZE + n)


func _chunk_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _chunk_px), floori(p.y / _chunk_px))


func _in_range(c: Vector2i, cc: Vector2i, slack: int) -> bool:
	return absi(c.x - cc.x) <= load_radius.x + slack and absi(c.y - cc.y) <= load_radius.y + slack


## Moves finished worker builds to `_built` (or drops them if no longer wanted or stale).
func _collect_builds(cc: Vector2i) -> void:
	var done: Array[Vector2i] = []
	for c: Vector2i in _building:
		if WorkerThreadPool.is_task_completed(_building[c].task):
			done.append(c)
	for c in done:
		var job: ChunkBuildJob = _building[c]
		_building.erase(c)
		WorkerThreadPool.wait_for_task_completion(job.task)
		PerfStats.add("chunk build (worker)", job.usec)
		if _in_range(c, cc, 0) and not _views.has(c) and not job.is_stale():
			_built[c] = job
	for c: Vector2i in _built.keys():
		if not _in_range(c, cc, 1) or _built[c].is_stale():
			_built.erase(c)


## True when the chunk and its 8 neighbors have data; requests any that don't.
func _neighborhood_ready(c: Vector2i) -> bool:
	var ready := true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if n.y >= 0 and n.y < _data.chunks_y and not _data.request_chunk(n):
				ready = false
	return ready


## Captures the 3x3 neighborhood's tile arrays. With `generate`, missing chunks are
## generated now (main thread); otherwise they must already exist.
func _make_job(c: Vector2i, generate: bool) -> ChunkBuildJob:
	var job := ChunkBuildJob.new()
	job.coord = c
	job.world_width = _data.width
	job.world_height = _data.height
	job.block_slot = _block_slot
	job.wall_slot = _wall_slot
	job.stone_slot = _stone_slot
	job.collision = _collision_table
	job.atlas_row = _atlas_rows
	job.grass_id = _grass_id
	job.generator = _world.generator
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			var chunk: ChunkData = null
			if n.y >= 0 and n.y < _data.chunks_y:
				chunk = _data.get_chunk(n) if generate else _data.peek_chunk(n)
			job.chunks.append(chunk)
			job.revisions.append(chunk.revision if chunk else 0)
			job.blocks.append(chunk.blocks if chunk else PackedInt32Array())
			job.walls.append(chunk.walls if chunk else PackedInt32Array())
	return job


func _start_build(c: Vector2i) -> void:
	var job := _make_job(c, false)
	job.task = WorkerThreadPool.add_task(job.run, false, "build chunk")
	_building[c] = job


## Builds and applies a chunk right now on this thread (spawn, or after a teleport).
func _build_now(c: Vector2i) -> void:
	var job: ChunkBuildJob = _built.get(c)
	_built.erase(c)
	if job == null and _building.has(c):
		job = _building[c]
		_building.erase(c)
		WorkerThreadPool.wait_for_task_completion(job.task)
	if job == null or job.is_stale():
		job = _make_job(c, true)
		job.run()
		PerfStats.add("chunk build (main)", job.usec)
	_apply(job)


## Main thread: turns a finished build into the chunk's nodes.
func _apply(job: ChunkBuildJob) -> void:
	var t := Time.get_ticks_usec()
	var c := job.coord
	var view := ChunkView.new()
	view.node = Node2D.new()
	view.node.name = "Chunk_%d_%d" % [c.x, c.y]
	view.node.position = Vector2(c) * _chunk_px

	view.tile_image = Image.create_from_data(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8, job.tile_bytes)
	var origin := c * ChunkData.SIZE
	view.tile_texture = ImageTexture.create_from_image(view.tile_image)

	view.terrain = Sprite2D.new()
	view.terrain.texture = view.tile_texture
	view.terrain.centered = false
	view.terrain.region_enabled = true
	view.terrain.region_rect = Rect2(BORDER, BORDER, ChunkData.SIZE, ChunkData.SIZE)
	view.terrain.scale = Vector2(TILE, TILE)
	var mat := _material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("tiles", view.tile_texture)
	mat.set_shader_parameter("origin", Vector2(origin * TILE))
	view.terrain.material = mat

	view.collision = TileMapLayer.new()
	view.collision.tile_set = _collision_set
	view.collision.visible = false
	view.props = TileMapLayer.new()
	view.props.tile_set = _props_set
	view.props.collision_enabled = false
	view.decor = Node2D.new()
	view.decor.z_index = -1

	view.node.add_child(view.decor)
	view.node.add_child(view.terrain)
	view.node.add_child(view.props)
	view.node.add_child(view.collision)
	var cells := job.collision_cells
	for i in range(0, cells.size(), 3):
		view.collision.set_cell(Vector2i(cells[i], cells[i + 1]), 0, Vector2i(0, cells[i + 2]))
	var props := job.prop_cells
	for i in range(0, props.size(), 4):
		view.props.set_cell(Vector2i(props[i], props[i + 1]), 0, Vector2i(props[i + 2], props[i + 3]))
	_add_decor(view, job.decor)
	add_child(view.node)
	_views[c] = view
	PerfStats.add("chunk apply (main)", Time.get_ticks_usec() - t)


func _unload(c: Vector2i) -> void:
	var view: ChunkView = _views[c]
	view.node.queue_free()
	_views.erase(c)


## R = block terrain slot, G = wall slot. Below the world counts as stone.
func _tile_color(tile: Vector2i) -> Color:
	var b := _data.get_block(tile.x, tile.y)
	var slot := _stone_slot if b == WorldData.OUT_OF_BOUNDS else (_block_slot[b] if b > 0 else 0)
	var w := _data.get_wall(tile.x, tile.y)
	var wslot := _wall_slot[w] if w > 0 else 0
	return Color(slot / 255.0, wslot / 255.0, 0.0, 1.0)


## Collision cell and, for platforms and ropes, the visible tile.
func _paint_cells(view: ChunkView, local: Vector2i, tile: Vector2i) -> void:
	var id := _data.get_block(tile.x, tile.y)
	var collision := _world.blocks.collision(id) if id > 0 else TileDef.Collision.NONE
	if collision == TileDef.Collision.NONE:
		view.collision.erase_cell(local)
	else:
		view.collision.set_cell(local, 0, Vector2i(0, _world.blocks.atlas_row(id)))
	if id <= 0 or _block_slot[id] > 0:
		view.props.erase_cell(local)
		return
	var mask := 0
	for i in 4:
		var n: Vector2i = tile + NEIGHBORS[i]
		if _data.get_block(n.x, n.y) == id:
			mask |= 1 << i
	var piece := posmod(_data.wrap_x(tile.x), 8) + posmod(tile.y, 8) * 8
	view.props.set_cell(local, 0, Vector2i(mask * PIECES + piece, _world.blocks.atlas_row(id)))


## Trees and flowers on grassy surfaces, at the spots ChunkBuildJob found from the
## world generator's decoration rules. `spots` is flat quads: x, y, tree, flower.
func _add_decor(view: ChunkView, spots: PackedInt32Array) -> void:
	for i in range(0, spots.size(), 4):
		var lx := spots[i]
		var ly := spots[i + 1]
		var tree := spots[i + 2]
		var flower := spots[i + 3]
		var tex: Texture2D = _trees[tree % _trees.size()] if tree >= 0 else _flowers[flower % _flowers.size()]
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = Vector2(lx * TILE + TILE / 2 - tex.get_width() / 2, ly * TILE + (3 if tree >= 0 else 1) - tex.get_height())
		view.decor.add_child(s)


func _build_terrain_material() -> void:
	var blocks := _world.blocks
	var walls := _world.walls
	var keys: Array[String] = []
	var overlays: Array[String] = []
	var grass := PackedFloat32Array()
	grass.resize(16)
	var built := PackedFloat32Array()
	built.resize(16)
	var built_walls := PackedFloat32Array()
	built_walls.resize(16)
	_block_slot.resize(blocks.size())
	for i in range(1, blocks.size()):
		var def := blocks.def(i)
		if def.terrain.is_empty() or def.collision != TileDef.Collision.SOLID:
			continue
		keys.append(def.terrain)
		overlays.append(def.ore_overlay)
		_block_slot[i] = keys.size()
		grass[keys.size()] = 1.0 if def.grass_cover else 0.0
		built[keys.size()] = 1.0 if def.built else 0.0
		if def.id == &"stone":
			_stone_slot = keys.size()
	var wall_keys: Array[String] = []
	_wall_slot.resize(walls.size())
	for i in range(1, walls.size()):
		var def := walls.def(i)
		if def.terrain.is_empty():
			continue
		wall_keys.append(def.terrain)
		_wall_slot[i] = wall_keys.size()
		built_walls[wall_keys.size()] = 1.0 if def.built else 0.0
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("materials", _strip(keys, ""))
	_material.set_shader_parameter("overlays", _strip(overlays, "ore_"))
	_material.set_shader_parameter("wall_tex", _strip(wall_keys, ""))
	_material.set_shader_parameter("noise_tex", load(TERRAIN_DIR + "/noise.png"))
	_material.set_shader_parameter("grass_slots", grass)
	_material.set_shader_parameter("built_slots", built)
	_material.set_shader_parameter("built_walls", built_walls)
	for i in GRASS_COLORS.size():
		_material.set_shader_parameter("grass_%d" % i, Color(GRASS_COLORS[i]))


## Packs 64x64 textures side by side; an empty key leaves that cell transparent.
func _strip(keys: Array[String], prefix: String) -> ImageTexture:
	var img := Image.create_empty(maxi(keys.size(), 1) * MATERIAL_TEX, MATERIAL_TEX, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for i in keys.size():
		if keys[i].is_empty():
			continue
		var tex := load(TERRAIN_DIR.path_join(prefix + keys[i] + ".png")) as Texture2D
		var src := tex.get_image()
		src.convert(Image.FORMAT_RGBA8)
		img.blit_rect(src, Rect2i(0, 0, MATERIAL_TEX, MATERIAL_TEX), Vector2i(i * MATERIAL_TEX, 0))
	return ImageTexture.create_from_image(img)


## Collision set: one tile per atlas row with its shape. Props set: every platform and
## rope variant, no physics.
func _build_tileset(physics: bool) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = load(BLOCKS_ATLAS) as Texture2D
	src.texture_region_size = Vector2i(TILE, TILE)
	if physics:
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, 1)  # "world"
		ts.set_physics_layer_collision_mask(0, 0)
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(1, 2)  # "platforms"
		ts.set_physics_layer_collision_mask(1, 0)
	ts.add_source(src, 0)
	var half := TILE / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	var platform := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + 3), Vector2(-half, -half + 3)])
	var rows := src.texture.get_height() / TILE
	for row in rows:
		var collision := _world.blocks.collision_for_row(row)
		if physics:
			var coords := Vector2i(0, row)
			src.create_tile(coords)
			var td := src.get_tile_data(coords, 0)
			if collision == TileDef.Collision.SOLID:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, square)
			elif collision == TileDef.Collision.PLATFORM:
				td.add_collision_polygon(1)
				td.set_collision_polygon_points(1, 0, platform)
				td.set_collision_polygon_one_way(1, 0, true)
		elif collision != TileDef.Collision.SOLID:
			for col in 16 * PIECES:
				src.create_tile(Vector2i(col, row))
	return ts
