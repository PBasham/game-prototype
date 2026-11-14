extends SceneTree
## Generates placeholder tile art (original), plus a mock scene to judge it.
##
## Usage (from the project folder):
##   godot --headless --path . --script res://tools/generate_tiles.gd -- --style=earthy
##   godot --headless --path . --script res://tools/generate_tiles.gd -- --style=deep --out=/tmp/x --preview
##
## How it's built:
## - Every material is a seamless 64x64 texture with hue-shifted color ramps (cool
##   shadows, warm highlights). A block shows the 8x8 piece of that texture at its world
##   position (x % 8, y % 8), so rocks, layers and grain flow across blocks.
## - Edges are added per tile from a neighbor mask: dark border where a block meets
##   air or a background wall, lit top edge, shaded bottom edge. Blocks stay square.
##
## Atlas layout (see assets/ASSETS.md): one row per material; column = mask * 64 + piece,
## piece = (x % 8) + (y % 8) * 8. Mask bits: 1 up, 2 right, 4 down, 8 left (bit = neighbor).

const T := 8
const TEX := 64
const PIECES := 64
const SIDE := TEX / 8  ## pieces per texture side
const MASKS := 16
const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8

## Block materials. Order = atlas row; must match atlas_row in data/tiles/*.tres.
const BLOCKS := [
	{"id": "dirt", "base": Color("7a4b2a"), "kind": "dirt"},
	{"id": "grass", "base": Color("7a4b2a"), "kind": "grass", "accent": Color("4f9a3a")},
	{"id": "stone", "base": Color("6f7178"), "kind": "stone"},
	{"id": "sand", "base": Color("cfae6c"), "kind": "sand"},
	{"id": "snow", "base": Color("dfe8f0"), "kind": "snow"},
	{"id": "ice", "base": Color("82c3e3"), "kind": "ice"},
	{"id": "mud", "base": Color("4d3a2e"), "kind": "mud"},
	{"id": "clay", "base": Color("a5573f"), "kind": "clay"},
	{"id": "wood_planks", "base": Color("9a6a3a"), "kind": "planks"},
	{"id": "copper_ore", "base": Color("6f7178"), "kind": "ore", "accent": Color("d0773a")},
	{"id": "iron_ore", "base": Color("6f7178"), "kind": "ore", "accent": Color("b59a86")},
	{"id": "silver_ore", "base": Color("6f7178"), "kind": "ore", "accent": Color("d9e2ea")},
	{"id": "gold_ore", "base": Color("6f7178"), "kind": "ore", "accent": Color("e8b93a")},
	{"id": "arcanite_ore", "base": Color("6f7178"), "kind": "ore", "accent": Color("9257e8")},
	{"id": "wood_platform", "base": Color("9a6a3a"), "kind": "platform"},
	{"id": "rope", "base": Color("bf9a5e"), "kind": "rope"},
]

## Background walls. Order = atlas row in walls.png.
const WALLS := [
	{"id": "dirt_wall", "base": Color("7a4b2a"), "kind": "dirt"},
	{"id": "stone_wall", "base": Color("6f7178"), "kind": "stone"},
	{"id": "wood_wall", "base": Color("9a6a3a"), "kind": "planks"},
	{"id": "sandstone_wall", "base": Color("bf9c5c"), "kind": "clay"},
]

const STYLES := {
	## Natural daylight palette, moderate contrast.
	"earthy": {"sat": 1.0, "val": 1.0, "shift": 1.0, "outline": 0.45, "wall_dark": 0.55, "wall_desat": 0.35, "sky_top": Color("4a86c5"), "sky_low": Color("c4e1ef")},
	## Darker, richer and moodier: deeper shadows, stronger hue shift.
	## Lush forest: saturated greens, warm dirt, small cobble stone, softer outline.
	## Preview renders a lit forest hillside.
	"lush": {"sat": 1.15, "val": 1.0, "shift": 1.3, "outline": 0.4, "wall_dark": 0.6, "wall_desat": 0.3,
		"sky_top": Color("9fd0d8"), "sky_low": Color("cfe9c9"), "scene": "forest", "stone_cells": 80, "dirt_fine": true,
		"bases": {"dirt": Color("6e4527"), "grass": Color("6e4527"), "stone": Color("77787c"), "copper_ore": Color("77787c"), "iron_ore": Color("77787c"), "silver_ore": Color("77787c"), "gold_ore": Color("77787c"), "arcanite_ore": Color("77787c")},
		"accents": {"grass": Color("4fb23a")}},
	## Natural: no outlines, organic edges, materials blend; lumpy dirt, pebble stone.
	"natural": {"sat": 0.95, "val": 1.0, "shift": 1.2, "outline": 0.0, "wall_dark": 0.55, "wall_desat": 0.3,
		"sky_top": Color("9fcfd6"), "sky_low": Color("d3ebcb"), "scene": "forest", "compose": true, "stone_cells": 130,
		"bases": {"dirt": Color("85633f"), "grass": Color("85633f"), "mud": Color("5b4532"), "stone": Color("6e7075"), "copper_ore": Color("6e7075"), "iron_ore": Color("6e7075"), "silver_ore": Color("6e7075"), "gold_ore": Color("6e7075"), "arcanite_ore": Color("6e7075")},
		"accents": {"grass": Color("4fae38")}},
	## Natural v2: Patrick's reference palettes, smooth silhouettes, lighter darkness.
	"natural2": {"backdrop": "v2", "sat": 1.0, "val": 1.0, "shift": 1.0, "outline": 0.0, "wall_dark": 0.0, "wall_desat": 0.0,
		"sky_top": Color("9fcfd6"), "sky_low": Color("d3ebcb"), "scene": "forest", "compose": "natural2", "ambient": 0.16,
		"accents": {"grass": Color("42a628")}, "character": "/home/claude/scratch/ase/frames/frame_00.png"},
	## Round 2 variants: between the clumpy and stroke dirt, smooth rounded stone.
	"t1": {"backdrop": "v2", "sat": 1.0, "val": 1.0, "shift": 1.0, "outline": 0.0, "wall_dark": 0.0, "wall_desat": 0.0, "sky_top": Color("9fcfd6"), "sky_low": Color("d3ebcb"), "scene": "forest", "compose": "natural2", "ambient": 0.16, "accents": {"grass": Color("42a628")}, "character": "/home/claude/scratch/ase/frames/frame_00.png", "dirt_mode": "soft_strokes", "dirt_pal": "dirt", "stone_cells": 256, "stone_soft": 0.8, "stone_pal": "stone_soft"},
	"t2": {"backdrop": "v2", "sat": 1.0, "val": 1.0, "shift": 1.0, "outline": 0.0, "wall_dark": 0.0, "wall_desat": 0.0, "sky_top": Color("9fcfd6"), "sky_low": Color("d3ebcb"), "scene": "forest", "compose": "natural2", "ambient": 0.16, "accents": {"grass": Color("42a628")}, "character": "/home/claude/scratch/ase/frames/frame_00.png", "dirt_mode": "clod_strokes", "dirt_pal": "dirt_mid", "stone_cells": 196, "stone_soft": 0.6, "stone_pal": "stone_soft"},
	"t3": {"backdrop": "v2", "sat": 1.0, "val": 1.0, "shift": 1.0, "outline": 0.0, "wall_dark": 0.0, "wall_desat": 0.0, "sky_top": Color("9fcfd6"), "sky_low": Color("d3ebcb"), "scene": "forest", "compose": "natural2", "ambient": 0.16, "accents": {"grass": Color("42a628")}, "character": "/home/claude/scratch/ase/frames/frame_00.png", "dirt_mode": "clods", "dirt_pal": "dirt_warm", "dirt_wall_pal": "dirt_wall_warm", "stone_cells": 256, "stone_soft": 0.7, "stone_pal": "stone"},
	"t4": {"backdrop": "v2", "sat": 1.0, "val": 1.0, "shift": 1.0, "outline": 0.0, "wall_dark": 0.0, "wall_desat": 0.0, "sky_top": Color("9fcfd6"), "sky_low": Color("d3ebcb"), "scene": "forest", "compose": "natural2", "ambient": 0.16, "accents": {"grass": Color("42a628")}, "character": "/home/claude/scratch/ase/frames/frame_00.png", "dirt_mode": "strokes", "dirt_pal": "dirt_mid", "stone_cells": 400, "stone_soft": 0.9, "stone_pal": "stone_soft"},
	"t5": {"backdrop": "v2", "sat": 1.0, "val": 1.0, "shift": 1.0, "outline": 0.0, "wall_dark": 0.0, "wall_desat": 0.0, "sky_top": Color("9fcfd6"), "sky_low": Color("d3ebcb"), "scene": "forest", "compose": "natural2", "ambient": 0.16, "accents": {"grass": Color("42a628")}, "character": "/home/claude/scratch/ase/frames/frame_00.png", "dirt_mode": "clod_strokes", "dirt_pal": "dirt", "stone_cells": 144, "stone_soft": 0.5, "stone_pal": "stone_warm"},
	"deep": {"sat": 1.15, "val": 0.88, "shift": 1.5, "outline": 0.55, "wall_dark": 0.62, "wall_desat": 0.3, "sky_top": Color("2f5f9c"), "sky_low": Color("a9c9de")},
}

var style: Dictionary
var style_name := "earthy"
var wood_variant := "B"


func _init() -> void:
	var out := "res://assets/tiles"
	var preview := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--style="):
			style_name = arg.trim_prefix("--style=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--preview":
			preview = true
		elif arg.begins_with("--wood="):
			wood_variant = arg.trim_prefix("--wood=")
		elif arg == "--export=game":
			_export_game()
			quit()
			return
	if not STYLES.has(style_name):
		push_error("unknown style %s (use %s)" % [style_name, ", ".join(STYLES.keys())])
		quit(1)
		return
	style = STYLES[style_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	var blocks := _build_atlas(BLOCKS, false)
	var walls := _build_atlas(WALLS, true)
	blocks.save_png(out.path_join("blocks.png"))
	walls.save_png(out.path_join("walls.png"))
	if preview:
		if style.get("scene", "") == "forest":
			_save_forest_preview(blocks, walls, out)
		else:
			_save_preview(blocks, walls, out)
	print("tiles: style=%s -> %s" % [style_name, out])
	quit()


# --- color -----------------------------------------------------------------

func _hue_toward(hue: float, target: float, amount: float) -> float:
	var d := fposmod(target - hue + 0.5, 1.0) - 0.5
	return fposmod(hue + d * clampf(amount, 0.0, 1.0), 1.0)


## 7-step ramp, index 0 darkest, 3 = base, 6 lightest. Shadows shift toward blue/violet,
## highlights toward warm yellow.
func ramp(base: Color) -> Array[Color]:
	var shift: float = style.shift
	var out: Array[Color] = []
	for i in 7:
		var t := float(i - 3)
		var hh := base.h
		var ss := base.s * float(style.sat)
		var vv := base.v * float(style.val)
		if t < 0.0:
			hh = _hue_toward(hh, 0.7, -t * 0.045 * shift)
			ss = ss * (1.0 - t * 0.07)
			vv = vv * (1.0 + t * 0.17)
		elif t > 0.0:
			hh = _hue_toward(hh, 0.14, t * 0.04 * shift)
			ss = ss * (1.0 - t * 0.13)
			vv = vv + (1.0 - vv) * t * 0.16
		out.append(Color.from_hsv(hh, clampf(ss, 0.0, 1.0), clampf(vv, 0.0, 1.0)))
	return out


# --- noise (periodic over the 64x64 texture, so it tiles seamlessly) ---------

func h(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 982451653) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65536.0


func pnoise(x: int, y: int, cell: int, s: int) -> float:
	var n := TEX / cell
	var gx := floori(float(x) / cell)
	var gy := floori(float(y) / cell)
	var tx := smoothstep(0.0, 1.0, float(posmod(x, cell)) / cell)
	var ty := smoothstep(0.0, 1.0, float(posmod(y, cell)) / cell)
	var a := lerpf(h(posmod(gx, n), posmod(gy, n), s), h(posmod(gx + 1, n), posmod(gy, n), s), tx)
	var b := lerpf(h(posmod(gx, n), posmod(gy + 1, n), s), h(posmod(gx + 1, n), posmod(gy + 1, n), s), tx)
	return lerpf(a, b, ty)


func fbm(x: int, y: int, s: int) -> float:
	return pnoise(x, y, 32, s) * 0.35 + pnoise(x, y, 16, s + 3) * 0.3 + pnoise(x, y, 8, s + 1) * 0.2 + pnoise(x, y, 4, s + 2) * 0.15


func wdist(a: Vector2, b: Vector2) -> float:
	var dx := absf(a.x - b.x)
	var dy := absf(a.y - b.y)
	return Vector2(minf(dx, TEX - dx), minf(dy, TEX - dy)).length()


# --- material textures (64x64, seamless) -------------------------------------

func _texture(mat: Dictionary, seed: int) -> Image:
	var img := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	var r := ramp(_base(mat))
	match String(mat.kind):
		"dirt", "grass":
			_tex_dirt(img, r, seed, false)
		"mud":
			_tex_dirt(img, r, seed, true)
		"stone":
			_tex_stone(img, r, seed, int(style.get("stone_cells", 34)))
		"ore":
			_tex_stone(img, r, seed, int(style.get("stone_cells", 34)))
			_tex_ore(img, r, ramp(_accent(mat)), seed + 7)
		"sand":
			_tex_sand(img, r, seed)
		"snow":
			_tex_snow(img, r, seed)
		"ice":
			_tex_ice(img, r, seed)
		"clay":
			_tex_clay(img, r, seed)
		"planks", "platform":
			_tex_planks(img, r, seed)
		_:
			img.fill(r[3])
	return img


func _tex_dirt(img: Image, r: Array[Color], seed: int, wet: bool) -> void:
	for y in TEX:
		for x in TEX:
			var v := fbm(x, y, seed)
			var idx := 2 if v < 0.4 else (3 if v < 0.66 else 4)
			if style.get("dirt_fine", false):
				var f := pnoise(x, y, 2, seed + 13)
				idx = 3 if f < 0.55 else (2 if f < 0.8 else 4)
				if v < 0.35:
					idx -= 1
			elif pnoise(x, y, 4, seed + 9) > 0.78:
				idx -= 1
			img.set_pixel(x, y, r[idx])
	# Embedded stones: lit top-left, shaded bottom-right, a shadow under each.
	var sr := ramp(Color("807468"))
	var shapes := [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]]
	for i in 22:
		var p := Vector2i(int(h(i, 1, seed) * TEX), int(h(i, 2, seed) * TEX))
		var shape: Array = shapes[int(h(i, 3, seed) * 2.99)]
		for o: Vector2i in shape:
			if not shape.has(o + Vector2i(0, 1)):
				img.set_pixel(posmod(p.x + o.x, TEX), posmod(p.y + o.y + 1, TEX), r[1])
		for o: Vector2i in shape:
			var lit := not shape.has(o + Vector2i(0, -1)) and not shape.has(o + Vector2i(-1, 0))
			var dark := not shape.has(o + Vector2i(0, 1)) or not shape.has(o + Vector2i(1, 0))
			img.set_pixel(posmod(p.x + o.x, TEX), posmod(p.y + o.y, TEX), sr[5] if lit else (sr[2] if dark else sr[3]))
	if wet:
		for i in 16:
			var x := int(h(i, 5, seed) * TEX)
			var y := int(h(i, 6, seed) * TEX)
			for k in 3:
				img.set_pixel(posmod(x + k, TEX), y, r[5] if k == 1 else r[4])


func _tex_stone(img: Image, r: Array[Color], seed: int, cells: int) -> void:
	var pts: Array[Vector2] = []
	var tone := PackedInt32Array()
	for i in cells:
		pts.append(Vector2(h(i, 1, seed) * TEX, h(i, 2, seed) * TEX))
		tone.append([2, 3, 3, 4][int(h(i, 3, seed) * 3.99)])
	var cell := PackedInt32Array()
	cell.resize(TEX * TEX)
	for y in TEX:
		for x in TEX:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := 1e9
			var d2 := 1e9
			var best := 0
			for i in cells:
				var d := wdist(p, pts[i])
				if d < d1:
					d2 = d1
					d1 = d
					best = i
				elif d < d2:
					d2 = d
			cell[y * TEX + x] = -1 if d2 - d1 < 1.1 else best
	for y in TEX:
		for x in TEX:
			var c := cell[y * TEX + x]
			if c < 0:
				img.set_pixel(x, y, r[0] if pnoise(x, y, 8, seed + 4) > 0.45 else r[1])
				continue
			var t := tone[c]
			if fbm(x, y, seed + 11) > 0.68:
				t = mini(t + 1, 5)
			if cell[posmod(y - 1, TEX) * TEX + x] < 0 or cell[y * TEX + posmod(x - 1, TEX)] < 0:
				t = mini(t + 2, 6)
			elif cell[posmod(y + 1, TEX) * TEX + x] < 0 or cell[y * TEX + posmod(x + 1, TEX)] < 0:
				t = maxi(t - 1, 1)
			img.set_pixel(x, y, r[t])


func _tex_ore(img: Image, sr: Array[Color], orr: Array[Color], seed: int) -> void:
	var shapes := [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]]
	# One nugget per 8x8 piece, so every ore block shows ore wherever it sits.
	for i in PIECES:
		var p := Vector2i((i % SIDE) * T + 1 + int(h(i, 1, seed) * 3.0), (i / SIDE) * T + 1 + int(h(i, 2, seed) * 3.0))
		var shape: Array = shapes[int(h(i, 3, seed) * 2.99)]
		for o: Vector2i in shape:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not shape.has(o + d):
					img.set_pixel(posmod(p.x + o.x + d.x, TEX), posmod(p.y + o.y + d.y, TEX), sr[0])
		for o: Vector2i in shape:
			var lit := not shape.has(o + Vector2i(0, -1)) and not shape.has(o + Vector2i(-1, 0))
			var dark := not shape.has(o + Vector2i(0, 1))
			img.set_pixel(posmod(p.x + o.x, TEX), posmod(p.y + o.y, TEX), orr[6] if lit else (orr[2] if dark else orr[4]))


func _tex_sand(img: Image, r: Array[Color], seed: int) -> void:
	for y in TEX:
		for x in TEX:
			var wave := sin(TAU * (y / 8.0 + x / 32.0) + pnoise(x, y, 8, seed) * 3.0)
			var idx := 3
			if wave > 0.72:
				idx = 4
			elif wave < -0.8:
				idx = 2
			if fbm(x, y, seed + 3) < 0.3:
				idx -= 1
			img.set_pixel(x, y, r[clampi(idx, 1, 5)])


func _tex_snow(img: Image, r: Array[Color], seed: int) -> void:
	for y in TEX:
		for x in TEX:
			var v := fbm(x, y, seed)
			img.set_pixel(x, y, r[3] if v < 0.42 else (r[4] if v < 0.7 else r[5]))


func _tex_ice(img: Image, r: Array[Color], seed: int) -> void:
	for y in TEX:
		for x in TEX:
			var v := fbm(x, y, seed)
			var idx := 3 if v < 0.55 else 4
			if posmod(x - y * 2, 16) < 2 and pnoise(x, y, 8, seed + 2) > 0.45:
				idx = 6 if posmod(x - y * 2, 16) == 0 else 5
			img.set_pixel(x, y, r[idx])
	for c in 6:
		var x := int(h(c, 1, seed) * TEX)
		var y := int(h(c, 2, seed) * TEX)
		for k in 9:
			img.set_pixel(posmod(x, TEX), posmod(y, TEX), r[1])
			x += 1 if h(c, k, seed + 5) > 0.4 else 0
			y += 1


func _tex_clay(img: Image, r: Array[Color], seed: int) -> void:
	for y in TEX:
		for x in TEX:
			var band := sin(TAU * y / 10.666 + pnoise(x, y, 8, seed) * 2.5)
			var idx := 3 if band < 0.45 else 4
			if band < -0.75:
				idx = 2
			if pnoise(x, y, 4, seed + 4) > 0.82:
				idx -= 1
			img.set_pixel(x, y, r[idx])


func _tex_planks(img: Image, r: Array[Color], seed: int) -> void:
	for y in TEX:
		var row := y / 4
		var ry := y % 4
		var seam := posmod(row * 11 + int(h(row, 0, seed) * 6), 16)
		for x in TEX:
			var idx := 3
			if ry == 0:
				idx = 4
			elif ry == 3:
				idx = 1
			elif pnoise(x, row * 4, 8, seed + row) > 0.6:
				idx = 2
			if posmod(x - seam, 16) == 0:
				idx = 0
			elif posmod(x - seam, 16) == 1 and ry != 3:
				idx = 4
			img.set_pixel(x, y, r[idx])


# --- tiles -------------------------------------------------------------------

func _build_atlas(mats: Array, walls: bool) -> Image:
	var img := Image.create_empty(MASKS * PIECES * T, mats.size() * T, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for mi in mats.size():
		var mat: Dictionary = mats[mi]
		var tex := _texture(mat, mi * 101 + (500 if walls else 0))
		var r := ramp(_base(mat))
		for piece in PIECES:
			var src := tex.get_region(Rect2i((piece % SIDE) * T, (piece / SIDE) * T, T, T))
			for mask in MASKS:
				var tile: Image
				if walls:
					tile = _wall_tile(src, mask)
				elif mat.kind == "platform":
					tile = _platform_tile(src, r, mask)
				elif mat.kind == "rope":
					tile = _rope_tile(r, mask, piece)
				else:
					tile = _block_tile(src, r, mask, mat, piece)
				img.blit_rect(tile, Rect2i(0, 0, T, T), Vector2i((mask * PIECES + piece) * T, mi * T))
	return img


func _block_tile(src: Image, r: Array[Color], mask: int, mat: Dictionary, piece: int) -> Image:
	var img := src.duplicate() as Image
	var outline := r[0].darkened(float(style.outline))
	var up := not (mask & UP)
	var down := not (mask & DOWN)
	var left := not (mask & LEFT)
	var right := not (mask & RIGHT)
	for y in T:
		for x in T:
			var c := img.get_pixel(x, y)
			var edge := (up and y == 0) or (down and y == T - 1) or (left and x == 0) or (right and x == T - 1)
			if edge:
				c = outline
			else:
				if up and y == 1:
					c = c.lerp(r[6], 0.45)
				elif left and x == 1:
					c = c.lerp(r[5], 0.25)
				if down and y == T - 2:
					c = c.lerp(r[1], 0.5)
				elif right and x == T - 2:
					c = c.lerp(r[1], 0.3)
			img.set_pixel(x, y, c)
	# Soften outer corners by one pixel.
	for corner: Array in [[up and left, 0, 0], [up and right, T - 1, 0], [down and left, 0, T - 1], [down and right, T - 1, T - 1]]:
		if corner[0]:
			img.set_pixel(corner[1], corner[2], Color.TRANSPARENT)
	if mat.kind == "grass":
		_grass(img, ramp(_accent(mat)), mask, piece)
	return img


func _grass(img: Image, g: Array[Color], mask: int, piece: int) -> void:
	var up := not (mask & UP)
	if up:
		for x in T:
			var n := h(x + piece * T, 0, 77)
			var depth := 3 if n > 0.45 else 2
			# Blade tips along the top row: bright tufts with small gaps.
			img.set_pixel(x, 0, g[5] if n > 0.35 else Color.TRANSPARENT)
			for y in range(1, depth + 1):
				img.set_pixel(x, y, g[4] if y == 1 else (g[3] if y < depth else g[1]))
	for side: Array in [[LEFT, 0], [RIGHT, T - 1]]:
		if mask & int(side[0]):
			continue
		var start := 1 if up else 0
		var length := 3 + int(h(piece, int(side[1]), 9) * 2.99)
		for y in range(start, mini(start + length, T)):
			img.set_pixel(side[1], y, g[2] if y < start + length - 1 else g[1])


func _wall_tile(src: Image, mask: int) -> Image:
	var img := src.duplicate() as Image
	var dark: float = style.wall_dark
	var desat: float = style.wall_desat
	for y in T:
		for x in T:
			var c := img.get_pixel(x, y)
			c = Color.from_hsv(c.h, c.s * (1.0 - desat), c.v).darkened(dark)
			var e := (not (mask & UP) and y == 0) or (not (mask & DOWN) and y == T - 1) \
				or (not (mask & LEFT) and x == 0) or (not (mask & RIGHT) and x == T - 1)
			img.set_pixel(x, y, c.darkened(0.35) if e else c)
	return img


func _platform_tile(src: Image, r: Array[Color], mask: int) -> Image:
	var img := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for x in T:
		img.set_pixel(x, 0, r[5])
		img.set_pixel(x, 1, src.get_pixel(x, 1))
		img.set_pixel(x, 2, r[1])
	for side: Array in [[LEFT, 0, 1], [RIGHT, T - 1, T - 2]]:
		if mask & int(side[0]):
			continue
		img.set_pixel(side[1], 0, Color.TRANSPARENT)
		img.set_pixel(side[1], 1, r[0])
		img.set_pixel(side[1], 2, Color.TRANSPARENT)
		for y in range(3, 6):
			img.set_pixel(side[2], y, r[1] if y < 5 else r[0])
	return img


func _rope_tile(r: Array[Color], mask: int, piece: int) -> Image:
	var img := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var c := T / 2
	var end := T if mask & DOWN else T - 2
	for y in end:
		var twist := (y + piece) % 3
		img.set_pixel(c - 2, y, r[0])
		img.set_pixel(c + 1, y, r[0])
		img.set_pixel(c - 1, y, r[4] if twist == 0 else r[3])
		img.set_pixel(c, y, r[2] if twist == 1 else r[3])
	if not (mask & DOWN):
		for x in range(c - 2, c + 2):
			img.set_pixel(x, T - 2, r[1])
	return img


# --- preview scene -----------------------------------------------------------

## Mock scene, 80x45 tiles (the game's 640x360 view at 8 px tiles), saved at 3x.
## closeup.png = upper left at 6x, underground.png = lower left at 6x.
func _save_preview(blocks: Image, walls: Image, out: String) -> void:
	var W := 80
	var H := 45
	var b := PackedInt32Array()
	var w := PackedInt32Array()
	b.resize(W * H)
	w.resize(W * H)
	b.fill(-1)
	w.fill(-1)
	var surf := PackedInt32Array()
	for x in W:
		var s := 25 + roundi(3.0 * sin(x * 0.11) + 2.0 * sin(x * 0.04 + 1.0))
		if x <= 26:
			s = 26
		surf.append(s)
	for x in W:
		for y in range(surf[x], H):
			var depth := y - surf[x]
			var m := 2
			if x < 34:
				m = 1 if depth == 0 else (0 if depth < 11 else 2)
			elif x < 58:
				m = 3 if depth < 12 else (7 if depth < 15 else 2)
			else:
				m = 4 if depth < 4 else (5 if depth < 9 else 2)
			b[y * W + x] = m
			if depth >= 3:
				w[y * W + x] = 0 if x < 34 and depth < 12 else (3 if x >= 34 and x < 58 and depth < 15 else 1)
	for y in H:
		for x in W:
			var dx := (x - 44.0) / 13.0
			var dy := (y - 38.0) / 5.0
			if dx * dx + dy * dy + 0.2 * h(x, y, 3) < 1.0:
				b[y * W + x] = -1
				w[y * W + x] = 1
	for y in range(surf[47], 37):
		for x in range(45, 50):
			b[y * W + x] = -1
			if y > surf[47] + 2:
				w[y * W + x] = 3
		b[y * W + 47] = 15
	var blobs := [[16, 32, 6, 2.6], [8, 39, 9, 1.8], [20, 42, 9, 1.6], [28, 40, 10, 1.7], [62, 36, 11, 1.8], [72, 41, 12, 1.7], [38, 43, 13, 1.9], [52, 29, 7, 2.0]]
	for bl: Array in blobs:
		for y in H:
			for x in W:
				if Vector2(x, y).distance_to(Vector2(bl[0], bl[1])) < float(bl[3]) and b[y * W + x] >= 0 and b[y * W + x] != 15:
					b[y * W + x] = int(bl[2])
	for x in range(2, 24):
		b[12 * W + x] = 8
		b[13 * W + x] = 8
	for y in range(14, 26):
		b[y * W + 22] = 8
		if y < 19:
			b[y * W + 3] = 8
		for x in range(4, 22):
			w[y * W + x] = 2
	for x in range(6, 13):
		b[20 * W + x] = 14

	var px_w := W * T
	var px_h := H * T
	var img := Image.create_empty(px_w, px_h, false, Image.FORMAT_RGBA8)
	var sky_top: Color = style.sky_top
	var sky_low: Color = style.sky_low
	for y in px_h:
		img.fill_rect(Rect2i(0, y, px_w, 1), sky_top.lerp(sky_low, clampf(float(y) / (26 * T), 0.0, 1.0)))
	# Distant hills, two layers fading into the sky.
	for layer in 2:
		var col := sky_low.lerp(Color("5d7f73"), 0.35 + 0.25 * layer).darkened(0.08 * layer)
		for x in px_w:
			var top := 150 + layer * 24 + roundi(18.0 * sin(x * 0.012 + layer * 2.0) + 9.0 * sin(x * 0.031 + layer) + 4.0 * sin(x * 0.08))
			img.fill_rect(Rect2i(x, top, 1, px_h - top), col)
	for x in W:
		img.fill_rect(Rect2i(x * T, (surf[x] + 3) * T, T, (H - surf[x] - 3) * T), Color("120e0d"))
	_blit_layer(img, walls, w, W, H, false)
	_blit_layer(img, blocks, b, W, H, true)

	var big := img.duplicate() as Image
	big.resize(px_w * 3, px_h * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(out.path_join("preview.png"))
	var crop := img.get_region(Rect2i(0, 9 * T, 40 * T, 22 * T))
	crop.resize(crop.get_width() * 6, crop.get_height() * 6, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join("closeup.png"))
	var under := img.get_region(Rect2i(0, 26 * T, 40 * T, 19 * T))
	under.resize(under.get_width() * 6, under.get_height() * 6, Image.INTERPOLATE_NEAREST)
	under.save_png(out.path_join("underground.png"))


func _blit_layer(img: Image, atlas: Image, grid: PackedInt32Array, W: int, H: int, blocks: bool) -> void:
	for y in H:
		for x in W:
			var m := grid[y * W + x]
			if m < 0:
				continue
			var mask := 0
			var dirs := [[0, -1, UP], [1, 0, RIGHT], [0, 1, DOWN], [-1, 0, LEFT]]
			for d: Array in dirs:
				var nx: int = x + int(d[0])
				var ny: int = y + int(d[1])
				var present := true
				if nx >= 0 and ny >= 0 and nx < W and ny < H:
					var n := grid[ny * W + nx]
					if not blocks:
						present = n >= 0
					elif m == 14 or m == 15:
						present = n == m
					else:
						present = n >= 0 and n != 14 and n != 15
				if present:
					mask |= int(d[2])
			var piece := posmod(x, SIDE) + posmod(y, SIDE) * SIDE
			img.blend_rect(atlas, Rect2i((mask * PIECES + piece) * T, m * T, T, T), Vector2i(x * T, y * T))


# --- forest preview: lighting, surface decorations, trees, layered backdrop ---

func _base(mat: Dictionary) -> Color:
	var bases: Dictionary = style.get("bases", {})
	return bases.get(mat.id, mat.base)


func _accent(mat: Dictionary) -> Color:
	var accents: Dictionary = style.get("accents", {})
	return accents.get(mat.id, mat.get("accent", Color.WHITE))


## Procedural pine: trunk plus stacked jagged tiers, lit from the left.
func _pine(height: int, seed: int, g: Array[Color], bark: Array[Color]) -> Image:
	var w := int(height * 0.6) | 1
	var img := Image.create_empty(w, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx := w / 2
	for y in range(int(height * 0.25), height):
		for x in range(cx - 2, cx + 2):
			var c := bark[3]
			if x == cx - 2:
				c = bark[4]
			elif x == cx + 1:
				c = bark[1]
			elif h(x, y / 2, seed) > 0.75:
				c = bark[2]
			img.set_pixel(x, y, c)
	var tiers := 4 + int(h(0, 0, seed) * 2.0)
	var bottom := int(height * 0.84)
	for t in tiers:
		var k := float(t) / (tiers - 1)
		var ty0 := int(lerpf(0.0, bottom * 0.58, k))
		var ty1 := mini(ty0 + int(height * 0.34), bottom)
		var half := lerpf(w * 0.16, w * 0.5, k)
		for y in range(ty0, ty1):
			var f := float(y - ty0) / maxf(ty1 - ty0, 1.0)
			for x in range(0, w):
				var rel := float(x - cx) / half
				# Jagged branch ends: per row, and a saw-tooth along each tier's lower edge.
				var jag := (h(y / 2, t, seed) - 0.5) * 0.18
				if absf(rel) > f + jag:
					continue
				# Scalloped lower edge: branch clumps hang a little lower than the gaps.
				if f > 1.0 - 0.22 * absf(sin(x * 0.75 + t * 1.3)):
					continue
				var idx := 3
				if rel < -0.35:
					idx = 4
				elif rel > 0.4:
					idx = 1
				elif rel > 0.05:
					idx = 2
				if posmod(x * 2 + y, 7) == 0 and absf(rel) < 0.8:
					idx = mini(idx + 1, 5)
				if f > 0.8:
					idx = maxi(idx - 1, 1)
				img.set_pixel(x, y, g[idx])
	var out := img.duplicate() as Image
	for y in height:
		for x in w:
			if img.get_pixel(x, y).a == 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= height or img.get_pixel(nx, ny).a == 0.0:
					out.set_pixel(x, y, g[0])
					break
	return out


## Tints every opaque pixel toward `haze` (atmospheric depth for backdrop layers).
func _hazed(src: Image, haze: Color, amount: float) -> Image:
	var img := src.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(c.lerp(haze, amount), 1.0))
	return img


func _tuft(img: Image, x0: int, ground_y: int, g: Array[Color], seed: int) -> void:
	for i in 5:
		var x := x0 + int(h(i, 1, seed) * T)
		var tall := 2 + int(h(i, 2, seed) * 5.0)
		for k in tall:
			var lean := 1 if (k > tall / 2 and h(i, 3, seed) > 0.6) else 0
			var c := g[5] if k == tall - 1 else (g[4] if k > tall / 2 else g[3])
			_px(img, x + lean, ground_y - 1 - k, c)


func _flower(img: Image, x: int, ground_y: int, petal: Color, seed: int) -> void:
	var stem := 3 + int(h(1, 1, seed) * 3.0)
	for k in stem:
		_px(img, x, ground_y - 1 - k, Color("3f7a2c"))
	var top := ground_y - 1 - stem
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		_px(img, x + d.x, top + d.y, petal)
	_px(img, x, top, Color("ffe27a"))


func _vine(img: Image, x: int, y0: int, length: int, g: Array[Color], seed: int) -> void:
	for k in length:
		var sway := roundi(sin(k * 0.35 + seed) * 1.2)
		_px(img, x + sway, y0 + k, g[2])
		if k % 4 == 1:
			_px(img, x + sway - 1, y0 + k, g[4])
			_px(img, x + sway + 1, y0 + k + 1, g[3])


func _torch(img: Image, x: int, y: int) -> void:
	for k in 4:
		_px(img, x, y + k, Color("6b4423"))
	_px(img, x, y - 1, Color("ffd36a"))
	_px(img, x, y - 2, Color("ffb13a"))
	_px(img, x - 1, y - 1, Color("ff8a2a"))
	_px(img, x + 1, y - 1, Color("ff8a2a"))
	_px(img, x, y, Color("fff2b0"))


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## Forest hillside: stone outcrop, rolling grass, a big cave with an entrance, pines,
## decorations and per-tile lighting (sky light fades into the ground, a torch lights
## part of the cave). Also writes an unlit version to judge textures.
func _save_forest_preview(blocks: Image, walls: Image, out: String) -> void:
	var W := 80
	var H := 45
	var b := PackedInt32Array()
	var w := PackedInt32Array()
	b.resize(W * H)
	w.resize(W * H)
	b.fill(-1)
	w.fill(-1)
	var surf := PackedInt32Array()
	for x in W:
		var s := 21.0 + 2.0 * sin(x * 0.09 + 0.5) + 1.2 * sin(x * 0.23)
		if x < 22:
			s = lerpf(12.0, 20.0, smoothstep(10.0, 22.0, x)) + 1.0 * sin(x * 0.7)
		if x > 62:
			s += (x - 62) * 0.35
		surf.append(roundi(s))
	for x in W:
		var dirt_depth := 7 + int(h(x / 4, 0, 5) * 4.0)
		for y in range(surf[x], H):
			var depth := y - surf[x]
			var m := 2
			if x < 20:
				m = (1 if h(x, 1, 8) < 0.55 else 2) if depth == 0 else 2
			else:
				m = 1 if depth == 0 else (0 if depth < dirt_depth else 2)
			if m == 2 and pnoise(x, y, 8, 21) > 0.72:
				m = 0
			b[y * W + x] = m
			if depth >= 2:
				w[y * W + x] = 0 if (x >= 20 and depth < dirt_depth) else 1
	# Cave: a wide noisy tunnel, opening to the surface on the right.
	for y in H:
		for x in W:
			var center := 35.0 + 3.0 * sin(x * 0.12) - maxf(0.0, (x - 58) * 0.9)
			var half := 4.5 + 2.0 * sin(x * 0.21 + 1.0) + 1.4 * (pnoise(x, y, 8, 31) - 0.5)
			if x > 8 and x < 74 and absf(y - center) < half:
				b[y * W + x] = -1
				if y > surf[x] + 1:
					w[y * W + x] = 1 if w[y * W + x] < 0 else w[y * W + x]
	# Ore pockets.
	for i in 14:
		var ox := 4 + int(h(i, 1, 41) * 72.0)
		var oy := 26 + int(h(i, 2, 41) * 18.0)
		var ore: int = [9, 9, 10, 10, 11, 13][int(h(i, 3, 41) * 5.99)]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var tx := ox + dx
				var ty := oy + dy
				if tx >= 0 and tx < W and ty < H and b[ty * W + tx] == 2 and h(tx, ty, 43) > 0.3:
					b[ty * W + tx] = ore

	var px_w := W * T
	var px_h := H * T
	var img := Image.create_empty(px_w, px_h, false, Image.FORMAT_RGBA8)
	var sky_top: Color = style.sky_top
	var sky_low: Color = style.sky_low
	var v2: bool = style.get("backdrop", "") == "v2"
	for y in px_h:
		img.fill_rect(Rect2i(0, y, px_w, 1), sky_top.lerp(sky_low, clampf(float(y) / 170.0, 0.0, 1.0)))
	if v2:
		_backdrop_v2(img, px_w, px_h)
	# Backdrop: rolling meadow layers and two rows of hazy pines.
	var gr := ramp(_accent(BLOCKS[1]))
	var pine_g := ramp(Color("3f6e3a"))
	var bark := ramp(Color("6a4a33"))
	var haze := sky_low
	for layer in (0 if v2 else 3):
		var base := gr[3].lerp(haze, 0.55 - layer * 0.17)
		if layer == 2:
			for i in 26:
				var tx := int(h(i, 1, 61) * px_w)
				var tree := _hazed(_pine(34 + int(h(i, 2, 61) * 20.0), i + 300, pine_g, bark), haze, 0.62)
				var ground := 104 + roundi(10.0 * sin(tx * 0.015))
				img.blend_rect(tree, Rect2i(Vector2i.ZERO, tree.get_size()), Vector2i(tx - tree.get_width() / 2, ground - tree.get_height()))
		for x in px_w:
			var top := 92 + layer * 22 + roundi(10.0 * sin(x * 0.011 + layer * 1.7) + 5.0 * sin(x * 0.029 + layer))
			for y in range(top, px_h):
				var c := base
				if posmod(x + y * 3 + int(pnoise(x % TEX, y % TEX, 8, layer) * 9.0), 11) == 0:
					c = base.lightened(0.05)
				img.set_pixel(x, y, c)
		if layer == 1:
			for i in 14:
				var tx := int(h(i, 4, 62) * px_w)
				var tree := _hazed(_pine(52 + int(h(i, 5, 62) * 26.0), i + 400, pine_g, bark), haze, 0.4)
				var ground := 138 + roundi(9.0 * sin(tx * 0.013))
				img.blend_rect(tree, Rect2i(Vector2i.ZERO, tree.get_size()), Vector2i(tx - tree.get_width() / 2, ground - tree.get_height()))
	for x in W:
		img.fill_rect(Rect2i(x * T, (surf[x] + 2) * T, T, (H - surf[x] - 2) * T), Color("120e0d"))
	if not style.get("compose", false):
		_blit_layer(img, walls, w, W, H, false)
	# Foreground pines stand on the grass, drawn before blocks so the grass covers their base.
	var fg_kinds := ["green", "olive", "teal", "green", "gold"]
	for i in 5:
		var tx: int = [24, 40, 51, 58, 66][i]
		var tree := _pine2(120 + int(h(tx, 0, 71) * 50.0), tx, fg_kinds[i]) if v2 else _pine(78 + int(h(tx, 0, 71) * 30.0), tx, pine_g, bark)
		img.blend_rect(tree, Rect2i(Vector2i.ZERO, tree.get_size()), Vector2i(tx * T + T / 2 - tree.get_width() / 2, surf[tx] * T + 2 - tree.get_height()))
	if style.get("compose", false) is String and style.compose == "natural2":
		_compose_natural(img, b, w, W, H)
	elif style.get("compose", false):
		_compose_terrain(img, b, w, W, H)
	else:
		_blit_layer(img, blocks, b, W, H, true)
	# Surface decorations on grass tops, vines at the cave mouth, a torch in the cave.
	var petals := [Color("e2508a"), Color("f2d34a"), Color("8a6cf0"), Color("f08a3a"), Color("ffffff")]
	for x in W:
		var y := surf[x]
		if b[y * W + x] != 1:
			continue
		if h(x, 7, 81) < 0.75:
			_tuft(img, x * T, y * T + 1, gr, x)
		if h(x, 8, 81) < 0.2:
			_flower(img, x * T + 2 + int(h(x, 9, 81) * 4.0), y * T + 1, petals[int(h(x, 10, 81) * 4.99)], x)
	for x in range(56, 74):
		for y in range(1, H):
			if b[y * W + x] >= 0 and b[(y + 1) * W + x] < 0 if y + 1 < H else false:
				if h(x, y, 91) < 0.4:
					_vine(img, x * T + 3, (y + 1) * T, 10 + int(h(x, y, 92) * 22.0), gr, x)
	if style.has("character") and FileAccess.file_exists(String(style.character)):
		var ch := Image.load_from_file(String(style.character))
		var bb := ch.get_used_rect()
		var body := ch.get_region(bb)
		var cx := 33
		img.blend_rect(body, Rect2i(Vector2i.ZERO, body.get_size()), Vector2i(cx * T - body.get_width() / 2, surf[cx] * T - body.get_height() + 1))
	var torch := Vector2i(30, 0)
	for y in range(H - 1, 0, -1):
		if b[y * W + 30] >= 0 and b[(y - 1) * W + 30] < 0:
			torch.y = y - 2
			break
	_torch(img, torch.x * T + 4, torch.y * T + 2)

	img.save_png(out.path_join("unlit_small.png"))
	var unlit := img.duplicate() as Image

	# Lighting: open sky (air with no wall) is fully lit; light fades 0.1 per open
	# tile and 0.3 per solid tile. The torch adds its own light.
	var light := PackedFloat32Array()
	light.resize(W * H)
	for y in H:
		for x in W:
			if b[y * W + x] < 0 and w[y * W + x] < 0:
				light[y * W + x] = 1.0
	light[torch.y * W + torch.x] = 1.0
	for it in 45:
		for y in H:
			for x in W:
				var best := light[y * W + x]
				var cost := 0.1 if b[y * W + x] >= 0 and b[y * W + x] != 15 else 0.06
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + d.x
					var ny := y + d.y
					if nx >= 0 and ny >= 0 and nx < W and ny < H:
						best = maxf(best, light[ny * W + nx] - cost)
				light[y * W + x] = best
	for py in px_h:
		for px in px_w:
			var fx := clampf((px + 0.5) / T - 0.5, 0.0, W - 1.001)
			var fy := clampf((py + 0.5) / T - 0.5, 0.0, H - 1.001)
			var ix := int(fx)
			var iy := int(fy)
			var tx := fx - ix
			var ty := fy - iy
			var l := lerpf(lerpf(light[iy * W + ix], light[iy * W + ix + 1], tx), lerpf(light[(iy + 1) * W + ix], light[(iy + 1) * W + ix + 1], tx), ty)
			l = clampf(l, 0.0, 1.0)
			l = l * l * (3.0 - 2.0 * l)
			var amb: float = style.get("ambient", 0.0)
			l = amb + (1.0 - amb) * l
			var c := img.get_pixel(px, py)
			img.set_pixel(px, py, Color(c.r * l, c.g * l, c.b * l, 1.0))

	var big := img.duplicate() as Image
	big.resize(px_w * 3, px_h * 3, Image.INTERPOLATE_NEAREST)
	big.save_png(out.path_join("preview.png"))
	var crop := img.get_region(Rect2i(10 * T, 6 * T, 40 * T, 22 * T))
	crop.resize(crop.get_width() * 6, crop.get_height() * 6, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join("closeup.png"))
	var under := unlit.get_region(Rect2i(8 * T, 22 * T, 40 * T, 19 * T))
	under.resize(under.get_width() * 6, under.get_height() * 6, Image.INTERPOLATE_NEAREST)
	under.save_png(out.path_join("underground_unlit.png"))
	var unlit_big := unlit.duplicate() as Image
	unlit_big.resize(px_w * 3, px_h * 3, Image.INTERPOLATE_NEAREST)
	unlit_big.save_png(out.path_join("preview_unlit.png"))


# --- natural terrain: per-pixel compositing across tiles -----------------------
# Blocks draw from seamless world-space textures. Where a block meets air its edge gets
# small rounded bumps, a lit top rim and a soft shadow underneath (no dark outline).
# Where two materials meet, the higher-priority one pushes irregular lumps into the
# other, so materials blend instead of meeting at a straight seam. In the game this
# becomes a terrain shader over the tile map.

const PRIORITY := {0: 2, 1: 2, 2: 3, 3: 1, 4: 1, 5: 2, 6: 2, 7: 2, 8: 4, 9: 3, 10: 3, 11: 3, 12: 3, 13: 3}


func _solid(m: int) -> bool:
	return m >= 0 and m != 14 and m != 15


## Layered dirt: short rounded clods in loose rows, lit tops, shaded bottoms.
func _tex_lumps(img: Image, r: Array[Color], seed: int) -> void:
	img.fill(r[1])
	var rows := TEX / 3
	for row in rows + 1:
		var x := int(h(row, 0, seed) * TEX)
		var used := 0
		var k := 0
		while used < TEX:
			var lw := 3 + int(h(row, k, seed + 1) * 4.0)
			var lh := 2 + (1 if h(row, k, seed + 5) > 0.45 else 0)
			var dy := int(h(row, k, seed + 2) * 2.0)
			var t := h(row, k, seed + 3)
			var tone := 2 if t < 0.3 else (3 if t < 0.85 else 4)
			for i in mini(lw, TEX - used):
				for j in lh:
					if (i == 0 or i == lw - 1) and (j == 0 or j == lh - 1) and lh > 2:
						continue
					var c := r[tone]
					if j == 0 and i > 0 and i < lw - 1:
						c = r[mini(tone + 1, 5)]
					elif j == lh - 1:
						c = r[tone - 1]
					img.set_pixel(posmod(x + i, TEX), posmod(row * 3 + dy + j, TEX), c)
			var gap := 1 if h(row, k, seed + 4) > 0.3 else 0
			x += lw + gap
			used += lw + gap
			k += 1
	for y in TEX:
		for x in TEX:
			var v := fbm(x, y, seed + 9)
			if v < 0.34:
				img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.12))
			elif v > 0.7:
				img.set_pixel(x, y, img.get_pixel(x, y).lightened(0.05))


## Pebble stone: small rounded stones shaded as little domes, dark gaps between.
func _tex_pebbles(img: Image, r: Array[Color], seed: int, cells: int) -> void:
	var pts: Array[Vector2] = []
	for i in cells:
		pts.append(Vector2(h(i, 1, seed) * TEX, h(i, 2, seed) * TEX))
	for y in TEX:
		for x in TEX:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := 1e9
			var d2 := 1e9
			var best := 0
			for i in cells:
				var d := wdist(p, pts[i])
				if d < d1:
					d2 = d1
					d1 = d
					best = i
				elif d < d2:
					d2 = d
			if d2 - d1 < 1.0:
				img.set_pixel(x, y, r[1])
				continue
			var c := pts[best]
			var off := Vector2(x + 0.5 - c.x, y + 0.5 - c.y)
			off.x -= roundf(off.x / TEX) * TEX
			off.y -= roundf(off.y / TEX) * TEX
			var lit := -(off.x + off.y) / maxf(d1 + (d2 - d1) * 0.5, 1.0)
			var idx := 2 + int(h(best, 3, seed) * 1.99)
			if lit > 0.75:
				idx += 2
			elif lit > 0.2:
				idx += 1
			elif lit < -0.5:
				idx -= 1
			img.set_pixel(x, y, r[clampi(idx, 1, 6)])


func _natural_texture(m: int, seed: int) -> Image:
	var mat: Dictionary = BLOCKS[m]
	var img := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	var r := ramp(_base(mat))
	match String(mat.kind):
		"dirt", "grass", "mud":
			_tex_lumps(img, r, seed)
		"stone":
			_tex_pebbles(img, r, seed, int(style.get("stone_cells", 60)))
		"ore":
			_tex_pebbles(img, r, seed, int(style.get("stone_cells", 60)))
			_tex_ore(img, r, ramp(_accent(mat)), seed + 7)
		_:
			return _texture(mat, seed)
	return img


## Draws blocks and walls per pixel. b / w are tile grids (material index or -1).
func _compose_terrain(img: Image, b: PackedInt32Array, w: PackedInt32Array, W: int, H: int) -> PackedInt32Array:
	var pw := W * T
	var ph := H * T
	var own := PackedInt32Array()
	own.resize(pw * ph)
	for py in ph:
		for px in pw:
			var m := b[(py / T) * W + px / T]
			own[py * pw + px] = m if _solid(m) else -1
	# Overhang: each solid tile pushes bumps into air and into lower-priority neighbors.
	var order: Array = PRIORITY.keys()
	order.sort_custom(func(a: int, c: int) -> bool: return PRIORITY[a] < PRIORITY[c])
	for m: int in order:
		for ty in H:
			for tx in W:
				if b[ty * W + tx] != m:
					continue
				for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					var nx := tx + d.x
					var ny := ty + d.y
					if nx < 0 or ny < 0 or nx >= W or ny >= H:
						continue
					var n := b[ny * W + nx]
					var into_air := not _solid(n)
					if not into_air and int(PRIORITY.get(n, 0)) >= int(PRIORITY[m]):
						continue
					for a in T:
						var gx := tx * T + (a if d.x == 0 else (T - 1 if d.x > 0 else 0))
						var gy := ty * T + (a if d.y == 0 else (T - 1 if d.y > 0 else 0))
						var along := gx if d.x == 0 else gy
						var noise := pnoise(posmod(along, TEX), posmod(tx * 7 + ty * 3, TEX), 4, m * 13 + (d.x + 2) * 5 + d.y)
						var depth := (int(noise * 2.4) if noise > 0.45 else 0) if into_air else 1 + int(noise * 4.6)
						if into_air and d.y > 0:
							depth = 0
						for k in depth:
							var qx := gx + d.x * (k + 1)
							var qy := gy + d.y * (k + 1)
							if qx < 0 or qy < 0 or qx >= pw or qy >= ph:
								continue
							var cur := own[qy * pw + qx]
							if cur < 0 or int(PRIORITY.get(cur, 0)) < int(PRIORITY[m]):
								own[qy * pw + qx] = m
	# Round off convex corners where a tile has air on two adjacent sides.
	for ty in H:
		for tx in W:
			if not _solid(b[ty * W + tx]):
				continue
			for c: Array in [[-1, -1, 0, 0], [1, -1, T - 1, 0], [-1, 1, 0, T - 1], [1, 1, T - 1, T - 1]]:
				var ax := tx + int(c[0])
				var ay := ty + int(c[1])
				var open_x := ax < 0 or ax >= W or not _solid(b[ty * W + ax])
				var open_y := ay < 0 or ay >= H or not _solid(b[ay * W + tx])
				if not (open_x and open_y):
					continue
				for k in 3:
					for j in 3 - k:
						var qx := tx * T + int(c[2]) - int(c[0]) * j
						var qy := ty * T + int(c[3]) - int(c[1]) * k
						if k + j < 2:
							own[qy * pw + qx] = -1
	var tex := {}
	for m: int in PRIORITY.keys():
		tex[m] = _natural_texture(m, m * 101)
	var ramps := {}
	for m: int in PRIORITY.keys():
		ramps[m] = ramp(_base(BLOCKS[m]))
	var g := ramp(_accent(BLOCKS[1]))
	var wall_tex := {}
	for i in WALLS.size():
		var mi := 0 if i == 0 else (2 if i == 1 else (8 if i == 2 else 7))
		wall_tex[i] = _natural_texture(mi, mi * 101 + 500)
	var wdark: float = style.wall_dark
	# Walls first (behind), soft-shaded toward their open edges.
	for py in ph:
		for px in pw:
			if own[py * pw + px] >= 0:
				continue
			var wi := w[(py / T) * W + px / T]
			if wi < 0:
				continue
			var c: Color = (wall_tex[wi] as Image).get_pixel(posmod(px, TEX), posmod(py, TEX))
			c = Color.from_hsv(c.h, c.s * 0.7, c.v).darkened(wdark)
			img.set_pixel(px, py, c)
	var open := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= pw or y >= ph:
			return false
		return own[y * pw + x] < 0
	for py in ph:
		for px in pw:
			var m := own[py * pw + px]
			if m < 0:
				continue
			var r: Array[Color] = ramps[m]
			var c: Color = (tex[m] as Image).get_pixel(posmod(px, TEX), posmod(py, TEX))
			var top := 99
			for k in range(1, 5):
				if open.call(px, py - k):
					top = k
					break
			var below := 99
			for k in range(1, 4):
				if open.call(px, py + k):
					below = k
					break
			if m == 1 and top <= 4:
				# Grass cover: bright on top, darker where it meets the dirt.
				c = g[5] if top == 1 else (g[4] if top == 2 else (g[3] if top == 3 else g[2]))
				if top == 4 and h(px, py, 5) > 0.5:
					c = (tex[m] as Image).get_pixel(posmod(px, TEX), posmod(py, TEX))
			elif top == 1:
				c = c.lerp(r[6], 0.55)
			elif top == 2:
				c = c.lerp(r[5], 0.2)
			if below == 1:
				c = c.lerp(r[0], 0.6)
			elif below == 2:
				c = c.lerp(r[0], 0.35)
			elif below == 3:
				c = c.lerp(r[1], 0.15)
			if open.call(px - 1, py):
				c = c.lerp(r[5], 0.15)
			elif open.call(px + 1, py):
				c = c.lerp(r[1], 0.25)
			# Contact shadow under a higher-priority material overlapping this one.
			if py > 0:
				var above := own[(py - 1) * pw + px]
				if above >= 0 and above != m and int(PRIORITY.get(above, 0)) > int(PRIORITY.get(m, 0)):
					c = c.lerp(r[0], 0.35)
			img.set_pixel(px, py, c)
	# Grass draping over side edges and blades sticking up into the air.
	for py in ph:
		for px in pw:
			if own[py * pw + px] != 1:
				continue
			if open.call(px, py - 1):
				var tall := int(h(px, 3, 11) * 4.0) if h(px, 4, 11) > 0.35 else 0
				for k in tall:
					if open.call(px, py - 1 - k):
						img.set_pixel(px, py - 1 - k, g[5] if k == tall - 1 else g[4])
			for side in [-1, 1]:
				if open.call(px + side, py):
					var depth := 0
					while depth < 8 and not open.call(px, py - depth - 1):
						depth += 1
					if depth < 3 + int(h(px, py / 4, 17) * 4.0):
						img.set_pixel(px, py, g[3] if depth > 1 else g[4])
	# Platforms and ropes keep their tiles.
	for ty in H:
		for tx in W:
			var m := b[ty * W + tx]
			if m == 14 or m == 15:
				pass
	return own


# --- natural v2: Patrick's reference palettes, smooth silhouettes -------------

## Palettes sampled from Patrick's own reference art (index 0 darkest .. 6 lightest).
const REF_PAL := {
	"dirt": ["2a1d0c", "413117", "65441a", "775728", "866737", "8a6a38", "a0804c"],
	"stone": ["1e1e1e", "3a3a3a", "555555", "6e6e6e", "838383", "959595", "aaaaaa"],
	"grass": ["1f5212", "2b7018", "349a20", "42a628", "4fb52f", "5cbf3a", "7fd457"],
	"dirt_wall": ["140e06", "1c1408", "231908", "2c200d", "38280e", "403017", "4a3a20"],
	"stone_wall": ["101010", "181818", "222222", "2c2c2c", "353535", "3e3e3e", "474747"],
	"sand": ["5c4a24", "7f6532", "a3864a", "b99c5c", "c9ad6c", "d6bd7f", "e4cf98"],
	"dirt_warm": ["2a160b", "472812", "5f3719", "774626", "8a5531", "9c6a40", "b08254"],
	"dirt_mid": ["2b1a0c", "45301a", "634424", "79552e", "8a6439", "9a7446", "b08d5c"],
	"stone_soft": ["262626", "4a4a4a", "5f5f5f", "737373", "868686", "989898", "ababab"],
	"stone_warm": ["29261f", "48443a", "5f5a4f", "757064", "8a8476", "9c9688", "b0aa9b"],
	"dirt_wall_warm": ["120a05", "1c1108", "26170b", "2f1d0f", "3a2413", "442b18", "50361f"],
}


func _pal(name: String) -> Array[Color]:
	var out: Array[Color] = []
	for hex: String in REF_PAL[name]:
		out.append(Color(hex))
	return out


## Dirt: 1 px tall horizontal strokes of varied length, tone drifting slowly so
## strokes group into soft clods. Low contrast, warm.
func _tex_strokes(img: Image, r: Array[Color], seed: int) -> void:
	for y in TEX:
		var x := int(h(y, 0, seed) * TEX)
		var used := 0
		var k := 0
		while used < TEX:
			var lw := 2 + int(h(y, k, seed + 1) * 5.0)
			var v := fbm(posmod(x, TEX), y, seed + 7)
			var tone := 3
			if v > 0.62:
				tone = 5
			elif v > 0.48:
				tone = 4
			elif v < 0.3:
				tone = 2
			if y % 2 == 0 and h(y, k, seed + 2) > 0.55:
				tone = mini(tone + 1, 5)
			if h(y, k, seed + 3) < 0.08:
				tone = 1
			for i in mini(lw, TEX - used):
				img.set_pixel(posmod(x + i, TEX), y, r[tone])
			# Short darker break between strokes.
			if h(y, k, seed + 4) > 0.45:
				img.set_pixel(posmod(x + lw, TEX), y, r[maxi(tone - 1, 1)])
				lw += 1
			x += lw
			used += lw
			k += 1


## Stone: irregular rounded cobbles (horizontally stretched cells), 1 px dark gaps,
## lit top edge and shaded bottom edge on each stone.
func _tex_cobbles(img: Image, r: Array[Color], seed: int) -> void:
	var cells := 120
	var pts: Array[Vector2] = []
	var tone := PackedInt32Array()
	for i in cells:
		pts.append(Vector2(h(i, 1, seed) * TEX, h(i, 2, seed) * TEX))
		var t := h(i, 3, seed)
		tone.append(2 if t < 0.2 else (3 if t < 0.75 else 4))
	var grid := PackedInt32Array()
	grid.resize(TEX * TEX)
	for y in TEX:
		for x in TEX:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := 1e9
			var d2 := 1e9
			var best := 0
			for i in cells:
				var dx := absf(p.x - pts[i].x)
				var dy := absf(p.y - pts[i].y)
				dx = minf(dx, TEX - dx) * 0.62
				dy = minf(dy, TEX - dy)
				var d := sqrt(dx * dx + dy * dy)
				if d < d1:
					d2 = d1
					d1 = d
					best = i
				elif d < d2:
					d2 = d
			grid[y * TEX + x] = -1 if d2 - d1 < 0.75 else best
	for y in TEX:
		for x in TEX:
			var c := grid[y * TEX + x]
			if c < 0:
				img.set_pixel(x, y, r[1])
				continue
			var t := tone[c]
			var up := grid[posmod(y - 1, TEX) * TEX + x] < 0
			var down := grid[posmod(y + 1, TEX) * TEX + x] < 0
			var left := grid[y * TEX + posmod(x - 1, TEX)] < 0
			if up:
				t += 1
				if left:
					t += 1
			elif down:
				t -= 1
			img.set_pixel(x, y, r[clampi(t, 1, 6)])


func _ref_texture(kind: String, seed: int) -> Image:
	var img := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	match kind:
		"dirt":
			_tex_strokes(img, _pal("dirt"), seed)
		"dirt_wall":
			_tex_strokes(img, _pal("dirt_wall"), seed)
		"stone":
			_tex_cobbles(img, _pal("stone"), seed)
		"stone_wall":
			_tex_cobbles(img, _pal("stone_wall"), seed)
		"sand":
			_tex_strokes(img, _pal("sand"), seed)
	return img


## Per-pixel terrain from the tile grids, with a smoothed silhouette (slopes and
## corners come out diagonal and rounded) and noisy boundaries between materials.
func _compose_natural(img: Image, b: PackedInt32Array, w: PackedInt32Array, W: int, H: int) -> void:
	var pw := W * T
	var ph := H * T
	var occ := func(tx: int, ty: int, grid: PackedInt32Array, walls: bool) -> float:
		tx = clampi(tx, 0, W - 1)
		if ty >= H:
			return 1.0
		if ty < 0:
			return 0.0
		var m := grid[ty * W + tx]
		return 1.0 if (m >= 0 if walls else _solid(m)) else 0.0
	var field := func(px: int, py: int, grid: PackedInt32Array, walls: bool) -> float:
		var fx := (px + 0.5) / T - 0.5
		var fy := (py + 0.5) / T - 0.5
		var ix := floori(fx)
		var iy := floori(fy)
		var tx := smoothstep(0.0, 1.0, fx - ix)
		var ty := smoothstep(0.0, 1.0, fy - iy)
		var a: float = lerpf(occ.call(ix, iy, grid, walls), occ.call(ix + 1, iy, grid, walls), tx)
		var c: float = lerpf(occ.call(ix, iy + 1, grid, walls), occ.call(ix + 1, iy + 1, grid, walls), tx)
		return lerpf(a, c, ty)
	var own := PackedInt32Array()
	own.resize(pw * ph)
	var wall_own := PackedInt32Array()
	wall_own.resize(pw * ph)
	for py in ph:
		for px in pw:
			var n := (pnoise(posmod(px, TEX), posmod(py, TEX), 4, 3) - 0.5) * 0.45 + (pnoise(posmod(px, TEX), posmod(py, TEX), 2, 4) - 0.5) * 0.15
			var solid: bool = float(field.call(px, py, b, false)) + n > 0.5
			own[py * pw + px] = -1
			if solid:
				# Material: tile under a noise-shifted point, so materials meet on wavy lines.
				var ox := roundi((pnoise(posmod(px, TEX), posmod(py, TEX), 8, 11) - 0.5) * 9.0)
				var oy := roundi((pnoise(posmod(px, TEX), posmod(py, TEX), 8, 12) - 0.5) * 9.0)
				var m := -1
				for cand: Vector2i in [Vector2i(px + ox, py + oy), Vector2i(px, py)]:
					var tx := clampi(cand.x / T, 0, W - 1)
					var ty := clampi(cand.y / T, 0, H - 1)
					if _solid(b[ty * W + tx]):
						m = b[ty * W + tx]
						break
				if m < 0:
					var tx := px / T
					var ty := py / T
					for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
						var nx := clampi(tx + d.x, 0, W - 1)
						var ny := clampi(ty + d.y, 0, H - 1)
						if _solid(b[ny * W + nx]):
							m = b[ny * W + nx]
							break
				own[py * pw + px] = m
			var wsolid: bool = float(field.call(px, py, w, true)) + n * 0.6 > 0.5
			wall_own[py * pw + px] = w[clampi(py / T, 0, H - 1) * W + clampi(px / T, 0, W - 1)] if wsolid else -1
			if wsolid and wall_own[py * pw + px] < 0:
				for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
					var nx := clampi(px / T + d.x, 0, W - 1)
					var ny := clampi(py / T + d.y, 0, H - 1)
					if w[ny * W + nx] >= 0:
						wall_own[py * pw + px] = w[ny * W + nx]
						break
	var use_var := style.has("dirt_mode")
	var tex := {}
	for kv: Array in [["dirt", 101], ["stone", 202], ["sand", 303], ["dirt_wall", 404], ["stone_wall", 505]]:
		tex[kv[0]] = _variant_texture(kv[0], kv[1]) if use_var else _ref_texture(kv[0], kv[1])
	var pal := {"dirt": _pal(String(style.get("dirt_pal", "dirt"))), "stone": _pal(String(style.get("stone_pal", "stone"))), "sand": _pal("sand")}
	var g := _pal("grass")
	var open := func(x: int, y: int) -> bool:
		if x < 0 or x >= pw or y < 0:
			return true
		if y >= ph:
			return false
		return own[y * pw + x] < 0
	# Walls (behind), softly shaded toward their edges.
	for py in ph:
		for px in pw:
			if own[py * pw + px] >= 0:
				continue
			var wi := wall_own[py * pw + px]
			if wi < 0:
				continue
			var key := "stone_wall" if wi == 1 else "dirt_wall"
			img.set_pixel(px, py, (tex[key] as Image).get_pixel(posmod(px, TEX), posmod(py, TEX)))
	for py in ph:
		for px in pw:
			var m := own[py * pw + px]
			if m < 0:
				continue
			var key := "dirt"
			if m == 2 or (m >= 9 and m <= 13):
				key = "stone"
			elif m == 3:
				key = "sand"
			var r: Array[Color] = pal[key]
			var c: Color = (tex[key] as Image).get_pixel(posmod(px, TEX), posmod(py, TEX))
			var top := 99
			for k in range(1, 6):
				if open.call(px, py - k):
					top = k
					break
			var below := 99
			for k in range(1, 4):
				if open.call(px, py + k):
					below = k
					break
			if m == 1 and top <= 4:
				var lim := 3 + int(h(px, 0, 5) * 2.0)
				if top <= lim:
					c = g[5] if top == 1 else (g[4] if top == 2 else (g[3] if top < lim else g[1]))
			elif top == 1:
				c = c.lerp(r[6], 0.3)
			if below == 1:
				c = c.lerp(r[1], 0.45)
			elif below == 2:
				c = c.lerp(r[1], 0.22)
			img.set_pixel(px, py, c)
	# Ore nuggets on top of the stone where the tile is ore.
	for ty in H:
		for tx in W:
			var m := b[ty * W + tx]
			if m < 9 or m > 13:
				continue
			var orr := ramp(_accent(BLOCKS[m]))
			for n in 2:
				var cx := tx * T + 1 + int(h(tx * 3 + n, ty, 51) * 5.0)
				var cy := ty * T + 1 + int(h(tx, ty * 3 + n, 52) * 5.0)
				for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var qx := cx + d.x
					var qy := cy + d.y
					if own[qy * pw + qx] >= 0:
						img.set_pixel(qx, qy, orr[6] if d == Vector2i.ZERO else (orr[2] if d.y == 1 else orr[4]))
	# Grass blades above grassy surfaces, and grass draping down the sides.
	for py in ph:
		for px in pw:
			if own[py * pw + px] != 1:
				continue
			if open.call(px, py - 1):
				var tall := 0
				var r1 := h(px, 1, 9)
				if r1 > 0.25:
					tall = 1 + int(h(px, 2, 9) * 5.0)
				for k in tall:
					if open.call(px, py - 1 - k):
						img.set_pixel(px, py - 1 - k, g[5] if k == tall - 1 else (g[4] if k > 0 else g[3]))
			for side in [-1, 1]:
				if open.call(px + side, py) and not open.call(px, py + 1):
					var depth := 0
					while depth < 9 and not open.call(px, py - depth - 1):
						depth += 1
					if depth < 4 + int(h(px, py / 3, 17) * 4.0):
						img.set_pixel(px, py, g[2] if depth > 2 else g[3])


# --- backdrop v2 and layered pines -------------------------------------------

const PINE_COLORS := {
	"green": ["1c2e18", "2f4a27", "40642f", "557f3a", "6f9a48"],
	"olive": ["2a2a14", "47471f", "5f5f28", "787834", "939147"],
	"teal": ["10292a", "1d4442", "275b57", "33736c", "4c8f84"],
	"gold": ["2e2010", "5a3e17", "7a5a1f", "967526", "b39338"],
}


func _hexes(list: Array) -> Array[Color]:
	var out: Array[Color] = []
	for s: String in list:
		out.append(Color(s))
	return out


## Pine built from tiers of drooping branch clumps. Each clump has a lit upper edge
## and a dark underside, so tiers read as layered boughs.
func _pine2(height: int, seed: int, kind: String, outline: bool = true) -> Image:
	var p := _hexes(PINE_COLORS[kind])
	var bark := _hexes(["3a2220", "5c3a33", "7a5048", "93685c"])
	var w := int(height * 0.5) | 1
	var img := Image.create_empty(w, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var cx := w / 2
	var trunk_w := maxi(4, height / 28)
	for y in range(int(height * 0.5), height):
		for x in range(cx - trunk_w / 2, cx + trunk_w / 2 + 1):
			var rel := x - (cx - trunk_w / 2)
			var c := bark[2]
			if rel == 0:
				c = bark[3]
			elif rel >= trunk_w - 1:
				c = bark[1]
			elif h(x, y / 3, seed) > 0.7:
				c = bark[1]
			img.set_pixel(x, y, c)
	var foliage_bottom := int(height * 0.86)
	var tiers := 7 + int(h(1, 1, seed) * 3.0)
	var spacing := float(foliage_bottom - 4) / (tiers + 0.6)
	# Dark core cone so no sky shows through between boughs.
	var core_bottom := int(2.0 + (tiers - 0.4) * spacing)
	for y in range(2, core_bottom):
		var f := float(y) / foliage_bottom
		var half := int(f * w * 0.38)
		for x in range(cx - half, cx + half + 1):
			img.set_pixel(x, y, p[0] if absi(x - cx) < half - 1 else p[1])
	for tt in tiers:
		var t := tiers - 1 - tt
		var k := float(t + 1) / tiers
		var y0 := 2.0 + t * spacing + (h(t, 9, seed) - 0.5) * spacing * 0.3
		var reach := lerpf(3.0, w * 0.48, k)
		for side in [-1, 1]:
			for f in 4:
				var length := reach * (1.0 - f * 0.2) * (0.7 + 0.35 * h(t, f + side * 7, seed))
				var sy := y0 + f * spacing * 0.22 + (h(t, f + side * 3, seed + 1) - 0.5) * spacing * 0.3
				var droop := spacing * (0.8 + 0.5 * h(t, f + side, seed + 2))
				var thick := spacing * (0.65 + 0.3 * h(t, f, seed + 3))
				var steps := int(length)
				for i in steps + 1:
					var u := float(i) / maxf(length, 1.0)
					var x: int = cx + side * i
					var yc := sy + pow(u, 1.5) * droop
					var th := lerpf(thick, 1.5, pow(u, 0.8))
					var ytop := int(yc - th * 0.45)
					var ybot := int(yc + th * 0.55)
					for y in range(ytop, ybot + 1):
						if x < 0 or x >= w or y < 0 or y >= height:
							continue
						var v := float(y - ytop) / maxf(ybot - ytop, 1.0)
						var c := p[3]
						if v < 0.2:
							c = p[4]
						elif v > 0.75:
							c = p[1]
						elif v > 0.5:
							c = p[2]
						# Needle strokes along the bough.
						if posmod(x + y * 2 + t, 5) == 0 and v > 0.2 and v < 0.7:
							c = p[2]
						img.set_pixel(x, y, c)
	# Top spike.
	for y in range(0, int(spacing)):
		img.set_pixel(cx, y, p[3])
		if y > 2:
			img.set_pixel(cx - 1, y, p[2])
			img.set_pixel(cx + 1, y, p[1])
	if not outline:
		return img
	var out := img.duplicate() as Image
	for y in height:
		for x in w:
			if img.get_pixel(x, y).a == 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= height or img.get_pixel(nx, ny).a == 0.0:
					out.set_pixel(x, y, p[0].darkened(0.3))
					break
	return out


func _cloud(img: Image, cx: int, cy: int, size: int, seed: int) -> void:
	var white := Color("ffffff")
	var shade := Color("cfeaf8")
	var deep := Color("a9d6ef")
	var puffs: Array[Vector3] = []
	for i in 9:
		var px := cx + int((h(i, 1, seed) - 0.5) * size * 2.6)
		var r := size * (0.35 + 0.35 * h(i, 2, seed))
		puffs.append(Vector3(px, cy - r * 0.4, r))
	for y in range(cy - size, cy + 2):
		for x in range(cx - size * 2, cx + size * 2):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var inside := false
			var lit := false
			for pf in puffs:
				var d := Vector2(x - pf.x, y - pf.y).length()
				if d < pf.z:
					inside = true
					if y < pf.y - pf.z * 0.2:
						lit = true
			if inside:
				var c := white if lit else shade
				if y > cy - 2:
					c = deep
				img.set_pixel(x, y, c)


func _backdrop_v2(img: Image, px_w: int, px_h: int) -> void:
	for y in px_h:
		img.fill_rect(Rect2i(0, y, px_w, 1), Color("3fa9e8").lerp(Color("aee4f6"), clampf(y / 150.0, 0.0, 1.0)))
	# Sun with soft glow and faint rays.
	var sun := Vector2(px_w * 0.48, 34)
	for y in 160:
		for x in range(int(sun.x) - 160, int(sun.x) + 160):
			var d := Vector2(x, y).distance_to(sun)
			var c := img.get_pixel(x, y)
			var ang := atan2(y - sun.y, x - sun.x)
			var fall := clampf(1.0 - d / 160.0, 0.0, 1.0)
			var ray := maxf(0.0, sin(ang * 12.0 + 0.4)) * 0.18 * fall * fall
			var glow := fall * fall * 0.55
			if d < 18:
				c = Color("ffffff")
			else:
				c = c.lerp(Color("f2fff0"), clampf(glow + ray, 0.0, 0.92))
			img.set_pixel(x, y, c)
	for i in 7:
		_cloud(img, int(h(i, 1, 900) * px_w), 26 + int(h(i, 2, 900) * 64.0), 13 + int(h(i, 3, 900) * 13.0), i)
	# Mountain range, lit on the left of each slope.
	var rock := Color("6b6a63")
	for x in px_w:
		var top := 110 + roundi(14.0 * sin(x * 0.018 + 1.0) + 8.0 * sin(x * 0.047) + 4.0 * sin(x * 0.11 + 2.0))
		var slope := 14.0 * 0.018 * cos(x * 0.018 + 1.0) + 8.0 * 0.047 * cos(x * 0.047) + 4.0 * 0.11 * cos(x * 0.11 + 2.0)
		for y in range(top, px_h):
			var depth := float(y - top)
			var c := rock.lerp(rock.lightened(0.14), clampf(slope * 1.6, 0.0, 1.0) * clampf(1.0 - depth / 40.0, 0.0, 1.0))
			c = c.lerp(rock.darkened(0.12), clampf(-slope * 1.4, 0.0, 1.0) * clampf(1.0 - depth / 50.0, 0.0, 1.0))
			if y == top:
				c = rock.lightened(0.16)
			if posmod(x * 3 + y * 7 + int(pnoise(posmod(x, TEX), posmod(y, TEX), 8, 77) * 20.0), 23) == 0:
				c = c.darkened(0.08)
			img.set_pixel(x, y, c)
	# Rolling hills: far, mid, near, each with grass strokes; small trees on the far ones.
	var hill_cols := [Color("5aa848"), Color("3e9e2e"), Color("27a11a")]
	for layer in 3:
		var base: Color = hill_cols[layer]
		var y_base := 150 + layer * 18
		for x in px_w:
			var top := y_base + roundi(7.0 * sin(x * 0.02 + layer * 1.7) + 4.0 * sin(x * 0.055 + layer))
			for y in range(top, px_h):
				var c := base
				var stroke := posmod(x / 3 + y * 2 + int(pnoise(posmod(x, TEX), posmod(y, TEX), 8, layer) * 6.0), 9)
				if stroke == 0:
					c = base.lightened(0.08)
				elif stroke == 4:
					c = base.darkened(0.06)
				if y == top:
					c = base.lightened(0.12)
				img.set_pixel(x, y, c)
		if layer < 2:
			var count := 10 if layer == 0 else 8
			for i in count:
				var tx := int(h(i, layer, 950) * px_w)
				var ground := y_base + roundi(7.0 * sin(tx * 0.02 + layer * 1.7) + 4.0 * sin(tx * 0.055 + layer))
				var size := 16 + layer * 22 + int(h(i, 5, 950) * 10.0)
				var kinds := ["green", "olive", "teal"]
				var tree := _hazed(_pine2(size, i + layer * 50, kinds[i % 3]), Color("9fd6ea"), 0.45 - layer * 0.2)
				img.blend_rect(tree, Rect2i(Vector2i.ZERO, tree.get_size()), Vector2i(tx - tree.get_width() / 2, ground - tree.get_height() + 2))


# --- tileset variants (round 2 of the natural look) ---------------------------

## Smooth stone: evenly sized rounded cobbles shaded like soft domes (lit top-left),
## with mid-dark gaps rather than black ones, so the surface reads as one fluid mass.
func _tex_round_cobbles(img: Image, r: Array[Color], seed: int, cells: int, soft: float) -> void:
	# Jittered grid keeps cobbles evenly sized.
	var side := int(sqrt(float(cells)))
	var step := float(TEX) / side
	var pts: Array[Vector2] = []
	for gy in side:
		for gx in side:
			var off := (gy % 2) * step * 0.5
			pts.append(Vector2(fposmod(gx * step + off + (h(gx, gy, seed) - 0.5) * step * 0.5, TEX), gy * step + (h(gx, gy, seed + 1) - 0.5) * step * 0.5))
	for y in TEX:
		for x in TEX:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := 1e9
			var d2 := 1e9
			var best := Vector2.ZERO
			var bi := 0
			for i in pts.size():
				var dx := absf(p.x - pts[i].x)
				var dy := absf(p.y - pts[i].y)
				dx = minf(dx, TEX - dx) * 0.85
				dy = minf(dy, TEX - dy)
				var d := sqrt(dx * dx + dy * dy)
				if d < d1:
					d2 = d1
					d1 = d
					best = pts[i]
					bi = i
				elif d < d2:
					d2 = d
			var gap := d2 - d1
			if gap < 0.8:
				img.set_pixel(x, y, r[2] if soft > 0.5 else r[1])
				continue
			var o := Vector2(p.x - best.x, p.y - best.y)
			o.x -= roundf(o.x / TEX) * TEX
			o.y -= roundf(o.y / TEX) * TEX
			var rad := d1 + gap * 0.5
			var lit := -(o.x * 0.7 + o.y) / maxf(rad, 1.0)
			var base := 3.0 + (h(bi, 7, seed) - 0.5) * 0.9
			var t := base + lit * (1.0 - soft * 0.4)
			if gap < 1.6:
				t -= 0.6
			img.set_pixel(x, y, r[clampi(roundi(t), 1, 5)])


## Strokes with adjustable softness (fewer dark breaks, narrower tone range).
func _tex_strokes_soft(img: Image, r: Array[Color], seed: int) -> void:
	for y in TEX:
		var x := int(h(y, 0, seed) * TEX)
		var used := 0
		var k := 0
		while used < TEX:
			var lw := 3 + int(h(y, k, seed + 1) * 6.0)
			var v := fbm(posmod(x, TEX), y, seed + 7)
			var tone := 3 if v < 0.55 else 4
			if v < 0.3:
				tone = 2
			if y % 2 == 0 and h(y, k, seed + 2) > 0.6:
				tone = mini(tone + 1, 5)
			for i in mini(lw, TEX - used):
				img.set_pixel(posmod(x + i, TEX), y, r[tone])
			if h(y, k, seed + 4) > 0.7:
				img.set_pixel(posmod(x + lw, TEX), y, r[maxi(tone - 1, 2)])
				lw += 1
			x += lw
			used += lw
			k += 1


## Clods with stroke texture inside: rounded lumps, each made of short horizontal strokes.
func _tex_clod_strokes(img: Image, r: Array[Color], seed: int) -> void:
	_tex_lumps(img, r, seed)
	for y in TEX:
		for x in TEX:
			var c := img.get_pixel(x, y)
			if c == r[1]:
				continue
			if posmod(x + int(h(y, x / 5, seed + 21) * 5.0), 6) == 0:
				img.set_pixel(x, y, c.darkened(0.08))


func _variant_texture(kind: String, seed: int) -> Image:
	var img := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	var dirt_pal := _pal(String(style.get("dirt_pal", "dirt")))
	var wall_pal := _pal(String(style.get("dirt_wall_pal", "dirt_wall")))
	var mode: String = style.get("dirt_mode", "strokes")
	var dirt_fn := func(target: Image, pal: Array[Color], s: int) -> void:
		match mode:
			"strokes":
				_tex_strokes(target, pal, s)
			"soft_strokes":
				_tex_strokes_soft(target, pal, s)
			"clods":
				_tex_lumps(target, pal, s)
			"clod_strokes":
				_tex_clod_strokes(target, pal, s)
	match kind:
		"dirt":
			dirt_fn.call(img, dirt_pal, seed)
		"dirt_wall":
			dirt_fn.call(img, wall_pal, seed)
		"stone":
			_tex_round_cobbles(img, _pal(String(style.get("stone_pal", "stone"))), seed, int(style.stone_cells), float(style.stone_soft))
		"stone_wall":
			_tex_round_cobbles(img, _pal("stone_wall"), seed, int(style.stone_cells), float(style.stone_soft))
		"sand":
			_tex_strokes_soft(img, _pal("sand"), seed)
	return img


# --- export for the game -------------------------------------------------------
# godot --headless --path . --script res://tools/generate_tiles.gd -- --export=game
# Writes everything the game draws procedurally, in the chosen style (V5 = "t5").

## Tile atlas rows for the game. Order must match atlas_row in data/tiles/*.tres.
## Solid blocks are drawn by the terrain shader; the atlas only supplies collision
## shapes for them, and the actual art for platforms and ropes.
const GAME_BLOCKS := [
	{"id": "dirt", "base": Color("85633f"), "kind": "dirt"},
	{"id": "grass", "base": Color("85633f"), "kind": "dirt"},
	{"id": "stone", "base": Color("757064"), "kind": "stone"},
	{"id": "copper_ore", "base": Color("757064"), "kind": "stone"},
	{"id": "wood_planks", "base": Color("9a6a3a"), "kind": "planks"},
	{"id": "wood_platform", "base": Color("9a6a3a"), "kind": "platform"},
	{"id": "rope", "base": Color("bf9a5e"), "kind": "rope"},
]

const BD_W := 1280


func _export_game() -> void:
	style_name = "t5"
	style = STYLES[style_name]
	var root := "res://assets"
	for sub in ["terrain", "trees", "decor", "backdrop", "tiles"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root.path_join(sub)))
	# Terrain material textures (64x64, seamless).
	_variant_texture("dirt", 101).save_png(root + "/terrain/dirt.png")
	_variant_texture("stone", 202).save_png(root + "/terrain/stone.png")
	_variant_texture("dirt_wall", 404).save_png(root + "/terrain/dirt_wall.png")
	_variant_texture("stone_wall", 505).save_png(root + "/terrain/stone_wall.png")
	# Wood boards in the colors of Patrick's reference (variant via --wood=A|B|C).
	var planks := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	_tex_boards(planks, wood_variant, 7)
	planks.save_png(root + "/terrain/planks.png")
	var planks_wall := planks.duplicate() as Image
	for y in TEX:
		for x in TEX:
			var c := planks_wall.get_pixel(x, y)
			planks_wall.set_pixel(x, y, Color.from_hsv(c.h, c.s * 0.9, c.v).darkened(0.45))
	planks_wall.save_png(root + "/terrain/planks_wall.png")
	var ore := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	ore.fill(Color.TRANSPARENT)
	_tex_ore(ore, _pal("stone_warm"), ramp(Color("d0773a")), 77)
	ore.save_png(root + "/terrain/ore_copper.png")
	var noise := Image.create_empty(TEX, TEX, false, Image.FORMAT_RGBA8)
	for y in TEX:
		for x in TEX:
			noise.set_pixel(x, y, Color(pnoise(x, y, 4, 3), pnoise(x, y, 2, 4), pnoise(x, y, 8, 11), pnoise(x, y, 8, 12)))
	noise.save_png(root + "/terrain/noise.png")
	# Collision atlas plus platform and rope art.
	_build_atlas(GAME_BLOCKS, false).save_png(root + "/tiles/blocks.png")
	# Trees: four color families, three sizes each, no outline.
	var kinds := ["green", "olive", "teal", "gold"]
	for k in kinds.size():
		for i in 3:
			_pine2(110 + i * 35 + k * 5, k * 10 + i, kinds[k], false).save_png(root + "/trees/pine_%s_%d.png" % [kinds[k], i])
	# Flowers.
	var petals := ["e2508a", "f2d34a", "8a6cf0", "f08a3a", "ffffff"]
	for i in petals.size():
		var f := Image.create_empty(5, 10, false, Image.FORMAT_RGBA8)
		f.fill(Color.TRANSPARENT)
		_flower(f, 2, 10, Color(petals[i]), i)
		f.save_png(root + "/decor/flower_%d.png" % i)
	_export_backdrop(root + "/backdrop")
	print("export: game art written to %s" % root)


func _wave(x: float, k: float, phase: float) -> float:
	return sin(TAU * x * k / BD_W + phase)


func _export_backdrop(dir: String) -> void:
	# Sun: white core with a soft glow and faint rays, on transparent.
	var sun := Image.create_empty(320, 200, false, Image.FORMAT_RGBA8)
	var c0 := Vector2(160, 70)
	for y in 200:
		for x in 320:
			var d := Vector2(x, y).distance_to(c0)
			var fall := clampf(1.0 - d / 150.0, 0.0, 1.0)
			var ang := atan2(y - c0.y, x - c0.x)
			var ray := maxf(0.0, sin(ang * 12.0 + 0.4)) * 0.22 * fall * fall
			var a := clampf(fall * fall * 0.6 + ray, 0.0, 0.95)
			if d < 20:
				a = 1.0
			sun.set_pixel(x, y, Color(0.96, 1.0, 0.94, a))
	sun.save_png(dir + "/sun.png")
	# Clouds (tile horizontally).
	var clouds := Image.create_empty(BD_W, 120, false, Image.FORMAT_RGBA8)
	clouds.fill(Color.TRANSPARENT)
	for i in 9:
		var cx := int(h(i, 1, 900) * BD_W)
		var cy := 30 + int(h(i, 2, 900) * 70.0)
		var size := 14 + int(h(i, 3, 900) * 14.0)
		for shift in [-BD_W, 0, BD_W]:
			_cloud(clouds, cx + shift, cy, size, i)
	clouds.save_png(dir + "/clouds.png")
	# Mountains: lit on slopes facing left, faint streaks.
	var mtn := Image.create_empty(BD_W, 130, false, Image.FORMAT_RGBA8)
	mtn.fill(Color.TRANSPARENT)
	var rock := Color("6b6a63")
	for x in BD_W:
		var hgt := 30.0 + 18.0 * _wave(x, 3, 1.0) + 10.0 * _wave(x, 8, 0.2) + 5.0 * _wave(x, 19, 2.0)
		var slope := 18.0 * cos(TAU * x * 3 / BD_W + 1.0) * 3 + 10.0 * cos(TAU * x * 8 / BD_W + 0.2) * 8 + 5.0 * cos(TAU * x * 19 / BD_W + 2.0) * 19
		slope = slope * TAU / BD_W
		var top := int(130 - 20 - hgt - 40)
		for y in range(maxi(top, 0), 130):
			var depth := float(y - top)
			var c := rock.lerp(rock.lightened(0.14), clampf(-slope * 1.6, 0.0, 1.0) * clampf(1.0 - depth / 40.0, 0.0, 1.0))
			c = c.lerp(rock.darkened(0.12), clampf(slope * 1.4, 0.0, 1.0) * clampf(1.0 - depth / 50.0, 0.0, 1.0))
			if y == top:
				c = rock.lightened(0.16)
			mtn.set_pixel(x, y, c)
	mtn.save_png(dir + "/mountains.png")
	# Rolling hills, two layers, each with grass strokes and small hazy pines.
	var cols := [Color("4fa543"), Color("31a024")]
	var kinds := ["green", "olive", "teal"]
	for layer in 2:
		var hh := 110 + layer * 20
		var img := Image.create_empty(BD_W, hh, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		var base: Color = cols[layer]
		var tops := PackedInt32Array()
		for x in BD_W:
			tops.append(int(40 + layer * 10 + 8.0 * _wave(x, 4 + layer, layer * 1.7) + 4.0 * _wave(x, 11, layer)))
		var count := 14 if layer == 0 else 9
		for i in count:
			var tx := int(h(i, layer, 950) * BD_W)
			var size := 18 + layer * 22 + int(h(i, 5, 950) * 12.0)
			var tree := _hazed(_pine2(size, i + layer * 50, kinds[i % 3], false), Color("9fd6ea"), 0.45 - layer * 0.2)
			for shift in [-BD_W, 0, BD_W]:
				img.blend_rect(tree, Rect2i(Vector2i.ZERO, tree.get_size()), Vector2i(tx + shift - tree.get_width() / 2, tops[posmod(tx, BD_W)] - tree.get_height() + 3))
		for x in BD_W:
			for y in range(tops[x], hh):
				var c := base
				var stroke := posmod(x / 3 + y * 2 + int(pnoise(posmod(x, TEX), posmod(y, TEX), 8, layer) * 6.0), 9)
				if stroke == 0:
					c = base.lightened(0.08)
				elif stroke == 4:
					c = base.darkened(0.06)
				if y == tops[x]:
					c = base.lightened(0.12)
				img.set_pixel(x, y, c)
		img.save_png(dir + "/hills_%d.png" % layer)


# --- wood boards (Patrick's reference: muted olive-brown, long boards, nails) --

## [palette dark..light (7), board band heights summing to 64, min length, max length, nails]
const WOOD_VARIANTS := {
	"A": [["1e160a", "2c210e", "3c2d11", "4b4022", "574c2c", "5d4f2c", "6e5f38"], [5, 6, 5, 5, 6, 5, 5, 6, 5, 5, 6, 5], 14, 22, true],
	"B": [["221509", "33230f", "46301a", "57402a", "654c33", "6f5638", "80683f"], [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4], 20, 30, false],
	"C": [["2a2210", "3b3014", "50431f", "62552c", "6f6235", "7a6c3b", "8c7d48"], [8, 8, 8, 8, 8, 8, 8, 8], 10, 16, true],
}


## Horizontal boards: lit top row, grain, shaded bottom row, a dark seam under each
## board and at each joint, and optional nails near the joints. Tiles seamlessly.
func _tex_boards(img: Image, variant: String, seed: int) -> void:
	var spec: Array = WOOD_VARIANTS[variant]
	var r := _hexes(spec[0])
	var bands: Array = spec[1]
	var min_len: int = spec[2]
	var max_len: int = spec[3]
	var nails: bool = spec[4]
	var y0 := 0
	for b in bands.size():
		var bh: int = bands[b]
		var x := int(h(b, 0, seed) * TEX)
		var used := 0
		var k := 0
		while used < TEX:
			var len := min_len + int(h(b, k, seed + 1) * (max_len - min_len + 1))
			len = mini(len, TEX - used)
			var tone := 4 if h(b, k, seed + 2) > 0.35 else 3
			for i in len:
				var px := posmod(x + i, TEX)
				for j in bh:
					var c := r[tone]
					if j == bh - 1 or i == 0:
						c = r[1]  # seam under the board / joint at its start
					elif j == 0:
						c = r[tone + 2] if i > 1 else r[tone + 1]
					elif j == bh - 2:
						c = r[tone - 1]
					elif i == 1:
						c = r[tone + 1]
					elif pnoise(px, y0 + j, 8, seed + b) > 0.62:
						c = r[tone - 1]
					img.set_pixel(px, y0 + j, c)
			if nails and bh >= 5 and len > 6:
				var ny := y0 + (bh - 1) / 2
				for nx in [x + 2, x + len - 3]:
					img.set_pixel(posmod(nx, TEX), ny, r[0])
					img.set_pixel(posmod(nx - 1, TEX), ny - 1, r[6])
			x += len
			used += len
			k += 1
		y0 += bh
