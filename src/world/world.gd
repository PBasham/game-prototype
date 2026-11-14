class_name World
extends Node2D
## The playable world: owns the tile data, draws it, spawns the player.
##
## Host-authoritative: shared state changes only through request_* methods, which
## apply the change where Game.is_authority() is true. In single-player that's always.
## Networking later turns these into requests a client sends to the host.

## A block changed (after it was applied). Tile coords are wrapped.
signal block_changed(tile: Vector2i, old_id: int, new_id: int)

## Tile size in pixels. The Scholar is about 3 tiles wide and 8 tall.
const TILE := 8
const PLAYER_SCENE := preload("res://src/player/player.tscn")

@export var size_preset: WorldData.Size = WorldData.Size.SMALL
@export var world_seed: int = 1337
## Chunks kept loaded around the camera, each direction.
@export var load_radius := Vector2i(2, 2)
## Max finished chunks turned into nodes per frame while moving (building happens on
## worker threads; this caps the main-thread part).
@export var chunks_per_frame: int = 1

var data: WorldData
var blocks: TileTypes
var walls: TileTypes
var generator: TestWorldGenerator
var renderer: ChunkRenderer
var lights: LightMap
var backdrop: Backdrop
var player: Player


func _ready() -> void:
	Game.set_state(Game.State.LOADING)
	blocks = TileTypes.new(&"tiles")
	walls = TileTypes.new(&"walls")
	var size: Vector2i = WorldData.SIZES[size_preset]
	data = WorldData.new(size.x, size.y)
	generator = TestWorldGenerator.new(blocks, walls, size.x, size.y, world_seed)
	data.generator = generator.generate_chunk

	backdrop = Backdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	renderer = ChunkRenderer.new()
	renderer.name = "Chunks"
	renderer.load_radius = load_radius
	renderer.chunks_per_frame = chunks_per_frame
	add_child(renderer)
	renderer.setup(self)

	player = PLAYER_SCENE.instantiate() as Player
	player.world = self
	var spawn := generator.spawn_tile()
	if DevCli.spawn_x >= 0:
		spawn = Vector2i(DevCli.spawn_x, generator.surface_at(DevCli.spawn_x))
	player.position = tile_to_world(spawn) + Vector2(TILE * 0.5, 0)
	renderer.load_all_now(player.position)
	add_child(player)
	teleport_player(player.position)
	backdrop.surface_y = tile_to_world(generator.spawn_tile()).y - 60.0

	lights = LightMap.new()
	lights.name = "Lights"
	lights.world = self
	add_child(lights)
	renderer.chunks_changed.connect(lights.mark_dirty)
	block_changed.connect(func(_t: Vector2i, _o: int, _n: int) -> void: lights.mark_dirty())
	lights.rebuild_now()

	if OS.is_debug_build():
		var brush := DebugBrush.new()
		brush.name = "DebugBrush"
		brush.world = self
		add_child(brush)

	DebugOverlay.watch("world", "%dx%d seed %d" % [data.width, data.height, world_seed])
	Game.set_state(Game.State.PLAYING)
	EventBus.world_loaded.emit()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	var center := cam.get_screen_center_position() if cam else player.position
	renderer.update(center)
	DebugOverlay.watch("chunks", "%d loaded, %d generated, %d queued" % [renderer.loaded_count(),
		data.generated_chunk_count(), renderer.pending_count() + data.pending_generation_count()])


func _exit_tree() -> void:
	# Background jobs hold their own data, but finish them before the world goes away.
	if lights:
		lights.wait()
	if renderer:
		renderer.wait_all()
	if data:
		data.wait_all()
	EventBus.world_unloaded.emit()


## Moves the player instantly (spawn, respawn, rewrapping x later). Use this, not
## `player.position =`: with physics interpolation on, a raw jump would be drawn as a
## one-tick slide across the screen, and the smoothed camera would pan the whole way.
func teleport_player(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()  # Propagates to the sprite and camera.
	var cam := player.get_node_or_null(^"Camera") as Camera2D
	if cam:
		cam.reset_smoothing()


# --- coordinates -------------------------------------------------------------

## Pixel position to tile coords (unwrapped x; data access wraps it).
func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


## Tile coords to the pixel position of the tile's top-left corner.
func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile * TILE)


func wrap_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(data.wrap_x(tile.x), tile.y)


# --- queries -----------------------------------------------------------------

func block_at(p: Vector2) -> int:
	var t := world_to_tile(p)
	return data.get_block(t.x, t.y)


func collision_at(p: Vector2) -> int:
	return blocks.collision(block_at(p))


func is_climbable_at(p: Vector2) -> bool:
	return blocks.climbable(block_at(p))


# --- requests (host-authoritative) -------------------------------------------

## Sets a foreground block. Returns true if it changed.
func request_set_block(tile: Vector2i, id: int) -> bool:
	if not Game.is_authority():
		return false  # Clients will send this to the host (multiplayer phase).
	if not data.in_bounds_y(tile.y) or id < 0 or id >= blocks.size():
		return false
	var old := data.get_block(tile.x, tile.y)
	if old == id:
		return false
	data.set_block(tile.x, tile.y, id)
	renderer.refresh_tile(tile)
	block_changed.emit(wrap_tile(tile), old, id)
	return true
