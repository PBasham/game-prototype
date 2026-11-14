class_name Backdrop
extends CanvasLayer
## Sky, sun, clouds, mountains and two layers of hills behind the world.
## Screen-space layers that scroll slower than the camera (parallax) and repeat
## horizontally. Fades toward dark as the camera goes underground.

const DIR := "res://assets/backdrop"
const LAYER_WIDTH := 1280

## [texture, horizontal parallax factor, vertical factor, screen y at the surface]
const LAYERS := [
	["clouds.png", 0.04, 0.02, 10.0],
	["mountains.png", 0.08, 0.05, 120.0],
	["hills_0.png", 0.16, 0.1, 165.0],
	["hills_1.png", 0.3, 0.18, 195.0],
]

## Camera y (pixels) where the backdrop sits at its normal height.
var surface_y := 0.0

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
	gradient.set_color(0, Color("3fa9e8"))
	gradient.set_color(1, Color("aee4f6"))
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

	var sun := TextureRect.new()
	sun.texture = load(DIR + "/sun.png") as Texture2D
	sun.position = Vector2(150, -40)
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(sun)

	for spec: Array in LAYERS:
		var rect := TextureRect.new()
		rect.texture = load(DIR.path_join(spec[0])) as Texture2D
		rect.stretch_mode = TextureRect.STRETCH_TILE
		rect.size = Vector2(LAYER_WIDTH * 2, rect.texture.get_height())
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(rect)
		_rects.append(rect)
	# Solid ground below the nearest hills, so holes never show sky underneath.
	var front := _rects.back().texture.get_image() as Image
	_ground = ColorRect.new()
	_ground.color = front.get_pixel(0, front.get_height() - 1)
	_ground.size = Vector2(LAYER_WIDTH * 2, 2000)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ground)
	_follow(Vector2.ZERO)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam:
		_follow(cam.get_screen_center_position())


func _follow(cam: Vector2) -> void:
	var dy := cam.y - surface_y
	for i in _rects.size():
		var spec: Array = LAYERS[i]
		var rect := _rects[i]
		rect.position.x = -fposmod(cam.x * float(spec[1]), LAYER_WIDTH)
		rect.position.y = float(spec[3]) - dy * float(spec[2])
	var last := _rects.back() as TextureRect
	_ground.position = Vector2(0, last.position.y + last.size.y - 1)
	# Darken as the camera goes underground.
	var under := clampf((dy - 120.0) / 360.0, 0.0, 1.0)
	_root.modulate = Color.WHITE.lerp(Color(0.08, 0.07, 0.07), under)
