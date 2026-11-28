class_name Backdrop
extends CanvasLayer
## Sky, sun, clouds, mountains and two layers of hills behind the world.
## Screen-space layers that scroll slower than the camera (parallax) and repeat
## horizontally. Fades toward dark as the camera goes underground. Follows the world
## clock: the sky color changes through the day, the sun crosses the sky by day and
## the moon by night, and the hills darken at night.

const DIR := "res://assets/backdrop"
const LAYER_WIDTH := 1280

## [texture, horizontal parallax factor, vertical factor, screen y at the surface]
const LAYERS := [
	["clouds.png", 0.04, 0.02, 10.0],
	["mountains.png", 0.08, 0.05, 120.0],
	["hills_0.png", 0.16, 0.1, 165.0],
	["hills_1.png", 0.3, 0.18, 195.0],
]

## Phase 90: each biome has its own backdrop, faded in as the camera enters it:
## [texture, horizontal parallax, vertical parallax, screen y at the surface].
## Dark Forest: a misty ridge, tall trees in the fog, huge near trunks (a murky veil
## darkens the sky behind them).
const DARK_LAYERS := [["df_far.png", 0.1, 0.06, 70.0], ["df_mid.png", 0.2, 0.12, 105.0], ["df_near.png", 0.36, 0.2, -50.0]]
## The ocean: far islands and the horizon, its horizon row (OCEAN_HORIZON) sitting on
## the sea's surface on screen.
const OCEAN_LAYERS := [["ocean_far.png", 0.05, 0.0, 0.0]]
const OCEAN_HORIZON := 112.0
## Under the sea, below the sea's surface on screen: light shafts from the surface, then
## far rock spires and near rocks and kelp standing on the bottom of the screen, rising
## into view as you go deeper ([texture, horizontal parallax, px below the bottom at the
## surface, px below it UW_DEEP deep]).
const UNDERWATER_LAYERS := [["uw_rays.png", 0.04, 0.0, 0.0], ["uw_far.png", 0.12, 110.0, 10.0], ["uw_near.png", 0.26, 150.0, 20.0]]
const UW_DEEP := 500.0
## Underwater colors: top of the screen and bottom.
@export var underwater_top := Color("26739a")
@export var underwater_low := Color("081a2a")
## The veil's color over the sky and hills in the Dark Forest, and how fast the
## backdrop turns dark or light again (share per second).
@export var dark_veil := Color("16282a")
@export var dark_fade_speed := 1.5

## How dark-forest the view is (0 to 1), set by the world from where the camera is.
var dark_target := 0.0
var _dark := 0.0
var _veil: ColorRect
var _dark_rects: Array[TextureRect] = []
## Phase 90: how much the ocean's backdrop shows, and the underwater one (0 to 1).
var ocean_target := 0.0
var underwater_target := 0.0
## The sea's surface in world pixels (INF: no ocean).
var sea_y := INF
var _ocean := 0.0
var _under := 0.0
var _ocean_rects: Array[TextureRect] = []
var _ocean_ground: ColorRect
var _dark_ground: ColorRect
var _uw_root: Control
var _uw_gradient: Gradient
var _uw_rects: Array[TextureRect] = []

## Sky colors (top, horizon) for day, dusk and dawn, and night.
@export var day_sky: PackedColorArray = PackedColorArray([Color("3fa9e8"), Color("aee4f6")])
@export var twilight_sky: PackedColorArray = PackedColorArray([Color("4a5aa8"), Color("f0a070")])
@export var night_sky: PackedColorArray = PackedColorArray([Color("070b1c"), Color("1c2a50")])

## Camera y (pixels) where the backdrop sits at its normal height.
var surface_y := 0.0
## The world's clock (null: always noon).
var clock: WorldClock
var _gradient: Gradient
var _sun: TextureRect
var _moon: TextureRect
var _stars: TextureRect
var _layers_tint := Color.WHITE

var _root: Control
var _rects: Array[TextureRect] = []
var _ground: ColorRect


func _ready() -> void:
	layer = -20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var gradient := Gradient.new()
	gradient.set_color(0, day_sky[0])
	gradient.set_color(1, day_sky[1])
	_gradient = gradient
	var sky := GradientTexture2D.new()
	sky.gradient = gradient
	sky.fill_from = Vector2(0, 0)
	sky.fill_to = Vector2(0, 0.6)
	var sky_rect := TextureRect.new()
	sky_rect.texture = sky
	sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(sky_rect)

	_stars = TextureRect.new()
	_stars.texture = load(DIR + "/stars.png") as Texture2D
	_stars.stretch_mode = TextureRect.STRETCH_TILE
	_stars.size = Vector2(LAYER_WIDTH, 260)
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stars)
	var sun := TextureRect.new()
	sun.texture = load(DIR + "/sun.png") as Texture2D
	sun.position = Vector2(150, -40)
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The rays reach the picture's edges: fade them out toward every edge so the glow
	# never ends in a straight line (sunrise near the screen edge showed it).
	var fade := ShaderMaterial.new()
	fade.shader = Shader.new()
	fade.shader.code = """shader_type canvas_item;
void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	float k = smoothstep(0.0, 0.22, d.x) * smoothstep(0.0, 0.22, d.y);
	COLOR = texture(TEXTURE, UV) * COLOR;  // keeps the node's modulate (rain hides the sun)
	COLOR.a *= k;
}"""
	sun.material = fade
	_root.add_child(sun)
	_sun = sun
	_moon = TextureRect.new()
	_moon.texture = load(DIR + "/moon.png") as Texture2D
	_moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_moon)

	for spec: Array in LAYERS:
		var rect := TextureRect.new()
		rect.texture = load(DIR.path_join(spec[0])) as Texture2D
		rect.stretch_mode = TextureRect.STRETCH_TILE
		rect.size = Vector2(LAYER_WIDTH * 2, rect.texture.get_height())
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(rect)
		_rects.append(rect)
	_ocean_rects = _make_layers(OCEAN_LAYERS)
	_ocean_ground = _ground_for(_ocean_rects.back())
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = dark_veil
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_veil)
	_dark_rects = _make_layers(DARK_LAYERS)
	_dark_ground = _ground_for(_dark_rects.back())
	# Under the sea: its own screen, over the rest.
	_uw_root = Control.new()
	_uw_root.clip_contents = true  # only below the sea's surface on screen
	_uw_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uw_gradient = Gradient.new()
	_uw_gradient.set_color(0, underwater_top)
	_uw_gradient.set_color(1, underwater_low)
	var uw_tex := GradientTexture2D.new()
	uw_tex.gradient = _uw_gradient
	uw_tex.fill_from = Vector2(0, 0)
	uw_tex.fill_to = Vector2(0, 1)
	var uw_bg := TextureRect.new()
	uw_bg.texture = uw_tex
	uw_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	uw_bg.stretch_mode = TextureRect.STRETCH_SCALE
	uw_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uw_root.add_child(uw_bg)
	# Solid ground below the nearest hills, so holes never show sky underneath.
	var front := (_rects.back().texture as Texture2D).get_image()
	_ground = ColorRect.new()
	_ground.color = front.get_pixel(0, front.get_height() - 1)
	_ground.size = Vector2(LAYER_WIDTH * 2, 2000)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ground)
	# The ocean's and Dark Forest's layers draw over the forest's (and its ground).
	for r in _ocean_rects:
		_root.move_child(r, -1)
	_root.move_child(_ocean_ground, -1)
	_root.move_child(_veil, -1)
	for r in _dark_rects:
		_root.move_child(r, -1)
	_root.move_child(_dark_ground, -1)
	add_child(_uw_root)
	for spec: Array in UNDERWATER_LAYERS:
		var rect := _layer_rect(spec[0])
		_uw_root.add_child(rect)
		_uw_rects.append(rect)
	_follow(Vector2.ZERO)


func _layer_rect(file: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(DIR.path_join(file)) as Texture2D
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.size = Vector2(LAYER_WIDTH * 2, rect.texture.get_height())
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _make_layers(specs: Array) -> Array[TextureRect]:
	var out: Array[TextureRect] = []
	for spec: Array in specs:
		var rect := _layer_rect(spec[0])
		_root.add_child(rect)
		out.append(rect)
	return out


## Solid fill under a set's nearest layer, in its bottom row's color.
func _ground_for(last: TextureRect) -> ColorRect:
	var img := (last.texture as Texture2D).get_image()
	var g := ColorRect.new()
	g.color = img.get_pixel(0, img.get_height() - 1)
	g.size = Vector2(LAYER_WIDTH * 2, 2000)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(g)
	return g


func _process(delta: float) -> void:
	_dark = move_toward(_dark, dark_target, dark_fade_speed * delta)
	_ocean = move_toward(_ocean, ocean_target, dark_fade_speed * delta)
	_under = move_toward(_under, underwater_target, 3.0 * delta)
	_update_sky()
	var cam := get_viewport().get_camera_2d()
	if cam:
		_follow(cam.get_screen_center_position())


func _follow(cam: Vector2) -> void:
	var dy := cam.y - surface_y
	# The forest's hills give way to the ocean's or the Dark Forest's (clouds stay).
	var other := maxf(_dark, _ocean)
	for i in _rects.size():
		var spec: Array = LAYERS[i]
		var rect := _rects[i]
		rect.modulate = Color(_layers_tint, 1.0 if i == 0 else 1.0 - other)
		rect.visible = i == 0 or other < 1.0
		rect.position.x = -fposmod(cam.x * float(spec[1]), LAYER_WIDTH)
		rect.position.y = float(spec[3]) - dy * float(spec[2])
	var last := _rects.back() as TextureRect
	_ground.position = Vector2(0, last.position.y + last.size.y - 1)
	_ground.modulate = Color(_layers_tint, 1.0 - other)
	var ocean := _ocean * (1.0 - _dark)
	_place_set(_ocean_rects, OCEAN_LAYERS, _ocean_ground, cam, dy, ocean)
	# The sea's surface on screen: the horizon sits on it, the underwater view under it.
	var view := get_viewport().get_visible_rect().size
	var cam2d := get_viewport().get_camera_2d()
	var zoom := cam2d.zoom.y if cam2d else 1.0
	var line := view.y * 0.5 + (sea_y - cam.y) * zoom if sea_y != INF else INF
	if line != INF:
		for r in _ocean_rects:
			r.position.y = line - OCEAN_HORIZON - 1.0
		_ocean_ground.position.y = _ocean_rects.back().position.y + _ocean_rects.back().size.y - 1
	# Dark Forest: the veil, then its own layers.
	_veil.visible = _dark > 0.0
	_veil.color = Color(dark_veil * _layers_tint, 0.75 * _dark)
	_place_set(_dark_rects, DARK_LAYERS, _dark_ground, cam, dy, _dark)
	# Darken as the camera goes underground.
	var under := clampf((dy - 120.0) / 360.0, 0.0, 1.0)
	_root.modulate = Color.WHITE.lerp(Color(0.08, 0.07, 0.07), under)
	# Under the sea: fades in, darker deeper down.
	var top := clampf(line, 0.0, view.y) if line != INF else view.y
	_uw_root.visible = _under > 0.0 and top < view.y
	_uw_root.position = Vector2(0, top)
	_uw_root.size = Vector2(view.x, view.y - top)
	var depth := maxf(cam.y - sea_y, 0.0) * zoom if sea_y != INF else 0.0
	var dim := clampf(depth / 900.0, 0.0, 1.0)
	_uw_root.modulate = Color(_layers_tint.lerp(Color.WHITE, 0.3) * Color.WHITE.lerp(Color(0.3, 0.36, 0.46), dim), _under)
	var k := clampf(depth / UW_DEEP, 0.0, 1.0)
	for i in _uw_rects.size():
		var spec: Array = UNDERWATER_LAYERS[i]
		var rect := _uw_rects[i]
		rect.position.x = -fposmod(cam.x * float(spec[1]), LAYER_WIDTH)
		if i == 0:
			rect.position.y = line - top if line != INF else 0.0  # shafts hang from the surface
			rect.modulate.a = 1.0 - k
		else:
			rect.position.y = _uw_root.size.y - rect.size.y + lerpf(float(spec[2]), float(spec[3]), k)


func _place_set(rects: Array[TextureRect], specs: Array, ground: ColorRect, cam: Vector2, dy: float, weight: float) -> void:
	for i in rects.size():
		var spec: Array = specs[i]
		var rect := rects[i]
		rect.visible = weight > 0.0
		rect.modulate = Color(_layers_tint, weight)
		rect.position.x = -fposmod(cam.x * float(spec[1]), LAYER_WIDTH)
		rect.position.y = float(spec[3]) - dy * float(spec[2])
	var last := rects.back() as TextureRect
	ground.visible = weight > 0.0
	ground.modulate = Color(_layers_tint, weight)
	ground.position = Vector2(0, last.position.y + last.size.y - 1)


## Sky colors, sun and moon from the clock.
func _update_sky() -> void:
	if clock == null or _gradient == null:
		_moon.visible = false
		_stars.modulate.a = 0.0
		return
	var d := clock.daylight()
	var tw := clock.twilight()
	for i in 2:
		var c := night_sky[i].lerp(day_sky[i], d)
		c = c.lerp(twilight_sky[i], tw * 0.75)
		# Rain: the sky goes grey (WorldClock.overcast).
		var grey := Color(c.get_luminance(), c.get_luminance(), c.get_luminance()) * Color(0.8, 0.82, 0.88)
		_gradient.set_color(i, c.lerp(grey, clampf(clock.overcast * 2.4, 0.0, 0.85)))
	var view := get_viewport().get_visible_rect().size
	# The sun crosses from sunrise to sunset, the moon through the night: an arc from
	# the left edge, up to the top, down to the right edge.
	var day_len := clock.sunset_hour - clock.sunrise_hour
	var h := clock.hour()
	var k_sun := (h - clock.sunrise_hour) / day_len
	var night_h := fposmod(h - clock.sunset_hour, 24.0)
	var k_moon := night_h / (24.0 - day_len)
	_place_on_arc(_sun, k_sun, view)
	_place_on_arc(_moon, k_moon, view)
	_sun.visible = k_sun > -0.1 and k_sun < 1.1
	_sun.modulate.a = clampf(1.0 - clock.overcast * 3.0, 0.0, 1.0)  # hidden by rain clouds
	_moon.visible = k_moon > -0.1 and k_moon < 1.1
	_stars.modulate.a = clampf(1.0 - d * 1.6, 0.0, 1.0)
	var sky := clock.sun_light()
	var lum := maxf(sky.r, maxf(sky.g, sky.b))
	_layers_tint = Color(sky.r, sky.g, sky.b).lerp(Color.WHITE, 0.15) if lum < 0.999 else Color.WHITE


func _place_on_arc(node: TextureRect, k: float, view: Vector2) -> void:
	var size := node.texture.get_size() if node.texture else Vector2(32, 32)
	var x := lerpf(-size.x * 0.5, view.x - size.x * 0.5, k)
	var y := 190.0 - sin(clampf(k, 0.0, 1.0) * PI) * 150.0
	node.position = Vector2(x, y - size.y * 0.5)
