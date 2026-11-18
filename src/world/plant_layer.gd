class_name PlantLayer
extends Node2D
## Trees, saplings and flowers, plus grass spreading onto dirt.
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

enum Kind { TREE, SAPLING, FLOWER, PICKUP, BUSH }

## Things lying on the grass (Kind.PICKUP variants), the item each gives.
## Berry bush variants.
const BUSH_YOUNG := 0
const BUSH_GROWN := 1
const PICKUP_ITEMS: Array[StringName] = [&"stick", &"rock", &"flint"]

@export_group("Trees")
## Damage a tree takes before it falls. A copper axe does 25 per hit.
@export var tree_health := 100.0
## Wood dropped by a fallen tree (random in this range).
@export var wood_min := 4
@export var wood_max := 7
## Seeds dropped: always 1, plus this chance of a second.
@export_range(0.0, 1.0) var extra_seed_chance := 0.5
## Seconds a tree takes to fall over.
@export var fall_time := 0.9
## Degrees a tree rocks when hit.
@export var wiggle_degrees := 4.0
## Trees need this many tiles between their trunks (planting).
@export var tree_spacing := 3
## Tiles of clear space above the ground a sapling needs to grow.
@export var grow_clearance := 10
@export_group("Saplings")
## Seconds a sapling takes to grow into a tree (random in this range, while the world
## is running).
@export var grow_min_seconds := 60.0
@export var grow_max_seconds := 150.0
@export_group("Things on the grass")
## Share of the generator's flower spots that are sticks, rocks or flint instead.
@export_range(0.0, 1.0) var pickup_share := 0.4
## Of those, how many are flint (the rest split between sticks and rocks).
@export_range(0.0, 1.0) var flint_share := 0.2
## Sticks a felled tree drops (random in this range).
@export var sticks_min := 1
@export var sticks_max := 3
@export_group("Berry bushes")
## Share of flower spots that are a berry bush instead.
@export_range(0.0, 1.0) var bush_share := 0.06
## Berries picked from a ripe bush (right click or E).
@export var berries_min := 1
@export var berries_max := 3
## Share of bushes the world starts with full grown (the rest are young).
@export_range(0.0, 1.0) var bush_grown_share := 0.7
## Seconds for a young bush to grow full size (with berries). Young bushes have none.
@export var bush_grow_min_seconds := 4320.0
@export var bush_grow_max_seconds := 7200.0
## Seconds until a picked bush has berries again (72 to 120 minutes: about 3 to 5
## in-game days once there's a day clock). Wild bushes are slow and stingy on purpose;
## farming will be the better way to get food.
@export var regrow_min_seconds := 4320.0
@export var regrow_max_seconds := 7200.0
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
var _flowers: Array[Texture2D] = []
var _sapling_tex: Texture2D
var _pickup_tex: Array[Texture2D] = []
## [young, grown ripe, grown picked].
var _bush_tex: Array[Texture2D] = []
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
	for i in 5:
		_flowers.append(load("res://assets/decor/flower_%d.png" % i) as Texture2D)
	_sapling_tex = load("res://assets/decor/sapling.png") as Texture2D
	for f: String in ["berry_bush_young", "berry_bush", "berry_bush_bare"]:
		_bush_tex.append(load("res://assets/decor/%s.png" % f) as Texture2D)
	for kind: StringName in PICKUP_ITEMS:
		_pickup_tex.append(load("res://assets/decor/pickup_%s.png" % kind) as Texture2D)
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


## True when a block placed on `tile` would go through a tree trunk.
func blocks_placement(tile: Vector2i) -> bool:
	for dy in range(1, 5):
		var plant: Plant = _plants.get(world.wrap_tile(tile + Vector2i(0, dy)))
		if plant and plant.kind == Kind.TREE:
			return true
	return false


## Where a tree seed would be planted for a cursor tile (the grass under it), or NONE.
func sapling_spot(tile: Vector2i) -> Vector2i:
	for g: Vector2i in [tile, tile + Vector2i.DOWN]:
		if world.data.get_block(g.x, g.y) == _grass_id and world.data.get_block(g.x, g.y - 1) == WorldData.AIR:
			if _plants.has(world.wrap_tile(g)):
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


## Plants a sapling on the grass tile `ground`. Returns true if it was planted.
func request_plant_tree(ground: Vector2i) -> bool:
	if not Game.is_authority() or sapling_spot(ground) != world.wrap_tile(ground):
		return false
	var p := _add(world.wrap_tile(ground), Kind.SAPLING, 0)
	p.grow_left = randf_range(grow_min_seconds, grow_max_seconds)
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

func _on_chunk_shown(c: Vector2i, spots: PackedInt32Array) -> void:
	var wc := Vector2i(posmod(c.x, world.data.chunks_x), c.y)
	if not _seeded.has(wc):
		_seeded[wc] = true
		for i in range(0, spots.size(), 4):
			var ground := world.wrap_tile(wc * SIZE + Vector2i(spots[i], spots[i + 1]))
			if spots[i + 2] >= 0:
				var p := _add(ground, Kind.TREE, spots[i + 2], false)
				p.health = tree_health
			elif _hash(ground, 31) < bush_share:
				var young := _hash(ground, 37) >= bush_grown_share
				var bush := _add(ground, Kind.BUSH, BUSH_YOUNG if young else BUSH_GROWN, false)
				if young:
					bush.health = randf_range(bush_grow_min_seconds, bush_grow_max_seconds)
					_young.append(ground)
			elif _hash(ground, 11) < pickup_share:
				var h := _hash(ground, 23)
				var variant := 2 if h < flint_share else (0 if h < flint_share + (1.0 - flint_share) * 0.5 else 1)
				_add(ground, Kind.PICKUP, variant, false)
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


## A steady 0..1 number per tile (so a spot is always the same kind of pickup).
static func _hash(t: Vector2i, salt: int) -> float:
	var h := (t.x * 73856093) ^ (t.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xffff) / 65535.0


## Right click on something lying on the grass (`tile` = where it lies): it goes into
## the inventory. Returns true if there was something.
func request_pick_up(tile: Vector2i, who: Player) -> bool:
	if not Game.is_authority():
		return false
	var bush := _bush_near(tile)
	if bush != NONE:
		return request_pick_berries(bush, who)
	var g := world.wrap_tile(tile + Vector2i.DOWN)
	var p: Plant = _plants.get(g)
	if p == null or p.kind != Kind.PICKUP or who == null or who.character == null:
		return false
	var item_id := PICKUP_ITEMS[p.variant % PICKUP_ITEMS.size()]
	if who.character.inventory.add(item_id, 1) > 0:
		return false  # no room
	EventBus.item_picked_up.emit(item_id, 1)
	_remove(g)
	return true


## A ripe berry bush covering `tile` (bushes are about 2x2 tiles), or NONE.
func _bush_near(tile: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, 2), Vector2i(1, 2)]:
		var g := world.wrap_tile(tile + d)
		var p: Plant = _plants.get(g)
		if p and p.kind == Kind.BUSH:
			return g
	return NONE


func is_ripe(ground: Vector2i) -> bool:
	var p: Plant = _plants.get(world.wrap_tile(ground))
	return _ripe(p)


## Only full grown bushes have berries.
static func _ripe(p: Plant) -> bool:
	return p != null and p.kind == Kind.BUSH and p.variant == BUSH_GROWN and p.grow_left <= 0.0


## Picks the berries off a ripe bush (`ground` = the grass tile it grows on). They grow
## back in regrow_min..max seconds. Returns true if there were berries.
func request_pick_berries(ground: Vector2i, who: Player) -> bool:
	ground = world.wrap_tile(ground)
	var p: Plant = _plants.get(ground)
	if not Game.is_authority() or not _ripe(p):
		return false
	var n := randi_range(berries_min, berries_max)
	if who and who.character:
		var left := who.character.inventory.add(&"berries", n)
		if left < n:
			EventBus.item_picked_up.emit(&"berries", n - left)
		if left > 0:
			world.request_spawn_drop(&"berries", left, who.chest())
	p.grow_left = randf_range(regrow_min_seconds, regrow_max_seconds)
	_regrowing.append(ground)
	_dirty[_chunk_of(ground)] = true
	_refresh_node(ground, p)
	return true


func _refresh_node(g: Vector2i, p: Plant) -> void:
	var s := p.node.get_child(0) as Sprite2D if p.node and p.node.get_child_count() > 0 else null
	if s:
		s.texture = _texture(p)


## The ground tile of the nearest pickup within `r` tiles of `feet`, or NONE.
func nearest_pickup(feet: Vector2i, r: int) -> Vector2i:
	var best := NONE
	var best_d := INF
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var g := world.wrap_tile(feet + Vector2i(dx, dy))
			var p: Plant = _plants.get(g)
			var ripe := _ripe(p)
			if p and (p.kind == Kind.PICKUP or ripe) and Vector2(dx, dy).length() < best_d:
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
		var tree := _add(g, Kind.TREE, randi() % _trees.size())
		tree.health = tree_health


## Young bushes grow to full size.
func _grow_bushes(delta: float) -> void:
	for g: Vector2i in _young.duplicate():
		var p: Plant = _plants.get(g)
		if p == null or p.kind != Kind.BUSH or p.variant != BUSH_YOUNG:
			_young.erase(g)
			continue
		p.health -= delta
		if p.health <= 0.0:
			p.health = 0.0
			p.variant = BUSH_GROWN
			_young.erase(g)
			_dirty[_chunk_of(g)] = true
			_refresh_node(g, p)


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
		if world.data.get_block(t.x, t.y) == _dirt_id and _exposed(t) and _near_grass(t) \
				and not world.is_solid(t + Vector2i.UP):  # grass doesn't grow under a block
			world.request_set_block(t, _grass_id)


func _exposed(t: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var b := world.data.get_block(t.x + d.x, t.y + d.y)
		if b == WorldData.AIR or (b > 0 and world.blocks.collision(b) != TileDef.Collision.SOLID):
			return true
	return false


func _near_grass(t: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and world.data.get_block(t.x + dx, t.y + dy) == _grass_id:
				return true
	return false


# --- changes ---------------------------------------------------------------------------

func _on_block_changed(tile: Vector2i, _old: int, new_id: int) -> void:
	# Grass covered by a solid block dies back to dirt (and won't spread back under it).
	if new_id > 0 and world.blocks.collision(new_id) == TileDef.Collision.SOLID:
		var under := world.wrap_tile(tile + Vector2i.DOWN)
		if world.data.get_block(under.x, under.y) == _grass_id and not _plants.has(under):
			world.request_set_block(under, _dirt_id)
	# The ground under a plant went away (or stopped being grass/dirt): it breaks.
	var p: Plant = _plants.get(tile)
	if p and new_id != _grass_id and new_id != _dirt_id:
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
	_plants.erase(g)
	var wc := _chunk_of(g)
	(_by_chunk[wc] as Array).erase(g)
	_dirty[wc] = true


## Breaks a plant where it stands (ground gone, cut): drops what it drops.
func _break(g: Vector2i, p: Plant) -> void:
	var pos := ground_position(g, world.player.global_position if world.player else Vector2.ZERO) + Vector2(0, -4)
	match p.kind:
		Kind.TREE:
			_drop_tree(pos, 0.0)
		Kind.SAPLING:
			world.request_spawn_drop(&"tree_seed", 1, pos, _pop())
		Kind.FLOWER:
			if randf() < grass_seed_chance:
				world.request_spawn_drop(&"grass_seeds", 1, pos, _pop())
		Kind.PICKUP:
			world.request_spawn_drop(PICKUP_ITEMS[p.variant % PICKUP_ITEMS.size()], 1, pos, _pop())
		Kind.BUSH:
			if _ripe(p):
				world.request_spawn_drop(&"berries", randi_range(berries_min, berries_max), pos, _pop())
	_remove(g)


func _fell(g: Vector2i, p: Plant, dir: float) -> void:
	var node := p.node
	p.node = null
	_remove(g)
	if node == null:
		_drop_tree(ground_position(g, world.player.global_position) + Vector2(0, -4), dir)
		return
	var tw := node.create_tween()
	tw.tween_property(node, "rotation", dir * PI * 0.5, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "modulate:a", 0.0, fall_time * 0.4).set_delay(fall_time * 0.75)
	tw.tween_callback(func() -> void:
		_drop_tree(node.global_position + Vector2(0, -4), dir)
		node.queue_free())


## Wood along where the trunk lay, and seeds.
func _drop_tree(base: Vector2, dir: float) -> void:
	var wood := randi_range(wood_min, wood_max)
	var length := 10.0 * TILE
	for i in wood:
		var along := (i + 0.5) / wood * length * (dir if dir != 0.0 else 0.0)
		var pos := base + Vector2(along, 0.0 if dir != 0.0 else float(-i * TILE))
		world.request_spawn_drop(&"wood", 1, pos, _pop())
	var sticks := randi_range(sticks_min, sticks_max)
	if sticks > 0:
		world.request_spawn_drop(&"stick", sticks, base + Vector2(-dir * TILE, -TILE), _pop())
	var seeds := 1 + (1 if randf() < extra_seed_chance else 0)
	world.request_spawn_drop(&"tree_seed", seeds, base + Vector2(dir * length * 0.6, 0), _pop())


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
	node.add_child(s)
	add_child(node)
	p.node = node


func _texture(p: Plant) -> Texture2D:
	match p.kind:
		Kind.TREE:
			return _trees[p.variant % _trees.size()]
		Kind.SAPLING:
			return _sapling_tex
		Kind.PICKUP:
			return _pickup_tex[p.variant % _pickup_tex.size()]
		Kind.BUSH:
			if p.variant != BUSH_GROWN:
				return _bush_tex[0]  # young: no berries yet
			return _bush_tex[1 if p.grow_left <= 0.0 else 2]
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


func from_dict(d: Dictionary) -> void:
	for key: String in d:
		var parts := key.split(",")
		var wc := Vector2i(int(parts[0]), int(parts[1]))
		_seeded[wc] = true
		_dirty[wc] = true
		for e: Array in d[key]:
			var p := _add(Vector2i(int(e[0]), int(e[1])), int(e[2]), int(e[3]))
			p.health = float(e[4])
			p.grow_left = float(e[5])
			if p.kind == Kind.BUSH and p.grow_left > 0.0:
				_regrowing.append(Vector2i(int(e[0]), int(e[1])))
			if p.kind == Kind.BUSH and p.variant == BUSH_YOUNG:
				_young.append(Vector2i(int(e[0]), int(e[1])))
