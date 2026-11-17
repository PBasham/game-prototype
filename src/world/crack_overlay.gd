class_name CrackOverlay
extends Node2D
## Draws cracks on damaged blocks and background walls (World.block_damage), heavier as
## they near breaking.
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
	for key: Vector3i in world.damaged_tiles():
		var tile := Vector2i(key.x, key.y)
		var wall := key.z == 1
		var f := world.block_damage(tile, wall)
		if f <= 0.0:
			continue
		var stage := clampi(int(f * STAGES), 0, STAGES - 1)
		var pos := Vector2(tile * World.TILE)
		pos.x += roundf((near.x - pos.x) / w) * w  # draw the copy near the player
		# Wall cracks are fainter (they're behind).
		draw_texture_rect_region(TEX, Rect2(pos, Vector2(World.TILE, World.TILE)),
			Rect2(stage * 8, 0, 8, 8), Color(1, 1, 1, 0.6 if wall else 1.0))
