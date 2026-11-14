class_name ChunkRenderer
extends Node2D
## Draws loaded chunks. Each chunk is:
## - a terrain sprite drawn by terrain.gdshader (smooth edges, blending, grass, walls),
## - a hidden TileMapLayer that only provides collision,
## - a visible TileMapLayer for thin tiles (platforms, ropes),
## - decorations (trees, flowers) on grassy surfaces.
## Only chunks near the camera exist, so cost stays flat however big the world is.
##
## Chunk coordinates here are UNWRAPPED: they keep counting past the world's edges.
## The data behind them wraps, so the seam is invisible.

## Emitted when the set of loaded chunks changes (lighting listens).
signal chunks_changed

const TILE := 8
const BORDER := 2
const TEX_SIZE := ChunkData.SIZE + BORDER * 2
const PIECES := 64
const MATERIAL_TEX := 64
const BLOCKS_ATLAS := "res://assets/tiles/blocks.png"
const TERRAIN_DIR := "res://assets/terrain"
const SHADER := preload("res://src/world/terrain.gdshader")
const NEIGHBORS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # mask bits 1, 2, 4, 8
## Grass palette from Patrick's reference art (darkest to lightest).
const GRASS_COLORS := ["1f5212", "2b7018", "349a20", "42a628", "4fb52f", "5cbf3a"]

class ChunkView:
	var node: Node2D
	var terrain: Sprite2D
	var tile_image: Image
	var tile_texture: ImageTexture
	var collision: TileMapLayer
	var props: TileMapLayer
	var decor: Node2D
	var dirty := false

## Chunks loaded around the camera, in each direction.
var load_radius := Vector2i(2, 2)
## Max chunks built per frame (spreads the cost when moving fast).
var chunks_per_frame := 2

var _world: World
var _data: WorldData
var _views: Dictionary[Vector2i, ChunkView] = {}
var _pending: Array[Vector2i] = []
var _chunk_px := float(ChunkData.SIZE * TILE)
var _block_slot := PackedInt32Array()
var _wall_slot := PackedInt32Array()
var _stone_slot := 0
var _material: ShaderMaterial
var _collision_set: TileSet
var _props_set: TileSet
var _trees: Array[Texture2D] = []
var _flowers: Array[Texture2D] = []


func setup(world: World) -> void:
	_world = world
	_data = world.data
	_build_terrain_material()
	_collision_set = _build_tileset(true)
	_props_set = _build_tileset(false)
	for kind in ["green", "olive", "teal", "gold"]:
		for i in 3:
			_trees.append(load("res://assets/trees/pine_%s_%d.png" % [kind, i]) as Texture2D)
	for i in 5:
		_flowers.append(load("res://assets/decor/flower_%d.png" % i) as Texture2D)


func loaded_count() -> int:
	return _views.size()


## Tile rectangle (unwrapped coords) covered by loaded chunks.
func loaded_tile_rect() -> Rect2i:
	if _views.is_empty():
		return Rect2i()
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for c: Vector2i in _views:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Rect2i(lo * ChunkData.SIZE, (hi - lo + Vector2i.ONE) * ChunkData.SIZE)


## Loads/unloads chunks around `center` (world pixels), within the per-frame budget.
func update(center: Vector2) -> void:
	var cc := _chunk_at(center)
	for dy in range(-load_radius.y, load_radius.y + 1):
		for dx in range(-load_radius.x, load_radius.x + 1):
			var c := cc + Vector2i(dx, dy)
			if c.y < 0 or c.y >= _data.chunks_y or _views.has(c) or _pending.has(c):
				continue
			_pending.append(c)
	var changed := false
	for c: Vector2i in _views.keys():
		if absi(c.x - cc.x) > load_radius.x + 1 or absi(c.y - cc.y) > load_radius.y + 1:
			_unload(c)
			changed = true
	_pending = _pending.filter(func(c: Vector2i) -> bool:
		return absi(c.x - cc.x) <= load_radius.x + 1 and absi(c.y - cc.y) <= load_radius.y + 1)
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - cc).length_squared() < (b - cc).length_squared())
	for i in mini(chunks_per_frame, _pending.size()):
		_load(_pending.pop_front())
		changed = true
	for view: ChunkView in _views.values():
		if view.dirty:
			view.tile_texture.update(view.tile_image)
			view.dirty = false
	if changed:
		chunks_changed.emit()


## Loads everything around `center` right now (used at spawn).
func load_all_now(center: Vector2) -> void:
	var budget := chunks_per_frame
	chunks_per_frame = 1000
	update(center)
	chunks_per_frame = budget


func clear() -> void:
	for c: Vector2i in _views.keys():
		_unload(c)
	_pending.clear()


## Redraws a tile everywhere it appears (including neighbors' borders).
func refresh_tile(tile: Vector2i) -> void:
	if not _data.in_bounds_y(tile.y):
		return
	var wx := _data.wrap_x(tile.x)
	for c: Vector2i in _views:
		var view: ChunkView = _views[c]
		var lx := posmod(wx - c.x * ChunkData.SIZE + BORDER, _data.width) - BORDER
		var ly := tile.y - c.y * ChunkData.SIZE
		if lx < -BORDER or lx >= ChunkData.SIZE + BORDER or ly < -BORDER or ly >= ChunkData.SIZE + BORDER:
			continue
		var world_tile := c * ChunkData.SIZE + Vector2i(lx, ly)
		view.tile_image.set_pixel(lx + BORDER, ly + BORDER, _tile_color(world_tile))
		view.dirty = true
		if lx >= 0 and lx < ChunkData.SIZE and ly >= 0 and ly < ChunkData.SIZE:
			_paint_cells(view, Vector2i(lx, ly), world_tile)
		for d: Vector2i in NEIGHBORS:
			var n := Vector2i(lx, ly) + d
			if n.x >= 0 and n.x < ChunkData.SIZE and n.y >= 0 and n.y < ChunkData.SIZE:
				_paint_cells(view, n, c * ChunkData.SIZE + n)


func _chunk_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _chunk_px), floori(p.y / _chunk_px))


func _load(c: Vector2i) -> void:
	var view := ChunkView.new()
	view.node = Node2D.new()
	view.node.name = "Chunk_%d_%d" % [c.x, c.y]
	view.node.position = Vector2(c) * _chunk_px

	view.tile_image = Image.create_empty(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var origin := c * ChunkData.SIZE
	for ty in TEX_SIZE:
		for tx in TEX_SIZE:
			view.tile_image.set_pixel(tx, ty, _tile_color(origin + Vector2i(tx - BORDER, ty - BORDER)))
	view.tile_texture = ImageTexture.create_from_image(view.tile_image)

	view.terrain = Sprite2D.new()
	view.terrain.texture = view.tile_texture
	view.terrain.centered = false
	view.terrain.region_enabled = true
	view.terrain.region_rect = Rect2(BORDER, BORDER, ChunkData.SIZE, ChunkData.SIZE)
	view.terrain.scale = Vector2(TILE, TILE)
	var mat := _material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("tiles", view.tile_texture)
	mat.set_shader_parameter("origin", Vector2(origin * TILE))
	view.terrain.material = mat

	view.collision = TileMapLayer.new()
	view.collision.tile_set = _collision_set
	view.collision.visible = false
	view.props = TileMapLayer.new()
	view.props.tile_set = _props_set
	view.props.collision_enabled = false
	view.decor = Node2D.new()
	view.decor.z_index = -1

	view.node.add_child(view.decor)
	view.node.add_child(view.terrain)
	view.node.add_child(view.props)
	view.node.add_child(view.collision)
	for ly in ChunkData.SIZE:
		for lx in ChunkData.SIZE:
			_paint_cells(view, Vector2i(lx, ly), origin + Vector2i(lx, ly))
	_add_decor(view, c)
	add_child(view.node)
	_views[c] = view


func _unload(c: Vector2i) -> void:
	var view: ChunkView = _views[c]
	view.node.queue_free()
	_views.erase(c)


## R = block terrain slot, G = wall slot. Below the world counts as stone.
func _tile_color(tile: Vector2i) -> Color:
	var b := _data.get_block(tile.x, tile.y)
	var slot := _stone_slot if b == WorldData.OUT_OF_BOUNDS else (_block_slot[b] if b > 0 else 0)
	var w := _data.get_wall(tile.x, tile.y)
	var wslot := _wall_slot[w] if w > 0 else 0
	return Color(slot / 255.0, wslot / 255.0, 0.0, 1.0)


## Collision cell and, for platforms and ropes, the visible tile.
func _paint_cells(view: ChunkView, local: Vector2i, tile: Vector2i) -> void:
	var id := _data.get_block(tile.x, tile.y)
	var collision := _world.blocks.collision(id) if id > 0 else TileDef.Collision.NONE
	if collision == TileDef.Collision.NONE:
		view.collision.erase_cell(local)
	else:
		view.collision.set_cell(local, 0, Vector2i(0, _world.blocks.atlas_row(id)))
	if id <= 0 or _block_slot[id] > 0:
		view.props.erase_cell(local)
		return
	var mask := 0
	for i in 4:
		var n: Vector2i = tile + NEIGHBORS[i]
		if _data.get_block(n.x, n.y) == id:
			mask |= 1 << i
	var piece := posmod(_data.wrap_x(tile.x), 8) + posmod(tile.y, 8) * 8
	view.props.set_cell(local, 0, Vector2i(mask * PIECES + piece, _world.blocks.atlas_row(id)))


## Trees and flowers on grassy surfaces, from the world generator's decoration rules.
func _add_decor(view: ChunkView, c: Vector2i) -> void:
	var gen := _world.generator
	if gen == null:
		return
	var grass := _world.blocks.index_of(&"grass")
	for lx in ChunkData.SIZE:
		var x := c.x * ChunkData.SIZE + lx
		var wx := _data.wrap_x(x)
		var tree := gen.tree_at(wx)
		var flower := gen.flower_at(wx)
		if tree < 0 and flower < 0:
			continue
		for ly in ChunkData.SIZE:
			var y := c.y * ChunkData.SIZE + ly
			if _data.get_block(x, y) != grass or _data.get_block(x, y - 1) != WorldData.AIR:
				continue
			var tex: Texture2D = _trees[tree % _trees.size()] if tree >= 0 else _flowers[flower % _flowers.size()]
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.position = Vector2(lx * TILE + TILE / 2 - tex.get_width() / 2, ly * TILE + (3 if tree >= 0 else 1) - tex.get_height())
			view.decor.add_child(s)
			break


func _build_terrain_material() -> void:
	var blocks := _world.blocks
	var walls := _world.walls
	var keys: Array[String] = []
	var overlays: Array[String] = []
	var grass := PackedFloat32Array()
	grass.resize(16)
	var built := PackedFloat32Array()
	built.resize(16)
	var built_walls := PackedFloat32Array()
	built_walls.resize(16)
	_block_slot.resize(blocks.size())
	for i in range(1, blocks.size()):
		var def := blocks.def(i)
		if def.terrain.is_empty() or def.collision != TileDef.Collision.SOLID:
			continue
		keys.append(def.terrain)
		overlays.append(def.ore_overlay)
		_block_slot[i] = keys.size()
		grass[keys.size()] = 1.0 if def.grass_cover else 0.0
		built[keys.size()] = 1.0 if def.built else 0.0
		if def.id == &"stone":
			_stone_slot = keys.size()
	var wall_keys: Array[String] = []
	_wall_slot.resize(walls.size())
	for i in range(1, walls.size()):
		var def := walls.def(i)
		if def.terrain.is_empty():
			continue
		wall_keys.append(def.terrain)
		_wall_slot[i] = wall_keys.size()
		built_walls[wall_keys.size()] = 1.0 if def.built else 0.0
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("materials", _strip(keys, ""))
	_material.set_shader_parameter("overlays", _strip(overlays, "ore_"))
	_material.set_shader_parameter("wall_tex", _strip(wall_keys, ""))
	_material.set_shader_parameter("noise_tex", load(TERRAIN_DIR + "/noise.png"))
	_material.set_shader_parameter("grass_slots", grass)
	_material.set_shader_parameter("built_slots", built)
	_material.set_shader_parameter("built_walls", built_walls)
	for i in GRASS_COLORS.size():
		_material.set_shader_parameter("grass_%d" % i, Color(GRASS_COLORS[i]))


## Packs 64x64 textures side by side; an empty key leaves that cell transparent.
func _strip(keys: Array[String], prefix: String) -> ImageTexture:
	var img := Image.create_empty(maxi(keys.size(), 1) * MATERIAL_TEX, MATERIAL_TEX, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for i in keys.size():
		if keys[i].is_empty():
			continue
		var tex := load(TERRAIN_DIR.path_join(prefix + keys[i] + ".png")) as Texture2D
		var src := tex.get_image()
		src.convert(Image.FORMAT_RGBA8)
		img.blit_rect(src, Rect2i(0, 0, MATERIAL_TEX, MATERIAL_TEX), Vector2i(i * MATERIAL_TEX, 0))
	return ImageTexture.create_from_image(img)


## Collision set: one tile per atlas row with its shape. Props set: every platform and
## rope variant, no physics.
func _build_tileset(physics: bool) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = load(BLOCKS_ATLAS) as Texture2D
	src.texture_region_size = Vector2i(TILE, TILE)
	if physics:
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, 1)  # "world"
		ts.set_physics_layer_collision_mask(0, 0)
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(1, 2)  # "platforms"
		ts.set_physics_layer_collision_mask(1, 0)
	ts.add_source(src, 0)
	var half := TILE / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	var platform := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + 3), Vector2(-half, -half + 3)])
	var rows := src.texture.get_height() / TILE
	for row in rows:
		var collision := _world.blocks.collision_for_row(row)
		if physics:
			var coords := Vector2i(0, row)
			src.create_tile(coords)
			var td := src.get_tile_data(coords, 0)
			if collision == TileDef.Collision.SOLID:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, square)
			elif collision == TileDef.Collision.PLATFORM:
				td.add_collision_polygon(1)
				td.set_collision_polygon_points(1, 0, platform)
				td.set_collision_polygon_one_way(1, 0, true)
		elif collision != TileDef.Collision.SOLID:
			for col in 16 * PIECES:
				src.create_tile(Vector2i(col, row))
	return ts
