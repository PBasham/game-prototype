class_name WorldMap
extends Node
## The world map (like Terraria's): what you've explored, one pixel per CELL x CELL
## tiles. Places within `reveal_tiles` of the player are revealed as you go (and redrawn,
## so digging shows up). The picture is an Image the map screen (MapView) shows; which
## cells are explored is saved with the world (WorldSave.META_MAP, as the picture).
## Colors: a block's color is the average of its terrain texture, a wall's the same but
## darker; open space above the original surface is sky, below it a dark cave color.

const CELL := 2
const SKY := Color("8fbfe0")
const CAVE := Color("17151a")
const TREE := Color("2c5a2e")
const DARK_TREE := Color("3e2a44")
## Water (voxel cells): drawn over the wall or sky behind it.
const WATER := Color("2f6fc0")

## How far around the player (tiles) the map fills in.
@export var reveal_tiles := 48.0
## How often (seconds) it looks around.
@export var reveal_every := 0.4

var world: World
## Map size in cells, and the picture (unexplored cells are transparent).
var size := Vector2i.ZERO
var image: Image
var _block_colors: Array[Color] = []
var _wall_colors: Array[Color] = []
var _left := 0.0
## The picture changed since the map screen last copied it.
var dirty := true


func setup(w: World) -> void:
	world = w
	size = Vector2i(ceili(w.data.width / float(CELL)), ceili(w.data.height / float(CELL)))
	image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	_block_colors = _colors(w.blocks, 1.0)
	_wall_colors = _colors(w.walls, 0.55)


## Average color of each tile kind's terrain texture (index -> color).
static func _colors(types: TileTypes, shade: float) -> Array[Color]:
	var out: Array[Color] = [Color.TRANSPARENT]
	for i in range(1, types.size()):
		var d := types.def(i)
		var c := Color(0.5, 0.45, 0.4)
		if d and d.terrain != "":
			var tex := load("res://assets/terrain/%s.png" % d.terrain) as Texture2D
			if tex:
				var img := tex.get_image()
				if img.is_compressed():
					img.decompress()
				img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
				c = img.get_pixel(0, 0)
				c.a = 1.0
		out.append(Color(c.r * shade, c.g * shade, c.b * shade, 1.0))
	return out


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = reveal_every
	reveal_around(world.world_to_tile(world.player.chest()), reveal_tiles)


## Reveals (and redraws) every cell within `radius` tiles of `tile`.
func reveal_around(tile: Vector2i, radius: float) -> void:
	var c := Vector2i(floori(tile.x / float(CELL)), floori(tile.y / float(CELL)))
	var r := ceili(radius / CELL)
	for dy in range(-r, r + 1):
		var cy := c.y + dy
		if cy < 0 or cy >= size.y:
			continue
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var cx := posmod(c.x + dx, size.x)
			image.set_pixel(cx, cy, cell_color(cx, cy))
	dirty = true


## The color of one map cell from what's in it now.
func cell_color(cx: int, cy: int) -> Color:
	var x0 := cx * CELL
	var y0 := cy * CELL
	var wall := 0
	for dy in CELL:
		for dx in CELL:
			var b := world.data.get_block(x0 + dx, y0 + dy)
			if b > 0 and b < _block_colors.size():
				return _block_colors[b]
			if wall == 0:
				wall = world.data.get_wall(x0 + dx, y0 + dy)
	var water := 0
	if world.voxels:
		for dy in CELL:
			for dx in CELL:
				water += world.voxels.count_in(Vector2i(x0 + dx, y0 + dy), &"water")
	if water * 2 >= CELL * CELL * VoxelLayer.CELLS:
		var behind := _wall_colors[wall] if wall > 0 and wall < _wall_colors.size() else WATER
		return WATER.lerp(behind, 0.2)
	if wall > 0 and wall < _wall_colors.size():
		return _wall_colors[wall]
	var surface := world.generator.surface_at(posmod(x0, world.data.width)) if world.generator else 0
	return SKY if y0 < surface else CAVE


func is_explored(cx: int, cy: int) -> bool:
	return image.get_pixel(cx, cy).a > 0.0


## Share of the world explored (0 to 1), for the map's corner.
func explored_share() -> float:
	var n := 0
	var data := image.get_data()
	for i in range(3, data.size(), 4):
		if data[i] > 0:
			n += 1
	return n / float(maxi(size.x * size.y, 1))


## The picture itself is what's saved (explored = not transparent), so loading never
## has to generate far chunks to redraw it.
func to_dict() -> Dictionary:
	return {"w": size.x, "h": size.y, "png": image.save_png_to_buffer()}


func from_dict(d: Dictionary) -> void:
	if d.is_empty() or int(d.get("w", 0)) != size.x or int(d.get("h", 0)) != size.y:
		return
	var img := Image.new()
	if img.load_png_from_buffer(d["png"]) != OK or img.get_size() != size:
		return
	img.convert(Image.FORMAT_RGBA8)
	image = img
	dirty = true
