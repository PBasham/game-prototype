class_name LightJob
extends RefCounted
## Computes the light map for a chunk-aligned tile rectangle as plain data, so it can
## run on a worker thread. LightMap captures the chunks' tile arrays on the main thread
## (copy-on-write, so later edits don't touch this copy) and uploads the result.
##
## Open sky (no block, no wall) is fully lit. Light fades by `open_falloff` per tile
## through air and walls and by `solid_falloff` per tile through solid blocks.

const SIZE := ChunkData.SIZE

# --- inputs ---
## Tile rectangle, chunk-aligned, unwrapped.
var rect: Rect2i
## Chunks covering `rect`, row-major. An empty array = not generated yet (dark).
var blocks: Array[PackedInt32Array] = []
var walls: Array[PackedInt32Array] = []
## 1 where a block id is solid (index = block id).
var solid := PackedByteArray()
var ambient := 0.16
var open_falloff := 0.06
var solid_falloff := 0.1

# --- outputs ---
## rect.size.x * rect.size.y bytes, FORMAT_L8.
var bytes := PackedByteArray()
var usec := 0
var task := -1


func run() -> void:
	var t := Time.get_ticks_usec()
	var w := rect.size.x
	var h := rect.size.y
	var cols := w / SIZE
	var light := PackedFloat32Array()
	var cost := PackedFloat32Array()
	light.resize(w * h)
	cost.resize(w * h)
	cost.fill(solid_falloff)

	# Seed: sky tiles are lit; each tile's falloff depends on whether it's solid.
	for k in blocks.size():
		var cb := blocks[k]
		if cb.is_empty():
			continue
		var cw := walls[k]
		var base := (k / cols) * SIZE * w + (k % cols) * SIZE
		for ly in SIZE:
			var row := base + ly * w
			var src := ly * SIZE
			for lx in SIZE:
				var b := cb[src + lx]
				var is_solid := b < 0 or (b > 0 and solid[b] == 1)
				if not is_solid:
					cost[row + lx] = open_falloff
					if cw[src + lx] == 0:
						light[row + lx] = 1.0

	# Sweep passes (left/up, then right/down), twice: close to a full flood fill.
	for _round in 2:
		for y in h:
			var row := y * w
			for x in w:
				var i := row + x
				var v := light[i]
				var c := cost[i]
				if x > 0:
					v = maxf(v, light[i - 1] - c)
				if y > 0:
					v = maxf(v, light[i - w] - c)
				light[i] = v
		for y in range(h - 1, -1, -1):
			var row := y * w
			for x in range(w - 1, -1, -1):
				var i := row + x
				var v := light[i]
				var c := cost[i]
				if x < w - 1:
					v = maxf(v, light[i + 1] - c)
				if y < h - 1:
					v = maxf(v, light[i + w] - c)
				light[i] = v

	bytes.resize(w * h)
	for i in w * h:
		var l := clampf(light[i], 0.0, 1.0)
		l = l * l * (3.0 - 2.0 * l)
		bytes[i] = int((ambient + (1.0 - ambient) * l) * 255.0 + 0.5)
	usec = Time.get_ticks_usec() - t
