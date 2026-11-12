extends SceneTree
## Generates placeholder tile art in one of several styles, plus the placeholder player.
##
## Usage (from the project folder):
##   godot --headless --path . --script res://tools/generate_tiles.gd -- --style=rough
##   godot --headless --path . --script res://tools/generate_tiles.gd -- --style=soft --out=/tmp/x --preview
##
## Styles: rough (Terraria-like), soft (Starbound-like), crumbly (chunky, rocky).
## Writes blocks.png and walls.png into --out (default res://assets/tiles), the player
## placeholder into res://assets/sprites (only when --out is the default), and with
## --preview a mock scene (preview.png at 2x, closeup.png at 4x) to judge the style.
##
## Atlas layout (see assets/ASSETS.md): one row per material, 48 columns =
## 16 neighbor masks x 3 random variants. Column = mask * 3 + variant.
## Mask bits: 1 = up neighbor, 2 = right, 4 = down, 8 = left (bit set = neighbor present).

const T := 16
const VARIANTS := 3
const MASKS := 16
const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8

const STONE := Color("7a7c80")

## Block materials. Order = atlas row; must match atlas_row in data/tiles/*.tres.
const BLOCKS := [
	{"id": "dirt", "base": Color("8b5a2b"), "kind": "natural", "rough": 1.0},
	{"id": "grass", "base": Color("8b5a2b"), "kind": "grass", "rough": 0.8, "accent": Color("4caf50")},
	{"id": "stone", "base": STONE, "kind": "stone", "rough": 1.0},
	{"id": "sand", "base": Color("d8c27a"), "kind": "sand", "rough": 1.0},
	{"id": "snow", "base": Color("eef3f7"), "kind": "snow", "rough": 0.8},
	{"id": "ice", "base": Color("9fd8f0"), "kind": "ice", "rough": 0.4},
	{"id": "mud", "base": Color("5b4636"), "kind": "natural", "rough": 1.0},
	{"id": "clay", "base": Color("b5654a"), "kind": "natural", "rough": 0.9},
	{"id": "wood_planks", "base": Color("a0703c"), "kind": "planks", "rough": 0.25},
	{"id": "copper_ore", "base": STONE, "kind": "ore", "rough": 1.0, "accent": Color("d27d2d")},
	{"id": "iron_ore", "base": STONE, "kind": "ore", "rough": 1.0, "accent": Color("b9a089")},
	{"id": "silver_ore", "base": STONE, "kind": "ore", "rough": 1.0, "accent": Color("dfe6ee")},
	{"id": "gold_ore", "base": STONE, "kind": "ore", "rough": 1.0, "accent": Color("f2c94c")},
	{"id": "arcanite_ore", "base": STONE, "kind": "ore", "rough": 1.0, "accent": Color("9b59f6")},
	{"id": "wood_platform", "base": Color("a0703c"), "kind": "platform", "rough": 0.0},
	{"id": "rope", "base": Color("c8a165"), "kind": "rope", "rough": 0.0},
]

## Background walls. Order = atlas row in walls.png.
const WALLS := [
	{"id": "dirt_wall", "base": Color("8b5a2b"), "kind": "natural"},
	{"id": "stone_wall", "base": STONE, "kind": "stone"},
	{"id": "wood_wall", "base": Color("a0703c"), "kind": "planks"},
	{"id": "sandstone_wall", "base": Color("c9ad66"), "kind": "sand"},
]

const STYLES := {
	"rough": {"erosion": 2, "corner": 3, "outline": 0.5, "rim2": 0.0, "contrast": 1.0, "cracks": false, "highlight": 0.18, "pebbles": 4, "pebble_size": 2, "cobble_cells": 4},
	"soft": {"erosion": 1, "corner": 4, "outline": 0.3, "rim2": 0.14, "contrast": 0.8, "cracks": false, "highlight": 0.12, "pebbles": 3, "pebble_size": 3, "cobble_cells": 0},
	"crumbly": {"erosion": 3, "corner": 5, "outline": 0.72, "rim2": 0.0, "contrast": 1.2, "cracks": true, "highlight": 0.24, "pebbles": 3, "pebble_size": 2, "cobble_cells": 5},
}

var style: Dictionary
var style_name := "rough"


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
	if not STYLES.has(style_name):
		push_error("unknown style %s (use %s)" % [style_name, ", ".join(STYLES.keys())])
		quit(1)
		return
	style = STYLES[style_name]
	DirAccess.make_dir_recursive_absolute(_abs(out))

	var blocks := _build_atlas(BLOCKS, false)
	var walls := _build_atlas(WALLS, true)
	blocks.save_png(out.path_join("blocks.png"))
	walls.save_png(out.path_join("walls.png"))
	var player := _make_player()
	if out == "res://assets/tiles":
		DirAccess.make_dir_recursive_absolute(_abs("res://assets/sprites"))
		player.save_png("res://assets/sprites/player_placeholder.png")
	if preview:
		_save_preview(blocks, walls, player, out)
	print("tiles: style=%s -> %s" % [style_name, out])
	quit()


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") else path


# --- noise -----------------------------------------------------------------

func h(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 982451653) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65536.0


func vnoise(x: int, y: int, scale: int, s: int) -> float:
	var gx := floori(float(x) / scale)
	var gy := floori(float(y) / scale)
	var tx := float(posmod(x, scale)) / scale
	var ty := float(posmod(y, scale)) / scale
	var a := lerpf(h(gx, gy, s), h(gx + 1, gy, s), tx)
	var b := lerpf(h(gx, gy + 1, s), h(gx + 1, gy + 1, s), tx)
	return lerpf(a, b, ty)


func edge_profile(p: int, s: int) -> float:
	return clampf(0.7 * vnoise(p, 0, 4, s) + 0.3 * h(p, 7, s), 0.0, 0.999)


func shades(base: Color) -> Array[Color]:
	return [base.darkened(0.35), base.darkened(0.17), base, base.lightened(0.1), base.lightened(0.24)]


# --- atlas -----------------------------------------------------------------

func _build_atlas(mats: Array, walls: bool) -> Image:
	var img := Image.create_empty(MASKS * VARIANTS * T, mats.size() * T, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for mi in mats.size():
		var mat: Dictionary = mats[mi]
		for mask in MASKS:
			for v in VARIANTS:
				var tile := _make_wall(mat, mask, v, mi) if walls else _make_block(mat, mask, v, mi)
				img.blit_rect(tile, Rect2i(0, 0, T, T), Vector2i((mask * VARIANTS + v) * T, mi * T))
	return img


func _make_block(mat: Dictionary, mask: int, v: int, mi: int) -> Image:
	var kind: String = mat.kind
	if kind == "platform":
		return _make_platform(mat, mask, v)
	if kind == "rope":
		return _make_rope(mat, mask)
	var seed := mi * 7919 + v * 131 + 17
	var img := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	_texture(img, mat, v, mi, mask)
	var solid := _shape(mask, seed, float(mat.rough))
	if kind == "grass":
		_draw_grass(img, solid, mask, mat.accent, seed)
	_apply_edges(img, solid, mask)
	return img


func _texture(img: Image, mat: Dictionary, v: int, mi: int, mask: int = 0) -> void:
	var base: Color = mat.base
	var sh := shades(base)
	var sd := mi * 1000 + v * 37 + mask * 101
	var contrast: float = style.contrast
	var kind: String = mat.kind
	match kind:
		"natural", "grass", "stone", "ore":
			for y in T:
				for x in T:
					var m := vnoise(x + v * 16, y, 6, sd)
					img.set_pixel(x, y, base.lerp(sh[1], clampf(m * 0.7 * contrast, 0.0, 1.0)))
			if kind == "stone" or kind == "ore":
				_cobble(img, sh, sd)
			_pebbles(img, sh, sd, int(style.pebbles))
			if kind == "ore":
				_draw_ore(img, mat.accent, sd + 3)
		"sand":
			for y in T:
				for x in T:
					var n := h(x + v * 16, y, sd)
					var col := base
					if n < 0.12:
						col = sh[1]
					elif n > 0.9:
						col = sh[3]
					if h(x, y, sd + 3) > 0.985:
						col = sh[0]
					img.set_pixel(x, y, col)
			_pebbles(img, sh, sd, 2)
		"snow":
			for y in T:
				for x in T:
					var n := vnoise(x + v * 16, y, 5, sd)
					img.set_pixel(x, y, base.lerp(Color("b9c9e6"), (1.0 - n) * 0.32 * contrast))
		"ice":
			for y in T:
				for x in T:
					var col := base.lerp(base.darkened(0.14), vnoise(x + v * 16, y, 6, sd))
					if posmod(x - y + v * 5, 9) == 0 and h(x, y, sd) > 0.25:
						col = base.lightened(0.4)
					img.set_pixel(x, y, col)
		"planks":
			for y in T:
				for x in T:
					var row := y / 4
					var col := base
					if y % 4 == 3:
						col = base.darkened(0.38)
					elif x == posmod(row * 7 + v * 5, T):
						col = base.darkened(0.32)
					elif h(x / 3, y, sd + row) > 0.78:
						col = base.darkened(0.12)
					elif y % 4 == 0:
						col = base.lightened(0.08)
					img.set_pixel(x, y, col)


## Small raised stones: light top-left, shadow bottom-right. Size and count depend on style.
func _pebbles(img: Image, sh: Array[Color], sd: int, count: int) -> void:
	var size: int = style.pebble_size
	for i in count:
		var px := 1 + int(h(i, 3, sd) * (T - size - 2))
		var py := 1 + int(h(i, 4, sd) * (T - size - 2))
		for dy in size:
			for dx in size:
				if size >= 3 and (dx == 0 or dx == size - 1) and (dy == 0 or dy == size - 1):
					continue
				img.set_pixel(px + dx, py + dy, sh[3])
		img.set_pixel(px + (1 if size >= 3 else 0), py, sh[4])
		for d in size:
			img.set_pixel(mini(px + d + 1, T - 1), mini(py + size, T - 1), sh[0])
		img.set_pixel(mini(px + size, T - 1), mini(py + size - 1, T - 1), sh[0])


## Rock cells split by cracks (Voronoi). Strength depends on style.
func _cobble(img: Image, sh: Array[Color], sd: int) -> void:
	var cells: int = style.cobble_cells
	if cells <= 0:
		return
	var pts: Array[Vector2] = []
	for i in cells:
		pts.append(Vector2(h(i, 1, sd) * T, h(i, 2, sd) * T))
	var crack_col: Color = sh[0] if style.cracks else sh[1]
	var grid := PackedInt32Array()
	grid.resize(T * T)
	for y in T:
		for x in T:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := 1e9
			var d2 := 1e9
			var best := 0
			for i in pts.size():
				var d := p.distance_to(pts[i])
				if d < d1:
					d2 = d1
					d1 = d
					best = i
				elif d < d2:
					d2 = d
			grid[y * T + x] = best if d2 - d1 >= 0.9 else -1
	for y in T:
		for x in T:
			var c := grid[y * T + x]
			if c < 0:
				img.set_pixel(x, y, crack_col)
				continue
			var col := img.get_pixel(x, y)
			if style.cracks:
				col = col.lerp(sh[3] if h(c, 9, sd) > 0.5 else sh[1], 0.45)
			if y > 0 and grid[(y - 1) * T + x] < 0:
				col = col.lightened(0.14)
			img.set_pixel(x, y, col)


## Ore nuggets: dark rim, bright top-left, darker bottom.
func _draw_ore(img: Image, accent: Color, seed: int) -> void:
	var shapes := [
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
	]
	var placed: Array[Vector2i] = []
	for c in 3:
		var shape: Array = shapes[int(h(c, 5, seed) * 2.99)]
		var cx := 2 + int(h(c, 0, seed) * 10)
		var cy := 2 + int(h(c, 1, seed) * 10)
		for o: Vector2i in shape:
			placed.append(Vector2i(clampi(cx + o.x, 0, T - 1), clampi(cy + o.y, 0, T - 1)))
	for p in placed:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := p + d
			if q.x >= 0 and q.y >= 0 and q.x < T and q.y < T and not placed.has(q):
				img.set_pixel(q.x, q.y, accent.darkened(0.6))
	for p in placed:
		img.set_pixel(p.x, p.y, accent)
	for p in placed:
		if not placed.has(p + Vector2i(0, -1)) and not placed.has(p + Vector2i(-1, 0)):
			img.set_pixel(p.x, p.y, accent.lightened(0.45))
		elif not placed.has(p + Vector2i(0, 1)):
			img.set_pixel(p.x, p.y, accent.darkened(0.25))


func _shape(mask: int, seed: int, rough: float) -> PackedByteArray:
	var s := PackedByteArray()
	s.resize(T * T)
	s.fill(1)
	var emax := roundi(float(style.erosion) * rough)
	for side in 4:
		if mask & (1 << side):
			continue
		for p in T:
			var d := floori(edge_profile(p, seed + side * 97) * (emax + 1))
			for k in d:
				var xy := _side_pixel(side, p, k)
				s[xy.y * T + xy.x] = 0
	var r := roundi(float(style.corner) * maxf(rough, 0.5))
	var corners := [[UP | LEFT, 0, 0], [UP | RIGHT, T - 1, 0], [DOWN | RIGHT, T - 1, T - 1], [DOWN | LEFT, 0, T - 1]]
	for c: Array in corners:
		if mask & int(c[0]):
			continue
		for y in T:
			for x in T:
				var dx := absi(x - int(c[1]))
				var dy := absi(y - int(c[2]))
				var jitter := 1 if h(x, y, seed + 5) > 0.6 else 0
				if dx + dy < r + jitter - 1:
					s[y * T + x] = 0
	return s


func _side_pixel(side: int, p: int, k: int) -> Vector2i:
	match side:
		0:
			return Vector2i(p, k)
		1:
			return Vector2i(T - 1 - k, p)
		2:
			return Vector2i(p, T - 1 - k)
	return Vector2i(k, p)


func _open(s: PackedByteArray, mask: int, x: int, y: int) -> bool:
	if y < 0:
		return not (mask & UP)
	if y >= T:
		return not (mask & DOWN)
	if x < 0:
		return not (mask & LEFT)
	if x >= T:
		return not (mask & RIGHT)
	return s[y * T + x] == 0


func _draw_grass(img: Image, s: PackedByteArray, mask: int, accent: Color, seed: int) -> void:
	if mask & UP:
		return
	for x in T:
		var top := -1
		for y in T:
			if s[y * T + x] == 1:
				top = y
				break
		if top < 0:
			continue
		var cap := 3 + int(h(x, 0, seed) * 2.5)
		for k in cap:
			var col := accent.lightened(0.15) if k == 0 else (accent.darkened(0.25) if k == cap - 1 else accent)
			if k > 0 and k < cap - 1 and h(x, k, seed + 3) > 0.8:
				col = accent.darkened(0.12)
			img.set_pixel(x, mini(top + k, T - 1), col)
		if top > 0 and h(x, 1, seed) > 0.5:
			s[(top - 1) * T + x] = 1
			img.set_pixel(x, top - 1, accent.lightened(0.1))
	for side in [LEFT, RIGHT]:
		if mask & side:
			continue
		for y in 7:
			for k in 2:
				var x := k if side == LEFT else T - 1 - k
				var inner := x
				while inner >= 0 and inner < T and s[y * T + inner] == 0:
					inner += 1 if side == LEFT else -1
				if inner >= 0 and inner < T and y < 7 - int(h(y, k, seed) * 3):
					img.set_pixel(inner, y, accent.darkened(0.1))


func _apply_edges(img: Image, s: PackedByteArray, mask: int) -> void:
	var out := img.duplicate() as Image
	var outline: float = style.outline
	var rim2: float = style.rim2
	var highlight: float = style.highlight
	for y in T:
		for x in T:
			if s[y * T + x] == 0:
				out.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var col := img.get_pixel(x, y)
			var edge := _open(s, mask, x - 1, y) or _open(s, mask, x + 1, y) or _open(s, mask, x, y - 1) or _open(s, mask, x, y + 1)
			if edge:
				out.set_pixel(x, y, col.darkened(outline))
				continue
			var near := _open(s, mask, x - 2, y) or _open(s, mask, x + 2, y) or _open(s, mask, x, y - 2) or _open(s, mask, x, y + 2)
			if rim2 > 0.0 and near:
				col = col.darkened(rim2)
			if _open(s, mask, x, y - 2) or (_open(s, mask, x - 1, y - 1) and not (mask & UP)):
				col = col.lightened(highlight)
			out.set_pixel(x, y, col)
	img.copy_from(out)


func _make_wall(mat: Dictionary, mask: int, v: int, mi: int) -> Image:
	var img := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	var dark := mat.duplicate()
	dark.base = (mat.base as Color).darkened(0.48)
	_texture(img, dark, v, mi + 50, mask)
	for y in T:
		for x in T:
			var col := img.get_pixel(x, y)
			var d := mini(mini(x, T - 1 - x), mini(y, T - 1 - y))
			var exposed := (not (mask & UP) and y < 2) or (not (mask & DOWN) and y > T - 3) \
				or (not (mask & LEFT) and x < 2) or (not (mask & RIGHT) and x > T - 3)
			if exposed:
				col = col.darkened(0.35 if d == 0 else 0.18)
			img.set_pixel(x, y, col)
	return img


func _make_platform(mat: Dictionary, mask: int, v: int) -> Image:
	var img := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var base: Color = mat.base
	for x in T:
		for y in 5:
			var col := base
			if y == 0:
				col = base.lightened(0.2)
			elif y == 4:
				col = base.darkened(0.4)
			elif h(x / 3, y, v + 40) > 0.75:
				col = base.darkened(0.12)
			img.set_pixel(x, y, col)
	if not (mask & LEFT):
		img.set_pixel(0, 0, Color.TRANSPARENT)
		img.set_pixel(0, 4, Color.TRANSPARENT)
		for y in range(1, 4):
			img.set_pixel(0, y, base.darkened(0.4))
		for y in range(5, 9):
			img.set_pixel(2, y, base.darkened(0.3))
	if not (mask & RIGHT):
		img.set_pixel(T - 1, 0, Color.TRANSPARENT)
		img.set_pixel(T - 1, 4, Color.TRANSPARENT)
		for y in range(1, 4):
			img.set_pixel(T - 1, y, base.darkened(0.4))
		for y in range(5, 9):
			img.set_pixel(T - 3, y, base.darkened(0.3))
	return img


func _make_rope(mat: Dictionary, mask: int) -> Image:
	var img := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var base: Color = mat.base
	var end := T if mask & DOWN else 12
	for y in end:
		img.set_pixel(6, y, base.darkened(0.45))
		img.set_pixel(9, y, base.darkened(0.45))
		img.set_pixel(7, y, base.darkened(0.2) if y % 3 == 0 else base)
		img.set_pixel(8, y, base.lightened(0.15) if y % 3 == 1 else base)
	if not (mask & DOWN):
		for y in range(12, 15):
			for x in range(5, 11):
				img.set_pixel(x, y, base.darkened(0.45) if x == 5 or x == 10 or y == 14 else base)
	return img


# --- player placeholder ----------------------------------------------------

## 32x64 frame. Hitbox (see player scene) is about 24x60, bottom-centered.
func _make_player() -> Image:
	var img := Image.create_empty(32, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var skin := Color("e0ac7e")
	var hair := Color("5a3a22")
	var shirt := Color("3f8f8a")
	var pants := Color("34405e")
	var boots := Color("4a3426")
	_rect(img, 9, 8, 14, 15, skin)       # head
	_rect(img, 8, 4, 16, 7, hair)        # hair top
	_rect(img, 8, 11, 3, 8, hair)        # hair side
	img.set_pixel(17, 15, Color("1d1d26"))
	img.set_pixel(18, 15, Color("1d1d26"))
	_rect(img, 13, 23, 6, 2, skin)       # neck
	_rect(img, 9, 25, 14, 18, shirt)     # torso
	_rect(img, 7, 26, 2, 13, shirt.darkened(0.15))
	_rect(img, 23, 26, 2, 13, shirt.darkened(0.15))
	_rect(img, 7, 39, 2, 3, skin)
	_rect(img, 23, 39, 2, 3, skin)
	_rect(img, 9, 41, 14, 2, Color("6b4a2a"))  # belt
	_rect(img, 10, 43, 5, 16, pants)
	_rect(img, 17, 43, 5, 16, pants)
	_rect(img, 9, 59, 6, 5, boots)
	_rect(img, 17, 59, 6, 5, boots)
	var out := img.duplicate() as Image
	for y in 64:
		for x in 32:
			if img.get_pixel(x, y).a == 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= 32 or ny >= 64 or img.get_pixel(nx, ny).a == 0.0:
					out.set_pixel(x, y, img.get_pixel(x, y).darkened(0.55))
					break
	return out


func _rect(img: Image, x: int, y: int, w: int, hh: int, col: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, hh), col)


# --- preview scene ---------------------------------------------------------

func _save_preview(blocks: Image, walls: Image, player: Image, out: String) -> void:
	var W := 60
	var H := 34
	var b := PackedInt32Array()
	var w := PackedInt32Array()
	b.resize(W * H)
	w.resize(W * H)
	b.fill(-1)
	w.fill(-1)
	var surf := PackedInt32Array()
	for x in W:
		var s := 13 + roundi(2.0 * sin(x * 0.21) + 1.2 * sin(x * 0.07 + 1.0))
		if x <= 14:
			s = 14
		surf.append(s)
	for x in W:
		for y in range(surf[x], H):
			var depth := y - surf[x]
			var m := 2
			if x < 24:
				m = 1 if depth == 0 else (0 if depth < 6 else 2)
			elif x < 42:
				m = 3 if depth < 7 else (7 if depth < 9 else 2)
			else:
				m = 4 if depth < 3 else (5 if depth < 6 else 2)
			b[y * W + x] = m
			if depth >= 2:
				w[y * W + x] = 0 if depth < 8 and x < 24 else (3 if x >= 24 and x < 42 and depth < 9 else 1)
	# cave
	for y in H:
		for x in W:
			var dx := (x - 31.0) / 10.0
			var dy := (y - 25.0) / 4.5
			if dx * dx + dy * dy + 0.25 * h(x, y, 3) < 1.0:
				b[y * W + x] = -1
				w[y * W + x] = 1
	# shaft + rope down into the cave
	for y in range(surf[34], 25):
		for x in range(33, 36):
			b[y * W + x] = -1
			if y > surf[34] + 1:
				w[y * W + x] = 3
		b[y * W + 34] = 15
	# mud and ores
	var blobs := [[15, 27, 6, 2.2], [8, 25, 9, 1.4], [12, 31, 9, 1.2], [20, 29, 10, 1.3], [46, 27, 11, 1.4], [53, 31, 12, 1.3], [27, 31, 13, 1.5], [38, 21, 7, 1.6]]
	for bl: Array in blobs:
		for y in H:
			for x in W:
				if Vector2(x, y).distance_to(Vector2(bl[0], bl[1])) < float(bl[3]) and b[y * W + x] >= 0 and b[y * W + x] != 15:
					b[y * W + x] = int(bl[2])
	# house
	for x in range(2, 14):
		b[7 * W + x] = 8
	for y in range(8, 14):
		b[y * W + 3] = 8
		if y < 10:
			b[y * W + 12] = 8
		for x in range(4, 12):
			w[y * W + x] = 2
	for x in range(5, 9):
		b[11 * W + x] = 14

	var img := Image.create_empty(W * T, H * T, false, Image.FORMAT_RGBA8)
	for y in H * T:
		img.fill_rect(Rect2i(0, y, W * T, 1), Color("8ec9ef").lerp(Color("d9eef7"), float(y) / (H * T)))
	for x in W:
		img.fill_rect(Rect2i(x * T, (surf[x] + 2) * T, T, (H - surf[x] - 2) * T), Color("1c1612"))
	_blit_layer(img, walls, w, W, H, false)
	_blit_layer(img, blocks, b, W, H, true)
	var px := 17
	img.blend_rect(player, Rect2i(0, 0, 32, 64), Vector2i(px * T - 8, surf[px] * T - 64))

	var big := img.duplicate() as Image
	big.resize(W * T * 2, H * T * 2, Image.INTERPOLATE_NEAREST)
	big.save_png(out.path_join("preview.png"))
	var crop := img.get_region(Rect2i(0, 5 * T, 30 * T, 17 * T))
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join("closeup.png"))


func _solid_kind(m: int) -> bool:
	return m >= 0 and m != 14 and m != 15


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
						present = _solid_kind(n)
				if present:
					mask |= int(d[2])
			var v := int(h(x, y, 77) * VARIANTS)
			img.blend_rect(atlas, Rect2i((mask * VARIANTS + v) * T, m * T, T, T), Vector2i(x * T, y * T))
