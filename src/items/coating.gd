class_name Coating
extends RefCounted
## A coating on one weapon (Poison Coating): kept in that item's slot data (its meta,
## {"coat": coating id, "hits": n}), so it stays with that weapon wherever it goes and
## no other weapon of the same kind shares it.


## The coating in an item's data and its hits left: [ItemData, hits], or [].
static func of(meta: Dictionary) -> Array:
	if meta.is_empty() or not meta.has("coat"):
		return []
	var it := ItemData.find(StringName(String(meta["coat"])))
	var hits := int(meta.get("hits", 0))
	return [it, hits] if it and hits > 0 else []


## Puts a coating on (replacing one already there). The weapon must be a weapon.
static func apply(meta: Dictionary, weapon: ItemData, coating: ItemData) -> bool:
	if weapon == null or weapon.kind != ItemData.Kind.WEAPON or coating == null or coating.buff_poison_hits <= 0:
		return false
	meta["coat"] = String(coating.id)
	meta["hits"] = coating.buff_poison_hits
	return true


## A hit landed: uses one of the coating's hits; returns the coating (null if none).
static func use(meta: Dictionary) -> ItemData:
	var c := of(meta)
	if c.is_empty():
		return null
	var left: int = c[1] - 1
	if left <= 0:
		meta.erase("coat")
		meta.erase("hits")
	else:
		meta["hits"] = left
	return c[0]
