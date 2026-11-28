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
## Tunnels break into pieces about this long (tiles), some shorter and some longer, so
## not every tunnel goes on and on. Bigger = longer runs.
@export var tunnel_length := 160.0
## How much of each tunnel's run is cut away into gaps: 0 = no breaks (one long
## ribbon wherever the coverage allows), higher = shorter, more separate tunnels.
@export_range(0.0, 0.9) var tunnel_breaks := 0.35

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

@export_group("Dark forest")
## Share of the world's width that is Dark Forest (0 = none). By default it's one big
## region, like Terraria's jungle: on Small, about 1,600 tiles wide.
@export_range(0.0, 0.6) var dark_forest_share := 0.25
## How many regions to split it into (1 = one big one). 0 = by size instead: patches of
## about dark_forest_patch_tiles each, spread evenly around the world.
@export var dark_forest_patches := 1
@export var dark_forest_patch_tiles := 640
## With one region: how far its middle is from spawn, as a share of the world's width
## (0.3 on Small = 1,920 tiles). The side (east or west) comes from the seed.
@export_range(0.1, 0.5) var dark_forest_distance := 0.3
## No Dark Forest closer to spawn than this (tiles from spawn to the patch's edge).
@export var dark_forest_spawn_clear := 300
## The patch fades in and out over this many tiles at each edge (trees, darkness, sky).
@export var dark_forest_edge_tiles := 40
## Underground the Dark Forest's blocks (Dark Forest Dirt, Stone, Grass and walls) go
## all the way to the bottom of the world. Their sides wander in and out by up to this
## many tiles as they go down (less near the surface, so they meet the trees' edge)...
@export var dark_forest_wobble_tiles := 40.0
## ...one wiggle every this many tiles going down...
@export var dark_forest_wobble_length := 110.0
## ...and the edge is a band this many tiles wide where both kinds mix in clumps.
@export var dark_forest_fringe_tiles := 7.0
## Dark trees: one spot every this many columns, the chance a spot has a tree, and the
## number of darkwood tree art variants (assets/trees/darkwood_<n>.png).
@export var dark_tree_spacing := 5
@export_range(0.0, 1.0) var dark_tree_chance := 0.9
@export var dark_tree_variants := 3
## Flower chance per column under the dark trees.
@export_range(0.0, 1.0) var dark_flower_chance := 0.01


@export_group("Ocean")
## One ocean: a wide stretch of deep water with sandy beaches on both sides. Off = none.
@export var ocean := true
## Where its middle is: this share of the world width away from spawn (0.5 = the far side).
@export_range(0.1, 0.9) var ocean_distance := 0.5
## Width of the water at sea level: this share of the world width, at least ocean_min_width.
@export_range(0.0, 0.5) var ocean_share := 0.2
@export var ocean_min_width := 140
## The upper sea floor's deepest point below sea level (beside the center chasm). Kept
## to at most half the world below sea level on small worlds.
@export var ocean_depth := 220.0
## How much of each side is a shallow shelf before it drops off (0 to 1 of the half width).
@export_range(0.0, 0.9) var ocean_shelf := 0.3
## Shelf depth below sea level.
@export var ocean_shelf_depth := 8.0
## Bumps on the sea floor (tiles up or down).
@export var ocean_floor_bumps := 3.0
## Each beach: this many tiles from the land down to the water's edge.
@export var beach_width := 60
## Sea level: this many tiles below the baseline surface (surface_level).
@export var sea_level_below := 3
## Sand on top, then Hard Sand, then stone (depth in tiles from the beach or sea floor).
@export var ocean_sand_depth := 6
@export var ocean_hard_sand_depth := 14
## Sunlight reaches this many tiles down into the sea; deeper water gets darker
## (LightMap's cave air fade).
@export var sunlit_water_tiles := 24

@export_group("Abyssal Stone (the sea's shell)")
## Unbreakable Abyssal Stone is the ocean's outer layer, so the sea can't drain into the
## land and the Deep is only reached through the sea. On each side: a layer
## abyss_thickness tiles thick under the sand and Hard Sand, following their curve from
## the Deep's edge out across the beach. Over the last abyss_taper of the beach it rises
## to abyss_cover tiles under the surface, ending abyss_rise rows above sea level (the
## beach rises a little to keep it covered). From the Deep's edge it goes straight down
## to the world's floor.
@export_range(0.05, 0.9) var abyss_taper := 0.35
@export var abyss_thickness := 4
@export var abyss_rise := 2
@export var abyss_cover := 3

@export_group("The Deep (under the ocean)")
## The center chasm: an open shaft of water from the sea floor down to the arena.
## Width picked per world between these.
@export var chasm_width_min := 50
@export var chasm_width_max := 80
## The chasm winds side to side as it goes down: up to chasm_wander tiles off the middle,
## one bend about every chasm_bend_tiles rows.
@export var chasm_wander := 70.0
@export var chasm_bend_tiles := 260.0
## Its width swells and narrows by up to chasm_wobble tiles each side.
@export var chasm_wobble := 8.0
## Smaller kinks on top of the big bends: up to chasm_kink tiles, about chasm_kink_tiles apart.
@export var chasm_kink := 12.0
@export var chasm_kink_tiles := 45.0
## Jagged rock on its walls: up to chasm_jag tiles, in spikes about chasm_jag_tiles tall,
## only on some stretches (the rest stays smooth).
@export var chasm_jag := 7.0
@export var chasm_jag_tiles := 6.0
## Flooded caves under the whole ocean (minus a margin of rock at each side, for the
## barrier): caverns where the noise is above deep_open, tunnels where a second noise is
## within deep_tunnel of zero. Lower deep_open = more open.
@export var deep_margin := 24
@export var deep_crust := 6
@export var deep_floor_rows := 8
@export var deep_cave_tiles := 120.0
@export_range(-1.0, 1.0) var deep_open := 0.22
@export var deep_tunnel_tiles := 160.0
@export_range(0.0, 0.3) var deep_tunnel := 0.045
## The arena at the bottom of the chasm (empty for now: a boss goes here later).
@export var arena_width := 140
@export var arena_height := 70
## Empty side caverns in the Deep for future scenes.
@export var scene_caverns := 4
@export var scene_cavern_width := 40
@export var scene_cavern_height := 20
@export_group("Ocean plants")
## Plants (SeaFlora): chance a column of sea floor at least kelp_min_depth under water
## has kelp (up to kelp_max_tiles tall, never reaching the surface), else seagrass; and
## dune grass on dry beach sand. Ponds get seagrass.
@export_range(0.0, 1.0) var kelp_chance := 0.3
@export var kelp_min_depth := 6
@export var kelp_max_tiles := 22
@export_range(0.0, 1.0) var seagrass_chance := 0.45
@export_range(0.0, 1.0) var dune_grass_chance := 0.3

@export_group("Coast")
## Phase 88: the beach rises toward the land's height smoothed over this many tiles each
## way (no cliff right at the beach), and blends into the real land over coast_blend.
@export var beach_land_smooth := 24
@export var coast_blend := 40
## The Deep's flooded caves: rock sheets thinner than this (tiles, up and down) are
## opened, so there are no thin floating strips in the water.
@export_range(0, 4) var deep_min_rock := 3

@export_group("Ponds")
## A pond spot every this many columns (on fairly flat ground, away from spawn and the
## ocean), and the chance a spot has one.
@export var pond_spacing := 140
@export_range(0.0, 1.0) var pond_chance := 0.6
## Pond width and depth (tiles), picked per pond between these (Phase 88: from puddles
## to big ponds; wider ones tend to be deeper).
@export var pond_width_min := 6
@export var pond_width_max := 40
@export var pond_depth_min := 2
@export var pond_depth_max := 10
## Ground can't rise or fall more than this over a pond's width (the banks are sloped
## down to the water, so it can be uneven).
@export var pond_max_slope := 10
## No ponds this close to spawn.
@export var pond_spawn_clear := 40
## Spots tried in each pond_spacing stretch to find flat enough ground (Phase 81).
@export_range(1, 20) var pond_tries := 6
## Phase 88: higher ground beside a pond or lake slopes down to the water over this share
## of its half width (at least pool_bank_min tiles), instead of a cliff.
@export_range(0.0, 2.0) var pool_bank_ratio := 0.7
@export var pool_bank_min := 6
## How many ponds and lakes have a sand bed (the rest dirt). Near the ocean it's sand.
@export_range(0.0, 1.0) var pool_sand_chance := 0.5

@export_group("Lakes")
## Big fresh water lakes (Phase 81): a lake spot every this many columns, and the
## chance a spot has one. Fresh water, like ponds; the sea is salt.
@export var lake_spacing := 1000
@export_range(0.0, 1.0) var lake_chance := 0.8
## Lake width and depth (tiles), picked per lake between these (Phase 88: real lakes).
@export var lake_width_min := 80
@export var lake_width_max := 200
@export var lake_depth_min := 15
@export var lake_depth_max := 40
## Ground can't rise or fall more than this over a lake's width.
@export var lake_max_slope := 30
## Spots tried in each lake_spacing stretch.
@export_range(1, 40) var lake_tries := 20
## No lakes this close to spawn.
@export var lake_spawn_clear := 80


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
	if dark_tree_spacing < 3:
		problems.append("%s: dark_tree_spacing must be at least 3" % id)
	if pond_width_min > pond_width_max or pond_depth_min > pond_depth_max:
		problems.append("%s: pond min > max" % id)
	if lake_width_min > lake_width_max or lake_depth_min > lake_depth_max:
		problems.append("%s: lake min > max" % id)
	if tree_spacing < 3:
		problems.append("%s: tree_spacing must be at least 3" % id)
	return problems
