class_name CraftStock
extends Inventory
## What crafting draws from: your inventory first, then nearby chests (closest first).
## Counts add up across them; removing takes from your inventory before any chest.
## Crafted items go to your inventory. With `free` (dev console `freecraft`), every
## count is plenty and nothing is taken.

## Plenty, for free crafting.
const PLENTY := 1000000

var sources: Array[Inventory] = []
var free := false


func _init(from: Array[Inventory] = [], free_crafting: bool = false) -> void:
	super(1)
	sources = from
	free = free_crafting


func count_of(item_id: StringName) -> int:
	if free:
		return PLENTY
	var total := 0
	for inv in sources:
		total += inv.count_of(item_id)
	return total


func remove(item_id: StringName, count: int) -> int:
	if free:
		return count
	var taken := 0
	for inv in sources:
		if taken >= count:
			break
		taken += inv.remove(item_id, count - taken)
	return taken


## Crafted items go to your inventory (the first source).
func add(item_id: StringName, count: int, keep_empty: int = -1) -> int:
	return sources[0].add(item_id, count, keep_empty) if not sources.is_empty() else count


func room_for(item_id: StringName) -> int:
	return sources[0].room_for(item_id) if not sources.is_empty() else 0
