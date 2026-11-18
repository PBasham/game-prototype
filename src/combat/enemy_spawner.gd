class_name EnemySpawner
extends Node
## Spawns enemies around the player, off screen, from the SpawnTable for where the
## player is (data/spawns), and removes the ones that wander too far. Not inside houses
## (tiles with a built back wall).
##
## Chance based, like Terraria: every frame there's a small chance of a spawn, so on
## average one arrives every `SpawnTable.day_seconds` (or `night_seconds`), at random
## gaps, until the table's cap is reached. With few enemies around it catches up faster.

## Multiplies every table's spawn rate (2 = twice as often). For quick tuning.
@export var rate_scale := 1.0
## Spawn faster when few enemies are around: below 20% of the cap the average wait is
## multiplied by 0.6, below 40% by 0.7, below 60% by 0.8 (Terraria's numbers).
@export var catch_up := true
## Spawn this many tiles to the side of the player (off screen, inside the loaded area).
@export var min_distance_tiles := 44.0
@export var max_distance_tiles := 60.0
## Enemies farther than this (tiles) are removed.
@export var despawn_tiles := 90.0
## No spawning at all (dev console `peaceful`).
@export var peaceful := false

var world: World


func _process(delta: float) -> void:
	if world == null or world.player == null or not Game.is_authority():
		return
	_despawn_far()
	if peaceful or world.player.dead:
		return
	var table := table_here()
	if table == null:
		return
	if randf() < spawn_chance(table, delta):
		try_spawn(table)


func is_night() -> bool:
	return world.clock != null and world.clock.is_night()


## The spawn table for where the player is, or null (nothing spawns there). Only the
## forest surface has one so far: underground, nothing spawns.
func table_here() -> SpawnTable:
	var feet := world.world_to_tile(world.player.global_position)
	for d in Registry.get_all(&"spawns"):
		var t := d as SpawnTable
		if t and t.biome == biome_at(feet.x) and in_layer(t, feet):
			return t
	return null


## The biome at a column. Only the forest exists so far.
func biome_at(_x: int) -> StringName:
	return &"forest"


## Whether a tile is in a table's layer (SURFACE: not deeper than max_depth_tiles below
## the natural surface).
func in_layer(t: SpawnTable, tile: Vector2i) -> bool:
	match t.layer:
		SpawnTable.Layer.SURFACE:
			var surface := world.generator.surface_at(world.wrap_tile(tile).x)
			return tile.y - surface <= t.max_depth_tiles
	return false


## Chance of a spawn in the next `delta` seconds (0 when at the cap).
func spawn_chance(table: SpawnTable, delta: float) -> float:
	var night := is_night()
	var cap := table.cap(night)
	var count := world.enemy_count()
	if count >= cap or rate_scale <= 0.0:
		return 0.0
	var wait := table.seconds(night) / rate_scale
	if catch_up and cap > 0:
		var full := float(count) / float(cap)
		if full < 0.2:
			wait *= 0.6
		elif full < 0.4:
			wait *= 0.7
		elif full < 0.6:
			wait *= 0.8
	return clampf(delta / maxf(wait, 0.01), 0.0, 1.0)


## Picks an enemy from the table and spawns it at a free spot in the table's layer.
## The new enemy or null.
func try_spawn(table: SpawnTable) -> Enemy:
	var data := table.pick(is_night(), randf(), world)
	if data == null:
		return null
	var spot := find_spot(data)
	if spot == Vector2.INF or not in_layer(table, world.world_to_tile(spot)):
		return null
	return world.request_spawn_enemy(data, spot)


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
