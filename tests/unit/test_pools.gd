extends GutTest
## Phase 88: real lakes, ponds of every size, sloped banks, sand or dirt beds, a smooth
## coast, and no thin rock strips floating in the Deep.

var g: ForestGenerator


func before_all() -> void:
	g = ForestGenerator.new(TileTypes.new(&"tiles"), TileTypes.new(&"walls"), 6400, 2048, 1337,
		ForestGenerator.default_settings())


func test_lakes_and_ponds_of_all_sizes() -> void:
	var lakes := 0
	var narrow := 1000
	var wide := 0
	for p in g.ponds():
		var w := p.y * 2.0
		if w >= g.settings.lake_width_min:
			lakes += 1
		else:
			narrow = mini(narrow, roundi(w))
			wide = maxi(wide, roundi(w))
	assert_gt(lakes, 0, "some lakes")
	assert_gt(wide - narrow, 15, "ponds from small (%d) to big (%d)" % [narrow, wide])


func test_banks_slope_down_to_the_water() -> void:
	for p in g.ponds():
		var c := roundi(p.x)
		var reach := ceili(p.y + maxf(p.y * g.settings.pool_bank_ratio, float(g.settings.pool_bank_min)))
		# Where the pool meets its banks: no cliff (land beyond may have its own).
		for side: int in [-1, 1]:
			var edge := c + side * ceili(p.y)
			for k in range(-2, 3):
				var x := edge + k
				var step := absi(g.surface_at(x + 1) - g.surface_at(x))
				assert_lte(step, 3, "pool at %d: a %d tile drop at %d" % [c, step, x])
		assert_gt(reach, 0)


func test_beds_are_sand_or_dirt() -> void:
	var sand := 0
	var dirt := 0
	for i in g.ponds().size():
		var p: Vector4 = g.ponds()[i]
		var c := roundi(p.x)
		var bed := g.block_at(c, g.surface_at(c))
		if bed == g._b[&"sand"]:
			sand += 1
		elif bed == g._b[&"dirt"]:
			dirt += 1
		else:
			fail_test("pool at %d has a %d bed" % [c, bed])
	assert_gt(sand, 0, "sand beds")
	assert_gt(dirt, 0, "dirt beds")


func test_no_thin_strips_in_the_deep() -> void:
	var o := g.ocean()
	var strips := 0
	for x in range(roundi(o.x - o.y * 0.4), roundi(o.x + o.y * 0.4), 7):
		var y := g.surface_at(x) + 30
		while y < 1980:
			if g.block_at(x, y) != WorldData.AIR and g.water_at(x, y - 1):
				var run := 0
				while run < 4 and g.block_at(x, y + run) != WorldData.AIR:
					run += 1
				if run < g.settings.deep_min_rock and g.water_at(x, y + run):
					strips += 1
				y += maxi(run, 1)
			else:
				y += 1
	assert_eq(strips, 0, "no rock sheets thinner than deep_min_rock with water both sides")
