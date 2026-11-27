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
## SURFACE: the player (and each spawn spot) must be no deeper than this many tiles
## below the world's natural surface at that column. Anything above counts.
@export var max_depth_tiles := 20

@export_group("Rate")
## Average seconds between spawns. Lower = more often.
@export var day_seconds := 10.0
@export var night_seconds := 6.0
## Most enemies around the player before spawning stops.
@export var max_day := 5
@export var max_night := 6

@export_group("Critters")
## Peaceful creatures (crabs, fish) spawn apart from the enemies: one every this many
## seconds while fewer than max_critters are around.
@export var critter_seconds := 3.0
@export var max_critters := 8
@export_group("Enemies")
@export var entries: Array[SpawnEntry] = []


## Average seconds between spawns right now.
func seconds(night: bool) -> float:
	return night_seconds if night else day_seconds


func cap(night: bool) -> int:
	return max_night if night else max_day


## Picks an enemy by weight among the entries allowed now (`roll` in 0..1): right time
## of day and every condition met in `world`. `critters`: pick among the critters
## (crabs, fish) instead of the enemies; null = either. Null if none are allowed.
func pick(night: bool, roll: float, world: Node, critters: Variant = null) -> EnemyData:
	var total := 0.0
	for e in entries:
		if _fits(e, night, world, critters):
			total += e.weight
	if total <= 0.0:
		return null
	var r := roll * total
	var last: EnemyData = null
	for e in entries:
		if _fits(e, night, world, critters):
			last = e.enemy
			r -= e.weight
			if r <= 0.0:
				return e.enemy
	return last


func _fits(e: SpawnEntry, night: bool, world: Node, critters: Variant) -> bool:
	if critters != null and e.enemy != null and e.enemy.is_critter() != bool(critters):
		return false
	return e.allowed(night, world)


func has_critters() -> bool:
	for e in entries:
		if e.enemy and e.enemy.is_critter():
			return true
	return false
