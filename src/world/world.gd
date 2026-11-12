class_name World
extends Node2D
## The playable world: owns the tile data, draws it, spawns the player.
##
## Host-authoritative: shared state changes only through request_* methods, which
## apply the change where Game.is_authority() is true. In single-player that's always.
## Networking later turns these into requests a client sends to the host.

## A block changed (after it was applied). Tile coords are wrapped.
signal block_changed(tile: Vector2i, old_id: int, new_id: int)

const TILE := 16
const PLAYER_SCENE := preload("res://src/player/player.tscn")

@export var size_preset: WorldData.Size = WorldData.Size.SMALL
@export var world_seed: int = 1337
## Chunks kept loaded around the camera, each direction.
@export var load_radius := Vector2i(2, 2)
## Max chunks built per frame while moving.
@export var chunks_per_frame: int = 2

var data: WorldData
var blocks: TileTypes
var walls: TileTypes
var generator: TestWorldGenerator
var renderer: ChunkRenderer
var player: Player


func _ready() -> void:
	Game.set_state(Game.State.LOADING)
	blocks = TileTypes.new(&"tiles")
	walls = TileTypes.new(&"walls")
	var size: Vector2i = WorldData.SIZES[size_preset]
	data = WorldData.new(size.x, size.y)
	generator = TestWorldGenerator.new(blocks, walls, size.x, size.y, world_seed)
	data.generator = generator.generate_chunk

	_add_sky()
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
	DebugOverlay.watch("chunks", "%d loaded, %d generated" % [renderer.loaded_count(), data.generated_chunk_count()])


func _exit_tree() -> void:
	EventBus.world_unloaded.emit()


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


func _add_sky() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Sky"
	layer.layer = -10
	var gradient := Gradient.new()
	gradient.set_color(0, Color("6fb3e8"))
	gradient.set_color(1, Color("d6ecf7"))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
