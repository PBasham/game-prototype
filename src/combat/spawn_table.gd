class_name SpawnTable
extends GameData
## What spawns in one biome and layer, and how often: `data/spawns/<id>.tres`.
## Each second there's a chance of a spawn, so the gaps are random, like Terraria.
## On average one enemy every `day_seconds` (or `night_seconds`), while fewer than the
## cap are around the player. See docs/combat.md.

enum Layer { SURFACE }

## Biome id this table is for (only &"forest" exists so far).
@export var biome: StringName = &"forest"
@export var layer := Layer.SURFACE

@export_group("Rate")
## Average seconds between spawns. Lower = more often.
@export var day_seconds := 12.0
@export var night_seconds := 6.0
## Most enemies around the player before spawning stops.
@export var max_day := 4
@export var max_night := 7

@export_group("Enemies")
@export var entries: Array[SpawnEntry] = []


## Average seconds between spawns right now.
func seconds(night: bool) -> float:
	return night_seconds if night else day_seconds


func cap(night: bool) -> int:
	return max_night if night else max_day


## Picks an enemy by weight among the entries allowed now (`roll` in 0..1). Null if
## none are allowed.
func pick(night: bool, roll: float) -> EnemyData:
	var total := 0.0
	for e in entries:
		if e.enemy and e.weight > 0.0 and (e.night if night else e.day):
			total += e.weight
	if total <= 0.0:
		return null
	var r := roll * total
	var last: EnemyData = null
	for e in entries:
		if e.enemy and e.weight > 0.0 and (e.night if night else e.day):
			last = e.enemy
			r -= e.weight
			if r <= 0.0:
				return e.enemy
	return last
