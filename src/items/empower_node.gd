class_name EmpowerNode
extends GameData
## One node of a spell's Empower tree (data/empower/), bought rank by rank at the Spell
## Weaving Table's Empower tab. Each known spell has its own ranks
## (`CharacterData.empower`). Bare bones for now: every spell's tree is the nodes whose
## `groups` fit it, in `order`; `requires` (a node id at rank 1+) makes the tree shape.

## MANA_COST: per_rank changes the mana cost. EVOLVE: each rank grows a melee summon
## into its next form (SpellData.summon_enemy_ranks: Green Slime, then Blue Slime).
## FIELDS: each rank changes spell numbers by name (`adds`, `scales`), e.g. Mining's
## Power: mining_power +10, mining_area_max +1, mining_damage +30%.
enum Stat { MANA_COST, EVOLVE, FIELDS }

## What a rank changes, and by how much (Efficient: MANA_COST -0.05 = 5% cheaper).
@export var stat := Stat.MANA_COST
@export var per_rank := -0.05
@export var max_rank := 5
## Cost of rank 1; rank n costs n times this.
@export var cost_per_rank: Dictionary[StringName, int] = {}
## Costs rank by rank (rank 1 first), used instead of cost_per_rank when set: Mining's
## Power takes copper bars, then iron bars.
@export var rank_costs: Array[Dictionary] = []
## FIELDS: SpellData numbers added per rank (`{&"mining_power": 10.0}`).
@export var adds: Dictionary[StringName, float] = {}
## FIELDS: SpellData numbers scaled per rank (`{&"damage": 0.1}` = 10% more per rank).
@export var scales: Dictionary[StringName, float] = {}
## Spells it's offered for by id (empty = by `groups`).
@export var spells: Array[StringName] = []
## Spell casts it's offered for (empty = any), e.g. Potency for projectiles and chains.
@export var casts: Array[SpellData.Cast] = []
## Spell groups it's offered for (empty = every spell that uses mana).
@export var groups: Array[SpellData.Group] = []
## Another node that needs a rank first (empty = a root node).
@export var requires: StringName = &""
## Sort order in the tree.
@export var order := 0


## Whether this node is offered for `spell`.
func fits(spell: SpellData) -> bool:
	if stat == Stat.MANA_COST and spell.mana_cost <= 0.0 and spell.mana_per_second <= 0.0:
		return false
	if stat == Stat.EVOLVE:
		return spell.summon_enemy_ranks.size() > 1
	if not spells.is_empty():
		return spells.has(spell.id)
	if not casts.is_empty() and not casts.has(spell.cast):
		return false
	return groups.is_empty() or groups.has(spell.group)


## What the next rank (from `rank`) costs.
func cost_for(rank: int) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if not rank_costs.is_empty():
		var d: Dictionary = rank_costs[mini(rank, rank_costs.size() - 1)]
		for id: StringName in d:
			out[StringName(id)] = int(d[id])
		return out
	for id in cost_per_rank:
		out[id] = cost_per_rank[id] * (rank + 1)
	return out


## Applies `rank` ranks of this node to a spell copy (FIELDS nodes).
func apply(spell: SpellData, rank: int) -> void:
	if stat != Stat.FIELDS or rank <= 0:
		return
	for f in adds:
		_set_num(spell, f, float(spell.get(f)) + adds[f] * rank)
	for f in scales:
		_set_num(spell, f, float(spell.get(f)) * (1.0 + scales[f] * rank))


static func _set_num(spell: SpellData, field: StringName, value: float) -> void:
	if typeof(spell.get(field)) == TYPE_INT:
		spell.set(field, roundi(value))
	else:
		spell.set(field, value)


func validate() -> PackedStringArray:
	var problems := super()
	var probe := SpellData.new()
	for f in adds.keys() + scales.keys():
		if not typeof(probe.get(f)) in [TYPE_INT, TYPE_FLOAT]:
			problems.append("%s: %s isn't a SpellData number" % [id, f])
	return problems


## The nodes offered for a spell, in tree order.
static func for_spell(spell: SpellData) -> Array[EmpowerNode]:
	var out: Array[EmpowerNode] = []
	for d in Registry.get_all(&"empower"):
		var n := d as EmpowerNode
		if n and n.fits(spell):
			out.append(n)
	out.sort_custom(func(a: EmpowerNode, b: EmpowerNode) -> bool: return a.order < b.order)
	return out
