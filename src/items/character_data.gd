class_name CharacterData
extends RefCounted
## A character, saved separately from worlds: user://characters/<name>.gpchar.
## Holds the inventory, the equipment (spellbook and conduit slots), the spells the
## character knows and the spells put into the book. Until character select exists
## (Phase 7) there is one automatic character, "default", made with the starting kit.
##
## File: SaveHeader (kind "character"), then one store_var Dictionary.

## Equipment or spells changed (the held spell's look and strength may change).
signal magic_changed

const DEFAULT_NAME := "default"
## Used when the book slot is empty (data/items).
const DEFAULT_BOOK := &"basic_spellbook"
## Equipment slots and the item kind each accepts.
const SLOT_BOOK := &"book"
const SLOT_CONDUIT := &"conduit"

## [item id, count] given to a new character. Hotbar order. "spell:<id>" is a hotbar
## shortcut to a spell.
const STARTING_KIT: Array = [
	[&"copper_pickaxe", 1], [&"copper_axe", 1], [&"spell:mining_spell", 1], [&"wood_planks", 99],
	[&"wood_platform", 30], [&"rope", 30], [&"tree_seed", 5], [&"grass_seeds", 10], [&"dirt", 50],
]
const STARTING_SPELLS: Array[StringName] = [&"mining_spell"]

var name := DEFAULT_NAME
var inventory := Inventory.new()
## Equipment slot -> item id (empty = nothing).
var equipment: Dictionary[StringName, StringName] = {SLOT_BOOK: &"", SLOT_CONDUIT: &""}
## Spells learned (data/spells ids).
var known_spells: Array[StringName] = []
## The equipped book's slots: spell id or &"" per slot. Kept when books are swapped;
## a smaller book only uses its first slots.
var book_spells: Array[StringName] = []
## Not saved (dev runs and tests use a throwaway character).
var temporary := false


static func create(char_name: String) -> CharacterData:
	var c := CharacterData.new()
	c.name = char_name
	for e: Array in STARTING_KIT:
		c.inventory.add(e[0], e[1])
	for s in STARTING_SPELLS:
		c.learn_spell(s)
		c.put_in_book(c.book_spells.size(), s)
	return c


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
func put_in_book(slot: int, spell_id: StringName) -> void:
	if slot < 0:
		return
	if spell_id != &"":
		var at := book_spells.find(spell_id)
		if at >= 0:
			book_spells[at] = &""
	while book_spells.size() <= slot:
		book_spells.append(&"")
	book_spells[slot] = spell_id
	magic_changed.emit()


## Equips an item (or &"" to empty the slot). Returns the item id that was there.
func equip(slot: StringName, item_id: StringName) -> StringName:
	var old: StringName = equipment.get(slot, &"")
	equipment[slot] = item_id
	magic_changed.emit()
	return old


## Whether an item can go in an equipment slot.
static func fits(slot: StringName, item: ItemData) -> bool:
	if item == null:
		return false
	match slot:
		SLOT_BOOK:
			return item.kind == ItemData.Kind.BOOK
		SLOT_CONDUIT:
			return item.kind == ItemData.Kind.CONDUIT
	return false


## Why a spell can't be cast right now ("" = it can). `from_tome` skips the book check.
func cast_problem(spell: SpellData, from_tome: bool = false) -> String:
	if spell == null:
		return "Unknown spell"
	if not from_tome and not in_book(spell.id):
		return "Not in your spellbook"
	if spell.requires_conduit != &"":
		var c := conduit()
		if c == null or c.conduit_type != spell.requires_conduit:
			return "Needs a %s conduit" % String(spell.requires_conduit)
	return ""


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

## Loads the character, or makes a new one with the starting kit if there's no save.
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
	for slot: StringName in [SLOT_BOOK, SLOT_CONDUIT]:
		var item_id := StringName(eq.get(String(slot), ""))
		c.equipment[slot] = item_id if item_id != &"" and ItemData.find(item_id) != null else &""
	for s: String in d.get("known_spells", []):
		if ItemData.find(ItemData.spell_key(StringName(s))) != null:
			c.known_spells.append(StringName(s))
	for s: String in d.get("book_spells", []):
		c.book_spells.append(StringName(s) if c.knows(StringName(s)) else &"")
	if not d.has("known_spells"):  # saved before magic existed
		for s in STARTING_SPELLS:
			c.learn_spell(s)
			c.put_in_book(c.book_spells.size(), s)
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
	return {"name": name, "inventory": inventory.to_dict(), "equipment": eq,
		"known_spells": known, "book_spells": book_list}
