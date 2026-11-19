class_name ForageLayer
extends Node2D
## Forageables: things lying on the ground you pick up with right click or E (sticks,
## rocks, flint; the types are ForageData in data/forage/).
##
## Seeded the first time a chunk is shown, the same way every time (a tile's roll is
## fixed by its position). After that they come back over time on random floor tiles
## (random ticks), never on screen, never indoors, with a crowding brake. Keyed by the
## ground tile they lie on (wrapped). Chunks whose forageables changed are saved with the
## world (WorldSave extra "forage"); the rest re-seed identically next session.

const TILE := World.TILE
const SIZE := ChunkData.SIZE
const NONE := Vector2i(0, -1000000)

@export_group("How many lie around")
## Share of the generator's flower spots that are a forageable instead of a flower.
@export_range(0.0, 1.0) var flower_spot_share := 0.4
## Chance a bare surface grass tile has one. 0.06 is about one every 16 tiles of surface.
@export_range(0.0, 1.0) var surface_grass_chance := 0.06
## Chance an exposed surface dirt or stone tile (cliffs, dug ground) has one.
@export_range(0.0, 1.0) var surface_ground_chance := 0.05
## Chance a cave floor tile (grass, dirt or stone with air above, more than 3 tiles below
## the generated surface) has one.
@export_range(0.0, 1.0) var cave_chance := 0.03
@export_group("Coming back")
## On average one new forageable per `regrow_floor_tiles` tiles of open floor (about a
## chunk's width of ground) every this many in-game days.
@export var regrow_days_per_item := 2.5
@export var regrow_floor_tiles := 32
## Caves get them back at this fraction of the surface rate.
@export_range(0.0, 1.0) var cave_regrow_scale := 0.5
## Crowding brake: the chance drops with every forageable already within `crowd_radius`
## tiles and is zero at `crowd_cap`, so floors never fill up.
@export var crowd_radius := 16
@export var crowd_cap := 6
## Random floor tiles checked per second (over the loaded area). More checks don't
## change the rate, only how evenly it trickles in.
@export var regrow_checks_per_second := 200.0
## A chunk that comes back into view catches up on the time it was away, up to this
## many in-game days.
@export var regrow_catch_up_days := 3.0
@export_group("")

## Pre-Forage saves stored these as plant variants 0, 1, 2.
const LEGACY_IDS: Array[StringName] = [&"stick", &"rock", &"flint"]


class Forage:
	var def: ForageData
	var node: Node2D


var world: World
## Every type, sorted by id (so weighted picks are stable).
var defs: Array[ForageData] = []
var _items: Dictionary[Vector2i, Forage] = {}
## Wrapped chunk coord -> ground tiles of its forageables.
var _by_chunk: Dictionary[Vector2i, Array] = {}
var _seeded: Dictionary[Vector2i, bool] = {}
## Chunks whose forageables changed since the world was generated (saved).
var _dirty: Dictionary[Vector2i, bool] = {}
## Shown chunks (unwrapped coord -> wrapped coord).
var _shown: Dictionary[Vector2i, Vector2i] = {}
var _regrow_budget := 0.0
## Seconds the world has run (this session), for catch-up.
var _now := 0.0
## Shown chunk (unwrapped) -> floor tiles there (flat local x, y pairs).
var _floor_spots: Dictionary[Vector2i, PackedInt32Array] = {}
var _floor_total := 0
## Wrapped chunk -> _now when it was last hidden.
var _last_seen: Dictionary[Vector2i, float] = {}
## Forageables that came back over time (dev console `pickups`).
var regrown_total := 0
var _grass_id := -1
var _dirt_id := -1
var _stone_id := -1


func setup(w: World) -> void:
	world = w
	z_index = 1  # in front of the grass blades, so sticks don't hide in them
	_grass_id = world.blocks.index_of(&"grass")
	_dirt_id = world.blocks.index_of(&"dirt")
	_stone_id = world.blocks.index_of(&"stone")
	for d in Registry.get_all(&"forage"):
		defs.append(d as ForageData)
	defs.sort_custom(func(a: ForageData, b: ForageData) -> bool: return a.id < b.id)
	world.renderer.chunk_shown.connect(_on_chunk_shown)
	world.renderer.chunk_hidden.connect(_on_chunk_hidden)
	world.block_changed.connect(_on_block_changed)


# --- queries -------------------------------------------------------------------------

## The forageable lying on ground tile `ground`, or null.
func at(ground: Vector2i) -> ForageData:
	var f: Forage = _items.get(world.wrap_tile(ground))
	return f.def if f else null


func count() -> int:
	return _items.size()


## True if this flower spot (from the generator) holds a forageable, not a flower.
func claims_flower_spot(ground: Vector2i) -> bool:
	return _hash(world.wrap_tile(ground), 11) < flower_spot_share


## The ground tile of the nearest forageable within `r` tiles of `feet`, or NONE.
func nearest(feet: Vector2i, r: int) -> Vector2i:
	var best := NONE
	var best_d := INF
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if _items.has(world.wrap_tile(feet + Vector2i(dx, dy))) and Vector2(dx, dy).length() < best_d:
				best = feet + Vector2i(dx, dy)
				best_d = Vector2(dx, dy).length()
	return best


## The sprite of the forageable lying at `tile` (it lies on tile + 1 down), or null. For
## the hover outline.
func hover_sprite(tile: Vector2i) -> Sprite2D:
	var f: Forage = _items.get(world.wrap_tile(tile + Vector2i.DOWN))
	if f == null or f.node == null or f.node.get_child_count() == 0:
		return null
	return f.node.get_child(0) as Sprite2D


## Forageables in shown chunks.
func loaded_count() -> int:
	var n := 0
	for c: Vector2i in _shown:
		n += (_by_chunk.get(_shown[c], []) as Array).size()
	return n


func floor_tile_count() -> int:
	return _floor_total


# --- requests (host-authoritative) -------------------------------------------------

## Right click on a forageable (`tile` = where it lies): it goes into the inventory.
## Returns true if there was one.
func request_pick_up(tile: Vector2i, who: Player) -> bool:
	if not Game.is_authority() or who == null or who.character == null:
		return false
	var g := world.wrap_tile(tile + Vector2i.DOWN)
	var f: Forage = _items.get(g)
	if f == null:
		return false
	if who.character.inventory.add(f.def.item, f.def.count) > 0:
		return false  # no room
	EventBus.item_picked_up.emit(f.def.item, f.def.count)
	_remove(g)
	return true


# --- chunks --------------------------------------------------------------------------

func _on_chunk_shown(c: Vector2i, spots: PackedInt32Array, floors: PackedInt32Array) -> void:
	var wc := Vector2i(posmod(c.x, world.data.chunks_x), c.y)
	if not _seeded.has(wc):
		_seeded[wc] = true
		_seed(wc, spots, floors)
	_shown[c] = wc
	for g: Vector2i in _by_chunk.get(wc, []):
		_make_node(g, _items[g], c)
	var mine := PackedInt32Array()
	for i in range(0, spots.size(), 4):
		mine.append_array([spots[i], spots[i + 1]])
	for i in range(0, floors.size(), 3):
		mine.append_array([floors[i], floors[i + 1]])
	_floor_spots[c] = mine
	_floor_total += mine.size() / 2
	if _last_seen.has(wc):
		_catch_up(c, minf(_now - _last_seen[wc], _days(regrow_catch_up_days)))
		_last_seen.erase(wc)


## First time a chunk is shown: the forageables it starts with (same every time).
## Plants were seeded first (trees, bushes and flowers keep their tiles).
func _seed(wc: Vector2i, spots: PackedInt32Array, floors: PackedInt32Array) -> void:
	for i in range(0, spots.size(), 4):
		var ground := world.wrap_tile(wc * SIZE + Vector2i(spots[i], spots[i + 1]))
		if spots[i + 2] >= 0 or (world.plants and world.plants.plant_at(ground)):
			continue  # a tree, bush or flower
		var bare := spots[i + 3] < 0
		if (bare and _hash(ground, 47) < surface_grass_chance) or (not bare and claims_flower_spot(ground)):
			_seed_one(ground, ChunkBuildJob.FLOOR_GRASS)
	for i in range(0, floors.size(), 3):
		var ground := world.wrap_tile(wc * SIZE + Vector2i(floors[i], floors[i + 1]))
		if _items.has(ground) or (world.plants and world.plants.plant_at(ground)):
			continue
		var place := floors[i + 2]
		if _hash(ground, 47 + place * 6) < _chance(place):
			_seed_one(ground, place)


func _seed_one(ground: Vector2i, place: int) -> void:
	var d := _pick(place, _hash(ground, 23))
	if d:
		_add(ground, d, false)


func _chance(place: int) -> float:
	match place:
		ChunkBuildJob.FLOOR_GRASS:
			return surface_grass_chance
		ChunkBuildJob.FLOOR_GROUND:
			return surface_ground_chance
	return cave_chance


## A type for a kind of place, by the types' weights; `roll` is 0..1.
func _pick(place: int, roll: float) -> ForageData:
	var total := 0.0
	for d in defs:
		total += maxf(0.0, d.weight(place))
	if total <= 0.0:
		return null
	var x := roll * total
	for d in defs:
		x -= maxf(0.0, d.weight(place))
		if x < 0.0:
			return d
	return defs[defs.size() - 1] if defs[defs.size() - 1].weight(place) > 0.0 else null


func _on_chunk_hidden(c: Vector2i) -> void:
	var wc: Vector2i = _shown.get(c, NONE)
	_shown.erase(c)
	if _floor_spots.has(c):
		_floor_total -= _floor_spots[c].size() / 2
		_floor_spots.erase(c)
	if wc == NONE:
		return
	_last_seen[wc] = _now
	for g: Vector2i in _by_chunk.get(wc, []):
		var f: Forage = _items[g]
		if f.node:
			f.node.queue_free()
			f.node = null


## F6 regenerate: forget the natural forageables of chunks the player never changed.
func reset_unchanged() -> void:
	for wc: Vector2i in _seeded.keys():
		if not _dirty.has(wc):
			_seeded.erase(wc)
			for g: Vector2i in (_by_chunk.get(wc, []) as Array).duplicate():
				_remove(g)


## A steady 0..1 number per tile (so a spot always rolls the same).
static func _hash(t: Vector2i, salt: int) -> float:
	var h := (t.x * 73856093) ^ (t.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xffff) / 65535.0


# --- coming back ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_now += delta
	_regrow_floors(delta)


## Time passes at once (sleeping through the night).
func advance(seconds: float) -> void:
	_now += seconds
	for c: Vector2i in _floor_spots.keys():
		_catch_up(c, minf(seconds, _days(regrow_catch_up_days)))


## Real seconds for in-game days (the world's clock).
func _days(n: float) -> float:
	return world.clock.days(n) if world and world.clock else n * 24.0 * 60.0


## Chance per second that one open floor tile gets a new forageable (surface rate).
func _regrow_rate() -> float:
	return 1.0 / (maxf(1.0, float(regrow_floor_tiles)) * maxf(0.001, _days(regrow_days_per_item)))


## Random ticks: a few random floor tiles of the loaded area per frame, each with the
## chance that gives regrow_days_per_item on average.
func _regrow_floors(delta: float) -> void:
	if not Game.is_authority() or _floor_total <= 0 or regrow_checks_per_second <= 0.0:
		return
	_regrow_budget += regrow_checks_per_second * delta
	var n := int(_regrow_budget)
	_regrow_budget -= n
	if n <= 0:
		return
	# Each floor tile is checked checks/total times a second; this chance per check
	# makes that come out to the rate.
	var chance := _regrow_rate() * _floor_total / regrow_checks_per_second
	var screen := _screen_tiles()
	for i in n:
		var pick := randi() % _floor_total
		for c: Vector2i in _floor_spots:
			var spots := _floor_spots[c]
			var count := spots.size() / 2
			if pick >= count:
				pick -= count
				continue
			var t := c * SIZE + Vector2i(spots[pick * 2], spots[pick * 2 + 1])
			if not screen.has_point(t):
				try_regrow(t, chance)
			break


## A chunk was away (or the world slept) for `seconds`: each of its floor tiles rolls
## for that time at once.
func _catch_up(c: Vector2i, seconds: float) -> void:
	if not Game.is_authority() or seconds <= 0.0 or not _floor_spots.has(c):
		return
	var chance := _regrow_rate() * seconds
	var screen := _screen_tiles()
	var spots := _floor_spots[c]
	for i in range(0, spots.size(), 2):
		var t := c * SIZE + Vector2i(spots[i], spots[i + 1])
		if not screen.has_point(t):
			try_regrow(t, chance)


## Dev console: `days` in-game days pass for the loaded area (catch-up cap ignored).
func regrow_for_days(days: float) -> void:
	for c: Vector2i in _floor_spots.keys():
		_catch_up(c, _days(days))


## Rolls one floor tile (ground tile, wrapped or not): maybe a forageable appears.
func try_regrow(t: Vector2i, chance: float) -> bool:
	var g := world.wrap_tile(t)
	if _items.has(g) or (world.plants and world.plants.plant_at(g)):
		return false
	var id := world.data.get_block(g.x, g.y)
	if id != _grass_id and id != _dirt_id and id != _stone_id:
		return false
	var above := g + Vector2i.UP
	if world.data.get_block(above.x, above.y) != WorldData.AIR:
		return false
	# Not in houses: nothing on tiles with a background wall or furniture.
	if world.data.get_wall(above.x, above.y) != WorldData.AIR or world.data.get_object(above.x, above.y) != WorldData.AIR:
		return false
	var place := ChunkBuildJob.FLOOR_GRASS if id == _grass_id else ChunkBuildJob.FLOOR_GROUND
	if world.generator != null and g.y > world.generator.surface_at(g.x) + 3:
		place = ChunkBuildJob.FLOOR_CAVE
		chance *= cave_regrow_scale
	if randf() >= chance:
		return false
	var crowd := _near(g)
	if crowd >= crowd_cap or randf() >= 1.0 - float(crowd) / float(maxi(1, crowd_cap)):
		return false
	var d := _pick(place, randf())
	if d == null:
		return false
	_add(g, d)
	regrown_total += 1
	return true


## Forageables within crowd_radius tiles of g.
func _near(g: Vector2i) -> int:
	var n := 0
	for dy in range(-crowd_radius, crowd_radius + 1):
		for dx in range(-crowd_radius, crowd_radius + 1):
			if _items.has(world.wrap_tile(g + Vector2i(dx, dy))):
				n += 1
	return n


## The tiles on screen (plus a margin), unwrapped like the shown chunks. Nothing
## appears where the player is looking.
func _screen_tiles() -> Rect2i:
	var vp := get_viewport()
	if vp == null:
		return Rect2i()
	var r := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var a := Vector2i(floori(r.position.x / TILE), floori(r.position.y / TILE)) - Vector2i(2, 2)
	var b := Vector2i(ceili(r.end.x / TILE), ceili(r.end.y / TILE)) + Vector2i(3, 3)
	return Rect2i(a, b - a)


# --- changes ---------------------------------------------------------------------------

func _on_block_changed(tile: Vector2i, _old: int, new_id: int) -> void:
	tile = world.wrap_tile(tile)
	# The ground under it went away: it drops as an item.
	var f: Forage = _items.get(tile)
	if f and (new_id <= 0 or world.blocks.collision(new_id) != TileDef.Collision.SOLID):
		_drop(tile, f)
	# Something was put where it lies: same.
	var below := world.wrap_tile(tile + Vector2i.DOWN)
	var q: Forage = _items.get(below)
	if q and new_id != WorldData.AIR:
		_drop(below, q)


func _drop(g: Vector2i, f: Forage) -> void:
	var pos := Vector2(g.x * TILE + TILE * 0.5, g.y * TILE - 4)
	if world.player:
		var w := world.data.width * TILE
		pos.x += roundf((world.player.global_position.x - pos.x) / w) * w
	world.request_spawn_drop(f.def.item, f.def.count, pos,
		Vector2(randf_range(-4.0, 4.0), randf_range(-10.0, -6.0)) * TILE)
	_remove(g)


func _add(g: Vector2i, d: ForageData, dirty: bool = true) -> Forage:
	_remove(g, false)
	var f := Forage.new()
	f.def = d
	_items[g] = f
	var wc := _chunk_of(g)
	if not _by_chunk.has(wc):
		_by_chunk[wc] = []
	_by_chunk[wc].append(g)
	if dirty:
		_dirty[wc] = true
	for c: Vector2i in _shown:
		if _shown[c] == wc:
			_make_node(g, f, c)
	return f


func _remove(g: Vector2i, dirty: bool = true) -> void:
	var f: Forage = _items.get(g)
	if f == null:
		return
	if f.node:
		f.node.queue_free()
	_items.erase(g)
	var wc := _chunk_of(g)
	(_by_chunk[wc] as Array).erase(g)
	if dirty:
		_dirty[wc] = true


func _make_node(g: Vector2i, f: Forage, shown_chunk: Vector2i) -> void:
	if f.node:
		f.node.queue_free()
	var local := g - _chunk_of(g) * SIZE
	var node := Node2D.new()
	node.position = Vector2((shown_chunk * SIZE + local) * TILE) + Vector2(TILE * 0.5, 0)
	var s := Sprite2D.new()
	s.texture = f.def.texture
	s.centered = false
	s.position = Vector2(-floorf(s.texture.get_width() / 2.0), 1 - s.texture.get_height())
	node.add_child(s)
	add_child(node)
	f.node = node


func _chunk_of(g: Vector2i) -> Vector2i:
	return Vector2i(floori(float(g.x) / SIZE), floori(float(g.y) / SIZE))


# --- save ------------------------------------------------------------------------------

## Forageables of chunks that changed (theirs or blocks), for the world file.
func to_dict(modified_chunks: Array[Vector2i]) -> Dictionary:
	var keep: Dictionary[Vector2i, bool] = _dirty.duplicate()
	for c in modified_chunks:
		if _seeded.has(c):
			keep[c] = true
	var out := {}
	for wc: Vector2i in keep:
		var list: Array = []
		for g: Vector2i in _by_chunk.get(wc, []):
			list.append([g.x, g.y, String((_items[g] as Forage).def.id)])
		out["%d,%d" % [wc.x, wc.y]] = list
	return out


func from_dict(d: Dictionary) -> void:
	for key: String in d:
		var parts := key.split(",")
		var wc := Vector2i(int(parts[0]), int(parts[1]))
		_seeded[wc] = true
		_dirty[wc] = true
		for e: Array in d[key]:
			var def := Registry.get_def(&"forage", StringName(e[2])) as ForageData
			if def:
				_add(Vector2i(int(e[0]), int(e[1])), def)


## Older saves kept forageables with the plants: a chunk the plants saved counts as
## seeded here too, and its loose sticks, rocks and flint come over.
func take_legacy_chunk(wc: Vector2i) -> void:
	_seeded[wc] = true
	_dirty[wc] = true


func take_legacy(g: Vector2i, variant: int) -> void:
	var def := Registry.get_def(&"forage", LEGACY_IDS[posmod(variant, LEGACY_IDS.size())]) as ForageData
	if def:
		_add(g, def)
