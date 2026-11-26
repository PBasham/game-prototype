class_name PhantomTool
extends Node2D
## The gathering spells' phantom pickaxe or axe (ItemUser drives it) and their glowing
## target box. Every swing the tool comes into being, strikes the middle of the target
## fast, lights things up and fades away; the next swing conjures it again. The hit
## lands at `impact` (SpellData.phantom_impact) of the swing.
##
## Styles (SpellData.phantom_style):
##   ARC    raised beside the target, a fast arc down with a glowing crescent streak
##   ECHO   the same arc, leaving fading copies of itself behind (afterimages)
##   COMET  appears high above, spins once as it drops onto the target, a comet tail
##
## Drawn above the lighting (LightMap is z 50): the tool, its streak and its glow are
## additive light, so they read as light underground too.

enum Style { ARC, ECHO, COMET }

## Where the grip and the striking point sit in the art (fractions of its size; set
## from SpellData.phantom_grip and phantom_tip).
var grip_at := Vector2(0.08, 0.92)
var tip_at := Vector2(0.88, 0.48)
## How big the tool is drawn (1 = the art's size, 2 tiles).
@export var size_mult := 1.5
## Turn (radians) from raised to the strike (ARC, ECHO).
@export var wind_up := 2.2
## Parts of the swing (0 to 1): fading in until `appear`, raised until `strike_from`,
## then the fast strike lands at the spell's impact, then it fades out.
@export var appear := 0.22
@export var strike_from := 0.55
## COMET: how high above the target it appears (tiles).
@export var comet_height := 4.0
## How bright the tool, its glow and its streak are.
@export var tool_alpha := 0.95
@export var glow_alpha := 0.55
@export var streak_alpha := 0.7
## Target box: fill and edge brightness, and how fast it breathes.
@export var box_fill_alpha := 0.12
@export var box_edge_alpha := 0.85
@export var box_pulse_speed := 4.0

const BOX_COLOR := Color(0.45, 0.8, 1.0)
const BAD_COLOR := Color(1.0, 0.35, 0.3)

var style := Style.ARC
var texture: Texture2D
var tint := Color(0.7, 0.9, 1.0)
## The point it strikes (the middle of the target), and which side you're on (+1:
## you're left of it).
var target := Vector2.ZERO
var side := 1.0
## 0 to 1 through the current swing; `impact` is where it lands.
var swing := 0.0
var impact := 0.8
var swinging := false
## The target box (px), shown while you hold a gathering spell; red when it can't work.
var box := Rect2()
var box_shown := false
var box_ok := true
## The blocks it will mine (tiles): each one lights up and the group gets one outline
## around it, like Starbound's matter manipulator. Empty: just the box (trees).
var tiles: Array[Vector2i] = []

## While aiming it's a real light (the light map's "light_sources"), so the blocks
## under the cursor show up in the dark: radius in tiles, and its color.
@export var light_radius := 3.0
@export var light_color := Color(0.55, 0.8, 1.0)
var radius := 0.0
var color := Color.WHITE
var _lit_at := Vector2i(-99999, -99999)

static var _glow_tex: GradientTexture2D
## The tool itself draws on this child with normal blending (solid, so it doesn't wash
## out over the bright sky); this node draws the light: box glow, streaks, halos.
var _tools: Node2D


func _ready() -> void:
	z_as_relative = false
	z_index = 56
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # light, not paint
	material = mat
	_tools = Node2D.new()
	_tools.name = "Tool"
	add_child(_tools)
	_tools.draw.connect(_draw_tools)
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64


func redraw() -> void:
	queue_redraw()
	_tools.queue_redraw()


## The light layer (additive).
func _draw() -> void:
	if box_shown:
		_draw_box()
	if swinging and texture:
		match style:
			Style.COMET:
				_draw_comet(false)
			_:
				_draw_arc_swing(style == Style.ECHO, false)


## The tool layer (solid).
func _draw_tools() -> void:
	if box_shown and not box_ok:
		_tools.draw_rect(box.grow(0.5), Color(BAD_COLOR, box_edge_alpha), false, 1.0)
	if swinging and texture:
		match style:
			Style.COMET:
				_draw_comet(true)
			_:
				_draw_arc_swing(style == Style.ECHO, true)


# --- the target box -----------------------------------------------------------------

## The light it casts while you aim (World.dynamic_lights reads these).
func light_point() -> Vector2:
	return box.get_center() / World.TILE


func light_tile() -> Vector2i:
	return Vector2i((box.get_center() / World.TILE).floor())


## Called by ItemUser after it sets the box: joins or leaves the light sources and
## relights when the aim moves (every quarter tile).
func update_light(world: World) -> void:
	var on := box_shown and box_ok and visible
	radius = light_radius
	color = light_color.lerp(tint, 0.35)
	if on != is_in_group(&"light_sources"):
		if on:
			add_to_group(&"light_sources")
		else:
			remove_from_group(&"light_sources")
		_lit_at = Vector2i(-99999, -99999)
		world.lights.mark_dirty()
	if on:
		var t := Vector2i((light_point() * 4.0).floor())
		if t != _lit_at:
			_lit_at = t
			world.lights.mark_dirty()


func _draw_box() -> void:
	var c := BOX_COLOR
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * box_pulse_speed)
	if not box_ok:
		return  # drawn solid on the tool layer (additive red turns yellow on the sky)
	if tiles.is_empty():
		draw_rect(box, Color(c, box_fill_alpha * pulse))
		for i in 3:  # a soft glow outside the edge
			draw_rect(box.grow(1.0 + i), Color(c, box_edge_alpha * 0.18 / (i + 1) * pulse), false, 1.0)
		draw_rect(box.grow(0.5), Color(c, box_edge_alpha * pulse), false, 1.0)
		return
	# Each block it will mine lights up; one outline (with a soft glow) traces the group.
	var t := World.TILE
	var in_set := {}
	for v in tiles:
		in_set[v] = true
	for v in tiles:
		draw_rect(Rect2(Vector2(v * t), Vector2(t, t)), Color(c, box_fill_alpha * 1.6 * pulse))
	var edges: Array[Array] = []
	for v in tiles:
		var o := Vector2(v * t)
		if not in_set.has(v + Vector2i.UP):
			edges.append([o, o + Vector2(t, 0), Vector2(0, -1)])
		if not in_set.has(v + Vector2i.DOWN):
			edges.append([o + Vector2(0, t), o + Vector2(t, t), Vector2(0, 1)])
		if not in_set.has(v + Vector2i.LEFT):
			edges.append([o, o + Vector2(0, t), Vector2(-1, 0)])
		if not in_set.has(v + Vector2i.RIGHT):
			edges.append([o + Vector2(t, 0), o + Vector2(t, t), Vector2(1, 0)])
	for e in edges:
		var out: Vector2 = e[2]
		for i in 3:  # glow spilling outward
			draw_line(e[0] + out * (1.0 + i), e[1] + out * (1.0 + i), Color(c, box_edge_alpha * 0.18 / (i + 1) * pulse), 1.0)
		draw_line(e[0] + out * 0.5, e[1] + out * 0.5, Color(c, box_edge_alpha * pulse), 1.0)


# --- the swing ----------------------------------------------------------------------

## Size of the tool in px, and the tip relative to the grip in the art's frame.
func _size() -> Vector2:
	return Vector2(texture.get_size()) / 2.0 * size_mult  # detailed art: 2 art px per world px


func _tip_offset() -> Vector2:
	return (tip_at - grip_at) * _size()


## How visible the tool is: fades in, holds, fades out after the hit.
func _life() -> float:
	if swing < appear:
		return swing / appear
	if swing > impact:
		return clampf(1.0 - (swing - impact) / maxf(1.0 - impact, 0.01), 0.0, 1.0)
	return 1.0


## 0 (raised) to 1 (striking) through the swing: still while it appears, a short
## wind up, then a fast strike that lands exactly at `impact`.
func _strike(t: float) -> float:
	if t <= strike_from:
		return -0.08 * clampf((t - appear) / maxf(strike_from - appear, 0.01), 0.0, 1.0)  # draws back a hair
	if t >= impact:
		return 1.0 + 0.06 * sin(clampf((t - impact) / 0.1, 0.0, 1.0) * PI)  # a little bite past the hit
	var k := (t - strike_from) / maxf(impact - strike_from, 0.01)
	return k * k * k  # slow, then very fast


## The tool's rotation at strike progress `k` (ARC, ECHO), mirrored for your side: at
## k = 1 the tip points from the grip straight at the target.
func _angle(k: float) -> float:
	var tip := _tip_offset()
	var strike_dir := Vector2(side * 0.55, 1.0).normalized()  # down and away from you
	var strike := strike_dir.angle() - Vector2(tip.x * side, tip.y).angle()
	return strike - side * wind_up * (1.0 - k)


## Where the grip sits so the tip lands on the target at the strike.
func _grip() -> Vector2:
	var tip := _tip_offset()
	var mirrored := Vector2(tip.x * side, tip.y)
	return target - mirrored.rotated(_angle(1.0))


func _tip_at(grip: Vector2, angle: float) -> Vector2:
	var tip := _tip_offset()
	return grip + Vector2(tip.x * side, tip.y).rotated(angle)


func _draw_tool(grip: Vector2, angle: float, alpha: float, scale_k: float = 1.0) -> void:
	var size := _size() * scale_k
	_tools.draw_set_transform(grip, angle, Vector2(side, 1.0))
	var r := Rect2(-grip_at * size, size)
	_tools.draw_texture_rect(texture, r, false, Color(tint.lightened(0.35), alpha))
	_tools.draw_set_transform(Vector2.ZERO)


## The tool's light outline: the art again, bigger and faint, on the light layer.
func _draw_tool_light(grip: Vector2, angle: float, alpha: float, scale_k: float = 1.0) -> void:
	var size := _size() * scale_k
	draw_set_transform(grip, angle, Vector2(side, 1.0))
	var r := Rect2(-grip_at * size, size)
	draw_texture_rect(texture, r.grow(1.5), false, Color(tint, alpha * 0.45))
	draw_set_transform(Vector2.ZERO)


func _glow(at: Vector2, radius: float, alpha: float) -> void:
	draw_texture_rect(_glow_tex, Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(tint, alpha))


func _draw_arc_swing(echo: bool, tools: bool) -> void:
	var life := _life()
	var k := _strike(swing)
	var grip := _grip()
	var angle := _angle(clampf(k, -0.2, 1.1))
	var tip := _tip_at(grip, angle)
	# Appearing: it grows in from a spark.
	var grow := lerpf(0.6, 1.0, clampf(swing / appear, 0.0, 1.0))
	var striking := swing > strike_from and swing < impact + 0.12
	if tools:
		if striking and echo:
			# Afterimages: where it was a moment ago, fainter the older they are.
			for i in range(4, 0, -1):
				var past := _strike(swing - i * 0.035)
				if past > 0.0:
					_draw_tool(grip, _angle(past), tool_alpha * life * (0.5 - i * 0.1), 1.0)
		_draw_tool(grip, angle, tool_alpha * life, grow)
		return
	if striking:
		var k0 := 0.0
		if echo:
			for i in range(4, 0, -1):
				var past := _strike(swing - i * 0.035)
				if past > 0.0:
					_draw_tool_light(grip, _angle(past), life * (0.5 - i * 0.1))
		else:
			# A glowing crescent along the path the tip swept.
			var pts := PackedVector2Array()
			var steps := 14
			for i in steps + 1:
				var kk := lerpf(k0, minf(k, 1.0), float(i) / steps)
				pts.append(_tip_at(grip, _angle(kk)))
			for w: Array in [[5.0, 0.18], [3.0, 0.35], [1.2, 0.9]]:
				var col := PackedColorArray()
				for i in pts.size():
					var along := float(i) / maxf(pts.size() - 1, 1)
					col.append(Color(tint, streak_alpha * life * w[1] * along * along))
				draw_polyline_colors(pts, col, w[0])
	_draw_tool_light(grip, angle, life, grow)
	# Its own light: around the head, flaring on the hit.
	var flare := 0.0
	if swing >= impact:
		flare = 1.0 - clampf((swing - impact) / 0.15, 0.0, 1.0)
	_glow(tip, 10.0 + 8.0 * flare, glow_alpha * life * (0.6 + flare))
	if flare > 0.0:
		_glow(target, 14.0 * flare + 6.0, glow_alpha * flare)
		for i in 6:  # sparks off the block
			var a := TAU * i / 6.0 + target.x
			draw_line(target, target + Vector2.from_angle(a) * (4.0 + 6.0 * (1.0 - flare)), Color(tint, flare * 0.8), 1.0)


func _draw_comet(tools: bool) -> void:
	var life := _life()
	var drop := 0.0  # 0 high above, 1 on the target
	if swing > strike_from:
		var k := clampf((swing - strike_from) / maxf(impact - strike_from, 0.01), 0.0, 1.0)
		drop = k * k
	var top := target + Vector2(-side * 6.0, -comet_height * 8.0)
	var tip_offset := _tip_offset()
	# One full turn on the way down, ending pointed at the target.
	var final_angle := Vector2(0.0, 1.0).angle() - Vector2(tip_offset.x * side, tip_offset.y).angle()
	var angle := final_angle - side * TAU * (1.0 - drop)
	var tip_pos := top.lerp(target, drop)
	var grip := tip_pos - Vector2(tip_offset.x * side, tip_offset.y).rotated(angle)
	var grow := lerpf(0.4, 1.0, clampf(swing / appear, 0.0, 1.0))
	if tools:
		_draw_tool(grip, angle, tool_alpha * life, grow)
		return
	if swing > strike_from and swing < impact + 0.05:
		# The tail: from where it started to where it is now.
		var pts := PackedVector2Array([top, tip_pos])
		for w: Array in [[6.0, 0.15], [3.0, 0.3], [1.2, 0.8]]:
			draw_polyline_colors(pts, PackedColorArray([Color(tint, 0.0), Color(tint, streak_alpha * life * w[1])]), w[0])
	_draw_tool_light(grip, angle, life, grow)
	var flare := 0.0
	if swing >= impact:
		flare = 1.0 - clampf((swing - impact) / 0.18, 0.0, 1.0)
	_glow(tip_pos, 9.0 + 10.0 * flare, glow_alpha * life * (0.6 + flare))
	if flare > 0.0:
		_glow(target, 18.0 * flare + 6.0, glow_alpha * flare)
		for i in 8:
			var a := -PI * float(i) / 7.0
			draw_line(target, target + Vector2.from_angle(a) * (5.0 + 8.0 * (1.0 - flare)), Color(tint, flare * 0.8), 1.0)
