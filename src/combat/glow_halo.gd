class_name GlowHalo
extends Sprite2D
## A soft round glow drawn on top of the lighting (additive), so glowing things (Forest
## Spirits, wild or summoned) are always bright, even in the dark or before the light
## map catches up. `strength` 0 to 1: a steady glow at `rest`, brighter while charging
## or shooting.

## How bright it is at rest, and at full (charging, shooting).
@export var rest := 0.35
@export var full := 0.85
## Its radius in pixels.
@export var radius_px := 16.0
var strength := 0.0
## Multiplies it (a summon fading out at the end).
var fade := 1.0
var _tint := Color.WHITE

static var _texture: GradientTexture2D


## A halo in this color, drawn above the light overlay (LightMap is z 50).
static func make(tint: Color, radius: float = 16.0) -> GlowHalo:
	var h := GlowHalo.new()
	h._tint = tint
	h.radius_px = radius
	return h


func _ready() -> void:
	if _texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		_texture = GradientTexture2D.new()
		_texture.gradient = g
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = 64
		_texture.height = 64
	texture = _texture
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_as_relative = false
	z_index = 54
	scale = Vector2.ONE * (radius_px * 2.0 / 64.0)


func _process(_delta: float) -> void:
	var a := lerpf(rest, full, clampf(strength, 0.0, 1.0))
	modulate = Color(_tint, a * fade)
