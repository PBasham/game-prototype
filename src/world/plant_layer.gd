class_name PlantLayer
extends Node2D
## Trees, saplings, flowers and berry bushes, plus grass spreading onto dirt. Things
## lying on the ground (sticks, rocks) are the Forage node (ForageLayer).
##
## Plants stand on a ground tile (grass) and are keyed by it (wrapped tile coords).
## Natural plants come from the world generator's decoration rules the first time a
## chunk is shown ("seeding"); after that the chunk's plants are this layer's data, so
## chopped trees stay chopped. Chunks whose plants or blocks changed are saved with the
## world (WorldSave extra "plants"); the rest re-seed identically next session.
##
## Host-authoritative like tiles: hits, planting and cutting go through request_*.

const TILE := World.TILE
const SIZE := ChunkData.SIZE
const NONE := Vector2i(0, -1000000)

## PICKUP: only in older saves (sticks, rocks and flint moved to the Forage node).
enum Kind { TREE, SAPLING, FLOWER, PICKUP, BUSH }

## Berry bush variants: `variant` = kind * 2 + grown (the kind is BushData.save_index).
const BUSH_YOUNG := 0
const BUSH_GROWN := 1

@export_group("Trees")
## Damage a tree takes before it falls. A copper axe does 25 per hit.
@export var tree_health := 100.0
## A fallen tree drops one Log per this many tiles of its height, rounded (small pines
## about 14 tiles: 2, medium about 19: 3, large about 23: 4). 1 Log crafts into 4 Wood.
@export var tiles_per_log := 4.5
## Seeds dropped: always 1, plus this chance of a second.
@export_range(0.0, 1.0) var extra_seed_chance := 0.5
## Seconds a tree takes to fall over.
@export var fall_time := 0.9
## Degrees a tree rocks when hit.
@export var wiggle_degrees := 4.0
## Trees lean up to this many degrees either way (each its own, from its spot).
@export var tree_lean_degrees := 4.0
## Trees need this many tiles between their trunks (planting).
@export var tree_spacing := 3
## How much of a tree's height (from the ground) is bare trunk you can hang a torch on.
@export_range(0.1, 1.0) var trunk_share := 0.6
## Tiles of clear space above the ground a sapling needs to grow.
@export var grow_clearance := 10
@export_group("Saplings")
## In-game days a sapling takes to grow into a tree (random in this range, while the
## world is running). A day is 24 real minutes (WorldClock.day_minutes).
@export var grow_min_days := 1.0
@export var grow_max_days := 2.0
@export_group("Berry bushes")
## Share of flower spots that are a berry bush instead.
@export_range(0.0, 1.0) var bush_share := 0.06
## Berries picked from a ripe bush (right click or E).
@export var berries_min := 1
@export var berries_max := 3
## Share of bushes the world starts with full grown (the rest are young).
@export_range(0.0, 1.0) var bush_grown_share := 0.7
## In-game days for a young bush to grow full size (with berries). Young bushes have none.
@export var bush_grow_min_days := 2.0
@export var bush_grow_max_days := 3.0
## In-game days until a picked bush has berries again. Wild bushes are slow and stingy
## on purpose; farming will be the better way to get food.
@export var regrow_min_days := 2.0
@export var regrow_max_days := 3.0
@export_group("Flowers and grass")
## Chance that cutting a flower drops grass seeds.
@export_range(0.0, 1.0) var grass_seed_chance := 0.35
## Random tiles checked per second (over the loaded area) for grass spreading: exposed
## dirt next to grass turns into grass. Higher = faster spread.
@export var grass_spread_checks_per_second := 1500.0
@export_group("")


class Plant:
	var kind: int
	var variant: int
	var health: float
	var grow_left: float
	var node: Node2D


var world: World
var _plants: Dictionary[Vector2i, Plant] = {}
## Wrapped chunk coord -> ground tiles of its plants.
var _by_chunk: Dictionary[Vector2i, Array] = {}
var _seeded: Dictionary[Vector2i, bool] = {}
## Chunks whose plants changed since the world was generated (saved).
var _dirty: Dictionary[Vector2i, bool] = {}
## Shown chunks (unwrapped coord -> wrapped coord).
var _shown: Dictionary[Vector2i, Vector2i] = {}
var _saplings: Array[Vector2i] = []
var _grass_budget := 0.0
var _grass_id := -1
var _dirt_id := -1
var _trees: Array[Texture2D] = []
## The pines come first in _trees; tree variants from here on are darkwood trees
## (the Dark Forest), which drop Dark Logs.
var _pines := 12
var _flowers: Array[Texture2D] = []
var _sapling_tex: Texture2D
var _dark_sapling_tex: Texture2D
## [young, grown ripe, grown picked].
## Bush kinds by save_index (data/bushes/), and the kinds in worldgen order.
var _bushes: Dictionary[int, BushData] = {}
var _bush_list: Array[BushData] = []
## Young bushes growing up (their Plant.health counts down the seconds left).
var _young: Array[Vector2i] = []
## Bushes waiting for their berries to grow back.
var _regrowing: Array[Vector2i] = []


func setup(w: World) -> void:
	world = w
	z_index = -1
	_grass_id = world.blocks.index_of(&"grass")
	_dirt_id = world.blocks.index_of(&"dirt")
	for kind: String in ["green", "olive", "teal", "gold"]:
		for i in 3:
			_trees.append(load("res://assets/trees/pine_%s_%d.png" % [kind, i]) as Texture2D)
	_pines = _trees.size()
	for i in 3:
		_trees.append(load("res://assets/trees/darkwood_%d.png" % i) as Texture2D)
	for i in 5:
		_flowers.append(load("res://assets/decor/flower_%d.png" % i) as Texture2D)
	_sapling_tex = load("res://assets/decor/sapling.png") as Texture2D
	_dark_sapling_tex = load("res://assets/decor/darkwood_sapling.png") as Texture2D
	for d: GameData in Registry.get_all(&"bushes"):
		var b := d as BushData
		_bushes[b.save_index] = b
		_bush_list.append(b)
	_bush_list.sort_custom(func(a: BushData, b: BushData) -> bool: return a.save_index < b.save_index)
	world.renderer.chunk_shown.connect(_on_chunk_shown)
	world.renderer.chunk_hidden.connect(_on_chunk_hidden)
	world.block_changed.connect(_on_block_changed)


# --- queries -------------------------------------------------------------------------

func plant_at(ground: Vector2i) -> Plant:
	return _plants.get(world.wrap_tile(ground))


func count() -> int:
	return _plants.size()


## The ground tile of the tree under a point (trunk or canopy), or NONE.
func tree_at_point(p: Vector2) -> Vector2i:
	var t := world.wrap_tile(world.world_to_tile(p))
	for dx: int in [0, -1, 1, -2, 2]:
		for dy in range(1, 15):
			var g := world.wrap_tile(t + Vector2i(dx, dy))
			var plant: Plant = _plants.get(g)
			if plant and plant.kind == Kind.TREE:
				var canopy := absi(dx) <= 1 or dy > 4  # trunk is narrow, canopy wide
				if canopy:
					return g
	return NONE


## The world position of a ground tile near `near` (unwrapped to match it).
func ground_position(ground: Vector2i, near: Vector2) -> Vector2:
	var base := Vector2(ground.x * TILE + TILE * 0.5, ground.y * TILE)
	var w := world.data.width * TILE
	base.x += roundf((near.x - base.x) / w) * w
	return base


## True when a tree stands on this block: it can't be mined (chop the tree first).
func supports(tile: Vector2i) -> bool:
	var plant: Plant = _plants.get(world.wrap_tile(tile))
	return plant != null and plant.kind == Kind.TREE


## True when `tile` is on a tree's trunk (below its canopy): torches can hang there.
## Pine trunks are one tile wide, darkwood trunks three.
func trunk_at(tile: Vector2i) -> bool:
	for dy in range(1, 40):
		for dx: int in [0, -1, 1]:
			var g := world.wrap_tile(tile + Vector2i(dx, dy))
			var p: Plant = _plants.get(g)
			if p == null or p.kind != Kind.TREE:
				continue
			var dark := p.variant % _trees.size() >= _pines
			if dx != 0 and not dark:
				continue
			return dy <= roundi(_height_tiles(p) * trunk_share)
	return false


## True when a block placed on `tile` would go through a tree trunk.
func blocks_placement(tile: Vector2i) -> bool:
	for dy in range(1, 5):
		var plant: Plant = _plants.get(world.wrap_tile(tile + Vector2i(0, dy)))
		if plant and plant.kind == Kind.TREE:
			return true
	return false


## Where a tree seed would be planted for a cursor tile (the grass under it), or NONE.
## Whether a berry bush fits on this grass tile: it takes 3 tiles of open grass (this
## one and one each side), none of them already holding a plant.
func bush_room(ground: Vector2i) -> bool:
	for dx in range(-1, 2):
		var g := ground + Vector2i(dx, 0)
		if not world.blocks.is_grass(world.data.get_block(g.x, g.y)) or world.data.get_block(g.x, g.y - 1) != WorldData.AIR:
			return false
		if plant_at(world.wrap_tile(g)) != null:
			return false
	for dx in [-2, 2]:  # a bush beside it would overlap
		var near := plant_at(world.wrap_tile(ground + Vector2i(dx, 0)))
		if near and near.kind == Kind.BUSH:
			return false
	return true


func sapling_spot(tile: Vector2i) -> Vector2i:
	for g: Vector2i in [tile, tile + Vector2i.DOWN]:
		if world.blocks.is_grass(world.data.get_block(g.x, g.y)) and world.data.get_block(g.x, g.y - 1) == WorldData.AIR:
			if _plants.has(world.wrap_tile(g)) or (world.forage and world.forage.at(g)):
				return NONE
			# The trunk needs ground under it: a block on each side of the root too.
			for dx in [-1, 1]:
				if not world.is_solid(g + Vector2i(dx, 0)):
					return NONE
			for dx in range(-tree_spacing + 1, tree_spacing):
				for dy in range(-3, 4):
					var other: Plant = _plants.get(world.wrap_tile(g + Vector2i(dx, dy)))
					if other and other.kind != Kind.FLOWER:
						return NONE
			return world.wrap_tile(g)
	return NONE


# --- requests (host-authoritative) -------------------------------------------------

## Axe hit. Returns true if a tree was there. `from_x` = where the hit came from (the
## tree falls away from it).
func request_hit_tree(ground: Vector2i, damage: float, from_x: float) -> bool:
	if not Game.is_authority():
		return false
	if world.instant_break:
		damage = INF
	ground = world.wrap_tile(ground)
	var plant: Plant = _plants.get(ground)
	if plant == null or plant.kind != Kind.TREE:
		return false
	plant.health -= damage
	if plant.health <= 0.0:
		var dir := 1.0
		if plant.node:
			dir = 1.0 if plant.node.global_position.x >= from_x else -1.0
		_fell(ground, plant, dir)
	elif plant.node:
		_wiggle(plant.node)
	return true


## Sapling variants: what it grows into (and drops when broken).
const SAPLING_PINE := 0
const SAPLING_DARKWOOD := 1
const SAPLING_ITEMS: Array[StringName] = [&"tree_seed", &"darkwood_sapling"]


## Plants a sapling on the grass tile `ground` (`kind`: SAPLING_PINE or
## SAPLING_DARKWOOD). Returns true if it was planted.
func request_plant_tree(ground: Vector2i, kind: int = SAPLING_PINE) -> bool:
	if not Game.is_authority() or sapling_spot(ground) != world.wrap_tile(ground):
		return false
	var p := _add(world.wrap_tile(ground), Kind.SAPLING, kind)
	p.grow_left = _days(randf_range(grow_min_days, grow_max_days))
	return true


## Cuts flowers whose stems are in the tile rect (a swing). Returns how many.
func request_cut_flowers(rect: Rect2i) -> int:
	if not Game.is_authority():
		return 0
	var cut := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var g := world.wrap_tile(Vector2i(x, y + 1))
			var plant: Plant = _plants.get(g)
			if plant and plant.kind == Kind.FLOWER:
				_break(g, plant)
				cut += 1
	return cut


# --- chunks --------------------------------------------------------------------------

func _on_chunk_shown(c: Vector2i, spots: PackedInt32Array, _floors: PackedInt32Array) -> void:
	var wc := Vector2i(posmod(c.x, world.data.chunks_x), c.y)
	if not _seeded.has(wc):
		_seeded[wc] = true
		for i in range(0, spots.size(), 4):
			var ground := world.wrap_tile(wc * SIZE + Vector2i(spots[i], spots[i + 1]))
			if spots[i + 2] >= 0:
				var p := _add(ground, Kind.TREE, spots[i + 2], false)
				p.health = tree_health
			elif spots[i + 3] < 0:
				continue  # bare grass (the Forage node may put something there)
			elif _hash(ground, 31) < bush_share:
				var young := _hash(ground, 37) >= bush_grown_share
				var bush := _add(ground, Kind.BUSH, bush_variant(_wild_bush(ground), not young), false)
				if young:
					bush.health = _days(randf_range(bush_grow_min_days, bush_grow_max_days))
					_young.append(ground)
			elif world.forage and world.forage.claims_flower_spot(ground):
				continue  # a stick or rock lies there instead
			else:
				_add(ground, Kind.FLOWER, spots[i + 3], false)
	_shown[c] = wc
	for g: Vector2i in _by_chunk.get(wc, []):
		_make_node(g, _plants[g], c)


func _on_chunk_hidden(c: Vector2i) -> void:
	var wc: Vector2i = _shown.get(c, NONE)
	_shown.erase(c)
	if wc == NONE:
		return
	for g: Vector2i in _by_chunk.get(wc, []):
		var p: Plant = _plants[g]
		if p.node:
			p.node.queue_free()
			p.node = null


## F6 regenerate: forget natural plants of chunks the player never changed.
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


## Right click on a berry bush (`tile` = a tile it covers): picks its berries if ripe.
## Returns true if there were berries.
func request_pick_up(tile: Vector2i, who: Player) -> bool:
	var bush := _bush_near(tile)
	return bush != NONE and request_pick_berries(bush, who)


## A ripe berry bush covering `tile` (bushes are about 2x2 tiles), or NONE.
func _bush_near(tile: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, 2), Vector2i(1, 2)]:
		var g := world.wrap_tile(tile + d)
		var p: Plant = _plants.get(g)
		if p and p.kind == Kind.BUSH:
			return g
	return NONE


## The sprite of a ripe bush covering `tile`, or null. For the hover outline.
func hover_sprite(tile: Vector2i) -> Sprite2D:
	var g := _bush_near(tile)
	if g == NONE or not _ripe(_plants.get(g)):
		return null
	var node := (_plants[g] as Plant).node
	return node.get_child(0) as Sprite2D if node and node.get_child_count() > 0 else null


func is_ripe(ground: Vector2i) -> bool:
	var p: Plant = _plants.get(world.wrap_tile(ground))
	return _ripe(p)


## The variant for a bush of `kind` (BushData.save_index), young or grown.
static func bush_variant(kind: int, grown: bool) -> int:
	return kind * 2 + (BUSH_GROWN if grown else BUSH_YOUNG)


## The kind of a bush plant (null if its kind's data is gone).
func bush_kind(p: Plant) -> BushData:
	return _bushes.get(p.variant >> 1) if p and p.kind == Kind.BUSH else null


## What a ripe bush gives.
func fruit_of(p: Plant) -> StringName:
	var b := bush_kind(p)
	return b.fruit if b else &"berries"


## The kind of the bush at `ground` (for the console and tests), or null.
func bush_kind_at(ground: Vector2i) -> BushData:
	return bush_kind(_plants.get(world.wrap_tile(ground)))


## The save_index of the bush kind with this id, or -1.
func bush_index(id: StringName) -> int:
	for b in _bush_list:
		if b.id == id:
			return b.save_index
	return -1


## Which kind a wild bush on `ground` is: picked by weight, the same for a seed.
func _wild_bush(ground: Vector2i) -> int:
	var total := 0.0
	for b in _bush_list:
		total += maxf(b.weight, 0.0)
	if total <= 0.0:
		return 0
	var r := _hash(ground, 41) * total
	for b in _bush_list:
		r -= maxf(b.weight, 0.0)
		if r <= 0.0:
			return b.save_index
	return _bush_list[-1].save_index


## Only full grown bushes have berries.
static func _ripe(p: Plant) -> bool:
	return p != null and p.kind == Kind.BUSH and p.variant % 2 == BUSH_GROWN and p.grow_left <= 0.0


## Picks the berries off a ripe bush (`ground` = the grass tile it grows on). They grow
## back in regrow_min..max seconds. Returns true if there were berries.
func request_pick_berries(ground: Vector2i, who: Player) -> bool:
	ground = world.wrap_tile(ground)
	var p: Plant = _plants.get(ground)
	if not Game.is_authority() or not _ripe(p):
		return false
	var n := randi_range(berries_min, berries_max)
	var fruit := fruit_of(p)
	if who and who.character:
		var left := who.pick_up(fruit, n)
		if left < n:
			EventBus.item_picked_up.emit(fruit, n - left)
		if left > 0:
			world.request_spawn_drop(fruit, left, who.chest())
	p.grow_left = _days(randf_range(regrow_min_days, regrow_max_days))
	_regrowing.append(ground)
	_dirty[_chunk_of(ground)] = true
	_refresh_node(ground, p)
	return true


func _refresh_node(g: Vector2i, p: Plant) -> void:
	var s := p.node.get_child(0) as Sprite2D if p.node and p.node.get_child_count() > 0 else null
	if s:
		s.texture = _texture(p)


## The ground tile of the nearest ripe berry bush within `r` tiles of `feet`, or NONE.
func nearest_ripe_bush(feet: Vector2i, r: int) -> Vector2i:
	var best := NONE
	var best_d := INF
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var g := world.wrap_tile(feet + Vector2i(dx, dy))
			var p: Plant = _plants.get(g)
			if _ripe(p) and Vector2(dx, dy).length() < best_d:
				best = feet + Vector2i(dx, dy)
				best_d = Vector2(dx, dy).length()
	return best


# --- per frame -----------------------------------------------------------------------

func _process(delta: float) -> void:
	_grow(delta)
	_regrow(delta)
	_grow_bushes(delta)
	_spread_grass(delta)


func _grow(delta: float) -> void:
	for g: Vector2i in _saplings.duplicate():
		var p: Plant = _plants.get(g)
		if p == null or p.kind != Kind.SAPLING:
			_saplings.erase(g)
			continue
		p.grow_left -= delta
		if p.grow_left > 0.0:
			continue
		if not _clear_above(g):
			p.grow_left = 10.0  # try again later
			continue
		_saplings.erase(g)
		_remove(g)
		var dark := p.variant == SAPLING_DARKWOOD and _trees.size() > _pines
		var tree := _add(g, Kind.TREE, _pines + randi() % (_trees.size() - _pines) if dark else randi() % _pines)
		tree.health = tree_health


## Time passes for every plant at once (sleeping through the night).
func advance(seconds: float) -> void:
	_grow(seconds)
	_regrow(seconds)
	_grow_bushes(seconds)


## Young bushes grow to full size.
func _grow_bushes(delta: float) -> void:
	for g: Vector2i in _young.duplicate():
		var p: Plant = _plants.get(g)
		if p == null or p.kind != Kind.BUSH or p.variant % 2 != BUSH_YOUNG:
			_young.erase(g)
			continue
		p.health -= delta
		if p.health <= 0.0:
			p.health = 0.0
			p.variant += BUSH_GROWN
			_young.erase(g)
			_dirty[_chunk_of(g)] = true
			_refresh_node(g, p)


## Real seconds for in-game days (the world's clock).
func _days(n: float) -> float:
	return world.clock.days(n) if world and world.clock else n * 24.0 * 60.0


func _regrow(delta: float) -> void:
	for g: Vector2i in _regrowing.duplicate():
		var p: Plant = _plants.get(g)
		if p == null or p.kind != Kind.BUSH:
			_regrowing.erase(g)
			continue
		p.grow_left -= delta
		if p.grow_left <= 0.0:
			p.grow_left = 0.0
			_regrowing.erase(g)
			_refresh_node(g, p)


## Dev console: every sapling grows on the next frame (if there's room). Returns how many.
func grow_all() -> int:
	for g in _saplings:
		_plants[g].grow_left = 0.0
	for g in _regrowing:
		_plants[g].grow_left = 0.001  # ripe next frame
	for g in _young:
		_plants[g].health = 0.001  # full grown next frame
	return _saplings.size() + _regrowing.size() + _young.size()


func _clear_above(g: Vector2i) -> bool:
	for dy in range(1, grow_clearance + 1):
		if world.data.get_block(g.x, g.y - dy) != WorldData.AIR:
			return false
	return true


func _spread_grass(delta: float) -> void:
	if _grass_id < 0 or _dirt_id < 0 or not Game.is_authority():
		return
	var rect := world.renderer.loaded_tile_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	_grass_budget += grass_spread_checks_per_second * delta
	var n := int(_grass_budget)
	_grass_budget -= n
	for i in n:
		var t := rect.position + Vector2i(randi() % rect.size.x, randi() % rect.size.y)
		var b := world.data.get_block(t.x, t.y)
		if world.blocks.is_dirt(b) and _exposed(t) and _near_grass(t) \
				and not world.is_solid(t + Vector2i.UP):  # grass doesn't grow under a block
			var g := world.blocks.grass_of(b)  # dirt -> grass, Dark Forest Dirt -> its grass
			if g > 0:
				world.request_set_block(t, g)


func _exposed(t: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var b := world.data.get_block(t.x + d.x, t.y + d.y)
		if b == WorldData.AIR or (b > 0 and world.blocks.collision(b) != TileDef.Collision.SOLID):
			return true
	return false


func _near_grass(t: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and world.blocks.is_grass(world.data.get_block(t.x + dx, t.y + dy)):
				return true
	return false


# --- changes ---------------------------------------------------------------------------

func _on_block_changed(tile: Vector2i, _old: int, new_id: int) -> void:
	# Grass covered by a solid block dies back to dirt (and won't spread back under it).
	if new_id > 0 and world.blocks.collision(new_id) == TileDef.Collision.SOLID:
		var under := world.wrap_tile(tile + Vector2i.DOWN)
		var ub := world.data.get_block(under.x, under.y)
		if world.blocks.is_grass(ub) and not _plants.has(under) and world.blocks.dirt_of(ub) > 0:
			world.request_set_block(under, world.blocks.dirt_of(ub))
	# The ground under a plant went away (or stopped being grass/dirt): it breaks.
	var p: Plant = _plants.get(tile)
	if p and not world.blocks.is_grass(new_id) and not world.blocks.is_dirt(new_id):
		_break(tile, p)
	# Something was put where a flower or sapling stood: it breaks.
	var below := world.wrap_tile(tile + Vector2i.DOWN)
	var q: Plant = _plants.get(below)
	if q and q.kind != Kind.TREE and new_id != WorldData.AIR:
		_break(below, q)


func _add(g: Vector2i, kind: int, variant: int, dirty: bool = true) -> Plant:
	var p := Plant.new()
	p.kind = kind
	p.variant = variant
	_plants[g] = p
	var wc := _chunk_of(g)
	if not _by_chunk.has(wc):
		_by_chunk[wc] = []
	_by_chunk[wc].append(g)
	if kind == Kind.SAPLING:
		_saplings.append(g)
	if dirty:
		_dirty[wc] = true
	for c: Vector2i in _shown:
		if _shown[c] == wc:
			_make_node(g, p, c)
	return p


func _remove(g: Vector2i) -> void:
	var p: Plant = _plants.get(g)
	if p == null:
		return
	if p.node:
		p.node.queue_free()
	var was_tree := p.kind == Kind.TREE
	var tall := roundi(_height_tiles(p) * trunk_share) if was_tree else 0
	_plants.erase(g)
	var wc := _chunk_of(g)
	(_by_chunk[wc] as Array).erase(g)
	_dirty[wc] = true
	if was_tree:
		# Torches hung on its trunk come off with it.
		for dy in range(1, tall + 1):
			for dx: int in [-1, 0, 1]:
				world.check_supports(g + Vector2i(dx, -dy))


## Breaks a plant where it stands (ground gone, cut): drops what it drops.
func _break(g: Vector2i, p: Plant) -> void:
	var pos := ground_position(g, world.player.global_position if world.player else Vector2.ZERO) + Vector2(0, -4)
	match p.kind:
		Kind.TREE:
			_drop_tree(pos, 0.0, _height_tiles(p), log_of(p))
		Kind.SAPLING:
			world.request_spawn_drop(SAPLING_ITEMS[clampi(p.variant, 0, SAPLING_ITEMS.size() - 1)], 1, pos, _pop())
		Kind.FLOWER:
			if randf() < grass_seed_chance:
				world.request_spawn_drop(&"grass_seeds", 1, pos, _pop())
		Kind.BUSH:
			if _ripe(p):
				world.request_spawn_drop(fruit_of(p), randi_range(berries_min, berries_max), pos, _pop())
	_remove(g)


## Logs a tree this tall (tiles) drops.
func logs_for(height_tiles: float) -> int:
	return maxi(1, roundi(height_tiles / maxf(tiles_per_log, 0.5)))


## A tree's height in tiles (its sprite).
func _height_tiles(p: Plant) -> float:
	return _trees[p.variant % _trees.size()].get_height() / float(TILE)


## What a tree drops: Dark Logs from darkwood trees, Logs from pines.
func log_of(p: Plant) -> StringName:
	return &"dark_log" if p.variant % _trees.size() >= _pines else &"log"


func _fell(g: Vector2i, p: Plant, dir: float) -> void:
	var height := _height_tiles(p)
	var log_id := log_of(p)
	var node := p.node
	p.node = null
	_remove(g)
	if node == null:
		_drop_tree(ground_position(g, world.player.global_position) + Vector2(0, -4), dir, _height_tiles(p), log_id)
		return
	var tw := node.create_tween()
	tw.tween_property(node, "rotation", dir * PI * 0.5, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "modulate:a", 0.0, fall_time * 0.4).set_delay(fall_time * 0.75)
	tw.tween_callback(func() -> void:
		_drop_tree(node.global_position + Vector2(0, -4), dir, height, log_id)
		node.queue_free())


## Logs along where the trunk lay, and seeds.
func _drop_tree(base: Vector2, dir: float, height_tiles: float, log_id: StringName = &"log") -> void:
	var wood := logs_for(height_tiles)
	var length := height_tiles * 0.8 * TILE  # the trunk, not the tip
	for i in wood:
		var along := (i + 0.5) / wood * length * (dir if dir != 0.0 else 0.0)
		var pos := base + Vector2(along, 0.0 if dir != 0.0 else float(-i * TILE))
		world.request_spawn_drop(log_id, 1, pos, _pop())
	var seeds := 1 + (1 if randf() < extra_seed_chance else 0)
	var seed_id := &"darkwood_sapling" if log_id == &"dark_log" else &"tree_seed"
	world.request_spawn_drop(seed_id, seeds, base + Vector2(dir * length * 0.6, 0), _pop())


func _pop() -> Vector2:
	return Vector2(randf_range(-4.0, 4.0), randf_range(-10.0, -6.0)) * TILE


func _wiggle(node: Node2D) -> void:
	var a := deg_to_rad(wiggle_degrees)
	var tw := node.create_tween()
	tw.tween_property(node, "rotation", a, 0.05)
	tw.tween_property(node, "rotation", -a * 0.6, 0.08)
	tw.tween_property(node, "rotation", a * 0.3, 0.07)
	tw.tween_property(node, "rotation", 0.0, 0.06)


func _make_node(g: Vector2i, p: Plant, shown_chunk: Vector2i) -> void:
	if p.node:
		p.node.queue_free()
	var local := g - _chunk_of(g) * SIZE
	var node := Node2D.new()
	# Pivot at the base of the stem, so wiggles and falls rotate around the ground.
	node.position = Vector2((shown_chunk * SIZE + local) * TILE) + Vector2(TILE * 0.5, 0)
	var s := Sprite2D.new()
	s.texture = _texture(p)
	s.centered = false
	var lift := 3 if p.kind == Kind.TREE else 1
	s.position = Vector2(-floorf(s.texture.get_width() / 2.0), lift - s.texture.get_height())
	if p.kind == Kind.TREE:
		# A little variety until there's more tree art: mirrored or not, and a slight
		# lean from the base (the same for the same tree every time).
		var h := hash(g)
		if h % 2 == 1:
			s.flip_h = true
			s.position.x = -ceilf(s.texture.get_width() / 2.0)
		node.skew = deg_to_rad(lerpf(-tree_lean_degrees, tree_lean_degrees, float((h >> 4) % 1000) / 999.0))
	node.add_child(s)
	add_child(node)
	p.node = node


func _texture(p: Plant) -> Texture2D:
	match p.kind:
		Kind.TREE:
			return _trees[p.variant % _trees.size()]
		Kind.SAPLING:
			return _dark_sapling_tex if p.variant == SAPLING_DARKWOOD and _dark_sapling_tex else _sapling_tex
		Kind.BUSH:
			var b := bush_kind(p)
			if b == null:
				return _sapling_tex
			if p.variant % 2 != BUSH_GROWN:
				return b.young_texture  # young: no berries yet
			return b.ripe_texture if p.grow_left <= 0.0 else b.bare_texture
	return _flowers[p.variant % _flowers.size()]


func _chunk_of(g: Vector2i) -> Vector2i:
	return Vector2i(floori(float(g.x) / SIZE), floori(float(g.y) / SIZE))


# --- save ------------------------------------------------------------------------------

## Plant state of chunks that changed (plants or blocks), for the world file.
func to_dict(modified_chunks: Array[Vector2i]) -> Dictionary:
	var keep: Dictionary[Vector2i, bool] = _dirty.duplicate()
	for c in modified_chunks:
		if _seeded.has(c):
			keep[c] = true
	var out := {}
	for wc: Vector2i in keep:
		var list: Array = []
		for g: Vector2i in _by_chunk.get(wc, []):
			var p: Plant = _plants[g]
			list.append([g.x, g.y, p.kind, p.variant, p.health, p.grow_left])
		out["%d,%d" % [wc.x, wc.y]] = list
	return out


## `has_forage_save`: the world file has its own forage data (else older loose sticks,
## rocks and flint saved with the plants move to the Forage node).
func from_dict(d: Dictionary, has_forage_save: bool = true) -> void:
	for key: String in d:
		var parts := key.split(",")
		var wc := Vector2i(int(parts[0]), int(parts[1]))
		_seeded[wc] = true
		_dirty[wc] = true
		if world.forage and not has_forage_save:
			world.forage.take_legacy_chunk(wc)
		for e: Array in d[key]:
			if int(e[2]) == Kind.PICKUP:
				if world.forage and not has_forage_save:
					world.forage.take_legacy(Vector2i(int(e[0]), int(e[1])), int(e[3]))
				continue
			var p := _add(Vector2i(int(e[0]), int(e[1])), int(e[2]), int(e[3]))
			p.health = float(e[4])
			p.grow_left = float(e[5])
			if p.kind == Kind.BUSH and p.grow_left > 0.0:
				_regrowing.append(Vector2i(int(e[0]), int(e[1])))
			if p.kind == Kind.BUSH and p.variant % 2 == BUSH_YOUNG:
				_young.append(Vector2i(int(e[0]), int(e[1])))
