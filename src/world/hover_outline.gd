class_name HoverOutline
extends Node2D
## A subtle outline around what the cursor is on when right click / E would use it:
## furniture (doors, chests, stations, beds), loose sticks, rocks and flint, ripe berry
## bushes, and interactable nodes (the magic bag). Only within reach.

## Outline color (alpha pulses between outline_alpha_min and the color's alpha).
@export var outline_color := Color(1.0, 0.95, 0.72, 0.75)
@export_range(0.0, 1.0) var outline_alpha_min := 0.4
## Pulses per second.
@export var pulse_speed := 1.2

const SHADER := """
shader_type canvas_item;
uniform vec4 region;  // the sprite's source rect in UV (x, y, w, h)
uniform vec4 color : source_color;
uniform float thick = 1.0;  // art pixels per world pixel: the outline stays 1 world pixel
float inside(vec2 uv) {
	return (uv.x < region.x || uv.y < region.y || uv.x > region.x + region.z || uv.y > region.y + region.w) ? 0.0 : 1.0;
}
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * thick;
	vec2 r = UV + vec2(px.x, 0.0);
	vec2 l = UV - vec2(px.x, 0.0);
	vec2 d = UV + vec2(0.0, px.y);
	vec2 u = UV - vec2(0.0, px.y);
	float n = max(max(texture(TEXTURE, r).a * inside(r), texture(TEXTURE, l).a * inside(l)),
		max(texture(TEXTURE, d).a * inside(d), texture(TEXTURE, u).a * inside(u)));
	float me = texture(TEXTURE, UV).a * inside(UV);
	COLOR = (me < 0.5 && n >= 0.5) ? color : vec4(0.0);
}
"""

var world: World
var _mat: ShaderMaterial
## What to outline this frame: texture, destination rect (world px), source rect (px).
var _tex: Texture2D
var _dest := Rect2()
var _src := Rect2()
## Art pixels per world pixel of the target (ObjectDef.detail).
var _det := 1
var _time := 0.0


func setup(w: World) -> void:
	world = w
	z_index = 50
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material = _mat


func _process(delta: float) -> void:
	_time += delta
	var had := _tex != null
	_tex = null
	_find_target()
	if _tex:
		var a := lerpf(outline_alpha_min, outline_color.a, 0.5 + 0.5 * sin(_time * TAU * pulse_speed))
		_mat.set_shader_parameter("color", Color(outline_color, a))
		_mat.set_shader_parameter("thick", float(_det))
		var size := Vector2(_tex.get_size())
		_mat.set_shader_parameter("region", Vector4(_src.position.x / size.x, _src.position.y / size.y,
			_src.size.x / size.x, _src.size.y / size.y))
	if _tex or had:
		queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	# One pixel bigger all around, so the outline has room outside the sprite.
	draw_texture_rect_region(_tex, _dest.grow(1.0), _src.grow(float(_det)))


## What the cursor is on (and the player could use), if anything.
func hovered() -> Texture2D:
	return _tex


func _find_target() -> void:
	var p := world.player if world else null
	if p == null or p.dead:
		return
	# Hidden while the mouse is over a window (scripted aiming doesn't count).
	if p.input_blocked and not (world.item_user and world.item_user.cursor_override.is_finite()):
		return
	var point := p.aim_point()
	if point.distance_to(p.chest()) > (world.interact_tiles + 2.0) * World.TILE:
		return
	var tile := world.world_to_tile(point)
	if _object(tile) or _plant(tile):
		return
	for node in get_tree().get_nodes_in_group(&"interactable"):
		if node.has_method(&"interact_rect") and (node.call(&"interact_rect") as Rect2).has_point(point):
			for c in node.get_children():
				var s := c as Sprite2D
				if s and s.texture:
					_tex = s.texture
					_det = 1
					_src = Rect2(Vector2.ZERO, s.texture.get_size())
					var top_left := s.global_position - (_src.size * 0.5 if s.centered else Vector2.ZERO)
					_dest = Rect2(top_left + s.offset, _src.size)
					return


func _object(tile: Vector2i) -> bool:
	var a := world.object_anchor_visual(tile)
	if a == World.NO_TILE:
		return false
	var def := world.object_at(a)
	if def and def.display:
		var item := world.displayed_item(a)
		if item == null or item.icon == null:
			return false
		var wpx := world.data.width
		a.x += roundi(float(tile.x - a.x) / wpx) * wpx
		_tex = item.icon
		_dest = world.display_rect(a, item)
		_src = Rect2(Vector2.ZERO, item.icon.get_size())
		_det = maxi(1, roundi(item.icon.get_width() / _dest.size.x))
		return true
	if def == null or def.frames == null or not World._usable(def):
		return false
	# The anchor next to the cursor (the world wraps sideways).
	var wpx := world.data.width
	a.x += roundi(float(tile.x - a.x) / wpx) * wpx
	var id := world.data.get_object(world.wrap_tile(a).x, world.wrap_tile(a).y)
	var frame := world.object_layer.frame_for(def, world.wrap_tile(a), id)
	var h := maxi(def.height_tiles, 1)
	var w := maxi(def.width_tiles, 1) if def.style == ObjectDef.Style.FURNITURE else 1
	var sw := def.sprite_width_px if def.sprite_width_px > 0 else w * World.TILE
	var x := a.x * World.TILE + (w * World.TILE - sw) / 2
	if def.sprite_align == ObjectDef.SpriteAlign.FROM_LEFT:
		x = a.x * World.TILE
	elif def.sprite_align == ObjectDef.SpriteAlign.FROM_RIGHT:
		x = a.x * World.TILE + w * World.TILE - sw
	_tex = def.frames
	_det = def.detail
	_dest = Rect2(x, (a.y - h + 1) * World.TILE, sw, h * World.TILE)
	_src = Rect2(frame * sw * def.detail, 0, sw * def.detail, h * World.TILE * def.detail)
	return true


func _plant(tile: Vector2i) -> bool:
	var s := world.forage.hover_sprite(tile) if world.forage else null
	if s == null and world.plants:
		s = world.plants.hover_sprite(tile)
	if s == null or s.texture == null:
		return false
	_tex = s.texture
	_det = 1
	_src = Rect2(Vector2.ZERO, s.texture.get_size())
	_dest = Rect2(s.global_position, _src.size)
	return true
