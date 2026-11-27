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

## Colors of the short rope joining two ropes side by side.
const ROPE_JOIN := Color(200 / 255.0, 176 / 255.0, 128 / 255.0)
const ROPE_JOIN_DARK := Color(154 / 255.0, 132 / 255.0, 86 / 255.0)

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
			if def.style == ObjectDef.Style.ROPE and world.data.get_object(origin.x + lx + 1, origin.y + ly) == id:
				# Ropes side by side join: a short rope across to the next one.
				var y := ly * TILE + TILE * 0.5 - 1.0
				view.draw_rect(Rect2(lx * TILE + TILE * 0.5, y, TILE, 1.0), ROPE_JOIN)
				view.draw_rect(Rect2(lx * TILE + TILE * 0.5, y + 1.0, TILE, 0.5), ROPE_JOIN_DARK)
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
			if def.fill_look >= ObjectDef.FillLook.BOTTLES:
				var store := world.container_at(origin + Vector2i(lx, ly))
				var flip := world.is_flipped(origin + Vector2i(lx, ly))
				if store and def.fill_look == ObjectDef.FillLook.BOTTLES:
					_draw_bottles(view, dest, store, flip, def)
				elif store and def.fill_look == ObjectDef.FillLook.PILE:
					_draw_pile(view, dest, store, flip)
				elif store and def.fill_look == ObjectDef.FillLook.BOOKS:
					_draw_books(view, dest, store, flip, def)
				elif store and def.fill_look == ObjectDef.FillLook.NET:
					_draw_net(view, dest, store, flip, def)
			if def.front_frame >= 0:
				# Drawn over what's inside (glass doors, a net's mesh).
				var over := Rect2(def.front_frame * sw * d, 0, sw * d, h * TILE * d)
				if def.style == ObjectDef.Style.FURNITURE and world.is_flipped(origin + Vector2i(lx, ly)):
					view.draw_set_transform(Vector2(dest.position.x * 2.0 + dest.size.x, 0), 0.0, Vector2(-1, 1))
					view.draw_texture_rect_region(def.frames, dest, over)
					view.draw_set_transform(Vector2.ZERO)
				else:
					view.draw_texture_rect_region(def.frames, dest, over)


## Redraws every shown chunk's objects (a storage's fill changed).
func redraw_all() -> void:
	for v: Node2D in _views.values():
		v.queue_redraw()


## Potion storage: bottles on its shelves (ObjectDef.bottle_shelves, bottom first), as
## many as it is full, each drawn as the bottle it comes in (ItemData.bottle_shape). In
## art pixels of its picture.
func _draw_bottles(view: Node2D, dest: Rect2, inv: Inventory, flip: bool, def: ObjectDef) -> void:
	# Each bottle is its item's shelf sprite (ItemData.shelf_sprite, else its icon at half
	# size), standing on the shelves left to right, bottom shelf first, 1 art px apart; a
	# bottle that doesn't fit goes to the next shelf. Each item shows as many bottles as
	# its share of the storage takes of the shelf width.
	var shelf_w := float(def.bottles_per_shelf) * def.bottle_step
	var total := shelf_w * def.bottle_shelves.size()
	var kinds: Array[ItemData] = []
	for i in inv.size:
		if inv.is_empty(i):
			continue
		var it := ItemData.find(inv.ids[i])
		var tex := shelf_texture(it)
		if tex == null:
			continue
		var room := float(inv.cap_for(inv.ids[i]))
		var share := inv.counts[i] / (maxf(room, 1.0) * inv.size)
		var n := maxi(1, roundi(share * total / (tex.get_width() + 1.0)))
		for _k in n:
			kinds.append(it)
	var art_w := dest.size.x * def.detail
	var s := dest.size.x / art_w  # art pixel to world pixel
	var shelf := 0
	var x := 0.0
	for it in kinds:
		var tex := shelf_texture(it)
		var size := Vector2(tex.get_size())
		if x > 0.0 and x + size.x > shelf_w:
			shelf += 1
			x = 0.0
		if shelf >= def.bottle_shelves.size():
			break
		# Too tall for the room up to the shelf above (its plank, 2 px, and 1 px air):
		# shrunk to fit, so caps don't poke through.
		var room := shelf_room(def, shelf)
		if size.y > room:
			tex = shelf_texture(it, int(room))
			size = Vector2(tex.get_size())
		var left := def.bottle_x0 + x
		if flip:
			left = art_w - left - size.x
		var at := Vector2(left, def.bottle_shelves[shelf] - size.y)
		view.draw_texture_rect(tex, Rect2(dest.position + at * s, size * s), false)
		x += size.x + 1.0


static var _shelf_cache: Dictionary[StringName, Texture2D] = {}


## Art px of room above a shelf: up to the next shelf's plank (2 px thick) less 1 px of
## air; the top shelf up to the inside of the top (5 px down).
static func shelf_room(def: ObjectDef, shelf: int) -> float:
	var y := def.bottle_shelves[shelf]
	var above := def.bottle_shelves[shelf + 1] + 2 if shelf + 1 < def.bottle_shelves.size() else 5
	return float(y - above - 1)


## How an item looks standing on a shelf: its `shelf_sprite` if it has one, else its icon
## cropped to the picture and halved (each 2x2 block keeps its most solid pixel, so
## outlines survive). Cached. Null for items with no icon.
static func shelf_texture(it: ItemData, max_h: int = 0) -> Texture2D:
	if it == null:
		return null
	if max_h > 0:
		# A shorter copy (nearest, keeping the width in proportion), cached by height.
		var key := StringName("%s@%d" % [it.id, max_h])
		if _shelf_cache.has(key):
			return _shelf_cache[key]
		var full := shelf_texture(it)
		var out: Texture2D = full
		if full and full.get_height() > max_h:
			var img := full.get_image()
			var k := float(max_h) / full.get_height()
			img.resize(maxi(1, roundi(img.get_width() * k)), max_h, Image.INTERPOLATE_NEAREST)
			out = ImageTexture.create_from_image(img)
		_shelf_cache[key] = out
		return out
	if it.shelf_sprite:
		return it.shelf_sprite
	if _shelf_cache.has(it.id):
		return _shelf_cache[it.id]
	var out: Texture2D = null
	if it.icon:
		var img := it.icon.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var used := img.get_used_rect()
			if used.size.x > 0:
				img = img.get_region(used)
				if it.icon.get_width() <= 16:
					# A 16x16 icon is already at the furniture's art size (2 art px per
					# world px vs the icon's 1): used as is.
					out = ImageTexture.create_from_image(img)
					_shelf_cache[it.id] = out
					return out
				var half := Vector2i(maxi(1, (used.size.x + 1) / 2), maxi(1, (used.size.y + 1) / 2))
				var small := Image.create_empty(half.x, half.y, false, Image.FORMAT_RGBA8)
				for y in half.y:
					for x in half.x:
						var best := Color(0, 0, 0, 0)
						for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
							var px := Vector2i(x * 2, y * 2) + d
							if px.x < img.get_width() and px.y < img.get_height():
								var c := img.get_pixelv(px)
								if c.a > best.a + 0.01:
									best = c
						small.set_pixel(x, y, best)
				out = ImageTexture.create_from_image(small)
	_shelf_cache[it.id] = out
	return out


## How many of an item to show: its share of the storage times `room` (art px or
## spots), over `each` (what one takes), at least 1.
static func _shown(inv: Inventory, slot: int, room: float, each: float) -> int:
	var cap := float(maxi(inv.cap_for(inv.ids[slot]), 1))
	return maxi(1, roundi(inv.counts[slot] / (cap * inv.size) * room / maxf(each, 1.0)))


## Bookshelf: books as spines (2 to 4 art px wide, 10 to 14 tall, in their icon's main
## color) on the upper shelves, left to right; scrolls, pages and paper as their shelf
## sprites on the bottom shelf (the drawer).
func _draw_books(view: Node2D, dest: Rect2, inv: Inventory, flip: bool, def: ObjectDef) -> void:
	var art_w := dest.size.x * def.detail
	var s := dest.size.x / art_w
	var shelf_w := float(def.bottles_per_shelf) * def.bottle_step
	var upper := def.bottle_shelves.size() - 1
	var books: Array[ItemData] = []
	var papers: Array[ItemData] = []
	for i in inv.size:
		if inv.is_empty(i):
			continue
		var it := ItemData.find(inv.ids[i])
		if it == null:
			continue
		if it.kind in [ItemData.Kind.BOOK, ItemData.Kind.TOME]:
			for _k in _shown(inv, i, shelf_w * upper, 4.0):
				books.append(it)
		elif shelf_texture(it):
			for _k in _shown(inv, i, shelf_w, 9.0):
				papers.append(it)
	var place := func(x: float, w: float) -> float:
		return art_w - x - w if flip else x
	# Books: upper shelves, bottom one up.
	var shelf := 1
	var x := 0.0
	var n := 0
	for it in books:
		var seed := absi(hash(String(it.id))) + n
		n += 1
		var w := 2.0 + float(seed % 3)
		var h := 10.0 + float((seed / 3) % 5)
		if x + w > shelf_w:
			shelf += 1
			x = 0.0
		if shelf >= def.bottle_shelves.size():
			break
		var c := icon_color(it)
		# Each copy a little lighter or darker, so a row of the same book reads as books.
		c = c.lightened(0.12) if seed % 3 == 0 else (c.darkened(0.12) if seed % 3 == 1 else c)
		var left: float = place.call(def.bottle_x0 + x, w)
		var top := def.bottle_shelves[shelf] - h
		view.draw_rect(Rect2(dest.position + Vector2(left, top) * s, Vector2(w, h) * s), c.darkened(0.15))
		view.draw_rect(Rect2(dest.position + Vector2(left, top + 2) * s, Vector2(w, 1) * s), c.lightened(0.35))
		view.draw_rect(Rect2(dest.position + Vector2(left, top + h - 3) * s, Vector2(w, 1) * s), c.lightened(0.35))
		var edge: float = place.call(def.bottle_x0 + x + w - 1.0, 1.0)
		view.draw_rect(Rect2(dest.position + Vector2(edge, top) * s, Vector2(1, h) * s), c.darkened(0.45))
		x += w
	# Papers: the drawer.
	x = 0.0
	for it in papers:
		var tex := shelf_texture(it)
		var size := Vector2(tex.get_size())
		if x + size.x > shelf_w:
			break
		var left: float = place.call(def.bottle_x0 + x, size.x)
		view.draw_texture_rect(tex, Rect2(dest.position + Vector2(left, def.bottle_shelves[0] - size.y) * s, size * s), false)
		x += size.x * 0.6  # overlapping, like a stack in a drawer


## Hanging net: what's inside heaped in its bag (ObjectDef.net_bag), bottom row first,
## items overlapping a little, each as its shelf sprite.
func _draw_net(view: Node2D, dest: Rect2, inv: Inventory, flip: bool, def: ObjectDef) -> void:
	var art_w := dest.size.x * def.detail
	var s := dest.size.x / art_w
	var bag := def.net_bag
	var items: Array[ItemData] = []
	for i in inv.size:
		if inv.is_empty(i):
			continue
		var it := ItemData.find(inv.ids[i])
		if shelf_texture(it):
			for _k in _shown(inv, i, float(bag.size.x) * maxf(bag.size.y / 6.0, 1.0), 8.0):
				items.append(it)
	var x := 0.0
	var floor_y := float(bag.end.y)
	var row_h := 0.0
	for it in items:
		var tex := shelf_texture(it)
		var size := Vector2(tex.get_size())
		if x + size.x > bag.size.x:
			x = 0.0
			floor_y -= maxf(row_h * 0.55, 3.0)
			row_h = 0.0
		if floor_y - size.y * 0.5 < bag.position.y:
			break
		var left := float(bag.position.x) + x
		if flip:
			left = art_w - left - size.x
		view.draw_texture_rect(tex, Rect2(dest.position + Vector2(left, floor_y - size.y) * s, size * s), false)
		x += size.x * 0.75
		row_h = maxf(row_h, size.y)


static var _icon_colors: Dictionary[StringName, Color] = {}


## An item's main color (its icon's average opaque pixel), for book spines. Cached.
static func icon_color(it: ItemData) -> Color:
	if _icon_colors.has(it.id):
		return _icon_colors[it.id]
	var c := Color(0.45, 0.3, 0.2)
	if it.shelf_color.a > 0.0:
		c = it.shelf_color
	elif it.icon:
		var img := it.icon.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var sum := Vector3.ZERO
			var count := 0
			for y in img.get_height():
				for x2 in img.get_width():
					var p := img.get_pixel(x2, y)
					if p.a > 0.5 and p.get_luminance() > 0.12:
						sum += Vector3(p.r, p.g, p.b)
						count += 1
			if count > 0:
				sum /= count
				c = Color(sum.x, sum.y, sum.z)
	_icon_colors[it.id] = c
	return c


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
