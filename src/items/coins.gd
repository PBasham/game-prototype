class_name Coins
extends RefCounted
## Phase 76: money. Copper, Silver, Gold and Platinum coins (items with
## `ItemData.coin_value`); 100 of one make 1 of the next. Coins you pick up go straight
## into the coin pouch (CharacterData.coins, a total in copper), which combines them by
## itself; the pouch's panel shows them by coin (Hud, bottom right of the inventory).

## The coins, smallest first.
const IDS: Array[StringName] = [&"copper_coin", &"silver_coin", &"gold_coin", &"platinum_coin"]
const SHORT: Array[String] = ["c", "s", "g", "p"]


## What one coin is worth in copper (0 = not a coin).
static func value_of(id: StringName) -> int:
	var i := IDS.find(id)
	return 0 if i < 0 else int(pow(100, i))


static func is_coin(id: StringName) -> bool:
	return IDS.has(id)


## A copper total by coin, smallest first: [copper, silver, gold, platinum]. Platinum
## has no cap.
static func split(total: int) -> Array[int]:
	var out: Array[int] = []
	var left := maxi(total, 0)
	for i in IDS.size():
		if i == IDS.size() - 1:
			out.append(left)
		else:
			out.append(left % 100)
			left /= 100
	return out


## "3p 12g 40s 5c", biggest first, skipping the empty ones ("0c" for nothing).
static func text(total: int) -> String:
	var parts := split(total)
	var out := PackedStringArray()
	for i in range(IDS.size() - 1, -1, -1):
		if parts[i] > 0:
			out.append("%d%s" % [parts[i], SHORT[i]])
	return " ".join(out) if not out.is_empty() else "0c"
