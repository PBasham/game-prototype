class_name DebugBrush
extends Node2D
## Debug builds only, until real mining arrives in Phase 4. B turns it on and off.
## While on: left mouse removes a block, right mouse places one, mouse wheel picks the
## block. Goes through World.request_set_block like real gameplay will. While on, empty
## hands don't punch; while holding an item (not put away), clicks use the item instead.

const PLACEABLE := [&"dirt", &"stone", &"copper_ore", &"wood_planks", &"wood_platform", &"rope"]

var world: World
## Brush on (B). Off by default, so empty-hand clicks punch.
var active := false
var _selected := 0


func _ready() -> void:
	z_index = 10
	_show()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_B:
		active = not active
		_show()
		queue_redraw()
		return
	if not active:
		return
	if event.is_action_pressed("hotbar_next"):
		_selected = posmod(_selected + 1, PLACEABLE.size())
		_show()
	elif event.is_action_pressed("hotbar_prev"):
		_selected = posmod(_selected - 1, PLACEABLE.size())
		_show()


func _process(_delta: float) -> void:
	if not active or (world.player and world.player.held != null and not world.player.stowed):
		return  # off, or clicks belong to the held item
	var tile := world.world_to_tile(get_global_mouse_position())
	if Input.is_action_pressed("use_primary"):
		world.request_set_block(tile, WorldData.AIR)
	elif Input.is_action_pressed("use_secondary"):
		world.request_set_block(tile, world.blocks.index_of(PLACEABLE[_selected]))
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var tile := world.world_to_tile(get_global_mouse_position())
	draw_rect(Rect2(world.tile_to_world(tile), Vector2(World.TILE, World.TILE)), Color(1, 1, 1, 0.6), false, 1.0)


func _show() -> void:
	DebugOverlay.watch("brush (B, wheel)", String(PLACEABLE[_selected]) if active else "off")
