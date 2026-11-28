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
## A tile object (rope, torch, furniture) changed. Tile coords are wrapped.
signal object_changed(tile: Vector2i, old_id: int, new_id: int)
## The player used a crafting station (anchor tile, wrapped).
signal station_opened(anchor: Vector2i)
## A Liquid Barrel was opened (right click or E).
signal liquid_opened(anchor: Vector2i)
## The player opened a container (a chest; anchor tile, wrapped).
signal container_opened(anchor: Vector2i)
## Right click or E on a magic bag (ItemBag).
signal bag_opened(bag: ItemBag)
## The player slept through the night (the HUD fades the screen).
signal slept
## An enemy was slain (its EnemyData id).
signal enemy_killed(enemy_id: StringName)

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

@export_group("Biome detection")
## Which biome you're in is counted from the blocks and walls around you, like
## Terraria: in a box this many tiles wide and tall, sampled every biome_sample_step...
@export var biome_box := Vector2i(48, 32)
@export var biome_sample_step := 2
## ...if at least this share of the ground there belongs to a biome (its blocks'
## TileDef.biome), you're in it. Too little ground (in the open sky): the surface
## biome under you counts instead.
@export_range(0.0, 1.0) var biome_share := 0.3
## The share is counted against at least this much of the box, so a few placed blocks
## in mostly open air can't turn the area (Terraria counts blocks, not shares).
@export_range(0.0, 1.0) var biome_min_ground := 0.6
@export_group("")
var _biome_cache: Dictionary = {}
## Chunks kept loaded around the camera, each direction.
@export var load_radius := Vector2i(2, 2)
## Max finished chunks turned into nodes per frame while moving (building happens on
## worker threads; this caps the main-thread part).
@export var chunks_per_frame: int = 1
## Seconds after the last hit before a damaged block heals back to full.
@export var block_heal_seconds := 5.0
## E interacts with things this close (tiles).
@export var interact_tiles := 6.0
## Crafting also uses what's in chests this close to you (tiles), after your inventory.
@export var craft_chest_tiles := 12.0
## Dev console `freecraft`: crafting needs no materials (and nothing is used up).
var free_crafting := false
## Dev console `instant_placement`: holding the button places every frame, no wait.
var instant_place := false
## Dev console `instant_break`: blocks, walls and trees break at once, every frame.
var instant_break := false
## Dev console `no_drop`: nothing drops (mined blocks, trees, loot).
var no_drop := false
## Dev console `no_los`: your spells, melee and slams don't need a clear line (they
## reach through blocks). Enemies still need one.
var no_los := false
## Dev console `infinite`: blocks, furniture, food and throwables aren't used up.
var infinite_items := false
## Loose items on the ground at most; past this the oldest disappear. 0 = no limit.
@export var max_drops := 400

@export_group("Spell scrolls")
## Scribing a scroll (Spell Weaving Table, Scrolls tab: only spells you know) uses its
## recipe's materials times this (1 = full cost; a skill can lower it later).
@export var scribe_cost_mult := 1.0
## Scribing needs at least this much max mana, by the spell's tier (1, 2, 3). Mana
## isn't used up.
@export var scroll_max_mana_by_tier: Array[float] = [100.0, 200.0, 300.0]
@export_group("")
## Seconds dead before you respawn at the world spawn.
@export var respawn_seconds := 3.0

var info: WorldInfo
var data: WorldData
var blocks: TileTypes
var walls: TileTypes
## Tile objects (data/objects): rope, torches.
var objects: TileTypes
var generator: WorldGenerator
var renderer: ChunkRenderer
var voxels: VoxelLayer
var sea_flora: SeaFlora
## Water in Liquid Barrels: wrapped anchor -> voxel cells.
var liquids: Dictionary[Vector2i, int] = {}
## Rain (Phase 81).
var weather: Weather
## How close (tiles) water has to be to count for crafting while you stand in or by it.
@export var craft_water_tiles := 2
var lights: LightMap
var backdrop: Backdrop
## Time of day (day and night, growth timers in days).
var clock: WorldClock
var player: Player
var plants: PlantLayer
var forage: ForageLayer
var object_layer: ObjectLayer
var hover_outline: HoverOutline
## The character playing (inventory). From Game.character, or a throwaway one.
var character: CharacterData
var item_user: ItemUser
var hud: Hud
## What you've explored (the map screen, N).
var world_map: WorldMap
var _drops: Node2D
var _bags: Node2D
var _enemies: Node2D
## Spawns enemies around the player.
var spawner: EnemySpawner
## Bed respawn points: character name -> bed anchor tile.
var spawn_points: Dictionary[String, Vector2i] = {}
## Where each character last stood in this world (feet, px), so entering it again puts
## you back there. Saved (meta "positions").
var player_spots: Dictionary[String, Vector2] = {}
## Conjured platforms by the tiles they cover (they count as platform tiles there).
var conjured: Dictionary[Vector2i, Node] = {}
## Enemies slain in this world, by enemy id (saved). Spawn conditions read these.
var kills: Dictionary[StringName, int] = {}
## Spell projectiles, damage numbers, dev dummies.
var effects: Node2D
var _cracks: CrackOverlay
## Storage of placed containers (chests): wrapped anchor tile -> its items. Saved with
## the world (meta "containers").
var containers: Dictionary[Vector2i, Inventory] = {}
## Items on display (tables, shelves, floors): wrapped tile -> item id. Saved with the
## world (meta "displays"). The tile holds the "display" object.
var displays: Dictionary[Vector2i, StringName] = {}
## Furniture placed facing left (anchor -> true), drawn mirrored. Saved (meta "flipped").
var flipped: Dictionary[Vector2i, bool] = {}
## Names given to chests (anchor -> name). Saved (meta "chest_names").
var chest_names: Dictionary[Vector2i, String] = {}
var _saved_map: Dictionary = {}
## Damaged tiles: (x, y, layer 0 = block / 1 = wall) -> [damage, seconds until healed].
var _damage: Dictionary[Vector3i, Array] = {}
## Debug builds only (B toggles it); null otherwise.
var brush: DebugBrush
## Debug builds only (` toggles it); null otherwise.
var console: DevConsole
## "No tile" for anchor lookups.
## Largest furniture footprint (tiles) object_anchor() searches.
const MAX_FURNITURE := Vector2i(8, 8)
const NO_TILE := Vector2i(-2147483647, -2147483647)
var _pause_menu: PauseMenu
var _autosave_left := 0.0


func _ready() -> void:
	if OS.is_debug_build():
		DevMagic._register()  # so `give dev_focus` and the Creative window have them
	Game.set_state(Game.State.LOADING)
	blocks = TileTypes.new(&"tiles")
	walls = TileTypes.new(&"walls")
	objects = TileTypes.new(&"objects")
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
		data.saved = WorldSave.load_chunks(info.path, blocks, walls, objects)
		var saved_shapes := WorldSave.read_extra(info.path, WorldSave.META_SHAPES)
		for key: String in saved_shapes:
			var sp := key.split(",")
			var sc := Vector2i(int(sp[0]), int(sp[1]))
			var bytes: Variant = saved_shapes[key]
			if data.saved.has(sc) and bytes is PackedByteArray and (bytes as PackedByteArray).size() == ChunkData.AREA:
				data.saved[sc].shapes = bytes

	clock = WorldClock.new()
	clock.name = "Clock"
	if is_saved():
		clock.from_dict(WorldSave.read_extra(info.path, WorldSave.META_TIME))
	add_child(clock)
	weather = Weather.new()
	weather.name = "Weather"
	weather.world = self
	if is_saved():
		weather.from_dict(WorldSave.read_extra(info.path, WorldSave.META_WEATHER))
	add_child(weather)
	backdrop = Backdrop.new()
	backdrop.name = "Backdrop"
	backdrop.clock = clock
	add_child(backdrop)
	renderer = ChunkRenderer.new()
	renderer.name = "Chunks"
	renderer.load_radius = load_radius
	renderer.chunks_per_frame = chunks_per_frame
	add_child(renderer)
	renderer.setup(self)
	voxels = VoxelLayer.new()
	voxels.name = "Voxels"
	voxels.z_index = VoxelLayer.Z  # over you, enemies and drops: you're in the water
	add_child(voxels)
	voxels.setup(self)
	sea_flora = SeaFlora.new()
	sea_flora.name = "SeaFlora"
	sea_flora.z_index = VoxelLayer.Z  # drawn right after the water (tinted under it)
	add_child(sea_flora)
	sea_flora.setup(self)
	object_layer = ObjectLayer.new()
	object_layer.name = "Objects"
	add_child(object_layer)
	object_layer.setup(self)
	plants = PlantLayer.new()
	plants.name = "Plants"
	add_child(plants)
	move_child(plants, renderer.get_index())  # behind the terrain
	plants.setup(self)
	forage = ForageLayer.new()
	forage.name = "Forage"
	add_child(forage)
	move_child(forage, plants.get_index() + 1)
	forage.setup(self)  # after the plants: trees, bushes and flowers keep their tiles
	if not info.temporary and not info.path.is_empty():
		var saved_forage := WorldSave.read_extra(info.path, WorldSave.META_FORAGE)
		forage.from_dict(saved_forage)
		plants.from_dict(WorldSave.read_extra(info.path, WorldSave.META_PLANTS), not saved_forage.is_empty())
		_containers_from_dict(WorldSave.read_extra(info.path, WorldSave.META_CONTAINERS))
		_displays_from_dict(WorldSave.read_extra(info.path, WorldSave.META_DISPLAYS))
		var names: Dictionary = WorldSave.read_extra(info.path, WorldSave.META_CHEST_NAMES)
		for key: String in names:
			var np := key.split(",")
			chest_names[Vector2i(int(np[0]), int(np[1]))] = String(names[key])
		_saved_map = WorldSave.read_extra(info.path, WorldSave.META_MAP)
		voxels.from_dict(WorldSave.read_extra(info.path, WorldSave.META_VOXELS))
		sea_flora.from_dict(WorldSave.read_extra(info.path, WorldSave.META_SEA_PLANTS))
		var saved_liquids: Dictionary = WorldSave.read_extra(info.path, WorldSave.META_LIQUIDS)
		for key: String in saved_liquids:
			var parts := key.split(",")
			if parts.size() == 2:
				liquids[Vector2i(int(parts[0]), int(parts[1]))] = int(saved_liquids[key])
		for key: String in WorldSave.read_extra(info.path, WorldSave.META_FLIPPED):
			var parts := key.split(",")
			flipped[Vector2i(int(parts[0]), int(parts[1]))] = true

	character = Game.character
	if character == null:
		# Running the world scene directly (tests, F6 in the editor): a throwaway
		# character with the dev kit.
		character = CharacterData.create_dev(CharacterData.DEFAULT_NAME)
		character.temporary = true
	player = PLAYER_SCENE.instantiate() as Player
	player.world = self
	player.character = character
	character.apply_empower()  # spells are looked up with their Empower ranks
	player.look = character.make_look()
	var spawn := generator.spawn_tile()
	if DevCli.spawn_x >= 0:
		spawn = Vector2i(DevCli.spawn_x, generator.surface_at(DevCli.spawn_x))
	player.position = tile_to_world(spawn) + Vector2(TILE * 0.5, 0)
	renderer.load_all_now(player.position)
	add_child(player)
	teleport_player(player.position)
	player.hunger_on = info.hunger
	player.thirst_on = info.thirst
	player.clock = clock
	if character.health > 0.0:
		player.health = minf(character.health, player.max_health)
	if character.hunger >= 0.0:
		player.hunger = minf(character.hunger, player.max_hunger)
	if character.thirst >= 0.0:
		player.thirst = minf(character.thirst, player.max_thirst)
	player.died.connect(_on_player_died)
	character.equipment_changed.connect(player.apply_stats)
	player.apply_stats.call_deferred()
	character.inventory.changed.connect(player.refresh_held)
	character.magic_changed.connect(player.refresh_held)
	player.select_slot(0)
	_drops = Node2D.new()
	_drops.name = "Drops"
	add_child(_drops)
	_bags = Node2D.new()
	_bags.name = "Bags"
	add_child(_bags)
	_enemies = Node2D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)
	hover_outline = HoverOutline.new()
	hover_outline.name = "HoverOutline"
	add_child(hover_outline)
	hover_outline.setup(self)
	spawner = EnemySpawner.new()
	spawner.name = "Spawner"
	spawner.world = self
	add_child(spawner)
	if is_saved():
		var sp: Dictionary = WorldSave.read_extra(info.path, WorldSave.META_SPAWNS)
		for who: String in sp:
			var a: Array = sp[who]
			spawn_points[who] = Vector2i(int(a[0]), int(a[1]))
		var k: Dictionary = WorldSave.read_extra(info.path, WorldSave.META_KILLS)
		for id: String in k:
			kills[StringName(id)] = int(k[id])
		var spots: Dictionary = WorldSave.read_extra(info.path, WorldSave.META_POSITIONS)
		for who: String in spots:
			var a: Array = spots[who]
			player_spots[who] = Vector2(float(a[0]), float(a[1]))
		if DevCli.spawn_x < 0:
			_place_at_saved_spot()
	if is_saved():
		for d: Dictionary in WorldSave.read_extra(info.path, WorldSave.META_BAGS).get("list", []):
			_bags.add_child(ItemBag.from_dict(self, d))
	effects = Node2D.new()
	effects.name = "Effects"  # projectiles, damage numbers, dev dummies
	add_child(effects)
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
	wall_changed.connect(func(_t: Vector2i, _o: int, _n: int) -> void: lights.mark_dirty())
	object_changed.connect(func(_t: Vector2i, _o: int, _n: int) -> void: lights.mark_dirty())
	# Torches pop off when what holds them goes away.
	block_changed.connect(func(t: Vector2i, _o: int, _n: int) -> void: _check_supports(t))
	wall_changed.connect(func(t: Vector2i, _o: int, _n: int) -> void: _check_supports(t))
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

	world_map = WorldMap.new()
	world_map.name = "WorldMap"
	world_map.setup(self)
	world_map.from_dict(_saved_map)
	_saved_map = {}
	add_child(world_map)

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
	if backdrop and generator:
		var t := world_to_tile(center)
		backdrop.dark_target = clampf(biome_amount(t, &"dark_forest") / maxf(biome_share, 0.01), 0.0, 1.0)
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


## Pause menu > Quit Game > Quit without saving: leaving doesn't save (anything the
## autosave already wrote stays).
var skip_save := false


func _exit_tree() -> void:
	ItemData.set_empowered([])
	# Background jobs hold their own data, but finish them before the world goes away.
	if lights:
		lights.wait()
	if renderer:
		renderer.wait_all()
	if data:
		data.wait_all()
		if not skip_save:
			save()
	elif character and not skip_save:
		character.save()
	EventBus.world_unloaded.emit()


## Camera zoom from Settings (display/zoom, slider in the pause menu).
func _apply_zoom() -> void:
	var cam := player.get_node_or_null(^"Camera") as Camera2D
	if cam:
		var z := Settings.camera_zoom()
		cam.zoom = Vector2(z, z)
		# Zoomed out, the screen shows more chunks: load enough to fill it plus one.
		var half := get_viewport().get_visible_rect().size / (z * 2.0)
		var need := Vector2i(ceili(half.x / (ChunkData.SIZE * TILE)) + 1, ceili(half.y / (ChunkData.SIZE * TILE)) + 1)
		renderer.load_radius = Vector2i(maxi(load_radius.x, need.x), maxi(load_radius.y, need.y))


## True for worlds that have a save file (not the test course or scripted runs).
func is_saved() -> bool:
	return info != null and not info.temporary and not info.path.is_empty()


## Writes the world file: its info and every chunk the player changed. Returns OK for
## temporary worlds without writing anything.
func save() -> Error:
	if character:
		character.health = player.health if player and not player.dead else -1.0
		character.hunger = player.hunger if player and not player.dead else -1.0
		character.thirst = player.thirst if player and not player.dead else -1.0
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
		{WorldSave.META_PLANTS: plants.to_dict(coords), WorldSave.META_FORAGE: forage.to_dict(coords),
			WorldSave.META_CONTAINERS: _containers_to_dict(), WorldSave.META_DISPLAYS: _displays_to_dict(),
			WorldSave.META_FLIPPED: _flipped_to_dict(), WorldSave.META_CHEST_NAMES: _names_to_dict(),
			WorldSave.META_BAGS: {"list": bags_to_list()}, WorldSave.META_TIME: clock.to_dict(),
			WorldSave.META_SPAWNS: _spawns_to_dict(), WorldSave.META_KILLS: _kills_to_dict(),
			WorldSave.META_POSITIONS: _spots_to_dict(), WorldSave.META_SHAPES: _shapes_to_dict(modified), WorldSave.META_VOXELS: voxels.to_dict(), WorldSave.META_LIQUIDS: _liquids_to_dict(),
			WorldSave.META_SEA_PLANTS: sea_flora.to_dict(), WorldSave.META_WEATHER: weather.to_dict(),
			WorldSave.META_MAP: world_map.to_dict() if world_map else {}}, objects)
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
	forage.reset_unchanged()
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


# --- dying -----------------------------------------------------------------------------

## The player died: their items go into a magic bag where they fell (unless the world
## keeps items), and they respawn at the world spawn after respawn_seconds.
func _on_player_died(cause: StringName) -> void:
	var inv := character.inventory
	var mode := info.death_drop
	if mode != WorldInfo.DeathDrop.KEEP:
		var from := Inventory.HOTBAR if mode == WorldInfo.DeathDrop.BACKPACK else 0
		var worn: Array[StringName] = []
		if mode in [WorldInfo.DeathDrop.ALL, WorldInfo.DeathDrop.PERMADEATH]:
			for slot: StringName in [CharacterData.SLOT_HEAD, CharacterData.SLOT_CHEST, CharacterData.SLOT_LEGS] \
					+ CharacterData.SLOT_ACCESSORIES:
				if character.equipment.get(slot, &"") != &"":
					worn.append(character.equip(slot, &""))  # armor and accessories come off
		var bag_inv := Inventory.new(inv.size + worn.size())
		for i in range(from, inv.size):
			if not inv.is_empty(i) and not String(inv.ids[i]).begins_with(ItemData.SPELL_PREFIX):
				bag_inv.set_slot(i, inv.ids[i], inv.counts[i], inv.metas[i])
				inv.clear(i)
		for k in worn.size():
			if worn[k] != &"":
				bag_inv.set_slot(inv.size + k, worn[k], 1)
		inv.changed.emit()
		if not bag_inv.is_all_empty():
			request_spawn_bag(bag_inv, character.name, player.chest())
	# Buffs, summons and lights end.
	player.clear_buffs()
	for n in get_tree().get_nodes_in_group(&"familiars"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group(&"light_sources"):
		if n is LightOrb:
			n.queue_free()
	if mode == WorldInfo.DeathDrop.PERMADEATH:
		character.ghost = true
		character.save()
	player.visible = false
	player.set_physics_process(false)
	EventBus.player_died.emit(cause)
	if hud:
		hud.set_open(false)
	get_tree().create_timer(respawn_seconds).timeout.connect(respawn_player)


## Back at your bed (or the world spawn if you have none, or it's gone) with full
## health, hunger and mana.
func respawn_player() -> void:
	if not is_instance_valid(player) or not player.dead:
		return
	if character and character.ghost:
		Game.quit_to_menu()  # permadeath: no coming back
		return
	var pos := respawn_position()
	renderer.load_all_now(pos)
	teleport_player(pos)
	player.revive()
	player.visible = true
	player.set_physics_process(true)


## Entering the world: back where this character last stood here. If that spot is
## blocked now (built over or filled in), at their bed instead (or the world spawn), so
## you can't teleport into a sealed room by leaving and coming back.
func _place_at_saved_spot() -> void:
	var who := character.name if character else ""
	var pos := respawn_position()
	if player_spots.has(who):
		var spot: Vector2 = player_spots[who]
		renderer.load_all_now(spot)
		if body_fits(spot):
			pos = spot
	renderer.load_all_now(pos)
	teleport_player(pos)


## Whether the player's body (3 x 8 tiles, standing with feet at `feet`) is clear of
## solid blocks and closed doors.
func body_fits(feet: Vector2) -> bool:
	var x0 := floori((feet.x - TILE * 1.4) / TILE)
	var x1 := floori((feet.x + TILE * 1.4) / TILE)
	var y0 := floori((feet.y - TILE * 7.8) / TILE)
	var y1 := floori((feet.y - 1.0) / TILE)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if blocks_hits(Vector2i(x, y)):
				return false
	return true


func _spots_to_dict() -> Dictionary:
	var out := {}
	if character and player and not player.dead:
		player_spots[character.name] = player.global_position
	elif character and player and player.dead:
		player_spots.erase(character.name)  # died: next time, your bed
	for who: String in player_spots:
		out[who] = [player_spots[who].x, player_spots[who].y]
	return out


## Where the player respawns: next to their bed if it's still there, else the world
## spawn.
func respawn_position() -> Vector2:
	var who := character.name if character else ""
	if spawn_points.has(who):
		var a: Vector2i = spawn_points[who]
		var def := object_at(a)
		if def and def.bed and object_anchor(a) == a:
			return tile_to_world(a) + Vector2(def.width_tiles * TILE * 0.5, TILE)
		spawn_points.erase(who)
		EventBus.debug_message.emit("Your bed is gone: back to the world spawn")
	return tile_to_world(generator.spawn_tile()) + Vector2(TILE * 0.5, 0)


func _spawns_to_dict() -> Dictionary:
	var out := {}
	for who in spawn_points:
		out[who] = [spawn_points[who].x, spawn_points[who].y]
	return out


## A bed: sets the respawn point, and at night (with no enemies close) sleeps until
## morning.
func use_bed(anchor: Vector2i) -> void:
	spawn_points[character.name] = wrap_tile(anchor)
	if clock == null or not clock.is_night():
		EventBus.debug_message.emit("Spawn point set. You can only sleep at night.")
		return
	if not enemies_near(player.global_position, sleep_enemy_tiles).is_empty():
		EventBus.debug_message.emit("Spawn point set. You can't sleep with enemies nearby.")
		return
	sleep_until_morning()


## Skips to an hour after sunrise. Plants grow for the skipped time and you get as
## hungry as you would have.
func sleep_until_morning() -> void:
	var from_h := clock.hour()
	var to_h := clock.sunrise_hour + 1.0
	var hours := fposmod(to_h - from_h, 24.0)
	var seconds := clock.days(hours / 24.0)
	clock.advance(seconds / maxf(clock.speed, 0.0001))
	plants.advance(seconds)
	forage.advance(seconds)
	if player.hunger_on:
		var per_second := player.max_hunger / maxf(clock.days(player.hunger_full_days), 1.0)
		player.hunger = maxf(player.hunger - per_second * seconds, 1.0)
	if player.thirst_on:
		var tps := player.max_thirst / maxf(clock.days(player.thirst_full_days), 1.0)
		player.thirst = maxf(player.thirst - tps * seconds, 1.0)
	EventBus.debug_message.emit("You slept until morning. Spawn point set.")
	slept.emit()


# --- enemies -------------------------------------------------------------------------

## Within this many tiles, enemies keep you awake.
@export var sleep_enemy_tiles := 20.0


## Whether a station of a kind (&"spell_weaving") is within `tiles` of a point (its
## middle; tile objects only).
func station_near(kind: StringName, at: Vector2, tiles: float = -1.0) -> bool:
	var r := (interact_tiles + 4.0) if tiles < 0.0 else tiles
	var c := world_to_tile(at)
	var n := ceili(r) + 6
	for y in range(c.y - n, c.y + n + 1):
		for x in range(c.x - n, c.x + n + 1):
			var t := wrap_tile(Vector2i(x, y))
			if not data.in_bounds_y(t.y):
				continue
			var def := object_at(t)
			if def and def.station == kind and object_anchor(t) == t:
				var mid := tile_to_world(Vector2i(x, y)) + Vector2(def.width_tiles * TILE * 0.5, 0)
				if mid.distance_to(at) <= (r + def.width_tiles * 0.5) * TILE:
					return true
	return false


## Light Orb: one orb follows the player; casting again replaces it (fresh timer).
## Wisp (light_placed): a new one each cast, steered while the button is held; past
## light_max of them, the oldest goes.
func summon_light_orb(spell: SpellData) -> LightOrb:
	var same: Array[LightOrb] = []
	for old in get_tree().get_nodes_in_group(&"light_sources"):
		var o := old as LightOrb
		if o == null or o.is_queued_for_deletion():
			continue
		if spell.light_placed:
			if o.placed and o.spell_id == spell.id:
				same.append(o)
		elif not o.placed and o.spell_id == spell.id:
			o.queue_free()  # recast: the new one replaces it (a Light Orb and a Floating Torch can both be out)
	while spell.light_placed and same.size() >= maxi(spell.light_max, 1):
		same.pop_front().queue_free()
	var orb := LightOrb.new()
	effects.add_child(orb)
	orb.setup(self, spell)
	lights.mark_dirty()
	return orb


## A melee summon (Summon Slime): the enemy for its Evolve rank, fighting for you.
func _summon_ally(spell: SpellData, power: float, used: Array[int]) -> Enemy:
	var rank := character.empower_rank(spell.id, &"evolve") if character else 0
	var ranks := spell.summon_enemy_ranks
	var d := Registry.get_def(&"enemies", ranks[clampi(rank, 0, ranks.size() - 1)]) as EnemyData
	var first := Registry.get_def(&"enemies", ranks[0]) as EnemyData
	if d == null:
		spell_problem = "Unknown summon"
		return null
	# A later form hits harder by as much as that slime does (Blue 9 vs Green 6).
	var dmg := spell.damage * power * (d.contact_damage / maxf(first.contact_damage if first else d.contact_damage, 1.0))
	var e := Enemy.new()
	e.setup_summon(self, d, spell, dmg)
	while e.slot in used:
		e.slot += 1
	var p := player.global_position if player else Vector2.ZERO
	e.position = Vector2(near_player_x(p.x - (player.facing if player else 1) * 2.0 * TILE), p.y - TILE)
	_enemies.add_child(e)
	EventBus.sound_requested.emit(&"slime_hop", e.global_position)
	return e


## The lights and familiars a spell has out right now (Light Orb, Wisps, Familiar).
func summons_of(spell: SpellData) -> Array[Node]:
	var out: Array[Node] = []
	if spell == null:
		return out
	var group := &"familiars" if spell.cast == SpellData.Cast.SUMMON else &"light_sources"
	for n in get_tree().get_nodes_in_group(group):
		if n.is_queued_for_deletion():
			continue
		if n is LightOrb and (n as LightOrb).spell_id == spell.id:
			out.append(n)
		elif n is Familiar and (n as Familiar).spell == spell:
			out.append(n)
		elif n is Enemy and (n as Enemy).summon_spell == spell:
			out.append(n)  # Summon Slime
	return out


## Seconds left on the newest of a spell's lights or familiars (0 = none out).
## Sends a spell's summons or lights away now (right click in the buff row).
func request_dismiss_summons(spell: SpellData) -> void:
	if not Game.is_authority():
		return
	for n in summons_of(spell):
		n.queue_free()


func summon_time_left(spell: SpellData) -> float:
	var best := 0.0
	for n in summons_of(spell):
		best = maxf(best, float(n.get(&"time_left")))
	return best


## Casts the world-placed spells (zone, ward, familiar, conjured platform, ore sense) at
## `at` (the cursor). Returns the new node, or null with a reason in `problem`.
var spell_problem := ""


func request_spell_effect(spell: SpellData, at: Vector2, power: float) -> Node:
	spell_problem = ""
	if not Game.is_authority():
		return null
	match spell.cast:
		SpellData.Cast.ZONE:
			# Up to `max_active` circles of this spell; a new one replaces the oldest.
			var zones := effects.get_children().filter(func(n: Node) -> bool:
				return n is SpellZone and (n as SpellZone).spell == spell and not n.is_queued_for_deletion())
			while zones.size() >= maxi(spell.max_active, 1):
				zones.pop_front().queue_free()
			var z := SpellZone.new()
			effects.add_child(z)
			z.setup(self, spell, at, power)
			return z
		SpellData.Cast.WARD:
			var ground := _ground_under(at, 12)
			if ground == Vector2.INF:
				spell_problem = "No ground there"
				return null
			var wards := get_tree().get_nodes_in_group(&"spell_wards").filter(
				func(n: Node) -> bool: return not n.is_queued_for_deletion())
			while wards.size() >= maxi(spell.max_active, 1):
				wards.pop_front().queue_free()
			var wd := SpellWard.new()
			effects.add_child(wd)
			wd.setup(self, spell, ground, power)
			return wd
		SpellData.Cast.SUMMON:
			# One summon, plus the gear's summon_slots (Forest Spirit Pendant): past that,
			# the oldest goes. Summon damage gear makes it hit harder.
			var limit := 1 + maxi(int(player.stat(&"summon_slots")), 0) if player else 1
			limit += maxi(spell.summon_bonus_slots, 0)  # Empower: Limit
			var out := get_tree().get_nodes_in_group(&"familiars").filter(
				func(n: Node) -> bool: return not n.is_queued_for_deletion())
			while out.size() >= limit:
				out.pop_front().queue_free()
			if player:
				power *= 1.0 + player.stat(&"summon_damage")
			var used: Array[int] = []
			for f: Node in out:
				used.append(int(f.get(&"slot")))
			if not spell.summon_enemy_ranks.is_empty():
				return _summon_ally(spell, power, used)
			var fam := Familiar.new()
			effects.add_child(fam)
			fam.setup(self, spell, power)
			while fam.slot in used:
				fam.slot += 1
			return fam
		SpellData.Cast.CONJURE:
			var t := world_to_tile(at)
			var left := t - Vector2i(spell.conjure_tiles / 2, 0)
			for i in spell.conjure_tiles:
				var c := left + Vector2i(i, 0)
				if is_solid(c) or conjured.has(wrap_tile(c)):
					spell_problem = "No room there"
					return null
			var plat := ConjuredPlatform.new()
			effects.add_child(plat)
			plat.setup(self, spell, left, spell.conjure_tiles)
			return plat
		SpellData.Cast.SENSE:
			var sense := OreSense.new()
			effects.add_child(sense)
			sense.setup(self, spell, player.chest() if player else at)
			return sense
	return null


## The Command spell (Phase 73): the enemy your summons go after (null = the nearest, as
## usual). Ends when it dies.
var summon_target: Enemy = null


## Your summons' commanded target, if it's still alive (else null).
func commanded_target() -> Enemy:
	if summon_target != null and (not is_instance_valid(summon_target) or summon_target.is_queued_for_deletion()
			or summon_target.health <= 0.0):
		summon_target = null
	return summon_target


## Command: the enemy at (or within 2 tiles of) `at` becomes your summons' target. At
## nothing, the target is cleared. Returns the new target (or null).
func command_summons(at: Vector2) -> Enemy:
	var best: Enemy = null
	var best_d := 2.0 * TILE
	for e in enemies():
		var r := e.hit_rect()
		# The point as seen from the enemy's side of the world's wrap.
		var p := Vector2(e.global_position.x + e._wrapped_dx(at.x), at.y)
		var d := 0.0 if r.grow(2.0).has_point(p) else (r.get_center() - p).length()
		if d < best_d:
			best_d = d
			best = e
	summon_target = best
	if best:
		FloatingText.spawn(_enemies, best.global_position + Vector2(0, -best.data.size.y - 12), "Target!", Color("ff8a6a"))
		EventBus.sound_requested.emit(&"craft", best.global_position)
	return best


## The top of the first solid tile at or below `at` (within `max_tiles`), or INF.
func _ground_under(at: Vector2, max_tiles: int) -> Vector2:
	var t := world_to_tile(at)
	for i in max_tiles:
		var c := t + Vector2i(0, i)
		if is_solid(c):
			return Vector2(at.x, c.y * TILE)
	return Vector2.INF


## The object with an aura (a campfire) whose radius reaches `pos`, or null.
func aura_near(pos: Vector2) -> ObjectDef:
	var r := 0
	for id in range(1, objects.size()):
		var od := objects.def(id) as ObjectDef
		if od and od.aura_radius > 0.0:
			r = maxi(r, ceili(od.aura_radius) + 4)
	if r == 0:
		return null
	var t := world_to_tile(pos)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var tile := t + Vector2i(dx, dy)
			var id := data.get_object(tile.x, tile.y)
			if id <= 0:
				continue
			var od := objects.def(id) as ObjectDef
			if od == null or od.aura_radius <= 0.0:
				continue
			# Measured from the middle of the object.
			var mid := Vector2(tile * TILE) + Vector2(od.width_tiles * TILE * 0.5, -od.height_tiles * TILE * 0.5 + TILE)
			if mid.distance_to(pos) <= od.aura_radius * TILE:
				return od
	return null


## Moving light sources (Light Orb, a Forest Spirit): [position in tiles (Vector2, the
## middle of a tile is +0.5), radius, color] for the light map. Between tiles, its light
## is shared over the nearest four, so it glides.
func dynamic_lights() -> Array[Array]:
	var out: Array[Array] = []
	for n in get_tree().get_nodes_in_group(&"light_sources"):
		if n.is_queued_for_deletion() or not n.has_method(&"light_tile"):
			continue
		var at := Vector2(n.call(&"light_tile")) + Vector2(0.5, 0.5)
		if n.has_method(&"light_point"):
			at = n.call(&"light_point")
		out.append([at, float(n.get(&"radius")), n.get(&"color") as Color])
	return out


## How many of an enemy have been slain in this world.
func kill_count(enemy_id: StringName) -> int:
	return kills.get(enemy_id, 0)


## An enemy died (Enemy calls this). Host only.
func record_kill(enemy_id: StringName) -> void:
	if not Game.is_authority():
		return
	kills[enemy_id] = kill_count(enemy_id) + 1
	enemy_killed.emit(enemy_id)


func _kills_to_dict() -> Dictionary:
	var out := {}
	for id in kills:
		out[String(id)] = kills[id]
	return out


func request_spawn_enemy(data: EnemyData, pos: Vector2) -> Enemy:
	if not Game.is_authority() or data == null:
		return null
	var e := Enemy.new()
	e.setup(self, data)
	e.position = Vector2(near_player_x(pos.x), pos.y)
	_enemies.add_child(e)
	return e


func enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	if _enemies == null:
		return out
	for e in _enemies.get_children():
		if e is Enemy and not e.is_queued_for_deletion() and not (e as Enemy).is_summon():
			out.append(e)
	return out


## Hostile enemies around (critters counted apart: critter_count).
func enemy_count() -> int:
	var n := 0
	for e in enemies():
		if not e.data.is_critter():
			n += 1
	return n


func critter_count() -> int:
	var n := 0
	for e in enemies():
		if e.data.is_critter():
			n += 1
	return n


func enemies_near(pos: Vector2, tiles: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies():
		if absf(e._wrapped_dx(pos.x)) <= tiles * TILE and absf(e.global_position.y - pos.y) <= tiles * TILE:
			out.append(e)
	return out


## A tile inside a building: a built (player placed) back wall behind it.
## Biggest spawn_safe_tiles of any object (cached), so the scan box stays small.
var _safe_reach := -1.0


## Whether something near a tile keeps enemies from spawning there (a bed or a campfire
## within its spawn_safe_tiles).
func near_spawn_safe(tile: Vector2i) -> bool:
	if _safe_reach < 0.0:
		_safe_reach = 0.0
		for id in range(1, objects.size()):
			var od := objects.def(id) as ObjectDef
			if od:
				_safe_reach = maxf(_safe_reach, od.spawn_safe_tiles)
	var r := ceili(_safe_reach)
	if r <= 0:
		return false
	for y in range(tile.y - r, tile.y + r + 1):
		if not data.in_bounds_y(y):
			continue
		for x in range(tile.x - r, tile.x + r + 1):
			var id := data.get_object(x, y)
			if id <= 0:
				continue
			var od := objects.def(id) as ObjectDef
			if od and od.spawn_safe_tiles > 0.0 and Vector2(x - tile.x, y - tile.y).length() <= od.spawn_safe_tiles:
				return true
	return false


func is_indoors(tile: Vector2i) -> bool:
	var w := data.get_wall(wrap_tile(tile).x, tile.y) if data.in_bounds_y(tile.y) else 0
	if w <= 0:
		return false
	var def := walls.def(w) as TileDef
	return def != null and def.built


## Tosses a magic bag up from `pos` (it falls and settles like a tombstone).
func request_spawn_bag(inv: Inventory, who: String, pos: Vector2) -> ItemBag:
	if not Game.is_authority():
		return null
	var bag := ItemBag.new()
	bag.setup(self, inv, who, Vector2(randf_range(-3.0, 3.0), -10.0) * TILE)
	bag.position = pos
	_bags.add_child(bag)
	return bag


func bags() -> Array[ItemBag]:
	var out: Array[ItemBag] = []
	for b in _bags.get_children():
		if b is ItemBag and not b.is_queued_for_deletion():
			out.append(b)
	return out


func bags_to_list() -> Array:
	var out: Array = []
	for b in bags():
		if not b.inventory.is_all_empty():
			out.append(b.to_dict())
	return out


## Moves the player instantly (spawn, respawn, rewrapping x later). Use this, not
## `player.position =`: with physics interpolation on, a raw jump would be drawn as a
## one-tick slide across the screen, and the smoothed camera would pan the whole way.
func teleport_player(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	player.reset_fall()
	player.reset_physics_interpolation()  # Propagates to the sprite and camera.
	var cam := player.get_node_or_null(^"Camera") as Camera2D
	if cam:
		cam.reset_smoothing()


# --- coordinates -------------------------------------------------------------

## Pixel position to tile coords (unwrapped x; data access wraps it).
func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


## Tile coords to the pixel position of the tile's top-left corner.
## The copy of world x `x` (px) closest to the player. The world wraps sideways and the
## player's x isn't wrapped (walk left from spawn and it goes below 0), so things made
## at a wrapped position (a bush's berries, a new slime) are moved next to the player
## instead of a whole world away.
func near_player_x(x: float) -> float:
	if player == null or data == null:
		return x
	var w := float(data.width * TILE)
	return player.global_position.x + wrapf(x - player.global_position.x, -w * 0.5, w * 0.5)


func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile * TILE)


func wrap_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(data.wrap_x(tile.x), tile.y)


# --- queries -----------------------------------------------------------------

func block_at(p: Vector2) -> int:
	var t := world_to_tile(p)
	return data.get_block(t.x, t.y)


func collision_at(p: Vector2) -> int:
	if not conjured.is_empty() and conjured.has(wrap_tile(world_to_tile(p))):
		return TileDef.Collision.PLATFORM
	return blocks.collision(block_at(p))


func is_climbable_at(p: Vector2) -> bool:
	var t := world_to_tile(p)
	return blocks.climbable(data.get_block(t.x, t.y)) or objects.climbable(data.get_object(t.x, t.y))


## The tile object at a tile (null = none).
func object_at(tile: Vector2i) -> ObjectDef:
	var id := data.get_object(tile.x, tile.y)
	return objects.def(id) as ObjectDef if id > 0 else null


## True for a solid block (or below the world).
func is_solid(tile: Vector2i) -> bool:
	var b := data.get_block(tile.x, tile.y)
	return b == WorldData.OUT_OF_BOUNDS or (b > 0 and blocks.collision(b) == TileDef.Collision.SOLID)


## True when a tile stops a melee hit: a solid block or a closed door.
func blocks_hits(tile: Vector2i) -> bool:
	if is_solid(tile):
		return true
	var a := object_anchor(tile)
	if a == NO_TILE:
		return false
	var def := object_at(a)
	return def != null and def.blocks_movement


## True when nothing blocks the straight line between two points (tiles stepped along
## it every half tile, the end included; the start doesn't count).
## `line_clear` for the player's own actions: always clear with the dev `no_los` on.
func player_sight(from: Vector2, to: Vector2) -> bool:
	return no_los or line_clear(from, to)


func line_clear(from: Vector2, to: Vector2) -> bool:
	var steps := ceili(from.distance_to(to) / (TILE * 0.5))
	for i in range(1, steps + 1):
		if blocks_hits(world_to_tile(from.lerp(to, float(i) / steps))):
			return false
	return true


## Whether an object can go in a tile: no object there yet, no solid block, and
## something to hold it (see ObjectDef.needs_support).
func can_place_object(tile: Vector2i, def: ObjectDef) -> bool:
	if def != null and def.style == ObjectDef.Style.FURNITURE:
		return _can_place_furniture(tile, def)
	if def == null or not data.in_bounds_y(tile.y) or data.get_object(tile.x, tile.y) > 0 or is_solid(tile):
		return false
	if not _room_above(tile, def):
		return false
	if def.needs_support:
		return _supported(tile)
	# Anything next to it, or a wall behind.
	if data.get_wall(tile.x, tile.y) > 0:
		return true
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if data.get_block(tile.x + d.x, tile.y + d.y) != WorldData.AIR or data.get_object(tile.x + d.x, tile.y + d.y) > 0:
			return true
	return false


# --- furniture (multi-tile objects) ----------------------------------------------

## The tiles a piece of furniture covers, from its anchor (bottom-left).
static func footprint(anchor: Vector2i, def: ObjectDef) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in def.height_tiles:
		for dx in def.width_tiles:
			out.append(anchor + Vector2i(dx, -dy))
	return out


## The anchor of the object at a tile (the tile itself for single-tile objects; for
## furniture, its bottom-left tile). NONE when there's no object.
func object_anchor(tile: Vector2i) -> Vector2i:
	tile = wrap_tile(tile)
	var id := data.get_object(tile.x, tile.y)
	if id <= 0:
		return NO_TILE
	if not (objects.def(id) as ObjectDef).filler:
		return tile
	for dy in MAX_FURNITURE.y:
		for dx in MAX_FURNITURE.x:
			var a := wrap_tile(tile + Vector2i(-dx, dy))
			var aid := data.get_object(a.x, a.y)
			var def := objects.def(aid) as ObjectDef if aid > 0 else null
			if def and not def.filler and def.style == ObjectDef.Style.FURNITURE \
					and dx < def.width_tiles and dy < def.height_tiles:
				return a
	return NO_TILE


## Like object_anchor, but also finds an object whose sprite reaches past its footprint
## over this tile (an open door's face), so any visible part can be clicked.
func object_anchor_visual(tile: Vector2i) -> Vector2i:
	var a := object_anchor(tile)
	if a != NO_TILE:
		return a
	tile = wrap_tile(tile)
	for dy in MAX_FURNITURE.y:
		for dx in range(-MAX_FURNITURE.x, MAX_FURNITURE.x + 1):
			var b := object_anchor(tile + Vector2i(dx, dy))
			if b == NO_TILE:
				continue
			var def := object_at(b)
			if def and def.sprite_width_px > 0:
				for t in sprite_tiles(b, def):
					if wrap_tile(t) == tile:
						return b
	return NO_TILE


## The object at a tile, looking through furniture fillers to the furniture itself.
func object_def_at(tile: Vector2i) -> ObjectDef:
	var a := object_anchor(tile)
	return object_at(a) if a != NO_TILE else null


func _can_place_furniture(anchor: Vector2i, def: ObjectDef) -> bool:
	for t in footprint(anchor, def):
		if not data.in_bounds_y(t.y) or is_solid(t) or data.get_object(t.x, t.y) > 0:
			return false
		if plants and plants.blocks_placement(t + Vector2i(0, 1)):
			return false
	if def.needs_floor:
		var floored := true
		for dx in def.width_tiles:
			var below := anchor + Vector2i(dx, 1)
			var b := data.get_block(below.x, below.y)
			if not (is_solid(below) or (b > 0 and blocks.collision(b) == TileDef.Collision.PLATFORM)
					or is_flat_top(below)):
				floored = false
				break
		if not floored:
			if not def.floor_or_wall:
				return false
			for t in footprint(anchor, def):
				if data.get_wall(t.x, t.y) <= 0:
					return false
	if def.needs_wall:
		for t in footprint(anchor, def):
			if data.get_wall(t.x, t.y) <= 0:
				return false
	for col in def.hang_points:
		if not is_solid(anchor + Vector2i(col, -def.height_tiles)):
			return false
	return true


## Whether a tile is the top row of furniture with a flat top (ObjectDef.flat_top):
## other furniture can stand on it.
func is_flat_top(tile: Vector2i) -> bool:
	var a := object_anchor(tile)
	if a == NO_TILE:
		return false
	var def := object_at(a)
	return def != null and def.flat_top and wrap_tile(tile).y == a.y - (def.height_tiles - 1)


## Furniture standing on top of this one (flat tops), else NO_TILE.
func _resting_on(anchor: Vector2i, def: ObjectDef) -> Vector2i:
	if not def.flat_top:
		return NO_TILE
	for dx in def.width_tiles:
		var top := anchor + Vector2i(dx, -def.height_tiles)
		var other := object_anchor(top)
		if other != NO_TILE and other != wrap_tile(anchor):
			var od := object_at(other)
			if od and od.needs_floor and not od.display:  # displayed items just fall off
				return other
	return NO_TILE


## Whether the furniture anchored at a tile is drawn mirrored (placed facing left).
func is_flipped(anchor: Vector2i) -> bool:
	return flipped.has(wrap_tile(anchor))


## Whether this object flips when placed facing left (furniture, not doors).
static func can_flip(def: ObjectDef) -> bool:
	return def != null and def.flips and def.style == ObjectDef.Style.FURNITURE and not def.display \
		and def.toggles_to == &"" and def.toggles_to_left == &""


func _names_to_dict() -> Dictionary:
	var out := {}
	for t: Vector2i in chest_names:
		out["%d,%d" % [t.x, t.y]] = chest_names[t]
	return out


func _shapes_to_dict(chunks: Array[ChunkData]) -> Dictionary:
	var out := {}
	for c in chunks:
		if c.shapes.size() == ChunkData.AREA and c.shapes.count(0) < ChunkData.AREA:
			out["%d,%d" % [c.coord.x, c.coord.y]] = c.shapes
	return out


## The Shaping Spell: sets a tile's shape byte (ChunkData.shapes) and redraws it.
func request_set_shape(tile: Vector2i, shape: int) -> bool:
	if not Game.is_authority():
		return false
	var b := data.get_block(tile.x, tile.y)
	var bdef := blocks.def(b) if b > 0 else null
	if bdef and bdef.unbreakable and (shape & 7) != (data.get_shape(tile.x, tile.y) & 7):
		return false  # Abyssal Stone keeps its whole shape (no gap for the sea to leak through)
	if not data.set_shape(tile.x, tile.y, shape):
		return false
	renderer.refresh_tile(tile)
	lights.mark_dirty()
	return true


func _flipped_to_dict() -> Dictionary:
	var out := {}
	for t: Vector2i in flipped:
		out["%d,%d" % [t.x, t.y]] = true
	return out


## Places an object with its anchor at `anchor`: furniture fills its footprint.
## `facing_left`: furniture that can flip is mirrored. Returns true if placed.
func request_place_object(anchor: Vector2i, id: int, facing_left: bool = false) -> bool:
	if not Game.is_authority() or id <= 0 or id >= objects.size():
		return false
	var def := objects.def(id) as ObjectDef
	if not can_place_object(anchor, def):
		return false
	if def.style != ObjectDef.Style.FURNITURE:
		return request_set_object(anchor, id)
	var filler := objects.index_of(&"filler")
	for t in footprint(anchor, def):
		request_set_object(t, filler)
	if facing_left and can_flip(def):
		flipped[wrap_tile(anchor)] = true
	else:
		flipped.erase(wrap_tile(anchor))
	request_set_object(anchor, id)
	if def.container_slots > 0:
		containers[wrap_tile(anchor)] = _new_container(def)
	if def.catches_rain > 0.0:
		liquids[wrap_tile(anchor)] = 0  # listed even when empty, so the rain finds it
	return true


## Removes the object at a tile (the whole piece of furniture) and drops its item.
## A container with something in it stays (returns false).
func request_remove_object(tile: Vector2i) -> bool:
	if not Game.is_authority():
		return false
	var a := object_anchor(tile)
	if a == NO_TILE:
		return false
	var def := object_at(a)
	if def == null:
		return false
	var store: Inventory = containers.get(a)
	if store and not store.is_all_empty():
		EventBus.debug_message.emit("Empty the %s first" % def.display_name.to_lower())
		return false
	var on_top := _resting_on(a, def)
	if on_top != NO_TILE:
		EventBus.debug_message.emit("Take the %s off the top first" % object_at(on_top).display_name.to_lower())
		return false
	if def.display:
		return request_take_display(a, null)
	if def.style == ObjectDef.Style.FURNITURE:
		for t in footprint(a, def):
			request_set_object(t, WorldData.AIR)
	else:
		request_set_object(a, WorldData.AIR)
	containers.erase(a)
	_spill_barrel(a, def)
	flipped.erase(wrap_tile(a))
	chest_names.erase(wrap_tile(a))
	_drop_for(def, a)
	if def.display_surface:
		# What was on display on top falls off.
		for dx in def.width_tiles:
			var top := a + Vector2i(dx, -def.height_tiles)
			if object_at(top) and object_at(top).display:
				request_take_display(top, null)
	return true


# --- items on display ---------------------------------------------------------------

## Whether an item can be put on display at a tile: the tile is empty (no block, no
## object) and stands on a solid block, a platform, or the top of a table or shelf
## (display_surface; not stations).
func can_display_at(tile: Vector2i, item: ItemData) -> bool:
	tile = wrap_tile(tile)
	if item == null or not item.can_display() or not data.in_bounds_y(tile.y) or objects.index_of(&"display") <= 0:
		return false
	if data.get_block(tile.x, tile.y) != WorldData.AIR or data.get_object(tile.x, tile.y) > 0:
		return false
	var below := tile + Vector2i.DOWN
	var b := data.get_block(below.x, below.y)
	if is_solid(below) or (b > 0 and blocks.collision(b) == TileDef.Collision.PLATFORM):
		return true
	var under := object_def_at(below)
	return under != null and under.display_surface


## Puts one of `item_id` on display at a tile. The caller takes it from the inventory.
func request_place_display(tile: Vector2i, item_id: StringName) -> bool:
	if not Game.is_authority() or not can_display_at(tile, ItemData.find(item_id)):
		return false
	EventBus.sound_requested.emit(&"block_place", tile_to_world(tile))
	tile = wrap_tile(tile)
	displays[tile] = item_id
	request_set_object(tile, objects.index_of(&"display"))
	return true


## Takes the item off display: into `who`'s inventory (dropped if it's full), or
## dropped on the ground when `who` is null.
func request_take_display(tile: Vector2i, who: Player) -> bool:
	tile = wrap_tile(tile)
	if not Game.is_authority() or not displays.has(tile):
		return false
	var id: StringName = displays[tile]
	displays.erase(tile)
	request_set_object(tile, WorldData.AIR)
	EventBus.sound_requested.emit(&"item_pickup", tile_to_world(tile))
	var left := 1
	if who and who.character:
		left = who.pick_up(id, 1)
		if left == 0:
			EventBus.item_picked_up.emit(id, 1)
	if left > 0:
		request_spawn_drop(id, left, tile_to_world(tile) + Vector2(TILE * 0.5, TILE * 0.5), Vector2(0, -3.0) * TILE)
	return true


## The item on display at a tile, or null.
func displayed_item(tile: Vector2i) -> ItemData:
	return ItemData.find(displays.get(wrap_tile(tile), &""))


## Right click with an item in hand on a free spot: puts one on display. False if the
## spot can't take it (then the click does whatever else it would).
func try_place_display(point: Vector2, who: Player) -> bool:
	if who == null or who.held_item == null or who.stowed or who.held_count() <= 0:
		return false
	if point.distance_to(who.chest()) > (interact_tiles + 2.0) * TILE:
		return false
	var item := who.held_item
	var tile := world_to_tile(point)
	if not can_display_at(tile, item):
		return false
	if not who.take_held():  # the hotbar slot, the mouse stack or a Z X C item
		return false
	return request_place_display(tile, item.id)


## Where an item on display is drawn (world px): bottom-centered on its tile, at its
## size on the ground.
func display_rect(tile: Vector2i, item: ItemData) -> Rect2:
	var s := item.drop_pixels() if item else 10.0
	return Rect2(Vector2((tile.x + 0.5) * TILE - s * 0.5, (tile.y + 1) * TILE - s), Vector2(s, s))


func _displays_to_dict() -> Dictionary:
	var out := {}
	for t: Vector2i in displays:
		out["%d,%d" % [t.x, t.y]] = String(displays[t])
	return out


func _displays_from_dict(d: Dictionary) -> void:
	for key: String in d:
		var parts := key.split(",")
		displays[Vector2i(int(parts[0]), int(parts[1]))] = StringName(String(d[key]))


## Right click / E on a door: open or close it (not while standing in its doorway).
func request_toggle_object(tile: Vector2i) -> bool:
	var a := object_anchor(tile)
	var def := object_at(a) if a != NO_TILE else null
	if not Game.is_authority() or def == null or def.toggles_to == &"":
		return false
	# A door swings away from the player: open to the left when they're on its right.
	var choices: Array[StringName] = [def.toggles_to]
	if def.toggles_to_left != &"":
		var hinge_x := (a.x + def.hinge_offset + 0.5) * TILE
		var on_right := false
		if player:
			var px := player.global_position.x
			px -= roundf((px - hinge_x) / (data.width * TILE)) * data.width * TILE
			on_right = px > hinge_x
		if on_right:
			choices.push_front(def.toggles_to_left)
		else:
			choices.append(def.toggles_to_left)
	var old_tiles := footprint(a, def)
	for choice in choices:
		var to := objects.index_of(choice)
		var to_def := objects.def(to) as ObjectDef if to > 0 else null
		if to_def == null:
			continue
		var to_anchor := a + Vector2i(def.hinge_offset - to_def.hinge_offset, 0)
		if _can_toggle_into(to_anchor, to_def, old_tiles):
			for t in old_tiles:
				request_set_object(t, WorldData.AIR)
			var filler := objects.index_of(&"filler")
			for t in footprint(to_anchor, to_def):
				request_set_object(t, filler)
			request_set_object(to_anchor, to)
			EventBus.sound_requested.emit(&"door", tile_to_world(a))
			return true
	return false


## The tiles an object's sprite covers beyond its footprint (ObjectDef.sprite_width_px
## and sprite_align), or none.
static func sprite_tiles(anchor: Vector2i, def: ObjectDef) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var extra := ceili(float(def.sprite_width_px) / TILE) - def.width_tiles if def.sprite_width_px > 0 else 0
	if extra <= 0:
		return out
	var columns: Array[int] = []
	match def.sprite_align:
		ObjectDef.SpriteAlign.FROM_LEFT:
			for i in extra:
				columns.append(def.width_tiles + i)
		ObjectDef.SpriteAlign.FROM_RIGHT:
			for i in extra:
				columns.append(-1 - i)
		_:
			for i in ceili(extra / 2.0):
				columns.append(def.width_tiles + i)
				columns.append(-1 - i)
	for dx in columns:
		for dy in def.height_tiles:
			out.append(anchor + Vector2i(dx, -dy))
	return out


## Whether a toggled object fits: new tiles are free (the old footprint doesn't count),
## and something solid doesn't close on the player.
func _can_toggle_into(anchor: Vector2i, def: ObjectDef, old_tiles: Array[Vector2i]) -> bool:
	for t in footprint(anchor, def):
		if t in old_tiles:
			continue
		if not data.in_bounds_y(t.y) or is_solid(t) or data.get_object(t.x, t.y) > 0:
			return false
	# A sprite wider than the footprint (an open door's face) needs that room too: no
	# blocks or other objects where it swings.
	for t in sprite_tiles(anchor, def):
		if t in old_tiles:
			continue
		if not data.in_bounds_y(t.y) or is_solid(t) or data.get_object(t.x, t.y) > 0:
			return false
	if def.blocks_movement and player:
		var rect := Rect2(Vector2(anchor.x * TILE, (anchor.y - def.height_tiles + 1) * TILE),
			Vector2(def.width_tiles * TILE, def.height_tiles * TILE))
		var body := player.body_rect()
		body.position.x -= roundf((body.position.x - rect.position.x) / (data.width * TILE)) * data.width * TILE
		if rect.intersects(body):
			return false  # standing in the doorway
	return true


## A chest's name: the one given to it, else its kind ("Chest").
func container_name(anchor: Vector2i) -> String:
	var def := object_at(anchor)
	var given: String = chest_names.get(wrap_tile(anchor), "")
	return given if given != "" else (def.display_name if def else "Chest")


## Names a chest ("" = back to its kind's name).
func request_rename_chest(anchor: Vector2i, chest_name: String) -> void:
	if not Game.is_authority():
		return
	var t := wrap_tile(anchor)
	if chest_name.strip_edges() == "":
		chest_names.erase(t)
	else:
		chest_names[t] = chest_name.strip_edges()


## The chests within `tiles` of a point, closest first (their inventories).
func chests_near(point: Vector2, tiles: float) -> Array[Inventory]:
	var found: Array = []
	for a: Vector2i in containers:
		var def := object_at(a)
		var w := def.width_tiles if def else 1
		var h := def.height_tiles if def else 1
		var mid := tile_to_world(a) + Vector2(w, -h + 1) * TILE * 0.5
		mid.x += roundf((point.x - mid.x) / (data.width * TILE)) * data.width * TILE  # the world wraps
		var d := mid.distance_to(point)
		if d <= tiles * TILE:
			found.append([d, containers[a]])
	found.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var out: Array[Inventory] = []
	for f: Array in found:
		out.append(f[1])
	return out


# --- water ----------------------------------------------------------------------------

## Water in the Liquid Barrel at a tile (its anchor), in voxel cells.
func barrel_water(tile: Vector2i) -> int:
	var a := object_anchor(tile)
	return liquids.get(wrap_tile(a), 0) if a != NO_TILE else 0


## Adds (or with a negative `delta` takes) water in a Liquid Barrel, within its
## capacity. Returns how much it actually moved.
func request_barrel_water(tile: Vector2i, delta: int) -> int:
	if not Game.is_authority():
		return 0
	var a := object_anchor(tile)
	var def := object_at(a) if a != NO_TILE else null
	if def == null or def.liquid_capacity <= 0:
		return 0
	var key := wrap_tile(a)
	var have: int = liquids.get(key, 0)
	var after := clampi(have + delta, 0, def.liquid_capacity)
	if after == 0 and def.catches_rain <= 0.0:
		liquids.erase(key)
	else:
		liquids[key] = after
	return after - have


## A broken barrel spills its water around where it stood.
func _spill_barrel(a: Vector2i, def: ObjectDef) -> void:
	var key := wrap_tile(a)
	var have: int = liquids.get(key, 0)
	liquids.erase(key)
	if have > 0 and def:
		var box := Rect2i(a.x - 1, a.y - def.height_tiles - 2, def.width_tiles + 2, def.height_tiles + 3)
		voxels.pour_liquid(box, have)


func _liquids_to_dict() -> Dictionary:
	var out := {}
	for a: Vector2i in liquids:
		out["%d,%d" % [a.x, a.y]] = liquids[a]
	return out


## The tiles around you that count as "standing in or next to water" for crafting.
func _water_box_near(point: Vector2) -> Rect2i:
	var body := player.body_rect() if player else Rect2(point, Vector2.ZERO)
	var lo := world_to_tile(body.position) - Vector2i.ONE * craft_water_tiles
	var hi := world_to_tile(body.end) + Vector2i.ONE * craft_water_tiles
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## Liquid Barrels within `tiles` of a point (closest first): their anchors.
func barrels_near(point: Vector2, tiles: float) -> Array[Vector2i]:
	var found: Array = []
	for a: Vector2i in liquids:
		var def := object_at(a)
		if def == null:
			continue
		var mid := tile_to_world(a) + Vector2(def.width_tiles, -def.height_tiles + 1) * TILE * 0.5
		mid.x += roundf((point.x - mid.x) / (data.width * TILE)) * data.width * TILE
		var d := mid.distance_to(point)
		if d <= tiles * TILE:
			found.append([d, a])
	found.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var out: Array[Vector2i] = []
	for f: Array in found:
		out.append(f[1])
	return out


## Water crafting can use here: water you stand in or next to, Liquid Barrels within
## crafting reach, and your Siphon Liquid reservoir.
func water_for_crafting(point: Vector2) -> int:
	var n := voxels.liquid_in(_water_box_near(point))
	for a in barrels_near(point, craft_chest_tiles):
		n += liquids.get(a, 0)
	if character:
		n += character.water
	return n


## Uses water for crafting, in that order (the water around you, barrels, then your
## reservoir, which you carry). Returns how much it took.
func take_water_for_crafting(point: Vector2, count: int) -> int:
	var taken := voxels.take_liquid(_water_box_near(point), count)
	for a in barrels_near(point, craft_chest_tiles):
		if taken >= count:
			break
		taken -= request_barrel_water(a, -(count - taken))
	if taken < count and character:
		var k := mini(character.water, count - taken)
		character.water -= k
		taken += k
	return taken


## The container (chest) at a tile, or null.
func container_at(tile: Vector2i) -> Inventory:
	var a := object_anchor(tile)
	return containers.get(a) if a != NO_TILE else null


func _containers_to_dict() -> Dictionary:
	var out := {}
	for a: Vector2i in containers:
		out["%d,%d" % [a.x, a.y]] = containers[a].to_dict()
	return out


func _containers_from_dict(d: Dictionary) -> void:
	for key: String in d:
		var parts := key.split(",")
		var at := Vector2i(int(parts[0]), int(parts[1]))
		var def := object_at(at)
		var inv := _new_container(def) if def and def.container_slots > 0 else Inventory.new(Inventory.DEFAULT_SIZE)
		inv.from_dict(d[key])
		containers[at] = inv


## A container's storage: its slots, and for special storage what fits and how much.
## Its changes redraw the object (fill looks).
func _new_container(def: ObjectDef) -> Inventory:
	var inv := Inventory.new(def.container_slots)
	inv.accepts_tag = def.container_accepts
	inv.stack_cap = def.container_stack_cap
	inv.stack_mult = def.container_stack_mult
	if def.fill_look != ObjectDef.FillLook.NONE:
		inv.changed.connect(func() -> void:
			if object_layer:
				object_layer.redraw_all())
	return inv


## Tall objects (a 2-tile torch) need the tiles above them free of solid blocks.
func _room_above(tile: Vector2i, def: ObjectDef) -> bool:
	for k in range(1, def.height_tiles):
		if is_solid(tile - Vector2i(0, k)):
			return false
	return true


## Torch support: a solid block below or beside, or a back wall behind.
func _supported(tile: Vector2i) -> bool:
	return is_solid(tile + Vector2i.DOWN) or is_solid(tile + Vector2i.LEFT) or is_solid(tile + Vector2i.RIGHT) \
		or data.get_wall(tile.x, tile.y) > 0 or (plants != null and plants.trunk_at(tile))


## Objects at and around a tile that lost their support pop off (a tree cut down).
func check_supports(tile: Vector2i) -> void:
	_check_supports(tile)


## After a block or wall changed: objects there or next to it that lost their support
## (or got buried by a solid block) pop off as items.
func _check_supports(tile: Vector2i) -> void:
	for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var t := wrap_tile(tile + d)
		var def := object_at(t)
		if def == null or def.style == ObjectDef.Style.FURNITURE:
			continue  # furniture protects its floor instead (is_protected)
		if (def.needs_support and not _supported(t)) or is_solid(t) or not _room_above(t, def):
			_break_object(t, def)


func _break_object(tile: Vector2i, _def: ObjectDef) -> void:
	request_remove_object(tile)


## Places or removes (AIR) a tile object. Returns true if it changed.
func request_set_object(tile: Vector2i, id: int) -> bool:
	if not Game.is_authority():
		return false
	if not data.in_bounds_y(tile.y) or id < 0 or id >= objects.size():
		return false
	var old := data.get_object(tile.x, tile.y)
	if old == id:
		return false
	data.set_object(tile.x, tile.y, id)
	object_changed.emit(wrap_tile(tile), old, id)
	return true


# --- requests (host-authoritative) -------------------------------------------

## Sets a foreground block. Returns true if it changed.
## `quiet`: no place or break sound (sand falling apart and settling).
func request_set_block(tile: Vector2i, id: int, quiet := false) -> bool:
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
	if quiet:
		return true
	if old != WorldData.AIR and id == WorldData.AIR:
		EventBus.sound_requested.emit(&"block_break", tile_to_world(tile))
	elif old == WorldData.AIR and id != WorldData.AIR:
		EventBus.sound_requested.emit(&"block_place", tile_to_world(tile))
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
	# The sound goes where the tile is drawn (unwrapped, near the camera), not at its
	# wrapped position, which can be a whole world away from the listener.
	EventBus.sound_requested.emit(&"mine_hit", tile_to_world(tile))
	tile = wrap_tile(tile)
	var id := data.get_wall(tile.x, tile.y) if wall else data.get_block(tile.x, tile.y)
	# Front-layer mining takes a tile object first when there's no solid block there
	# (rope on a platform, a torch). Objects break in one hit.
	if not wall and data.get_object(tile.x, tile.y) > 0 and not is_solid(tile):
		return request_remove_object(tile)
	if not wall and id == WorldData.AIR and voxels.has_minable(tile):
		return voxels.request_damage(tile, INF if instant_break else amount)
	if not wall and id == WorldData.AIR and sea_flora and sea_flora.kelp_at(tile):
		return sea_flora.request_harvest(tile)  # kelp cuts in one hit
	if id <= 0 or tile.y >= data.height - 1:
		return false
	var def := (walls if wall else blocks).def(id)
	if def == null or def.unbreakable or def.health <= 0.0:
		return false
	if not wall and is_protected(tile):
		return false
	if instant_break:
		amount = INF
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
	_break_dust(def, tile, wall)
	_drop_for(def, tile)
	return true


## Places a block where a tile of voxel cells may be (sand grains of its own kind become
## part of it; other cells make room). Like request_set_block otherwise.
func request_place_block(tile: Vector2i, id: int) -> bool:
	if not Game.is_authority() or data.get_block(wrap_tile(tile).x, tile.y) != WorldData.AIR:
		return false
	voxels.clear_for_block(tile)
	return request_set_block(tile, id)


## How many of `item` placing it at `tile` takes (see VoxelLayer.place_cost).
func place_cost(tile: Vector2i, item: ItemData, wall := false) -> int:
	return maxi(item.place_units, 1) if wall else voxels.place_cost(tile, item)


## An explosion at `center` (the Bomb): sand and Sand Bricks lose a round bite (voxel
## cells), other blocks within the radius break whole (with drops) if `power` is
## enough, and everything damageable nearby is hurt, you included. Walls are left.
func request_explode(center: Vector2, radius_tiles: float, damage: float, power: int, from: Node = null) -> void:
	if not Game.is_authority():
		return
	var radius := radius_tiles * TILE
	voxels.explode(center, radius)
	var lo := Vector2i(floori((center.x - radius) / TILE), floori((center.y - radius) / TILE))
	var hi := Vector2i(floori((center.x + radius) / TILE), floori((center.y + radius) / TILE))
	for ty in range(lo.y, hi.y + 1):
		for tx in range(lo.x, hi.x + 1):
			var t := Vector2i(tx, ty)
			if Vector2((tx + 0.5) * TILE, (ty + 0.5) * TILE).distance_to(center) > radius:
				continue
			var b := data.get_block(wrap_tile(t).x, ty)
			if b <= 0:
				continue
			var def := blocks.def(b)
			if def == null or def.min_mining_power > power or def.unbreakable:
				continue
			_damage_tile(t, INF, false)
	var reach := radius * 1.25
	var falloff := func(r: Rect2) -> float:
		var dist := r.get_center().distance_to(center) - r.size.length() * 0.25
		return -1.0 if dist > reach else damage * clampf(1.0 - dist / reach, 0.25, 1.0)
	if player and damage > 0.0:
		var hurt: float = falloff.call(player.body_rect())
		if hurt > 0.0:
			player.take_damage(hurt, &"explosion", center, 6.0)
	for node in get_tree().get_nodes_in_group(&"damageable"):
		if node == player or not is_instance_valid(node) or not node.has_method(&"hit_rect") or damage <= 0.0:
			continue
		var amount: float = falloff.call(node.call(&"hit_rect"))
		if amount < 0.0:
			continue
		node.call(&"take_damage", amount, from if from else player)
		if node.has_method(&"knock_back"):
			node.call(&"knock_back", center, 6.0, true)
	var ring := SpellEffect.spawn(effects, SpellEffect.Kind.BURST, center, Vector2.ZERO, Color(1, 0.75, 0.4))
	if ring:
		ring.scale = Vector2.ONE * maxf(radius_tiles / 2.0, 1.0)
	BreakDust.spawn(effects, center, Color(0.45, 0.42, 0.4))
	EventBus.sound_requested.emit(&"bomb", center)


## A puff of dust in the broken tile's colors (darker for a back wall).
func _break_dust(def: TileDef, tile: Vector2i, wall: bool) -> void:
	if effects == null or def.terrain.is_empty():
		return
	var c := ChunkRenderer.terrain_color(def.terrain)
	if wall:
		c = c.darkened(0.3)
	var pos := tile_to_world(tile) + Vector2(TILE * 0.5, TILE * 0.5)
	if player:
		pos.x += roundf((player.global_position.x - pos.x) / (data.width * TILE)) * data.width * TILE
	BreakDust.spawn(effects, pos, c)


## A broken tile's item drop, popping out of the tile.
func _drop_for(def: TileDef, tile: Vector2i) -> void:
	var drop := def.drop_item if def.drop_item != &"" else def.id
	if ItemData.find(drop) == null or def.drop_count <= 0:
		return
	var pos := tile_to_world(tile) + Vector2(TILE * 0.5, TILE * 0.5)
	if player:
		pos.x += roundf((player.global_position.x - pos.x) / (data.width * TILE)) * data.width * TILE
	request_spawn_drop(drop, def.drop_count, pos, Vector2(randf_range(-2.0, 2.0), -4.0) * TILE)
	if def.bonus_drop_item != &"" and randf() < def.bonus_drop_chance:
		request_spawn_drop(def.bonus_drop_item, 1, pos, Vector2(randf_range(-2.0, 2.0), -5.0) * TILE)


## True when something depends on this block (a tree stands on it; chests later), so
## it can't be mined.
func is_protected(tile: Vector2i) -> bool:
	if plants != null and plants.supports(tile):
		return true
	var above := object_def_at(tile + Vector2i.UP)
	return above != null and above.needs_floor


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


## Right click: interacts with what's under `point`: furniture (open a door, a chest, a
## crafting station), something lying on the grass (pick it up), or an interactable
## node (group "interactable", with interact_rect() and interact(player)). Must be
## within interact_tiles of the player. Returns true if something was used.
## Whether usable furniture (a door, chest, station, bed, display) is at a point.
func usable_object_at(point: Vector2) -> bool:
	if interactable_node_at(point):
		return true  # a magic bag on top counts too
	var a := object_anchor_visual(world_to_tile(point))
	if a == NO_TILE:
		return false
	var def := object_at(a)
	return def != null and _usable(def)


func try_interact_at(point: Vector2, who: Player) -> bool:
	if who and point.distance_to(who.chest()) > (interact_tiles + 2.0) * TILE:
		return false
	# Interactable nodes (the magic bag) sit on top of furniture, so they come first.
	var node := interactable_node_at(point)
	if node:
		node.call(&"interact", who)
		return true
	var tile := world_to_tile(point)
	var a := object_anchor_visual(tile)
	if a != NO_TILE and _interact_object(a):
		return true
	if forage and forage.request_pick_up(tile, who):
		return true
	if plants and plants.request_pick_up(tile, who):
		return true
	return false


## The interactable node (a magic bag) under a point, or null.
func interactable_node_at(point: Vector2) -> Node:
	for node in get_tree().get_nodes_in_group(&"interactable"):
		if node.has_method(&"interact_rect") and (node.call(&"interact_rect") as Rect2).has_point(point):
			return node
	return null


## E: interacts with the nearest usable furniture (or pickup, or interactable node)
## within interact_tiles of the player.
func try_interact_near(who: Player) -> bool:
	var center := who.chest()
	var ct := world_to_tile(center)
	var best := NO_TILE
	var best_d := interact_tiles * TILE
	var r := ceili(interact_tiles) + 1
	for dy in range(-r, r + 5):
		for dx in range(-r, r + 1):
			var a := object_anchor(ct + Vector2i(dx, dy))
			var def := object_at(a) if a != NO_TILE else null
			if def == null or not _usable(def):
				continue
			var mid := Vector2((ct.x + dx + 0.5) * TILE, (ct.y + dy + 0.5) * TILE)
			var d := mid.distance_to(center)
			if d < best_d:
				best = a
				best_d = d
	if best != NO_TILE:
		return _interact_object(best)
	var feet := world_to_tile(who.global_position)
	var reach := ceili(interact_tiles)
	var stick := forage.nearest(feet, reach) if forage else ForageLayer.NONE
	var bush := plants.nearest_ripe_bush(feet, reach) if plants else PlantLayer.NONE
	if stick != ForageLayer.NONE and (bush == PlantLayer.NONE or Vector2(stick - feet).length() <= Vector2(bush - feet).length()):
		return forage.request_pick_up(stick + Vector2i.UP, who)
	if bush != PlantLayer.NONE:
		return plants.request_pick_up(bush + Vector2i.UP, who)
	var best_node: Node = null
	var node_d := interact_tiles * TILE
	for node in get_tree().get_nodes_in_group(&"interactable"):
		if not node.has_method(&"interact_rect"):
			continue
		var d := (node.call(&"interact_rect") as Rect2).get_center().distance_to(center)
		if d < node_d:
			best_node = node
			node_d = d
	if best_node:
		best_node.call(&"interact", who)
	return best_node != null


static func _usable(def: ObjectDef) -> bool:
	return def.toggles_to != &"" or def.container_slots > 0 or def.station != &"" or def.bed or def.display \
		or def.right_click_takes or def.seat or def.liquid_capacity > 0


func _interact_object(anchor: Vector2i) -> bool:
	var def := object_at(anchor)
	if def == null or not _usable(def):
		return false
	if def.right_click_takes:
		request_remove_object(anchor)  # a torch: off the wall, it drops
	elif def.display:
		request_take_display(anchor, player)
	elif def.bed:
		use_bed(anchor)
	elif def.seat:
		player.sit_on(anchor)
	elif def.toggles_to != &"":
		if not request_toggle_object(anchor):
			EventBus.debug_message.emit("Something's in the way" if def.blocks_movement else "Can't close: you're in the doorway")
	elif def.container_slots > 0:
		container_opened.emit(wrap_tile(anchor))
	elif def.liquid_capacity > 0:
		liquid_opened.emit(wrap_tile(anchor))
	else:
		station_opened.emit(wrap_tile(anchor))
	return true


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
## Tele Grab: loose items within `radius` (px) of `portal` fly into it and come out at
## the player's hand. Returns how many drops were caught this frame.
func tele_grab(portal: Vector2, radius: float, speed: float) -> int:
	if forage:
		forage.request_lift_near(portal, radius)  # sticks, rocks, mushrooms come loose too
	var n := 0
	var w := float(data.width * TILE)
	for c in _drops.get_children():
		var d := c as ItemDrop
		if d == null or d.is_queued_for_deletion():
			continue
		var off := d.global_position + Vector2(0, -4) - portal
		off.x = wrapf(off.x, -w * 0.5, w * 0.5)
		if off.length() <= radius:
			d.grab(portal, speed)
			n += 1
	return n


func request_spawn_drop(item_id: StringName, count: int, pos: Vector2, vel: Vector2 = Vector2.ZERO,
		thrown: bool = false) -> ItemDrop:
	if no_drop and not thrown:
		return null  # dev `no_drop` (throwing still works)
	if not Game.is_authority() or count <= 0 or ItemData.find(item_id) == null:
		return null
	if String(item_id).begins_with(ItemData.SPELL_PREFIX):
		return null  # spell shortcuts aren't things; throwing one just removes it
	var drop := ItemDrop.new()
	drop.setup(self, item_id, count, vel, thrown)
	drop.position = out_of_ground(Vector2(near_player_x(pos.x), pos.y))
	_drops.add_child(drop)
	# Too many loose items: the oldest go (Terraria keeps at most 400).
	while max_drops > 0 and _drops.get_child_count() > max_drops:
		var oldest := _drops.get_child(0)
		_drops.remove_child(oldest)
		oldest.queue_free()
	return drop


## A point inside solid ground moved straight up to rest on top of it (the first open
## tile above, up to `max_tiles`), so things that drop there aren't buried: a tree
## felled into a hillside, loot from an enemy against a wall. Open points are unchanged.
func out_of_ground(pos: Vector2, max_tiles: int = 40) -> Vector2:
	var t := world_to_tile(pos + Vector2(0.0, -1.0))
	if collision_at(pos + Vector2(0.0, -1.0)) != TileDef.Collision.SOLID:
		return pos
	for i in range(1, max_tiles + 1):
		var up := Vector2i(t.x, t.y - i)
		if collision_at(tile_to_world(up) + Vector2(TILE * 0.5, TILE * 0.5)) != TileDef.Collision.SOLID:
			return Vector2(pos.x, (up.y + 1) * TILE)
	return pos


## Fires a spell projectile from `from` along `dir` (normalized). `power` multiplies
## its damage.
func request_spawn_projectile(spell: SpellData, from: Vector2, dir: Vector2, power: float,
		source: Node = null) -> SpellProjectile:
	if not Game.is_authority() or spell == null or dir == Vector2.ZERO:
		return null
	var b := SpellProjectile.new()
	b.world = self
	b.spell = spell
	b.direction = dir
	b.power = power
	b.source = source
	b.position = from
	effects.add_child(b)
	return b


func drop_count() -> int:
	return _drops.get_child_count() if _drops else 0


# --- biomes ---------------------------------------------------------------------------

## The biome at a tile: counted from the blocks and walls around it (biome_box), so it
## follows the ground you see, dug or built. &"forest" when nothing else wins.
func biome_at(tile: Vector2i) -> StringName:
	return &"dark_forest" if biome_amount(tile, &"dark_forest") >= biome_share else &"forest"


## The share (0 to 1) of the ground around a tile that belongs to `biome`. Above open
## sky with little ground, the surface biome of the column (generator) counts instead.
## Cached for a quarter second per area.
func biome_amount(tile: Vector2i, biome: StringName) -> float:
	var key := Vector3i(tile.x / 8, tile.y / 8, biome.hash())
	var now := Time.get_ticks_msec()
	var hit: Array = _biome_cache.get(key, [])
	if not hit.is_empty() and now - int(hit[0]) < 250:
		return float(hit[1])
	if _biome_cache.size() > 256:
		_biome_cache.clear()
	var step := maxi(biome_sample_step, 1)
	var ground := 0
	var mine := 0
	for dy in range(-biome_box.y / 2, biome_box.y / 2, step):
		for dx in range(-biome_box.x / 2, biome_box.x / 2, step):
			var x := tile.x + dx
			var y := tile.y + dy
			var b := data.get_block(x, y)
			var id := b if b > 0 else 0
			var types := blocks
			if id == 0:
				var w := data.get_wall(x, y)
				if w <= 0:
					continue
				id = w
				types = walls
			ground += 1
			if types.biome_of(id) == biome:
				mine += 1
	var total := float(biome_box.x * biome_box.y) / float(step * step)
	var amount := float(mine) / maxf(ground, maxf(total * biome_min_ground, 1.0))
	if ground < total * 0.15 and generator:
		# Mostly open sky: the surface below decides (a tree top, a high jump).
		var col := generator.dark_forest_at(data.wrap_x(tile.x)) if biome == &"dark_forest" else 0.0
		amount = maxf(amount, col)
	_biome_cache[key] = [now, amount]
	return amount
