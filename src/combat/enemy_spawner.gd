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
## Enemies farther than this (tiles, sideways) for despawn_seconds in a row are removed...
@export var despawn_tiles := 90.0
## ...or farther than this up or down (Terraria spawns at most 47 tiles up or down, so
## a surface slime far above you in a cave goes away).
@export var despawn_tiles_vertical := 50.0
## Enemies never spawn inside the view: when zoomed out, spawn and despawn distances
## grow to at least the edge of the screen plus this many tiles.
@export var view_margin_tiles := 6.0
@export var despawn_seconds := 6.0
## While you're moving sideways faster than ahead_speed_tiles (tiles/s), this share of
## spawns appear ahead of you instead of either side (so travelling isn't empty).
@export_range(0.0, 1.0) var ahead_bias := 0.8
@export var ahead_speed_tiles := 6.0
## No spawning at all (dev console `peaceful`).
@export var peaceful := false

var world: World
## Natural spawns this session, and spawn rolls that found no spot (for the console).
var spawned_total := 0
var failed_total := 0
## Seconds the spawner has been allowed to spawn (not peaceful, below the cap).
var active_seconds := 0.0


func _process(delta: float) -> void:
	if world == null or world.player == null or not Game.is_authority():
		return
	_despawn_far()
	if peaceful or world.player.dead:
		return
	var table := table_here()
	if table == null:
		return
	var chance := spawn_chance(table, delta)
	if chance > 0.0:
		active_seconds += delta
	if randf() < chance:
		if try_spawn(table):
			spawned_total += 1
		else:
			failed_total += 1
	# Critters (crabs, fish) on their own cap and clock.
	if table.has_critters() and world.critter_count() < table.max_critters and rate_scale > 0.0 \
			and randf() < clampf(delta / maxf(table.critter_seconds / rate_scale, 0.01), 0.0, 1.0):
		try_spawn(table, true)


func is_night() -> bool:
	return world.clock != null and world.clock.is_night()


## The spawn table for where the player is, or null (nothing spawns there). Only the
## forest surface has one so far: underground, nothing spawns.
func table_here() -> SpawnTable:
	var feet := world.world_to_tile(world.player.global_position)
	for d in Registry.get_all(&"spawns"):
		var t := d as SpawnTable
		if t and t.biome == biome_here(feet) and in_layer(t, feet):
			return t
	return null


## The biome at a tile, counted from the blocks around it (World.biome_at).
func biome_here(tile: Vector2i) -> StringName:
	if world and world.data:
		return world.biome_at(tile)
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
## Spawns one from the table: an enemy, or with `critters` a critter.
func try_spawn(table: SpawnTable, critters: bool = false) -> Enemy:
	var data := table.pick(is_night(), randf(), world, critters)
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
	var moving := absf(p.velocity.x) > ahead_speed_tiles * 8.0
	var ahead := 1 if p.velocity.x > 0.0 else -1
	for attempt in 6:
		var side := 1 if randf() < 0.5 else -1
		if moving:
			side = ahead if randf() < ahead_bias else -ahead
		var near := maxf(min_distance_tiles, view_half_tiles().x + view_margin_tiles)
		var far := maxf(max_distance_tiles, near + (max_distance_tiles - min_distance_tiles))
		var x := feet.x + side * randi_range(int(near), int(far))
		if data.swims:
			var spot := _water_spot(x, feet.y, data)
			if spot != Vector2.INF:
				return spot
			continue
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
			# Land creatures don't start out under water (Phase 86).
			if room and world.voxels and world.voxels.liquid_at(world.tile_to_world(Vector2i(x, y - 1)) + Vector2(4.0, 4.0)):
				room = false
			if room and not world.near_spawn_safe(t) and not _in_view(world.tile_to_world(t) + Vector2(4.0, 0.0), data):
				var at := world.tile_to_world(world.wrap_tile(t)) + Vector2(4.0, 0.0)
				if data.flies:
					# Up in the air: as high as there's room for, up to 6 tiles.
					var up := randi_range(2, 6)
					for k in range(1, up + 1):
						if world.is_solid(Vector2i(t.x, t.y - k - 1)):
							up = k
							break
					at.y -= up * World.TILE
				return at
			break
	return Vector2.INF


## Half the visible area in tiles (bigger when zoomed out).
## A fish's spot: a random tile full of water in column x (near the player's height).
func _water_spot(x: int, around_y: int, data: EnemyData) -> Vector2:
	var found: Array[Vector2i] = []
	for y in range(around_y - 40, around_y + 40):
		var t := world.wrap_tile(Vector2i(x, y))
		if world.voxels.count_in(t, &"water") + world.voxels.count_in(t, &"salt_water") == VoxelLayer.CELLS:
			found.append(t)
	if found.is_empty():
		return Vector2.INF
	var t: Vector2i = found[randi() % found.size()]
	var pos := world.tile_to_world(t) + Vector2(4.0, 7.0)
	if _in_view(pos, data):
		return Vector2.INF
	return pos


func view_half_tiles() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	var scale := vp.get_canvas_transform().get_scale()
	return vp.get_visible_rect().size / (scale * 2.0 * World.TILE)


## True if an enemy standing at `pos` (unwrapped px, feet) would be on screen (plus margin).
func _in_view(pos: Vector2, data: EnemyData) -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var r := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	r = r.grow(view_margin_tiles * World.TILE)
	return r.intersects(Rect2(pos - Vector2(data.size.x * 0.5, data.size.y), data.size))


## Enemies that stay beyond despawn_tiles for despawn_seconds are removed (no loot).
func _despawn_far() -> void:
	var p := world.player
	var delta := get_process_delta_time()
	var view := view_half_tiles() + Vector2.ONE * view_margin_tiles
	var lim := Vector2(maxf(despawn_tiles, view.x), maxf(despawn_tiles_vertical, view.y)) * World.TILE
	for e in world.enemies():
		var dx := absf(e._wrapped_dx(p.global_position.x))
		var dy := absf(e.global_position.y - p.global_position.y)
		if dx > lim.x or dy > lim.y:
			e.far_for += delta
			if e.far_for >= despawn_seconds:
				e.queue_free()
		else:
			e.far_for = 0.0
