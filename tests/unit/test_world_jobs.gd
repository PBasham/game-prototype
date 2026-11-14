extends GutTest
## Background world jobs (generation, chunk builds, lighting) must match the
## main-thread results exactly.

const W := 6400
const H := 2048

var blocks: TileTypes
var walls: TileTypes
var gen: TestWorldGenerator


func before_all() -> void:
	blocks = TileTypes.new(&"tiles")
	walls = TileTypes.new(&"walls")
	gen = TestWorldGenerator.new(blocks, walls, W, H, 1337)


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
	assert_eq(job.bytes[5 * w + 5], 255, "sky")
	assert_lt(job.bytes[(ChunkData.SIZE + 3) * w + 5], 255, "3 tiles into rock is dimmer")
	assert_gt(job.bytes[(ChunkData.SIZE + 3) * w + 5], job.bytes[(ChunkData.SIZE * 2 - 1) * w + 5], "fades with depth")
	assert_eq(job.bytes[(ChunkData.SIZE * 2 - 1) * w + 5], int(job.ambient * 255.0 + 0.5), "deep rock is ambient")
