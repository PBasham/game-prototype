class_name CharacterData
extends RefCounted
## A character, saved separately from worlds: user://characters/<name>.gpchar.
## Holds the inventory, the equipment (spellbook and conduit slots), the spells the
## character knows and the spells put into the book, and its look (colors, hairstyle).
## The main menu's character select lists every saved character; any character can
## play any world.
##
## A new character starts with nothing: no items, no spells (they lost their memory).
## The dev kit (console `devkit`; also tests and scripted runs) gives tools, blocks,
## all spells and the dev test items.
##
## File: SaveHeader (kind "character"), then one store_var Dictionary.

## Equipment or spells changed (the held spell's look and strength may change).
signal magic_changed
## Something was equipped or taken off (stats may have changed).
signal equipment_changed
## A hidden recipe (or a spell to learn) showed up because you got one of its key
## items for the first time.
signal recipe_discovered(display_name: String)

const DEFAULT_NAME := "default"
## Used when the book slot is empty (data/items).
const DEFAULT_BOOK := &"basic_spellbook"
## Equipment slots and the item kind each accepts.
const SLOT_BOOK := &"book"
const SLOT_CONDUIT := &"conduit"
const SLOT_HEAD := &"head"
const SLOT_CHEST := &"chest"
const SLOT_LEGS := &"legs"
const SLOT_ACCESSORIES: Array[StringName] = [&"accessory_1", &"accessory_2", &"accessory_3"]
## Every equipment slot, in panel order: armor, accessories, magic.
const ALL_SLOTS: Array[StringName] = [&"head", &"chest", &"legs", &"accessory_1", &"accessory_2",
	&"accessory_3", &"book", &"conduit"]
## Stat names items can raise (ItemData.stats).
const STATS: Array[StringName] = [&"max_health", &"max_mana", &"mana_regen", &"move_speed", &"jump",
	&"melee_damage", &"magic_damage", &"mining_speed", &"summon_slots", &"summon_damage"]
## Hairstyles are the .png files in this folder (Patrick draws more later).
const HAIR_DIR := "res://assets/sprites/hair"
const DEFAULT_HAIR := &"short"

## [item id, count] in the dev kit. Hotbar order.
const DEV_KIT: Array = [
	[&"copper_pickaxe", 1], [&"copper_axe", 1], [&"iron_pickaxe", 1], [&"wood", 99],
	[&"wood_platform", 30], [&"rope", 30], [&"torch", 20], [&"tree_seed", 5], [&"grass_seeds", 10],
	[&"dirt", 50],
]
## More dev kit items, added after the debug placeholders (so they fill later rows).
const DEV_KIT_EXTRA: Array = [
	[&"copper_sword", 1], [&"wooden_sword", 1], [&"copper_helmet", 1], [&"copper_chestplate", 1],
	[&"copper_greaves", 1], [&"bed", 1], [&"berries", 10],
]
## Spells the dev kit teaches (in order); give_dev_kit also fills the quick slots.
const DEV_SPELLS: Array[StringName] = [&"mining_spell", &"chopping_spell", &"fly", &"spark", &"levitate",
	&"hyper_drill", &"air_push", &"blink", &"light_orb", &"wisp", &"mend", &"gel_cushion",
	&"arcane_bolt", &"healing_circle", &"spark_ward", &"familiar", &"conjure_platform", &"arcane_edge", &"barrier",
	&"chain_spark", &"recall", &"seek_ore"]

const WHEELS: Array[StringName] = [&"q", &"e"]
const WHEEL_SIZE := 8
const QUICK_KEYS: Array[StringName] = [&"z", &"x", &"c"]
const BUFF_SET_SIZE := 6

func _init() -> void:
	_watch_inventory()


func _watch_inventory() -> void:
	if inventory and not inventory.changed.is_connected(note_inventory):
		inventory.changed.connect(note_inventory)


## Marks everything in the inventory as seen; new key items reveal their recipes.
func note_inventory() -> void:
	var fresh: Array[StringName] = []
	for id in inventory.ids:
		if id != &"" and not seen_items.has(id):
			seen_items[id] = true
			fresh.append(id)
	if fresh.is_empty():
		return
	for name_ in Crafting.revealed_by(fresh, self):
		recipe_discovered.emit(name_)


## The rank of an Empower node on a spell (0 = none).
func empower_rank(spell_id: StringName, node_id: StringName) -> int:
	return int(empower.get(spell_id, {}).get(node_id, 0))


## What a spell's mana costs are multiplied by (Efficient: 5% less per rank).
func mana_mult(spell_id: StringName) -> float:
	var ranks: Dictionary = empower.get(spell_id, {})
	var m := 1.0
	for node_id: StringName in ranks:
		var n := Registry.get_def(&"empower", node_id) as EmpowerNode
		if n and n.stat == EmpowerNode.Stat.MANA_COST:
			m += n.per_rank * int(ranks[node_id])
	return maxf(m, 0.1)


## Why the next rank of `node` on `spell` can't be bought ("" = it can).
func empower_problem(spell: SpellData, node: EmpowerNode) -> String:
	if not knows(spell.id):
		return "You don't know this spell"
	var rank := empower_rank(spell.id, node.id)
	if rank >= node.max_rank:
		return "Fully empowered"
	if node.requires != &"" and empower_rank(spell.id, node.requires) <= 0:
		return "Needs the node before it"
	var cost := node.cost_for(rank)
	for id in cost:
		if inventory.count_of(id) < cost[id]:
			var it := ItemData.find(id)
			return "Needs %d %s" % [cost[id], it.display_name if it else String(id)]
	return ""


## Buys the next rank (paying from the inventory). False if it can't.
func buy_empower(spell: SpellData, node: EmpowerNode) -> bool:
	if empower_problem(spell, node) != "":
		return false
	var rank := empower_rank(spell.id, node.id)
	var cost := node.cost_for(rank)
	for id in cost:
		inventory.remove(id, cost[id])
	if not empower.has(spell.id):
		empower[spell.id] = {}
	empower[spell.id][node.id] = rank + 1
	return true


## True when a recipe's key items (if it has any) have been seen.
func unlocked(unlock_items: Array[StringName]) -> bool:
	if unlock_items.is_empty():
		return true
	for id in unlock_items:
		if seen_items.has(id):
			return true
	return false


## The movement spell the movement key (F) uses, set in the Equipment window's Movement
## slot (empty = Fly if known, else Levitate).
var movement_spell: StringName = &""
## The trash slot (like Terraria's): the last item thrown away, until another replaces it.
var trash := Inventory.new(1)

## Empower ranks: spell id -> {node id -> rank} (Spell Weaving Table, Empower tab).
var empower: Dictionary[StringName, Dictionary] = {}

## Every item this character has ever had in the inventory (id -> true). Hidden recipes
## (`RecipeData.unlock_items`, `SpellData.learn_unlock_items`) show up once one of their
## key items is in here.
var seen_items: Dictionary[StringName, bool] = {}
## The Catalog: enemies this character has slain (id -> how many), and what each has
## been seen to drop (id -> {item id: true}). Saved.
var slain: Dictionary[StringName, int] = {}
var seen_drops: Dictionary[StringName, Dictionary] = {}

var name := DEFAULT_NAME
var inventory := Inventory.new():
	set(value):
		inventory = value
		_watch_inventory()
## Appearance: palette group (skin, hair, tunic, trim, pants, leather) -> the color its
## middle shade becomes. Missing groups keep the art's colors.
var colors: Dictionary[StringName, Color] = {}
## Hairstyle: a file name in HAIR_DIR (without .png), &"" = bald.
var hairstyle: StringName = DEFAULT_HAIR
## Health and hunger when last saved (-1 = full).
var health := -1.0
var hunger := -1.0
## Equipment slot -> item id (empty = nothing).
## Died in a permadeath world: a ghost, kept but no longer playable.
var ghost := false
var equipment: Dictionary[StringName, StringName] = {
	&"head": &"", &"chest": &"", &"legs": &"", &"accessory_1": &"", &"accessory_2": &"",
	&"accessory_3": &"", &"book": &"", &"conduit": &"",
}
## Spells learned (data/spells ids).
var known_spells: Array[StringName] = []
## Quick spells (see docs/items-and-mining.md, "Quick spells"): slot name to spell id.
## Slots: the Q and E wheels ("q_0".."q_7", "e_0".."e_7"), the Z, X and C keys ("z",
## "x", "c") and the buff set cast by B ("buff_0".."buff_5").
var quick: Dictionary[StringName, StringName] = {}
## Per slot: true = cast right away, false = put it in your hand. A slot that isn't
## here uses the spell's default (SpellData.casts_from_quick_slot). The buff set always casts.
var quick_modes: Dictionary[StringName, bool] = {}
## The slot last picked on each wheel (&"q", &"e"): tapping the key uses it again.
var wheel_last: Dictionary[StringName, StringName] = {}
## Not saved (dev runs and tests use a throwaway character).
var temporary := false


## A new character: empty inventory, no spells.
static func create(char_name: String) -> CharacterData:
	var c := CharacterData.new()
	c.name = char_name
	c.give_catalog()  # everyone starts with the Catalog (J)
	return c


## The Catalog goes in the backpack's last slot, out of the hotbar's way (any free slot if
## that one is taken).
func give_catalog() -> void:
	if ItemData.find(&"catalog") == null or inventory.count_of(&"catalog") > 0:
		return
	var last := inventory.size - 1
	if inventory.item(last) == null:
		inventory.set_slot(last, &"catalog", 1)
	else:
		inventory.add(&"catalog", 1)
	note_inventory()


## A character with the dev kit (tests, scripted runs).
static func create_dev(char_name: String) -> CharacterData:
	var c := create(char_name)
	c.give_dev_kit()
	return c


## The dev kit: tools, blocks, torches, all spells (in the book), and in debug builds
## the dev test items.
func give_dev_kit() -> void:
	for e: Array in DEV_KIT:
		inventory.add(e[0], e[1])
	for s in DEV_SPELLS:
		learn_spell(s)
	# A starting loadout to try things with.
	var q: Array[StringName] = [&"spark", &"arcane_bolt", &"chain_spark", &"air_push", &"familiar",
		&"spark_ward", &"healing_circle", &"wisp"]
	var ew: Array[StringName] = [&"blink", &"conjure_platform", &"light_orb", &"seek_ore", &"recall",
		&"mend", &"hyper_drill", &"levitate"]
	for i in WHEEL_SIZE:
		set_quick(wheel_slot(&"q", i), q[i])
		set_quick(wheel_slot(&"e", i), ew[i])
	set_quick(&"z", &"blink")
	set_quick(&"x", &"air_push")
	set_quick(&"c", &"light_orb")
	var buffs_in: Array[StringName] = [&"arcane_edge", &"barrier", &"gel_cushion"]
	for i in buffs_in.size():
		set_quick(buff_slot(i), buffs_in[i])
	if OS.is_debug_build():
		DevHeldItems.add_to(inventory)
		DevMagic.add_to(self)
	for e: Array in DEV_KIT_EXTRA:
		inventory.add(e[0], e[1])


# --- looks -----------------------------------------------------------------------------

## The look for the paper doll (colors and hairstyle).
func make_look() -> CharacterLook:
	var look := CharacterLook.new()
	look.colors = colors.duplicate()
	look.hair = hair_texture(hairstyle)
	return look


static func hair_texture(style: StringName) -> Texture2D:
	if style == &"":
		return null
	var path := HAIR_DIR.path_join(String(style) + ".png")
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Hairstyle ids, sorted ("short", ...).
static func hairstyles() -> Array[StringName]:
	var out: Array[StringName] = []
	for f in ResourceLoader.list_directory(HAIR_DIR):
		if f.ends_with(".png"):
			out.append(StringName(f.get_basename()))
	out.sort()
	return out


# --- magic -----------------------------------------------------------------------------

## The equipped spellbook, or the basic one when the slot is empty.
func book() -> ItemData:
	var b := ItemData.find(equipment[SLOT_BOOK]) if equipment[SLOT_BOOK] != &"" else null
	return b if b else ItemData.find(DEFAULT_BOOK)


func conduit() -> ItemData:
	return ItemData.find(equipment[SLOT_CONDUIT]) if equipment[SLOT_CONDUIT] != &"" else null


func knows(spell_id: StringName) -> bool:
	return spell_id in known_spells


# --- quick spells ------------------------------------------------------------------------

static func wheel_slot(wheel: StringName, i: int) -> StringName:
	return StringName("%s_%d" % [wheel, i])


static func buff_slot(i: int) -> StringName:
	return StringName("buff_%d" % i)


static func is_buff_slot(slot: StringName) -> bool:
	return String(slot).begins_with("buff_")


## Which group a slot belongs to (&"q", &"e", &"keys", &"buff"): a spell moves within
## its group instead of being in it twice.
static func slot_group(slot: StringName) -> StringName:
	var text := String(slot)
	if text.begins_with("buff_"):
		return &"buff"
	if slot in QUICK_KEYS:
		return &"keys"
	return StringName(text.get_slice("_", 0))


## Every quick slot name, in order: the Q wheel, the E wheel, Z X C, the buff set.
static func all_quick_slots() -> Array[StringName]:
	var out: Array[StringName] = []
	for w in WHEELS:
		for i in WHEEL_SIZE:
			out.append(wheel_slot(w, i))
	out.append_array(QUICK_KEYS)
	for i in BUFF_SET_SIZE:
		out.append(buff_slot(i))
	return out


## Sets the movement spell (the Movement slot; &"" = default: Fly, else Levitate).
func set_movement_spell(spell_id: StringName) -> bool:
	if spell_id != &"":
		var spell := ItemData.find(ItemData.spell_key(spell_id)) as SpellData
		if spell == null or not knows(spell_id) or not spell.fits_movement_slot():
			return false
	movement_spell = spell_id
	magic_changed.emit()
	return true


## Z X C can also hold a shortcut to an item (stored as "item:<id>").
const ITEM_SHORTCUT := "item:"


## The spell in a quick slot (&"" when empty or an item shortcut).
func quick_spell(slot: StringName) -> StringName:
	var v: StringName = quick.get(slot, &"")
	return &"" if String(v).begins_with(ITEM_SHORTCUT) else v


## The item a Z X C slot is a shortcut to (&"" when empty or a spell).
func quick_item(slot: StringName) -> StringName:
	var v := String(quick.get(slot, &""))
	return StringName(v.trim_prefix(ITEM_SHORTCUT)) if v.begins_with(ITEM_SHORTCUT) else &""


## Makes Z, X or C a shortcut to an item in your inventory (any item: food is eaten,
## a block or tool goes in your hand). Only the Z X C keys take items. False if refused.
func set_quick_item(slot: StringName, item_id: StringName) -> bool:
	var item := ItemData.find(item_id)
	if not slot in QUICK_KEYS or item == null or item.is_spell():
		return false
	var v := StringName(ITEM_SHORTCUT + String(item_id))
	for other: StringName in QUICK_KEYS:
		if other != slot and quick.get(other, &"") == v:
			quick.erase(other)
	quick_modes.erase(slot)
	quick[slot] = v
	magic_changed.emit()
	return true


## Puts a known spell in a quick slot (&"" empties it). If it's already in another slot
## of the same group it moves. The buff set only takes timed effects on you
## (SpellData.fits_buff_set). False if refused.
func set_quick(slot: StringName, spell_id: StringName) -> bool:
	if spell_id == &"":
		quick.erase(slot)
		quick_modes.erase(slot)
		magic_changed.emit()
		return true
	var spell := ItemData.find(ItemData.spell_key(spell_id)) as SpellData
	if spell == null or not knows(spell_id):
		return false
	if is_buff_slot(slot) and not spell.fits_buff_set():
		return false
	var group := slot_group(slot)
	for other: StringName in quick.keys():
		if other != slot and quick[other] == spell_id and slot_group(other) == group:
			quick.erase(other)
			quick_modes.erase(other)
	if quick.get(slot, &"") != spell_id:
		quick_modes.erase(slot)
	quick[slot] = spell_id
	magic_changed.emit()
	return true


## True: the slot casts its spell right away. False: it puts the spell in your hand.
func quick_casts(slot: StringName) -> bool:
	if is_buff_slot(slot):
		return true
	if quick_modes.has(slot):
		return quick_modes[slot]
	var spell := ItemData.find(ItemData.spell_key(quick_spell(slot))) as SpellData
	return spell.casts_from_quick_slot() if spell else false


func toggle_quick_mode(slot: StringName) -> void:
	if is_buff_slot(slot) or quick_spell(slot) == &"":
		return
	quick_modes[slot] = not quick_casts(slot)
	magic_changed.emit()


## The filled slots of a wheel (&"q" or &"e"), in order.
func wheel(w: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for i in WHEEL_SIZE:
		var slot := wheel_slot(w, i)
		if quick_spell(slot) != &"":
			out.append(slot)
	return out


## The spells in the buff set, in order.
func buff_set() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in BUFF_SET_SIZE:
		var id := quick_spell(buff_slot(i))
		if id != &"":
			out.append(id)
	return out


## Whether a spell is in any quick slot.
func in_quick(spell_id: StringName) -> bool:
	return spell_id != &"" and spell_id in quick.values()


func learn_spell(spell_id: StringName) -> void:
	if not knows(spell_id):
		known_spells.append(spell_id)
		magic_changed.emit()


## The highest spell tier the equipped book can hold.
func max_spell_tier() -> int:
	var b := book()
	return b.max_spell_tier if b else 1


## Equips an item (or &"" to empty the slot). Returns the item id that was there.
func equip(slot: StringName, item_id: StringName) -> StringName:
	var old: StringName = equipment.get(slot, &"")
	equipment[slot] = item_id
	magic_changed.emit()
	equipment_changed.emit()
	return old


## Total defense of everything equipped.
func defense() -> int:
	var d := 0
	for slot in equipment:
		var it := ItemData.find(equipment[slot]) if equipment[slot] != &"" else null
		if it:
			d += it.defense
	return d


## Sum of every equipped item's stat bonuses: name -> amount (STATS).
func equipment_stats() -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	for slot in equipment:
		var it := ItemData.find(equipment[slot]) if equipment[slot] != &"" else null
		if it == null:
			continue
		for k: StringName in it.stats:
			out[k] = out.get(k, 0.0) + it.stats[k]
	return out


## Equipped armor and accessories with a look on the character (legs, chest, head,
## then accessories), for PaperDoll.wear.
func worn_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for slot: StringName in [SLOT_LEGS, SLOT_CHEST, SLOT_HEAD] + SLOT_ACCESSORIES:
		var id: StringName = equipment.get(slot, &"")
		var it := ItemData.find(id) if id != &"" else null
		if it and not it.wear.is_empty():
			out.append(it)
	return out


## Whether an item can go in an equipment slot.
static func fits(slot: StringName, item: ItemData) -> bool:
	if item == null:
		return false
	match slot:
		SLOT_BOOK:
			return item.kind == ItemData.Kind.BOOK
		SLOT_CONDUIT:
			return item.kind == ItemData.Kind.CONDUIT
		SLOT_HEAD, SLOT_CHEST, SLOT_LEGS:
			return item.kind == ItemData.Kind.ARMOR and item.equip_slot == slot
	if slot in SLOT_ACCESSORIES:
		return item.kind == ItemData.Kind.ACCESSORY
	return false


## Why an item can't go in this slot ("" = it can): it doesn't fit, or it's an
## accessory you're already wearing in another slot (one of each, like Terraria).
func equip_problem(slot: StringName, item: ItemData) -> String:
	if not fits(slot, item):
		return "That doesn't go there"
	if slot in SLOT_ACCESSORIES:
		for other in SLOT_ACCESSORIES:
			if other != slot and equipment.get(other, &"") == item.id:
				return "You're already wearing %s" % item.display_name
	return ""


## Why a spell can't be cast right now ("" = it can). `from_tome` skips the book check.
func cast_problem(spell: SpellData, from_tome: bool = false) -> String:
	if spell == null:
		return "Unknown spell"
	if not from_tome and not knows(spell.id):
		return "You don't know this spell"
	if not from_tome and spell.tier > max_spell_tier():
		return "Too powerful for your spellbook (tier %d)" % spell.tier
	if spell.requires_conduit != &"":
		var c := conduit()
		if c == null or c.conduit_type != spell.requires_conduit:
			return "Needs a %s conduit" % String(spell.requires_conduit)
	for id: StringName in spell.reagents:
		if inventory.count_of(id) < spell.reagents[id]:
			var item := ItemData.find(id)
			return "Needs %d %s" % [spell.reagents[id], item.display_name if item else String(id)]
	return ""


## Uses up a spell's reagents from the inventory. False (nothing taken) if any are short.
func take_reagents(spell: SpellData) -> bool:
	for id: StringName in spell.reagents:
		if inventory.count_of(id) < spell.reagents[id]:
			return false
	for id: StringName in spell.reagents:
		inventory.remove(id, spell.reagents[id])
	return true


## Spell strength multiplier from the book (or the tome) and the conduit. The book
## powers every spell you cast.
func spell_power(tome: ItemData = null) -> float:
	var source := tome if tome else book()
	var p := source.spell_power if source else 1.0
	var c := conduit()
	return p * (c.spell_power if c else 1.0)


func spell_reach_bonus() -> float:
	var c := conduit()
	return c.spell_reach_bonus if c else 0.0


# --- files -----------------------------------------------------------------------------

## Every saved character, sorted by name.
static func list_saved() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for file_name in SaveManager.list_characters():
		var c := load_file(SaveManager.character_path(file_name))
		if c:
			out.append(c)
	out.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	return out


static func exists(char_name: String) -> bool:
	return FileAccess.file_exists(SaveManager.character_path(char_name))


static func delete(char_name: String) -> Error:
	return DirAccess.remove_absolute(SaveManager.character_path(char_name))


## Loads the character, or makes a new one if there's no save.
static func load_or_create(char_name: String) -> CharacterData:
	var loaded := load_file(SaveManager.character_path(char_name))
	if loaded:
		return loaded
	var c := create(char_name)
	c.save()
	return c


static func load_file(path: String) -> CharacterData:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var header := SaveHeader.read(f)
	if not header.ok or header.kind != SaveHeader.KIND_CHARACTER:
		push_warning("CharacterData: can't read %s (%s)" % [path, header.error])
		return null
	var v: Variant = f.get_var()
	if not v is Dictionary:
		return null
	var d: Dictionary = v
	var c := CharacterData.new()
	c.name = String(d.get("name", DEFAULT_NAME))
	for sid: String in d.get("empower", {}):
		var ranks := {}
		for nid: String in d["empower"][sid]:
			ranks[StringName(nid)] = int(d["empower"][sid][nid])
		c.empower[StringName(sid)] = ranks
	for id: String in d.get("seen_items", []):
		c.seen_items[StringName(id)] = true
	for id: String in d.get("slain", {}):
		c.slain[StringName(id)] = int(d["slain"][id])
	for id: String in d.get("seen_drops", {}):
		var items := {}
		for it: String in d["seen_drops"][id]:
			items[StringName(it)] = true
		c.seen_drops[StringName(id)] = items
	c.inventory.from_dict(d.get("inventory", {}))
	if not c.seen_items.has(&"catalog"):
		c.give_catalog()  # characters from before the Catalog get one
	if d.has("trash"):
		c.trash.from_dict(d["trash"])
	c.note_inventory()
	var eq: Dictionary = d.get("equipment", {})
	for slot: StringName in ALL_SLOTS:
		var item_id := StringName(eq.get(String(slot), ""))
		c.equipment[slot] = item_id if item_id != &"" and ItemData.find(item_id) != null else &""
	for s: String in d.get("known_spells", []):
		if ItemData.find(ItemData.spell_key(StringName(s))) != null:
			c.known_spells.append(StringName(s))
	var q: Dictionary = d.get("quick", {})
	for slot: String in q:
		var id := StringName(String(q[slot]))
		var item_id := String(id).trim_prefix(ITEM_SHORTCUT)
		if c.knows(id):
			c.quick[StringName(slot)] = id
		elif String(id).begins_with(ITEM_SHORTCUT) and ItemData.find(StringName(item_id)) != null:
			c.quick[StringName(slot)] = id
	var modes: Dictionary = d.get("quick_modes", {})
	for slot: String in modes:
		if c.quick.has(StringName(slot)):
			c.quick_modes[StringName(slot)] = bool(modes[slot])
	var last: Dictionary = d.get("wheel_last", {})
	for w: String in last:
		c.wheel_last[StringName(w)] = StringName(String(last[w]))
	if not d.has("quick"):
		c._migrate_spell_slots(d.get("book_spells", []))
	var look: Dictionary = d.get("look", {})
	var cols: Dictionary = look.get("colors", {})
	for group: String in cols:
		c.colors[StringName(group)] = Color.html(String(cols[group]))
	c.hairstyle = StringName(look.get("hair", String(DEFAULT_HAIR)))
	c.health = float(d.get("health", -1.0))
	c.ghost = bool(d.get("ghost", false))
	c.hunger = float(d.get("hunger", -1.0))
	c.movement_spell = StringName(d.get("movement_spell", ""))
	return c


func save() -> Error:
	if temporary:
		return OK
	var path := SaveManager.character_path(name)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	SaveHeader.write(f, SaveHeader.KIND_CHARACTER)
	f.store_var(to_dict())
	f.close()
	return DirAccess.rename_absolute(tmp, path)


## Older saves: the book's spells go on the Q wheel; spell shortcuts in the inventory
## go on the E wheel (shortcuts are gone).
func _migrate_spell_slots(old_book: Array) -> void:
	var qi := 0
	for s: String in old_book:
		if s != "" and qi < WHEEL_SIZE and set_quick(wheel_slot(&"q", qi), StringName(s)):
			qi += 1
	var ei := 0
	for i in inventory.size:
		var item := inventory.item(i)
		if item and item.is_spell():
			if ei < WHEEL_SIZE and set_quick(wheel_slot(&"e", ei), item.id):
				ei += 1
			inventory.clear(i)


## Dev items and dev spells (debug builds, runtime only) are left out.
func to_dict() -> Dictionary:
	var eq := {}
	for slot: StringName in equipment:
		var item_id: StringName = equipment[slot]
		eq[String(slot)] = "" if ItemData.is_runtime(item_id) else String(item_id)
	var known: Array[String] = []
	for s in known_spells:
		if not ItemData.is_runtime(ItemData.spell_key(s)):
			known.append(String(s))
	var q := {}
	for slot: StringName in quick:
		if String(quick[slot]).begins_with(ITEM_SHORTCUT) or not ItemData.is_runtime(ItemData.spell_key(quick[slot])):
			q[String(slot)] = String(quick[slot])
	var modes := {}
	for slot: StringName in quick_modes:
		if q.has(String(slot)):
			modes[String(slot)] = quick_modes[slot]
	var last := {}
	for w: StringName in wheel_last:
		last[String(w)] = String(wheel_last[w])
	var cols := {}
	for group: StringName in colors:
		cols[String(group)] = colors[group].to_html(false)
	return {"name": name, "inventory": inventory.to_dict(), "equipment": eq,
		"known_spells": known, "quick": q, "quick_modes": modes, "wheel_last": last,
		"look": {"colors": cols, "hair": String(hairstyle)}, "health": health, "hunger": hunger,
		"movement_spell": String(movement_spell), "ghost": ghost, "trash": trash.to_dict(),
		"empower": _empower_dict(),
		"seen_items": seen_items.keys().map(func(k: StringName) -> String: return String(k)),
		"slain": _slain_dict(), "seen_drops": _drops_dict()}


func _slain_dict() -> Dictionary:
	var out := {}
	for k in slain:
		out[String(k)] = slain[k]
	return out


func _drops_dict() -> Dictionary:
	var out := {}
	for k in seen_drops:
		out[String(k)] = seen_drops[k].keys().map(func(i: StringName) -> String: return String(i))
	return out


## You slew an enemy that dropped these items: the Catalog learns it and its drops.
func note_kill(enemy_id: StringName, drops: Array) -> void:
	slain[enemy_id] = int(slain.get(enemy_id, 0)) + 1
	if not seen_drops.has(enemy_id):
		seen_drops[enemy_id] = {}
	for it: Variant in drops:
		seen_drops[enemy_id][StringName(it)] = true


func _empower_dict() -> Dictionary:
	var out := {}
	for sid: StringName in empower:
		var ranks := {}
		for nid: StringName in empower[sid]:
			ranks[String(nid)] = empower[sid][nid]
		out[String(sid)] = ranks
	return out
