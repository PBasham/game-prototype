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

@export_group("Mining")
## Damage it takes to break. A copper pickaxe does 25 per hit, so 50 = two hits. Walls
## (the back layer) are mined with right click, by the same tools.
@export var health: float = 50.0
## The pickaxe power (ItemData.mining_power) needed to mine it at all. A pickaxe that's
## strong enough but has less mining_damage just takes longer. 0 = anything mines it.
@export var min_mining_power := 0
## Item dropped when broken (empty = the item with this tile's id, if one exists).
## Walls drop the block they're the back layer of (dirt_wall drops dirt).
@export var drop_item: StringName = &""
@export var drop_count: int = 1
## A second item it can drop, with this chance (stone: flint 10%).
@export var bonus_drop_item: StringName = &""
@export_range(0.0, 1.0) var bonus_drop_chance := 0.0
## Can't be broken at all (0 health also means unbreakable).
@export var unbreakable: bool = false
@export_group("")

@export_group("Terrain look")
## Texture key for the terrain shader: assets/terrain/<terrain>.png. Empty = drawn as a
## regular tile from the atlas instead (platforms, ropes).
@export var terrain: String = ""
## Grass grows on its exposed surfaces (top and upper sides).
@export var grass_cover: bool = false
## Overlay drawn on top of the base texture: assets/terrain/ore_<ore_overlay>.png.
@export var ore_overlay: String = ""
## Built block (planks, bricks): crisp square edges with a dark edge line instead of the
## smooth, blended edges natural ground gets.
@export var built: bool = false
## Built blocks only: where a run of them ends (open on the left or right), the end
## sticks out this many pixels into the open tile, with rounded tips (log cabin
## corners). Only drawn; it doesn't change collision. 0 = none.
@export_range(0, 4) var overhang_px := 0


func validate() -> PackedStringArray:
	var problems := super.validate()
	if atlas_row < 0:
		problems.append("%s has a negative atlas_row" % id)
	return problems
