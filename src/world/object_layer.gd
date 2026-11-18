class_name ObjectLayer
extends Node2D
## Draws tile objects (rope, torches; data/objects) for the loaded chunks: one node per
## chunk that draws its objects, redrawn when one changes. In front of the terrain,
## behind the player.
##
## Frames come from each ObjectDef's `frames` strip (8x8 frames):
##   rope:  single, top, middle, bottom (from the rope above and below)
##   torch: standing, on a block to the left, to the right, on a back wall

const TILE := World.TILE
const SIZE := ChunkData.SIZE

var world: World
## Unwrapped chunk coord -> its drawing node.
var _views: Dictionary[Vector2i, ChunkObjects] = {}


class ChunkObjects extends Node2D:
	var layer: ObjectLayer
	var coord: Vector2i

	func _draw() -> void:
		layer.draw_chunk(self)


func setup(w: World) -> void:
	world = w
	world.renderer.chunk_shown.connect(_on_chunk_shown)
	world.renderer.chunk_hidden.connect(_on_chunk_hidden)
	world.object_changed.connect(_on_changed)
	world.block_changed.connect(_on_changed)
	world.wall_changed.connect(_on_changed)


func _on_chunk_shown(c: Vector2i, _decor: PackedInt32Array) -> void:
	var view := ChunkObjects.new()
	view.layer = self
	view.coord = c
	view.position = Vector2(c * SIZE * TILE)
	add_child(view)
	_views[c] = view


func _on_chunk_hidden(c: Vector2i) -> void:
	var view: ChunkObjects = _views.get(c)
	if view:
		view.queue_free()
		_views.erase(c)


## Redraws the chunks around a changed tile (frames depend on neighbors).
func _on_changed(tile: Vector2i, _old: int, _new: int) -> void:
	var wx := world.data.wrap_x(tile.x)
	for c: Vector2i in _views:
		var lx := posmod(wx - c.x * SIZE + 1, world.data.width) - 1
		var ly := tile.y - c.y * SIZE
		if lx >= -1 and lx <= SIZE and ly >= -1 and ly <= SIZE:
			_views[c].queue_redraw()


func draw_chunk(view: ChunkObjects) -> void:
	var c := Vector2i(posmod(view.coord.x, world.data.chunks_x), view.coord.y)
	var chunk := world.data.peek_chunk(c)
	if chunk == null:
		return
	var origin := view.coord * SIZE
	for ly in SIZE:
		for lx in SIZE:
			var id := chunk.objects[ly * SIZE + lx]
			if id <= 0:
				continue
			var def := world.objects.def(id) as ObjectDef
			if def == null or def.frames == null:
				continue
			var frame := frame_for(def, origin + Vector2i(lx, ly), id)
			var h := maxi(def.height_tiles, 1)
			# Taller objects grow upward from their tile.
			view.draw_texture_rect_region(def.frames, Rect2(lx * TILE, (ly - h + 1) * TILE, TILE, h * TILE),
				Rect2(frame * TILE, 0, TILE, h * TILE))


## Which frame of the strip an object shows at a tile.
func frame_for(def: ObjectDef, tile: Vector2i, id: int) -> int:
	match def.style:
		ObjectDef.Style.ROPE:
			var up := world.data.get_object(tile.x, tile.y - 1) == id
			var down := world.data.get_object(tile.x, tile.y + 1) == id
			if up and down:
				return 2
			if down:
				return 1
			if up:
				return 3
			return 0
		ObjectDef.Style.TORCH:
			if world.is_solid(tile + Vector2i.DOWN):
				return 0
			if world.is_solid(tile + Vector2i.LEFT):
				return 1
			if world.is_solid(tile + Vector2i.RIGHT):
				return 2
			return 3
	return 0
