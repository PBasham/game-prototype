class_name World
extends Node2D
## The playable world: owns the tile data, draws it, spawns the player.
##
## Host-authoritative: shared state changes only through request_* methods, which
## apply the change where Game.is_authority() is true. In single-player that's always.
## Networking later turns these into requests a client sends to the host.

## A block changed (after it was applied). Tile coords are wrapped.
signal block_changed(tile: Vector2i, old_id: int, new_id: int)
## A background wall changed. Tile coords are wrapped.
signal wall_changed(tile: Vector2i, old_id: int, new_id: int)

## Tile size in pixels. The Scholar is about 3 tiles wide and 8 tall.
const TILE := 8
const PLAYER_SCENE := preload("res://src/player/player.tscn")

@export_group("When run directly")
## Used only when this scene is run on its own (F6 in the editor, "Run Current Scene"),
## with no world chosen in the menu. Not saved.
@export var size_preset: WorldData.Size = WorldData.Size.SMALL
@export var world_seed: int = 1337
@export_enum("forest", "course") var world_kind := "forest"
@export_group("")
## Minutes between autosaves (saved worlds only). 0 turns autosave off.
@export var autosave_minutes := 5.0
## Chunks kept loaded around the camera, each direction.
@export var load_radius := Vector2i(2, 2)
## Max finished chunks turned into nodes per frame while moving (building happens on
## worker threads; this caps the main-thread part).
@export var chunks_per_frame: int = 1
## Seconds after the last hit before a damaged block heals back to full.
@export var block_heal_seconds := 5.0
## E interacts with things this close (tiles).
@export var interact_tiles := 4.0

var info: WorldInfo
var data: WorldData
var blocks: TileTypes
var walls: TileTypes
var generator: WorldGenerator
var renderer: ChunkRenderer
var lights: LightMap
var backdrop: Backdrop
var player: Player
var plants: PlantLayer
## The character playing (inventory). From Game.character, or a throwaway one.
var character: CharacterData
var item_user: ItemUser
var hud: Hud
var _drops: Node2D
var _cracks: CrackOverlay
## Damaged tiles: (x, y, layer 0 = block / 1 = wall) -> [damage, seconds until healed].
var _damage: Dictionary[Vector3i, Array] = {}
## Debug builds only (B toggles it); null otherwise.
var brush: DebugBrush
## Debug builds only (` toggles it); null otherwise.
var console: DevConsole
var _pause_menu: PauseMenu
var _autosave_left := 0.0


func _ready() -> void:
	Game.set_state(Game.State.LOADING)
	blocks = TileTypes.new(&"tiles")
	walls = TileTypes.new(&"walls")
	info = Game.world_info
	if info == null:
		info = WorldInfo.create("Scene run", size_preset, world_seed)
		info.kind = StringName(world_kind)
		info.temporary = true
	var size := info.dimensions()
	data = WorldData.new(size.x, size.y)
	generator = WorldGenerator.create(info.kind, blocks, walls, size.x, size.y, info.seed)
	data.generator = generator.generate_chunk
	if not info.temporary and not info.path.is_empty():
		data.saved = WorldSave.load_chunks(info.path, blocks, walls)

	backdrop = Backdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	renderer = ChunkRenderer.new()
	renderer.name = "Chunks"
	renderer.load_radius = load_radius
	renderer.chunks_per_frame = chunks_per_frame
	add_child(renderer)
	renderer.setup(self)
	plants = PlantLayer.new()
	plants.name = "Plants"
	add_child(plants)
	move_child(plants, renderer.get_index())  # behind the terrain
	plants.setup(self)
	if not info.temporary and not info.path.is_empty():
		plants.from_dict(WorldSave.read_extra(info.path, WorldSave.META_PLANTS))

	character = Game.character
	if character == null:
		character = CharacterData.create(CharacterData.DEFAULT_NAME)
		character.temporary = true
	if OS.is_debug_build():
		DevHeldItems.add_to(character.inventory)
		DevMagic.add_to(character)
	player = PLAYER_SCENE.instantiate() as Player
	player.world = self
	player.character = character
	var spawn := generator.spawn_tile()
	if DevCli.spawn_x >= 0:
		spawn = Vector2i(DevCli.spawn_x, generator.surface_at(DevCli.spawn_x))
	player.position = tile_to_world(spawn) + Vector2(TILE * 0.5, 0)
	renderer.load_all_now(player.position)
	add_child(player)
	teleport_player(player.position)
	character.inventory.changed.connect(player.refresh_held)
	character.magic_changed.connect(player.refresh_held)
	player.select_slot(0)
	_drops = Node2D.new()
	_drops.name = "Drops"
	add_child(_drops)
	_cracks = CrackOverlay.new()
	_cracks.name = "Cracks"
	_cracks.world = self
	add_child(_cracks)
	item_user = ItemUser.new()
	item_user.name = "ItemUser"
	item_user.world = self
	add_child(item_user)
	backdrop.surface_y = tile_to_world(generator.spawn_tile()).y - 60.0

	lights = LightMap.new()
	lights.name = "Lights"
	lights.world = self
	add_child(lights)
	renderer.chunks_changed.connect(lights.mark_dirty)
	block_changed.connect(func(_t: Vector2i, _o: int, _n: int) -> void: lights.mark_dirty())
	lights.rebuild_now()

	if OS.is_debug_build():
		brush = DebugBrush.new()
		brush.name = "DebugBrush"
		brush.world = self
		add_child(brush)

	_apply_zoom()
	Settings.changed.connect(func(section: String, key: String, _v: Variant) -> void:
		if section == "display" and key == "zoom":
			_apply_zoom())

	hud = Hud.new()
	hud.name = "Hud"
	hud.world = self
	add_child(hud)

	if OS.is_debug_build():
		console = DevConsole.new()
		console.name = "DevConsole"
		console.world = self
		add_child(console)

	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.world = self
	add_child(_pause_menu)
	_autosave_left = autosave_minutes * 60.0

	DebugOverlay.watch("world", "%s: %s %dx%d seed %d" % [info.name, info.kind, data.width, data.height, info.seed])
	Game.set_state(Game.State.PLAYING)
	EventBus.world_loaded.emit()


func _process(delta: float) -> void:
	if autosave_minutes > 0.0 and is_saved():
		_autosave_left -= delta
		if _autosave_left <= 0.0:
			_autosave_left = autosave_minutes * 60.0
			save()
	var cam := get_viewport().get_camera_2d()
	var center := cam.get_screen_center_position() if cam else player.position
	renderer.update(center)
	_heal_blocks(delta)
	DebugOverlay.watch("chunks", "%d loaded, %d generated, %d queued" % [renderer.loaded_count(),
		data.generated_chunk_count(), renderer.pending_count() + data.pending_generation_count()])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_pause_menu.toggle()
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and _key_pressed(event, KEY_F6):
		regenerate()
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and _key_pressed(event, KEY_F7):
		HeldItemLook.reload_types()  # after editing data/item_types/*.tres
		EventBus.debug_message.emit("Item types reloaded")
		get_viewport().set_input_as_handled()


func _key_pressed(event: InputEvent, key: Key) -> bool:
	var k := event as InputEventKey
	return k != null and k.pressed and not k.echo and k.physical_keycode == key


func _exit_tree() -> void:
	# Background jobs hold their own data, but finish them before the world goes away.
	if lights:
		lights.wait()
	if renderer:
		renderer.wait_all()
	if data:
		data.wait_all()
		save()
	elif character:
		character.save()
	EventBus.world_unloaded.emit()


## Camera zoom from Settings (display/zoom, slider in the pause menu).
func _apply_zoom() -> void:
	var cam := player.get_node_or_null(^"Camera") as Camera2D
	if cam:
		var z := Settings.camera_zoom()
		cam.zoom = Vector2(z, z)


## True for worlds that have a save file (not the test course or scripted runs).
func is_saved() -> bool:
	return info != null and not info.temporary and not info.path.is_empty()


## Writes the world file: its info and every chunk the player changed. Returns OK for
## temporary worlds without writing anything.
func save() -> Error:
	if character:
		var cerr := character.save()
		if cerr != OK:
			push_error("World: saving the character failed: %s" % error_string(cerr))
	if not is_saved():
		return OK
	info.last_played_unix = int(Time.get_unix_time_from_system())
	var t := Time.get_ticks_usec()
	var modified := data.modified_chunks()
	var coords: Array[Vector2i] = []
	for c in modified:
		coords.append(c.coord)
	var err := WorldSave.save(info.path, info, modified, blocks, walls,
		{WorldSave.META_PLANTS: plants.to_dict(coords)})
	PerfStats.add("world save (main)", Time.get_ticks_usec() - t)
	if err != OK:
		push_error("World: saving %s failed: %s" % [info.path, error_string(err)])
	else:
		EventBus.debug_message.emit("World saved")
	return err


## Debug (F6): rebuilds the generator from data/worldgen/forest.tres as saved on disk and
## regenerates every chunk the player hasn't edited. For tuning generation while playing:
## edit the .tres in the editor, save it, press F6 in the running game.
func regenerate() -> void:
	var size := info.dimensions()
	lights.wait()
	renderer.clear()
	data.discard_unmodified()
	plants.reset_unchanged()
	if info.kind == &"forest":
		generator = ForestGenerator.new(blocks, walls, size.x, size.y, info.seed, ForestGenerator.default_settings(true))
	else:
		generator = WorldGenerator.create(info.kind, blocks, walls, size.x, size.y, info.seed)
	data.generator = generator.generate_chunk
	var spawn := generator.spawn_tile()
	backdrop.surface_y = tile_to_world(spawn).y - 60.0
	# Stand the player on the new surface where they are.
	var col := wrap_tile(world_to_tile(player.global_position)).x
	var pos := tile_to_world(Vector2i(col, generator.surface_at(col))) + Vector2(TILE * 0.5, 0)
	renderer.load_all_now(pos)
	teleport_player(pos)
	lights.rebuild_now()
	EventBus.debug_message.emit("Regenerated from forest.tres")


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
	if tile.y >= data.height - 1:
		return false  # The bottom row is the world's floor: it can't be dug or replaced.
	var old := data.get_block(tile.x, tile.y)
	if old == id:
		return false
	data.set_block(tile.x, tile.y, id)
	renderer.refresh_tile(tile)
	block_changed.emit(wrap_tile(tile), old, id)
	return true


## Damages a block (mining, left click). Breaks it at its health: it drops its item and
## the tile becomes air. Damage heals after block_heal_seconds without hits. Returns
## true if the block broke.
func request_damage_block(tile: Vector2i, amount: float) -> bool:
	return _damage_tile(tile, amount, false)


## Damages a background wall (mining, right click). Works behind blocks too.
func request_damage_wall(tile: Vector2i, amount: float) -> bool:
	return _damage_tile(tile, amount, true)


func _damage_tile(tile: Vector2i, amount: float, wall: bool) -> bool:
	if not Game.is_authority():
		return false
	tile = wrap_tile(tile)
	var id := data.get_wall(tile.x, tile.y) if wall else data.get_block(tile.x, tile.y)
	if id <= 0 or tile.y >= data.height - 1:
		return false
	var def := (walls if wall else blocks).def(id)
	if def == null or def.unbreakable or def.health <= 0.0:
		return false
	if not wall and is_protected(tile):
		return false
	var key := Vector3i(tile.x, tile.y, 1 if wall else 0)
	var entry: Array = _damage.get(key, [0.0, 0.0])
	entry[0] = float(entry[0]) + amount
	entry[1] = block_heal_seconds
	if entry[0] < def.health:
		_damage[key] = entry
		return false
	_damage.erase(key)
	var removed := request_set_wall(tile, WorldData.AIR) if wall else request_set_block(tile, WorldData.AIR)
	if not removed:
		return false
	var drop := def.drop_item if def.drop_item != &"" else def.id
	if ItemData.find(drop) != null and def.drop_count > 0:
		var pos := tile_to_world(tile) + Vector2(TILE * 0.5, TILE * 0.5)
		pos.x += roundf((player.global_position.x - pos.x) / (data.width * TILE)) * data.width * TILE
		request_spawn_drop(drop, def.drop_count, pos, Vector2(randf_range(-2.0, 2.0), -4.0) * TILE)
	return true


## True when something depends on this block (a tree stands on it; chests later), so
## it can't be mined.
func is_protected(tile: Vector2i) -> bool:
	return plants != null and plants.supports(tile)


## 0..1: how damaged a block (or with `wall`, a background wall) is, for the cracks.
func block_damage(tile: Vector2i, wall: bool = false) -> float:
	tile = wrap_tile(tile)
	var entry: Array = _damage.get(Vector3i(tile.x, tile.y, 1 if wall else 0), [])
	if entry.is_empty():
		return 0.0
	var id := data.get_wall(tile.x, tile.y) if wall else data.get_block(tile.x, tile.y)
	var def := (walls if wall else blocks).def(id)
	return clampf(float(entry[0]) / def.health, 0.0, 1.0) if def and def.health > 0.0 else 0.0


## (x, y, layer) of every damaged tile; layer 1 = background wall.
func damaged_tiles() -> Array[Vector3i]:
	return _damage.keys()


func _heal_blocks(delta: float) -> void:
	for key: Vector3i in _damage.keys():
		var entry: Array = _damage[key]
		entry[1] = float(entry[1]) - delta
		var id := data.get_wall(key.x, key.y) if key.z == 1 else data.get_block(key.x, key.y)
		if entry[1] <= 0.0 or id <= 0:
			_damage.erase(key)


## Right click: interacts with whatever interactable is under `point` (doors, chests,
## later). Interactables are nodes in the "interactable" group with
## `interact_rect() -> Rect2` (world space) and `interact(player)`. Returns true if one
## was used.
func try_interact_at(point: Vector2, who: Player) -> bool:
	for node in get_tree().get_nodes_in_group(&"interactable"):
		if node.has_method(&"interact_rect") and (node.call(&"interact_rect") as Rect2).has_point(point):
			node.call(&"interact", who)
			return true
	return false


## E: interacts with the nearest interactable within interact_tiles of the player.
func try_interact_near(who: Player) -> bool:
	var best: Node = null
	var best_d := interact_tiles * TILE
	for node in get_tree().get_nodes_in_group(&"interactable"):
		if not node.has_method(&"interact_rect"):
			continue
		var d := (node.call(&"interact_rect") as Rect2).get_center().distance_to(who.chest())
		if d < best_d:
			best = node
			best_d = d
	if best:
		best.call(&"interact", who)
	return best != null


## Sets a background wall. Returns true if it changed.
func request_set_wall(tile: Vector2i, id: int) -> bool:
	if not Game.is_authority():
		return false
	if not data.in_bounds_y(tile.y) or id < 0 or id >= walls.size():
		return false
	var old := data.get_wall(tile.x, tile.y)
	if old == id:
		return false
	data.set_wall(tile.x, tile.y, id)
	renderer.refresh_tile(tile)
	wall_changed.emit(wrap_tile(tile), old, id)
	return true


## Puts an item stack in the world at `pos` with velocity `vel` (px/s). `thrown` = the
## player threw it (it can't be picked straight back up).
func request_spawn_drop(item_id: StringName, count: int, pos: Vector2, vel: Vector2 = Vector2.ZERO,
		thrown: bool = false) -> ItemDrop:
	if not Game.is_authority() or count <= 0 or ItemData.find(item_id) == null:
		return null
	if String(item_id).begins_with(ItemData.SPELL_PREFIX):
		return null  # spell shortcuts aren't things; throwing one just removes it
	var drop := ItemDrop.new()
	drop.setup(self, item_id, count, vel, thrown)
	drop.position = pos
	_drops.add_child(drop)
	return drop


func drop_count() -> int:
	return _drops.get_child_count() if _drops else 0
