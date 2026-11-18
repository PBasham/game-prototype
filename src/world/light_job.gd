class_name LightJob
extends RefCounted
## Computes the light map for a chunk-aligned tile rectangle as plain data, so it can
## run on a worker thread. LightMap captures the chunks' tile arrays on the main thread
## (copy-on-write, so later edits don't touch this copy) and uploads the result.
##
## Open sky (no block, no wall) is fully lit. Light fades by `open_falloff` per tile
## through air and walls. Sunlight soaks down into the ground by `solid_falloff` per
## block, but going sideways or up into a block costs `solid_side_falloff`, and coming
## out of a block into an enclosed space (a tile with a background wall: a room, a
## cave) costs `indoors_falloff`. So the sun lights the top of the ground but doesn't
## shine through a house's walls or roof. Objects that block movement (closed doors)
## block light like blocks.
## Light sources (torches: tile objects with a light_radius) add colored light that
## fades to nothing at their radius through air, faster through blocks. The result is
## RGB: white sky light plus the sources' colors.

const SIZE := ChunkData.SIZE

# --- inputs ---
## Tile rectangle, chunk-aligned, unwrapped.
var rect: Rect2i
## Chunks covering `rect`, row-major. An empty array = not generated yet (dark).
var blocks: Array[PackedInt32Array] = []
var walls: Array[PackedInt32Array] = []
var objects: Array[PackedInt32Array] = []
## Per object id: r, g, b, radius (radius 0 = gives no light).
var emitters := PackedFloat32Array()
## Fraction of a source's reach used up per tile through solid blocks, relative to air.
var source_solid_factor := 3.0
## 1 where a block id is solid (index = block id).
var solid := PackedByteArray()
var ambient := 0.16
## Sky light color and brightness (WorldClock.sun_light()): multiplies sunlight.
var sky := Color.WHITE
var open_falloff := 0.06
var solid_falloff := 0.1
var solid_side_falloff := 0.5
var indoors_falloff := 1.0
## 1 where an object id blocks light (closed doors).
var object_solid := PackedByteArray()

# --- outputs ---
## rect.size.x * rect.size.y * 3 bytes, FORMAT_RGB8.
var bytes := PackedByteArray()
var usec := 0
var task := -1


func run() -> void:
	var t := Time.get_ticks_usec()
	var w := rect.size.x
	var h := rect.size.y
	var cols := w / SIZE
	var light := PackedFloat32Array()
	light.resize(w * h)

	# Seed: sky tiles are lit. Flags per tile: solid (blocks and closed doors), walled.
	var solid_at := PackedByteArray()
	var walled := PackedByteArray()
	solid_at.resize(w * h)
	solid_at.fill(1)  # not generated yet: dark
	walled.resize(w * h)
	for k in blocks.size():
		var cb := blocks[k]
		if cb.is_empty():
			continue
		var cw := walls[k]
		var co := objects[k] if k < objects.size() else PackedInt32Array()
		var base := (k / cols) * SIZE * w + (k % cols) * SIZE
		for ly in SIZE:
			var row := base + ly * w
			var src := ly * SIZE
			for lx in SIZE:
				var b := cb[src + lx]
				var o := co[src + lx] if not co.is_empty() else 0
				var is_solid := b < 0 or (b > 0 and solid[b] == 1) or (o > 0 and o < object_solid.size() and object_solid[o] == 1)
				solid_at[row + lx] = 1 if is_solid else 0
				if cw[src + lx] != 0:
					walled[row + lx] = 1
				elif not is_solid:
					light[row + lx] = 1.0

	# Sweep passes (left/up, then right/down), twice: close to a full flood fill. The
	# cost of moving into a tile depends on direction (down into a block is cheap, sideways
	# or up is not) and on leaving a block into a walled space.
	for _round in 2:
		for y in h:
			var row := y * w
			for x in w:
				var i := row + x
				var v := light[i]
				if x > 0:
					v = maxf(v, light[i - 1] - _cost(solid_at, walled, i, i - 1, false))
				if y > 0:
					v = maxf(v, light[i - w] - _cost(solid_at, walled, i, i - w, true))
				light[i] = v
		for y in range(h - 1, -1, -1):
			var row := y * w
			for x in range(w - 1, -1, -1):
				var i := row + x
				var v := light[i]
				if x < w - 1:
					v = maxf(v, light[i + 1] - _cost(solid_at, walled, i, i + 1, false))
				if y < h - 1:
					v = maxf(v, light[i + w] - _cost(solid_at, walled, i, i + w, false))
				light[i] = v

	var colored := _sources(w, h, cols)

	bytes.resize(w * h * 3)
	for i in w * h:
		for ch in 3:
			var l: float = light[i] * sky[ch]
			if not colored.is_empty():
				l += (colored[ch] as PackedFloat32Array)[i]
			l = clampf(l, 0.0, 1.0)
			l = l * l * (3.0 - 2.0 * l)
			bytes[i * 3 + ch] = int((ambient + (1.0 - ambient) * l) * 255.0 + 0.5)
	usec = Time.get_ticks_usec() - t


## Sunlight cost of moving from tile `from` into tile `to` (`down`: from above).
func _cost(solid_at: PackedByteArray, walled: PackedByteArray, to: int, from: int, down: bool) -> float:
	if solid_at[to] == 1:
		return solid_falloff if down else solid_side_falloff
	if walled[to] == 1 and solid_at[from] == 1:
		return indoors_falloff
	return open_falloff


## Light from sources, one array per color channel (empty if there are none). Each
## source seeds its radius at its tile and loses 1 per tile through air
## (source_solid_factor per tile through solid blocks), so it reaches its radius; the
## brightness that leaves is then tinted by the source's color. Sources are grouped by
## color (one sweep per color), so mixed colors blend instead of splitting into rings.
func _sources(w: int, h: int, cols: int) -> Array:
	var by_color: Dictionary[Color, Array] = {}  # color -> [x, y, radius]
	for k in objects.size():
		var co := objects[k]
		if co.is_empty():
			continue
		var base := Vector2i((k % cols) * SIZE, (k / cols) * SIZE)
		for li in co.size():
			var id := co[li]
			if id > 0 and id * 4 + 3 < emitters.size() and emitters[id * 4 + 3] > 0.0:
				var c := Color(emitters[id * 4], emitters[id * 4 + 1], emitters[id * 4 + 2])
				if not by_color.has(c):
					by_color[c] = []
				by_color[c].append(Vector3(base.x + li % SIZE, base.y + li / SIZE, emitters[id * 4 + 3]))
	if by_color.is_empty():
		return []
	# Cost per tile: 1 through air, more through solid blocks.
	var cost := PackedFloat32Array()
	cost.resize(w * h)
	cost.fill(source_solid_factor)
	for k in blocks.size():
		var cb := blocks[k]
		if cb.is_empty():
			continue
		var co := objects[k] if k < objects.size() else PackedInt32Array()
		var base := (k / cols) * SIZE * w + (k % cols) * SIZE
		for li in SIZE * SIZE:
			var b := cb[li]
			var o := co[li] if not co.is_empty() else 0
			var blocked := b < 0 or (b > 0 and solid[b] == 1) or (o > 0 and o < object_solid.size() and object_solid[o] == 1)
			if not blocked:
				cost[base + (li / SIZE) * w + li % SIZE] = 1.0
	# (Packed arrays are values: fill local ones, then hand them out.)
	var r := PackedFloat32Array()
	var g := PackedFloat32Array()
	var b2 := PackedFloat32Array()
	r.resize(w * h)
	g.resize(w * h)
	b2.resize(w * h)
	for c: Color in by_color:
		var reach := PackedFloat32Array()
		reach.resize(w * h)
		var max_r := 1.0
		for sd: Vector3 in by_color[c]:
			var i := int(sd.y) * w + int(sd.x)
			reach[i] = maxf(reach[i], sd.z)
			max_r = maxf(max_r, sd.z)
		_sweep(reach, cost, w, h)
		for i in w * h:
			if reach[i] <= 0.0:
				continue
			# Bright for the inner half, then fading out to the edge of the radius.
			var b := clampf(reach[i] / (max_r * 0.55), 0.0, 1.0)
			r[i] += b * c.r
			g[i] += b * c.g
			b2[i] += b * c.b
	return [r, g, b2]


## Two-pass distance-style sweep (like the sky light), twice.
func _sweep(v: PackedFloat32Array, cost: PackedFloat32Array, w: int, h: int) -> void:
	for _round in 2:
		for y in h:
			var row := y * w
			for x in w:
				var i := row + x
				var c := cost[i]
				var best := v[i]
				if x > 0:
					best = maxf(best, v[i - 1] - c)
				if y > 0:
					best = maxf(best, v[i - w] - c)
				v[i] = best
		for y in range(h - 1, -1, -1):
			var row := y * w
			for x in range(w - 1, -1, -1):
				var i := row + x
				var c := cost[i]
				var best := v[i]
				if x < w - 1:
					best = maxf(best, v[i + 1] - c)
				if y < h - 1:
					best = maxf(best, v[i + w] - c)
				v[i] = best
