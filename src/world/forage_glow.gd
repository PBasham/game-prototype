class_name ForageGlow
extends Node2D
## A forageable that gives off light (the Glowcap). The light map picks up every node in
## the "light_sources" group (World.dynamic_lights).

var radius := 8.0
var color := Color(0.5, 1.0, 0.95)


func _ready() -> void:
	add_to_group(&"light_sources")


## The tile it lights from (the tile it sits in, just above its ground).
func light_tile() -> Vector2i:
	return Vector2i(floori(global_position.x / World.TILE), floori((global_position.y - 2.0) / World.TILE))
