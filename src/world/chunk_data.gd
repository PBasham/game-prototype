class_name ChunkData
extends RefCounted
## One 32x32 block of world tiles: foreground blocks and background walls.
## Pure data; ChunkRenderer draws it.

const SIZE := 32
const AREA := SIZE * SIZE

## Chunk coordinate (wrapped, so 0 <= x < chunks_x).
var coord: Vector2i
var blocks := PackedInt32Array()
var walls := PackedInt32Array()
## Set when anything changes after generation (for saving in Phase 5).
var modified := false
## Bumped by every edit, so background work can tell its copy of the tiles is stale.
var revision := 0


func _init(chunk_coord: Vector2i) -> void:
	coord = chunk_coord
	blocks.resize(AREA)
	walls.resize(AREA)


static func local_index(lx: int, ly: int) -> int:
	return ly * SIZE + lx
