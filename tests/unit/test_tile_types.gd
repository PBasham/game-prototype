extends GutTest

var blocks: TileTypes


func before_all() -> void:
	blocks = TileTypes.new(&"tiles")


func test_index_zero_is_empty() -> void:
	assert_null(blocks.def(0))
	assert_eq(blocks.collision(0), TileDef.Collision.NONE)


func test_lookup_by_id() -> void:
	var dirt := blocks.index_of(&"dirt")
	assert_gt(dirt, 0)
	assert_eq(blocks.def(dirt).id, &"dirt")
	assert_eq(blocks.index_of(&"nope"), -1)


func test_collision_kinds() -> void:
	assert_eq(blocks.collision(blocks.index_of(&"stone")), TileDef.Collision.SOLID)
	assert_eq(blocks.collision(blocks.index_of(&"wood_platform")), TileDef.Collision.PLATFORM)
	assert_eq(blocks.collision(blocks.index_of(&"rope")), TileDef.Collision.NONE)
	assert_true(blocks.climbable(blocks.index_of(&"rope")))


func test_solids_connect_to_any_solid_others_only_to_themselves() -> void:
	var dirt := blocks.index_of(&"dirt")
	var stone := blocks.index_of(&"stone")
	var platform := blocks.index_of(&"wood_platform")
	assert_true(blocks.connects(dirt, stone))
	assert_false(blocks.connects(dirt, platform))
	assert_false(blocks.connects(dirt, WorldData.AIR))
	assert_true(blocks.connects(platform, platform))
	assert_false(blocks.connects(platform, dirt))


func test_atlas_rows_are_unique_and_fit_the_texture() -> void:
	var tex := load("res://assets/tiles/blocks.png") as Texture2D
	var rows := tex.get_height() / 16
	var seen := {}
	for i in range(1, blocks.size()):
		var row := blocks.atlas_row(i)
		assert_false(seen.has(row), "atlas_row %d used twice" % row)
		assert_lt(row, rows, "%s atlas_row past the texture" % blocks.def(i).id)
		seen[row] = true
