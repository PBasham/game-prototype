class_name EnemySpawner
extends Node
## Spawns enemies on the surface around the player, off screen, and removes the ones
## that wander too far. More at night. Not inside houses (tiles with a built back wall).
## Which enemy: weighted by EnemyData.day_weight / night_weight.

## Seconds between spawn attempts.
@export var interval := 3.0
## Most enemies alive near the player, by day and by night.
@export var max_day := 2
@export var max_night := 5
## Spawn this many tiles to the side of the player (off screen, inside the loaded area).
@export var min_distance_tiles := 44.0
@export var max_distance_tiles := 60.0
## Enemies farther than this (tiles) are removed.
@export var despawn_tiles := 90.0
## No spawning at all (dev console `peaceful`).
@export var peaceful := false

var world: World
var _timer := 2.0


func _process(delta: float) -> void:
	if world == null or world.player == null or not Game.is_authority():
		return
	_despawn_far()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = interval
	if peaceful or world.player.dead:
		return
	var night := world.clock != null and world.clock.is_night()
	if world.enemy_count() >= (max_night if night else max_day):
		return
	var data := _pick(night)
	if data == null:
		return
	var spot := find_spot(data)
	if spot != Vector2.INF:
		world.request_spawn_enemy(data, spot)


func _pick(night: bool) -> EnemyData:
	var total := 0.0
	var list: Array[EnemyData] = []
	for d in Registry.get_all(&"enemies"):
		var e := d as EnemyData
		if e and (e.night_weight if night else e.day_weight) > 0.0:
			list.append(e)
			total += e.night_weight if night else e.day_weight
	var r := randf() * total
	for e in list:
		r -= e.night_weight if night else e.day_weight
		if r <= 0.0:
			return e
	return list.back() if not list.is_empty() else null


## A spot on the surface to one side of the player: open ground with room for the enemy
## and not indoors. Vector2.INF when none was found.
func find_spot(data: EnemyData) -> Vector2:
	var p := world.player
	var feet := world.world_to_tile(p.global_position)
	for attempt in 6:
		var side := 1 if randf() < 0.5 else -1
		var x := feet.x + side * randi_range(int(min_distance_tiles), int(max_distance_tiles))
		# From well above, find the first solid ground with air above it.
		for y in range(feet.y - 40, feet.y + 40):
			var t := Vector2i(x, y)
			if not world.is_solid(t):
				continue
			var room := true
			for dy in range(1, int(ceilf(data.size.y / 8.0)) + 2):
				var above := Vector2i(x, y - dy)
				if world.is_solid(above) or world.is_indoors(above):
					room = false
					break
			if room:
				return world.tile_to_world(world.wrap_tile(t)) + Vector2(4.0, 0.0)
			break
	return Vector2.INF


func _despawn_far() -> void:
	var p := world.player
	for e in world.enemies():
		var dx := absf(e._wrapped_dx(p.global_position.x))
		var dy := absf(e.global_position.y - p.global_position.y)
		if dx > despawn_tiles * 8.0 or dy > despawn_tiles * 8.0:
			e.queue_free()
