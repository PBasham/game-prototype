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
	&"melee_damage", &"magic_damage", &"mining_speed"]
## Hairstyles are the .png files in this folder (Patrick draws more later).
const HAIR_DIR := "res://assets/sprites/hair"
const DEFAULT_HAIR := &"short"

## [item id, count] in the dev kit. Hotbar order. "spell:<id>" is a hotbar shortcut
## to a spell.
const DEV_KIT: Array = [
	[&"copper_pickaxe", 1], [&"copper_axe", 1], [&"spell:mining_spell", 1], [&"wood_planks", 99],
	[&"wood_platform", 30], [&"rope", 30], [&"torch", 20], [&"tree_seed", 5], [&"grass_seeds", 10],
	[&"dirt", 50],
]
## More dev kit items, added after the debug placeholders (so they fill later rows).
const DEV_KIT_EXTRA: Array = [
	[&"copper_sword", 1], [&"wooden_sword", 1], [&"copper_helmet", 1], [&"copper_chestplate", 1],
	[&"copper_greaves", 1], [&"bed", 1], [&"berries", 10],
]
## Spells the dev kit teaches and puts in the book (in order).
const DEV_SPELLS: Array[StringName] = [&"mining_spell", &"chopping_spell", &"fly", &"spark", &"levitate",
	&"hyper_drill", &"air_push", &"blink", &"light_orb", &"wisp", &"mend", &"gel_cushion",
	&"arcane_bolt", &"healing_circle", &"spark_ward", &"familiar", &"conjure_platform", &"arcane_edge", &"barrier",
	&"chain_spark", &"recall", &"seek_ore"]

## The movement spell the movement key (F) and double jump use: the last of Fly or
## Levitate you turned on (empty = Fly if known, else Levitate).
var movement_spell: StringName = &""

var name := DEFAULT_NAME
var inventory := Inventory.new()
## Appearance: palette group (skin, hair, tunic, trim, pants, leather) -> the color its
## middle shade becomes. Missing groups keep the art's colors.
var colors: Dictionary[StringName, Color] = {}
## Hairstyle: a file name in HAIR_DIR (without .png), &"" = bald.
var hairstyle: StringName = DEFAULT_HAIR
## Health and hunger when last saved (-1 = full).
var health := -1.0
var hunger := -1.0
## Equipment slot -> item id (empty = nothing).
var equipment: Dictionary[StringName, StringName] = {
	&"head": &"", &"chest": &"", &"legs": &"", &"accessory_1": &"", &"accessory_2": &"",
	&"accessory_3": &"", &"book": &"", &"conduit": &"",
}
## Spells learned (data/spells ids).
var known_spells: Array[StringName] = []
## The equipped book's slots: spell id or &"" per slot. Kept when books are swapped;
## a smaller book only uses its first slots.
var book_spells: Array[StringName] = []
## Not saved (dev runs and tests use a throwaway character).
var temporary := false


## A new character: empty inventory, no spells.
static func create(char_name: String) -> CharacterData:
	var c := CharacterData.new()
	c.name = char_name
	return c


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
		if not in_book(s):
			var free := book_loadout().find(&"")
			if free >= 0:
				put_in_book(free, s)
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


func book_slot_count() -> int:
	var b := book()
	return b.spell_slots if b else 4


## The spells in the book's usable slots (&"" for empty slots).
func book_loadout() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in book_slot_count():
		out.append(book_spells[i] if i < book_spells.size() else &"")
	return out


func knows(spell_id: StringName) -> bool:
	return spell_id in known_spells


func in_book(spell_id: StringName) -> bool:
	return spell_id != &"" and spell_id in book_loadout()


func learn_spell(spell_id: StringName) -> void:
	if not knows(spell_id):
		known_spells.append(spell_id)
		magic_changed.emit()


## Puts a spell into a book slot (moving it if it's in another slot). &"" clears it.
## Refused (false) when the spell's tier is above what the equipped book can hold.
func put_in_book(slot: int, spell_id: StringName) -> bool:
	if slot < 0:
		return false
	var spell := ItemData.find(ItemData.spell_key(spell_id)) as SpellData if spell_id != &"" else null
	if spell and spell.tier > max_spell_tier():
		return false
	if spell_id != &"":
		var at := book_spells.find(spell_id)
		if at >= 0:
			book_spells[at] = &""
	while book_spells.size() <= slot:
		book_spells.append(&"")
	book_spells[slot] = spell_id
	magic_changed.emit()
	return true


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


## Why a spell can't be cast right now ("" = it can). `from_tome` skips the book check.
func cast_problem(spell: SpellData, from_tome: bool = false) -> String:
	if spell == null:
		return "Unknown spell"
	if not from_tome and not in_book(spell.id):
		return "Not in your spellbook"
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


## Spell strength multiplier from the book (or the tome) and the conduit.
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
	c.inventory.from_dict(d.get("inventory", {}))
	var eq: Dictionary = d.get("equipment", {})
	for slot: StringName in ALL_SLOTS:
		var item_id := StringName(eq.get(String(slot), ""))
		c.equipment[slot] = item_id if item_id != &"" and ItemData.find(item_id) != null else &""
	for s: String in d.get("known_spells", []):
		if ItemData.find(ItemData.spell_key(StringName(s))) != null:
			c.known_spells.append(StringName(s))
	for s: String in d.get("book_spells", []):
		c.book_spells.append(StringName(s) if c.knows(StringName(s)) else &"")
	var look: Dictionary = d.get("look", {})
	var cols: Dictionary = look.get("colors", {})
	for group: String in cols:
		c.colors[StringName(group)] = Color.html(String(cols[group]))
	c.hairstyle = StringName(look.get("hair", String(DEFAULT_HAIR)))
	c.health = float(d.get("health", -1.0))
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
	var book_list: Array[String] = []
	for s in book_spells:
		book_list.append("" if s == &"" or ItemData.is_runtime(ItemData.spell_key(s)) else String(s))
	var cols := {}
	for group: StringName in colors:
		cols[String(group)] = colors[group].to_html(false)
	return {"name": name, "inventory": inventory.to_dict(), "equipment": eq,
		"known_spells": known, "book_spells": book_list,
		"look": {"colors": cols, "hair": String(hairstyle)}, "health": health, "hunger": hunger,
		"movement_spell": String(movement_spell)}
