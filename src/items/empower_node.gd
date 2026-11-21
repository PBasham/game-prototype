class_name EmpowerNode
extends GameData
## One node of a spell's Empower tree (data/empower/), bought rank by rank at the Spell
## Weaving Table's Empower tab. Each known spell has its own ranks
## (`CharacterData.empower`). Bare bones for now: every spell's tree is the nodes whose
## `groups` fit it, in `order`; `requires` (a node id at rank 1+) makes the tree shape.

enum Stat { MANA_COST }

## What a rank changes, and by how much (Efficient: MANA_COST -0.05 = 5% cheaper).
@export var stat := Stat.MANA_COST
@export var per_rank := -0.05
@export var max_rank := 5
## Cost of rank 1; rank n costs n times this.
@export var cost_per_rank: Dictionary[StringName, int] = {}
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
	return groups.is_empty() or groups.has(spell.group)


## What the next rank (from `rank`) costs.
func cost_for(rank: int) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for id in cost_per_rank:
		out[id] = cost_per_rank[id] * (rank + 1)
	return out


## The nodes offered for a spell, in tree order.
static func for_spell(spell: SpellData) -> Array[EmpowerNode]:
	var out: Array[EmpowerNode] = []
	for d in Registry.get_all(&"empower"):
		var n := d as EmpowerNode
		if n and n.fits(spell):
			out.append(n)
	out.sort_custom(func(a: EmpowerNode, b: EmpowerNode) -> bool: return a.order < b.order)
	return out
