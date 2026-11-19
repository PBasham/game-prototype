class_name HeldItemLook
extends Resource
## How one item looks in the character's hands: its sprite, where the hands grip it, and
## its item type (which says how it's held and its attacks). Each ItemData points at one
## of these (`held`).
##
## Texture convention: draw the item pointing up and to the right (like an inventory
## icon), handle at the bottom left.

## Used for item-specific drawn arm frames ("arms/<id>/<motion name>").
@export var id: StringName
@export var texture: Texture2D
## Item type id (data/item_types/<type>.tres).
@export var type: StringName
## Pixel in the texture held by the holding hand.
@export var grip := Vector2(3, 13)
## Pixel the other hand holds on two-handed items.
@export var grip2 := Vector2(7, 9)
## Art pixels per world pixel: 1 for normal art, 2 for art drawn at double detail (a
## 32x32 sprite shown the size of a 16x16 one). Grips stay in texture pixels.
@export_range(1, 4) var detail := 1
## Overrides for this item only (leave empty to use the type's).
@export var hold_override: ItemMotion
@export var attacks_override: Array[ItemMotion] = []

var _type_cache: ItemTypeData


## Re-reads every item type from disk (after editing a .tres while the game runs).
## Items already holding a type see the new values: the cached resource is updated in
## place.
static func reload_types() -> void:
	for f in DirAccess.get_files_at("res://data/item_types"):
		if f.ends_with(".tres"):
			ResourceLoader.load("res://data/item_types/" + f, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)


func item_type() -> ItemTypeData:
	if _type_cache == null or _type_cache.id != type:
		_type_cache = load("res://data/item_types/%s.tres" % type) as ItemTypeData
	return _type_cache


func hold_motion() -> ItemMotion:
	return hold_override if hold_override else (item_type().hold if item_type() else null)


func attacks() -> Array[ItemMotion]:
	if not attacks_override.is_empty():
		return attacks_override
	return item_type().attacks if item_type() else ([] as Array[ItemMotion])
