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

## Dark Forest: [texture, horizontal parallax factor]; drawn over the hills (with a
## murky veil over the sky) as the camera enters a Dark Forest patch.
const DARK_LAYERS := [["dark_forest_far.png", 0.2], ["dark_forest_near.png", 0.34]]
## The veil's color over the sky and hills in the Dark Forest, and how fast the
## backdrop turns dark or light again (share per second).
@export var dark_veil := Color("16282a")
@export var dark_fade_speed := 1.5

## How dark-forest the view is (0 to 1), set by the world from where the camera is.
var dark_target := 0.0
var _dark := 0.0
var _veil: ColorRect
var _dark_rects: Array[TextureRect] = []

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
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = dark_veil
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_veil)
	for spec: Array in DARK_LAYERS:
		var rect := TextureRect.new()
		rect.texture = load(DIR.path_join(spec[0])) as Texture2D
		rect.stretch_mode = TextureRect.STRETCH_TILE
		rect.size = Vector2(LAYER_WIDTH * 2, rect.texture.get_height())
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(rect)
		_dark_rects.append(rect)
	# Solid ground below the nearest hills, so holes never show sky underneath.
	var front := (_rects.back().texture as Texture2D).get_image()
	_ground = ColorRect.new()
	_ground.color = front.get_pixel(0, front.get_height() - 1)
	_ground.size = Vector2(LAYER_WIDTH * 2, 2000)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ground)
	_follow(Vector2.ZERO)


func _process(delta: float) -> void:
	_dark = move_toward(_dark, dark_target, dark_fade_speed * delta)
	_update_sky()
	var cam := get_viewport().get_camera_2d()
	if cam:
		_follow(cam.get_screen_center_position())


func _follow(cam: Vector2) -> void:
	var dy := cam.y - surface_y
	for i in _rects.size():
		var spec: Array = LAYERS[i]
		var rect := _rects[i]
		rect.modulate = _layers_tint
		rect.position.x = -fposmod(cam.x * float(spec[1]), LAYER_WIDTH)
		rect.position.y = float(spec[3]) - dy * float(spec[2])
	var last := _rects.back() as TextureRect
	_ground.position = Vector2(0, last.position.y + last.size.y - 1)
	# Dark Forest: the veil, then trunks standing on the ground line.
	_veil.visible = _dark > 0.0
	_veil.color = Color(dark_veil * _layers_tint, 0.9 * _dark)
	for i in _dark_rects.size():
		var rect := _dark_rects[i]
		rect.visible = _dark > 0.0
		rect.modulate = Color(_layers_tint, _dark)
		rect.position.x = -fposmod(cam.x * float(DARK_LAYERS[i][1]), LAYER_WIDTH)
		rect.position.y = _ground.position.y - rect.size.y + 4.0 + i * 6.0
	_ground.modulate = _layers_tint
	# Darken as the camera goes underground.
	var under := clampf((dy - 120.0) / 360.0, 0.0, 1.0)
	_root.modulate = Color.WHITE.lerp(Color(0.08, 0.07, 0.07), under)


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
