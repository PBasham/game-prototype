class_name LightJob
extends RefCounted
## Computes the light map for a chunk-aligned tile rectangle as plain data, so it can
## run on a worker thread. LightMap captures the chunks' tile arrays on the main thread
## (copy-on-write, so later edits don't touch this copy) and uploads the result.
##
## Like Terraria's: light is multiplied by `air_decay` for every tile it crosses through
## air and walls and by `solid_decay` through blocks, so it fades smoothly and dies a few
## blocks into the ground. Open sky (no block, no wall, above the natural ground: see
## `sky_floor`) is fully lit. Coming out of a
## block into an enclosed space (a tile with a background wall: a room, a cave) keeps
## only `indoors_factor` of it, so the sun lights the top of the ground but doesn't
## shine through a house's walls or roof. Objects that block movement (closed doors)
## block light like blocks. Nothing lit = black (plus `ambient`).
## Light sources (torches: tile objects with a light_radius) add colored light that
## fades the same way, scaled so it's down to about a tenth at its radius through air;
## blocks eat it `source_solid_factor` times faster. The result is RGB: white sky light
## plus the sources' colors.

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
var source_solid_factor := 6.0
var walled_sky := 0.0
var source_curve := 1.0
## Moving lights: [position in tiles from the rect's corner (Vector2), radius, color].
var extra: Array[Array] = []
## 1 where a block id is solid (index = block id).
var solid := PackedByteArray()
## Wall ids that don't count as walls for sunlight (Glass Wall).
var clear_walls := PackedByteArray()
var ambient := 0.0
## Sky light color and brightness (WorldClock.sun_light()): multiplies sunlight.
var sky := Color.WHITE
var air_decay := 0.965
var solid_decay := 0.8
var indoors_factor := 0.0
## Per column (relative to rect): rows above this (relative to rect) can be open sky;
## air at or below it (dug out underground) isn't, it only gets light that spreads in.
var sky_floor := PackedInt32Array()
## Per column: how bright open sky is there (1 = full daylight; the Dark Forest's
## canopy lets less through). Empty = 1 everywhere.
var sky_scale := PackedFloat32Array()
## Per object id that blocks light (closed doors): its footprint width and height in
## tiles (0 = doesn't block). The id is only stored on the object's anchor (bottom-left)
## tile; the rest of the footprint is "filler", so the whole footprint is marked here.
var object_solid := PackedByteArray()
var object_h := PackedByteArray()

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
	var blocked_by_object := PackedByteArray()
	blocked_by_object.resize(w * h)
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
				var is_solid := b < 0 or (b > 0 and solid[b] == 1)
				solid_at[row + lx] = 1 if is_solid else 0
				if o > 0 and o < object_solid.size() and object_solid[o] > 0:
					# A blocking object: mark its whole footprint (it grows up and right).
					for dy in object_h[o]:
						for dx in object_solid[o]:
							var tx := (k % cols) * SIZE + lx + dx
							var ty := (k / cols) * SIZE + ly - dy
							if tx < w and ty >= 0:
								blocked_by_object[ty * w + tx] = 1
				var wid := cw[src + lx]
				if wid != 0 and (wid >= clear_walls.size() or clear_walls[wid] == 0):
					walled[row + lx] = 1
					if not is_solid and walled_sky > 0.0:
						var wx := (k % cols) * SIZE + lx
						var wy := (k / cols) * SIZE + ly
						if sky_floor.is_empty() or wy < sky_floor[wx]:
							light[row + lx] = walled_sky * (1.0 if sky_scale.is_empty() else sky_scale[wx])
				elif not is_solid:
					var tx := (k % cols) * SIZE + lx
					var ty := (k / cols) * SIZE + ly
					if sky_floor.is_empty() or ty < sky_floor[tx]:
						light[row + lx] = 1.0 if sky_scale.is_empty() else sky_scale[tx]
	for i in w * h:
		if blocked_by_object[i] == 1:
			solid_at[i] = 1
			if walled[i] == 0:
				light[i] = 0.0  # a closed door isn't open sky

	# Sweep passes (left/up, then right/down), twice: close to a full flood fill. Each
	# step multiplies by the decay of the tile it moves into.
	var mult := PackedFloat32Array()
	mult.resize(w * h)
	for i in w * h:
		mult[i] = solid_decay if solid_at[i] == 1 else air_decay
	for _round in 2:
		for y in h:
			var row := y * w
			for x in w:
				var i := row + x
				var v := light[i]
				if x > 0:
					v = maxf(v, light[i - 1] * _step(mult, solid_at, walled, i, i - 1))
				if y > 0:
					v = maxf(v, light[i - w] * _step(mult, solid_at, walled, i, i - w))
				light[i] = v
		for y in range(h - 1, -1, -1):
			var row := y * w
			for x in range(w - 1, -1, -1):
				var i := row + x
				var v := light[i]
				if x < w - 1:
					v = maxf(v, light[i + 1] * _step(mult, solid_at, walled, i, i + 1))
				if y < h - 1:
					v = maxf(v, light[i + w] * _step(mult, solid_at, walled, i, i + w))
				light[i] = v

	var colored := _sources(w, h, cols, solid_at)

	bytes.resize(w * h * 3)
	for i in w * h:
		for ch in 3:
			var l: float = light[i] * sky[ch]
			if not colored.is_empty():
				l += (colored[ch] as PackedFloat32Array)[i]
			l = clampf(l, 0.0, 1.0)
			bytes[i * 3 + ch] = int((ambient + (1.0 - ambient) * l) * 255.0 + 0.5)
	usec = Time.get_ticks_usec() - t


## How much sunlight survives moving from tile `from` into tile `to`.
func _step(mult: PackedFloat32Array, solid_at: PackedByteArray, walled: PackedByteArray, to: int, from: int) -> float:
	if walled[to] == 1 and solid_at[to] == 0 and solid_at[from] == 1:
		return indoors_factor * mult[to]
	return mult[to]


## Light from sources, one array per color channel (empty if there are none). Each
## source starts at full brightness and is multiplied per tile by a decay that leaves
## about a tenth at its radius through air (that decay to the power source_solid_factor
## through solid blocks), then tinted by the source's color. Sources are grouped by
## radius and color (one sweep each), so mixed colors blend instead of splitting.
func _sources(w: int, h: int, cols: int, solid_at: PackedByteArray) -> Array:
	var groups: Dictionary[Vector4, Array] = {}  # (r, g, b, radius) -> tiles
	for k in objects.size():
		var co := objects[k]
		if co.is_empty():
			continue
		var base := Vector2i((k % cols) * SIZE, (k / cols) * SIZE)
		for li in co.size():
			var id := co[li]
			if id > 0 and id * 4 + 3 < emitters.size() and emitters[id * 4 + 3] > 0.0:
				var key := Vector4(emitters[id * 4], emitters[id * 4 + 1], emitters[id * 4 + 2], emitters[id * 4 + 3])
				if not groups.has(key):
					groups[key] = []
				groups[key].append([base + Vector2i(li % SIZE, li / SIZE), 1.0])
	for l: Array in extra:
		# A moving light between tiles: shared over the four nearest, so it glides.
		var at: Vector2 = l[0] - Vector2(0.5, 0.5)
		var t0 := Vector2i(floori(at.x), floori(at.y))
		var f := at - Vector2(t0)
		var c: Color = l[2]
		var key := Vector4(c.r, c.g, c.b, float(l[1]))
		if not groups.has(key):
			groups[key] = []
		for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var t := t0 + d
			if t.x < 0 or t.y < 0 or t.x >= w or t.y >= h:
				continue
			var wx := f.x if d.x == 1 else 1.0 - f.x
			var wy := f.y if d.y == 1 else 1.0 - f.y
			# Brightest at the nearest tile; the others a little dimmer by distance.
			var weight := pow(wx * wy, 0.35) if wx * wy > 0.0 else 0.0
			if weight > 0.01:
				groups[key].append([t, weight])
	if groups.is_empty():
		return []
	# (Packed arrays are values: fill local ones, then hand them out.)
	var r := PackedFloat32Array()
	var g := PackedFloat32Array()
	var b2 := PackedFloat32Array()
	r.resize(w * h)
	g.resize(w * h)
	b2.resize(w * h)
	var mult := PackedFloat32Array()
	mult.resize(w * h)
	for key: Vector4 in groups:
		var air := pow(0.1, 1.0 / maxf(key.w, 1.0))
		var solid_m := pow(air, source_solid_factor)
		for i in w * h:
			mult[i] = solid_m if solid_at[i] == 1 else air
		var v := PackedFloat32Array()
		v.resize(w * h)
		for e: Array in groups[key]:
			var t: Vector2i = e[0]
			v[t.y * w + t.x] = maxf(v[t.y * w + t.x], float(e[1]))
		_sweep(v, mult, w, h)
		for i in w * h:
			var bright := v[i]
			if bright <= 0.01:
				continue
			bright = pow(bright, source_curve)
			r[i] += bright * key.x
			g[i] += bright * key.y
			b2[i] += bright * key.z
	return [r, g, b2]


## Two-pass multiplicative sweep (like the sky light), twice.
func _sweep(v: PackedFloat32Array, mult: PackedFloat32Array, w: int, h: int) -> void:
	for _round in 2:
		for y in h:
			var row := y * w
			for x in w:
				var i := row + x
				var m := mult[i]
				var best := v[i]
				if x > 0:
					best = maxf(best, v[i - 1] * m)
				if y > 0:
					best = maxf(best, v[i - w] * m)
				v[i] = best
		for y in range(h - 1, -1, -1):
			var row := y * w
			for x in range(w - 1, -1, -1):
				var i := row + x
				var m := mult[i]
				var best := v[i]
				if x < w - 1:
					best = maxf(best, v[i + 1] * m)
				if y < h - 1:
					best = maxf(best, v[i + w] * m)
				v[i] = best
