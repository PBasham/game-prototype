extends GutTest
## Background world jobs (generation, chunk builds, lighting) must match the
## main-thread results exactly.

const W := 6400
const H := 2048

var blocks: TileTypes
var walls: TileTypes
var gen: CourseGenerator


func before_all() -> void:
	blocks = TileTypes.new(&"tiles")
	walls = TileTypes.new(&"walls")
	gen = CourseGenerator.new(blocks, walls, W, H, 1337)


func _world() -> WorldData:
	var data := WorldData.new(W, H)
	data.generator = gen.generate_chunk
	return data


func test_background_generation_matches_main_thread() -> void:
	var sync := _world()
	var bg := _world()
	var coords: Array[Vector2i] = [Vector2i(6, 19), Vector2i(-1, 20), Vector2i(150, 30)]
	for c in coords:
		assert_false(bg.request_chunk(c), "not ready before the job runs")
	bg.wait_all()
	for c in coords:
		assert_true(bg.request_chunk(c))
		assert_eq(bg.peek_chunk(c).blocks, sync.get_chunk(c).blocks)
		assert_eq(bg.peek_chunk(c).walls, sync.get_chunk(c).walls)
	assert_eq(bg.pending_generation_count(), 0)


func test_get_chunk_waits_for_a_running_job() -> void:
	var data := _world()
	data.request_chunk(Vector2i(3, 19))
	var chunk := data.get_chunk(Vector2i(3, 19))
	assert_eq(data.pending_generation_count(), 0)
	assert_eq(chunk, data.peek_chunk(Vector2i(3, 19)), "uses the job's chunk, not a second one")


func _job(data: WorldData, c: Vector2i) -> ChunkBuildJob:
	var job := ChunkBuildJob.new()
	job.coord = c
	job.world_width = W
	job.world_height = H
	job.collision = blocks.collision_table()
	job.atlas_row = blocks.atlas_row_table()
	job.block_slot.resize(blocks.size())
	job.wall_slot.resize(walls.size())
	job.grass_id = blocks.index_of(&"grass")
	job.generator = gen
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			var chunk: ChunkData = data.get_chunk(n) if n.y >= 0 and n.y < data.chunks_y else null
			job.chunks.append(chunk)
			job.revisions.append(chunk.revision if chunk else 0)
			job.blocks.append(chunk.blocks if chunk else PackedInt32Array())
			job.walls.append(chunk.walls if chunk else PackedInt32Array())
	return job


func test_build_job_reads_the_same_tiles_as_world_data() -> void:
	var data := _world()
	# Across the wrap seam, at the top row of the world and on the surface.
	for c: Vector2i in [Vector2i(-1, 19), Vector2i(0, 0), Vector2i(6, 19)]:
		var job := _job(data, c)
		var origin := c * ChunkData.SIZE
		for ly in range(-2, ChunkData.SIZE + 2):
			for lx in range(-2, ChunkData.SIZE + 2):
				var t := origin + Vector2i(lx, ly)
				if job.block(lx, ly) != data.get_block(t.x, t.y) or job.wall(lx, ly) != data.get_wall(t.x, t.y):
					fail_test("tile mismatch at %s in chunk %s" % [t, c])
					return
	pass_test("all tiles match")


func test_build_job_collision_matches_tile_types() -> void:
	var data := _world()
	var c := Vector2i(6, 19)
	var job := _job(data, c)
	job.run()
	var expected := 0
	for ly in ChunkData.SIZE:
		for lx in ChunkData.SIZE:
			var id := data.get_block(c.x * ChunkData.SIZE + lx, c.y * ChunkData.SIZE + ly)
			if id > 0 and blocks.collision(id) != TileDef.Collision.NONE:
				expected += 1
	assert_eq(job.collision_cells.size(), expected * 3)
	assert_eq(job.tile_bytes.size(), ChunkBuildJob.TEX * ChunkBuildJob.TEX * 4)


func test_build_job_goes_stale_on_edit() -> void:
	var data := _world()
	var job := _job(data, Vector2i(6, 19))
	assert_false(job.is_stale())
	data.set_block(6 * ChunkData.SIZE + 33, 19 * ChunkData.SIZE, WorldData.AIR)  # right neighbor
	assert_true(job.is_stale())


func test_build_job_on_a_worker_matches_inline() -> void:
	var data := _world()
	var a := _job(data, Vector2i(9, 19))
	var b := _job(data, Vector2i(9, 19))
	a.run()
	WorkerThreadPool.wait_for_task_completion(WorkerThreadPool.add_task(b.run))
	assert_eq(a.tile_bytes, b.tile_bytes)
	assert_eq(a.collision_cells, b.collision_cells)
	assert_eq(a.prop_cells, b.prop_cells)
	assert_eq(a.decor, b.decor)


func test_light_sky_is_lit_and_deep_rock_is_ambient() -> void:
	# One column of chunks: open sky on top, solid stone below.
	var stone := blocks.index_of(&"stone")
	var sky := PackedInt32Array()
	sky.resize(ChunkData.AREA)
	var rock := PackedInt32Array()
	rock.resize(ChunkData.AREA)
	rock.fill(stone)
	var no_walls := PackedInt32Array()
	no_walls.resize(ChunkData.AREA)
	var job := LightJob.new()
	job.rect = Rect2i(0, 0, ChunkData.SIZE, ChunkData.SIZE * 2)
	job.blocks = [sky, rock]
	job.walls = [no_walls, no_walls]
	var table := blocks.collision_table()
	job.solid.resize(table.size())
	for i in table.size():
		job.solid[i] = 1 if table[i] == TileDef.Collision.SOLID else 0
	job.run()
	var w := ChunkData.SIZE
	var at := func(x: int, y: int) -> int: return job.bytes[(y * w + x) * 3]  # red channel (sky is white)
	assert_eq(at.call(5, 5), 255, "sky")
	assert_lt(at.call(5, ChunkData.SIZE + 3), 255, "3 tiles into rock is dimmer")
	assert_gt(at.call(5, ChunkData.SIZE + 3), at.call(5, ChunkData.SIZE * 2 - 1), "fades with depth")
	assert_eq(at.call(5, ChunkData.SIZE * 2 - 1), int(job.ambient * 255.0 + 0.5), "deep rock is ambient")


func test_torches_light_a_dark_cave_warm() -> void:
	# A sealed 32x32 room in rock (no sky), with a torch in the middle.
	var stone := blocks.index_of(&"stone")
	var room := PackedInt32Array()
	room.resize(ChunkData.AREA)
	room.fill(stone)
	for y in range(4, 28):
		for x in range(4, 28):
			room[y * ChunkData.SIZE + x] = WorldData.AIR
	var walls := PackedInt32Array()
	walls.resize(ChunkData.AREA)
	walls.fill(1)  # back walls everywhere: no sky light
	var objs := PackedInt32Array()
	objs.resize(ChunkData.AREA)
	var objects := TileTypes.new(&"objects")
	var torch := objects.index_of(&"torch")
	objs[16 * ChunkData.SIZE + 16] = torch
	var job := LightJob.new()
	job.rect = Rect2i(0, 0, ChunkData.SIZE, ChunkData.SIZE)
	job.blocks = [room]
	job.walls = [walls]
	job.objects = [objs]
	var table := blocks.collision_table()
	job.solid.resize(table.size())
	for i in table.size():
		job.solid[i] = 1 if table[i] == TileDef.Collision.SOLID else 0
	var def := objects.def(torch) as ObjectDef
	job.emitters.resize(objects.size() * 4)
	job.emitters[torch * 4] = def.light_color.r
	job.emitters[torch * 4 + 1] = def.light_color.g
	job.emitters[torch * 4 + 2] = def.light_color.b
	job.emitters[torch * 4 + 3] = def.light_radius
	job.run()
	var px := func(x: int, y: int) -> Color:
		var i := (y * ChunkData.SIZE + x) * 3
		return Color8(job.bytes[i], job.bytes[i + 1], job.bytes[i + 2])
	var near: Color = px.call(17, 16)
	var far: Color = px.call(5, 5)
	var ambient := job.ambient
	assert_gt(near.r, 0.9, "bright next to the torch")
	assert_gt(near.r, near.b + 0.1, "warm (more red than blue)")
	assert_lt(far.r, near.r, "dimmer in the far corner")
	assert_almost_eq(px.call(16, 16 + 14).r, ambient, 0.02, "past its radius through rock: dark")


func test_closed_doors_block_torch_light() -> void:
	# A room (x 4..15) with a stone wall at x 16 and a closed 1x8 door in it (rows 20..27),
	# open air (no walls) outside, a torch inside near the door.
	var stone := blocks.index_of(&"stone")
	var tiles := PackedInt32Array()
	tiles.resize(ChunkData.AREA)
	for y in ChunkData.SIZE:
		for x in ChunkData.SIZE:
			if y >= 28 or x < 2 or (x == 16 and y < 20) or y < 10:
				tiles[y * ChunkData.SIZE + x] = stone
	var walls := PackedInt32Array()
	walls.resize(ChunkData.AREA)
	walls.fill(1)  # dark everywhere: only the torch lights it
	var objs := PackedInt32Array()
	objs.resize(ChunkData.AREA)
	var objects := TileTypes.new(&"objects")
	var torch := objects.index_of(&"torch")
	var door := objects.index_of(&"door")
	var filler := objects.index_of(&"filler")
	objs[22 * ChunkData.SIZE + 14] = torch
	objs[27 * ChunkData.SIZE + 16] = door
	for y in range(20, 27):
		objs[y * ChunkData.SIZE + 16] = filler
	var run := func(with_door: bool) -> int:
		var job := LightJob.new()
		job.rect = Rect2i(0, 0, ChunkData.SIZE, ChunkData.SIZE)
		job.blocks = [tiles]
		job.walls = [walls]
		job.objects = [objs]
		var table := blocks.collision_table()
		job.solid.resize(table.size())
		for i in table.size():
			job.solid[i] = 1 if table[i] == TileDef.Collision.SOLID else 0
		var def := objects.def(torch) as ObjectDef
		job.emitters.resize(objects.size() * 4)
		job.emitters[torch * 4] = def.light_color.r
		job.emitters[torch * 4 + 1] = def.light_color.g
		job.emitters[torch * 4 + 2] = def.light_color.b
		job.emitters[torch * 4 + 3] = def.light_radius
		job.object_solid.resize(objects.size())
		job.object_h.resize(objects.size())
		if with_door:
			job.object_solid[door] = 1
			job.object_h[door] = 8
		job.run()
		return job.bytes[(22 * ChunkData.SIZE + 18) * 3]  # 2 tiles outside the door
	var open_light: int = run.call(false)
	var shut_light: int = run.call(true)
	assert_gt(open_light, shut_light + 40, "the open doorway lets light out")
	assert_almost_eq(shut_light, int(0.16 * 255.0 + 0.5), 3, "a closed door keeps it in")
