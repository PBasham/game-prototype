extends SceneTree
## Writes the default items (data/items/*.tres) and spells (data/spells/*.tres) from the
## tables below.
##
##   godot --headless --path . --script res://tools/make_items.gd
##   godot --headless --path . --script res://tools/make_items.gd -- --force
##   godot --headless --path . --script res://tools/make_items.gd -- --only=copper_pickaxe --force
##
## Without --force, existing files are kept (your Inspector edits are safe). Art comes
## from tools/make_item_art.gd (assets/items/icons and assets/items/held).

const DIR := "res://data/items"
const SPELL_DIR := "res://data/spells"

var _force := false


func _init() -> void:
	_force = OS.get_cmdline_user_args().has("--force")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPELL_DIR))
	var written := 0
	var all: Array[ItemData] = _items()
	all.append_array(_spells())
	for item: ItemData in all:
		if not _selected(item):
			continue
		var path := "%s/%s.tres" % [SPELL_DIR if item.is_spell() else DIR, item.id]
		if FileAccess.file_exists(path) and not _force:
			print("make_items: %s exists, kept (use --force to overwrite)" % path)
			continue
		ResourceSaver.save(item, path)
		written += 1
		print("make_items: wrote %s" % path)
	print("make_items: %d written" % written)
	quit()


func _selected(item: ItemData) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			return String(item.id) == a.trim_prefix("--only=")
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
	var rope := _block(&"rope", "Rope", "Climb with Up and Down.")
	rope.place_area_max = 1
	out.append(rope)
	# Materials and seeds.
	var wood := _small(&"wood", "Wood", "From trees. Crafted into planks (crafting comes later).")
	out.append(wood)
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
	# The spellbook used when the book slot is empty. Not found in the world.
	var book := _base(&"basic_spellbook", "Basic Spellbook", "Holds 4 spells. Used when no other book is equipped.")
	book.kind = ItemData.Kind.BOOK
	book.max_stack = 1
	book.spell_slots = 4
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
	out.append(mining)
	return out


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
