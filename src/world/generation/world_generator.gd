class_name WorldGenerator
extends RefCounted
## Base for world generators. A generator is a pure function of (seed, x, y): any chunk
## can be generated on its own, in any order, on any thread, and the same seed always
## gives the same world. Nothing here may write shared state after _init.
##
## World creates one with WorldGenerator.create(kind, ...). Kinds:
##   &"forest"  the real world (ForestGenerator, tuned by data/worldgen/forest.tres)
##   &"course"  dev-only movement test course (CourseGenerator)

const KINDS: Array[StringName] = [&"forest", &"course"]

var width: int
var height: int
var seed: int

## Block and wall indices by id, filled by _ids().
var _b: Dictionary[StringName, int] = {}
var _w: Dictionary[StringName, int] = {}


static func create(kind: StringName, tiles: TileTypes, walls: TileTypes, world_width: int,
		world_height: int, world_seed: int) -> WorldGenerator:
	match kind:
		&"course":
			return CourseGenerator.new(tiles, walls, world_width, world_height, world_seed)
		_:
			return ForestGenerator.new(tiles, walls, world_width, world_height, world_seed)


func _init(tiles: TileTypes, walls: TileTypes, world_width: int, world_height: int, world_seed: int) -> void:
	width = world_width
	height = world_height
	seed = world_seed
	for id: StringName in [&"dirt", &"grass", &"stone", &"copper_ore", &"iron_ore", &"clay", &"wood_planks", &"wood_platform", &"rope"]:
		_b[id] = tiles.index_of(id)
	for id: StringName in [&"dirt_wall", &"stone_wall", &"wood_wall"]:
		_w[id] = walls.index_of(id)


## Where a new player appears: the surface tile they stand on.
func spawn_tile() -> Vector2i:
	return Vector2i.ZERO


## Row of the top solid tile at column x, ignoring caves (x is wrapped, 0..width-1).
func surface_at(_x: int) -> int:
	return 0


## Fills a fresh chunk. Runs on worker threads.
func generate_chunk(_chunk: ChunkData) -> void:
	pass


## Tree art variant for column x, or -1. Read by chunk builds (worker threads).
func tree_at(_x: int) -> int:
	return -1


## Flower art variant for column x, or -1.
func flower_at(_x: int) -> int:
	return -1


## Signed distance from `from` to x, the short way around the wrapped world.
func wrap_delta(x: int, from: int) -> int:
	return posmod(x - from + width / 2, width) - width / 2
