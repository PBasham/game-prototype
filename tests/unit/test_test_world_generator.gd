extends GutTest

const W := 4224
const H := 1216

var blocks: TileTypes
var walls: TileTypes


func before_all() -> void:
	blocks = TileTypes.new(&"tiles")
	walls = TileTypes.new(&"walls")


func _gen(seed: int) -> TestWorldGenerator:
	return TestWorldGenerator.new(blocks, walls, W, H, seed)


func test_same_seed_same_world() -> void:
	var a := WorldData.new(W, H)
	var b := WorldData.new(W, H)
	a.generator = _gen(7).generate_chunk
	b.generator = _gen(7).generate_chunk
	for c: Vector2i in [Vector2i(0, 11), Vector2i(5, 12), Vector2i(131, 20)]:
		assert_eq(a.get_chunk(c).blocks, b.get_chunk(c).blocks)
		assert_eq(a.get_chunk(c).walls, b.get_chunk(c).walls)


func test_surface_is_seamless_across_the_wrap() -> void:
	var g := _gen(1)
	for x in range(-3, 4):
		assert_lte(absi(g.surface_at(posmod(x, W)) - g.surface_at(posmod(x - 1, W))), 3, "jump at x=%d" % x)


func test_spawn_is_standable() -> void:
	var g := _gen(1)
	var s := g.spawn_tile()
	assert_eq(g.block_at(s.x, s.y - 1), WorldData.AIR, "air above spawn")
	assert_ne(blocks.collision(g.block_at(s.x, s.y)), TileDef.Collision.NONE, "solid at spawn")
	for dy in range(1, 5):
		assert_eq(g.block_at(s.x, s.y - dy), WorldData.AIR, "room for a 4-tile player")


func test_jump_values_reach_the_height() -> void:
	var jv := Player.jump_values(5.5, 0.42)
	var apex := jv.y * jv.y / (2.0 * jv.x) / 16.0
	assert_almost_eq(apex, 5.5, 0.01)
