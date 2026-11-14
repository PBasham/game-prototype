extends GutTest

var data: WorldData


func before_each() -> void:
	data = WorldData.new(128, 64)


func test_size_must_be_chunk_multiple() -> void:
	assert_eq(data.chunks_x, 4)
	assert_eq(data.chunks_y, 2)


func test_wraps_horizontally() -> void:
	data.set_block(-1, 10, 5)
	assert_eq(data.get_block(127, 10), 5)
	assert_eq(data.get_block(255, 10), 5)
	data.set_block(128, 3, 7)
	assert_eq(data.get_block(0, 3), 7)


func test_vertical_bounds() -> void:
	assert_eq(data.get_block(0, -1), WorldData.AIR)
	assert_eq(data.get_block(0, 64), WorldData.OUT_OF_BOUNDS)
	assert_false(data.set_block(0, 64, 1))
	assert_false(data.set_block(0, -1, 1))


func test_chunks_generate_lazily_with_generator() -> void:
	var calls := [0]
	data.generator = func(chunk: ChunkData) -> void:
		calls[0] += 1
		chunk.blocks.fill(3)
	assert_eq(data.generated_chunk_count(), 0)
	assert_eq(data.get_block(40, 40), 3)
	assert_eq(calls[0], 1)
	data.get_block(41, 41)
	assert_eq(calls[0], 1, "same chunk should not regenerate")


func test_set_marks_chunk_modified() -> void:
	data.set_block(5, 5, 2)
	assert_true(data.get_chunk(Vector2i(0, 0)).modified)
	assert_false(data.get_chunk(Vector2i(1, 0)).modified)


func test_walls_are_separate_from_blocks() -> void:
	data.set_wall(10, 10, 4)
	assert_eq(data.get_wall(10, 10), 4)
	assert_eq(data.get_block(10, 10), WorldData.AIR)
