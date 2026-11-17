class_name Inventory
extends RefCounted
## A character's 40 item slots. Slots 0..9 are the hotbar (the top row of the panel).
## A slot is empty when its id is &"". Items are referenced by id (ItemData.find), so a
## save keeps working when an item's stats change.

signal changed

const SIZE := 40
const HOTBAR := 10

var ids: Array[StringName] = []
var counts: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	ids.resize(SIZE)
	ids.fill(&"")
	counts.resize(SIZE)


func is_empty(slot: int) -> bool:
	return ids[slot] == &"" or counts[slot] <= 0


func item(slot: int) -> ItemData:
	return null if is_empty(slot) else ItemData.find(ids[slot])


static func max_stack(item_id: StringName) -> int:
	var data := ItemData.find(item_id)
	return data.max_stack if data else 999


## Adds items: tops up existing stacks first, then fills empty slots (hotbar first).
## Returns how many didn't fit.
func add(item_id: StringName, count: int) -> int:
	if count <= 0 or item_id == &"":
		return 0
	var cap := max_stack(item_id)
	for i in SIZE:
		if count == 0:
			break
		if ids[i] == item_id and counts[i] < cap:
			var n := mini(count, cap - counts[i])
			counts[i] += n
			count -= n
	for i in SIZE:
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
	var cap := max_stack(item_id)
	var room := 0
	for i in SIZE:
		if is_empty(i):
			room += cap
		elif ids[i] == item_id:
			room += cap - counts[i]
	return room


func count_of(item_id: StringName) -> int:
	var total := 0
	for i in SIZE:
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


func set_slot(slot: int, item_id: StringName, count: int) -> void:
	if item_id == &"" or count <= 0:
		ids[slot] = &""
		counts[slot] = 0
	else:
		ids[slot] = item_id
		counts[slot] = count
	changed.emit()


func clear(slot: int) -> void:
	ids[slot] = &""
	counts[slot] = 0


func to_dict() -> Dictionary:
	var slots: Array = []
	for i in SIZE:
		var keep := not is_empty(i) and not ItemData.is_runtime(ids[i])  # dev items aren't saved
		slots.append([String(ids[i]), counts[i]] if keep else [])
	return {"slots": slots}


## Unknown item ids (removed content) are dropped with a warning.
func from_dict(d: Dictionary) -> void:
	var slots: Array = d.get("slots", [])
	for i in SIZE:
		clear(i)
		if i < slots.size() and (slots[i] as Array).size() == 2:
			var item_id := StringName(slots[i][0])
			if ItemData.find(item_id) == null:
				push_warning("Inventory: unknown item '%s' dropped from slot %d" % [item_id, i])
				continue
			ids[i] = item_id
			counts[i] = int(slots[i][1])
	changed.emit()
