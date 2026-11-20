extends SceneTree
## Writes the default items (data/items), spells (data/spells), tile objects
## (data/objects: furniture), recipes (data/recipes), enemies (data/enemies) and spawn
## tables (data/spawns) and forageables (data/forage) from the tables below.
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
const ENEMY_DIR := "res://data/enemies"
const SPAWN_DIR := "res://data/spawns"
const FORAGE_DIR := "res://data/forage"
const BUSH_DIR := "res://data/bushes"

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
	for enemy in _enemies():
		all.append([enemy, ENEMY_DIR])
	for scroll in _scrolls():
		all.append([scroll, DIR])
	for f in _forage():
		all.append([f, FORAGE_DIR])
	for b in _bushes():
		all.append([b, BUSH_DIR])
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
	# Spawn tables point at the saved enemy files, so they're written after them.
	for table in _spawns():
		if not _selected(table.id):
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPAWN_DIR))
		var path := "%s/%s.tres" % [SPAWN_DIR, table.id]
		if FileAccess.file_exists(path) and not _force:
			print("make_items: %s exists, kept (use --force to overwrite)" % path)
			continue
		ResourceSaver.save(table, path)
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
	out.append(_block(&"copper_ore", "Copper Ore", "Smelts into copper bars in a Furnace."))
	out.append(_block(&"iron_ore", "Iron Ore", "Deeper than copper. Smelts into iron bars in a Furnace."))
	# Wood is the building block too (like Terraria): it places the plank block.
	var wood := _block(&"wood", "Wood", "From logs (1 log = 4 wood) and sticks. A building block (right click places it as a back wall), and the wood in tools, torches and furniture.", &"wood_wall")
	wood.places_block = &"wood_planks"
	wood.icon = load("res://assets/items/icons/wood_planks.png") as Texture2D
	wood.held = _look(&"wood_planks", &"block", Vector2(3, 5))
	out.append(wood)
	# Logs: what trees drop. Craft into 4 Wood, or build a log cabin with them.
	out.append(_block(&"log", "Log", "From trees. Craft into 4 Wood, or build with it: a log cabin block (right click: a log back wall).", &"log_wall"))
	# Dark Forest: darkwood trees drop Dark Logs, 1 = 4 Darkwood (a building block).
	var dlog := _small(&"dark_log", "Dark Log", "From darkwood trees in the Dark Forest. Craft into 4 Darkwood.")
	out.append(dlog)
	var dwood := _block(&"darkwood", "Darkwood", "Dark, dense wood from the Dark Forest (1 Dark Log = 4). A building block (right click: a back wall).", &"darkwood_wall")
	dwood.places_block = &"darkwood_planks"
	dwood.held.grip = Vector2(3, 5)
	out.append(dwood)
	var dsap := _small(&"darkwood_sapling", "Darkwood Sapling", "Plant on grass to grow a darkwood tree (Dark Logs).")
	dsap.kind = ItemData.Kind.SEED
	dsap.plants = &"darkwood"
	dsap.place_area_max = 1
	out.append(dsap)
	out.append(_small(&"magic_essence", "Magic Essence", "A wisp of magic left by a Forest Spirit."))
	out.append(_small(&"spirit_core", "Spirit Core", "The glowing heart of a Forest Spirit. Rare."))
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
	out.append(_small(&"copper_bar", "Copper Bar", "Smelted from copper ore in a Furnace."))
	out.append(_small(&"iron_bar", "Iron Bar", "Smelted from iron ore in a Furnace."))
	var berries := _small(&"berries", "Berries", "Picked from berry bushes. Left click to eat: +10 hunger, +2 health.")
	berries.kind = ItemData.Kind.FOOD
	berries.food_value = 10.0
	berries.heal_value = 2.0
	out.append(berries)
	var rasp := _small(&"raspberries", "Raspberries", "Picked from raspberry bushes. Filling: left click to eat, +14 hunger, +1 health.")
	rasp.kind = ItemData.Kind.FOOD
	rasp.food_value = 14.0
	rasp.heal_value = 1.0
	out.append(rasp)
	var blue := _small(&"blueberries", "Blueberries", "Picked from blueberry bushes. Light but good for you: left click to eat, +6 hunger, +4 health.")
	blue.kind = ItemData.Kind.FOOD
	blue.food_value = 6.0
	blue.heal_value = 4.0
	out.append(blue)
	# Mushrooms (forageables): food, and ingredients for potions and poisons later.
	var field := _small(&"field_mushroom", "Field Mushroom", "A plain, filling mushroom. Left click to eat: +8 hunger, +1 health. Better cooked at a campfire.")
	field.kind = ItemData.Kind.FOOD
	field.food_value = 8.0
	field.heal_value = 1.0
	out.append(field)
	var red := _small(&"red_cap", "Red Cap", "Red with white spots. Barely food (+2 hunger); brewed into Healing Potions.")
	red.kind = ItemData.Kind.FOOD
	red.food_value = 2.0
	out.append(red)
	out.append(_small(&"duskcap", "Duskcap", "A purple cave mushroom. Toxic: brewed into Poison Coatings and Poison Flasks."))
	out.append(_small(&"glowcap", "Glowcap", "Glows in dark caves. Brewed into Mana Potions."))
	# Food & Alchemy.
	out.append(_block(&"clay", "Clay", "Found in patches in the dirt. Fire it in a Furnace into Clay Flasks."))
	var flask_empty := _small(&"clay_flask", "Clay Flask", "An empty flask of fired clay. Potions, coatings and thrown flasks start with one.")
	_detailed(flask_empty, &"")
	out.append(flask_empty)
	out.append(_small(&"wooden_bowl", "Wooden Bowl", "For stew."))
	for row: Array in [
			[&"roasted_berries", "Roasted Berries", "Warm and sweet. +25 hunger, +5 health.", 25.0, 5.0],
			[&"cooked_mushroom", "Cooked Mushroom", "Seared on the campfire. +16 hunger, +4 health.", 16.0, 4.0],
			[&"mushroom_stew", "Mushroom Stew", "A hearty bowl. +40 hunger, +8 health, and Well Fed for 5 minutes.", 40.0, 8.0]]:
		var food := _small(row[0], row[1], row[2])
		food.kind = ItemData.Kind.FOOD
		food.food_value = row[3]
		food.heal_value = row[4]
		out.append(food)
	out[out.size() - 1].buff_name = "Well Fed"
	out[out.size() - 1].buff_description = "Health refills a little faster and you move 10% faster."
	out[out.size() - 1].buff_seconds = 300.0
	out[out.size() - 1].buff_health_regen = 0.5
	out[out.size() - 1].buff_move_speed = 0.1
	var compote := _small(&"raspberry_compote", "Raspberry Compote", "Stewed raspberries. +35 hunger, +6 health, and Mending for 4 minutes.")
	compote.kind = ItemData.Kind.FOOD
	compote.food_value = 35.0
	compote.heal_value = 6.0
	compote.buff_name = "Mending"
	compote.buff_description = "Health refills 1 a second faster."
	compote.buff_seconds = 240.0
	compote.buff_health_regen = 1.0
	out.append(compote)
	var mash := _small(&"blueberry_mash", "Blueberry Mash", "Mashed blueberries. +20 hunger, +10 health, and Light Step for 4 minutes.")
	mash.kind = ItemData.Kind.FOOD
	mash.food_value = 20.0
	mash.heal_value = 10.0
	mash.buff_name = "Light Step"
	mash.buff_description = "You move 15% faster."
	mash.buff_seconds = 240.0
	mash.buff_move_speed = 0.15
	out.append(mash)
	var heal := _small(&"healing_potion", "Healing Potion", "Drink: +30 health. Then 30 s before another.")
	heal.kind = ItemData.Kind.FOOD
	heal.heal_value = 30.0
	heal.sickness = &"healing"
	heal.sickness_seconds = 30.0
	heal.max_stack = 30
	_detailed(heal, &"heal")
	out.append(heal)
	var manap := _small(&"mana_potion", "Mana Potion", "Drink: +40 mana. Then 10 s before another.")
	manap.kind = ItemData.Kind.FOOD
	manap.mana_value = 40.0
	manap.sickness = &"mana"
	manap.sickness_seconds = 10.0
	manap.max_stack = 30
	_detailed(manap, &"mana")
	out.append(manap)
	var coat := _small(&"poison_coating", "Poison Coating", "Rub it on your weapon: the next 10 melee hits poison (2 damage a second for 4 s).")
	coat.kind = ItemData.Kind.FOOD
	coat.buff_name = "Poison Coating"
	coat.buff_description = "Melee hits poison what they hit."
	coat.buff_seconds = 180.0
	coat.buff_poison_hits = 10
	coat.poison_dps = 2.0
	coat.poison_seconds = 4.0
	coat.max_stack = 30
	out.append(coat)
	var flask := _small(&"poison_flask", "Poison Flask", "Left click to throw. Shatters into a cloud that poisons enemies inside (2 damage a second).")
	flask.throw_speed = 22.0
	flask.throw_effect = &"poison_cloud"
	flask.poison_dps = 2.0
	flask.poison_seconds = 3.0
	flask.cloud_tiles = Vector2(4, 3)
	flask.cloud_seconds = 4.0
	flask.max_stack = 30
	out.append(flask)
	var hammer := _small(&"hand_hammer", "Hand Hammer", "Needed in your inventory to build a Workbench.")
	hammer.max_stack = 1
	out.append(hammer)
	# Furniture (crafting stations, storage, doors).
	for f: Array in [[&"workbench", "Workbench", "A crafting station: furniture, tools and the next stations."],
			[&"furnace", "Furnace", "A crafting station: smelts ore into bars."],
			[&"copper_anvil", "Copper Anvil", "A crafting station: copper tools."],
			[&"chest", "Chest", "Stores 40 stacks. Right click or E to open."],
			[&"door", "Door", "Right click or E to open and close."],
			[&"spell_weaving_table", "Spell Weaving Table", "A crafting station: learn spells (and later, empower them)."],
			[&"scribes_desk", "Scribe's Desk", "A crafting station: scribe scrolls of the spells you know onto blank scrolls."],
			[&"lumber_rack", "Lumber Rack", "Storage for logs and wood: 1,000 of them. It fills up as you stock it."],
			[&"potion_cabinet", "Potion Cabinet", "Storage for potions, flasks and coatings: 10 stacks, shown on its shelves."],
			[&"campfire", "Campfire", "A big warm light. Standing near it, health refills faster (Cozy). Right click to cook."],
			[&"alchemy_table", "Alchemy Table", "A crafting station: potions, weapon coatings and thrown flasks."],
			[&"table", "Table", "Put things on display on top: hold an item and right click the table top."],
			[&"shelf", "Shelf", "Hangs on a back wall. Put things on display on it: hold an item and right click the shelf."]]:
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
	var pick := _tool(&"copper_pickaxe", "Copper Pickaxe", "Mines a 2x2 area per swing (Ctrl + wheel: 1x1).", &"tool")
	pick.mining_damage = 25.0
	pick.mining_power = 40
	pick.mining_area = 2
	pick.reach_tiles = 10.0
	out.append(pick)
	var ipick := _tool(&"iron_pickaxe", "Iron Pickaxe", "Mines a 2x2 area per swing (Ctrl + wheel: 1x1). Faster and stronger than copper.", &"tool")
	ipick.mining_damage = 35.0
	ipick.mining_power = 50
	ipick.mining_area = 2
	ipick.reach_tiles = 11.0
	out.append(ipick)
	var iaxe := _tool(&"iron_axe", "Iron Axe", "Chops trees, faster than copper.", &"tool")
	iaxe.axe_damage = 35.0
	out.append(iaxe)
	var axe := _tool(&"copper_axe", "Copper Axe", "Chops trees.", &"tool")
	axe.axe_damage = 25.0
	out.append(axe)
	var stone_pick := _tool(&"stone_pickaxe", "Stone Pickaxe", "A stone pickaxe. Mines a 2x2 area per swing (Ctrl + wheel: 1x1).", &"tool")
	stone_pick.mining_damage = 15.0
	stone_pick.mining_power = 35
	stone_pick.mining_area = 2
	stone_pick.reach_tiles = 7.0
	out.append(stone_pick)
	var stone_axe := _tool(&"stone_axe", "Stone Axe", "A stone axe. Chops trees, slowly.", &"tool")
	stone_axe.axe_damage = 15.0
	stone_axe.reach_tiles = 7.0
	out.append(stone_axe)
	# Combat (Phase 7).
	out.append(_small(&"slime", "Slime", "Sticky. Drops from slimes."))
	var wsword := _weapon(&"wooden_sword", "Wooden Sword", "A practice sword. Better than your fists.")
	wsword.melee_damage = 8.0
	wsword.melee_reach = 4.0
	wsword.knockback = 10.0
	out.append(wsword)
	var csword := _weapon(&"copper_sword", "Copper Sword", "A proper blade.")
	csword.melee_damage = 13.0
	csword.melee_reach = 4.5
	csword.knockback = 13.0
	out.append(csword)
	var isword := _weapon(&"iron_sword", "Iron Sword", "Heavier and sharper than copper.")
	isword.melee_damage = 18.0
	isword.melee_reach = 4.75
	isword.knockback = 15.0
	out.append(isword)
	for a: Array in [[&"copper_helmet", "Copper Helmet", &"head", 1], [&"copper_chestplate", "Copper Chestplate", &"chest", 2],
			[&"copper_greaves", "Copper Greaves", &"legs", 1], [&"iron_helmet", "Iron Helmet", &"head", 2],
			[&"iron_chestplate", "Iron Chestplate", &"chest", 3], [&"iron_greaves", "Iron Greaves", &"legs", 2]]:
		var armor := _small(a[0], a[1], "Armor (%s). Defense %d." % [String(a[2]), a[3]])
		armor.kind = ItemData.Kind.ARMOR
		armor.max_stack = 1
		armor.equip_slot = a[2]
		armor.defense = a[3]
		# Drawn on the character: overlays from tools/make_armor_art.gd.
		var parts: Array = {&"head": ["Head"], &"chest": ["Torso", "Front Arm Upper", "Back Arm Upper"],
			&"legs": ["Front Leg Upper", "Back Leg Upper", "Front Leg Lower", "Back Leg Lower"]}[a[2]]
		for part: String in parts:
			var path := "res://assets/armor/%s_%s.png" % [a[0], part.to_lower().replace(" ", "_")]
			if ResourceLoader.exists(path):
				armor.wear[part] = load(path) as Texture2D
		armor.hides_hair = a[2] == &"head"
		out.append(armor)
	var bed_item := _small(&"bed", "Bed", "Right click: set your respawn point here, and sleep through the night.")
	bed_item.kind = ItemData.Kind.FURNITURE
	bed_item.places_object = &"bed"
	bed_item.place_area_max = 1
	bed_item.max_stack = 99
	out.append(bed_item)
	# The spellbook used when the book slot is empty. Not found in the world.
	var book := _base(&"basic_spellbook", "Basic Spellbook", "Always yours: used when no other book is equipped.")
	book.kind = ItemData.Kind.BOOK
	book.max_stack = 1
	book.max_spell_tier = 1
	book.held = _look(&"basic_spellbook", &"spell_book", Vector2(5, 9))
	out.append(book)
	# Spellbooks by tier (Patrick: for testing; not found or crafted yet: `give` them).
	for t in range(1, 4):
		var tb := _base(StringName("spellbook_t%d" % t), "Tier %d Spellbook" % t,
			"A spellbook for spells up to tier %d." % t)
		tb.kind = ItemData.Kind.BOOK
		tb.max_stack = 1
		tb.max_spell_tier = t
		tb.spell_power = [1.0, 1.25, 1.5][t - 1]
		tb.held = _look(tb.id, &"spell_book", Vector2(5, 9))
		out.append(tb)
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
	mining.mining_power = 40
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

	var fly := _spell(&"fly", "Fly", "Concentration. Click to start flying, click again to stop. Move with WASD, Space goes up. Hold Shift to fly much faster, for a lot more mana.")
	fly.cast = SpellData.Cast.TOGGLE
	fly.effect = &"fly"
	fly.move_speed = 34.0
	fly.boost_speed_mult = 2.0
	fly.boost_mana_mult = 4.0
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

	# Phase 7 spells (numbers are first guesses).
	var lev := _spell(&"levitate", "Levitate", "Concentration. Float about 5 blocks above the ground and glide fast. Down lowers you; you can't rise higher.")
	lev.cast = SpellData.Cast.TOGGLE
	lev.effect = &"levitate"
	lev.move_speed = 30.0
	lev.hover_tiles = 5.0
	lev.mana_per_second = 4.0
	out.append(lev)

	var drill := _spell(&"hyper_drill", "Hyper Drill", "Hold for a huge drilling beam that tears through a round area. Very mana hungry. Right click: back walls.")
	drill.beam = true
	drill.mining_damage = 400.0  # per second, on every tile in the circle
	drill.mining_power = 55
	drill.mining_area = 11  # 5 tiles each way from the center
	drill.mining_round = true
	drill.reach_tiles = 24.0
	drill.mana_per_second = 30.0
	drill.tier = 3
	drill.projectile_color = Color(1.0, 0.55, 0.3)
	out.append(drill)

	var push := _spell(&"air_push", "Air Push", "A gust toward the cursor that shoves enemies away. Walls stop it. It pushes you back too: in the air, or aimed down at the ground for a gust jump.")
	push.cast = SpellData.Cast.GUST
	push.damage = 2.0
	push.gust_tiles = 8.0
	push.gust_angle = 35.0
	push.gust_push = 36.0
	push.gust_recoil = 26.0
	push.mana_cost = 8.0
	push.cooldown = 0.6
	push.impact_at = 0.3
	push.projectile_color = Color(0.85, 0.95, 1.0)
	out.append(push)

	var blink := _spell(&"blink", "Blink", "Teleport toward the cursor, up to 12 blocks, to the farthest spot you fit.")
	blink.cast = SpellData.Cast.BLINK
	blink.blink_tiles = 12.0
	blink.mana_cost = 15.0
	blink.cooldown = 1.0
	blink.impact_at = 0.3
	blink.projectile_color = Color(0.78, 0.6, 1.0)
	out.append(blink)

	var orb := _spell(&"light_orb", "Light Orb", "A glowing orb follows you and lights the way for 3 minutes. Cast again to refresh it.")
	orb.cast = SpellData.Cast.LIGHT
	orb.light_radius = 36.0
	orb.light_color = Color(1.0, 0.92, 0.75)
	orb.duration = 180.0
	orb.mana_cost = 10.0
	orb.cooldown = 1.0
	orb.impact_at = 0.3
	out.append(orb)

	var wisp := _spell(&"wisp", "Wisp", "Hold to steer a wisp of light with the cursor; let go to leave it there. Up to 3 at once, 5 minutes each.")
	wisp.cast = SpellData.Cast.LIGHT
	wisp.light_placed = true
	wisp.light_max = 3
	wisp.light_radius = 26.0
	wisp.light_color = Color(0.75, 0.9, 1.0)
	wisp.duration = 300.0
	wisp.mana_cost = 12.0
	wisp.cooldown = 0.5
	wisp.impact_at = 0.2
	out.append(wisp)

	var grab := _spell(&"tele_grab", "Tele Grab", "Hold: a portal opens at the cursor and pulls loose items near it into a portal at your hand. Needs sight of the spot.")
	grab.cast = SpellData.Cast.GRAB
	grab.group = SpellData.Group.TOOLS
	grab.quick_default = 2
	grab.beam = true
	grab.reach_tiles = 25.0
	grab.grab_tiles = 3.0
	grab.grab_pull_speed = 18.0
	grab.mana_per_second = 3.0
	grab.projectile_color = Color(0.75, 0.55, 1.0)
	grab.learn_cost = {&"copper_bar": 3}
	out.append(grab)

	var gel := _spell(&"gel_cushion", "Gel Cushion", "A slime cushion: the next fall that would hurt you doesn't. Lasts 2 minutes or one fall. Uses 5 Slime.")
	gel.cast = SpellData.Cast.BUFF
	gel.effect = &"gel_cushion"
	gel.duration = 120.0
	gel.mana_cost = 10.0
	gel.reagents = {&"slime": 5}
	gel.cooldown = 0.5
	gel.impact_at = 0.3
	gel.projectile_color = Color(0.55, 1.0, 0.45)
	out.append(gel)

	# Phase 8: one spell per new type (numbers are first guesses).
	var bolt := _spell(&"arcane_bolt", "Arcane Bolt", "Hold to charge, let go to fire. A full charge (1.5 s) hits five times harder than a tap, for more mana.")
	bolt.cast = SpellData.Cast.CHARGED
	bolt.damage = 30.0
	bolt.mana_cost = 15.0
	bolt.charge_seconds = 1.5
	bolt.charge_min_damage = 0.2
	bolt.charge_min_mana = 0.27
	bolt.projectile_speed = 45.0
	bolt.projectile_range = 26.0
	bolt.cooldown = 0.2
	bolt.projectile_color = Color(0.75, 0.5, 1.0)
	out.append(bolt)

	var circle := _spell(&"healing_circle", "Healing Circle", "A circle of light at the cursor for 10 seconds. Standing in it heals you.")
	circle.cast = SpellData.Cast.ZONE
	circle.zone_tiles = 5.0
	circle.duration = 10.0
	circle.heal_per_second = 4.0
	circle.max_active = 1  # casting again moves it
	circle.mana_cost = 25.0
	circle.cooldown = 2.0
	circle.impact_at = 0.3
	circle.projectile_color = Color(0.5, 1.0, 0.6)
	out.append(circle)

	var ward := _spell(&"spark_ward", "Spark Ward", "A rune on the ground under the cursor. The first enemy to touch it is zapped and thrown back. Up to 3; lasts 2 minutes.")
	ward.cast = SpellData.Cast.WARD
	ward.damage = 20.0
	ward.knockback = 20.0
	ward.duration = 120.0
	ward.max_active = 3
	ward.mana_cost = 15.0
	ward.cooldown = 0.5
	ward.impact_at = 0.3
	ward.projectile_color = Color(1.0, 0.85, 0.4)
	out.append(ward)

	var fam := _spell(&"familiar", "Familiar", "A little spirit follows you for a minute and shoots at enemies nearby.")
	fam.cast = SpellData.Cast.SUMMON
	fam.damage = 5.0
	fam.duration = 60.0
	fam.summon_interval = 1.0
	fam.summon_tiles = 15.0
	fam.projectile_speed = 35.0
	fam.projectile_range = 18.0
	fam.mana_cost = 30.0
	fam.cooldown = 1.0
	fam.impact_at = 0.3
	fam.projectile_color = Color(0.6, 0.85, 1.0)
	out.append(fam)

	var plat := _spell(&"conjure_platform", "Conjure Platform", "A glowing platform, 6 blocks wide, at the cursor for 30 seconds. Down + Jump drops through.")
	plat.cast = SpellData.Cast.CONJURE
	plat.conjure_tiles = 6
	plat.duration = 30.0
	plat.mana_cost = 10.0
	plat.cooldown = 0.5
	plat.impact_at = 0.3
	plat.projectile_color = Color(0.7, 0.6, 1.0)
	out.append(plat)

	var edge := _spell(&"arcane_edge", "Arcane Edge", "Your melee weapons hit 50% harder for a minute.")
	edge.cast = SpellData.Cast.BUFF
	edge.effect = &"arcane_edge"
	edge.duration = 60.0
	edge.melee_mult = 1.5
	edge.mana_cost = 20.0
	edge.cooldown = 0.5
	edge.impact_at = 0.3
	edge.projectile_color = Color(0.8, 0.5, 1.0)
	out.append(edge)

	var barrier := _spell(&"barrier", "Barrier", "Waits up to 5 minutes. When a hit would take you under a quarter of your health, a shield pops up and soaks the next 30 damage (10 seconds).")
	barrier.cast = SpellData.Cast.BUFF
	barrier.effect = &"barrier"
	barrier.duration = 300.0
	barrier.trigger_health = 0.25
	barrier.shield_amount = 30.0
	barrier.shield_seconds = 10.0
	barrier.mana_cost = 30.0
	barrier.cooldown = 1.0
	barrier.impact_at = 0.3
	barrier.projectile_color = Color(0.6, 0.85, 1.0)
	out.append(barrier)

	var chain := _spell(&"chain_spark", "Chain Spark", "Shoots lightning toward the cursor. If it hits, it jumps to up to 3 more nearby, weaker each jump. If it misses, it misses.")
	chain.cast = SpellData.Cast.CHAIN
	chain.damage = 10.0
	chain.reach_tiles = 12.0
	chain.chain_jumps = 3
	chain.chain_tiles = 6.0
	chain.chain_falloff = 0.2
	chain.mana_cost = 12.0
	chain.cooldown = 0.6
	chain.impact_at = 0.3
	chain.projectile_color = Color(0.7, 0.9, 1.0)
	out.append(chain)

	var recall := _spell(&"recall", "Recall", "Ritual: stand still for 3 seconds and you're sent back to your bed (or the world spawn). Moving or getting hurt breaks it. Mana is spent when it finishes.")
	recall.cast = SpellData.Cast.RITUAL
	recall.effect = &"recall"
	recall.ritual_seconds = 3.0
	recall.mana_cost = 40.0
	recall.cooldown = 3.0
	recall.impact_at = 0.3
	recall.projectile_color = Color(0.95, 0.8, 0.5)
	out.append(recall)

	var seek := _spell(&"seek_ore", "Seek Ore", "Copper ore within 30 blocks glows through everything for 15 seconds.")
	seek.cast = SpellData.Cast.SENSE
	seek.sense_block = &"copper_ore"
	seek.sense_tiles = 30.0
	seek.duration = 15.0
	seek.mana_cost = 15.0
	seek.cooldown = 2.0
	seek.impact_at = 0.3
	seek.projectile_color = Color(1.0, 0.6, 0.3)
	out.append(seek)

	var mend := _spell(&"mend", "Mend", "Concentration. Slowly heals you while it's on.")
	mend.cast = SpellData.Cast.TOGGLE
	mend.effect = &"mend"
	mend.heal_per_second = 3.0
	mend.mana_per_second = 6.0
	out.append(mend)
	# Learning from a scroll (at a Spell Weaving Table) costs extra: copper bars by tier, or
	# the spell's own material.
	# Spell Index tabs.
	var groups := {
		&"mining_spell": SpellData.Group.TOOLS,
		&"chopping_spell": SpellData.Group.TOOLS,
		&"hyper_drill": SpellData.Group.TOOLS,
		&"seek_ore": SpellData.Group.TOOLS,
		&"fly": SpellData.Group.MOVEMENT,
		&"levitate": SpellData.Group.MOVEMENT,
		&"blink": SpellData.Group.MOVEMENT,
		&"conjure_platform": SpellData.Group.MOVEMENT,
		&"recall": SpellData.Group.MOVEMENT,
		&"spark": SpellData.Group.ATTACK,
		&"arcane_bolt": SpellData.Group.ATTACK,
		&"chain_spark": SpellData.Group.ATTACK,
		&"air_push": SpellData.Group.ATTACK,
		&"spark_ward": SpellData.Group.ATTACK,
		&"familiar": SpellData.Group.ATTACK,
		&"arcane_edge": SpellData.Group.DEFENSE,
		&"barrier": SpellData.Group.DEFENSE,
		&"gel_cushion": SpellData.Group.DEFENSE,
		&"mend": SpellData.Group.DEFENSE,
		&"healing_circle": SpellData.Group.DEFENSE,
		&"light_orb": SpellData.Group.LIGHT,
		&"wisp": SpellData.Group.LIGHT}
	for sp in out:
		(sp as SpellData).group = groups.get(sp.id, SpellData.Group.ATTACK)
	for sp in out:
		var spell := sp as SpellData
		spell.learn_cost.assign(LEARN_COSTS.get(spell.id, {&"copper_bar": LEARN_BARS[clampi(spell.tier, 1, 3) - 1]}))
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
			[&"door", "Door", 1, 8, &""], [&"spell_weaving_table", "Spell Weaving Table", 6, 3, &"spell_weaving"],
			[&"campfire", "Campfire", 4, 3, &"cooking"], [&"alchemy_table", "Alchemy Table", 5, 3, &"alchemy"],
			[&"table", "Table", 4, 3, &""], [&"shelf", "Shelf", 3, 1, &""],
			# Added later go last, so the indexes below stay put.
			[&"scribes_desk", "Scribe's Desk", 4, 3, &"scribing"],
			[&"lumber_rack", "Lumber Rack", 3, 3, &""], [&"potion_cabinet", "Potion Cabinet", 3, 4, &""]]:
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
		o.detail = 2 if o.station != &"" else 1  # stations have detailed (2x) art
		out.append(o)
	out[2].light_radius = 16.0  # the furnace glows
	# The campfire: a big warm light, and Cozy (faster health refill) nearby.
	out[7].light_radius = 48.0
	out[7].light_color = Color(1.0, 0.68, 0.38)
	out[7].aura_radius = 12.0
	out[7].aura_health_regen = 1.5
	out[7].aura_name = "Cozy"
	out[7].aura_description = "Near a campfire: health refills faster."
	out[2].light_color = Color(1.0, 0.6, 0.3)
	# Table and shelf: things go on display on top (detailed art).
	for i in [9, 10]:
		out[i].display_surface = true
		out[i].detail = 2
	out[10].needs_floor = false
	out[10].needs_wall = true
	# Special storage (detailed art): what fits, how much, how it shows its fill.
	out[12].detail = 2
	out[12].container_slots = 10
	out[12].container_accepts = &"lumber"
	out[12].container_stack_cap = 100
	out[12].fill_look = ObjectDef.FillLook.FRAMES
	out[13].detail = 2
	out[13].container_slots = 10
	out[13].container_accepts = &"potion"
	out[13].fill_look = ObjectDef.FillLook.BOTTLES
	# What's on display (World.displays): drawn as the item itself.
	var shown := ObjectDef.new()
	shown.id = &"display"
	shown.display_name = "On display"
	shown.display = true
	shown.needs_floor = true  # the block under it can't be mined out from under it
	shown.health = 1.0
	out.append(shown)
	out[4].container_slots = 40
	out[5].blocks_movement = true
	out[5].anchors_building = true  # build walls and a lintel against it (stays when opened)
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
	var bed := ObjectDef.new()
	bed.id = &"bed"
	bed.display_name = "Bed"
	bed.style = ObjectDef.Style.FURNITURE
	bed.width_tiles = 9  # the Scholar is 8 tiles tall
	bed.height_tiles = 3
	bed.needs_floor = true
	bed.health = 1.0
	bed.drop_item = &"bed"
	bed.bed = true
	bed.frames = load("res://assets/objects/bed.png") as Texture2D
	out.append(bed)
	return out


## Enemies (Phase 7).
func _enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	var slime := EnemyData.new()
	slime.id = &"green_slime"
	slime.display_name = "Green Slime"
	slime.description = "Hops around. Not very dangerous."
	slime.texture = load("res://assets/enemies/slime.png") as Texture2D
	slime.frame_size = Vector2i(36, 27)
	slime.tint = Color(0.55, 1.0, 0.45)
	slime.size = Vector2(30, 20)
	slime.max_health = 20.0
	slime.contact_damage = 6.0
	slime.knockback = 10.0
	slime.loot.append(LootDrop.make(&"slime", 1, 2))
	out.append(slime)
	# The rare one: tougher, hits harder, hops higher, drops more slime.
	var blue := EnemyData.new()
	blue.id = &"blue_slime"
	blue.display_name = "Blue Slime"
	blue.description = "A rarer, tougher slime. Hops higher and hits harder."
	blue.texture = slime.texture
	blue.frame_size = slime.frame_size
	blue.tint = Color(0.3, 0.6, 1.0)
	blue.size = slime.size
	blue.max_health = 35.0
	blue.defense = 1
	blue.contact_damage = 9.0
	blue.knockback = 12.0
	blue.hop_speed = 11.0
	blue.hop_tiles_min = 3.0
	blue.hop_tiles = 7.0
	blue.hop_wait_min = 0.6
	blue.hop_wait_max = 1.8
	blue.loot.append(LootDrop.make(&"slime", 2, 4))
	out.append(blue)
	# Dark Forest: a glowing ball that darts about, stops, charges and shoots.
	var spirit := EnemyData.new()
	spirit.id = &"forest_spirit"
	spirit.display_name = "Forest Spirit"
	spirit.description = "A glowing wisp of the Dark Forest. Darts about, stops, charges for a second and shoots."
	spirit.texture = load("res://assets/enemies/forest_spirit.png") as Texture2D
	spirit.frame_size = Vector2i(24, 24)
	spirit.size = Vector2(12, 12)
	spirit.ai = EnemyData.AI.SPIRIT
	spirit.gravity = 0.0
	spirit.max_health = 30.0
	spirit.contact_damage = 6.0
	spirit.knockback = 10.0
	spirit.knockback_resist = 0.3
	spirit.aggro_tiles = 40.0
	spirit.aggro_tiles_vertical = 24.0
	spirit.wander_by_day = false
	spirit.shot_damage = 15.0
	spirit.glow_tiles = 8.0
	spirit.loot.append(LootDrop.make(&"magic_essence", 1, 2))
	spirit.loot.append(LootDrop.make(&"spirit_core", 1, 1, 0.05))
	out.append(spirit)
	return out


## Spawn tables (what spawns where, how often). Enemies are loaded from data/enemies.
func _spawns() -> Array[SpawnTable]:
	var out: Array[SpawnTable] = []
	var forest := SpawnTable.new()
	forest.id = &"forest_surface"
	forest.display_name = "Forest surface"
	forest.biome = &"forest"
	forest.layer = SpawnTable.Layer.SURFACE
	forest.day_seconds = 10.0
	forest.night_seconds = 6.0
	forest.max_day = 5
	forest.max_night = 6
	forest.entries.append(SpawnEntry.make(load(ENEMY_DIR + "/green_slime.tres") as EnemyData, 100.0))
	forest.max_depth_tiles = 20
	# Blue Slimes only once a Green Slime has been slain in this world.
	var after_green: Array[SpawnCondition] = [KillCountCondition.make(&"green_slime", 1)]
	forest.entries.append(SpawnEntry.make(load(ENEMY_DIR + "/blue_slime.tres") as EnemyData, 12.0, true, true, after_green))
	out.append(forest)
	# The Dark Forest: Forest Spirits day and night, and a few slimes.
	var dark := SpawnTable.new()
	dark.id = &"dark_forest_surface"
	dark.display_name = "Dark Forest surface"
	dark.biome = &"dark_forest"
	dark.layer = SpawnTable.Layer.SURFACE
	dark.day_seconds = 9.0
	dark.night_seconds = 6.0
	dark.max_day = 5
	dark.max_night = 7
	dark.max_depth_tiles = 20
	dark.entries.append(SpawnEntry.make(load(ENEMY_DIR + "/forest_spirit.tres") as EnemyData, 70.0))
	dark.entries.append(SpawnEntry.make(load(ENEMY_DIR + "/green_slime.tres") as EnemyData, 30.0))
	out.append(dark)
	return out


## Things lying on the ground. Weights per kind of floor: surface grass, bare surface
## dirt or stone, cave floors (sticks only on surface grass). A stick gives Wood, a rock
## Stone.
func _forage() -> Array[ForageData]:
	var out: Array[ForageData] = []
	# [id, name, surface grass, surface ground, caves, item]
	for row: Array in [[&"stick", "Stick", 45.0, 0.0, 0.0, &"wood"], [&"rock", "Rock", 55.0, 100.0, 100.0, &"stone"],
			[&"field_mushroom", "Field Mushroom", 8.0, 0.0, 10.0, &"field_mushroom"],
			[&"red_cap", "Red Cap", 4.0, 0.0, 6.0, &"red_cap"],
			[&"duskcap", "Duskcap", 0.0, 0.0, 14.0, &"duskcap"],
			[&"glowcap", "Glowcap", 0.0, 0.0, 12.0, &"glowcap"]]:
		var f := ForageData.new()
		f.id = row[0]
		f.display_name = row[1]
		f.item = row[5]
		f.description = "Lying on the ground. Picking it up gives 1 %s." % ("Wood" if f.item == &"wood" else ("Stone" if f.item == &"stone" else row[1]))
		f.texture = load("res://assets/decor/pickup_%s.png" % row[0]) as Texture2D
		f.surface_grass_weight = row[2]
		f.surface_ground_weight = row[3]
		f.cave_weight = row[4]
		if f.id == &"glowcap":
			f.light_radius = 14.0
			f.light_color = Color(0.45, 0.95, 1.0)
		out.append(f)
	return out


## Berry bush kinds (data/bushes): [id, name, save index, fruit, worldgen weight, art].
func _bushes() -> Array[BushData]:
	var out: Array[BushData] = []
	for row: Array in [[&"berry_bush", "Berry Bush", 0, &"berries", 2.0, "berry_bush"],
			[&"raspberry_bush", "Raspberry Bush", 1, &"raspberries", 1.0, "raspberry_bush"],
			[&"blueberry_bush", "Blueberry Bush", 2, &"blueberries", 1.0, "blueberry_bush"]]:
		var b := BushData.new()
		b.id = row[0]
		b.display_name = row[1]
		b.description = "A wild bush. Ripe ones give %s." % String(row[3]).capitalize()
		b.save_index = row[2]
		b.fruit = row[3]
		b.weight = row[4]
		b.young_texture = load("res://assets/decor/%s_young.png" % row[5]) as Texture2D
		b.ripe_texture = load("res://assets/decor/%s.png" % row[5]) as Texture2D
		b.bare_texture = load("res://assets/decor/%s_bare.png" % row[5]) as Texture2D
		out.append(b)
	return out


## Recipes: [id, station, {inputs}, output, count, requires]. Station &"" = by hand.
func _recipes() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	var table: Array = [
		# By hand.
		[&"hand_hammer", &"", {&"stone": 1, &"wood": 1}, &"hand_hammer", 1, []],
		[&"stone_pickaxe", &"", {&"stone": 3, &"wood": 2}, &"stone_pickaxe", 1, []],
		[&"stone_axe", &"", {&"stone": 3, &"wood": 2}, &"stone_axe", 1, []],
		[&"wood", &"", {&"log": 1}, &"wood", 4, []],
		[&"darkwood", &"", {&"dark_log": 1}, &"darkwood", 4, []],
		[&"wood_platform", &"", {&"wood": 1}, &"wood_platform", 2, []],
		[&"campfire", &"", {&"wood": 5, &"stone": 3}, &"campfire", 1, []],
		# Food & Alchemy.
		[&"clay_flask", &"furnace", {&"clay": 2}, &"clay_flask", 1, []],
		[&"wooden_bowl", &"workbench", {&"wood": 2}, &"wooden_bowl", 2, []],
		[&"alchemy_table", &"workbench", {&"wood": 12, &"copper_bar": 3, &"clay_flask": 2}, &"alchemy_table", 1, []],
		[&"table", &"workbench", {&"wood": 8}, &"table", 1, []],
		[&"shelf", &"workbench", {&"wood": 4}, &"shelf", 1, []],
		[&"roasted_berries", &"cooking", {&"berries": 3}, &"roasted_berries", 1, []],
		[&"cooked_mushroom", &"cooking", {&"field_mushroom": 1}, &"cooked_mushroom", 1, []],
		[&"raspberry_compote", &"cooking", {&"raspberries": 4, &"wooden_bowl": 1}, &"raspberry_compote", 1, []],
		[&"blueberry_mash", &"cooking", {&"blueberries": 4, &"wooden_bowl": 1}, &"blueberry_mash", 1, []],
		[&"mushroom_stew", &"cooking", {&"field_mushroom": 2, &"red_cap": 1, &"wooden_bowl": 1}, &"mushroom_stew", 1, []],
		[&"healing_potion", &"alchemy", {&"clay_flask": 1, &"red_cap": 2}, &"healing_potion", 1, []],
		[&"mana_potion", &"alchemy", {&"clay_flask": 1, &"glowcap": 2}, &"mana_potion", 1, []],
		[&"poison_coating", &"alchemy", {&"clay_flask": 1, &"duskcap": 2}, &"poison_coating", 1, []],
		[&"poison_flask", &"alchemy", {&"clay_flask": 1, &"duskcap": 1, &"slime": 1}, &"poison_flask", 2, []],
		[&"workbench", &"", {&"wood": 10}, &"workbench", 1, [&"hand_hammer"]],
		# Workbench.
		[&"chest", &"workbench", {&"wood": 8, &"copper_bar": 2}, &"chest", 1, []],
		[&"door", &"workbench", {&"wood": 6}, &"door", 1, []],
		[&"furnace", &"workbench", {&"stone": 20, &"wood": 4, &"torch": 3}, &"furnace", 1, []],
		[&"copper_anvil", &"workbench", {&"copper_bar": 6}, &"copper_anvil", 1, []],
		# Furnace.
		[&"copper_bar", &"furnace", {&"copper_ore": 3}, &"copper_bar", 1, []],
		# Anvil.
		[&"copper_pickaxe", &"anvil", {&"copper_bar": 10, &"wood": 3}, &"copper_pickaxe", 1, []],
		[&"copper_axe", &"anvil", {&"copper_bar": 8, &"wood": 3}, &"copper_axe", 1, []],
		# Phase 7: combat and beds.
		[&"torch_from_slime", &"", {&"slime": 1, &"wood": 1}, &"torch", 5, []],
		[&"wooden_sword", &"workbench", {&"wood": 10}, &"wooden_sword", 1, []],
		[&"bed", &"workbench", {&"wood": 20}, &"bed", 1, []],
		[&"copper_sword", &"anvil", {&"copper_bar": 8, &"wood": 2}, &"copper_sword", 1, []],
		[&"copper_helmet", &"anvil", {&"copper_bar": 10}, &"copper_helmet", 1, []],
		[&"copper_chestplate", &"anvil", {&"copper_bar": 16}, &"copper_chestplate", 1, []],
		[&"copper_greaves", &"anvil", {&"copper_bar": 12}, &"copper_greaves", 1, []],
		[&"iron_bar", &"furnace", {&"iron_ore": 3}, &"iron_bar", 1, []],
		[&"iron_pickaxe", &"anvil", {&"iron_bar": 12, &"wood": 3}, &"iron_pickaxe", 1, []],
		[&"iron_axe", &"anvil", {&"iron_bar": 10, &"wood": 3}, &"iron_axe", 1, []],
		[&"iron_sword", &"anvil", {&"iron_bar": 10, &"wood": 2}, &"iron_sword", 1, []],
		[&"iron_helmet", &"anvil", {&"iron_bar": 12}, &"iron_helmet", 1, []],
		[&"iron_chestplate", &"anvil", {&"iron_bar": 20}, &"iron_chestplate", 1, []],
		[&"iron_greaves", &"anvil", {&"iron_bar": 15}, &"iron_greaves", 1, []],
		# Spell scrolls (placeholder chain, will change).
		[&"paper", &"workbench", {&"wood": 1}, &"paper", 3, []],
		[&"blank_scroll", &"workbench", {&"paper": 3, &"slime": 1}, &"blank_scroll", 1, []],
		[&"spell_weaving_table", &"workbench", {&"wood": 20, &"copper_bar": 5, &"paper": 4}, &"spell_weaving_table", 1, []],
		[&"scribes_desk", &"workbench", {&"wood": 15, &"paper": 5, &"copper_bar": 2}, &"scribes_desk", 1, []],
		[&"lumber_rack", &"workbench", {&"wood": 25, &"log": 4}, &"lumber_rack", 1, []],
		[&"potion_cabinet", &"workbench", {&"wood": 20, &"copper_bar": 2, &"clay_flask": 2}, &"potion_cabinet", 1, []],
	]
	# One scroll per spell at the Spell Weaving Table: a Blank Scroll plus copper bars by
	# tier (placeholder until each spell gets its own materials). Only spells you know can
	# be scribed (Crafting.scroll_recipes).
	for sp in _spells():
		var spell := sp as SpellData
		var cost: Dictionary = SCROLL_COSTS.get(spell.id,
			{&"blank_scroll": 1, &"copper_bar": SCROLL_BARS[clampi(spell.tier, 1, 3) - 1]})
		table.append([StringName("scroll_" + String(spell.id)), &"scribing", cost,
			StringName("scroll_" + String(spell.id)), 1, []])

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
		r.tab = {&"poison_coating": "Coatings", &"poison_flask": "Flasks"}.get(r.id, "Potions" if r.station == &"alchemy" else "")
		out.append(r)
	return out


## Copper bars a spell scroll costs, by tier (1, 2, 3).
const SCROLL_BARS: Array[int] = [2, 5, 10]
## Copper bars learning a spell from its scroll costs, by tier; and exceptions.
const LEARN_BARS: Array[int] = [4, 10, 20]
const LEARN_COSTS := {&"gel_cushion": {&"slime": 20}}
## Scrolls that cost something else instead.
const SCROLL_COSTS := {&"gel_cushion": {&"blank_scroll": 1, &"slime": 20}}


## Paper, the Blank Scroll, a scroll for every spell (left click casts it once) and a
## Spell Page for every spell (left click learns it; found, not crafted).
func _scrolls() -> Array[ItemData]:
	var out: Array[ItemData] = []
	out.append(_small(&"paper", "Paper", "Made from wood. Used for scrolls and the Spell Weaving Table."))
	out.append(_small(&"blank_scroll", "Blank Scroll", "Write a spell on it at the Spell Weaving Table."))
	for sp in _spells():
		var spell := sp as SpellData
		var scroll := _small(StringName("scroll_" + String(spell.id)), "Scroll: %s" % spell.display_name,
			"One use. Left click: cast %s once for free, at base power." % spell.display_name)
		scroll.kind = ItemData.Kind.SCROLL
		scroll.teaches_spell = spell.id
		scroll.max_stack = 20
		out.append(scroll)
		var page := _small(StringName("page_" + String(spell.id)), "Spell Page: %s" % spell.display_name,
			"A found page of spellcraft. Left click: learn %s for good (the page is used up)." % spell.display_name)
		page.kind = ItemData.Kind.PAGE
		page.learns_spell = spell.id
		page.max_stack = 20
		out.append(page)
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


## Which special storage takes an item (Lumber Rack, Potion Cabinet).
const STORAGE_TAGS := {&"log": &"lumber", &"wood": &"lumber", &"dark_log": &"lumber", &"darkwood": &"lumber", &"healing_potion": &"potion",
	&"mana_potion": &"potion", &"poison_coating": &"potion", &"poison_flask": &"potion", &"clay_flask": &"potion"}


## How potions look in a Potion Cabinet.
const SHELF_COLORS := {&"healing_potion": Color(0.86, 0.27, 0.27), &"mana_potion": Color(0.3, 0.5, 0.95),
	&"poison_coating": Color(0.45, 0.8, 0.32), &"poison_flask": Color(0.45, 0.8, 0.32), &"clay_flask": Color(0.66, 0.46, 0.32)}


func _base(item_id: StringName, label: String, text: String) -> ItemData:
	var item := ItemData.new()
	item.id = item_id
	item.display_name = label
	item.description = text
	item.icon = load("res://assets/items/icons/%s.png" % item_id) as Texture2D
	if STORAGE_TAGS.has(item_id):
		item.storage_tags.assign([STORAGE_TAGS[item_id]])
	if SHELF_COLORS.has(item_id):
		item.shelf_color = SHELF_COLORS[item_id]
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


## The 32x32 flask art (detail 2): held by the body, with an inventory badge.
func _detailed(item: ItemData, badge: StringName) -> void:
	item.held.detail = 2
	item.held.grip = Vector2(12, 22)
	item.drop_size = 16  # same size on the ground as in the hand
	if badge != &"":
		item.badge = load("res://assets/items/badges/%s.png" % badge) as Texture2D


func _small(item_id: StringName, label: String, text: String) -> ItemData:
	var item := _base(item_id, label, text)
	item.impact_at = 0.2
	item.held = _look(item_id, &"block", Vector2(4, 6))
	return item


func _weapon(item_id: StringName, label: String, text: String) -> ItemData:
	var item := _base(item_id, label, text)
	item.kind = ItemData.Kind.WEAPON
	item.max_stack = 1
	item.held = _look(item_id, &"sword", Vector2(2, 13))
	return item


func _tool(item_id: StringName, label: String, text: String, type_id: StringName) -> ItemData:
	var item := _base(item_id, label, text)
	item.kind = ItemData.Kind.TOOL
	item.max_stack = 1
	item.held = _look(item_id, type_id, Vector2(3, 12))
	return item
