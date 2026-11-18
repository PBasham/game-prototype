class_name ObjectDef
extends TileDef
## A tile object (data/objects): something attached in a tile rather than a block, on
## its own layer between the back wall and the front block. It can share a tile with a
## platform or a wall, never with a solid block. Rope and torches now; chests, doors and
## signs later.
##
## Art: `frames`, a strip of frames 8 wide and 8 * height_tiles tall; which frame
## shows depends on `style`.

enum Style {
	ROPE,   ## frames: single, top, middle, bottom (joins ropes above and below)
	TORCH,  ## frames: standing on a block, on a block to the left, to the right, on a wall
}

@export var frames: Texture2D
@export var style := Style.ROPE
## How many tiles tall it's drawn, upward from its tile (frames are 8 x 8*height). The
## tiles above it must be free of solid blocks; a block placed there pops it off.
@export var height_tiles := 1
## What it needs to stay put. Torches need a solid block below or beside them, or a
## back wall behind; they pop off as an item when it's gone. Rope needs anything next
## to it (a block, a platform, more rope, or a wall behind) to be placed, and then stays.
@export var needs_support := false
@export_group("Light")
## Light given off (0 radius = none). Colored: warm for torches.
@export var light_color := Color(1.0, 0.75, 0.45)
## Tiles the light reaches through open air (less through blocks).
@export var light_radius := 0.0
@export_group("")
