extends SceneTree
## Writes the default items (data/items), spells (data/spells), tile objects
## (data/objects: furniture) and recipes (data/recipes) from the tables below.
## --only takes a comma-separated list of ids.
##
##   godot --headless --path . --script res://tools/make_items.gd
##   godot --headless --path . --script res://tools/make_items.gd -- --force
##   godot --headless --path . --script res://tools/make_items.gd -- --only=copper_pickaxe --force
##
## Without --force, existing files are kept (your Inspector edits are safe). Art comes
## from tools/make_item_art.gd (assets/items/icons and assets/items/held).

const DIR := "res://data/items"
const SPELL_DIR := "res://data/spells"
const OBJECT_DIR := "res://data/objects"
const RECIPE_DIR := "res://data/recipes"

var _force := false


func _init() -> void:
	_force = OS.get_cmdline_user_args().has("--force")
	var written := 0
	var all: Array = []
	for item in _items():
		all.append([item, DIR])
	for spell in _spells():
		all.append([spell, SPELL_DIR])
	for obj in _objects():
		all.append([obj, OBJECT_DIR])
	for recipe in _recipes():
		all.append([recipe, RECIPE_DIR])
	for e: Array in all:
		var res: GameData = e[0]
		var dir: String = e[1]
		if not _selected(res.id):
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var path := "%s/%s.tres" % [dir, res.id]
		if FileAccess.file_exists(path) and not _force:
			print("make_items: %s exists, kept (use --force to overwrite)" % path)
			continue
		ResourceSaver.save(res, path)
		written += 1
		print("make_items: wrote %s" % path)
	print("make_items: %d written" % written)
	quit()


func _selected(res_id: StringName) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			return String(res_id) in a.trim_prefix("--only=").split(",")
	return true


func _items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	# Blocks.
	# Right click places a block as the back layer (places_wall), when it has one.
	out.append(_block(&"dirt", "Dirt", "Soft ground. Grass spreads onto it.", &"dirt_wall"))
	out.append(_block(&"stone", "Stone", "Hard rock.", &"stone_wall"))
	out.append(_block(&"copper_ore", "Copper Ore", "Smelts into copper (crafting comes later)."))
	out.append(_block(&"wood_planks", "Wood Planks", "A building block. Right click places it as a back wall.", &"wood_wall"))
	# Platforms and rope go one at a time (line placing may come later).
	var platform := _block(&"wood_platform", "Wood Platform", "Stand on it; jump up through it, Down + Jump drops through.")
	platform.place_area_max = 1
	out.append(platform)
	# Tile objects (their own layer: they can share a tile with a platform or a wall).
	var rope := _block(&"rope", "Rope", "Climb with Up and Down. Can hang through platforms.")
	rope.places_block = &""
	rope.places_object = &"rope"
	rope.place_area_max = 1
	out.append(rope)
	var torch := _small(&"torch", "Torch", "Light. Goes on a block (below or beside) or a back wall.")
	torch.kind = ItemData.Kind.BLOCK
	torch.places_object = &"torch"
	torch.place_area_max = 1
	torch.held.grip = Vector2(3, 6)
	out.append(torch)
	# Materials and seeds.
	var wood := _small(&"wood", "Wood", "From trees. Craft into planks or torches.")
	out.append(wood)
	out.append(_small(&"stick", "Stick", "Lies on the grass; trees drop some too. For tools and torches."))
	out.append(_small(&"rock", "Rock", "Lies on the grass. A Workbench breaks stone into rocks."))
	out.append(_small(&"flint", "Flint", "A sharp stone for the first tools. Found on the grass, sometimes in stone."))
	out.append(_small(&"copper_bar", "Copper Bar", "Smelted from copper ore in a Furnace."))
	var berries := _small(&"berries", "Berries", "Picked from berry bushes. Left click to eat: +10 hunger, +2 health.")
	berries.kind = ItemData.Kind.FOOD
	berries.food_value = 10.0
	berries.heal_value = 2.0
	out.append(berries)
	var hammer := _small(&"hand_hammer", "Hand Hammer", "Needed in your inventory to build a Workbench and to break stone into rocks.")
	hammer.max_stack = 1
	out.append(hammer)
	# Furniture (crafting stations, storage, doors).
	for f: Array in [[&"workbench", "Workbench", "A crafting station: furniture, tools and the next stations."],
			[&"furnace", "Furnace", "A crafting station: smelts ore into bars."],
			[&"copper_anvil", "Copper Anvil", "A crafting station: copper tools."],
			[&"chest", "Chest", "Stores 40 stacks. Right click or E to open."],
			[&"door", "Door", "Right click or E to open and close."]]:
		var furn := _small(f[0], f[1], f[2])
		furn.kind = ItemData.Kind.FURNITURE
		furn.places_object = f[0]
		furn.place_area_max = 1
		furn.max_stack = 99
		out.append(furn)
	var acorn := _small(&"tree_seed", "Tree Seed", "Plant on grass to grow a tree.")
	acorn.kind = ItemData.Kind.SEED
	acorn.plants = &"tree"
	acorn.place_area_max = 1
	out.append(acorn)
	var grass := _small(&"grass_seeds", "Grass Seeds", "Plant on dirt to grow grass. Cutting flowers and tall grass drops them.")
	grass.kind = ItemData.Kind.SEED
	grass.plants = &"grass"
	out.append(grass)
	# Tools.
	var pick := _tool(&"copper_pickaxe", "Copper Pickaxe", "Mines a 2x2 area per swing.", &"tool")
	pick.mining_damage = 25.0
	pick.mining_area = 2
	pick.reach_tiles = 10.0
	out.append(pick)
	var axe := _tool(&"copper_axe", "Copper Axe", "Chops trees.", &"tool")
	axe.axe_damage = 25.0
	out.append(axe)
	var stone_pick := _tool(&"stone_pickaxe", "Stone Pickaxe", "A flint pickaxe. Mines one block per swing.", &"tool")
	stone_pick.mining_damage = 15.0
	stone_pick.mining_area = 1
	stone_pick.reach_tiles = 7.0
	out.append(stone_pick)
	var stone_axe := _tool(&"stone_axe", "Stone Axe", "A flint axe. Chops trees, slowly.", &"tool")
	stone_axe.axe_damage = 15.0
	stone_axe.reach_tiles = 7.0
	out.append(stone_axe)
	# The spellbook used when the book slot is empty. Not found in the world.
	var book := _base(&"basic_spellbook", "Basic Spellbook", "Holds 4 spells. Used when no other book is equipped.")
	book.kind = ItemData.Kind.BOOK
	book.max_stack = 1
	book.spell_slots = 4
	book.max_spell_tier = 1
	book.held = _look(&"basic_spellbook", &"spell_book", Vector2(5, 9))
	out.append(book)
	return out


func _spells() -> Array[ItemData]:
	var out: Array[ItemData] = []
	var mining := SpellData.new()
	mining.id = &"mining_spell"
	mining.display_name = "Mining Spell"
	mining.description = "Hold to mine with a beam (right click: the back layer). Ctrl + mouse wheel changes the area."
	mining.icon = load("res://assets/items/icons/mining_spell.png") as Texture2D
	mining.kind = ItemData.Kind.SPELL
	mining.max_stack = 1
	mining.beam = true
	mining.mining_damage = 55.0  # per second, on every tile in the area
	mining.mining_area = 2
	mining.mining_area_max = 3
	mining.reach_tiles = 12.0
	mining.mana_per_second = 4.0
	out.append(mining)

	var chop := _spell(&"chopping_spell", "Chopping Spell", "Hold to chop a tree with a beam. A bit slower than the copper axe.")
	chop.beam = true
	chop.axe_damage = 55.0  # per second (the copper axe is 25 per 0.35 s swing, about 71/s)
	chop.reach_tiles = 12.0
	chop.mana_per_second = 3.0
	out.append(chop)

	var fly := _spell(&"fly", "Fly", "Concentration. Click to start flying, click again to stop. Move with WASD, Space goes up.")
	fly.cast = SpellData.Cast.TOGGLE
	fly.effect = &"fly"
	fly.mana_per_second = 10.0
	out.append(fly)

	var spark := _spell(&"spark", "Spark", "A small bolt toward the cursor. Hold to keep casting.")
	spark.cast = SpellData.Cast.PROJECTILE
	spark.damage = 8.0
	spark.projectile_speed = 40.0
	spark.projectile_range = 20.0
	spark.impact_at = 0.35
	spark.mana_cost = 2.0
	out.append(spark)
	return out


## Furniture tile objects. The anchor is the bottom-left tile.
func _objects() -> Array[ObjectDef]:
	var out: Array[ObjectDef] = []
	var filler := ObjectDef.new()
	filler.id = &"filler"
	filler.display_name = "(furniture filler)"
	filler.filler = true
	filler.style = ObjectDef.Style.FURNITURE
	out.append(filler)
	# [id, name, w, h, station, frames file]
	for f: Array in [[&"workbench", "Workbench", 5, 4, &"workbench"], [&"furnace", "Furnace", 4, 5, &"furnace"],
			[&"copper_anvil", "Copper Anvil", 3, 3, &"anvil"], [&"chest", "Chest", 3, 3, &""],
			[&"door", "Door", 1, 8, &""]]:
		var o := ObjectDef.new()
		o.id = f[0]
		o.display_name = f[1]
		o.style = ObjectDef.Style.FURNITURE
		o.width_tiles = f[2]
		o.height_tiles = f[3]
		o.station = f[4]
		o.needs_floor = true
		o.health = 1.0
		o.drop_item = f[0]
		o.frames = load("res://assets/objects/%s.png" % f[0]) as Texture2D
		out.append(o)
	out[2].light_radius = 6.0  # the furnace glows
	out[2].light_color = Color(1.0, 0.6, 0.3)
	out[4].container_slots = 40
	out[5].blocks_movement = true
	out[5].toggles_to = &"door_open"
	out[5].toggles_to_left = &"door_open_left"
	# Open doors keep the 1x8 footprint (Starbound style): the door swings toward you,
	# seen edge on. door_open hinges on the left, door_open_left on the right.
	for left: bool in [false, true]:
		var open := out[5].duplicate() as ObjectDef
		open.id = &"door_open_left" if left else &"door_open"
		open.display_name = "Door (open)"
		open.blocks_movement = false
		open.frames = load("res://assets/objects/door_open.png") as Texture2D
		open.frame = 1 if left else 0
		open.sprite_width_px = 24  # the door's face, 3 tiles wide
		# Hinged at the doorway: hinge left grows right, hinge right grows left.
		open.sprite_align = ObjectDef.SpriteAlign.FROM_RIGHT if left else ObjectDef.SpriteAlign.FROM_LEFT
		open.toggles_to = &"door"
		open.toggles_to_left = &""
		out.append(open)
	return out


## Recipes: [id, station, {inputs}, output, count, requires]. Station &"" = by hand.
func _recipes() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	var table: Array = [
		# By hand.
		[&"hand_hammer", &"", {&"rock": 1, &"stick": 1}, &"hand_hammer", 1, []],
		[&"stone_pickaxe", &"", {&"flint": 3, &"stick": 2}, &"stone_pickaxe", 1, []],
		[&"stone_axe", &"", {&"flint": 3, &"stick": 2}, &"stone_axe", 1, []],
		[&"wood_planks", &"", {&"wood": 1}, &"wood_planks", 2, []],
		[&"wood_platform", &"", {&"wood_planks": 1}, &"wood_platform", 2, []],
		[&"torch", &"", {&"stick": 1, &"wood": 1}, &"torch", 3, []],
		[&"workbench", &"", {&"wood_planks": 10}, &"workbench", 1, [&"hand_hammer"]],
		# Workbench.
		[&"rocks_from_stone", &"workbench", {&"stone": 1}, &"rock", 3, [&"hand_hammer"]],
		[&"chest", &"workbench", {&"wood_planks": 8, &"copper_bar": 2}, &"chest", 1, []],
		[&"door", &"workbench", {&"wood_planks": 6}, &"door", 1, []],
		[&"furnace", &"workbench", {&"stone": 20, &"wood": 4, &"torch": 3}, &"furnace", 1, []],
		[&"copper_anvil", &"workbench", {&"copper_bar": 6}, &"copper_anvil", 1, []],
		# Furnace.
		[&"copper_bar", &"furnace", {&"copper_ore": 3}, &"copper_bar", 1, []],
		# Anvil.
		[&"copper_pickaxe", &"anvil", {&"copper_bar": 10, &"stick": 3}, &"copper_pickaxe", 1, []],
		[&"copper_axe", &"anvil", {&"copper_bar": 8, &"stick": 3}, &"copper_axe", 1, []],
	]
	for e: Array in table:
		var r := RecipeData.new()
		r.id = e[0]
		r.station = e[1]
		for k: StringName in (e[2] as Dictionary):
			r.inputs[k] = e[2][k]
		r.output = e[3]
		r.output_count = e[4]
		for q: StringName in e[5]:
			r.requires.append(q)
		r.display_name = String(e[3]).capitalize()
		out.append(r)
	return out


func _spell(spell_id: StringName, label: String, text: String) -> SpellData:
	var s := SpellData.new()
	s.id = spell_id
	s.display_name = label
	s.description = text
	s.icon = load("res://assets/items/icons/%s.png" % spell_id) as Texture2D
	s.kind = ItemData.Kind.SPELL
	s.max_stack = 1
	return s


func _base(item_id: StringName, label: String, text: String) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = label
	item.description = text
	item.icon = load("res://assets/items/icons/%s.png" % item_id) as Texture2D
	return item


func _look(item_id: StringName, type_id: StringName, grip: Vector2) -> HeldItemLook:
	var look := HeldItemLook.new()
	look.id = item_id
	look.type = type_id
	look.texture = load("res://assets/items/held/%s.png" % item_id) as Texture2D
	look.grip = grip
	return look


func _block(item_id: StringName, label: String, text: String, wall: StringName = &"") -> ItemData:
	var item := _base(item_id, label, text)
	item.kind = ItemData.Kind.BLOCK
	item.places_block = item_id
	item.places_wall = wall
	item.impact_at = 0.2  # placed early in the quick Place reach
	item.held = _look(item_id, &"block", Vector2(3, 5))
	return item


func _small(item_id: StringName, label: String, text: String) -> ItemData:
	var item := _base(item_id, label, text)
	item.impact_at = 0.2
	item.held = _look(item_id, &"block", Vector2(4, 6))
	return item


func _tool(item_id: StringName, label: String, text: String, type_id: StringName) -> ItemData:
	var item := _base(item_id, label, text)
	item.kind = ItemData.Kind.TOOL
	item.max_stack = 1
	item.held = _look(item_id, type_id, Vector2(3, 12))
	return item
