class_name TileDef
extends GameData
## A block or wall type. Blocks live in data/tiles, background walls in data/walls.
##
## The art comes from a row of the atlas (assets/tiles/blocks.png or walls.png):
## 48 columns = 16 neighbor masks x 3 random variants (see assets/ASSETS.md).

enum Collision {
	NONE,      ## walk through (rope, decorations)
	SOLID,     ## full block
	PLATFORM,  ## one-way from below, drop through with Down + Jump
}

## Row in the atlas texture.
@export var atlas_row: int = 0

@export var collision: Collision = Collision.SOLID

## Player can climb it with Up/Down (ropes, ladders).
@export var climbable: bool = false

## How hard it is to mine. Used from Phase 3.
@export var hardness: int = 1

@export_group("Terrain look")
## Texture key for the terrain shader: assets/terrain/<terrain>.png. Empty = drawn as a
## regular tile from the atlas instead (platforms, ropes).
@export var terrain: String = ""
## Grass grows on its exposed surfaces (top and upper sides).
@export var grass_cover: bool = false
## Overlay drawn on top of the base texture: assets/terrain/ore_<ore_overlay>.png.
@export var ore_overlay: String = ""


func validate() -> PackedStringArray:
	var problems := super.validate()
	if atlas_row < 0:
		problems.append("%s has a negative atlas_row" % id)
	return problems
