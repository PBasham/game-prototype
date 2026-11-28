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


## The Spell Weaving Table's Spells tab: one recipe per spell you don't know yet that's
## `learnable_at_table`, for its learn_cost (copper bars by tier, slime for Gel Cushion).
## Crafting it teaches the spell. Other spells come from Spell Pages. Cheapest tier first.
static func learn_recipes(c: CharacterData) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	if c == null:
		return out
	for d in Registry.get_all(&"spells"):
		var spell := d as SpellData
		if spell == null or c.knows(spell.id) or not spell.learnable_at_table:
			continue
		if not c.unlocked(spell.learn_unlock_items):
			continue
		var r := RecipeData.new()
		r.id = StringName("learn_" + String(spell.id))
		r.display_name = "Learn: %s" % spell.display_name
		r.station = &"spell_weaving"
		r.inputs.assign(spell.learn_cost)
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


## The Spell Weaving Table's Empower tab: one entry per spell you know that has an
## Empower tree (EmpowerNode.for_spell). Each is set to one node of its tree: `picks`
## (spell id -> node id, the one clicked in the tree), else the first node that can take
## a rank, else the first. Its inputs are that node's next rank cost (none when maxed).
static func empower_recipes(c: CharacterData, picks: Dictionary = {}) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	if c == null:
		return out
	var spells: Array[SpellData] = []
	for id in c.known_spells:
		var s := ItemData.find(ItemData.spell_key(id)) as SpellData
		if s:
			spells.append(s)
	spells.sort_custom(func(a: SpellData, b: SpellData) -> bool: return a.display_name < b.display_name)
	for spell in spells:
		var nodes := EmpowerNode.for_spell(spell)
		if nodes.is_empty():
			continue
		var node: EmpowerNode = null
		for n in nodes:
			if picks.get(spell.id, &"") == n.id:
				node = n
		if node == null:
			for n in nodes:
				var parent := n.parent_in(spell)
				if c.empower_rank(spell.id, n.id) < n.max_rank and (parent == null or c.empower_rank(spell.id, parent.id) > 0):
					node = n
					break
		if node == null:
			node = nodes[0]
		var rank := c.empower_rank(spell.id, node.id)
		var r := RecipeData.new()
		r.id = StringName("empower_%s" % spell.id)
		r.display_name = spell.display_name
		r.station = &"spell_weaving"
		if rank < node.max_rank:
			r.inputs.assign(node.cost_for(rank))
		r.output = ItemData.spell_key(spell.id)
		r.empower_node = node.id
		r.empower_spell = spell.id
		out.append(r)
	return out


## The Scribe's Desk: a scroll for each spell you know (only those),
## from its scroll recipe (data/recipes, output `scroll_<spell>`) with the materials
## times `cost_mult` (rounded up, at least 1; the Blank Scroll stays 1), or just a Blank
## Scroll when the spell has no recipe. Your max mana must be at least
## `max_mana_by_tier` for the spell's tier. Scrolls cast at base power.
static func scroll_recipes(c: CharacterData, max_mana_by_tier: Array[float], cost_mult: float = 1.0) -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	if c == null:
		return out
	var by_output := {}
	for d in Registry.get_all(&"recipes"):
		var rd := d as RecipeData
		if rd and String(rd.output).begins_with("scroll_"):
			by_output[rd.output] = rd
	# Spells you know, and scrolls whose recipe you've discovered (Summon Forest Spirit: from a
	# Spirit Core) even without knowing the spell.
	var ids: Array[StringName] = c.known_spells.duplicate()
	for out_id: StringName in by_output:
		var rd: RecipeData = by_output[out_id]
		var sid := StringName(String(out_id).trim_prefix("scroll_"))
		if not rd.unlock_items.is_empty() and c.unlocked(rd.unlock_items) and not ids.has(sid):
			ids.append(sid)
	for id in ids:
		var spell := ItemData.find(ItemData.spell_key(id)) as SpellData
		var scroll := StringName("scroll_" + String(id))
		if spell == null or ItemData.find(scroll) == null:
			continue
		var base: RecipeData = by_output.get(scroll)
		var r := base.duplicate() as RecipeData if base else RecipeData.new()
		r.inputs = {}
		if base:
			for k: StringName in base.inputs:
				r.inputs[k] = 1 if k == &"blank_scroll" else maxi(1, ceili(base.inputs[k] * cost_mult))
		else:
			r.id = scroll
			r.inputs[&"blank_scroll"] = 1
		r.display_name = "Scroll: %s" % spell.display_name
		r.station = &"scribing"
		r.output = scroll
		r.output_count = maxi(1, r.output_count)
		var tier := clampi(spell.tier, 1, maxi(max_mana_by_tier.size(), 1)) - 1
		r.requires_max_mana = max_mana_by_tier[tier] if not max_mana_by_tier.is_empty() else 0.0
		r.note = "Needs %d max mana" % roundi(r.requires_max_mana) if r.requires_max_mana > 0.0 else ""
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
	var extra := {}  # byproducts that didn't fit: id -> count
	for k: StringName in r.also_makes:
		var more := inv.add(k, r.also_makes[k] * n)
		if more > 0:
			extra[k] = more
	return [n, left, extra]


static func _name(item_id: StringName) -> String:
	var item := ItemData.find(item_id)
	return item.display_name if item else String(item_id)


## Names of the hidden recipes that `fresh` (items just seen for the first time) reveal
## for `c`: data recipes, scroll recipes and spells to learn.
static func revealed_by(fresh: Array[StringName], c: CharacterData) -> PackedStringArray:
	var out := PackedStringArray()
	for d in Registry.get_all(&"recipes"):
		var r := d as RecipeData
		if r and r.unlock_items.any(func(id: StringName) -> bool: return fresh.has(id)):
			# Already known through another key item seen before: not new.
			if r.unlock_items.any(func(id: StringName) -> bool: return not fresh.has(id) and c.seen_items.has(id)):
				continue
			var it := ItemData.find(r.output)
			var name := it.display_name if it else (r.display_name if r.display_name != "" else String(r.output))
			if not name in out:
				out.append(name)
	for d in Registry.get_all(&"spells"):
		var s := d as SpellData
		if s and not c.knows(s.id) and s.learn_unlock_items.any(func(id: StringName) -> bool: return fresh.has(id)):
			out.append("Learn: %s" % s.display_name)
	return out
