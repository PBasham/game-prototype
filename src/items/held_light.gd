class_name HeldLight
extends Node2D
## The light of a lit item in your hand (a torch: ItemData.held_light_radius). In the
## "light_sources" group while shown, so World.dynamic_lights picks it up; relights the
## light map when the hand moves a quarter tile.

var radius := 0.0
var color := Color.WHITE
var _point := Vector2.ZERO
var _lit_at := Vector2i(-99999, -99999)


func light_point() -> Vector2:
	return _point


func light_tile() -> Vector2i:
	return Vector2i(_point.floor())


## Shows the light at `world_pos` (px) with this radius and color, or hides it (radius 0).
func set_light(world: World, world_pos: Vector2, r: float, c: Color) -> void:
	var on := r > 0.0
	radius = r
	color = c
	_point = world_pos / World.TILE
	if on != is_in_group(&"light_sources"):
		if on:
			add_to_group(&"light_sources")
		else:
			remove_from_group(&"light_sources")
		_lit_at = Vector2i(-99999, -99999)
		world.lights.mark_dirty()
	if on:
		var t := Vector2i((_point * 4.0).floor())
		if t != _lit_at:
			_lit_at = t
			world.lights.mark_dirty()
