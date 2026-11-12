class_name ChunkRenderer
extends Node2D
## Draws the world as one pair of TileMapLayers (walls behind, blocks in front) per
## loaded chunk. Only chunks near the camera exist as nodes, so draw and collision
## cost stays flat however big the world is.
##
## Chunk coordinates here are UNWRAPPED: they keep counting past the world's edges
## (x = -1, x = chunks_x + 3, ...). The data behind them wraps, which is what makes
## the seam invisible: near the edge, chunks from the other side are simply drawn
## next to the camera.

const BLOCKS_TEXTURE := "res://assets/tiles/blocks.png"
const WALLS_TEXTURE := "res://assets/tiles/walls.png"
const TILE := 16
const VARIANTS := 3
const MASK_COLUMNS := 16 * VARIANTS
var _square := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
var _platform_shape := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -3), Vector2(-8, -3)])
const NEIGHBORS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # bits 1, 2, 4, 8

class ChunkView:
	var node: Node2D
	var walls: TileMapLayer
	var blocks: TileMapLayer

## Chunks loaded around the camera, in each direction.
var load_radius := Vector2i(2, 2)
## Max chunks built per frame (spreads the cost when moving fast).
var chunks_per_frame := 2

var _world: World
var _data: WorldData
var _block_set: TileSet
var _wall_set: TileSet
var _views: Dictionary[Vector2i, ChunkView] = {}
var _pending: Array[Vector2i] = []
var _chunk_px := float(ChunkData.SIZE * TILE)


func setup(world: World) -> void:
	_world = world
	_data = world.data
	_block_set = _build_tileset(BLOCKS_TEXTURE, world.blocks, true)
	_wall_set = _build_tileset(WALLS_TEXTURE, world.walls, false)


func loaded_count() -> int:
	return _views.size()


## Loads/unloads chunks around `center` (world pixels), within the per-frame budget.
func update(center: Vector2) -> void:
	var cc := _chunk_at(center)
	for dy in range(-load_radius.y, load_radius.y + 1):
		for dx in range(-load_radius.x, load_radius.x + 1):
			var c := cc + Vector2i(dx, dy)
			if c.y < 0 or c.y >= _data.chunks_y or _views.has(c) or _pending.has(c):
				continue
			_pending.append(c)
	for c: Vector2i in _views.keys():
		if absi(c.x - cc.x) > load_radius.x + 1 or absi(c.y - cc.y) > load_radius.y + 1:
			_unload(c)
	_pending = _pending.filter(func(c: Vector2i) -> bool:
		return absi(c.x - cc.x) <= load_radius.x + 1 and absi(c.y - cc.y) <= load_radius.y + 1)
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - cc).length_squared() < (b - cc).length_squared())
	for i in mini(chunks_per_frame, _pending.size()):
		_load(_pending.pop_front())


## Loads everything around `center` right now (used at spawn so the player never
## starts above an empty world).
func load_all_now(center: Vector2) -> void:
	var budget := chunks_per_frame
	chunks_per_frame = 1000
	update(center)
	chunks_per_frame = budget


func clear() -> void:
	for c: Vector2i in _views.keys():
		_unload(c)
	_pending.clear()


## Redraws a tile and its 4 neighbors in every loaded copy (masks may change).
func refresh_tile(tile: Vector2i) -> void:
	_repaint(tile)
	for d: Vector2i in NEIGHBORS:
		_repaint(tile + d)


func _chunk_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _chunk_px), floori(p.y / _chunk_px))


func _load(c: Vector2i) -> void:
	var view := ChunkView.new()
	view.node = Node2D.new()
	view.node.name = "Chunk_%d_%d" % [c.x, c.y]
	view.node.position = Vector2(c) * _chunk_px
	view.walls = TileMapLayer.new()
	view.walls.tile_set = _wall_set
	view.walls.collision_enabled = false
	view.blocks = TileMapLayer.new()
	view.blocks.tile_set = _block_set
	view.node.add_child(view.walls)
	view.node.add_child(view.blocks)
	var origin := c * ChunkData.SIZE
	for ly in ChunkData.SIZE:
		for lx in ChunkData.SIZE:
			_paint(view, Vector2i(lx, ly), origin + Vector2i(lx, ly))
	add_child(view.node)
	_views[c] = view


func _unload(c: Vector2i) -> void:
	var view: ChunkView = _views[c]
	view.node.queue_free()
	_views.erase(c)


func _repaint(tile: Vector2i) -> void:
	if not _data.in_bounds_y(tile.y):
		return
	var wx := _data.wrap_x(tile.x)
	var cy := tile.y / ChunkData.SIZE
	for c: Vector2i in _views:
		if c.y != cy:
			continue
		var lx := posmod(wx - c.x * ChunkData.SIZE, _data.width)
		if lx < ChunkData.SIZE:
			var local := Vector2i(lx, tile.y - cy * ChunkData.SIZE)
			_paint(_views[c], local, c * ChunkData.SIZE + local)


func _paint(view: ChunkView, local: Vector2i, tile: Vector2i) -> void:
	var variant := _variant(tile)
	var id := _data.get_block(tile.x, tile.y)
	if id <= 0:
		view.blocks.erase_cell(local)
	else:
		var mask := 0
		for i in 4:
			var n: Vector2i = tile + NEIGHBORS[i]
			if _world.blocks.connects(id, _data.get_block(n.x, n.y)):
				mask |= 1 << i
		view.blocks.set_cell(local, 0, Vector2i(mask * VARIANTS + variant, _world.blocks.atlas_row(id)))
	var wall := _data.get_wall(tile.x, tile.y)
	if wall <= 0:
		view.walls.erase_cell(local)
	else:
		var wmask := 0
		for i in 4:
			var n: Vector2i = tile + NEIGHBORS[i]
			if _data.get_wall(n.x, n.y) > 0 or not _data.in_bounds_y(n.y):
				wmask |= 1 << i
		view.walls.set_cell(local, 0, Vector2i(wmask * VARIANTS + variant, _world.walls.atlas_row(wall)))


func _variant(tile: Vector2i) -> int:
	return int(GenUtil.hash01(_data.wrap_x(tile.x), tile.y, 77) * VARIANTS)


func _build_tileset(path: String, types: TileTypes, physics: bool) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	if physics:
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, 1)  # "world"
		ts.set_physics_layer_collision_mask(0, 0)
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(1, 2)  # "platforms"
		ts.set_physics_layer_collision_mask(1, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load(path) as Texture2D
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var rows := src.texture.get_height() / TILE
	for row in rows:
		var collision := types.collision_for_row(row)
		for col in MASK_COLUMNS:
			var coords := Vector2i(col, row)
			src.create_tile(coords)
			if not physics:
				continue
			var td := src.get_tile_data(coords, 0)
			if collision == TileDef.Collision.SOLID:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, _square)
			elif collision == TileDef.Collision.PLATFORM:
				td.add_collision_polygon(1)
				td.set_collision_polygon_points(1, 0, _platform_shape)
				td.set_collision_polygon_one_way(1, 0, true)
	return ts
