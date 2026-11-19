class_name ObjectDef
extends TileDef
## A tile object (data/objects): something attached in a tile rather than a block, on
## its own layer between the back wall and the front block. It can share a tile with a
## platform or a wall, never with a solid block. Rope, torches, and furniture (crafting
## stations, chests, doors).
##
## Art: `frames`, a strip of frames 8 * width_tiles wide and 8 * height_tiles tall;
## which frame shows depends on `style`.
##
## Furniture covers several tiles: its id is stored in the bottom-left tile (the
## anchor) and the "filler" object in the rest, so nothing else can go there.

enum Style {
	ROPE,       ## frames: single, top, middle, bottom (joins ropes above and below)
	TORCH,      ## frames: standing on a block, on a block to the left, to the right, on a wall
	FURNITURE,  ## one frame (`frame`); covers width_tiles x height_tiles
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

## Holds one item on display (see World.request_place_display): drawn as that item,
## right click takes it back. The "display" object; no frames of its own.
@export var display := false
## Items can be put on display on its top (tables, shelves; not stations).
@export var display_surface := false
## Every tile of it needs a back wall when placed (wall shelves).
@export var needs_wall := false

## Art pixels per world pixel: 1 normal, 2 for double-detail art (a 5x4 tile workbench
## is then 80x64 px instead of 40x32). sprite_width_px stays in world pixels.
@export_range(1, 4) var detail := 1
@export_group("Furniture")
## Tiles wide (furniture). The anchor is the bottom-left tile.
@export var width_tiles := 1
## Which frame of the strip to show (a door's open version uses frame 1).
@export var frame := 0
## Needs solid blocks or platforms under its whole bottom row. Those blocks can't be
## mined while it stands.
@export var needs_floor := false
## Stops the player (a closed door).
@export var blocks_movement := false
## Blocks and back walls can be placed against it (doors): blocks next to it or on top,
## walls next to it, on top or behind it.
@export var anchors_building := false
## Right click / E swaps it for this object (a door opening or closing).
@export var toggles_to: StringName = &""
## Used instead of toggles_to when the player is on the right (a door then swings open
## to the left, away from them). Empty = always toggles_to.
@export var toggles_to_left: StringName = &""
## Column of the footprint the object turns around when it toggles (a door's hinge):
## the toggled object is placed so its hinge column lands on the same tile.
@export var hinge_offset := 0
## Sprite width in px when it's wider than the footprint (an open door is drawn 3
## tiles wide from its 1 tile doorway); 0 = the footprint's width.
@export var sprite_width_px := 0
## Where a wider sprite sits: centered on the footprint, starting at its left edge
## (growing right), or ending at its right edge (growing left). An open door starts at
## its hinge.
enum SpriteAlign { CENTER, FROM_LEFT, FROM_RIGHT }
@export var sprite_align := SpriteAlign.CENTER
## Storage slots (chests). It can only be picked up when empty.
@export var container_slots := 0
## Internal: the filler that marks the tiles furniture covers besides its anchor.
@export var filler := false

@export_group("Crafting station")
## Station kind for recipes (&"workbench", &"furnace", &"anvil"). Empty = not a station.
@export var station: StringName = &""
## A bed: right click sets your respawn point here, and at night you sleep till morning.
@export var bed := false
## Recipes need at least this tier of their station.
@export var station_tier := 1
## Upgrading turns it into this station (the next tier) in place. Empty = top tier.
@export var upgrade_to: StringName = &""
## Item id -> count used up by the upgrade.
@export var upgrade_cost: Dictionary[StringName, int] = {}
@export_group("Light")
## Light given off (0 radius = none). Colored: warm for torches.
@export var light_color := Color(1.0, 0.75, 0.45)
## Tiles the light reaches through open air (less through blocks).
@export var light_radius := 0.0
## A buff while the player is within this many tiles (0 = none): the campfire's Cozy.
@export var aura_radius := 0.0
## Extra health per second the aura gives (added to the regular refill).
@export var aura_health_regen := 0.0
@export var aura_name := ""
@export_multiline var aura_description := ""
@export_group("")
