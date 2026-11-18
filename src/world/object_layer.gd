class_name ObjectLayer
extends Node2D
## Draws tile objects (rope, torches; data/objects) for the loaded chunks: one node per
## chunk that draws its objects, redrawn when one changes. In front of the terrain,
## behind the player.
##
## Frames come from each ObjectDef's `frames` strip (8x8 frames):
##   rope:      single, top, middle, bottom (from the rope above and below)
##   torch:     standing, on a block to the left, to the right, on a back wall
##   furniture: one frame (ObjectDef.frame) covering its whole footprint, drawn from
##              its anchor (bottom-left tile); fillers draw nothing
## Furniture that blocks movement (a closed door) gets a collision box here.

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
	_sync_bodies(view)


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
		if lx >= -3 and lx <= SIZE + 2 and ly >= -1 and ly <= SIZE + 8:
			_views[c].queue_redraw()
			if lx >= 0 and lx < SIZE and ly >= 0 and ly < SIZE:
				_sync_bodies(_views[c])


## Collision boxes for the chunk's closed doors (and anything else that blocks).
func _sync_bodies(view: ChunkObjects) -> void:
	for child in view.get_children():
		child.queue_free()
	var c := Vector2i(posmod(view.coord.x, world.data.chunks_x), view.coord.y)
	var chunk := world.data.peek_chunk(c)
	if chunk == null:
		return
	for li in chunk.objects.size():
		var id := chunk.objects[li]
		if id <= 0:
			continue
		var def := world.objects.def(id) as ObjectDef
		if def == null or not def.blocks_movement:
			continue
		var lx := li % SIZE
		var ly := li / SIZE
		var body := StaticBody2D.new()
		body.collision_layer = 1  # "world", like solid blocks
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(def.width_tiles * TILE, def.height_tiles * TILE)
		shape.shape = rect
		shape.position = Vector2(lx * TILE, (ly - def.height_tiles + 1) * TILE) + rect.size * 0.5
		body.add_child(shape)
		view.add_child(body)


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
			var w := maxi(def.width_tiles, 1) if def.style == ObjectDef.Style.FURNITURE else 1
			# Taller objects grow upward from their tile; furniture also rightward. A sprite
			# wider than its footprint is centered on it.
			var sw := def.sprite_width_px if def.sprite_width_px > 0 else w * TILE
			var x := lx * TILE + (w * TILE - sw) / 2
			if def.sprite_align == ObjectDef.SpriteAlign.FROM_LEFT:
				x = lx * TILE
			elif def.sprite_align == ObjectDef.SpriteAlign.FROM_RIGHT:
				x = lx * TILE + w * TILE - sw
			view.draw_texture_rect_region(def.frames, Rect2(x, (ly - h + 1) * TILE, sw, h * TILE),
				Rect2(frame * sw, 0, sw, h * TILE))


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
		ObjectDef.Style.FURNITURE:
			return def.frame
	return 0
