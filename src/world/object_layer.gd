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


func _on_chunk_shown(c: Vector2i, _decor: PackedInt32Array, _floors: PackedInt32Array) -> void:
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
			if def and def.display:
				var item := world.displayed_item(origin + Vector2i(lx, ly))
				if item and item.icon:
					var r := world.display_rect(Vector2i(lx, ly), item)
					view.draw_texture_rect(item.icon, r, false)
				continue
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
			var d := def.detail
			var dest := Rect2(x, (ly - h + 1) * TILE, sw, h * TILE)
			var src := Rect2(frame * sw * d, 0, sw * d, h * TILE * d)
			if def.style == ObjectDef.Style.FURNITURE and world.is_flipped(origin + Vector2i(lx, ly)):
				# Placed facing left: mirrored around its footprint.
				view.draw_set_transform(Vector2(dest.position.x * 2.0 + dest.size.x, 0), 0.0, Vector2(-1, 1))
				view.draw_texture_rect_region(def.frames, dest, src)
				view.draw_set_transform(Vector2.ZERO)
			else:
				view.draw_texture_rect_region(def.frames, dest, src)
			if def.fill_look in [ObjectDef.FillLook.BOTTLES, ObjectDef.FillLook.PILE]:
				var store := world.container_at(origin + Vector2i(lx, ly))
				if store and def.fill_look == ObjectDef.FillLook.BOTTLES:
					_draw_bottles(view, dest, store, world.is_flipped(origin + Vector2i(lx, ly)), def)
				elif store:
					_draw_pile(view, dest, store, world.is_flipped(origin + Vector2i(lx, ly)))


## Redraws every shown chunk's objects (a storage's fill changed).
func redraw_all() -> void:
	for v: Node2D in _views.values():
		v.queue_redraw()


## Potion storage: bottles on its shelves (ObjectDef.bottle_shelves, bottom first), as
## many as it is full, each drawn as the bottle it comes in (ItemData.bottle_shape). In
## art pixels of its picture.
func _draw_bottles(view: Node2D, dest: Rect2, inv: Inventory, flip: bool, def: ObjectDef) -> void:
	# Shelf space is counted in spots (bottle_step wide): a big round bottle takes 2,
	# the others 1 (bottle_spots). Each item shows as many bottles as its share of the
	# storage, in spots, then they're set on the shelves left to right, bottom shelf
	# first, a bottle that doesn't fit going to the next shelf.
	var per_shelf := def.bottles_per_shelf
	var total := per_shelf * def.bottle_shelves.size()
	var kinds: Array[ItemData] = []
	var cap := float(inv.stack_cap if inv.stack_cap > 0 else 1)
	for i in inv.size:
		if inv.is_empty(i):
			continue
		var it := ItemData.find(inv.ids[i])
		var room := cap if inv.stack_cap > 0 else float(Inventory.max_stack(inv.ids[i]))
		var share := inv.counts[i] / (room * inv.size)
		var n := maxi(1, roundi(share * total / float(bottle_spots(it))))
		for _k in n:
			kinds.append(it)
	var art_w := dest.size.x * def.detail
	var s := dest.size.x / art_w  # art pixel to world pixel
	var shelf := 0
	var spot := 0
	for it in kinds:
		var w := bottle_spots(it)
		if spot + w > per_shelf:
			shelf += 1
			spot = 0
		if shelf >= def.bottle_shelves.size():
			break
		var x := def.bottle_x0 + (spot + (w - 1) * 0.5) * def.bottle_step
		if flip:
			x = art_w - x
		draw_bottle(view, dest.position + Vector2(x, def.bottle_shelves[shelf]) * s, s, it)
		spot += w


## How many shelf spots a bottle takes: big round ones 2, the rest 1.
static func bottle_spots(it: ItemData) -> int:
	if it and it.bottle_shape in [ItemData.BottleShape.CLAY_LARGE, ItemData.BottleShape.GLASS_LARGE]:
		return 2
	return 1


const CLAY := Color("b5704a")
const CLAY_DARK := Color("7e4b31")
const CLAY_LIGHT := Color("d18a5e")
const CORK := Color("8a5f3c")
const GLASS_RIM := Color(0.55, 0.72, 0.8, 0.95)
const GLASS_EMPTY := Color(0.8, 0.92, 0.98, 0.3)


## One bottle standing on a shelf, `foot` = the middle of its base (world px), `s` =
## world px per art px. Clay: opaque, the contents show as the cork and a band; glass:
## the liquid shows through, with a shine.
static func draw_bottle(view: CanvasItem, foot: Vector2, s: float, it: ItemData) -> void:
	var shape := it.bottle_shape if it else ItemData.BottleShape.NONE
	if shape == ItemData.BottleShape.NONE:
		shape = ItemData.BottleShape.CLAY_THIN
	var contents := it.bottle_contents if it else Color(0, 0, 0, 0)
	var filled := contents.a > 0.0
	# [body width, body height, neck height] in art px per shape.
	var size: Vector3 = {
		ItemData.BottleShape.CLAY_THIN: Vector3(3, 6, 2), ItemData.BottleShape.CLAY_REGULAR: Vector3(4, 7, 2),
		ItemData.BottleShape.CLAY_LARGE: Vector3(8, 7, 2), ItemData.BottleShape.GLASS_THIN: Vector3(2, 6, 2),
		ItemData.BottleShape.GLASS_REGULAR: Vector3(4, 7, 2), ItemData.BottleShape.GLASS_LARGE: Vector3(8, 7, 2),
	}[shape]
	var bw := size.x
	var bh := size.y
	var top := -bh
	var r := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		view.draw_rect(Rect2(foot + Vector2(x, y) * s, Vector2(w, h) * s), c)
	var round_body := shape in [ItemData.BottleShape.CLAY_LARGE, ItemData.BottleShape.GLASS_LARGE]
	var glass := shape >= ItemData.BottleShape.GLASS_THIN
	if glass:
		var liquid := contents if filled else GLASS_EMPTY
		r.call(-bw * 0.5, top, bw, bh, GLASS_RIM)  # the glass
		var fill_top := top + 1 + (1 if filled else 0)
		r.call(-bw * 0.5 + (0.5 if bw > 2 else 0.0), fill_top, bw - (1 if bw > 2 else 0), -fill_top - 0.5, liquid)
		r.call(-bw * 0.5 + 0.5, top + 1, 0.6, minf(2.0, bh - 2), Color(1, 1, 1, 0.75))  # shine
		r.call(-0.5, top - size.z, 1, size.z, GLASS_RIM)  # neck
		r.call(-0.5 if bw <= 2 else -1.0, top - size.z - 1, 1 if bw <= 2 else 2, 1, CORK)
	else:
		r.call(-bw * 0.5, top, bw, bh, CLAY)
		r.call(bw * 0.5 - 1, top, 1, bh, CLAY_DARK)  # shaded side
		r.call(-bw * 0.5, top, 0.6, bh, CLAY_LIGHT)  # lit side
		if round_body:
			r.call(-bw * 0.5, top, 1, 1, Color(0, 0, 0, 0))
			r.call(-bw * 0.5 - 0.5, top + 1, 0.5, bh - 2, CLAY)  # a rounder belly
			r.call(bw * 0.5, top + 1, 0.5, bh - 2, CLAY_DARK)
		r.call(-0.5 if bw <= 3 else -1.0, top - size.z, 1 if bw <= 3 else 2, size.z, CLAY)  # neck
		# What's inside: a colored band and a wax seal on the cork; empty: plain cork.
		if filled:
			r.call(-bw * 0.5, top + bh * 0.4, bw, 1, contents)
		r.call(-1.0, top - size.z - 1, 2, 1, contents if filled else CORK)


## Lumber Rack: staggered rows of 5, 4, 5, 4, 5 ends (23), bottom row first, as many as
## it is full; each item gets its share in slot order. Logs are round ends with a ring,
## wood is square board ends. In art pixels of its 48x48 picture.
func _draw_pile(view: Node2D, dest: Rect2, inv: Inventory, flip: bool) -> void:
	var spots: Array[Vector2] = []
	for row in 5:
		var n := 5 if row % 2 == 0 else 4
		var x0 := 9.0 if row % 2 == 0 else 12.5
		for i in n:
			spots.append(Vector2(x0 + i * 7.0, 38.0 - row * 6.0))
	var kinds: Array[ItemData] = []
	var total := 0.0
	for i in inv.size:
		if inv.is_empty(i):
			continue
		var share := inv.counts[i] / float(maxi(inv.cap_for(inv.ids[i]), 1)) / inv.size
		total += share
		var n := maxi(1, roundi(share * spots.size()))
		for _k in n:
			kinds.append(ItemData.find(inv.ids[i]))
	var shown := mini(kinds.size(), maxi(roundi(total * spots.size()), 1 if total > 0.0 else 0))
	var s := dest.size.x / 48.0
	for b in mini(shown, spots.size()):
		var p := spots[b]
		if flip:
			p.x = 48.0 - p.x
		var at := dest.position + p * s
		var c := shelf_color(kinds[b])
		var dark := c.darkened(0.45)
		if kinds[b] and String(kinds[b].id).ends_with("log"):
			view.draw_circle(at, 3.4 * s, dark)
			view.draw_circle(at, 2.6 * s, c)
			view.draw_arc(at, 1.4 * s, 0.0, TAU, 10, dark, 0.5 * s)
			view.draw_rect(Rect2(at - Vector2(0.5, 0.5) * s, Vector2(1, 1) * s), dark)
		else:
			view.draw_rect(Rect2(at - Vector2(3.2, 2.8) * s, Vector2(6.4, 5.6) * s), dark)
			view.draw_rect(Rect2(at - Vector2(2.6, 2.2) * s, Vector2(5.2, 4.4) * s), c)
			view.draw_line(at + Vector2(-2.6, 0) * s, at + Vector2(2.6, 0) * s, dark, 0.5 * s)


static var _shelf_colors: Dictionary[StringName, Color] = {}


## The color an item shows as in a cabinet: its shelf_color, else the most colorful
## pixels of its icon.
static func shelf_color(it: ItemData) -> Color:
	if it == null:
		return Color.GRAY
	if it.shelf_color.a > 0.0:
		return it.shelf_color
	if _shelf_colors.has(it.id):
		return _shelf_colors[it.id]
	var c := Color(0.6, 0.6, 0.6)
	if it.icon:
		var img := it.icon.get_image()
		var best := 0.0
		var sum := Color(0, 0, 0, 0)
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				if p.a > 0.5 and p.s > 0.45 and p.v > 0.35:
					sum += p
					best += 1.0
		if best > 0.0:
			c = Color(sum.r / best, sum.g / best, sum.b / best)
	_shelf_colors[it.id] = c
	return c


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
			if def.fill_look == ObjectDef.FillLook.FRAMES:
				var inv := world.container_at(tile)
				return roundi((inv.fill() if inv else 0.0) * 10.0)  # 0% to 100% in 10% steps
			return def.frame
	return 0
