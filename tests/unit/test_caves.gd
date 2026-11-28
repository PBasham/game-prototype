extends GutTest
## Phase 89: Terraria-like caves: more of them, long winding tunnels, small caves up top,
## caverns deeper down, more surface entrances.


func test_enough_caves_but_not_swiss_cheese() -> void:
	var g := ForestGenerator.new(TileTypes.new(&"tiles"), TileTypes.new(&"walls"), 6400, 2048, 1337,
		ForestGenerator.default_settings())
	var open := 0
	var n := 0
	var small := 0
	for x in range(300, 6000, 9):
		if g.ocean_at(x) > 0.0:
			continue
		var top := g.surface_at(x)
		for d in range(8, 400, 5):
			n += 1
			if g.block_at(x, top + d) == WorldData.AIR:
				open += 1
				if d < 70:
					small += 1
	var share := float(open) / n
	assert_between(share, 0.12, 0.4, "about a fifth to a third open (%.2f)" % share)
	assert_gt(small, 0, "caves in the upper ground too")


func test_more_entrances() -> void:
	var s := ForestGenerator.default_settings()
	assert_lte(s.entrance_spacing, 400)
	assert_gte(s.entrance_depth_max, 140)
