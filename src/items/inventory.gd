class_name Inventory
extends RefCounted
## Item slots: a character's inventory (40 by default, slots 0..9 are the hotbar, the
## top row of the panel) or a chest. The size is set when it's made, so a smaller
## starting inventory or bags that add rows only change the number.
## A slot is empty when its id is &"". Items are referenced by id (ItemData.find), so a
## save keeps working when an item's stats change.

signal changed

const DEFAULT_SIZE := 40
const HOTBAR := 10

## Number of slots.
var size := DEFAULT_SIZE
var ids: Array[StringName] = []
var counts: PackedInt32Array = PackedInt32Array()
## Extra data that belongs to the one item in a slot (a weapon's coating:
## {"coat": coating id, "hits": n}). It moves with the item; empty for most.
var metas: Array[Dictionary] = []
## Special storage: only items with this storage tag fit (&"" = anything).
var accepts_tag: StringName = &""
## Special storage: each slot holds this many of an item (0 = the item's own stack).
var stack_cap := 0


func _init(slots: int = DEFAULT_SIZE) -> void:
	resize(slots)


## Changes the number of slots (items in removed slots are lost: move them first).
func resize(slots: int) -> void:
	size = maxi(slots, 1)
	ids.resize(size)  # new slots are &"" (empty)
	counts.resize(size)
	metas.resize(size)
	for i in size:
		if metas[i] == null:
			metas[i] = {}


func is_empty(slot: int) -> bool:
	return ids[slot] == &"" or counts[slot] <= 0


func item(slot: int) -> ItemData:
	return null if is_empty(slot) else ItemData.find(ids[slot])


## Whether an item may go in (special storage takes only its tag).
func accepts(item_id: StringName) -> bool:
	if accepts_tag == &"":
		return true
	var it := ItemData.find(item_id)
	return it != null and accepts_tag in it.storage_tags


## How many of an item one slot holds here.
func cap_for(item_id: StringName) -> int:
	return stack_cap if stack_cap > 0 else max_stack(item_id)


## How full it is, 0 to 1: each slot counts as its share of a full stack there.
func fill() -> float:
	var total := 0.0
	for i in size:
		if not is_empty(i):
			total += counts[i] / float(maxi(cap_for(ids[i]), 1))
	return clampf(total / maxf(size, 1.0), 0.0, 1.0)


static func max_stack(item_id: StringName) -> int:
	var data := ItemData.find(item_id)
	return data.max_stack if data else 999


## Adds items: tops up existing stacks first, then fills empty slots (hotbar first).
## Returns how many didn't fit.
## `keep_empty`: an empty slot to fill only if nothing else has room (the slot in your
## hand, so picking things up doesn't fill your empty hand).
func add(item_id: StringName, count: int, keep_empty: int = -1) -> int:
	if count <= 0 or item_id == &"":
		return 0
	if not accepts(item_id):
		return count
	var cap := cap_for(item_id)
	for i in size:
		if count == 0:
			break
		if ids[i] == item_id and counts[i] < cap:
			var n := mini(count, cap - counts[i])
			counts[i] += n
			count -= n
	var order: Array[int] = []
	for i in size:
		if i != keep_empty:
			order.append(i)
	if keep_empty >= 0 and keep_empty < size:
		order.append(keep_empty)
	for i in order:
		if count == 0:
			break
		if is_empty(i):
			var n := mini(count, cap)
			ids[i] = item_id
			counts[i] = n
			count -= n
	changed.emit()
	return count


## How many of an item fit (for pickups).
func room_for(item_id: StringName) -> int:
	if not accepts(item_id):
		return 0
	var cap := cap_for(item_id)
	var room := 0
	for i in size:
		if is_empty(i):
			room += cap
		elif ids[i] == item_id:
			room += cap - counts[i]
	return room


func is_all_empty() -> bool:
	for i in size:
		if not is_empty(i):
			return false
	return true


## Takes `count` of an item from wherever it is (the last slots first, so the hotbar is
## used last). Returns how many were taken.
func remove(item_id: StringName, count: int) -> int:
	var taken := 0
	for i in range(size - 1, -1, -1):
		if taken >= count:
			break
		if ids[i] == item_id:
			var n := mini(count - taken, counts[i])
			counts[i] -= n
			taken += n
			if counts[i] <= 0:
				clear(i)
	if taken > 0:
		changed.emit()
	return taken


func count_of(item_id: StringName) -> int:
	var total := 0
	for i in size:
		if ids[i] == item_id:
			total += counts[i]
	return total


## Takes up to `count` from one slot. Returns how many were taken.
func take(slot: int, count: int) -> int:
	if is_empty(slot):
		return 0
	var n := mini(count, counts[slot])
	counts[slot] -= n
	if counts[slot] <= 0:
		clear(slot)
	changed.emit()
	return n


## Puts `count` of an item in a slot. `meta` is that item's own data (moving a coated
## weapon passes its meta along); left out, the slot keeps its meta only if it still
## holds the same item.
func set_slot(slot: int, item_id: StringName, count: int, meta: Variant = null) -> void:
	if item_id == &"" or count <= 0:
		ids[slot] = &""
		counts[slot] = 0
		metas[slot] = {}
	else:
		if meta != null:
			metas[slot] = meta
		elif ids[slot] != item_id:
			metas[slot] = {}
		ids[slot] = item_id
		counts[slot] = count
	changed.emit()


func clear(slot: int) -> void:
	ids[slot] = &""
	counts[slot] = 0
	metas[slot] = {}


func to_dict() -> Dictionary:
	var slots: Array = []
	for i in size:
		var keep := not is_empty(i) and not ItemData.is_runtime(ids[i])  # dev items aren't saved
		var entry: Array = [String(ids[i]), counts[i]]
		if keep and not metas[i].is_empty():
			entry.append(metas[i])
		slots.append(entry if keep else [])
	return {"slots": slots}


## Unknown item ids (removed content) are dropped with a warning.
func from_dict(d: Dictionary) -> void:
	var slots: Array = d.get("slots", [])
	if not slots.is_empty():
		resize(slots.size())  # the saved size wins (bags may have grown it)
	for i in size:
		clear(i)
		if i < slots.size() and (slots[i] as Array).size() >= 2:
			var item_id := StringName(slots[i][0])
			item_id = ItemData.RENAMED.get(item_id, item_id)
			if ItemData.find(item_id) == null:
				push_warning("Inventory: unknown item '%s' dropped from slot %d" % [item_id, i])
				continue
			ids[i] = item_id
			counts[i] = int(slots[i][1])
			if (slots[i] as Array).size() >= 3 and slots[i][2] is Dictionary:
				metas[i] = (slots[i][2] as Dictionary).duplicate()
	changed.emit()
