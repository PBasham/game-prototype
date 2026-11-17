class_name ItemUser
extends Node2D
## Uses the item in the player's hand on the world, and draws the targeting indicators.
## Left click works on the front layer, right click on the back layer (Starbound-like).
##
## - Mining (pickaxes: one hit per swing; spells: a beam while held): damages every
##   block (left) or background wall (right, also behind blocks) in the area around the
##   cursor that's within reach.
## - Chopping (axes, left click): hits the tree under the cursor.
## - Placing: left click places a block, right click places it as a background wall.
##   Seeds plant with left click.
## - Any swing cuts flowers in front of the player (grass seed chance).
## - Spells (from the wheel, a hotbar shortcut or a tome) are stronger with a better
##   book or conduit, and can need a conduit (CharacterData.cast_problem).
##
## Indicators (Starbound-like): a box around the target area (white = will work, blue =
## back layer, red = out of reach or nothing to do), ghost blocks where blocks will go,
## the beam from the casting hand, and a range ring that fades in as the cursor nears
## the edge of reach. Ctrl + mouse wheel changes the area.

enum Mode { NONE, MINE, CHOP, PLACE_BLOCK, PLACE_WALL, PLANT_TREE, PLANT_GRASS }

const TILE := World.TILE

@export_group("Indicators")
@export var valid_color := Color(1, 1, 1, 0.85)
## Target box for the back layer (right click held).
@export var back_color := Color(0.6, 0.82, 1.0, 0.85)
@export var invalid_color := Color(1.0, 0.28, 0.22, 0.9)
@export var ghost_alpha := 0.5
@export var beam_color := Color(0.55, 0.9, 1.0, 0.9)
## The range ring starts fading in when the cursor is this fraction of the reach away.
@export_range(0.0, 1.0) var ring_fade_start := 0.7
@export var ring_alpha := 0.45
@export_group("Swings")
## Tiles in front of the player that a swing cuts flowers in.
@export var swing_cut_tiles := 3
@export_group("")

var world: World
## Tests and scripted runs aim here instead of at the mouse (INF = use the mouse).
var cursor_override := Vector2.INF
## Chosen area size per item id (Ctrl + wheel).
var _area: Dictionary[StringName, int] = {}
var _area_shown := 0.0

# The target this frame.
var mode := Mode.NONE
var rect := Rect2i()
var valid: Array[Vector2i] = []
var tree := PlantLayer.NONE
## Targeting the back layer (right click).
var back := false
## Why the held spell can't be cast ("" = it can).
var problem := ""
var _item: ItemData


func _ready() -> void:
	z_index = 20
	world.player.use_impact.connect(_on_impact)
	world.player.area_scrolled.connect(_on_area_scrolled)
	world.player.use_check = can_use


func _process(delta: float) -> void:
	_area_shown = maxf(_area_shown - delta, 0.0)
	var p := world.player
	# While using, the layer of that use; otherwise preview the back layer while right
	# click is held.
	update_target(cursor(), p.use_back if p.is_using() else Input.is_action_pressed("use_secondary"))
	if _item and _item.beam and mode == Mode.MINE and p.is_using() and not p.input_blocked:
		for t in valid:
			if back:
				world.request_damage_wall(t, damage() * delta)
			else:
				world.request_damage_block(t, damage() * delta)
		if not back:
			world.plants.request_cut_flowers(rect)
	queue_redraw()


## Mining damage of the item in use, with spell strength from the book and conduit.
func damage() -> float:
	if _item == null:
		return 0.0
	return _item.mining_damage * (_spell_power() if _item.is_spell() else 1.0)


func reach() -> float:
	if _item == null:
		return 0.0
	var c := world.player.character
	if _places(_item):
		# Building reach comes from the spellbook (the book is the building tool).
		if _item.place_reach_tiles > 0.0 or c == null:
			return maxf(_item.place_reach_tiles, 1.0) * TILE
		return (c.book().build_reach_tiles + c.spell_reach_bonus()) * TILE
	var bonus := c.spell_reach_bonus() if _item.is_spell() and c else 0.0
	return (_item.reach_tiles + bonus) * TILE


## Blocks, walls and seeds (not tools or spells).
static func _places(item: ItemData) -> bool:
	return item.mining_damage <= 0.0 and item.axe_damage <= 0.0 \
		and (item.places_block != &"" or item.places_wall != &"" or item.plants != &"")


func _spell_power() -> float:
	var p := world.player
	if p.character == null:
		return 1.0
	var tome := p.held_item if p.held_item and p.held_item.tome_spell != &"" else null
	return p.character.spell_power(tome)


## Where the player is aiming (world px).
func cursor() -> Vector2:
	return cursor_override if cursor_override.is_finite() else get_global_mouse_position()


## Works out what the held item would do at `at` (world px), on the back layer with
## `on_back`: fills mode, rect, valid (tiles it would affect), tree and problem.
func update_target(at: Vector2, on_back: bool = false) -> void:
	var p := world.player
	_item = p.use_item() if not p.stowed else null
	back = on_back
	mode = _mode_for(_item, back)
	valid.clear()
	tree = PlantLayer.NONE
	problem = ""
	if mode == Mode.NONE:
		return
	if _item.is_spell() and p.character:
		var from_tome := p.held_item != null and p.held_item.tome_spell != &""
		problem = p.character.cast_problem(_item as SpellData, from_tome)
	var size := area_size(_item)
	var c := at / TILE
	rect = Rect2i(Vector2i(floori(c.x - size / 2.0 + 0.5), floori(c.y - size / 2.0 + 0.5)), Vector2i(size, size))
	match mode:
		Mode.MINE:
			if problem != "":
				return
			var types := world.walls if back else world.blocks
			for t in _tiles():
				var id := world.data.get_wall(t.x, t.y) if back else world.data.get_block(t.x, t.y)
				var def := types.def(id) if id > 0 else null
				if def and not def.unbreakable and def.health > 0.0 and t.y < world.data.height - 1 and _in_reach(t):
					valid.append(t)
		Mode.CHOP:
			var g := world.plants.tree_at_point(at)
			if g != PlantLayer.NONE:
				var base := world.plants.ground_position(g, p.global_position)
				var bt := Vector2i(floori(base.x / TILE), g.y)
				rect = Rect2i(bt + Vector2i(0, -3), Vector2i(1, 3))
				if _in_reach(bt + Vector2i.UP):
					tree = g
			else:
				rect = Rect2i(Vector2i(floori(c.x), floori(c.y)), Vector2i.ONE)
		Mode.PLACE_BLOCK, Mode.PLACE_WALL:
			_place_targets()
		Mode.PLANT_TREE:
			var g := world.plants.sapling_spot(Vector2i(floori(c.x), floori(c.y)))
			if g != PlantLayer.NONE:
				# Back to unwrapped coords near the cursor.
				var gx := floori(c.x) + (g.x - posmod(floori(c.x), world.data.width))
				var spot := Vector2i(gx, g.y - 1)
				rect = Rect2i(spot, Vector2i.ONE)
				if _in_reach(spot):
					valid.append(spot + Vector2i.DOWN)
		Mode.PLANT_GRASS:
			var dirt := world.blocks.index_of(&"dirt")
			for t in _tiles():
				if world.data.get_block(t.x, t.y) == dirt and _exposed(t) and _in_reach(t):
					valid.append(t)
			_limit_to_stack()


## False when using the held item would do nothing (no swing for a block with nowhere
## to go, a spell that can't be cast, a right click the item has no use for). Tools and
## weapons always swing with left click.
func can_use(on_back: bool = false) -> bool:
	update_target(cursor(), on_back)
	if problem != "":
		EventBus.debug_message.emit(problem)
		return false
	match mode:
		Mode.PLACE_BLOCK, Mode.PLACE_WALL, Mode.PLANT_TREE, Mode.PLANT_GRASS:
			return not valid.is_empty()
		Mode.NONE:
			return not on_back
	return true


func area_size(item: ItemData) -> int:
	if item == null:
		return 1
	var lo := 1
	var hi := 1
	var start := 1
	if item.mining_damage > 0.0:
		# Fixed area (pickaxes) unless mining_area_max gives a range to toggle through.
		hi = maxi(item.mining_area_max, item.mining_area)
		lo = 1 if hi > item.mining_area else item.mining_area
		start = item.mining_area
		start = item.mining_area
	elif _places(item):
		var c := world.player.character
		hi = c.book().build_area_max if c and c.book() else 2
		if item.place_area_max > 0:
			hi = mini(hi, item.place_area_max)
		start = 1
	return clampi(_area.get(_area_key(item), start), lo, maxi(hi, lo))


## Spells and building share one area setting (like Starbound's matter manipulator);
## other tools keep their own.
func _area_key(item: ItemData) -> StringName:
	return &"book" if item.is_spell() or _places(item) else item.id


func _on_area_scrolled(step: int) -> void:
	var item := world.player.use_item()
	if item == null:
		return
	var key := _area_key(item)
	_area[key] = area_size(item) + step
	_area[key] = area_size(item)  # clamped
	_area_shown = 1.0


func _mode_for(item: ItemData, on_back: bool) -> Mode:
	if item == null:
		return Mode.NONE
	if item.mining_damage > 0.0:
		return Mode.MINE
	if on_back:
		return Mode.PLACE_WALL if item.places_wall != &"" else Mode.NONE
	if item.axe_damage > 0.0:
		return Mode.CHOP
	if item.places_block != &"":
		return Mode.PLACE_BLOCK
	if item.plants == &"tree":
		return Mode.PLANT_TREE
	if item.plants == &"grass":
		return Mode.PLANT_GRASS
	return Mode.NONE


func _tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out


func _in_reach(t: Vector2i) -> bool:
	var center := Vector2(t * TILE) + Vector2(TILE, TILE) * 0.5
	return center.distance_to(world.player.chest()) <= reach()


func _exposed(t: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if world.data.get_block(t.x + d.x, t.y + d.y) == WorldData.AIR:
			return true
	return false


## Blocks: empty tiles in reach, not inside the player or a tree trunk, touching a block
## or a wall (directly or through other tiles placed in the same click). Walls: tiles
## without a wall, touching a wall or a block. free_place items skip the touching rule.
func _place_targets() -> void:
	var walls := mode == Mode.PLACE_WALL
	var body := world.player.body_rect()
	var open: Array[Vector2i] = []
	for t in _tiles():
		if not _in_reach(t):
			continue
		if walls:
			if world.data.get_wall(t.x, t.y) == WorldData.AIR:
				open.append(t)
		elif world.data.get_block(t.x, t.y) == WorldData.AIR and not world.plants.blocks_placement(t) \
				and not body.intersects(Rect2(Vector2(t * TILE), Vector2(TILE, TILE))):
			open.append(t)
	if _item.free_place:
		valid = open
	else:
		# Grow outward from the tiles that touch something.
		var anchored: Array[Vector2i] = []
		for t in open:
			if _anchored(t, walls):
				anchored.append(t)
		var i := 0
		while i < anchored.size():
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n := anchored[i] + d
				if n in open and not n in anchored:
					anchored.append(n)
			i += 1
		valid = anchored
	_limit_to_stack()


func _anchored(t: Vector2i, walls: bool) -> bool:
	if walls and world.data.get_block(t.x, t.y) > 0:
		return true
	if not walls and world.data.get_wall(t.x, t.y) > 0:
		return true
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var b := world.data.get_block(t.x + d.x, t.y + d.y)
		if b > 0 or b == WorldData.OUT_OF_BOUNDS:
			return true
		if walls and world.data.get_wall(t.x + d.x, t.y + d.y) > 0:
			return true
	return false


## Can't place more than the selected stack holds.
func _limit_to_stack() -> void:
	var p := world.player
	var have := p.character.inventory.counts[p.selected] if p.character and p.selected >= 0 else 0
	if valid.size() > have:
		valid.resize(have)


func _on_impact(item: ItemData) -> void:
	var p := world.player
	update_target(cursor(), p.use_back)
	var inv := p.character.inventory
	match mode:
		Mode.MINE:
			if not item.beam:
				for t in valid:
					if back:
						world.request_damage_wall(t, damage())
					else:
						world.request_damage_block(t, damage())
		Mode.CHOP:
			if tree != PlantLayer.NONE:
				world.plants.request_hit_tree(tree, item.axe_damage, p.global_position.x)
		Mode.PLACE_BLOCK:
			var id := world.blocks.index_of(item.places_block)
			for t in valid:
				if inv.counts[p.selected] > 0 and world.request_set_block(t, id):
					inv.take(p.selected, 1)
		Mode.PLACE_WALL:
			var id := world.walls.index_of(item.places_wall)
			for t in valid:
				if inv.counts[p.selected] > 0 and world.request_set_wall(t, id):
					inv.take(p.selected, 1)
		Mode.PLANT_TREE:
			for g in valid:
				if world.plants.request_plant_tree(g):
					inv.take(p.selected, 1)
		Mode.PLANT_GRASS:
			var grass := world.blocks.index_of(&"grass")
			for t in valid:
				if inv.counts[p.selected] > 0 and world.request_set_block(t, grass):
					inv.take(p.selected, 1)
	if not back and (item.kind == ItemData.Kind.TOOL or item.kind == ItemData.Kind.WEAPON):
		_cut_flowers_in_swing()


## A swing cuts flowers in front of the player.
func _cut_flowers_in_swing() -> void:
	var p := world.player
	var feet := Vector2i(floori(p.global_position.x / TILE), floori((p.global_position.y - 1.0) / TILE))
	var x0 := feet.x if p.facing > 0 else feet.x - swing_cut_tiles
	world.plants.request_cut_flowers(Rect2i(Vector2i(x0, feet.y - 4), Vector2i(swing_cut_tiles + 1, 5)))


# --- drawing -------------------------------------------------------------------------

func _draw() -> void:
	if mode == Mode.NONE or world.player.input_blocked:
		return
	var p := world.player
	var aim := cursor()
	var reach := reach()
	var ok := not valid.is_empty() or (mode == Mode.CHOP and tree != PlantLayer.NONE)
	var color := (back_color if back else valid_color) if ok else invalid_color
	# Range ring: fades in near the edge of reach (and stays when past it).
	var d := aim.distance_to(p.chest())
	var k := clampf((d - ring_fade_start * reach) / maxf((1.0 - ring_fade_start) * reach, 1.0), 0.0, 1.0)
	if k > 0.0:
		var ring := valid_color if d <= reach else invalid_color
		ring.a = ring_alpha * k
		draw_arc(p.chest(), reach, 0.0, TAU, 128, ring, 1.0)
	# Ghost blocks where blocks or walls will go.
	if mode in [Mode.PLACE_BLOCK, Mode.PLACE_WALL, Mode.PLANT_GRASS] and _item.icon:
		var ghost_tex := _item.icon
		if mode == Mode.PLANT_GRASS:
			ghost_tex = (ItemData.find(&"dirt").icon if ItemData.find(&"dirt") else null)
		for t in valid:
			var r := Rect2(Vector2(t * TILE), Vector2(TILE, TILE))
			if mode == Mode.PLANT_GRASS:
				draw_rect(r, Color(0.35, 0.75, 0.25, ghost_alpha))
			elif ghost_tex:
				var tint := Color(0.6, 0.6, 0.65, ghost_alpha) if back else Color(1, 1, 1, ghost_alpha)
				draw_texture_rect_region(ghost_tex, r, Rect2(2, 2, 12, 12), tint)
	# Beam from the hand to the target.
	if _item.beam and p.is_using():
		var from := p.casting_hand_position() if _item.is_spell() else p.doll_item_position()
		var to := Vector2(rect.position * TILE) + Vector2(rect.size * TILE) * 0.5
		var glow := beam_color if ok else invalid_color
		glow.a *= 0.3
		draw_line(from, to, glow, 3.0)
		var core := beam_color if ok else invalid_color
		core.a *= 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.03)
		draw_line(from, to, core, 1.0)
	# Target box.
	draw_rect(Rect2(Vector2(rect.position * TILE), Vector2(rect.size * TILE)).grow(0.5), color, false, 1.0)
	if problem != "":
		var font := ThemeDB.fallback_font
		draw_string(font, aim + Vector2(6, -4), problem, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, invalid_color)
	if _area_shown > 0.0:
		var font := ThemeDB.fallback_font
		var label := "%dx%d" % [rect.size.x, rect.size.y]
		var c := Color(1, 1, 1, minf(_area_shown * 2.0, 1.0))
		draw_string(font, Vector2(rect.end * TILE) + Vector2(2, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, c)
