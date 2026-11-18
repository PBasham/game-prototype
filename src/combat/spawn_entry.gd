class_name SpawnEntry
extends Resource
## One enemy in a SpawnTable. Its chance to be picked is its weight divided by the total
## weight of every entry allowed at that time (day or night).

@export var enemy: EnemyData
## Relative chance. Green Slime 100 and Blue Slime 12 means about 11% of spawns are Blue.
@export var weight := 100.0
@export var day := true
@export var night := true


static func make(e: EnemyData, w: float, by_day := true, by_night := true) -> SpawnEntry:
	var s := SpawnEntry.new()
	s.enemy = e
	s.weight = w
	s.day = by_day
	s.night = by_night
	return s
