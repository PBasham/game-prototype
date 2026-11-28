class_name VoxelMaterial
extends GameData
## A material that lives in the voxel layer (VoxelLayer): 4x4 cells per tile, each 2x2
## world pixels. Sand and water move cell by cell; Sand Bricks stay put but can be
## partly blown away.

enum Behavior {
	POWDER,  ## Falls and piles up at 45 degrees (sand). Sinks through liquids.
	LIQUID,  ## Falls, then spreads sideways to level out (water). No collision.
	STATIC,  ## Never moves (Sand Bricks): only explosions turn its block into cells.
}

@export var behavior: Behavior = Behavior.POWDER
## Its cell code in saved worlds (1 to 15). Keep it: changing it turns saved cells into
## another material. New materials take the next free number (Phase 81).
@export_range(0, 15) var code := 0
## Terrain picture (assets/terrain/<name>.png) its cells take their colors from. Empty =
## `color` with a little variation.
@export var terrain: String = ""
@export var color := Color(0.5, 0.5, 0.5)
## The block a full tile of these cells is (sand), or that turns into these cells
## (Sand Bricks). Empty = none (water).
@export var block: StringName = &""
## What mining the cells gives: `item`, one per `cells_per_item` cells (sand: one grain
## a cell; Sand Bricks: one brick for at least half a tile). Empty = nothing.
@export var item: StringName = &""
@export var cells_per_item := 1
## How hard the cells are to mine (like a tile's health). 0 = the block's health.
@export var health := 0.0


func is_solid() -> bool:
	return behavior != Behavior.LIQUID


func validate() -> PackedStringArray:
	var problems := super()
	if cells_per_item < 1:
		problems.append("%s: cells_per_item must be at least 1" % id)
	return problems
