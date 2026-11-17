class_name FloatingText
extends Node2D
## A number or word that rises and fades (damage numbers).

var text := ""
var color := Color.WHITE
var _life := 0.8


static func spawn(parent: Node, at: Vector2, label: String, c: Color = Color.WHITE) -> FloatingText:
	var f := FloatingText.new()
	f.text = label
	f.color = c
	f.global_position = at
	f.z_index = 30
	parent.add_child(f)
	return f


func _process(delta: float) -> void:
	_life -= delta
	position.y -= 14.0 * delta
	queue_redraw()
	if _life <= 0.0:
		queue_free()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	var a := clampf(_life / 0.4, 0.0, 1.0)
	draw_string(font, Vector2(-w * 0.5 + 0.5, 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0, 0, 0, 0.7 * a))
	draw_string(font, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(color, a))
