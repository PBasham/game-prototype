class_name ConjuredPlatform
extends StaticBody2D
## Conjure Platform: a glowing plank you can stand on, `conjure_tiles` wide, for
## `duration` seconds, then it fades (blinking in its last 3 s). It acts like a platform
## tile (one way, Down + Jump drops through) and drops nothing.

var world: World
var spell: SpellData
var time_left := 30.0
## The tiles it covers (registered with the World so it counts as a platform there).
var tiles: Array[Vector2i] = []


## `left_tile`: its leftmost tile; the platform's top is that tile's top.
func setup(w: World, s: SpellData, left_tile: Vector2i, width: int) -> void:
	world = w
	spell = s
	time_left = s.duration
	for i in width:
		tiles.append(left_tile + Vector2i(i, 0))
	global_position = Vector2(left_tile * World.TILE)
	collision_layer = 2  # the platforms layer
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width * World.TILE, 4.0)
	shape.shape = rect
	shape.position = Vector2(width * World.TILE * 0.5, 2.0)
	shape.one_way_collision = true
	add_child(shape)
	z_index = 5
	for t in tiles:
		world.conjured[world.wrap_tile(t)] = self


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		EventBus.sound_requested.emit(&"platform_fade", global_position)
		queue_free()
		return
	queue_redraw()


func _exit_tree() -> void:
	if world:
		for t in tiles:
			var w := world.wrap_tile(t)
			if world.conjured.get(w) == self:
				world.conjured.erase(w)


func _draw() -> void:
	var c := spell.projectile_color
	var a := 1.0
	if time_left < 3.0:
		a = 0.35 if fmod(time_left, 0.4) < 0.2 else 0.9
	var w := tiles.size() * World.TILE
	draw_rect(Rect2(0, 0, w, 3), Color(c, 0.75 * a))
	draw_rect(Rect2(0, 0, w, 1), Color(c.lightened(0.5), a))
	for i in tiles.size():
		draw_rect(Rect2(i * World.TILE + 3, 3, 2, 1), Color(c, 0.4 * a))
