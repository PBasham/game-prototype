class_name DollCanvas
extends Node2D
## Draws the paper doll on its own pixel grid (render test, console `doll grid`).
## The doll is drawn into a small canvas (a SubViewport) at its art resolution, so a
## turned arm or leg is redrawn in whole, square pixels lined up with the rest of the
## body; the finished canvas is then shown in the world like any sprite.
##
## RotSprite style turning (console `doll turn rotsprite`): the doll uses a sheet
## upscaled with Scale2x (tools/upscale_doll.py) and is drawn at that higher resolution,
## then shrunk back onto its art grid, which keeps turned lines cleaner.
##
## This node stands where the doll stands (the Player moves it, with the step offset);
## `anchor` (a child, flipped with the facing) is the doll's frame in the world, so
## world positions (aim, hands, the held item) still convert correctly.

## Canvas size and where the doll's feet are in it, in art pixels (room for long items).
@export var canvas_px := Vector2i(128, 112)
@export var origin_px := Vector2(64, 92)

var anchor: Node2D
var _draw_vp: SubViewport  # the doll, at sheet resolution
var _grid_vp: SubViewport  # shrunk onto the art grid (RotSprite style only)
var _show: Sprite2D
var _shrink: Sprite2D
var _doll: PaperDoll
var _home: Node  # where the doll lives when the canvas is off
var _home_index := 0


func _init() -> void:
	anchor = Node2D.new()
	anchor.name = "DollAnchor"
	add_child(anchor)


## Whether the doll is on the canvas now.
func is_on() -> bool:
	return _doll != null


## Moves the doll onto the canvas. `sheet_scale`: the sheet's pixels per art pixel (1, 2
## or 4); `out_scale`: the canvas's pixels per art pixel (1 = 1x art, 2 = 2x art).
## When sheet_scale > out_scale, it's drawn big and shrunk (RotSprite style).
func attach(doll: PaperDoll, sheet_scale: int, out_scale: int) -> void:
	if _doll == null:
		_home = doll.get_parent()
		_home_index = doll.get_index()
	detach_clean()
	_doll = doll
	var big := Vector2i(canvas_px * sheet_scale)
	_draw_vp = _viewport(big)
	add_child(_draw_vp)
	if doll.get_parent():
		doll.get_parent().remove_child(doll)
	_draw_vp.add_child(doll)
	doll.position = origin_px * sheet_scale
	doll.world_node = anchor
	doll.draw_scale = float(sheet_scale)
	var tex: Texture2D = _draw_vp.get_texture()
	if sheet_scale != out_scale:
		_grid_vp = _viewport(Vector2i(canvas_px * out_scale))
		add_child(_grid_vp)
		_shrink = Sprite2D.new()
		_shrink.centered = false
		_shrink.texture = tex
		_shrink.scale = Vector2.ONE * (float(out_scale) / sheet_scale)
		_shrink.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_grid_vp.add_child(_shrink)
		tex = _grid_vp.get_texture()
	_show = Sprite2D.new()
	_show.name = "DollPicture"
	_show.centered = false
	_show.texture = tex
	_show.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_show.scale = Vector2.ONE / float(out_scale)
	_show.position = -origin_px
	_show.use_parent_material = false
	add_child(_show)


## Puts the doll back where it was (drawn straight into the world).
func detach(doll: PaperDoll) -> void:
	detach_clean()
	if _home and doll.get_parent() != _home:
		if doll.get_parent():
			doll.get_parent().remove_child(doll)
		_home.add_child(doll)
		_home.move_child(doll, mini(_home_index, _home.get_child_count() - 1))
	doll.world_node = null
	doll.draw_scale = 1.0
	_doll = null


func detach_clean() -> void:
	for n: Node in [_show, _grid_vp, _draw_vp]:
		if n and is_instance_valid(n):
			if _doll and _doll.get_parent() == n:
				n.remove_child(_doll)
			n.queue_free()
	_show = null
	_grid_vp = null
	_draw_vp = null
	_shrink = null


## Facing (1 or -1): the doll flips inside the canvas; the anchor flips with it.
func set_facing(facing: int) -> void:
	anchor.scale.x = float(facing)
	if _doll:
		_doll.facing = facing


static func _viewport(size_px: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size_px
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.snap_2d_transforms_to_pixel = true
	return vp
