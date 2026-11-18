class_name Crafting
extends RefCounted
## Recipe lookups and crafting against an inventory. Recipes are data
## (data/recipes, RecipeData); each belongs to a station kind or to hand crafting.


## The recipes made at a station kind (&"" = by hand), up to a station tier, in a
## stable order (by name).
static func recipes_for(station: StringName, tier: int = 1) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for d in Registry.get_all(&"recipes"):
		var r := d as RecipeData
		if r and r.station == station and r.station_tier <= tier:
			out.append(r)
	out.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return a.display_name < b.display_name)
	return out


## A spell scroll recipe as this character pays for it: spells they know cost `share`
## of the materials (rounded up; the Blank Scroll is still needed). Other recipes come
## back unchanged.
static func for_crafter(r: RecipeData, c: CharacterData, share: float) -> RecipeData:
	var out := ItemData.find(r.output)
	if c == null or out == null or out.teaches_spell == &"" or not c.knows(out.teaches_spell):
		return r
	var cheap := r.duplicate() as RecipeData
	cheap.inputs = r.inputs.duplicate()  # its own copy: never touch the real recipe
	for k: StringName in cheap.inputs:
		if k != &"blank_scroll":
			cheap.inputs[k] = maxi(1, ceili(r.inputs[k] * share))
	cheap.note = "Known spell: %d%% of the materials" % roundi(share * 100.0)
	return cheap


## Copy tab: a recipe per spell the character knows: a Blank Scroll plus mana makes that
## spell's scroll. Mana is the spell's cost (per cast, or 2 seconds of a beam or
## concentration) times `factor`, kept between `low` and `high`.
static func copy_recipes(c: CharacterData, factor: float, low: float, high: float) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	if c == null:
		return out
	for id in c.known_spells:
		var spell := ItemData.find(ItemData.spell_key(id)) as SpellData
		var scroll := StringName("scroll_" + String(id))
		if spell == null or ItemData.find(scroll) == null:
			continue
		var r := RecipeData.new()
		r.id = StringName("copy_" + String(id))
		r.display_name = "Copy: %s" % spell.display_name
		r.station = &"spell_weaving"
		r.inputs = {&"blank_scroll": 1}
		r.output = scroll
		r.mana = clampf(maxf(spell.mana_cost, spell.mana_per_second * 2.0) * factor, low, high)
		r.note = "Copied from your known spells, with %d mana" % roundi(r.mana)
		out.append(r)
	out.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return a.display_name < b.display_name)
	return out


## How many times the recipe can be made from what's in the inventory (0 = can't), and
## with `mana` to spend on recipes that use it.
static func times_craftable(inv: Inventory, r: RecipeData, mana: float = INF) -> int:
	for q in r.requires:
		if inv.count_of(q) <= 0:
			return 0
	var times := 1000000
	for k: StringName in r.inputs:
		times = mini(times, inv.count_of(k) / maxi(r.inputs[k], 1))
	if r.mana > 0.0 and mana != INF:
		times = mini(times, floori(mana / r.mana))
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
## outputs that didn't fit] (the caller drops the extra, and spends r.mana * times made).
static func craft(inv: Inventory, r: RecipeData, times: int, mana: float = INF) -> Array:
	var n := mini(times, times_craftable(inv, r, mana))
	if n <= 0:
		return [0, 0]
	for k: StringName in r.inputs:
		inv.remove(k, r.inputs[k] * n)
	var left := inv.add(r.output, r.output_count * n)
	return [n, left]


static func _name(item_id: StringName) -> String:
	var item := ItemData.find(item_id)
	return item.display_name if item else String(item_id)
