class_name ChunkData
extends RefCounted
## One 32x32 block of world tiles: foreground blocks, background walls and tile objects
## (rope, torches) in between.
## Pure data; ChunkRenderer draws it.

const SIZE := 32
const AREA := SIZE * SIZE

## Chunk coordinate (wrapped, so 0 <= x < chunks_x).
var coord: Vector2i
var blocks := PackedInt32Array()
var walls := PackedInt32Array()
var objects := PackedInt32Array()
## The Shaping Spell's shapes (bits 0-2 the block's: 0 full, 1 bottom half, 2 top half,
## 3 to 6 slopes solid toward the bottom left, bottom right, top left, top right; bit 3
## a log turned the other way; bits 4-5 the wall's: 0 full, 1 bottom half, 2 top half).
## Reset when the block or wall changes.
var shapes := PackedByteArray()
## Tiles the generator filled with water (1), empty when none. Read once by the voxel
## layer when the chunk is first made (VoxelLayer.import_generated).
var water := PackedByteArray()
## Set when anything changes after generation (for saving in Phase 5).
var modified := false
## Bumped by every edit, so background work can tell its copy of the tiles is stale.
var revision := 0


func _init(chunk_coord: Vector2i) -> void:
	coord = chunk_coord
	blocks.resize(AREA)
	walls.resize(AREA)
	objects.resize(AREA)
	shapes.resize(AREA)


static func local_index(lx: int, ly: int) -> int:
	return ly * SIZE + lx
