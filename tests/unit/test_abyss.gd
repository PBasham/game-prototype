extends GutTest
## Phase 65: Abyssal Stone, the sea refilling itself, pristine water (not saved, dropped
## far away and put back).

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const PATH := "user://test_abyss_world.tres"

var w: World
var g: ForestGenerator


func before_each() -> void:
	WorldSave.delete(PATH)
	var info := WorldInfo.create("Abyss", WorldData.Size.TINY, 7)
	info.path = PATH
	Game.world_info = info
	Game.character = null
	w = WORLD_SCENE.instantiate() as World
	add_child(w)
	await wait_physics_frames(3)
	g = w.generator as ForestGenerator
	w.voxels.ocean_refill = false


func after_each() -> void:
	w.queue_free()
	await wait_physics_frames(2)
	WorldSave.delete(PATH)
	Game.world_info = null


## A tile of the shell: its wall down the Deep's left side.
func _wall_tile() -> Vector2i:
	var o := g.ocean()
	var x := roundi(o.x - o.y + g.settings.deep_margin - 1.0)
	return Vector2i(x, g.height - 40)


## The top row of the sea, in its middle.
func _sea_row() -> int:
	return g.surface_at(roundi(g.ocean().x - g.ocean().y) + 2)


func test_nothing_breaks_abyssal_stone() -> void:
	var t := _wall_tile()
	var abyss := w.blocks.index_of(&"abyssal_stone")
	assert_eq(w.data.get_block(t.x, t.y), abyss)
	w.instant_break = true
	assert_false(w.request_damage_block(t, INF), "mining")
	w.instant_break = false
	w.request_explode(w.tile_to_world(t) + Vector2(4, 4), 4.0, 0.0, 999)
	assert_eq(w.data.get_block(t.x, t.y), abyss, "a bomb")
	assert_false(w.request_set_shape(t, 1), "the Shaping Spell")
	assert_eq(w.data.get_shape(t.x, t.y) & 7, 0)


func test_the_sea_refills_near_you() -> void:
	var c := roundi(g.ocean().x - g.ocean().y * 0.5)
	var sea := _sea_row()
	for x in range(c - 60, c + 60, 16):
		w.data.get_chunk(Vector2i(posmod(x, w.data.width) / ChunkData.SIZE, sea / ChunkData.SIZE))
		w.data.get_chunk(Vector2i(posmod(x, w.data.width) / ChunkData.SIZE, (sea + 12) / ChunkData.SIZE))
	w.voxels.import_generated()
	w.teleport_player(w.tile_to_world(Vector2i(c, sea + 4)))
	await wait_seconds(1.0)
	w.voxels.import_generated()
	var band := Rect2i(c - 60, sea, 120, 12)
	var full := w.voxels.liquid_in(band, &"salt_water")
	assert_gt(w.voxels.take_liquid(Rect2i(c - 4, sea, 8, 6), 8 * 6 * 16, &"salt_water"), 300)
	await wait_seconds(1.0)
	var low := w.voxels.liquid_in(band, &"salt_water")
	assert_lt(low, full - 300, "water was taken")
	w.voxels.ocean_refill = true
	await wait_seconds(3.0)
	assert_gt(w.voxels.liquid_in(band, &"salt_water"), low + 150, "the sea filled back up")


func test_no_refill_out_of_the_sea() -> void:
	w.voxels.ocean_refill = true
	var dry := Vector2i(g.settings.spawn_x, g.surface_at(g.settings.spawn_x) - 3)
	assert_false(g.sea_at(dry.x, dry.y))
	assert_eq(w.voxels.refill_sea(dry, 50), 0)


func test_pristine_water_is_not_saved_and_streams() -> void:
	var t := Vector2i(roundi(g.ocean().x - g.ocean().y * 0.5), _sea_row() + 3)
	var c := Vector2i(t.x / ChunkData.SIZE, t.y / ChunkData.SIZE)
	w.data.get_chunk(c)
	w.voxels.import_generated()
	assert_true(w.voxels.is_pristine(c))
	var saved: Dictionary = w.voxels.to_dict().get("tiles", {})
	assert_false(saved.has("%d,%d" % [t.x, t.y]), "untouched water isn't saved")
	# Far away it's dropped, near again it's back.
	w.voxels.stream_water(t + Vector2i(w.data.width / 2, 0))
	assert_eq(w.voxels.count_in(t, &"salt_water"), 0, "dropped")
	w.voxels.stream_water(t)
	w.voxels.flush_imports()  # streamed chunks queue (Phase 85)
	assert_eq(w.voxels.count_in(t, &"salt_water"), 16, "back from the generator")
	# Touched water is saved and stays.
	w.voxels.take_liquid(Rect2i(t, Vector2i.ONE), 4, &"salt_water")
	assert_false(w.voxels.is_pristine(c))
	saved = w.voxels.to_dict().get("tiles", {})
	assert_true(saved.has("%d,%d" % [t.x, t.y]))
	w.voxels.stream_water(t + Vector2i(w.data.width / 2, 0))
	assert_eq(w.voxels.count_in(t, &"salt_water"), 12, "not dropped")
