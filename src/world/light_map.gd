class_name LightMap
extends Sprite2D
## Tile-level lighting over the loaded area, drawn as a smooth multiply overlay.
##
## Like Terraria's: open sky (no block, no background wall) is fully lit, and light is
## multiplied by `air_decay` per tile through air and walls and by `solid_decay` per
## tile through blocks, so sunlight dies a few blocks into the ground and caves with no
## light are black. Terraria's numbers are 0.91 and 0.56 per tile, but its tiles are
## bigger next to the player (3 tall vs our 8), so ours are those to the power 3/8. Recomputed (on a worker thread, see LightJob) when
## chunks load or a block changes.
## Light sources (tile objects with a light_radius, like torches, and moving ones like
## the Light Orb, World.dynamic_lights) add colored light, so the overlay is RGB.

## Brightness everything gets even with no light (0 = unlit caves are black).
@export_range(0.0, 1.0) var ambient := 0.0
## Share of light kept per tile through air and walls (Terraria 0.91 per its tile).
@export_range(0.5, 1.0) var air_decay := 0.965
## Sunlight through air deep under the natural ground (caves, shafts): kept per tile.
## Lower than air_decay so daylight from an entrance dies out a short way in instead of
## faintly lighting whole cave systems. Torches and other lights aren't affected.
@export_range(0.5, 1.0) var cave_air_decay := 0.86
## How far below the natural ground (tiles) air counts as cave air.
@export var cave_air_below_tiles := 4
## Share kept per tile through blocks (Terraria 0.56): sunlight lights about 3 blocks
## down well and is gone by about 10.
@export_range(0.0, 1.0) var solid_decay := 0.8
## Share of light kept coming out of a block into a walled space (a room or a cave):
## 0 = none, so the sun doesn't shine through a roof into a house.
@export_range(0.0, 1.0) var indoors_factor := 0.0
## Light sources fade this many times faster through blocks than through air
## (Terraria's torch: about 42 tiles of air vs 7 of blocks).
@export var source_solid_factor := 6.0
## Share of the sky's light a background wall above the natural ground gets on its own
## (a built room, a wall with no roof), so walls aren't dark in daylight. 0 = Terraria.
@export_range(0.0, 1.0) var walled_sky := 0.4
## Torches and other lights: their brightness is raised to this power, so they stay
## bright further out before fading (1 = plain falloff, lower = brighter rooms).
@export_range(0.2, 1.0) var source_curve := 0.6
## Recompute when the sky light (day and night) changes by more than this.
@export var sky_change := 0.012
## Open air (no block, no wall) is sky only down to this many tiles below the natural
## ground (the generator's surface): a hole dug deeper gets light only as it spreads in
## from above, instead of every dug-out tile shining like open sky.
@export var sky_depth_tiles := 0
## Minimum seconds between recomputes.
@export var min_interval := 0.12
## Each new light map fades in over the last one over this long, so moving lights
## glide instead of jumping a tile at a time (0 = snap).
@export var fade_seconds := 0.14
var _outside: Node2D
var _image: Image
var _prev: ImageTexture
var _fade := 1.0

var world: World
var _dirty := true
var _cooldown := 0.0
var _job: LightJob
var _texture: ImageTexture
## Share of daylight the Dark Forest's canopy keeps out (0.5 = half as bright).
@export_range(0.0, 1.0) var dark_forest_shade := 0.5
var _last_sky := Color.WHITE
## The tile rect the shown light covers. Outside it (moving fast, zoomed out) a rough
## stand-in is drawn: the sky's light above the ground, dark below.
var _shown_rect := Rect2i()
## Tiles of stand-in light drawn around the real light map.
@export var outside_margin_tiles := 160
## Columns per stand-in strip (coarser = cheaper).
@export var outside_strip_tiles := 4


func _ready() -> void:
	# Snaps to the loaded area when it changes; never slides between physics ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	centered = false
	scale = Vector2(World.TILE, World.TILE)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 50
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/world/light_map.gdshader")
	material = mat
	# The rough stand-in light around the map draws on a child with a plain multiply.
	_outside = Node2D.new()
	_outside.name = "Outside"
	var omat := CanvasItemMaterial.new()
	omat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_outside.material = omat
	add_child(_outside)
	_outside.draw.connect(func() -> void: _draw_outside(_outside))


func mark_dirty() -> void:
	_dirty = true


## The sky light for this moment (white at noon, dim blue at night).
func _sky() -> Color:
	return world.clock.sun_light() if world and world.clock else Color.WHITE


func _process(delta: float) -> void:
	_cooldown -= delta
	if _fade < 1.0:
		_fade = minf(_fade + delta / maxf(fade_seconds, 0.001), 1.0)
		(material as ShaderMaterial).set_shader_parameter(&"fade", _fade)
	if _job != null and WorkerThreadPool.is_task_completed(_job.task):
		WorkerThreadPool.wait_for_task_completion(_job.task)
		PerfStats.add("light rebuild (worker)", _job.usec)
		_apply(_job)
		_job = null
	var sky := _sky()
	if absf(sky.r - _last_sky.r) + absf(sky.g - _last_sky.g) + absf(sky.b - _last_sky.b) > sky_change:
		_dirty = true
	if world and world.renderer and world.renderer.loaded_tile_rect() != _shown_rect:
		_dirty = true  # more of the world came into view: light it soon
	if _dirty and _job == null and _cooldown <= 0.0:
		rebuild()


## Starts a recompute on a worker thread; the result shows a few frames later.
func rebuild() -> void:
	var job := _make_job()
	if job == null:
		return
	job.task = WorkerThreadPool.add_task(job.run, false, "light map")
	_job = job


## Recomputes on this thread and shows it immediately (used at spawn).
func rebuild_now() -> void:
	wait()
	var job := _make_job()
	if job == null:
		return
	job.run()
	PerfStats.add("light rebuild (main)", job.usec)
	_apply(job)


## Natural ground height of a column (the generator's surface), cached.
var _surfaces: Dictionary[int, int] = {}


## How much daylight reaches open ground in column x: less under the Dark Forest.
func _sky_scale(x: int) -> float:
	if world == null or world.generator == null:
		return 1.0
	return 1.0 - dark_forest_shade * world.generator.dark_forest_at(world.data.wrap_x(x))


func _surface(x: int) -> int:
	var wx := posmod(x, world.data.width)
	if not _surfaces.has(wx):
		_surfaces[wx] = world.generator.surface_at(wx) if world.generator else 0
	return _surfaces[wx]


## Blocks until a running recompute is done (on world unload).
func wait() -> void:
	if _job != null:
		WorkerThreadPool.wait_for_task_completion(_job.task)
		_job = null


## Captures the loaded area's tile arrays (main thread, cheap: no per-tile work).
func _make_job() -> LightJob:
	_dirty = false
	_cooldown = min_interval
	var rect := world.renderer.loaded_tile_rect()
	if rect.size.x <= 0:
		return null
	var job := LightJob.new()
	job.rect = rect
	job.sky_floor.resize(rect.size.x)
	job.sky_scale.resize(rect.size.x)
	for x in rect.size.x:
		job.sky_floor[x] = _surface(rect.position.x + x) + sky_depth_tiles - rect.position.y
		job.sky_scale[x] = _sky_scale(rect.position.x + x)
	job.ambient = ambient
	_last_sky = _sky()
	job.sky = _last_sky
	job.air_decay = air_decay
	job.cave_air_decay = cave_air_decay
	job.cave_air_below = cave_air_below_tiles
	job.solid_decay = solid_decay
	job.indoors_factor = indoors_factor
	job.object_solid.resize(world.objects.size())
	job.object_h.resize(world.objects.size())
	for id in range(1, world.objects.size()):
		var od := world.objects.def(id) as ObjectDef
		if od and od.blocks_movement:
			job.object_solid[id] = od.width_tiles
			job.object_h[id] = od.height_tiles
	job.source_solid_factor = source_solid_factor
	job.walled_sky = walled_sky
	job.source_curve = source_curve
	for l in world.dynamic_lights():
		job.extra.append([Vector2(l[0]) - Vector2(rect.position), l[1], l[2]])
	job.emitters.resize(world.objects.size() * 4)
	for id in range(1, world.objects.size()):
		var def := world.objects.def(id) as ObjectDef
		if def and def.light_radius > 0.0:
			job.emitters[id * 4] = def.light_color.r
			job.emitters[id * 4 + 1] = def.light_color.g
			job.emitters[id * 4 + 2] = def.light_color.b
			job.emitters[id * 4 + 3] = def.light_radius
	var table := world.blocks.collision_table()
	job.solid.resize(table.size())
	for i in table.size():
		job.solid[i] = 1 if table[i] == TileDef.Collision.SOLID and not world.blocks.def(i).see_through else 0
	job.clear_walls.resize(world.walls.size())
	for i in range(1, world.walls.size()):
		job.clear_walls[i] = 1 if world.walls.def(i).see_through else 0
	var first := rect.position / ChunkData.SIZE
	var count := rect.size / ChunkData.SIZE
	for cy in count.y:
		for cx in count.x:
			var chunk := world.data.peek_chunk(first + Vector2i(cx, cy))
			job.blocks.append(chunk.blocks if chunk else PackedInt32Array())
			job.walls.append(chunk.walls if chunk else PackedInt32Array())
			job.objects.append(chunk.objects if chunk else PackedInt32Array())
	return job


## Around the real light map: sky light above the natural ground, dark below, so
## ground that comes into view before the light catches up isn't lit up bright.
func _draw_outside(c: CanvasItem) -> void:
	if world == null or _shown_rect.size.x <= 0:
		return
	var w := _shown_rect.size.x
	var h := _shown_rect.size.y
	var m := outside_margin_tiles
	var dark := Color(ambient, ambient, ambient)
	var sky := _last_sky
	var step := maxi(outside_strip_tiles, 1)
	# Local coords are tiles from the map's corner. Left and right of it, column strips.
	for x in range(-m, w + m, step):
		var inside_x := x >= 0 and x < w
		var ground := _surface(_shown_rect.position.x + x) - _shown_rect.position.y
		var k := _sky_scale(_shown_rect.position.x + x)
		var col_sky := Color(ambient, ambient, ambient).lerp(sky, k) if k < 1.0 else sky
		var top := -m
		var bottom := h + m
		if inside_x:
			# Above and below the map only.
			_strip(c, x, step, top, 0, ground, col_sky, dark)
			_strip(c, x, step, h, bottom, ground, col_sky, dark)
		else:
			_strip(c, x, step, top, bottom, ground, col_sky, dark)


## A column strip from y0 to y1 (tiles): sky light down to `ground`, dark under it.
func _strip(c: CanvasItem, x: int, w: int, y0: int, y1: int, ground: int, sky: Color, dark: Color) -> void:
	var split := clampi(ground, y0, y1)
	if split > y0:
		c.draw_rect(Rect2(x, y0, w, split - y0), sky)
	if y1 > split:
		c.draw_rect(Rect2(x, split, w, y1 - split), dark)


## Main thread: uploads the result and moves the overlay onto its rectangle.
func _apply(job: LightJob) -> void:
	var t := Time.get_ticks_usec()
	var w := job.rect.size.x
	var h := job.rect.size.y
	var image := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, job.bytes)
	var mat := material as ShaderMaterial
	if _image != null and fade_seconds > 0.0 and mat:
		# Fade from what was shown (lined up by where the old map's corner was).
		if _prev == null or _prev.get_size() != Vector2(_image.get_size()):
			_prev = ImageTexture.create_from_image(_image)
		else:
			_prev.update(_image)
		mat.set_shader_parameter(&"prev_tex", _prev)
		mat.set_shader_parameter(&"prev_size", Vector2(_image.get_size()))
		mat.set_shader_parameter(&"cur_size", Vector2(w, h))
		mat.set_shader_parameter(&"shift", Vector2(job.rect.position - _shown_rect.position))
		_fade = 0.0
		mat.set_shader_parameter(&"fade", 0.0)
	_image = image
	if _texture == null or _texture.get_size() != Vector2(w, h):
		_texture = ImageTexture.create_from_image(image)
		texture = _texture
	else:
		_texture.update(image)
	position = Vector2(job.rect.position * World.TILE)
	_shown_rect = job.rect
	_outside.queue_redraw()
	PerfStats.add("light apply (main)", Time.get_ticks_usec() - t)
