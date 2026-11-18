class_name OreSense
extends Node2D
## Seek Ore: outlines every `sense_block` tile within `sense_tiles` of where you cast it,
## drawn above the darkness, for `duration` seconds (fading at the end). A snapshot:
## ore mined afterwards may still show until it ends.

var world: World
var spell: SpellData
var time_left := 15.0
var found: Array[Vector2i] = []


func setup(w: World, s: SpellData, center: Vector2) -> void:
	world = w
	spell = s
	time_left = s.duration
	z_index = 60  # above the light overlay
	var id := world.blocks.index_of(s.sense_block)
	var c := world.world_to_tile(center)
	var r := int(s.sense_tiles)
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			var t := world.wrap_tile(Vector2i(x, y))
			if Vector2(x - c.x, y - c.y).length() <= r and world.data.in_bounds_y(t.y) \
					and world.data.get_block(t.x, t.y) == id:
				found.append(Vector2i(x, y))
	add_to_group(&"ore_senses")


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := clampf(time_left / 2.0, 0.0, 1.0) * (0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006))
	var c := spell.projectile_color
	for t in found:
		var r := Rect2(Vector2(t * World.TILE), Vector2(World.TILE, World.TILE))
		draw_rect(r.grow(-0.5), Color(c, 0.18 * a))
		draw_rect(r.grow(-0.5), Color(c, a), false, 1.0)
