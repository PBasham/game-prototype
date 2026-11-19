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
	out.append(_block(&"copper_ore", "Copper Ore", "Smelts into copper (crafting comes later)."))
	# Wood is the building block too (like Terraria): it places the plank block.
	var wood := _block(&"wood", "Wood", "From trees and sticks. A building block (right click places it as a back wall), and the wood in tools, torches and furniture.", &"wood_wall")
	wood.places_block = &"wood_planks"
	wood.icon = load("res://assets/items/icons/wood_planks.png") as Texture2D
	wood.held = _look(&"wood_planks", &"block", Vector2(3, 5))
	out.append(wood)
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
	var berries := _small(&"berries", "Berries", "Picked from berry bushes. Left click to eat: +10 hunger, +2 health.")
	berries.kind = ItemData.Kind.FOOD
	berries.food_value = 10.0
	berries.heal_value = 2.0
	out.append(berries)
	var hammer := _small(&"hand_hammer", "Hand Hammer", "Needed in your inventory to build a Workbench.")
	hammer.max_stack = 1
	out.append(hammer)
	# Furniture (crafting stations, storage, doors).
	for f: Array in [[&"workbench", "Workbench", "A crafting station: furniture, tools and the next stations."],
			[&"furnace", "Furnace", "A crafting station: smelts ore into bars."],
			[&"copper_anvil", "Copper Anvil", "A crafting station: copper tools."],
			[&"chest", "Chest", "Stores 40 stacks. Right click or E to open."],
			[&"door", "Door", "Right click or E to open and close."],
			[&"spell_weaving_table", "Spell Weaving Table", "A crafting station: writes spells onto blank scrolls."]]:
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
	pick.mining_area = 2
	pick.reach_tiles = 10.0
	out.append(pick)
	var axe := _tool(&"copper_axe", "Copper Axe", "Chops trees.", &"tool")
	axe.axe_damage = 25.0
	out.append(axe)
	var stone_pick := _tool(&"stone_pickaxe", "Stone Pickaxe", "A stone pickaxe. Mines a 2x2 area per swing (Ctrl + wheel: 1x1).", &"tool")
	stone_pick.mining_damage = 15.0
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
	for a: Array in [[&"copper_helmet", "Copper Helmet", &"head", 1], [&"copper_chestplate", "Copper Chestplate", &"chest", 2],
			[&"copper_greaves", "Copper Greaves", &"legs", 1]]:
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
	drill.mining_area = 11  # 5 tiles each way from the center
	drill.mining_round = true
	drill.reach_tiles = 24.0
	drill.mana_per_second = 30.0
	drill.tier = 3
	drill.projectile_color = Color(1.0, 0.55, 0.3)
	out.append(drill)

	var push := _spell(&"air_push", "Air Push", "A gust toward the cursor that shoves enemies away. In the air, it pushes you back too.")
	push.cast = SpellData.Cast.GUST
	push.damage = 2.0
	push.gust_tiles = 8.0
	push.gust_angle = 35.0
	push.gust_push = 24.0
	push.gust_recoil = 12.0
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
	orb.light_radius = 10.0
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
	wisp.light_radius = 9.0
	wisp.light_color = Color(0.75, 0.9, 1.0)
	wisp.duration = 300.0
	wisp.mana_cost = 12.0
	wisp.cooldown = 0.5
	wisp.impact_at = 0.2
	out.append(wisp)

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

	var chain := _spell(&"chain_spark", "Chain Spark", "Lightning hits the enemy nearest the cursor, then jumps to up to 3 more nearby, weaker each jump.")
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
			[&"door", "Door", 1, 8, &""], [&"spell_weaving_table", "Spell Weaving Table", 6, 3, &"spell_weaving"]]:
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
	return out


## Things lying on the ground. Weights per kind of floor: surface grass, bare surface
## dirt or stone, cave floors (sticks only on surface grass). A stick gives Wood, a rock
## Stone.
func _forage() -> Array[ForageData]:
	var out: Array[ForageData] = []
	for row: Array in [[&"stick", "Stick", 45.0, 0.0, 0.0], [&"rock", "Rock", 55.0, 100.0, 100.0]]:
		var f := ForageData.new()
		f.id = row[0]
		f.display_name = row[1]
		f.item = &"stone" if row[0] == &"rock" else &"wood"
		f.description = "A %s on the ground. Picking it up gives 1 %s." % [String(row[1]).to_lower(), "Stone" if f.item == &"stone" else "Wood"]
		f.texture = load("res://assets/decor/pickup_%s.png" % row[0]) as Texture2D
		f.surface_grass_weight = row[2]
		f.surface_ground_weight = row[3]
		f.cave_weight = row[4]
		out.append(f)
	return out


## Recipes: [id, station, {inputs}, output, count, requires]. Station &"" = by hand.
func _recipes() -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	var table: Array = [
		# By hand.
		[&"hand_hammer", &"", {&"stone": 1, &"wood": 1}, &"hand_hammer", 1, []],
		[&"stone_pickaxe", &"", {&"stone": 3, &"wood": 2}, &"stone_pickaxe", 1, []],
		[&"stone_axe", &"", {&"stone": 3, &"wood": 2}, &"stone_axe", 1, []],
		[&"wood_platform", &"", {&"wood": 1}, &"wood_platform", 2, []],
		[&"torch", &"", {&"wood": 2}, &"torch", 3, []],
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
		# Spell scrolls (placeholder chain, will change).
		[&"paper", &"workbench", {&"wood": 1}, &"paper", 3, []],
		[&"blank_scroll", &"workbench", {&"paper": 3, &"slime": 1}, &"blank_scroll", 1, []],
		[&"spell_weaving_table", &"workbench", {&"wood": 20, &"copper_bar": 5, &"paper": 4}, &"spell_weaving_table", 1, []],
	]
	# One scroll per spell at the Spell Weaving Table: a Blank Scroll plus copper bars by
	# tier (until scrolls come from loot). Known spells cost less, and the table's Copy tab
	# copies known spells for mana (Crafting.for_crafter, copy_recipes).
	for sp in _spells():
		var spell := sp as SpellData
		var cost: Dictionary = SCROLL_COSTS.get(spell.id,
			{&"blank_scroll": 1, &"copper_bar": SCROLL_BARS[clampi(spell.tier, 1, 3) - 1]})
		table.append([StringName("scroll_" + String(spell.id)), &"spell_weaving", cost,
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
		out.append(r)
	return out


## Copper bars a spell scroll costs, by tier (1, 2, 3).
const SCROLL_BARS: Array[int] = [2, 5, 10]
## Copper bars learning a spell from its scroll costs, by tier; and exceptions.
const LEARN_BARS: Array[int] = [4, 10, 20]
const LEARN_COSTS := {&"gel_cushion": {&"slime": 20}}
## Scrolls that cost something else instead.
const SCROLL_COSTS := {&"gel_cushion": {&"blank_scroll": 1, &"slime": 20}}


## Paper, the Blank Scroll, and a scroll for every spell (left click to learn it).
func _scrolls() -> Array[ItemData]:
	var out: Array[ItemData] = []
	out.append(_small(&"paper", "Paper", "Made from wood. Used for scrolls and the Spell Weaving Table."))
	out.append(_small(&"blank_scroll", "Blank Scroll", "Write a spell on it at the Spell Weaving Table."))
	for sp in _spells():
		var spell := sp as SpellData
		var scroll := _small(StringName("scroll_" + String(spell.id)), "Scroll: %s" % spell.display_name,
			"One use. Left click: cast %s once for free. Right click: learn it." % spell.display_name)
		scroll.kind = ItemData.Kind.SCROLL
		scroll.teaches_spell = spell.id
		scroll.max_stack = 20
		out.append(scroll)
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
