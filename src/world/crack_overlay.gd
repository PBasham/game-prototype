class_name CrackOverlay
extends Node2D
## Draws cracks on damaged blocks (World.block_damage), heavier as they near breaking.
## Art: assets/fx/cracks.png, 4 stages of 8x8 side by side.

const TEX := preload("res://assets/fx/cracks.png")
const STAGES := 4

var world: World


func _ready() -> void:
	z_index = 3


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null or world.player == null:
		return
	var near := world.player.global_position
	var w := float(world.data.width * World.TILE)
	for tile: Vector2i in world.damaged_tiles():
		var f := world.block_damage(tile)
		if f <= 0.0:
			continue
		var stage := clampi(int(f * STAGES), 0, STAGES - 1)
		var pos := Vector2(tile * World.TILE)
		pos.x += roundf((near.x - pos.x) / w) * w  # draw the copy near the player
		draw_texture_rect_region(TEX, Rect2(pos, Vector2(World.TILE, World.TILE)),
			Rect2(stage * 8, 0, 8, 8))
