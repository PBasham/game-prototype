class_name DebugBrush
extends Node2D
## Debug builds only, until real mining arrives in Phase 3:
##   Left mouse: remove block. Right mouse: place block. Mouse wheel: change block.
## Goes through World.request_set_block like real gameplay will.

const PLACEABLE := [&"dirt", &"stone", &"copper_ore", &"wood_planks", &"wood_platform", &"rope"]

var world: World
var _selected := 0


func _ready() -> void:
	z_index = 10
	_show()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hotbar_next"):
		_selected = posmod(_selected + 1, PLACEABLE.size())
		_show()
	elif event.is_action_pressed("hotbar_prev"):
		_selected = posmod(_selected - 1, PLACEABLE.size())
		_show()


func _process(_delta: float) -> void:
	var tile := world.world_to_tile(get_global_mouse_position())
	if Input.is_action_pressed("use_primary"):
		world.request_set_block(tile, WorldData.AIR)
	elif Input.is_action_pressed("use_secondary"):
		world.request_set_block(tile, world.blocks.index_of(PLACEABLE[_selected]))
	queue_redraw()


func _draw() -> void:
	var tile := world.world_to_tile(get_global_mouse_position())
	draw_rect(Rect2(world.tile_to_world(tile), Vector2(World.TILE, World.TILE)), Color(1, 1, 1, 0.6), false, 1.0)


func _show() -> void:
	DebugOverlay.watch("brush (wheel)", String(PLACEABLE[_selected]))
