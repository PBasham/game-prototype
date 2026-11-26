class_name PhantomTool
extends Node2D
## The see-through pickaxe or axe a gathering spell conjures (ItemUser drives it). It
## hangs above the target on your side, winds up, and strikes down onto it once per
## swing, glowing in its rank's color. Drawn above the lighting (LightMap is z 50) so it
## glows underground too.

## Where the grip sits in the art (fraction of its size) and where the head is: the
## art is the usual tool diagonal, grip bottom left, head top right.
const GRIP := Vector2(0.15, 0.85)
const HEAD := Vector2(0.75, 0.25)
## Turn (radians) from the raised pose to the strike.
@export var wind_up := 2.3
## How big it's drawn (1 = the art's size: 2 tiles).
@export var size_mult := 1.4
## Glow strength (0 to 1) and the soft rim around it.
@export var alpha := 0.85
@export var rim_alpha := 0.25

var texture: Texture2D
var tint := Color.WHITE
## The point it strikes, and which side you're on (+1: you're left of it).
var target := Vector2.ZERO
var side := 1.0
## 0 to 1 through the swing (it strikes at 1).
var swing := 0.0
var hand := Vector2.ZERO


func _ready() -> void:
	z_as_relative = false
	z_index = 56


func _draw() -> void:
	if texture == null:
		return
	var size := Vector2(texture.get_size()) / 2.0 * size_mult  # detailed art: 2 art px per world px
	var head := (HEAD - GRIP) * size
	var reach := head.length()
	# The grip hangs up and back from the target, so the head comes down onto it.
	var grip := target + Vector2(-side * 0.7, -0.7) * reach
	var strike := PI / 2.0
	var angle := side * lerpf(strike - wind_up, strike, ease(swing, 3.2))
	draw_line(hand, grip, Color(tint, 0.15), 1.0)  # the thread back to your hand
	draw_set_transform(grip, angle, Vector2(side, 1.0))
	var r := Rect2(-GRIP * size, size)
	draw_texture_rect(texture, r.grow(1.0), false, Color(tint, rim_alpha))
	draw_texture_rect(texture, r, false, Color(tint, alpha))
	draw_set_transform(Vector2.ZERO)
	if swing < 0.15:  # just landed: a little flash on the block
		draw_circle(target, 3.5 * (1.0 - swing / 0.15), Color(tint, 0.6))
