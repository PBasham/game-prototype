class_name BreathBar
extends Node2D
## Bubbles over your head while you hold your breath under water: one per second left,
## popping as it runs out (Player.breath).

const BUBBLES := 10

var player: Player
var _icon: Texture2D = load("res://assets/ui/icon_breath.png") as Texture2D


func _ready() -> void:
	z_index = 20
	position = Vector2(0, -74)


func _draw() -> void:
	if player == null:
		return
	var n := ceili(player.breath / maxf(player.max_breath, 0.01) * BUBBLES)
	var w := BUBBLES * 6.0
	for i in BUBBLES:
		var at := Vector2(-w / 2.0 + i * 6.0, 0.0)
		if i < n:
			draw_texture(_icon, at)
		else:
			draw_rect(Rect2(at + Vector2(3, 3), Vector2(1, 1)), Color(0.7, 0.85, 1.0, 0.4))
