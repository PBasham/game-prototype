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


## Copy tab: a recipe per spell the character knows: a Blank Scroll makes that spell's
## scroll, if their max mana is at least `max_mana_by_tier` for the spell's tier (a
## stronger mage for stronger spells). Mana isn't used up.
## The Spell Weaving Table's Spells tab: one recipe per spell you don't know yet, its
## inputs the spell's learn_cost (copper bars by tier, slime for Gel Cushion). Crafting
## it teaches the spell; no scroll needed. Cheapest tier first.
static func learn_recipes(c: CharacterData) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	if c == null:
		return out
	for d in Registry.get_all(&"spells"):
		var spell := d as SpellData
		if spell == null or c.knows(spell.id):
			continue
		var r := RecipeData.new()
		r.id = StringName("learn_" + String(spell.id))
		r.display_name = "Learn: %s" % spell.display_name
		r.station = &"spell_weaving"
		r.inputs = spell.learn_cost.duplicate()
		r.output = ItemData.spell_key(spell.id)
		r.teaches = spell.id
		r.note = "Tier %d. Yours for good." % spell.tier
		if spell.tier > c.max_spell_tier():
			r.note = "Tier %d: needs a tier %d book to cast." % [spell.tier, spell.tier]
		out.append(r)
	out.sort_custom(func(a: RecipeData, b: RecipeData) -> bool:
		var ta := (ItemData.find(a.output) as SpellData).tier
		var tb := (ItemData.find(b.output) as SpellData).tier
		return a.display_name < b.display_name if ta == tb else ta < tb)
	return out


static func copy_recipes(c: CharacterData, max_mana_by_tier: Array[float]) -> Array[RecipeData]:
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
		var tier := clampi(spell.tier, 1, maxi(max_mana_by_tier.size(), 1)) - 1
		r.requires_max_mana = max_mana_by_tier[tier] if not max_mana_by_tier.is_empty() else 0.0
		r.note = "Copied from your known spells. Needs %d max mana" % roundi(r.requires_max_mana)
		out.append(r)
	out.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return a.display_name < b.display_name)
	return out


## How many times the recipe can be made from what's in the inventory (0 = can't), by a
## crafter with `max_mana` (for recipes that need a big enough pool).
static func times_craftable(inv: Inventory, r: RecipeData, max_mana: float = INF) -> int:
	if r.requires_max_mana > 0.0 and max_mana < r.requires_max_mana:
		return 0
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
static func craft(inv: Inventory, r: RecipeData, times: int, max_mana: float = INF) -> Array:
	var n := mini(times, times_craftable(inv, r, max_mana))
	if n <= 0:
		return [0, 0]
	for k: StringName in r.inputs:
		inv.remove(k, r.inputs[k] * n)
	var left := inv.add(r.output, r.output_count * n)
	return [n, left]


static func _name(item_id: StringName) -> String:
	var item := ItemData.find(item_id)
	return item.display_name if item else String(item_id)
