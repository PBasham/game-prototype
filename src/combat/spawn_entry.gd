class_name SpawnEntry
extends Resource
## One enemy in a SpawnTable. Its chance to be picked is its weight divided by the total
## weight of every entry allowed at that time (day or night).

@export var enemy: EnemyData
## Relative chance. Green Slime 100 and Blue Slime 12 means about 11% of spawns are Blue.
@export var weight := 100.0
@export var day := true
@export var night := true
## All must be met for it to spawn (e.g. a KillCountCondition). Empty = always.
@export var conditions: Array[SpawnCondition] = []


## Can spawn now: allowed at this time of day and every condition is met.
func allowed(night_now: bool, world: Node) -> bool:
	if enemy == null or weight <= 0.0 or not (night if night_now else day):
		return false
	for c in conditions:
		if c and not c.met(world):
			return false
	return true


static func make(e: EnemyData, w: float, by_day := true, by_night := true,
		needs: Array[SpawnCondition] = []) -> SpawnEntry:
	var s := SpawnEntry.new()
	s.enemy = e
	s.weight = w
	s.day = by_day
	s.night = by_night
	s.conditions = needs
	return s
