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

enum Mode { NONE, MINE, CHOP, PLACE_BLOCK, PLACE_WALL, PLACE_OBJECT, PLANT_TREE, PLANT_GRASS, CAST, TOGGLE, EAT,
	CHARGE, SCROLL, THROW, PAGE, GRAB }

const TILE := World.TILE

@export_group("Melee")
## Swings (swords) hit from this many tiles above your chest down to this many below
## your feet, so they reach an enemy downhill.
@export var swing_above_chest_tiles := 6.0
@export var swing_below_feet_tiles := 3.0
## The same while you're off the ground (flying, levitating, jumping): no slope to reach
## down, so a swing doesn't hit things far below you.
@export var swing_below_feet_airborne_tiles := 0.0
## Aimed attacks (punches): the most they turn up or down from straight ahead, and how
## wide their line is (tiles).
@export var aimed_hit_limit_degrees := 60.0
@export var aimed_hit_width_tiles := 3.0
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
## Dev console `reach`: mining, chopping and placing reach anywhere on screen.
var infinite_reach := false
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
## The frame something was last eaten (a right click asks twice in one frame).
var _eat_frame := -1
## When each spell (by id) can be cast again (seconds, engine time), for cooldowns.
var _ready_at: Dictionary[StringName, float] = {}


func _ready() -> void:
	z_index = 20
	_phantom_node = PhantomTool.new()
	_phantom_node.visible = false
	add_child(_phantom_node)
	world.player.use_impact.connect(_on_impact)
	world.player.weapon_slammed.connect(slam)
	world.player.area_scrolled.connect(_on_area_scrolled)
	world.player.use_check = can_use


func _process(delta: float) -> void:
	_area_shown = maxf(_area_shown - delta, 0.0)
	_update_charge(delta)
	var p := world.player
	# While using, the layer of that use; otherwise preview the back layer while right
	# click is held.
	update_target(cursor(), p.use_back if p.is_using() else Input.is_action_pressed("use_secondary"))
	# Hovering: when the front layer has nothing to do here but the back layer does
	# (a wall can go here, or there's a wall to mine), show the back target (blue).
	if not p.is_using() and not back and valid.is_empty() and problem == "" \
			and mode in [Mode.MINE, Mode.PLACE_BLOCK]:
		update_target(cursor(), true)
		if valid.is_empty():
			update_target(cursor(), false)
	# Spell beams drain mana while they run, and stop when it's gone.
	if _item and _item.beam and _item.is_spell() and p.is_using() and not p.input_blocked \
			and not p.is_free_spell(_item as SpellData):
		if not p.spend_mana(p.mana_cost_of(_item as SpellData, true) * delta):
			p.stop_using()
			EventBus.debug_message.emit("Out of mana")
	if mode == Mode.GRAB and p.is_using() and not p.input_blocked and problem == "":
		var sp := _item as SpellData
		world.tele_grab(grab_point(), sp.grab_tiles * TILE, sp.grab_pull_speed * TILE)
	# A phantom tool lands its hits once per swing; a plain beam works smoothly.
	var working := _item != null and _item.beam and p.is_using() and not p.input_blocked \
		and ((mode == Mode.CHOP and tree != PlantLayer.NONE) or (mode == Mode.MINE and not valid.is_empty()))
	var dt := delta
	var phantom := _phantom()
	if working and phantom:
		var before := _swing
		_swing += delta / maxf(phantom.phantom_swing_time, 0.05)
		dt = 0.0
		# The hit lands when the swing passes its impact point.
		if before < phantom.phantom_impact and _swing >= phantom.phantom_impact:
			dt = phantom.phantom_swing_time
			EventBus.sound_requested.emit(&"phantom_chop" if mode == Mode.CHOP else &"phantom_mine",
				Vector2(rect.position * TILE) + Vector2(rect.size * TILE) * 0.5)
		if _swing >= 1.0:
			_swing -= 1.0  # the next swing conjures it again
	elif not working:
		_swing = 0.0
	if working and dt > 0.0 and mode == Mode.CHOP:
		world.plants.request_hit_tree(tree, chop_damage() * dt, p.global_position.x)
	if working and dt > 0.0 and mode == Mode.MINE:
		for t in valid:
			if back:
				world.request_damage_wall(t, damage() * dt)
			else:
				world.request_damage_block(t, damage() * dt)
		if not back:
			world.plants.request_cut_flowers(rect)
	_update_phantom(p, working and phantom != null)
	queue_redraw()


## Whether the target box is the phantom tool's glowing one (gathering spells).
func _glow_box() -> bool:
	return _phantom() != null and mode in [Mode.MINE, Mode.CHOP] and not world.player.stowed


## How far through its swing the phantom tool is (0 to 1), and the node that draws it.
var _swing := 0.0
var _phantom_node: PhantomTool


## The gathering spell in use when it shows a phantom tool, else null.
func _phantom() -> SpellData:
	var sp := _item as SpellData
	return sp if sp and sp.phantom_texture else null


## Mining damage of the item in use, with spell strength from the book and conduit.
func damage() -> float:
	if _item == null:
		return 0.0
	return _item.mining_damage * (_spell_power() if _item.is_spell() else 1.0) * (1.0 + world.player.stat(&"mining_speed"))


## Chopping damage of the item in use (spells: with book and conduit strength).
func chop_damage() -> float:
	if _item == null:
		return 0.0
	return _item.axe_damage * (_spell_power() if _item.is_spell() else 1.0)


## Where Tele Grab's portal opens: the cursor, pulled in to the spell's reach.
func grab_point() -> Vector2:
	var p := world.player
	var at := cursor()
	var from := p.chest()
	return from + (at - from).limit_length(reach())


func reach() -> float:
	if _item == null:
		return 0.0
	if infinite_reach:
		return 100000.0
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
		and (item.places_block != &"" or item.places_wall != &"" or item.places_object != &"" or item.plants != &"")


## Spell strength: book and conduit (or tome), magic damage, and the spell's school
## (gear and a school weapon in hand). `spell` defaults to the item in use.
func _spell_power(spell: ItemData = null) -> float:
	var p := world.player
	if p.character == null:
		return 1.0
	var s := spell if spell else _item
	var tome := p.held_item if p.held_item and p.held_item.tome_spell != &"" else null
	return p.character.spell_power(tome) * (1.0 + p.stat(&"magic_damage")) * p.school_mult(s.school if s else 0)


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
		var sp := _item as SpellData
		var turning_off := sp.cast == SpellData.Cast.TOGGLE and p.concentration == sp
		var need := p.mana_cost_of(sp) * (sp.charge_min_mana if sp.cast == SpellData.Cast.CHARGED else 1.0)
		if problem == "" and not turning_off and not p.has_mana(maxf(need, minf(sp.mana_per_second * 0.1, 1.0))):
			problem = "Not enough mana"
		if p.is_free_spell(sp):
			problem = ""  # from a scroll: no book or mana needed
	var size := area_size(_item)
	var c := at / TILE
	rect = Rect2i(Vector2i(floori(c.x - size / 2.0 + 0.5), floori(c.y - size / 2.0 + 0.5)), Vector2i(size, size))
	match mode:
		Mode.MINE:
			if problem != "":
				return
			var types := world.walls if back else world.blocks
			var too_hard := false
			for t in _tiles():
				var id := world.data.get_wall(t.x, t.y) if back else world.data.get_block(t.x, t.y)
				var def := types.def(id) if id > 0 else null
				if def and def.min_mining_power > _item.mining_power:
					too_hard = true
					continue
				var obj := not back and world.data.get_object(t.x, t.y) > 0 and not world.is_solid(t)
				if (obj or (def and not def.unbreakable and def.health > 0.0 and t.y < world.data.height - 1
						and (back or not world.is_protected(t)))) and _in_reach(t):
					valid.append(t)
			if too_hard and valid.is_empty():
				problem = "Too hard: needs a stronger pickaxe"
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
		Mode.PLACE_OBJECT:
			var def := world.objects.def(world.objects.index_of(_item.places_object)) as ObjectDef
			if def and def.style == ObjectDef.Style.FURNITURE:
				# Furniture: the cursor is on its bottom row, centered.
				var anchor := Vector2i(floori(c.x) - (def.width_tiles - 1) / 2, floori(c.y))
				rect = Rect2i(anchor + Vector2i(0, -def.height_tiles + 1), Vector2i(def.width_tiles, def.height_tiles))
				var body := world.player.body_rect()
				var blocked := def.blocks_movement and body.intersects(Rect2(Vector2(rect.position * TILE), Vector2(rect.size * TILE)))
				if _in_reach(anchor) and world.can_place_object(anchor, def) and not blocked:
					valid.append(anchor)
			else:
				for t in _tiles():
					if _in_reach(t) and world.can_place_object(t, def) and not world.plants.blocks_placement(t):
						valid.append(t)
			_limit_to_stack()
		Mode.CAST, Mode.TOGGLE:
			rect = Rect2i(Vector2i(floori(c.x), floori(c.y)), Vector2i.ONE)
		Mode.GRAB:
			rect = Rect2i(Vector2i(floori(c.x), floori(c.y)), Vector2i.ONE)
			if problem == "" and (_item as SpellData).needs_sight \
					and not world.line_clear(p.chest(), grab_point().move_toward(p.chest(), World.TILE)):
				problem = "Out of sight"
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
			for t in _tiles():
				var b := world.data.get_block(t.x, t.y)
				if world.blocks.is_dirt(b) and world.blocks.grass_of(b) > 0 and _exposed(t) and _in_reach(t):
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
		Mode.PLACE_BLOCK, Mode.PLACE_WALL, Mode.PLACE_OBJECT, Mode.PLANT_TREE, Mode.PLANT_GRASS:
			return not valid.is_empty()
		Mode.TOGGLE:
			# One toggle per click (holding the button doesn't flip it back and forth).
			if on_back or not Input.is_action_just_pressed("use_primary"):
				return false
			world.player.toggle_concentration(_item as SpellData)
			return true
		Mode.CAST:
			if on_back:
				return false
			return cooldown_left(_item as SpellData) <= 0.0
		Mode.GRAB:
			return not on_back
		Mode.EAT:
			var pressed := Input.is_action_just_pressed("use_secondary" if on_back else "use_primary")
			if pressed and _eat_frame != Engine.get_process_frames():
				_eat_frame = Engine.get_process_frames()  # asked twice in one click: eat once
				eat_held()
			return false  # no swing
		Mode.PAGE:
			if not on_back and Input.is_action_just_pressed("use_primary"):
				read_page()
			return false
		Mode.SCROLL:
			if not on_back and Input.is_action_just_pressed("use_primary"):
				cast_scroll()
			return false
		Mode.THROW:
			if not on_back and Input.is_action_just_pressed("use_primary"):
				throw_held()
			return false
		Mode.CHARGE:
			return false  # charged in _update_charge, no swing
		Mode.NONE:
			# Empty hands punch and weapons swing; materials, books and the like have no
			# use, so the arm just keeps holding them.
			var held := world.player.held_item
			return not on_back and (held == null or world.player.stowed
				or held.kind in [ItemData.Kind.WEAPON, ItemData.Kind.TOOL])
	return true


## The area a melee attack hits. A swing (swords) sweeps an arc in front, toward the
## cursor, from above your head to below your feet (like Terraria's), so it reaches an
## enemy downhill. An aimed attack (punches) hits in front of you (head to knees) and
## along a line toward the cursor, so aiming down reaches a slime on a slope below.
func melee_rect(item: ItemData) -> Rect2:
	var p := world.player
	var chest := p.chest()
	var side := signf(cursor().x - chest.x)
	if side == 0.0:
		side = float(p.facing)
	var reach_px := item.melee_reach * World.TILE
	if item.melee_aims:
		var a := (cursor() - chest).angle() if side > 0.0 else PI - (cursor() - chest).angle()
		a = clampf(wrapf(a, -PI, PI), -deg_to_rad(aimed_hit_limit_degrees), deg_to_rad(aimed_hit_limit_degrees))
		var end := chest + Vector2(cos(a) * side, sin(a)) * reach_px
		var line := Rect2(chest, Vector2.ZERO).expand(end).grow(aimed_hit_width_tiles * 0.5 * World.TILE)
		var front_x := chest.x if side > 0.0 else chest.x - reach_px
		return line.merge(Rect2(front_x, chest.y - 5.0 * World.TILE, reach_px, 9.0 * World.TILE))
	var feet_y := p.global_position.y
	var top := chest.y - swing_above_chest_tiles * World.TILE
	var x := chest.x if side > 0.0 else chest.x - reach_px
	var below := swing_below_feet_tiles if p.is_on_floor() else swing_below_feet_airborne_tiles
	return Rect2(x, top, reach_px, feet_y + below * World.TILE - top)


## A school weapon's hit leaves its school's mark (Storm: shocked, a few ticks of damage).
func _leave_mark(node: Node, item: ItemData) -> void:
	if item.school != ItemData.School.NONE and item.mark_seconds > 0.0 and node.has_method(&"mark"):
		node.call(&"mark", item.school, item.mark_damage * (1.0 + world.player.stat(&"melee_damage")), item.mark_seconds)


## A weapon skill's slam (LEAP_SLAM, when you land): hits everything within
## `skill_radius_tiles` of where you landed, knocks it away and leaves the weapon's
## mark. Returns how many were hit.
func slam(item: ItemData, at: Vector2) -> int:
	var p := world.player
	var radius := item.skill_radius_tiles * TILE
	var amount := item.skill_damage * (1.0 + p.stat(&"melee_damage"))
	var hit := 0
	for node in get_tree().get_nodes_in_group(&"damageable"):
		if node == p or not is_instance_valid(node):
			continue
		var r: Rect2 = node.call(&"hit_rect")
		var c := r.get_center()
		if c.distance_to(at + Vector2(0, -TILE)) > radius + r.size.length() * 0.5:
			continue
		if not world.line_clear(at + Vector2(0, -TILE), c):
			continue
		node.call(&"take_damage", amount, p)
		if node.has_method(&"knock_back"):
			node.call(&"knock_back", at, item.knockback * 1.5, true)
		_leave_mark(node, item)
		hit += 1
	var color := Schools.color(item.school) if item.school != ItemData.School.NONE else Color(1, 0.95, 0.8)
	var ring := SpellEffect.spawn(world.effects, SpellEffect.Kind.BURST, at + Vector2(0, -2), Vector2.ZERO, color)
	if ring:
		ring.scale = Vector2.ONE * maxf(item.skill_radius_tiles / 2.0, 1.0)
	EventBus.sound_requested.emit(&"slam", at)
	return hit


## Hits everything damageable in the swing (once each). Returns how many were hit.
func melee_hit(item: ItemData) -> int:
	var p := world.player
	var area := melee_rect(item)
	var amount := item.melee_damage * (1.0 + p.stat(&"melee_damage"))
	if p.has_buff(&"arcane_edge"):
		amount *= p.buff_spells[&"arcane_edge"].melee_mult
	var hit := 0
	for node in get_tree().get_nodes_in_group(&"damageable"):
		if node == p or not is_instance_valid(node):
			continue
		var r: Rect2 = node.call(&"hit_rect")
		if not area.intersects(r) or not _reachable(p.chest(), r):
			continue
		node.call(&"take_damage", amount, p)
		if node.has_method(&"knock_back"):
			node.call(&"knock_back", p.chest(), item.knockback, item.staggers)
		_leave_mark(node, item)
		var held_meta := p.held_meta()
		var coat := Coating.use(held_meta) if item == p.held_item else null
		if coat and p.character:
			p.character.inventory.changed.emit()  # the hits left changed
		if coat and node.has_method(&"poison"):
			node.call(&"poison", coat.poison_dps, coat.poison_seconds)
		hit += 1
	return hit


## Whether a melee hit from `from` reaches a target: a clear line to its center or to
## its nearest point (walls and closed doors stop hits, so no hitting through them).
func _reachable(from: Vector2, r: Rect2) -> bool:
	r = r.grow(-minf(2.0, minf(r.size.x, r.size.y) * 0.25))  # its edges touch the ground
	var near := Vector2(clampf(from.x, r.position.x, r.end.x), clampf(from.y, r.position.y, r.end.y))
	for to: Vector2 in [r.get_center(), near, Vector2(near.x, r.get_center().y)]:
		if world.line_clear(from, to):
			return true
	return false


## Holding something that can go on a table or shelf over a free display spot (in
## reach): a faint picture of it there; right click puts it down.
func _draw_display_ghost() -> void:
	var p := world.player
	var item := p.held_item
	if item == null or p.stowed or not item.can_display() or item.is_spell() or p.held_count() <= 0:
		return
	var aim := cursor()
	if aim.distance_to(p.chest()) > (world.interact_tiles + 2.0) * World.TILE:
		return
	var tile := world.world_to_tile(aim)
	if not world.can_display_at(tile, item):
		return
	var r := world.display_rect(tile, item)
	if item.icon:
		draw_texture_rect(item.icon, r, false, Color(1, 1, 1, 0.55))
	draw_rect(r.grow(1.0), Color(1, 1, 1, 0.35), false, 1.0)


## Learns the held Spell Page's spell for good (the page is used up). A spell you
## already know keeps the page. Returns true if learned.
func read_page() -> bool:
	var p := world.player
	var item := p.held_item
	if item == null or item.learns_spell == &"" or p.character == null:
		return false
	var spell := ItemData.find(ItemData.spell_key(item.learns_spell)) as SpellData
	if spell == null:
		return false
	if p.character.knows(spell.id):
		EventBus.debug_message.emit("You already know %s" % spell.display_name)
		return false
	if spell.page_needs_table:
		EventBus.debug_message.emit("Too much for one page: learn %s at a Spell Weaving Table" % spell.display_name)
		return false
	if not p.take_held():
		return false
	p.character.learn_spell(spell.id)
	var note := "" if spell.tier <= p.character.max_spell_tier() else " (needs a tier %d book to cast)" % spell.tier
	EventBus.debug_message.emit("Learned %s%s" % [spell.display_name, note])
	EventBus.sound_requested.emit(&"learn_spell", p.chest())
	return true


## Casts the held scroll's spell once, free: no mana, reagents, cooldown, book or tier.
## Concentration spells and held beams run free for a while (a buff shows the time
## left); a charged bolt fires at full charge; a ritual still needs you to stand still.
## The scroll is used up only if the spell went off. Returns true if it did.
func cast_scroll() -> bool:
	var p := world.player
	var item := p.held_item
	if item == null or item.teaches_spell == &"" or p.held_count() <= 0 or p.character == null:
		return false
	var spell := ItemData.find(ItemData.spell_key(item.teaches_spell)) as SpellData
	if spell == null:
		return false
	if cooldown_left(spell) > 0.0:
		return false  # shares the spell's cooldown with casting it from the book
	var ok := true
	match spell.cast:
		SpellData.Cast.TOGGLE:
			var secs := item.scroll_seconds if item.scroll_seconds > 0.0 else p.scroll_concentration_seconds
			p.start_scroll_spell(spell, secs)
		SpellData.Cast.TOOL:
			var secs := item.scroll_seconds if item.scroll_seconds > 0.0 else p.scroll_beam_seconds
			p.take_held()
			p.start_scroll_spell(spell, secs)
			EventBus.debug_message.emit("%s: free for %d seconds" % [spell.display_name, roundi(secs)])
			return true
		SpellData.Cast.CHARGED:
			var from := p.casting_hand_position()
			var bolt := world.request_spawn_projectile(spell, from, (cursor() - from).normalized(), _spell_power(spell), p)
			ok = bolt != null
			if bolt:
				bolt.size = 1.8
				EventBus.sound_requested.emit(&"bolt_fire", from)
		SpellData.Cast.RITUAL:
			ok = p.start_ritual(spell, true)
		_:
			ok = cast(spell)
	if ok:
		p.take_held()
		_ready_at[spell.id] = _now() + spell.cooldown
	return ok


## Eats or drinks one of the held food or potion (hunger, health, mana, a buff).
## Returns true if it was used up.
func eat_held() -> bool:
	var p := world.player
	if p.mouse_stack:
		var item := p.mouse_stack
		if item.kind != ItemData.Kind.FOOD:
			return false
		var why := p.cant_consume(item)
		if why != "":
			EventBus.debug_message.emit(why)
			return false
		if not p.take_held():
			return false
		p.consume(item)
		EventBus.sound_requested.emit(&"eat", p.chest())
		return true
	return eat_from(p.held_slot())


## Eats or drinks one from an inventory slot (held, or a Z X C shortcut).
func eat_from(slot: int) -> bool:
	var p := world.player
	var item := p.character.inventory.item(slot) if slot >= 0 else null
	if item == null or item.kind != ItemData.Kind.FOOD:
		return false
	var why := p.cant_consume(item)
	if why != "":
		EventBus.debug_message.emit(why)
		return false
	var inv := p.character.inventory
	if not world.infinite_items and inv.take(slot, 1) <= 0:
		return false
	p.refresh_held()
	p.consume(item)
	var drink := item.mana_value > 0.0 or item.sickness != &"" or item.food_value <= 0.0
	EventBus.debug_message.emit("%s %s" % ["Drank" if drink else "Ate", item.display_name])
	EventBus.sound_requested.emit(&"eat", world.player.chest())
	return true


## Throws one of the held throwable (the Poison Flask) toward the cursor. Returns true
## if thrown.
func throw_held() -> bool:
	var p := world.player
	var item := p.held_item
	if item == null or item.throw_speed <= 0.0 or p.held_count() <= 0 or not Game.is_authority():
		return false
	if not p.take_held():
		return false
	var from := p.chest() + Vector2(p.facing * 6.0, -4.0)
	var dir := (cursor() - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(p.facing, 0)
	var t := ThrownItem.new()
	world.add_child(t)
	t.launch(world, item, from, dir * item.throw_speed * TILE + Vector2(0, -2.0 * TILE))
	EventBus.sound_requested.emit(&"swing", from)
	return true


func area_size(item: ItemData) -> int:
	if item == null:
		return 1
	var lo := 1
	var hi := 1
	var start := 1
	if item.mining_damage > 0.0:
		# Starts at mining_area; the area toggle goes down to 1x1 and up to
		# mining_area_max (if bigger).
		hi = maxi(item.mining_area_max, item.mining_area)
		lo = 1
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
	if item is SpellData:
		match (item as SpellData).cast:
			SpellData.Cast.CHARGED:
				return Mode.CHARGE
			SpellData.Cast.PROJECTILE, SpellData.Cast.GUST, SpellData.Cast.BLINK, SpellData.Cast.LIGHT, \
					SpellData.Cast.BUFF, SpellData.Cast.ZONE, SpellData.Cast.WARD, SpellData.Cast.SUMMON, \
					SpellData.Cast.CONJURE, SpellData.Cast.CHAIN, SpellData.Cast.RITUAL, SpellData.Cast.SENSE:
				return Mode.CAST
			SpellData.Cast.TOGGLE:
				return Mode.TOGGLE
			SpellData.Cast.GRAB:
				return Mode.GRAB
	if item.mining_damage > 0.0:
		return Mode.MINE
	if item.kind == ItemData.Kind.FOOD:
		return Mode.EAT if not on_back else Mode.NONE  # left click
	if item.throw_speed > 0.0:
		return Mode.THROW if not on_back else Mode.NONE
	if item.teaches_spell != &"":
		return Mode.NONE if on_back else Mode.SCROLL
	if item.learns_spell != &"":
		return Mode.NONE if on_back else Mode.PAGE
	if on_back:
		return Mode.PLACE_WALL if item.places_wall != &"" else Mode.NONE
	if item.axe_damage > 0.0:
		return Mode.CHOP
	if item.places_block != &"":
		return Mode.PLACE_BLOCK
	if item.places_object != &"":
		return Mode.PLACE_OBJECT
	if item.plants in [&"tree", &"darkwood"]:
		return Mode.PLANT_TREE
	if item.plants == &"grass":
		return Mode.PLANT_GRASS
	return Mode.NONE


func _tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var round_area := _item != null and _item.mining_round and mode == Mode.MINE
	var center := Vector2(rect.position) + Vector2(rect.size) * 0.5
	var radius := rect.size.x * 0.5
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if round_area and (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(center) > radius:
				continue
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
				and not body.intersects(Rect2(Vector2(t * TILE), Vector2(TILE, TILE))) \
				and not _furniture_at(t):
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
	if walls and _anchors(t):
		return true  # behind a door
	if not walls and world.data.get_wall(t.x, t.y) > 0:
		return true
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var b := world.data.get_block(t.x + d.x, t.y + d.y)
		if b > 0 or b == WorldData.OUT_OF_BOUNDS:
			return true
		if walls and world.data.get_wall(t.x + d.x, t.y + d.y) > 0:
			return true
		if _anchors(t + d):
			return true  # next to or on top of a door
	return false


## True if the object at a tile is something to build against (a door).
func _anchors(t: Vector2i) -> bool:
	var def := world.object_def_at(t)
	return def != null and def.anchors_building


func _furniture_at(t: Vector2i) -> bool:
	var def := world.object_def_at(t)
	return def != null and def.style == ObjectDef.Style.FURNITURE


## Can't place more than the selected stack holds.
func _limit_to_stack() -> void:
	var p := world.player
	var have := p.held_count()
	if valid.size() > have:
		valid.resize(have)


func _on_impact(item: ItemData) -> void:
	var p := world.player
	update_target(cursor(), p.use_back)
	var inv := p.character.inventory
	if item.melee_damage > 0.0:
		EventBus.sound_requested.emit(&"swing", p.chest())
		melee_hit(item)
	match mode:
		Mode.MINE:
			if not item.beam:
				for t in valid:
					if back:
						world.request_damage_wall(t, damage())
					else:
						world.request_damage_block(t, damage())
		Mode.CHOP:
			if tree != PlantLayer.NONE and not item.beam:
				world.plants.request_hit_tree(tree, chop_damage(), p.global_position.x)
		Mode.PLACE_OBJECT:
			var id := world.objects.index_of(item.places_object)
			for t in valid:
				if p.held_count() > 0 and world.request_place_object(t, id, p.facing < 0):
					p.take_held()
		Mode.CAST:
			var spell := item as SpellData
			# Mana is checked before the reagents are used up, so a failed cast costs nothing.
			# A ritual pays when it completes.
			var pays := spell.cast != SpellData.Cast.RITUAL
			var cost := p.mana_cost_of(spell)
			if cooldown_left(spell) <= 0.0 and p.has_mana(cost) and p.character.take_reagents(spell):
				if pays:
					p.spend_mana(cost)
					_ready_at[spell.id] = _now() + spell.cooldown  # a ritual's starts when it completes
				if not cast(spell) and pays:
					p.mana += cost  # it fizzled (no room, no target): refund
					_ready_at.erase(spell.id)
		Mode.PLACE_BLOCK:
			var id := world.blocks.index_of(item.places_block)
			for t in valid:
				if p.held_count() > 0 and world.request_set_block(t, id):
					p.take_held()
		Mode.PLACE_WALL:
			var id := world.walls.index_of(item.places_wall)
			for t in valid:
				if p.held_count() > 0 and world.request_set_wall(t, id):
					p.take_held()
		Mode.PLANT_TREE:
			for g in valid:
				var kind := PlantLayer.SAPLING_DARKWOOD if item.plants == &"darkwood" else PlantLayer.SAPLING_PINE
				if p.held_count() > 0 and world.plants.request_plant_tree(g, kind):
					p.take_held()
		Mode.PLANT_GRASS:
			for t in valid:
				var grass := world.blocks.grass_of(world.data.get_block(t.x, t.y))  # dirt's own grass
				if p.held_count() > 0 and grass > 0 and world.request_set_block(t, grass):
					p.take_held()
	if not back and (item.kind == ItemData.Kind.TOOL or item.kind == ItemData.Kind.WEAPON):
		_cut_flowers_in_swing()


## Casts a spell straight away, without the casting animation (the buff set, B): the
## same checks and costs as a normal cast. Returns "" if it went off, else why not.
func cast_direct(spell: SpellData) -> String:
	var p := world.player
	var why := p.character.cast_problem(spell)
	if why != "":
		return why
	if cooldown_left(spell) > 0.0:
		return "Not ready yet"
	var cost := p.mana_cost_of(spell)
	if not p.has_mana(cost):
		return "Not enough mana"
	if not p.character.take_reagents(spell):
		return "Missing reagents"
	p.spend_mana(cost)
	_ready_at[spell.id] = _now() + spell.cooldown
	if not cast(spell):
		p.mana += cost
		_ready_at.erase(spell.id)
		return "It fizzles"
	return ""


## Starts a spell's cooldown now (a ritual, when it completes: cancelling one by moving
## leaves no cooldown).
func start_cooldown(spell: SpellData) -> void:
	_ready_at[spell.id] = _now() + spell.cooldown


## Casts a non-toggle spell now (mana and cooldown already handled). False if it
## fizzled (no room, no target), with the reason shown.
func cast(spell: SpellData) -> bool:
	var p := world.player
	var from := p.casting_hand_position()
	EventBus.sound_requested.emit(StringName("cast_" + SpellData.Cast.keys()[spell.cast].to_lower()), from)
	match spell.cast:
		SpellData.Cast.PROJECTILE:
			world.request_spawn_projectile(spell, from, (cursor() - from).normalized(), _spell_power(spell), p)
		SpellData.Cast.GUST:
			gust(spell, from, (cursor() - from).normalized())
		SpellData.Cast.BLINK:
			var start := p.chest()
			if p.blink_toward(cursor(), spell.blink_tiles):
				SpellEffect.spawn(world.effects, SpellEffect.Kind.BURST, start, Vector2.ZERO, spell.projectile_color)
				SpellEffect.spawn(world.effects, SpellEffect.Kind.BURST, p.chest(), Vector2.ZERO, spell.projectile_color)
			else:
				EventBus.debug_message.emit("No room to blink there")
		SpellData.Cast.LIGHT:
			world.summon_light_orb(spell)
		SpellData.Cast.BUFF:
			p.add_buff(spell)
			SpellEffect.spawn(world.effects, SpellEffect.Kind.BURST, p.chest(), Vector2.ZERO, spell.projectile_color)
		SpellData.Cast.ZONE, SpellData.Cast.WARD, SpellData.Cast.SUMMON, SpellData.Cast.CONJURE, SpellData.Cast.SENSE:
			# Made at the cursor: it has to be in sight (no casting through walls), unless
			# the spell says otherwise (`needs_sight`, for a later upgrade).
			if spell.needs_sight and spell.cast != SpellData.Cast.SENSE \
					and not world.line_clear(p.chest(), cursor().move_toward(p.chest(), World.TILE)):
				EventBus.debug_message.emit("Out of sight")
				return false
			if world.request_spell_effect(spell, cursor(), _spell_power(spell)) == null:
				EventBus.debug_message.emit(world.spell_problem if world.spell_problem != "" else "It fizzles")
				return false
		SpellData.Cast.CHAIN:
			chain(spell, from)  # a miss is still a cast: the bolt flies and fizzles
		SpellData.Cast.RITUAL:
			return p.start_ritual(spell)
	return true


## Seconds a CHARGED spell has been charging (-1 = not charging).
var charge := -1.0


## Arcane Bolt: press and hold to charge, let go to fire. The bolt's damage, size and
## mana grow with the charge. Holding past a full charge keeps it full.
func _update_charge(delta: float) -> void:
	var p := world.player
	if mode != Mode.CHARGE or p == null or p.dead or p.stowed:
		charge = -1.0
		return
	var spell := _item as SpellData
	if Input.is_action_pressed("use_primary") and not p.input_blocked:
		if charge < 0.0:
			if not Input.is_action_just_pressed("use_primary") or problem != "" or cooldown_left(spell) > 0.0:
				return
			charge = 0.0
			EventBus.sound_requested.emit(&"bolt_charge", p.casting_hand_position())
		charge = minf(charge + delta, spell.charge_seconds)
		queue_redraw()
	elif charge >= 0.0:
		release_charge()


## Fires a charging bolt now. Returns the bolt, or null (not enough mana: it fizzles).
func release_charge() -> SpellProjectile:
	var p := world.player
	var spell := _item as SpellData
	var k := clampf(charge / maxf(spell.charge_seconds, 0.01), 0.0, 1.0)
	charge = -1.0
	queue_redraw()
	if spell == null:
		return null
	var cost := p.mana_cost_of(spell) * lerpf(spell.charge_min_mana, 1.0, k)
	if not p.spend_mana(cost):
		EventBus.debug_message.emit("Not enough mana")
		return null
	_ready_at[spell.id] = _now() + spell.cooldown
	var from := p.casting_hand_position()
	var bolt := world.request_spawn_projectile(spell, from, (cursor() - from).normalized(),
		_spell_power(spell) * lerpf(spell.charge_min_damage, 1.0, k), p)
	if bolt:
		bolt.size = lerpf(0.6, 1.8, k)
	EventBus.sound_requested.emit(&"bolt_fire", from)
	return bolt


## Chain Spark: a bolt shoots toward the cursor (out to `reach_tiles`); the first thing it
## touches is hit, then it jumps to the nearest
## one not yet hit within `chain_tiles`, up to `chain_jumps` times, each `chain_falloff`
## weaker. Returns how many were hit.
func chain(spell: SpellData, from: Vector2) -> int:
	var p := world.player
	var targets: Array[Node] = []
	for n in get_tree().get_nodes_in_group(&"damageable"):
		if n != p and is_instance_valid(n) and not n.is_queued_for_deletion():
			targets.append(n)
	# The bolt shoots toward the cursor, out to its reach: the first thing it touches is
	# hit (then it jumps); a block stops it; nothing = it fizzles at the end.
	var reach := spell.reach_tiles * TILE
	var dir := (cursor() - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(p.facing, 0)
	var first: Node = null
	var end := from + dir * reach
	var step := 2.0
	var travelled := 0.0
	while travelled <= reach and first == null:
		var pt := from + dir * travelled
		if world.blocks_hits(world.world_to_tile(pt)):  # blocks and closed doors stop it
			end = pt
			break
		for n in targets:
			if (n.call(&"hit_rect") as Rect2).grow(2.0).has_point(pt):
				first = n
				break
		travelled += step
	if first == null:
		var miss := SpellEffect.spawn(world.effects, SpellEffect.Kind.ZAP, Vector2.ZERO, Vector2.ZERO, spell.projectile_color)
		miss.points = PackedVector2Array([from, end])
		return 0
	var path := PackedVector2Array([from])
	var hit: Array[Node] = []
	var current := first
	var amount := spell.damage * _spell_power(spell)
	while current:
		var at: Vector2 = (current.call(&"hit_rect") as Rect2).get_center()
		path.append(at)
		hit.append(current)
		current.call(&"take_damage", amount * Schools.payoff(current, spell), p)
		if hit.size() > spell.chain_jumps:
			break
		amount *= 1.0 - spell.chain_falloff
		var next: Node = null
		var nd := spell.chain_tiles * TILE
		for n in targets:
			if n in hit or not is_instance_valid(n):
				continue
			var c := (n.call(&"hit_rect") as Rect2).get_center()
			var d := c.distance_to(at)
			if d <= nd and world.line_clear(at, c):  # it doesn't jump through walls
				nd = d
				next = n
		current = next
	var fx := SpellEffect.spawn(world.effects, SpellEffect.Kind.ZAP, Vector2.ZERO, Vector2.ZERO, spell.projectile_color)
	fx.points = path
	return hit.size()


## Air Push: everything damageable in the cone is hurt and shoved away; in the air the
## caster is pushed back a little. Returns how many were hit.
func gust(spell: SpellData, from: Vector2, dir: Vector2) -> int:
	var p := world.player
	var reach_px := spell.gust_tiles * TILE
	var hit := 0
	for node in get_tree().get_nodes_in_group(&"damageable"):
		if node == p or not is_instance_valid(node):
			continue
		var r: Rect2 = node.call(&"hit_rect")
		var to := r.get_center() - from
		var d := to.length()
		if d > reach_px + r.size.length() * 0.5:
			continue
		if d > 1.0 and rad_to_deg(absf(dir.angle_to(to))) > spell.gust_angle:
			continue
		if not world.line_clear(from, r.get_center()):
			continue  # walls and closed doors stop the gust
		if spell.damage > 0.0:
			node.call(&"take_damage", spell.damage * _spell_power(spell) * Schools.payoff(node, spell), p)
		if node.has_method(&"knock_back"):
			node.call(&"knock_back", from, spell.gust_push)
		hit += 1
	# The push back on you: full in the air; on the ground only a gust aimed down lifts
	# you (a gust jump).
	if spell.gust_recoil > 0.0:
		if not p.is_on_floor():
			p.velocity -= dir * spell.gust_recoil * TILE
		elif dir.y > 0.4:
			p.velocity.y = minf(p.velocity.y, -dir.y * spell.gust_recoil * TILE)
			p.velocity.x -= dir.x * spell.gust_recoil * TILE
	SpellEffect.spawn(world.effects, SpellEffect.Kind.GUST, from, dir * reach_px, spell.projectile_color,
		spell.gust_angle)
	return hit


## Seconds before a spell can be cast again.
func cooldown_left(spell: SpellData) -> float:
	if spell == null:
		return 0.0
	return maxf(_ready_at.get(spell.id, 0.0) - _now(), 0.0)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## A swing cuts flowers in front of the player.
func _cut_flowers_in_swing() -> void:
	var p := world.player
	var feet := Vector2i(floori(p.global_position.x / TILE), floori((p.global_position.y - 1.0) / TILE))
	var x0 := feet.x if p.facing > 0 else feet.x - swing_cut_tiles
	world.plants.request_cut_flowers(Rect2i(Vector2i(x0, feet.y - 4), Vector2i(swing_cut_tiles + 1, 5)))


# --- drawing -------------------------------------------------------------------------

func _draw() -> void:
	_draw_display_ghost()
	if mode == Mode.NONE or world.player.input_blocked:
		return
	var p := world.player
	var aim := cursor()
	if mode == Mode.GRAB:
		var sp := _item as SpellData
		var on := p.is_using() and problem == ""
		var gp := grab_point()
		if on:
			_draw_portal(gp, 7.0, sp.projectile_color, 1.0)
			_draw_portal(p.casting_hand_position(), 3.5, sp.projectile_color, 0.9)
			draw_arc(gp, sp.grab_tiles * TILE, 0.0, TAU, 40, Color(sp.projectile_color, 0.18), 1.0)
		else:
			_draw_portal(gp, 6.0, Color(0.9, 0.3, 0.3) if problem != "" else sp.projectile_color, 0.35)
		return
	if mode == Mode.CHARGE and charge >= 0.0:
		# The bolt growing in the casting hand, with a ring that closes when it's full.
		var spell := _item as SpellData
		var k := clampf(charge / maxf(spell.charge_seconds, 0.01), 0.0, 1.0)
		var at := p.casting_hand_position()
		draw_circle(at, lerpf(1.5, 5.0, k), Color(spell.projectile_color, 0.5))
		draw_circle(at, lerpf(0.8, 2.2, k), Color(1, 1, 1, 0.9))
		draw_arc(at, lerpf(12.0, 6.0, k), 0.0, TAU * k, 24, Color(spell.projectile_color, 0.8), 1.0)
	if mode in [Mode.SCROLL, Mode.PAGE] and p.held_item:
		# Holding a scroll or a page: what a click does.
		var font := ThemeDB.fallback_font
		var hint := "Left: cast once (free)" if mode == Mode.SCROLL else "Left: learn this spell"
		draw_string_outline(font, aim + Vector2(8, 4), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, 2, Color(0, 0, 0, 0.7))
		draw_string(font, aim + Vector2(8, 4), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, valid_color)
	if mode in [Mode.CAST, Mode.TOGGLE, Mode.CHARGE]:
		# No target box: just say why it can't be cast, if it can't.
		if problem != "":
			draw_string(ThemeDB.fallback_font, aim + Vector2(6, -4), problem, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, invalid_color)
		return
	var reach_px := reach()
	var ok := not valid.is_empty() or (mode == Mode.CHOP and tree != PlantLayer.NONE)
	var color := (back_color if back else valid_color) if ok else invalid_color
	# Range ring: fades in near the edge of reach (and stays when past it).
	var d := aim.distance_to(p.chest())
	var k := clampf((d - ring_fade_start * reach_px) / maxf((1.0 - ring_fade_start) * reach_px, 1.0), 0.0, 1.0)
	if k > 0.0 and not infinite_reach:
		var ring := valid_color if d <= reach_px else invalid_color
		ring.a = ring_alpha * k
		draw_arc(p.chest(), reach_px, 0.0, TAU, 128, ring, 1.0)
	# Ghost blocks where blocks or walls will go.
	if mode in [Mode.PLACE_BLOCK, Mode.PLACE_WALL, Mode.PLACE_OBJECT, Mode.PLANT_GRASS] and _item.icon:
		var ghost_tex := _item.icon
		if mode == Mode.PLANT_GRASS:
			ghost_tex = (ItemData.find(&"dirt").icon if ItemData.find(&"dirt") else null)
		var furn := world.objects.def(world.objects.index_of(_item.places_object)) as ObjectDef \
			if mode == Mode.PLACE_OBJECT else null
		if furn and furn.style == ObjectDef.Style.FURNITURE and furn.frames:
			# Furniture ghost: the object itself over its footprint.
			var w := furn.width_tiles * TILE
			var h := furn.height_tiles * TILE
			var det := furn.detail
			var gr := Rect2(Vector2(rect.position * TILE), Vector2(w, h))
			var mirror := p.facing < 0 and World.can_flip(furn)
			if mirror:  # it'll face the way you do
				draw_set_transform(Vector2(gr.position.x * 2.0 + gr.size.x, 0), 0.0, Vector2(-1, 1))
			draw_texture_rect_region(furn.frames, gr,
				Rect2(furn.frame * w * det, 0, w * det, h * det), Color(1, 1, 1, ghost_alpha if not valid.is_empty() else 0.25))
			if mirror:
				draw_set_transform(Vector2.ZERO)
		for t in valid if not (furn and furn.style == ObjectDef.Style.FURNITURE) else []:
			var r := Rect2(Vector2(t * TILE), Vector2(TILE, TILE))
			if mode == Mode.PLANT_GRASS:
				draw_rect(r, Color(0.35, 0.75, 0.25, ghost_alpha))
			elif ghost_tex:
				var tint := Color(0.6, 0.6, 0.65, ghost_alpha) if back else Color(1, 1, 1, ghost_alpha)
				draw_texture_rect_region(ghost_tex, r, Rect2(2, 2, 12, 12), tint)
	# Beam from the hand to the target (gathering spells show the phantom tool instead).
	if _item.beam and p.is_using() and not _phantom_node.swinging:
		var from := p.casting_hand_position() if _item.is_spell() else p.doll_item_position()
		var to := Vector2(rect.position * TILE) + Vector2(rect.size * TILE) * 0.5
		if mode == Mode.CHOP and tree != PlantLayer.NONE:
			to = world.plants.ground_position(tree, p.global_position) + Vector2(0, -2.5 * TILE)
		var glow := beam_color if ok else invalid_color
		glow.a *= 0.3
		draw_line(from, to, glow, 3.0)
		var core := beam_color if ok else invalid_color
		core.a *= 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.03)
		draw_line(from, to, core, 1.0)
	# Target box (a circle for a round area). Gathering spells: the glowing blue one.
	if _glow_box():
		pass
	elif _item.mining_round and mode == Mode.MINE:
		var box := Rect2(Vector2(rect.position * TILE), Vector2(rect.size * TILE))
		draw_arc(box.get_center(), box.size.x * 0.5, 0.0, TAU, 48, color, 1.0)
	else:
		draw_rect(Rect2(Vector2(rect.position * TILE), Vector2(rect.size * TILE)).grow(0.5), color, false, 1.0)
	if problem != "":
		var font := ThemeDB.fallback_font
		draw_string(font, aim + Vector2(6, -4), problem, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, invalid_color)
	if _area_shown > 0.0:
		var font := ThemeDB.fallback_font
		var label := "%dx%d" % [rect.size.x, rect.size.y]
		var c := Color(1, 1, 1, minf(_area_shown * 2.0, 1.0))
		draw_string(font, Vector2(rect.end * TILE) + Vector2(2, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, c)


func _update_phantom(p: Player, show: bool) -> void:
	var pt := _phantom_node
	var sp := _phantom()
	pt.box_shown = sp != null and _glow_box()
	pt.swinging = show
	pt.visible = pt.box_shown or show
	if not pt.visible:
		return
	pt.box = Rect2(Vector2(rect.position * TILE), Vector2(rect.size * TILE))
	pt.box_ok = problem == "" and (not valid.is_empty() or tree != PlantLayer.NONE)
	pt.target = pt.box.get_center()
	pt.texture = sp.phantom_texture
	pt.style = sp.phantom_style as PhantomTool.Style
	pt.impact = sp.phantom_impact
	pt.grip_at = sp.phantom_grip
	pt.tip_at = sp.phantom_tip
	pt.tint = Color(0.75, 0.9, 1.0)
	if not sp.phantom_tints.is_empty():
		pt.tint = sp.phantom_tints[clampi(sp.gather_rank, 0, sp.phantom_tints.size() - 1)]
	pt.side = 1.0 if p.global_position.x < pt.target.x else -1.0
	pt.swing = _swing
	pt.redraw()


## A swirling portal (Tele Grab): a dark middle, a glowing rim and a turning spark.
func _draw_portal(at: Vector2, radius: float, color: Color, alpha: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	draw_circle(at, radius, Color(0.06, 0.04, 0.12, 0.85 * alpha))
	for i in 3:
		var r := radius * (1.0 - i * 0.22)
		var start := t * (3.0 + i) * (1.0 if i % 2 == 0 else -1.0)
		draw_arc(at, r, start, start + PI * 1.3, 18, Color(color, (0.9 - i * 0.25) * alpha), 1.0)
	draw_circle(at + Vector2.from_angle(t * 5.0) * radius * 0.5, 0.8, Color(1, 1, 1, alpha))
