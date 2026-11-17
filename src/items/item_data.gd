class_name ItemData
extends GameData
## An item: what it looks like in the inventory and in hand, how it stacks, and what it
## does when used (mine, chop, place, plant). Files: data/items/<id>.tres.
##
## Left click uses it on the front layer, right click on the back layer (blocks placed
## as background, background mined). The held look's item type (data/item_types)
## decides the arm animation; the fields below decide the effect.
##
## Spells (data/spells) are ItemData too (SpellData): a hotbar spell shortcut is the id
## "spell:<spell id>".

## New kinds go at the end (saved .tres files store the number).
enum Kind { MATERIAL, BLOCK, WALL, TOOL, SPELL, SEED, WEAPON, BOOK, CONDUIT, TOME }

const SPELL_PREFIX := "spell:"

@export var kind := Kind.MATERIAL
## Inventory icon (16x16).
@export var icon: Texture2D
## Most per inventory slot (999 for blocks and materials, 1 for tools).
@export var max_stack := 999
## How it looks and animates in hand. Null = held like a small block.
@export var held: HeldItemLook

@export_group("Mining")
## Damage to blocks per hit (swinging tools), or per second (beam).
@export var mining_damage := 0.0
## Damage to trees per hit (axes).
@export var axe_damage := 0.0
## Mines continuously while held (the mining spell), instead of once per swing.
@export var beam := false
## Square area mined, in tiles (2 = 2x2).
@export var mining_area := 1
## Largest area the area toggle (Ctrl + mouse wheel) can pick. 0 = same as mining_area
## (no toggle).
@export var mining_area_max := 0
## How far from the player it reaches, in tiles.
@export var reach_tiles := 10.0
## When in the swing the hit lands (0..1 through the attack animation).
@export_range(0.0, 1.0) var impact_at := 0.5

@export_group("Placing")
## Block id placed with left click (data/tiles).
@export var places_block: StringName = &""
## Wall id placed with right click, as the back layer (data/walls).
@export var places_wall: StringName = &""
## Plants something: &"tree" (a sapling on grass) or &"grass" (turns dirt to grass).
@export var plants: StringName = &""
## Can be placed anywhere in reach; otherwise it must touch a block or a wall.
@export var free_place := false
## Largest square the area toggle can place at once. 0 = whatever the spellbook allows
## (build_area_max); 1 = always one at a time (tree seeds).
@export var place_area_max := 0
## Placing reach in tiles. 0 = the spellbook's build_reach_tiles.
@export var place_reach_tiles := 0.0

@export_group("Magic")
## Spellbooks: how many spells the book holds.
@export var spell_slots := 0
## Spellbooks: the book is your building tool too (like Starbound's matter manipulator).
## Placing blocks, walls and grass seeds reaches this far (tiles)...
@export var build_reach_tiles := 12.0
## ...and up to this big an area (Ctrl + wheel, shared with the mining spell's area).
@export var build_area_max := 3
## Spellbooks, conduits and tomes: multiplies spell strength (mining damage for now).
@export var spell_power := 1.0
## Conduits: extra reach for spells, in tiles.
@export var spell_reach_bonus := 0.0
## Conduits: the kind of conduit (spells can require one, e.g. &"focus").
@export var conduit_type: StringName = &""
## Tomes: the one spell this tome casts (data/spells id). Held on the hotbar.
@export var tome_spell: StringName = &""
@export_group("")


## Looks up an item by id: data/items, spells ("spell:<id>", data/spells), plus
## runtime-only dev items in debug builds.
static func find(item_id: StringName) -> ItemData:
	if _runtime.has(item_id):
		return _runtime[item_id]
	var category := &"items"
	var key := item_id
	if String(item_id).begins_with(SPELL_PREFIX):
		category = &"spells"
		key = StringName(String(item_id).trim_prefix(SPELL_PREFIX))
	var tree := Engine.get_main_loop() as SceneTree
	var registry: Node = tree.root.get_node_or_null(^"/root/Registry") if tree else null
	if registry:
		return registry.call(&"get_def", category, key) as ItemData
	var path := "res://data/%s/%s.tres" % [category, key]
	return load(path) as ItemData if ResourceLoader.exists(path) else null


## The inventory id of a spell shortcut.
static func spell_key(spell_id: StringName) -> StringName:
	return StringName(SPELL_PREFIX + String(spell_id))


func is_spell() -> bool:
	return false


## Items made at runtime (debug builds' placeholder weapons). Not content.
static var _runtime: Dictionary[StringName, ItemData] = {}


static func register_runtime(item: ItemData) -> void:
	_runtime[spell_key(item.id) if item.is_spell() else item.id] = item


## Runtime-only items aren't saved.
static func is_runtime(item_id: StringName) -> bool:
	return _runtime.has(item_id)


func validate() -> PackedStringArray:
	var problems := super()
	if icon == null:
		problems.append("%s: no icon" % id)
	if max_stack < 1:
		problems.append("%s: max_stack < 1" % id)
	return problems
