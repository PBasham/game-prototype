class_name Crafting
extends RefCounted
## Recipe lookups and crafting against an inventory. Recipes are data
## (data/recipes, RecipeData); each belongs to a station kind or to hand crafting.


## The recipes made at a station kind (&"" = by hand), up to a station tier, in a
## stable order (by name). With a character, "Copy: <spell>" recipes show only for spells
## in their book; without one they're left out.
static func recipes_for(station: StringName, tier: int = 1, c: CharacterData = null) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for d in Registry.get_all(&"recipes"):
		var r := d as RecipeData
		if r and r.station == station and r.station_tier <= tier and allowed(r, c):
			out.append(r)
	out.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return a.display_name < b.display_name)
	return out


## Whether a character may use a recipe (a copy recipe needs its spell in their book).
static func allowed(r: RecipeData, c: CharacterData) -> bool:
	return r.requires_book_spell == &"" or (c != null and c.in_book(r.requires_book_spell))


## How many times the recipe can be made from what's in the inventory (0 = can't).
static func times_craftable(inv: Inventory, r: RecipeData) -> int:
	for q in r.requires:
		if inv.count_of(q) <= 0:
			return 0
	var times := 1000000
	for k: StringName in r.inputs:
		times = mini(times, inv.count_of(k) / maxi(r.inputs[k], 1))
	return times


## What's missing for one craft, for the tooltip ("2 Flint", "Hand Hammer (keep)").
static func missing(inv: Inventory, r: RecipeData) -> PackedStringArray:
	var out := PackedStringArray()
	for q in r.requires:
		if inv.count_of(q) <= 0:
			out.append("%s (not used up)" % _name(q))
	for k: StringName in r.inputs:
		var short := r.inputs[k] - inv.count_of(k)
		if short > 0:
			out.append("%d %s" % [short, _name(k)])
	return out


## Crafts up to `times`: takes the inputs, adds the outputs. Returns [times made,
## outputs that didn't fit] (the caller drops the extra).
static func craft(inv: Inventory, r: RecipeData, times: int) -> Array:
	var n := mini(times, times_craftable(inv, r))
	if n <= 0:
		return [0, 0]
	for k: StringName in r.inputs:
		inv.remove(k, r.inputs[k] * n)
	var left := inv.add(r.output, r.output_count * n)
	return [n, left]


static func _name(item_id: StringName) -> String:
	var item := ItemData.find(item_id)
	return item.display_name if item else String(item_id)
