class_name ChunkBuildJob
extends RefCounted
## Everything a chunk view needs, worked out from tile data as plain data so it can run
## on a worker thread: the terrain texture (chunk plus border), collision cells, prop
## cells (platforms, ropes) and decoration spots. ChunkRenderer applies it on the main
## thread, where the only work left is creating nodes and setting cells.
##
## The job holds its own references to the 3x3 neighborhood's tile arrays. Packed arrays
## are copy-on-write, so an edit on the main thread copies the chunk's array instead of
## changing the one this job is reading; `revisions` tell the renderer it went stale.

const SIZE := ChunkData.SIZE
const BORDER := 2
const TEX := SIZE + BORDER * 2
const PIECES := 64
const SOLID := 1  # TileDef.Collision.SOLID
const NONE := 0  # TileDef.Collision.NONE

# --- inputs (set on the main thread before run) ---
## Unwrapped chunk coordinate.
var coord: Vector2i
## The 3x3 neighborhood's chunks (null outside the world) and their revisions when
## the inputs were captured.
var chunks: Array[ChunkData] = []
var revisions := PackedInt32Array()
var world_width: int
var world_height: int
## 3x3 neighborhood (row-major, center at 4). Rows outside the world are empty arrays.
var blocks: Array[PackedInt32Array] = []
var walls: Array[PackedInt32Array] = []
var block_slot: PackedInt32Array
var wall_slot: PackedInt32Array
var stone_slot: int
var collision: PackedInt32Array
var atlas_row: PackedInt32Array
var grass_id: int
## Decoration rules (pure functions of x). Null skips decorations.
var generator: TestWorldGenerator

# --- outputs ---
## TEX x TEX RGBA8: R = block terrain slot, G = wall slot.
var tile_bytes := PackedByteArray()
## Flat triples: local x, local y, atlas row.
var collision_cells := PackedInt32Array()
## Flat quads: local x, local y, atlas x, atlas y.
var prop_cells := PackedInt32Array()
## Flat quads: local x, local y, tree index (-1 none), flower index.
var decor := PackedInt32Array()
var usec := 0
var task := -1


## Main thread: true if any chunk in the neighborhood was edited since capture.
func is_stale() -> bool:
	for i in chunks.size():
		if chunks[i] != null and chunks[i].revision != revisions[i]:
			return true
	return false


func run() -> void:
	var t := Time.get_ticks_usec()
	_terrain()
	_cells()
	_decor()
	usec = Time.get_ticks_usec() - t


## Block at chunk-local (lx, ly); valid for -SIZE <= lx, ly < 2 * SIZE.
func block(lx: int, ly: int) -> int:
	var arr := blocks[((ly + SIZE) / SIZE) * 3 + (lx + SIZE) / SIZE]
	if arr.is_empty():
		return WorldData.AIR if coord.y * SIZE + ly < 0 else WorldData.OUT_OF_BOUNDS
	return arr[posmod(ly, SIZE) * SIZE + posmod(lx, SIZE)]


func wall(lx: int, ly: int) -> int:
	var arr := walls[((ly + SIZE) / SIZE) * 3 + (lx + SIZE) / SIZE]
	if arr.is_empty():
		return WorldData.AIR
	return arr[posmod(ly, SIZE) * SIZE + posmod(lx, SIZE)]


func _terrain() -> void:
	tile_bytes.resize(TEX * TEX * 4)
	var i := 0
	for ty in TEX:
		for tx in TEX:
			var b := block(tx - BORDER, ty - BORDER)
			var w := wall(tx - BORDER, ty - BORDER)
			tile_bytes[i] = stone_slot if b == WorldData.OUT_OF_BOUNDS else (block_slot[b] if b > 0 else 0)
			tile_bytes[i + 1] = wall_slot[w] if w > 0 else 0
			tile_bytes[i + 2] = 0
			tile_bytes[i + 3] = 255
			i += 4


func _cells() -> void:
	var origin := coord * SIZE
	var center := blocks[4]
	for ly in SIZE:
		for lx in SIZE:
			var id := center[ly * SIZE + lx]
			if id <= 0:
				continue
			if collision[id] != NONE:
				collision_cells.append_array([lx, ly, atlas_row[id]])
			if block_slot[id] > 0:
				continue
			# Thin tile (platform, rope): pick the piece that joins same-kind neighbors.
			var mask := 0
			if block(lx, ly - 1) == id:
				mask |= 1
			if block(lx + 1, ly) == id:
				mask |= 2
			if block(lx, ly + 1) == id:
				mask |= 4
			if block(lx - 1, ly) == id:
				mask |= 8
			var piece := posmod(posmod(origin.x + lx, world_width), 8) + posmod(origin.y + ly, 8) * 8
			prop_cells.append_array([lx, ly, mask * PIECES + piece, atlas_row[id]])


func _decor() -> void:
	if generator == null:
		return
	for lx in SIZE:
		var wx := posmod(coord.x * SIZE + lx, world_width)
		var tree := generator.tree_at(wx)
		var flower := generator.flower_at(wx)
		if tree < 0 and flower < 0:
			continue
		for ly in SIZE:
			if block(lx, ly) == grass_id and block(lx, ly - 1) == WorldData.AIR:
				decor.append_array([lx, ly, tree, flower])
				break
