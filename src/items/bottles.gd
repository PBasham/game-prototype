class_name Bottles
## Bottles of a liquid hold charges (sips). A full one is `<liquid>_<bottle>`, a part
## drunk one `<liquid>_<bottle>_<n>`, the empty one the bottle itself (Phase 80).


## The item for `bottle` holding `n` sips of `liquid` (the empty bottle at 0).
static func id_for(liquid: StringName, bottle: StringName, n: int) -> StringName:
	var b := ItemData.find(bottle)
	if n <= 0 or b == null:
		return bottle
	if n >= b.holds_charges:
		return StringName("%s_%s" % [liquid, bottle])
	return StringName("%s_%s_%d" % [liquid, bottle, n])


## Sips a bottle (empty or not) holds when full; 0 if it isn't a bottle.
static func capacity(item: ItemData) -> int:
	if item == null:
		return 0
	if item.holds_charges > 0:
		return item.holds_charges
	var b := ItemData.find(item.container) if item.container != &"" else null
	return b.holds_charges if b else 0


## Pours sips from one bottle into another (empty, or the same liquid with room).
## Returns [from_after, to_after] ids, or [] if nothing can pour.
static func pour(from: ItemData, to: ItemData) -> Array[StringName]:
	if from == null or to == null or from.charges <= 0 or from.liquid == &"":
		return []
	var to_bottle := to.id if to.holds_charges > 0 else to.container
	if to_bottle == &"" or (to.charges > 0 and to.liquid != from.liquid):
		return []
	var room := capacity(to) - to.charges
	var n := mini(from.charges, room)
	if n <= 0:
		return []
	var out: Array[StringName] = [id_for(from.liquid, from.container, from.charges - n), id_for(from.liquid, to_bottle, to.charges + n)]
	if ItemData.find(out[0]) == null or ItemData.find(out[1]) == null:
		return []  # salt water only comes in full bottles
	return out
