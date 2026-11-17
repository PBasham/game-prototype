class_name DevDummy
extends Node2D
## Debug builds only: a training dummy to test damage spells on (console: `dummy`,
## `dummy clear`). Shows damage numbers and its health, and heals back after a pause.
## Not content.

@export var max_health := 100.0
## Seconds without a hit before it heals to full.
@export var heal_after := 3.0

var health := 100.0
var _since_hit := 99.0
var _flash := 0.0


func _ready() -> void:
	add_to_group(&"damageable")
	z_index = 1
	health = max_health


func hit_rect() -> Rect2:
	return Rect2(global_position + Vector2(-6, -40), Vector2(12, 40))


func take_damage(amount: float, _from: Node) -> void:
	health = maxf(health - amount, 0.0)
	_since_hit = 0.0
	_flash = 0.12
	FloatingText.spawn(get_parent(), global_position + Vector2(randf_range(-4, 4), -44), str(roundi(amount)), Color("ffd27a"))
	if health <= 0.0:
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -54), "down!", Color("ff7a6a"))


func _process(delta: float) -> void:
	_since_hit += delta
	_flash = maxf(_flash - delta, 0.0)
	if _since_hit > heal_after and health < max_health:
		health = max_health
	queue_redraw()


func _draw() -> void:
	var wood := Color("9a6a3a") if _flash <= 0.0 else Color.WHITE
	draw_rect(Rect2(-1, -40, 2, 40), wood.darkened(0.2))  # post
	draw_rect(Rect2(-6, -34, 12, 16), wood)  # body
	draw_rect(Rect2(-9, -30, 18, 3), wood.darkened(0.1))  # arms
	draw_circle(Vector2(0, -38), 4.0, wood.lightened(0.1))  # head
	draw_rect(Rect2(-6, -36, 12, 2), Color("c84a3a"))  # target band
	# Health bar.
	draw_rect(Rect2(-10, -48, 20, 2), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-10, -48, 20 * health / max_health, 2), Color("6ad04a"))
