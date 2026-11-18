class_name LootDrop
extends Resource
## One line of a loot table: `chance` to drop `min_count`..`max_count` of `item`.

@export var item: StringName = &""
@export var min_count := 1
@export var max_count := 1
@export_range(0.0, 1.0) var chance := 1.0


static func make(item_id: StringName, lo: int, hi: int, odds: float = 1.0) -> LootDrop:
	var l := LootDrop.new()
	l.item = item_id
	l.min_count = lo
	l.max_count = hi
	l.chance = odds
	return l


## Rolls the table: item id -> count (only the drops that happened).
static func roll(table: Array[LootDrop]) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for l in table:
		if l and l.item != &"" and randf() <= l.chance:
			var n := randi_range(l.min_count, maxi(l.min_count, l.max_count))
			if n > 0:
				out[l.item] = out.get(l.item, 0) + n
	return out
