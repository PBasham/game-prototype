class_name SatchelLook
extends RefCounted
## The inventory drawn as a soft cloth satchel (Patrick's concept, "moonweave v4"): a
## rounded bag of blue cloth that darkens toward the middle, with no lines between the
## cells, only a faint change of hue from one cell to the next. Open, a gathered knot
## with a cord and a glowing crystal hangs off its right side. The pictures are made in
## code (placeholders) and cached per size; Patrick can replace them with real art later.

## Texels per UI unit (the HUD's units: a slot is 20). 2 matches the detailed icons.
const DETAIL := 2
## Rim and middle colors of the cloth, and how much each cell's hue shifts.
const RIM := Color("3a62c4")
const MIDDLE := Color("1a2f78")
const CELL_HUE := 0.014
const CELL_VALUE := 0.035
## How far past the bag (units) its soft shadow reaches.
const SHADOW := 3

static var _bags: Dictionary[String, ImageTexture] = {}
static var _knot: ImageTexture


## The bag picture for a pane of `size` units with `count` cells in rows of 10 from
## `origin` (`slot` units big, `step` apart). Cached by size and cell count.
static func bag(size: Vector2, origin: Vector2, count: int, slot: float, step: float) -> ImageTexture:
	var key := "%dx%d:%d" % [roundi(size.x), roundi(size.y), count]
	if _bags.has(key):
		return _bags[key]
	var w := roundi(size.x + SHADOW * 2) * DETAIL
	var h := roundi(size.y + SHADOW * 2) * DETAIL
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var rim_hsv := Vector3(RIM.h, RIM.s, RIM.v)
	var mid_hsv := Vector3(MIDDLE.h, MIDDLE.s, MIDDLE.v)
	var center := size * 0.5
	var radius := 9.0
	for py in h:
		for px in w:
			# Position in pane units.
			var u := Vector2((px + 0.5) / DETAIL - SHADOW, (py + 0.5) / DETAIL - SHADOW)
			var inside := _inside(u, size, radius)
			if inside < 0.0:
				# The soft shadow under the bag (a little lower than it).
				var s := _inside(u - Vector2(0, 1.5), size, radius)
				if s > -SHADOW:
					img.set_pixel(px, py, Color(0, 0, 0, 0.28 * (1.0 + s / SHADOW)))
				continue
			# Darker toward the middle of the whole bag.
			var d := Vector2((u.x - center.x) / center.x, (u.y - center.y) / center.y).length()
			var k := clampf(d / 1.15, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var hsv := mid_hsv.lerp(rim_hsv, k)
			# The cells: a faint hue change, soft at the edges (no lines).
			var col := floori((u.x - origin.x + (step - slot) * 0.5) / step)
			var row := floori((u.y - origin.y + (step - slot) * 0.5) / step)
			if col >= 0 and col < 10 and row >= 0 and row * 10 + col < count:
				var c := Rect2(origin + Vector2(col, row) * step, Vector2(slot, slot))
				var e := _soft_in(u, c, 2.5)
				var sgn := 1.0 if (col + row) % 2 == 0 else -1.0
				hsv.x += CELL_HUE * sgn * e
				hsv.z += CELL_VALUE * (0.6 if sgn > 0.0 else -0.4) * e
			# Cloth weave: a faint crosshatch and grain.
			var weave := 0.012 * (1.0 if (px + py) % 4 < 2 else -1.0) + 0.018 * (_hash(px, py) - 0.5)
			hsv.z += weave
			# Light on the upper left rim, shade on the lower right.
			if inside < 2.0:
				var t := 1.0 - inside / 2.0
				var lit := (center.x - u.x) / center.x * 0.5 + (center.y - u.y) / center.y * 0.5
				hsv.z += 0.1 * t * lit
				hsv.y -= 0.08 * t * maxf(lit, 0.0)
			var a := clampf(inside * DETAIL, 0.0, 1.0)
			img.set_pixel(px, py, Color.from_hsv(fposmod(hsv.x, 1.0), clampf(hsv.y, 0.0, 1.0), clampf(hsv.z, 0.0, 1.0), a))
	var tex := ImageTexture.create_from_image(img)
	_bags[key] = tex
	return tex


## Draws the bag behind a pane's contents.
static func draw_bag(ci: CanvasItem, size: Vector2, origin: Vector2, count: int, slot: float, step: float) -> void:
	var tex := bag(size, origin, count, slot, step)
	ci.draw_texture_rect(tex, Rect2(-Vector2(SHADOW, SHADOW), size + Vector2(SHADOW * 2, SHADOW * 2)), false)


## A cell's highlight: a soft rounded glow (selected: brighter, with a pale rim).
static func draw_cell_glow(ci: CanvasItem, r: Rect2, selected: bool) -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(5)
	box.bg_color = Color(0.62, 0.78, 1.0, 0.22 if selected else 0.12)
	if selected:
		box.set_border_width_all(1)
		box.border_color = Color(0.75, 0.88, 1.0, 0.75)
		box.shadow_color = Color(0.5, 0.7, 1.0, 0.35)
		box.shadow_size = 3
	box.anti_aliasing = true
	box.draw(ci.get_canvas_item(), r.grow(1.0))


## The trash cell: a darker, sunken rounded spot; with a little bin drawn in it while
## it's empty.
static func draw_trash(ci: CanvasItem, r: Rect2, hover: bool, empty: bool) -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(5)
	box.bg_color = Color(0.03, 0.05, 0.16, 0.55 if not hover else 0.4)
	box.set_border_width_all(1)
	box.border_color = Color(0.55, 0.7, 1.0, 0.18 if not hover else 0.4)
	box.anti_aliasing = true
	box.draw(ci.get_canvas_item(), r)
	if not empty:
		return
	var c := Color(0.62, 0.72, 0.95, 0.55)
	var m := r.get_center()
	ci.draw_line(m + Vector2(-5, -5), m + Vector2(5, -5), c, 1.0)  # lid
	ci.draw_line(m + Vector2(-1.5, -6.5), m + Vector2(1.5, -6.5), c, 1.0)  # handle
	ci.draw_polyline(PackedVector2Array([m + Vector2(-4, -3.5), m + Vector2(-3, 5.5), m + Vector2(3, 5.5),
		m + Vector2(4, -3.5)]), c, 1.0)
	for x in [-1.5, 1.5]:
		ci.draw_line(m + Vector2(x, -2), m + Vector2(x, 4), c, 1.0)


## The gathered knot, cord and crystal that hang off the bag's right side (open only).
## Drawn with its top left at `at` (units); 30 x 70 units.
static func draw_knot(ci: CanvasItem, at: Vector2) -> void:
	if _knot == null:
		_knot = ImageTexture.create_from_image(_knot_image())
	ci.draw_texture_rect(_knot, Rect2(at, Vector2(30, 70)), false)
	# The crystal glows a little (pulsing).
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003)
	ci.draw_circle(at + Vector2(19, 58), 5.0 + pulse, Color(0.7, 0.45, 1.0, 0.12 + 0.08 * pulse))


static func _knot_image() -> Image:
	var w := 30 * DETAIL
	var h := 70 * DETAIL
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cloth_lit := Color("4c74d4")
	var cloth := Color("2e4ea8")
	var cloth_dark := Color("1c3274")
	# A gathered fan of cloth where the bag is tied, pointing up and out.
	for py in 26 * DETAIL:
		for px in w:
			var u := Vector2(float(px) / DETAIL, float(py) / DETAIL)
			var o := Vector2(4, 20)  # where the folds meet (the tie)
			var v := u - o
			var ang := atan2(-v.y, v.x)
			var dist := v.length()
			if ang < 0.15 or ang > 1.45 or dist > 18.0 + 3.0 * sin(ang * 9.0):
				continue
			var fold := sin(ang * 9.0)
			var c := cloth.lerp(cloth_lit, clampf(fold, 0.0, 1.0)).lerp(cloth_dark, clampf(-fold, 0.0, 1.0))
			img.set_pixel(px, py, c)
	# The tie: a few pale wraps of cord.
	for i in 3:
		var y := (17 + i * 2) * DETAIL
		for px in range(1 * DETAIL, 8 * DETAIL):
			for t in DETAIL:
				img.set_pixel(px, y + t, Color("d8dcf0") if (px / DETAIL + i) % 3 != 0 else Color("a0a8c8"))
	# The cord curving down to the crystal.
	for s in 200:
		var t := s / 199.0
		var p := Vector2(7, 22).lerp(Vector2(19, 52), t) + Vector2(sin(t * PI) * 6.0, 0)
		var q := Vector2i(roundi(p.x * DETAIL), roundi(p.y * DETAIL))
		if q.x >= 0 and q.x < w - 1 and q.y < h:
			img.set_pixel(q.x, q.y, Color("c8cce4"))
			img.set_pixel(q.x + 1, q.y, Color("8890b4"))
	# The crystal: a violet diamond with a lit face, and a little tassel under it.
	var cc := Vector2(19, 58) * DETAIL
	for py in range(int(cc.y) - 7 * DETAIL, int(cc.y) + 7 * DETAIL):
		for px in range(int(cc.x) - 5 * DETAIL, int(cc.x) + 5 * DETAIL):
			var d := absf(px - cc.x) / (4.0 * DETAIL) + absf(py - cc.y) / (6.0 * DETAIL)
			if d <= 1.0:
				var lit := px < cc.x and py < cc.y
				var c := Color("b88cff") if lit else Color("7a48d8")
				if d < 0.35:
					c = Color("e6d4ff")
				img.set_pixel(px, py, c)
	for i in 5:
		for py in range(int(cc.y) + 6 * DETAIL, mini(h, int(cc.y) + 11 * DETAIL)):
			img.set_pixel(int(cc.x) - 2 * DETAIL + i * DETAIL, py, Color("c0b4e8"))
	return img


## How far inside the bag's wobbly rounded outline a point is (units; < 0 outside).
static func _inside(u: Vector2, size: Vector2, radius: float) -> float:
	# The edge wobbles a little, like soft cloth.
	var wob := 0.7 * sin(u.x * 0.21 + u.y * 0.05) + 0.5 * sin(u.y * 0.33 + 1.7) + 0.4 * sin((u.x + u.y) * 0.13)
	var q := Vector2(absf(u.x - size.x * 0.5), absf(u.y - size.y * 0.5)) - (size * 0.5 - Vector2(radius, radius))
	var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
	return -outside + wob - 1.0


## 1 well inside a rect, fading to 0 over `soft` units at its edges.
static func _soft_in(u: Vector2, r: Rect2, soft: float) -> float:
	var dx := minf(u.x - r.position.x, r.end.x - u.x)
	var dy := minf(u.y - r.position.y, r.end.y - u.y)
	var m := minf(dx, dy)
	if m < -soft * 0.5:
		return 0.0
	return clampf((m + soft * 0.5) / soft, 0.0, 1.0)


static func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n & 0xffff) / 65535.0
