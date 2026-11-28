extends GutTest
## Phase 81: the salt sea, boiling, rain, Rain Catchers and lakes.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

var w: World
var v: VoxelLayer
var floor_tile: Vector2i


func before_each() -> void:
	Game.world_info = WorldInfo.test_course()
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	v = w.voxels
	var feet := w.world_to_tile(w.player.global_position)
	floor_tile = Vector2i(feet.x + 12, feet.y - 30)


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	Game.world_info = null


## A stone tank 10 wide high in the air with `depth` tiles of `liquid`, the player in it.
func _tank(depth: int, liquid: StringName = &"salt_water") -> void:
	var stone := w.blocks.index_of(&"stone")
	for x in range(-1, 11):
		w.request_set_block(floor_tile + Vector2i(x, 0), stone)
	for y in range(1, 15):
		w.request_set_block(floor_tile + Vector2i(-1, -y), stone)
		w.request_set_block(floor_tile + Vector2i(10, -y), stone)
	for y in range(1, depth + 1):
		for x in 10:
			v.request_fill(floor_tile + Vector2i(x, -y), liquid)
	w.teleport_player(w.tile_to_world(floor_tile + Vector2i(2, 0)))
	await wait_physics_frames(3)


func _hold(id: StringName, count: int) -> void:
	w.character.inventory.set_slot(0, id, count)
	w.player.select_slot(0)


func test_cell_codes_stay_put() -> void:
	assert_eq(v.code_of(&"sand"), 1)
	assert_eq(v.code_of(&"sand_bricks"), 2)
	assert_eq(v.code_of(&"water"), 3, "saved worlds keep their water")
	assert_eq(v.code_of(&"salt_water"), 4)


func test_the_sea_is_salt_and_lakes_are_fresh() -> void:
	var g := ForestGenerator.new(TileTypes.new(&"tiles"), TileTypes.new(&"walls"), 4200, 1200, 42,
		ForestGenerator.default_settings())
	var o := g.ocean()
	var c := roundi(o.x)
	assert_true(g.salt_at(c, g.surface_at(c) - 2), "the sea")
	var lakes := 0
	for p in g.ponds():
		var x := roundi(p.x)
		var y := int(p.w) + 1
		assert_true(g.water_at(x, y), "water in the pool")
		assert_false(g.salt_at(x, y), "fresh")
		var chunk := ChunkData.new(Vector2i(x >> 5, y >> 5))
		g.generate_chunk(chunk)
		assert_eq(chunk.water[ChunkData.local_index(x & 31, y & 31)], 1, "generated as fresh water")
		if p.y * 2.0 >= g.settings.lake_width_min:
			lakes += 1
	assert_gt(lakes, 0, "some lakes")


func test_bottles_fill_with_salt_water() -> void:
	await _tank(2)
	_hold(&"glass_vial", 2)
	var spot := floor_tile + Vector2i(4, -1)
	assert_eq(w.item_user.fill_held(spot), 1)
	assert_eq(w.character.inventory.count_of(&"salt_water_glass_vial"), 1)
	_hold(&"water_clay_jug_2", 1)
	assert_eq(w.item_user.fill_held(spot), 0, "no mixing")
	_hold(&"clay_bucket", 1)
	assert_eq(w.item_user.fill_held(spot), 1)
	assert_eq(w.character.inventory.count_of(&"clay_bucket_salt_water"), 1)


func test_salt_water_is_too_salty() -> void:
	await _tank(2)
	w.character.inventory.set_slot(0, &"", 0)
	w.player.select_slot(0)
	w.player.thirst = 10.0
	assert_true(w.item_user.sip_at(floor_tile + Vector2i(4, -1)), "handled")
	assert_eq(w.player.thirst, 10.0, "no sip")
	assert_eq(ItemData.find(&"salt_water_clay_jug").kind, ItemData.Kind.MATERIAL, "can't drink a bottle of it")


func test_boiling_gives_water_and_salt() -> void:
	for station: StringName in [&"cooking", &"furnace"]:
		var id := &"boil_clay_jug" if station == &"cooking" else &"boil_clay_jug_furnace"
		var r := Registry.get_def(&"recipes", id) as RecipeData
		assert_not_null(r)
		assert_eq(r.station, station)
		var inv := Inventory.new(10)
		inv.add(&"salt_water_clay_jug", 2)
		assert_eq(Crafting.craft(inv, r, 2)[0], 2)
		assert_eq(inv.count_of(&"water_clay_jug"), 2)
		assert_eq(inv.count_of(&"salt"), 8, "4 Salt a jug")


func test_barrels_take_only_fresh_water() -> void:
	await _tank(0)
	var spot := floor_tile + Vector2i(5, -1)
	assert_true(w.request_place_object(spot, w.objects.index_of(&"liquid_barrel")))
	_hold(&"clay_bucket_salt_water", 1)
	assert_false(w.item_user.pour_held(spot))
	assert_eq(w.barrel_water(spot), 0)


func test_rain_fills_catchers_under_open_sky() -> void:
	await _tank(0)
	var spot := floor_tile + Vector2i(2, -1)
	assert_true(w.request_place_object(spot, w.objects.index_of(&"rain_catcher")))
	var def := w.object_at(spot)
	assert_eq(def.liquid_capacity, 96, "its size in water: 2 x 3 tiles")
	assert_eq(w.barrel_water(spot), 0)
	assert_true(w.liquids.has(w.object_anchor(spot)), "listed even when empty")
	w.weather.start_rain(2.0)
	w.weather.intensity = 1.0
	assert_eq(w.weather.fill_catchers(60.0), int(def.catches_rain), "a minute of rain")
	assert_eq(w.barrel_water(spot), int(def.catches_rain))
	# A roof: no more.
	w.request_set_block(spot + Vector2i(0, -6), w.blocks.index_of(&"stone"))
	assert_eq(w.weather.fill_catchers(60.0), 0, "covered")
	assert_eq(w.weather.to_dict()["raining"], true)
	w.weather.stop_rain()
	assert_false(w.weather.raining)


func test_rain_dims_the_sky() -> void:
	var light := w.clock.sun_light()
	w.clock.overcast = 0.3
	assert_lt(w.clock.sun_light().get_luminance(), light.get_luminance())
	w.clock.overcast = 0.0
