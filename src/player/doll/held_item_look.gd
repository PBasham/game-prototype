class_name HeldItemLook
extends Resource
## How one item looks in the character's hands: its sprite, where the hands grip it, and
## its item type (which says how it's held and its attacks). Items (Phase 4) will each
## point at one of these.
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
## Overrides for this item only (leave empty to use the type's).
@export var hold_override: ItemMotion
@export var attacks_override: Array[ItemMotion] = []

var _type_cache: ItemTypeData


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
