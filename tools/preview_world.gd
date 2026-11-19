extends SceneTree
## Renders a world (or part of it) to a PNG map, for tuning world generation without
## playing. 1 pixel = `step` tiles. Runs the real generator on all CPU cores.
##
##   godot --headless --path . --script res://tools/preview_world.gd -- --seed=42
##
## Options (all optional):
##   --seed=N          world seed (default 1337)
##   --size=small      tiny, small, medium, large (default small)
##   --world=forest    generator kind: forest or course
##   --x=X0:WIDTH      columns to draw (default: the whole world, starting at spawn - W/2)
##   --y=Y0:HEIGHT     rows to draw (default: from 60 above the highest surface to 700
##                     below spawn)
##   --step=N          tiles per pixel (default 2)
##   --scale=N         upscale the image by N with nearest filtering (default 1)
##   --out=PATH        output file (default user://preview_<seed>.png)
##
## Colors: sky, grass, dirt, stone, copper (orange), iron (pale grey), clay (terracotta), caves (dark), cave walls (darker
## brown/gray), tree trunks (dark green ticks above the surface), flowers (pink dots).

const COLORS := {
	&"grass": Color("4f8a2c"),
	&"dirt": Color("7a5233"),
	&"stone": Color("6b6b70"),
	&"copper_ore": Color("e07a2c"),
	&"iron_ore": Color("c8ccd8"),
	&"clay": Color("b86a48"),
	&"log": Color("6a4a2a"),
	&"wood_planks": Color("8a6a3a"),
	&"wood_platform": Color("8a6a3a"),
	&"rope": Color("c8b080"),
}
const SKY := Color("9cc8e8")
const CAVE_DIRT := Color("2e2118")
const CAVE_STONE := Color("26262b")
const CAVE_OPEN := Color("141418")
const TREE := Color("1f4a22")
const FLOWER := Color("e070b0")

var _gen: WorldGenerator
var _blocks: TileTypes
var _walls: TileTypes
var _img: Image
var _x0: int
var _y0: int
var _w: int
var _h: int
var _step: int
var _block_colors: PackedColorArray
var _dirt_wall: int
var _lock := Mutex.new()


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var world_seed := int(args.get("seed", "1337"))
	var size_name: String = args.get("size", "small")
	var kind := StringName(args.get("world", "forest"))
	_step = maxi(1, int(args.get("step", "2")))

	var registry: Node = load("res://src/core/registry.gd").new()
	registry.quiet = true
	registry.load_all("res://data")
	_blocks = TileTypes.new(&"tiles", registry)
	_walls = TileTypes.new(&"walls", registry)
	var size: Vector2i = WorldData.SIZES[WorldData.Size.get(size_name.to_upper(), WorldData.Size.SMALL)]
	if kind == &"forest":
		var settings := load("res://data/worldgen/forest.tres") as ForestGenSettings
		_gen = ForestGenerator.new(_blocks, _walls, size.x, size.y, world_seed, settings)
	else:
		_gen = WorldGenerator.create(kind, _blocks, _walls, size.x, size.y, world_seed)
	registry.free()

	var spawn := _gen.spawn_tile()
	_x0 = spawn.x - size.x / 2
	_w = size.x
	if args.has("x"):
		var v: PackedStringArray = (args["x"] as String).split(":")
		_x0 = int(v[0])
		_w = int(v[1])
	var top := spawn.y
	for x in range(0, size.x, 16):
		top = mini(top, _gen.surface_at(x))
	_y0 = top - 60
	_h = spawn.y + 700 - _y0
	if args.has("y"):
		var v: PackedStringArray = (args["y"] as String).split(":")
		_y0 = int(v[0])
		_h = int(v[1])
	_h = mini(_h, size.y - _y0)

	_block_colors.resize(_blocks.size())
	for i in range(1, _blocks.size()):
		_block_colors[i] = COLORS.get(_blocks.def(i).id, Color.MAGENTA)
	_dirt_wall = _walls.index_of(&"dirt_wall")

	var t := Time.get_ticks_msec()
	_img = Image.create_empty(_w / _step, _h / _step, false, Image.FORMAT_RGB8)
	var rows := _img.get_height()
	var task := WorkerThreadPool.add_group_task(_row, rows, -1, true, "preview rows")
	WorkerThreadPool.wait_for_group_task_completion(task)
	_decor()
	var scale := maxi(1, int(args.get("scale", "1")))
	if scale > 1:
		_img.resize(_img.get_width() * scale, _img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var out: String = args.get("out", "user://preview_%d.png" % world_seed)
	_img.save_png(out)
	print("preview_world: %s seed %d, %dx%d tiles from (%d, %d), step %d, %d ms -> %s" % [
		kind, world_seed, _w, _h, _x0, _y0, _step, Time.get_ticks_msec() - t,
		ProjectSettings.globalize_path(out)])
	quit()


## One image row (worker thread). Samples the generator one chunk at a time per column
## run, so per-column work is shared.
func _row(r: int) -> void:
	var y := _y0 + r * _step
	var forest := _gen as ForestGenerator
	var colors := PackedColorArray()
	colors.resize(_img.get_width())
	for c in _img.get_width():
		var x := posmod(_x0 + c * _step, _gen.width)
		var id: int
		var wall: int
		if forest:
			id = forest.block_at(x, y)
			wall = forest.wall_at(x, y)
		else:
			var course := _gen as CourseGenerator
			id = course.block_at(x, y)
			wall = course.wall_at(x, y)
		var col := SKY
		if id > 0:
			col = _block_colors[id]
		elif wall > 0:
			col = CAVE_DIRT if wall == _dirt_wall else CAVE_STONE
		elif y > _gen.surface_at(x):
			col = CAVE_OPEN
		colors[c] = col
	_lock.lock()  # Image isn't thread safe: compute in parallel, write one row at a time.
	for c in colors.size():
		_img.set_pixel(c, r, colors[c])
	_lock.unlock()


func _decor() -> void:
	for c in _img.get_width():
		for k in _step:
			var x := posmod(_x0 + c * _step + k, _gen.width)
			var tree := _gen.tree_at(x)
			var flower := _gen.flower_at(x)
			if tree < 0 and flower < 0:
				continue
			var r := (_gen.surface_at(x) - _y0) / _step
			if tree >= 0:
				for dy in range(1, maxi(2, 14 / _step)):
					if r - dy >= 0:
						_img.set_pixel(c, r - dy, TREE)
			elif r - 1 >= 0:
				_img.set_pixel(c, r - 1, FLOWER)
