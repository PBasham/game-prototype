class_name ForestGenSettings
extends GameData
## Every tunable of the forest world generator, as data: data/worldgen/forest.tres.
##
## Open that file in the Inspector to tweak generation. Changes apply to newly
## generated chunks, so press F6 in game (debug builds) to regenerate the current world
## with the saved settings, or use tools/preview_world.gd for a whole-world map.
## docs/world-generation.md explains what every value does and how they interact.
##
## Units: tiles (8 px), unless noted. "Depth" is tiles below the surface at that column.

@export_group("Surface level")
## Baseline surface height as a fraction of world height from the top (0.3 = the top 30%
## is sky).
@export_range(0.1, 0.6) var surface_level := 0.3
## The surface never goes above or below these fractions of world height.
@export_range(0.05, 0.6) var surface_min := 0.15
@export_range(0.1, 0.8) var surface_max := 0.45

@export_group("Rolling hills")
## How far (up or down) ordinary hills reach from the baseline.
@export var hill_height := 20.0
## Rough distance between hilltops. Larger = longer, gentler hills.
@export var hill_width := 160.0
## Extra noise layers on the hills. 1 = smooth, 3 to 4 = bumpy.
@export_range(1, 6) var hill_detail := 3

@export_group("Big hills")
## Height of the tallest big hills, on top of the rolling hills.
@export var big_hill_height := 50.0
## Rough distance between big hills.
@export var big_hill_width := 700.0
## How much of the world has big hills: 0 = none, 1 = most of it. Default is a few.
@export_range(0.0, 1.0) var big_hill_amount := 0.3

@export_group("Cliffs")
## Steep faces: the ground steps up or down by this much over a few tiles.
@export var cliff_height_min := 6.0
@export var cliff_height_max := 12.0
## Rough distance between possible cliff spots.
@export var cliff_spacing := 220.0
## How much of the world can have cliffs: 0 = none, 1 = everywhere. Default is rare.
@export_range(0.0, 1.0) var cliff_amount := 0.25
## Width of a cliff face, in tiles. 1 to 2 is a wall, 6+ is a steep slope.
@export var cliff_face_width := 2.0

@export_group("Spawn")
## Spawn column. Near x = 0 so the world seam is a short walk to the left.
@export var spawn_x := 200
## Half-width of the flattened area around spawn (60 wide by default).
@export var spawn_flat_radius := 30
## Distance over which the flat area blends back into the hills.
@export var spawn_blend := 30
## No cave entrances, cliffs or shallow caves within this distance of spawn.
@export var spawn_safe_radius := 40

@export_group("Dirt and stone")
## Dirt thickness under the grass varies between these.
@export var dirt_depth_min := 15
@export var dirt_depth_max := 30
## Rough distance over which the dirt thickness changes.
@export var dirt_depth_width := 60.0
## Small-scale wobble (tiles, up or down) on the dirt/stone line, so it's never a
## smooth curve.
@export var dirt_edge_jitter := 3
## Dirt pockets inside the stone. 0 = none, 0.15 = plenty.
@export_range(0.0, 0.5) var dirt_pocket_amount := 0.08
## Size of dirt pockets (bigger = larger, rounder pockets).
@export var dirt_pocket_size := 14.0
## Stone pockets inside the dirt (below stone_pocket_min_depth).
@export_range(0.0, 0.5) var stone_pocket_amount := 0.05
@export var stone_pocket_min_depth := 8
## Rows at the bottom of the world that are always solid stone. The very last row can't
## be broken (World.request_set_block refuses it).
@export var floor_rows := 3

@export_group("Caves: tunnels")
## Tunnels start this deep (except where a surface entrance leads down).
@export var tunnel_min_depth := 16
## Typical tunnel height, in tiles. The Scholar is 8 tall and 3 wide, so tunnels under
## about 10 are crawl spaces he can't walk through.
@export var tunnel_width := 24.0
## Rough distance between neighboring tunnels.
@export var tunnel_spacing := 240.0
## How much of the underground has tunnels: 0 = none, 1 = everywhere.
@export_range(0.0, 1.0) var tunnel_coverage := 0.5
## Above 1, caves stretch sideways (wider than tall), like Terraria. 1 = no stretch.
@export_range(0.5, 3.0) var cave_flatten := 1.5
## Where a tunnel runs out (the edge of the tunnel coverage, or its first tiles of
## depth) it narrows to this share of tunnel_width before it ends. Low = long crawl
## spaces at tunnel ends; 1 = tunnels end at full height.
@export_range(0.0, 1.0) var tunnel_taper := 0.8

@export_group("Caves: caverns")
## Large open caverns start this deep.
@export var cavern_min_depth := 80
## Rough size of a cavern.
@export var cavern_size := 140.0
## How much of the underground is cavern near cavern_min_depth (0 to 1).
@export_range(0.0, 1.0) var cavern_amount_top := 0.04
## ...and at cavern_full_depth and below. Caverns get more common with depth.
@export_range(0.0, 1.0) var cavern_amount_deep := 0.2
@export var cavern_full_depth := 500

@export_group("Caves: surface entrances")
## Average distance between surface entrances. Each one sits somewhere in its stretch.
@export var entrance_spacing := 600
## Chance that a stretch actually gets an entrance.
@export_range(0.0, 1.0) var entrance_chance := 0.85
## How deep an entrance shaft goes before ending in a small chamber.
@export var entrance_depth_min := 50
@export var entrance_depth_max := 110
## Shaft width (the Scholar is 3 wide).
@export var entrance_width_min := 10
@export var entrance_width_max := 13
## How far the shaft winds left and right.
@export var entrance_wobble := 8.0
## Radius of the chamber at the bottom of the shaft.
@export var entrance_chamber := 9.0

@export_group("Copper")
## Copper never appears shallower than this.
@export var copper_min_depth := 6
## Chance per 8x8 area of holding a copper blob, near the surface...
@export_range(0.0, 1.0) var copper_chance_shallow := 0.05
## ...and at copper_full_depth and below.
@export_range(0.0, 1.0) var copper_chance_deep := 0.14
@export var copper_full_depth := 150
## Blob radius range. 1.2 is about 4 tiles of ore, 1.9 about 10.
@export var copper_radius_min := 1.2
@export var copper_radius_max := 1.9
## Copper can replace dirt too (true) or only stone (false).
@export var copper_in_dirt := true

@export_group("Iron")
## Like Terraria's spread: rare where it starts (below the dirt layer), denser deeper.
## Only in stone. Iron wins where an iron and a copper blob overlap.
@export var iron_min_depth := 40
## Chance per 8x8 area of holding an iron blob at iron_min_depth...
@export_range(0.0, 1.0) var iron_chance_shallow := 0.02
## ...and at iron_full_depth and below.
@export_range(0.0, 1.0) var iron_chance_deep := 0.1
@export var iron_full_depth := 250
## Blob radius range (a bit smaller than copper's).
@export var iron_radius_min := 1.0
@export var iron_radius_max := 1.6

@export_group("Clay")
## Clay patches in dirt, like Terraria's: common near the surface, rarer deeper.
## Clay replaces dirt only (never stone, never the grass row).
@export var clay_min_depth := 2
## Chance per 8x8 area of holding a clay patch at clay_min_depth...
@export_range(0.0, 1.0) var clay_chance_shallow := 0.12
## ...and at clay_full_depth and below.
@export_range(0.0, 1.0) var clay_chance_deep := 0.04
@export var clay_full_depth := 60
## Patch radius range (bigger than ore blobs).
@export var clay_radius_min := 1.6
@export var clay_radius_max := 2.6

@export_group("Trees and flowers")
## One tree spot every this many columns (also the minimum spacing between trees).
@export var tree_spacing := 9
## Rough size of a grove (and of the clearings between groves).
@export var grove_width := 120.0
## How much of the surface is grove rather than clearing (0 to 1).
@export_range(0.0, 1.0) var grove_amount := 0.55
## Chance a tree spot gets a tree, inside a grove and in a clearing.
@export_range(0.0, 1.0) var grove_tree_chance := 0.85
@export_range(0.0, 1.0) var clearing_tree_chance := 0.06
## No trees where the ground rises or falls more than this over 4 columns.
@export var tree_max_slope := 2
## Flower chance per column, in clearings and in groves.
@export_range(0.0, 1.0) var clearing_flower_chance := 0.14
@export_range(0.0, 1.0) var grove_flower_chance := 0.03
## Number of tree and flower art variants (assets/trees, assets/decor).
@export var tree_variants := 12
@export var flower_variants := 5


func validate() -> PackedStringArray:
	var problems := super()
	if dirt_depth_min > dirt_depth_max:
		problems.append("%s: dirt_depth_min > dirt_depth_max" % id)
	if entrance_depth_min > entrance_depth_max or entrance_width_min > entrance_width_max:
		problems.append("%s: entrance min > max" % id)
	if cliff_height_min > cliff_height_max or copper_radius_min > copper_radius_max:
		problems.append("%s: cliff or copper min > max" % id)
	if surface_min >= surface_max:
		problems.append("%s: surface_min must be below surface_max" % id)
	if tree_spacing < 3:
		problems.append("%s: tree_spacing must be at least 3" % id)
	return problems
