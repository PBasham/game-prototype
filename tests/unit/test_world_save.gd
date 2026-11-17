extends GutTest
## WorldSave round trip: info, edited chunks, id palette remapping.

const PATH := "user://test_worlds/roundtrip.gpworld"

var blocks: TileTypes
var walls: TileTypes


func before_all() -> void:
	blocks = TileTypes.new(&"tiles")
	walls = TileTypes.new(&"walls")


func after_all() -> void:
	WorldSave.delete(PATH)


func test_round_trip() -> void:
	var info := WorldInfo.create("Round Trip", WorldData.Size.MEDIUM, 4242)
	var c := ChunkData.new(Vector2i(3, 17))
	c.blocks.fill(blocks.index_of(&"stone"))
	c.blocks[5] = blocks.index_of(&"copper_ore")
	c.walls[9] = walls.index_of(&"wood_wall")
	c.modified = true
	assert_eq(WorldSave.save(PATH, info, [c] as Array[ChunkData], blocks, walls), OK)

	var read := WorldSave.read_info(PATH)
	assert_not_null(read)
	assert_eq(read.name, "Round Trip")
	assert_eq(read.seed, 4242)
	assert_eq(read.size, WorldData.Size.MEDIUM)
	assert_eq(read.kind, &"forest")

	var chunks := WorldSave.load_chunks(PATH, blocks, walls)
	assert_eq(chunks.size(), 1)
	var back: ChunkData = chunks[Vector2i(3, 17)]
	assert_eq(back.blocks, c.blocks)
	assert_eq(back.walls, c.walls)
	assert_true(back.modified)


func test_saved_chunks_replace_generation() -> void:
	var d := WorldData.new(64, 64)
	d.generator = func(chunk: ChunkData) -> void: chunk.blocks.fill(1)
	var saved := ChunkData.new(Vector2i(1, 1))
	saved.blocks.fill(2)
	saved.modified = true
	d.saved[Vector2i(1, 1)] = saved
	assert_eq(d.get_block(40, 40), 2, "saved chunk is used")
	assert_eq(d.get_block(5, 5), 1, "other chunks generate")
	assert_eq(d.modified_chunks().size(), 1)


func test_seed_from_text() -> void:
	assert_eq(WorldInfo.seed_from_text("123"), 123)
	assert_eq(WorldInfo.seed_from_text("forest"), WorldInfo.seed_from_text("forest"))
	assert_ne(WorldInfo.seed_from_text("forest"), WorldInfo.seed_from_text("Forest"))
