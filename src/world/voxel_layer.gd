class_name VoxelLayer
extends Node2D
## The voxel experiment (Phase 52): a finer grid of cells, 4x4 per tile (2x2 world
## pixels each), for materials that move cell by cell. Sand falls and piles, water
## flows and levels, Sand Bricks stay put but explosions bite pieces out of them.
##
## Cells only live in tiles whose block is air: a sand block that loses its support
## turns into 16 sand cells (and a tile full of resting sand turns back into a block,
## so piles stay cheap). Each cell is one byte: the material (low 4 bits, index into
## `materials` + 1) and a shade (high 4 bits, which of the material's 16 colors).
## Simulated only where something changed (`_active`), on the host.

const N := 4  ## cells per tile side
const CELLS := 16  ## cells per tile
const CELL_PX := 2  ## World.TILE / N
const TILE := World.TILE

## Simulation steps per second.
@export var ticks_per_second := 30.0
## Cells a falling grain or drop moves per step when nothing is under it.
@export_range(1, 4) var fall_cells := 2
## How far (cells) a water cell looks sideways for somewhere lower to flow to. Water
## only slides toward a drop, so a level surface settles (and stops costing anything).
@export var water_spread := 32
## Chance a sand cell sinks into the water under it each step (lower = slower sinking).
@export_range(0.0, 1.0) var sand_sink_chance := 0.35
## Turn tiles full of resting sand back into sand blocks (cheaper for huge piles, but
## the terrain shader rounds their edges inside a loose pile, so it's off for now).
@export var solidify_piles := false
## Steps a tile full of sand must rest before it becomes a sand block again.
@export var settle_steps := 20
## Steps with no movement before a tile stops being simulated.
@export var sleep_steps := 30
## Brightness of sand and brick cells next to the blocks the terrain shader draws (so
## a loose pile matches a sand block).
@export_range(0.5, 1.2) var cell_shade := 0.84
## Water cells' opacity.
@export_range(0.0, 1.0) var water_alpha := 0.72

var world: World
## Index + 1 = a cell's material code.
var materials: Array[VoxelMaterial] = []
## Wrapped tile -> 16 cell bytes (row by row, top row first).
var tiles: Dictionary[Vector2i, PackedByteArray] = {}
var _index: Dictionary[StringName, int] = {}
var _palettes: Array[PackedColorArray] = []
var _palette_lum: Array[PackedFloat32Array] = []
var _images: Array[Image] = []
## Tile -> steps without movement.
var _active: Dictionary[Vector2i, int] = {}
var _moved: Dictionary[Vector2i, bool] = {}
var _damage: Dictionary[Vector2i, float] = {}
var _acc := 0.0
var _tick := 0
var _collision: TileMapLayer
## Tile -> the world copy (x offset in tiles) its collision cells were put at.
var _col_x: Dictionary[Vector2i, int] = {}
var _col_dirty: Dictionary[Vector2i, bool] = {}
var _col_check_left := 1.0
## Per material code (0 = empty): its Behavior, or -1.
var _behavior := PackedInt32Array()
## Per step: tile -> 0 open, 1 full solid, 2 shaped solid, 3 platform.
var _terrain_cache: Dictionary[Vector2i, int] = {}
## Tiles changed during a step (woken once it ends).
var _changed: Dictionary[Vector2i, bool] = {}
var _in_step := false
## Drawing: tiles to repaint, and per region (REGION tiles square) its picture at art
## resolution (2 pixels a world pixel, like the terrain textures).
const REGION := 16
var _paint: Dictionary[Vector2i, bool] = {}
var _regions: Dictionary[Vector2i, Array] = {}  # region -> [Image, ImageTexture]
var _width_cells := 0


func setup(w: World) -> void:
	world = w
	var list: Array[VoxelMaterial] = []
	for d in Registry.get_all(&"voxels"):
		if d is VoxelMaterial:
			list.append(d as VoxelMaterial)
	list.sort_custom(func(a: VoxelMaterial, b: VoxelMaterial) -> bool: return String(a.id) < String(b.id))
	for m in list:
		materials.append(m)
		_index[m.id] = materials.size()
		_build_palette(m)
	_behavior.resize(16)
	_behavior.fill(-1)
	for i in materials.size():
		_behavior[i + 1] = materials[i].behavior
	_width_cells = world.data.width * N
	_collision = TileMapLayer.new()
	_collision.name = "VoxelCollision"
	_collision.visible = false
	_collision.tile_set = _cell_tileset()
	add_child(_collision)
	world.block_changed.connect(_on_block_changed)


## A material's cell code (0 = unknown).
func code_of(material_id: StringName) -> int:
	return _index.get(material_id, 0)


func material_of(byte: int) -> VoxelMaterial:
	var i := (byte & 15) - 1
	return materials[i] if i >= 0 and i < materials.size() else null


## The voxel material a block turns into (sand, Sand Bricks), or null.
func material_for_block(block_id: int) -> VoxelMaterial:
	if block_id <= 0:
		return null
	var def := world.blocks.def(block_id)
	if def == null or def.voxel == &"":
		return null
	var c := code_of(def.voxel)
	return materials[c - 1] if c > 0 else null


# --- cells -------------------------------------------------------------------------------

func _tile_of(cell: Vector2i) -> Vector2i:
	var x := cell.x
	if x < 0 or x >= _width_cells:
		x = posmod(x, _width_cells)
	return Vector2i(x >> 2, cell.y >> 2)


func cell(c: Vector2i) -> int:
	var arr: PackedByteArray = tiles.get(_tile_of(c), PackedByteArray())
	if arr.is_empty():
		return 0
	return arr[(c.y & 3) * N + (c.x & 3)]


func _set_cell(c: Vector2i, byte: int) -> void:
	var t := _tile_of(c)
	var arr: PackedByteArray = tiles.get(t, PackedByteArray())
	if arr.is_empty():
		if byte == 0:
			return
		arr.resize(CELLS)
	arr[(c.y & 3) * N + (c.x & 3)] = byte
	if byte == 0 and arr.count(0) == CELLS:
		tiles.erase(t)
	else:
		tiles[t] = arr
	if _in_step:
		_changed[t] = true
	else:
		_touched(t)


## True when terrain (a solid block, its shape, a platform's top) fills this cell.
func _terrain_blocks(c: Vector2i) -> bool:
	if c.y < 0 or c.y >= world.data.height * N:
		return true
	var t := _tile_of(c)
	var kind: int = _terrain_cache.get(t, -1)
	if kind < 0:
		kind = _terrain_kind(t)
		if _in_step:
			_terrain_cache[t] = kind
	match kind:
		1:
			return true
		2:
			var s := world.data.get_shape(t.x, t.y) & 7
			return in_shape(s, Vector2((c.x & 3) * CELL_PX + 1.0, (c.y & 3) * CELL_PX + 1.0))
		3:
			return (c.y & 3) == 0
	return false


## 0 open, 1 full solid, 2 shaped solid, 3 platform.
func _terrain_kind(t: Vector2i) -> int:
	var b := world.data.get_block(t.x, t.y)
	if b == WorldData.OUT_OF_BOUNDS:
		return 1
	if b <= 0:
		return 0
	match world.blocks.collision(b):
		TileDef.Collision.SOLID:
			return 1 if (world.data.get_shape(t.x, t.y) & 7) == 0 else 2
		TileDef.Collision.PLATFORM:
			return 3
	return 0


func _free(c: Vector2i) -> bool:
	return not _terrain_blocks(c) and cell(c) == 0


func _liquid(c: Vector2i) -> bool:
	return _behavior[cell(c) & 15] == VoxelMaterial.Behavior.LIQUID


## Whether a point inside a tile (0 to 8 px) is inside a Shaping Spell shape (the same
## test as terrain.gdshader's in_shape).
static func in_shape(s: int, c: Vector2) -> bool:
	match s:
		1:
			return c.y >= 4.0
		2:
			return c.y < 4.0
		3:
			return c.y >= c.x
		4:
			return c.x + c.y >= 8.0
		5:
			return c.x + c.y < 8.0
		6:
			return c.y < c.x
	return true


## True when a solid cell (sand, brick) is at this world point.
func solid_at(p: Vector2) -> bool:
	var m := material_of(cell(Vector2i(floori(p.x / CELL_PX), floori(p.y / CELL_PX))))
	return m != null and m.is_solid()


## True when a liquid cell (water) is at this world point.
func liquid_at(p: Vector2) -> bool:
	return _behavior[cell(Vector2i(floori(p.x / CELL_PX), floori(p.y / CELL_PX))) & 15] == VoxelMaterial.Behavior.LIQUID


## Liquid cells of a material in a box of tiles.
func liquid_in(tiles_rect: Rect2i, material_id: StringName = &"water") -> int:
	var n := 0
	for y in range(tiles_rect.position.y, tiles_rect.end.y):
		for x in range(tiles_rect.position.x, tiles_rect.end.x):
			n += count_in(Vector2i(x, y), material_id)
	return n


## Takes up to `count` liquid cells from a box of tiles, top cells first (the surface
## drops, the rest flows in). Returns how many it took.
func take_liquid(tiles_rect: Rect2i, count: int, material_id: StringName = &"water") -> int:
	if not Game.is_authority() or count <= 0:
		return 0
	var code := code_of(material_id)
	var taken := 0
	for cy in range(tiles_rect.position.y * N, tiles_rect.end.y * N):
		for cx in range(tiles_rect.position.x * N, tiles_rect.end.x * N):
			if taken >= count:
				return taken
			var c := Vector2i(cx, cy)
			if (cell(c) & 15) == code:
				_set_cell(c, 0)
				taken += 1
	return taken


## Pours up to `count` liquid cells into the empty cells of a box of tiles, bottom
## first. Returns how many it poured.
func pour_liquid(tiles_rect: Rect2i, count: int, material_id: StringName = &"water") -> int:
	if not Game.is_authority() or count <= 0:
		return 0
	var code := code_of(material_id)
	var poured := 0
	for cy in range(tiles_rect.end.y * N - 1, tiles_rect.position.y * N - 1, -1):
		for cx in range(tiles_rect.position.x * N, tiles_rect.end.x * N):
			if poured >= count:
				return poured
			var c := Vector2i(cx, cy)
			if _free(c) and world.data.get_block(_tile_of(c).x, _tile_of(c).y) == WorldData.AIR:
				_set_cell(c, code | ((randi() % 16) << 4))
				poured += 1
	return poured


## Cells of anything but liquid in a tile (what mining takes).
func has_minable(tile: Vector2i) -> bool:
	var arr: PackedByteArray = tiles.get(world.wrap_tile(tile), PackedByteArray())
	for b in arr:
		if b != 0 and material_of(b).is_solid():
			return true
	return false


func count_in(tile: Vector2i, material_id: StringName) -> int:
	var arr: PackedByteArray = tiles.get(world.wrap_tile(tile), PackedByteArray())
	var code := code_of(material_id)
	var n := 0
	for b in arr:
		if b != 0 and (b & 15) == code:
			n += 1
	return n


# --- blocks <-> cells --------------------------------------------------------------------

## Turns a block with a voxel material into cells (keeping its Shaping Spell shape).
## Returns false when the block has none.
func break_into_cells(tile: Vector2i) -> bool:
	var t := world.wrap_tile(tile)
	var b := world.data.get_block(t.x, t.y)
	var m := material_for_block(b)
	if m == null or t.y >= world.data.height - 1:
		return false
	var code := code_of(m.id)
	var s := world.data.get_shape(t.x, t.y) & 7
	var arr: PackedByteArray = tiles.get(t, PackedByteArray())
	if arr.is_empty():
		arr.resize(CELLS)
	for ly in N:
		for lx in N:
			if s != 0 and not in_shape(s, Vector2(lx * CELL_PX + 1.0, ly * CELL_PX + 1.0)):
				continue
			var px := Vector2i(t.x * TILE + lx * CELL_PX, t.y * TILE + ly * CELL_PX)
			arr[ly * N + lx] = code | (_shade_at(code - 1, px) << 4)
	world.data.set_shape(t.x, t.y, world.data.get_shape(t.x, t.y) & 0xF0)
	world.request_set_block(t, WorldData.AIR, true)
	tiles[t] = arr
	_touched(t)
	return true


## A tile full of resting powder becomes its block again.
func _try_solidify(t: Vector2i) -> void:
	var arr: PackedByteArray = tiles.get(t, PackedByteArray())
	if arr.size() != CELLS or arr.count(0) > 0:
		return
	var code := arr[0] & 15
	for b in arr:
		if (b & 15) != code:
			return
	var m := material_of(code)
	if m == null or m.behavior != VoxelMaterial.Behavior.POWDER or m.block == &"" or not _supported(t):
		return
	var id := world.blocks.index_of(m.block)
	if id <= 0:
		return
	tiles.erase(t)
	_touched(t)
	world.request_set_block(t, id, true)


## Something solid and whole under the tile: a solid unshaped block, or a tile full of
## solid cells.
func _supported(t: Vector2i) -> bool:
	var below := Vector2i(t.x, t.y + 1)
	if below.y >= world.data.height:
		return true
	if world.is_solid(below):
		var sb := world.data.get_block(below.x, below.y)
		return sb == WorldData.OUT_OF_BOUNDS or world.blocks.collision(sb) != TileDef.Collision.SOLID \
			or (world.data.get_shape(below.x, below.y) & 7) == 0
	var arr: PackedByteArray = tiles.get(world.wrap_tile(below), PackedByteArray())
	if arr.size() != CELLS or arr.count(0) > 0:
		return false
	for b in arr:
		if not material_of(b).is_solid():
			return false
	return true


## A powder block with nothing whole under it starts to fall.
func _check_block(t: Vector2i) -> void:
	var m := material_for_block(world.data.get_block(t.x, t.y))
	if m and m.behavior == VoxelMaterial.Behavior.POWDER and not _supported(t):
		break_into_cells(t)


func _on_block_changed(tile: Vector2i, _old: int, _new: int) -> void:
	var t := world.wrap_tile(tile)
	_terrain_cache.erase(t)  # a block appeared or went mid-step
	_wake_around(t)


# --- simulation --------------------------------------------------------------------------

func _touched(t: Vector2i) -> void:
	_wake_around(t)
	_col_dirty[t] = true
	_paint[t] = true
	_paint[Vector2i(t.x, t.y + 1)] = true  # a water surface under it may change


func _wake_around(t: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(-1, -1), Vector2i(1, -1), Vector2i.DOWN]:
		var n := Vector2i(world.data.wrap_x(t.x + d.x), t.y + d.y)
		if n.y >= 0 and n.y < world.data.height:
			_active[n] = 0


func _physics_process(delta: float) -> void:
	if world == null or not Game.is_authority():
		return
	_acc = minf(_acc + delta * ticks_per_second, 3.0)
	while _acc >= 1.0:
		_acc -= 1.0
		step()
	_col_check_left -= delta
	if _col_check_left <= 0.0:
		_col_check_left = 1.0
		_check_collision_copies()
	_flush_collision()


func _process(_delta: float) -> void:
	if world == null:
		return
	if not _paint.is_empty():
		_flush_paint()
	queue_redraw()


## Moves a tile's cells one by one, bottom row first. True if any moved.
func _step_cells(t: Vector2i, flip: bool) -> bool:
	var moved := false
	for ly in range(N - 1, -1, -1):
		for i in N:
			var lx := i if flip else N - 1 - i
			var c := Vector2i(t.x * N + lx, t.y * N + ly)
			if _moved.has(c):
				continue
			var byte := cell(c)
			if byte == 0:
				continue
			match _behavior[byte & 15]:
				VoxelMaterial.Behavior.POWDER:
					moved = _step_powder(c, byte) or moved
				VoxelMaterial.Behavior.LIQUID:
					moved = _step_liquid(c, byte) or moved
	return moved


## One simulation step over the active tiles, bottom up.
func step() -> void:
	if _active.is_empty():
		return
	_tick += 1
	_moved.clear()
	_terrain_cache.clear()
	_changed.clear()
	_in_step = true
	var list: Array[Vector2i] = _active.keys()
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y)
	var flip := (_tick & 1) == 0
	for t in list:
		if not tiles.has(t):
			_active.erase(t)
			_check_block(t)
			continue
		var moved := false
		var fast := _fast_tile(t)
		if fast == 1:
			_active[t] = 0
			continue
		if fast == 0:
			moved = _step_cells(t, flip)
		if not _active.has(t):
			continue
		if moved:
			_active[t] = 0
			continue
		var idle := _active[t] + 1
		_active[t] = idle
		if solidify_piles and idle >= settle_steps:
			_try_solidify(t)
		if idle >= sleep_steps:
			_active.erase(t)
	_in_step = false
	for t: Vector2i in _changed:
		_touched(t)
		_active[t] = 0


func _move(from: Vector2i, to: Vector2i, byte: int) -> void:
	var there := cell(to)
	_set_cell(to, byte)
	_set_cell(from, there)
	_moved[to] = true
	if there != 0:
		_moved[from] = true


## Tile-sized shortcuts: 1 = the whole tile shifted down (open space under it), 2 =
## nothing in it can move (full of solid cells on something full), 0 = go cell by cell.
func _fast_tile(t: Vector2i) -> int:
	var arr: PackedByteArray = tiles[t]
	var empties := arr.count(0)
	var below := Vector2i(t.x, t.y + 1)
	if below.y >= world.data.height:
		return 2
	var bkind: int = _terrain_cache.get(below, -1)
	if bkind < 0:
		bkind = _terrain_kind(below)
		_terrain_cache[below] = bkind
	var barr: PackedByteArray = tiles.get(below, PackedByteArray())
	var all_solid := true
	var all_static := true
	for b in arr:
		var k := _behavior[b & 15]
		if b != 0 and k == VoxelMaterial.Behavior.LIQUID:
			all_solid = false
		if b != 0 and k != VoxelMaterial.Behavior.STATIC:
			all_static = false
	if all_static:
		return 2
	# Full, and boxed in by full tiles or rock below and to the sides: nothing in it can
	# move (the inside of a pool or a pile).
	if empties == 0 and _full_or_rock(below) and _full_or_rock(Vector2i(world.data.wrap_x(t.x - 1), t.y)) \
			and _full_or_rock(Vector2i(world.data.wrap_x(t.x + 1), t.y)) \
			and _full_or_rock(Vector2i(world.data.wrap_x(t.x - 1), t.y + 1)) \
			and _full_or_rock(Vector2i(world.data.wrap_x(t.x + 1), t.y + 1)):
		return 2
	if empties == 0 and all_solid and _holds_up(below) \
			and _holds_up(Vector2i(world.data.wrap_x(t.x - 1), t.y + 1)) \
			and _holds_up(Vector2i(world.data.wrap_x(t.x + 1), t.y + 1)):
		return 2
	# Shift: the top fall_cells rows of the tile below are open and empty, and nothing
	# static in this one.
	if bkind != 0:
		return 0
	for b in arr:
		if b != 0 and _behavior[b & 15] == VoxelMaterial.Behavior.STATIC:
			return 0
	if not barr.is_empty():
		for i in fall_cells * N:
			if barr[i] != 0:
				return 0
	var out := PackedByteArray()
	out.resize(CELLS)
	var down := barr.duplicate() if not barr.is_empty() else PackedByteArray()
	if down.is_empty():
		down.resize(CELLS)
	for ly in N:
		for lx in N:
			var b := arr[ly * N + lx]
			if b == 0:
				continue
			var ny := ly + fall_cells
			if ny < N:
				out[ny * N + lx] = b
			else:
				down[(ny - N) * N + lx] = b
	if out.count(0) == CELLS:
		tiles.erase(t)
	else:
		tiles[t] = out
	tiles[below] = down
	_changed[t] = true
	_changed[below] = true
	return 1


## True when a tile is solid rock (a full solid block) or has no empty cells.
func _full_or_rock(t: Vector2i) -> bool:
	if t.y >= world.data.height:
		return true
	var kind: int = _terrain_cache.get(t, -1)
	if kind < 0:
		kind = _terrain_kind(t)
		_terrain_cache[t] = kind
	if kind == 1:
		return true
	var arr: PackedByteArray = tiles.get(t, PackedByteArray())
	return arr.size() == CELLS and arr.count(0) == 0


## True when a tile is terrain-solid or full of solid cells (nothing can fall into it).
func _holds_up(t: Vector2i) -> bool:
	if t.y >= world.data.height:
		return true
	var kind: int = _terrain_cache.get(t, -1)
	if kind < 0:
		kind = _terrain_kind(t)
		_terrain_cache[t] = kind
	if kind == 1:
		return true
	var arr: PackedByteArray = tiles.get(t, PackedByteArray())
	if arr.size() != CELLS or arr.count(0) > 0:
		return false
	for b in arr:
		if _behavior[b & 15] == VoxelMaterial.Behavior.LIQUID:
			return false
	return true


## Falls up to fall_cells through empty cells. Returns where it ended (c = didn't).
func _fall(c: Vector2i, byte: int) -> Vector2i:
	var to := c
	for i in fall_cells:
		if not _free(to + Vector2i.DOWN):
			break
		to += Vector2i.DOWN
	if to != c:
		_move(c, to, byte)
	return to


func _step_powder(c: Vector2i, byte: int) -> bool:
	if _fall(c, byte) != c:
		return true
	var down := c + Vector2i.DOWN
	if _liquid(down) and randf() < sand_sink_chance:
		_move(c, down, byte)
		return true
	var d := 1 if randf() < 0.5 else -1
	for dd: int in [d, -d]:
		var diag := c + Vector2i(dd, 1)
		if _terrain_blocks(c + Vector2i(dd, 0)):
			continue
		if _free(diag) or (_liquid(diag) and randf() < sand_sink_chance):
			_move(c, diag, byte)
			return true
	return false


func _step_liquid(c: Vector2i, byte: int) -> bool:
	if _fall(c, byte) != c:
		return true
	var d := 1 if randf() < 0.5 else -1
	for dd: int in [d, -d]:
		if not _terrain_blocks(c + Vector2i(dd, 0)) and _free(c + Vector2i(dd, 1)):
			_move(c, c + Vector2i(dd, 1), byte)
			return true
	for dd: int in [d, -d]:
		for k in range(1, water_spread + 1):
			var to := c + Vector2i(dd * k, 0)
			if not _free(to):
				break
			if _free(to + Vector2i.DOWN):
				_move(c, to, byte)
				return true
	return false


# --- requests ----------------------------------------------------------------------------

## Fills a tile's empty cells with a material (dev console `water`). Returns cells added.
func request_fill(tile: Vector2i, material_id: StringName) -> int:
	if not Game.is_authority():
		return 0
	var t := world.wrap_tile(tile)
	var code := code_of(material_id)
	if code == 0 or world.data.get_block(t.x, t.y) != WorldData.AIR:
		return 0
	var n := 0
	for ly in N:
		for lx in N:
			var c := Vector2i(t.x * N + lx, t.y * N + ly)
			if cell(c) == 0:
				_set_cell(c, code | ((randi() % 16) << 4))
				n += 1
	return n


## Mining a tile of cells: takes every solid cell at once (at the material's health).
## Liquid stays. Returns true when it broke.
func request_damage(tile: Vector2i, amount: float) -> bool:
	if not Game.is_authority() or not has_minable(tile):
		return false
	var t := world.wrap_tile(tile)
	var arr: PackedByteArray = tiles[t]
	var health := 0.0
	for b in arr:
		var m := material_of(b)
		if m and m.is_solid():
			var def := world.blocks.def(world.blocks.index_of(m.block)) if m.block != &"" else null
			health = maxf(health, m.health if m.health > 0.0 else (def.health if def else 30.0))
	var done: float = _damage.get(t, 0.0) + amount
	if done < health:
		_damage[t] = done
		return false
	_damage.erase(t)
	var counts := _take_solid(t)
	var pos := world.tile_to_world(tile) + Vector2(TILE * 0.5, TILE * 0.5)
	for code: int in counts:
		var m := materials[code - 1]
		var n := int(counts[code]) / m.cells_per_item
		if m.item != &"" and n > 0:
			world.request_spawn_drop(m.item, n, pos, Vector2(randf_range(-2.0, 2.0), -4.0) * TILE)
		if not m.terrain.is_empty():
			BreakDust.spawn(world.effects, pos, ChunkRenderer.terrain_color(m.terrain))
	EventBus.sound_requested.emit(&"block_break", pos)
	return true


## Removes a tile's solid cells. Returns cell code -> how many.
func _take_solid(t: Vector2i) -> Dictionary:
	var counts := {}
	var arr: PackedByteArray = tiles.get(t, PackedByteArray())
	if arr.is_empty():
		return counts
	for i in CELLS:
		var b := arr[i]
		var m := material_of(b)
		if m and m.is_solid():
			counts[b & 15] = int(counts.get(b & 15, 0)) + 1
			arr[i] = 0
	if arr.count(0) == CELLS:
		tiles.erase(t)
	else:
		tiles[t] = arr
	_touched(t)
	return counts


## How many of `item` placing its block at this tile takes: the item's `place_units`
## for an empty tile; a tile partly full of the same material (loose sand, a bitten
## Sand Bricks tile) only needs the missing cells.
func place_cost(tile: Vector2i, item: ItemData) -> int:
	var units := maxi(item.place_units, 1)
	var t := world.wrap_tile(tile)
	if not tiles.has(t) or item.places_block == &"":
		return units
	var m := material_for_block(world.blocks.index_of(item.places_block))
	if m == null:
		return units
	return maxi(units - count_in(t, m.id) * units / CELLS, 1)


## Makes room for a block: powder of the block's own material is kept (it becomes the
## block), other solid cells drop as items, liquid is pushed into the tile above.
func clear_for_block(tile: Vector2i) -> void:
	var t := world.wrap_tile(tile)
	var arr: PackedByteArray = tiles.get(t, PackedByteArray())
	if arr.is_empty():
		return
	var liquid: Array[int] = []
	for b in arr:
		var m := material_of(b)
		if m and not m.is_solid():
			liquid.append(b)
	tiles.erase(t)
	_touched(t)
	var above := Vector2i(t.x, t.y - 1)
	if above.y >= 0 and world.data.get_block(above.x, above.y) == WorldData.AIR:
		for ly in range(N - 1, -1, -1):
			for lx in N:
				var c := Vector2i(above.x * N + lx, above.y * N + ly)
				if not liquid.is_empty() and cell(c) == 0:
					_set_cell(c, liquid.pop_back())


## An explosion: blocks with a voxel material (sand, Sand Bricks) turn into cells, then
## every solid cell within `radius` px of `center` is destroyed. Liquid is left.
## Returns how many cells were destroyed.
func explode(center: Vector2, radius: float) -> int:
	if not Game.is_authority():
		return 0
	var lo := Vector2i(floori((center.x - radius) / TILE), floori((center.y - radius) / TILE))
	var hi := Vector2i(floori((center.x + radius) / TILE), floori((center.y + radius) / TILE))
	var opened: Array[Vector2i] = []
	for ty in range(lo.y, hi.y + 1):
		for tx in range(lo.x, hi.x + 1):
			var mid := Vector2((tx + 0.5) * TILE, (ty + 0.5) * TILE)
			if mid.distance_to(center) <= radius + TILE * 0.71 and break_into_cells(Vector2i(tx, ty)):
				opened.append(world.wrap_tile(Vector2i(tx, ty)))
	var n := 0
	var r2 := radius * radius
	for cy in range(floori((center.y - radius) / CELL_PX), floori((center.y + radius) / CELL_PX) + 1):
		for cx in range(floori((center.x - radius) / CELL_PX), floori((center.x + radius) / CELL_PX) + 1):
			var p := Vector2((cx + 0.5) * CELL_PX, (cy + 0.5) * CELL_PX)
			if p.distance_squared_to(center) > r2:
				continue
			var c := Vector2i(cx, cy)
			var m := material_of(cell(c))
			if m and m.is_solid():
				_set_cell(c, 0)
				n += 1
	# Tiles the blast only grazed are whole blocks again.
	for t in opened:
		_restore_whole(t)
	return n


## A tile still full of one material with a block goes back to being that block.
func _restore_whole(t: Vector2i) -> void:
	var arr: PackedByteArray = tiles.get(t, PackedByteArray())
	if arr.size() != CELLS or arr.count(0) > 0:
		return
	var code := arr[0] & 15
	for b in arr:
		if (b & 15) != code:
			return
	var m := material_of(code)
	var id := world.blocks.index_of(m.block) if m and m.block != &"" else -1
	if id <= 0:
		return
	tiles.erase(t)
	_touched(t)
	world.request_set_block(t, id, true)


# --- colors and drawing ------------------------------------------------------------------

func _build_palette(m: VoxelMaterial) -> void:
	var img: Image = null
	if not m.terrain.is_empty():
		var tex := load(ChunkRenderer.TERRAIN_DIR.path_join(m.terrain + ".png")) as Texture2D
		if tex:
			img = tex.get_image()
			if img.is_compressed():
				img.decompress()
	_images.append(img)
	var colors: Array[Color] = []
	if img:
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				colors.append(img.get_pixel(x, y))
		colors.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	var pal := PackedColorArray()
	var lum := PackedFloat32Array()
	for i in 16:
		var c: Color
		if colors.is_empty():
			c = m.color.lightened(0.12 * (i - 8) / 8.0) if i >= 8 else m.color.darkened(0.12 * (8 - i) / 8.0)
		else:
			c = colors[int((i + 0.5) / 16.0 * colors.size())]
		pal.append(c)
		lum.append(c.get_luminance())
	_palettes.append(pal)
	_palette_lum.append(lum)


## The shade (0 to 15) closest to the material's picture at a world pixel.
func _shade_at(index: int, px: Vector2i) -> int:
	var img := _images[index]
	if img == null:
		return randi() % 16
	var c := img.get_pixel(posmod(px.x * 2 + 1, img.get_width()), posmod(px.y * 2 + 1, img.get_height()))
	var l := c.get_luminance()
	var best := 0
	var lum := _palette_lum[index]
	for i in 16:
		if absf(lum[i] - l) < absf(lum[best] - l):
			best = i
	return best


## Repaints the changed tiles into their regions' pictures.
func _flush_paint() -> void:
	var touched: Dictionary[Vector2i, bool] = {}
	for t: Vector2i in _paint:
		if t.y < 0 or t.y >= world.data.height:
			continue
		var r := Vector2i(t.x / REGION, t.y / REGION)
		var entry: Array = _regions.get(r, [])
		if entry.is_empty():
			if not tiles.has(t):
				continue
			var img := Image.create_empty(REGION * TILE * 2, REGION * TILE * 2, false, Image.FORMAT_RGBA8)
			entry = [img, null]
			_regions[r] = entry
		_paint_tile(entry[0] as Image, t, Vector2i((t.x - r.x * REGION) * TILE * 2, (t.y - r.y * REGION) * TILE * 2))
		touched[r] = true
	_paint.clear()
	for r: Vector2i in touched:
		var entry: Array = _regions[r]
		var img := entry[0] as Image
		if img.is_invisible():
			_regions.erase(r)
			continue
		if entry[1] == null:
			entry[1] = ImageTexture.create_from_image(img)
		else:
			(entry[1] as ImageTexture).update(img)


func _paint_tile(img: Image, t: Vector2i, at: Vector2i) -> void:
	var size := TILE * 2
	img.fill_rect(Rect2i(at, Vector2i(size, size)), Color(0, 0, 0, 0))
	var arr: PackedByteArray = tiles.get(t, PackedByteArray())
	if arr.is_empty():
		return
	var cp := CELL_PX * 2  # a cell's art pixels
	for i in CELLS:
		var b := arr[i]
		if b == 0:
			continue
		var code := (b & 15) - 1
		if code < 0 or code >= materials.size():
			continue
		var m := materials[code]
		var lx := i % N
		var ly := i / N
		var o := at + Vector2i(lx * cp, ly * cp)
		var src := _images[code]
		if m.behavior == VoxelMaterial.Behavior.LIQUID or src == null:
			var col := _palettes[code][b >> 4]
			if m.behavior == VoxelMaterial.Behavior.LIQUID:
				col.a = water_alpha
				var above := Vector2i(t.x * N + lx, t.y * N + ly - 1)
				if cell(above) == 0 and not _terrain_blocks(above):
					col = col.lightened(0.35)  # the surface
			else:
				col = Color(col.r * cell_shade, col.g * cell_shade, col.b * cell_shade, col.a)
			img.fill_rect(Rect2i(o, Vector2i(cp, cp)), col)
			continue
		# Static cells show the texture where they are (bricks stay lined up); loose
		# grains carry their own patch of it (picked by the shade), so they keep their
		# look as they move.
		var origin: Vector2i
		if m.behavior == VoxelMaterial.Behavior.STATIC:
			origin = Vector2i((t.x * TILE + lx * CELL_PX) * 2, (t.y * TILE + ly * CELL_PX) * 2)
		else:
			var k := b >> 4
			origin = Vector2i((k * 37) % 31 * cp, (k * 53) % 29 * cp)
		var w := src.get_width()
		var h := src.get_height()
		for py in cp:
			for px in cp:
				var c := src.get_pixel(posmod(origin.x + px, w), posmod(origin.y + py, h))
				img.set_pixel(o.x + px, o.y + py, Color(c.r * cell_shade, c.g * cell_shade, c.b * cell_shade, c.a))


func _draw() -> void:
	if world == null:
		return
	for r: Vector2i in _regions:
		var entry: Array = _regions[r]
		if entry[1] == null:
			continue
		var x := world.near_player_x(r.x * REGION * TILE)
		draw_texture_rect(entry[1] as Texture2D, Rect2(x, r.y * REGION * TILE, REGION * TILE, REGION * TILE), false)


# --- collision ---------------------------------------------------------------------------

func _cell_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL_PX, CELL_PX)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)  # "world", like solid blocks
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	var img := Image.create_empty(CELL_PX, CELL_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(CELL_PX, CELL_PX)
	ts.add_source(src, 0)
	src.create_tile(Vector2i.ZERO)
	var td := src.get_tile_data(Vector2i.ZERO, 0)
	td.add_collision_polygon(0)
	var h := CELL_PX / 2.0
	td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	return ts


## The world copy (in tiles) of a tile closest to the player.
func _copy_x(t: Vector2i) -> int:
	return roundi(world.near_player_x(t.x * TILE) / TILE)


func _flush_collision() -> void:
	if _col_dirty.is_empty():
		return
	for t: Vector2i in _col_dirty:
		var old_x: int = _col_x.get(t, t.x)
		for ly in N:
			for lx in N:
				_collision.erase_cell(Vector2i(old_x * N + lx, t.y * N + ly))
		_col_x.erase(t)
		var arr: PackedByteArray = tiles.get(t, PackedByteArray())
		if arr.is_empty():
			continue
		var x := _copy_x(t)
		var any := false
		for i in CELLS:
			var m := material_of(arr[i])
			if m and m.is_solid():
				_collision.set_cell(Vector2i(x * N + i % N, t.y * N + i / N), 0, Vector2i.ZERO)
				any = true
		if any:
			_col_x[t] = x
	_col_dirty.clear()


## Moves collision to the world copy next to the player when the player crosses the wrap.
func _check_collision_copies() -> void:
	for t: Vector2i in _col_x:
		if _col_x[t] != _copy_x(t):
			_col_dirty[t] = true


# --- saving ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	if tiles.is_empty():
		return {}
	var names: Array[String] = []
	for m in materials:
		names.append(String(m.id))
	var out := {}
	for t: Vector2i in tiles:
		out["%d,%d" % [t.x, t.y]] = tiles[t]
	return {"materials": names, "tiles": out}


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	var names: Array = d.get("materials", [])
	var remap := PackedByteArray()
	remap.resize(16)
	for i in names.size():
		if i < 15:
			remap[i + 1] = code_of(StringName(names[i]))
	var saved: Dictionary = d.get("tiles", {})
	for key: String in saved:
		var parts := key.split(",")
		var bytes: Variant = saved[key]
		if parts.size() != 2 or not bytes is PackedByteArray or (bytes as PackedByteArray).size() != CELLS:
			continue
		var arr := (bytes as PackedByteArray).duplicate()
		for i in CELLS:
			if arr[i] != 0:
				var code := remap[arr[i] & 15]
				arr[i] = (code | (arr[i] & 0xF0)) if code > 0 else 0
		if arr.count(0) < CELLS:
			var t := Vector2i(int(parts[0]), int(parts[1]))
			tiles[t] = arr
			_touched(t)
