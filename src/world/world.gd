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
## Chunks kept loaded around the camera, each direction.
@export var load_radius := Vector2i(2, 2)
## Max finished chunks turned into nodes per frame while moving (building happens on
## worker threads; this caps the main-thread part).
@export var chunks_per_frame: int = 1
## Seconds after the last hit before a damaged block heals back to full.
@export var block_heal_seconds := 5.0
## E interacts with things this close (tiles).
@export var interact_tiles := 6.0

@export_group("Spell scrolls")
## Crafting a scroll of a spell you know uses this share of its materials.
@export var known_scroll_discount := 0.5
## Copying a known spell into a scroll (Spell Weaving Table, Copy tab) needs at least
## this much max mana, by the spell's tier (1, 2, 3). Nothing is used up but the scroll.
@export var copy_max_mana_by_tier: Array[float] = [100.0, 200.0, 300.0]
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
var _drops: Node2D
var _bags: Node2D
var _enemies: Node2D
## Spawns enemies around the player.
var spawner: EnemySpawner
## Bed respawn points: character name -> bed anchor tile.
var spawn_points: Dictionary[String, Vector2i] = {}
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

	clock = WorldClock.new()
	clock.name = "Clock"
	if is_saved():
		clock.from_dict(WorldSave.read_extra(info.path, WorldSave.META_TIME))
	add_child(clock)
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

	character = Game.character
	if character == null:
		# Running the world scene directly (tests, F6 in the editor): a throwaway
		# character with the dev kit.
		character = CharacterData.create_dev(CharacterData.DEFAULT_NAME)
		character.temporary = true
	player = PLAYER_SCENE.instantiate() as Player
	player.world = self
	player.character = character
	player.look = character.make_look()
	var spawn := generator.spawn_tile()
	if DevCli.spawn_x >= 0:
		spawn = Vector2i(DevCli.spawn_x, generator.surface_at(DevCli.spawn_x))
	player.position = tile_to_world(spawn) + Vector2(TILE * 0.5, 0)
	renderer.load_all_now(player.position)
	add_child(player)
	teleport_player(player.position)
	player.hunger_on = info.hunger
	player.clock = clock
	if character.health > 0.0:
		player.health = minf(character.health, player.max_health)
	if character.hunger >= 0.0:
		player.hunger = minf(character.hunger, player.max_hunger)
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
		character.health = player.health if player and not player.dead else -1.0
		character.hunger = player.hunger if player and not player.dead else -1.0
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
			WorldSave.META_BAGS: {"list": bags_to_list()}, WorldSave.META_TIME: clock.to_dict(),
			WorldSave.META_SPAWNS: _spawns_to_dict(), WorldSave.META_KILLS: _kills_to_dict()}, objects)
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
	if info.death_drop == WorldInfo.DeathDrop.BAG and not inv.is_all_empty():
		var bag_inv := Inventory.new(inv.size)
		for i in inv.size:
			if not inv.is_empty(i) and not String(inv.ids[i]).begins_with(ItemData.SPELL_PREFIX):
				bag_inv.set_slot(i, inv.ids[i], inv.counts[i])
				inv.clear(i)
		inv.changed.emit()
		if not bag_inv.is_all_empty():
			request_spawn_bag(bag_inv, character.name, player.chest())
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
	var pos := respawn_position()
	renderer.load_all_now(pos)
	teleport_player(pos)
	player.revive()
	player.visible = true
	player.set_physics_process(true)


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
		elif not o.placed:
			o.queue_free()
	while spell.light_placed and same.size() >= maxi(spell.light_max, 1):
		same.pop_front().queue_free()
	var orb := LightOrb.new()
	effects.add_child(orb)
	orb.setup(self, spell)
	lights.mark_dirty()
	return orb


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
	return out


## Seconds left on the newest of a spell's lights or familiars (0 = none out).
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
			for f in get_tree().get_nodes_in_group(&"familiars"):
				f.queue_free()
			var fam := Familiar.new()
			effects.add_child(fam)
			fam.setup(self, spell, power)
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


## Moving light sources (Light Orb): [tile, radius, color] for the light map.
func dynamic_lights() -> Array[Array]:
	var out: Array[Array] = []
	for n in get_tree().get_nodes_in_group(&"light_sources"):
		if n.is_queued_for_deletion() or not n.has_method(&"light_tile"):
			continue
		out.append([n.call(&"light_tile"), float(n.get(&"radius")), n.get(&"color") as Color])
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
	e.position = pos
	_enemies.add_child(e)
	return e


func enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	if _enemies == null:
		return out
	for e in _enemies.get_children():
		if e is Enemy and not e.is_queued_for_deletion():
			out.append(e)
	return out


func enemy_count() -> int:
	return enemies().size()


func enemies_near(pos: Vector2, tiles: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies():
		if absf(e._wrapped_dx(pos.x)) <= tiles * TILE and absf(e.global_position.y - pos.y) <= tiles * TILE:
			out.append(e)
	return out


## A tile inside a building: a built (player placed) back wall behind it.
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
		for dx in def.width_tiles:
			var below := anchor + Vector2i(dx, 1)
			var b := data.get_block(below.x, below.y)
			if not (is_solid(below) or (b > 0 and blocks.collision(b) == TileDef.Collision.PLATFORM)):
				return false
	if def.needs_wall:
		for t in footprint(anchor, def):
			if data.get_wall(t.x, t.y) <= 0:
				return false
	return true


## Places an object with its anchor at `anchor`: furniture fills its footprint. Returns
## true if placed.
func request_place_object(anchor: Vector2i, id: int) -> bool:
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
	request_set_object(anchor, id)
	if def.container_slots > 0:
		containers[wrap_tile(anchor)] = Inventory.new(def.container_slots)
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
	if def.display:
		return request_take_display(a, null)
	if def.style == ObjectDef.Style.FURNITURE:
		for t in footprint(a, def):
			request_set_object(t, WorldData.AIR)
	else:
		request_set_object(a, WorldData.AIR)
	containers.erase(a)
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
	tile = wrap_tile(tile)
	displays[tile] = item_id
	request_set_object(tile, objects.index_of(&"display"))
	EventBus.sound_requested.emit(&"block_place", tile_to_world(tile))
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
	if who == null or who.held_item == null or who.stowed or who.selected < 0:
		return false
	if point.distance_to(who.chest()) > (interact_tiles + 2.0) * TILE:
		return false
	var item := who.held_item
	var tile := world_to_tile(point)
	if not can_display_at(tile, item):
		return false
	if who.character.inventory.take(who.selected, 1) <= 0:
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
		var inv := Inventory.new(def.container_slots if def and def.container_slots > 0 else Inventory.DEFAULT_SIZE)
		inv.from_dict(d[key])
		containers[at] = inv


## Tall objects (a 2-tile torch) need the tiles above them free of solid blocks.
func _room_above(tile: Vector2i, def: ObjectDef) -> bool:
	for k in range(1, def.height_tiles):
		if is_solid(tile - Vector2i(0, k)):
			return false
	return true


## Torch support: a solid block below or beside, or a back wall behind.
func _supported(tile: Vector2i) -> bool:
	return is_solid(tile + Vector2i.DOWN) or is_solid(tile + Vector2i.LEFT) or is_solid(tile + Vector2i.RIGHT) \
		or data.get_wall(tile.x, tile.y) > 0


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
	tile = wrap_tile(tile)
	EventBus.sound_requested.emit(&"mine_hit", tile_to_world(tile))
	var id := data.get_wall(tile.x, tile.y) if wall else data.get_block(tile.x, tile.y)
	# Front-layer mining takes a tile object first when there's no solid block there
	# (rope on a platform, a torch). Objects break in one hit.
	if not wall and data.get_object(tile.x, tile.y) > 0 and not is_solid(tile):
		return request_remove_object(tile)
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
	_drop_for(def, tile)
	return true


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
	var a := object_anchor_visual(world_to_tile(point))
	if a == NO_TILE:
		return false
	var def := object_at(a)
	return def != null and _usable(def)


func try_interact_at(point: Vector2, who: Player) -> bool:
	if who and point.distance_to(who.chest()) > (interact_tiles + 2.0) * TILE:
		return false
	var tile := world_to_tile(point)
	var a := object_anchor_visual(tile)
	if a != NO_TILE and _interact_object(a):
		return true
	if forage and forage.request_pick_up(tile, who):
		return true
	if plants and plants.request_pick_up(tile, who):
		return true
	for node in get_tree().get_nodes_in_group(&"interactable"):
		if node.has_method(&"interact_rect") and (node.call(&"interact_rect") as Rect2).has_point(point):
			node.call(&"interact", who)
			return true
	return false


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
	return def.toggles_to != &"" or def.container_slots > 0 or def.station != &"" or def.bed or def.display


func _interact_object(anchor: Vector2i) -> bool:
	var def := object_at(anchor)
	if def == null or not _usable(def):
		return false
	if def.display:
		request_take_display(anchor, player)
	elif def.bed:
		use_bed(anchor)
	elif def.toggles_to != &"":
		if not request_toggle_object(anchor):
			EventBus.debug_message.emit("Something's in the way" if def.blocks_movement else "Can't close: you're in the doorway")
	elif def.container_slots > 0:
		container_opened.emit(wrap_tile(anchor))
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
