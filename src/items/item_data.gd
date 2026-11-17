class_name ItemData
extends GameData
## An item: what it looks like in the inventory and in hand, how it stacks, and what it
## does when used (mine, chop, place, plant). Files: data/items/<id>.tres.
##
## "Use" is left click with the item selected on the hotbar. The held look's item type
## (data/item_types) decides the arm animation; the fields below decide the effect.

enum Kind { MATERIAL, BLOCK, WALL, TOOL, SPELL, SEED, WEAPON }

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
## Damage to walls per hit (hammers). Walls can only be removed with a hammer.
@export var hammer_damage := 0.0
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
## Block id placed on use (data/tiles).
@export var places_block: StringName = &""
## Wall id placed on use (data/walls).
@export var places_wall: StringName = &""
## Plants something: &"tree" (a sapling on grass) or &"grass" (turns dirt to grass).
@export var plants: StringName = &""
## Can be placed anywhere in reach; otherwise it must touch a block or a wall.
@export var free_place := false
## Largest square the area toggle can place at once (1 = no toggle).
@export var place_area_max := 2


## Looks up an item by id: data/items, plus runtime-only dev items in debug builds.
static func find(item_id: StringName) -> ItemData:
	if _runtime.has(item_id):
		return _runtime[item_id]
	var tree := Engine.get_main_loop() as SceneTree
	var registry: Node = tree.root.get_node_or_null(^"/root/Registry") if tree else null
	if registry:
		return registry.call(&"get_def", &"items", item_id) as ItemData
	var path := "res://data/items/%s.tres" % item_id
	return load(path) as ItemData if ResourceLoader.exists(path) else null


## Items made at runtime (debug builds' placeholder weapons). Not content.
static var _runtime: Dictionary[StringName, ItemData] = {}


static func register_runtime(item: ItemData) -> void:
	_runtime[item.id] = item


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
