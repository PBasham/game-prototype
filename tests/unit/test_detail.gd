extends GutTest
## Detailed art (2 art pixels per world pixel): items with 32x32 art show at the same
## size as 16x16 ones, and terrain textures of either size pack into one strip.


func test_detailed_items_show_at_normal_size() -> void:
	var item := ItemData.find(&"healing_potion")
	assert_eq(item.icon.get_width(), 32, "detailed icon")
	assert_eq(item.held.detail, 2)
	assert_not_null(item.badge, "badge for the inventory slot")
	var drop := ItemDrop.new()
	drop.item_id = &"healing_potion"
	add_child_autofree(drop)
	var sprite := drop._sprite
	assert_almost_eq(sprite.texture.get_width() * sprite.scale.x, drop._size, 0.01, "same size as a 16 px icon would be")


func test_terrain_strip_mixes_detail() -> void:
	var r := ChunkRenderer.new()
	var keys: Array[String] = ["dirt", "planks"]
	var tex := r._strip(keys, "")
	assert_eq(tex.get_height(), ChunkRenderer.MATERIAL_CELL)
	assert_eq(tex.get_width(), ChunkRenderer.MATERIAL_CELL * 2)
	var dirt := (load("res://assets/terrain/dirt.png") as Texture2D).get_image()
	assert_eq(dirt.get_width(), 128, "dirt is detailed now")
	r.free()
