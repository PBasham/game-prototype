extends SceneTree
## Measures how roomy the caves are: of all cave floor tiles (a solid block with air
## above, underground), the share where the Scholar fits standing (3 wide, 8 tall of
## open air above). Overrides for any ForestGenSettings value can be passed to compare.
##
##   godot --headless --path . --script res://tools/cave_fit.gd -- --seed=42
##   ... -- --seed=42 --tunnel_width=18 --cave_flatten=1.2
##
## Options: --seed, --size (small), --width (tiles sampled, 1600), --depth (tiles below
## the surface, 300), plus any ForestGenSettings property.

const FIT_W := 3
const FIT_H := 8


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var registry: Node = load("res://src/core/registry.gd").new()
	registry.quiet = true
	registry.load_all("res://data")
	var blocks := TileTypes.new(&"tiles", registry)
	var walls := TileTypes.new(&"walls", registry)
	registry.free()
	var settings := (load("res://data/worldgen/forest.tres") as ForestGenSettings).duplicate() as ForestGenSettings
	for k: String in args:
		if k in ["seed", "size", "width", "depth"]:
			continue
		if settings.get(k) == null:
			push_error("cave_fit: no setting %s" % k)
			continue
		settings.set(k, float(args[k]) if args[k].contains(".") else int(args[k]))
	var size: Vector2i = WorldData.SIZES[WorldData.Size.get(String(args.get("size", "small")).to_upper(), WorldData.Size.SMALL)]
	var gen := ForestGenerator.new(blocks, walls, size.x, size.y, int(args.get("seed", "42")), settings)
	var width := int(args.get("width", "1600"))
	var depth := int(args.get("depth", "300"))
	var x0 := gen.spawn_tile().x - width / 2
	var solid := blocks.collision_table()
	var floors := 0
	var fits := 0
	var by_band := {}  # depth band -> [floors, fits]
	for c in width:
		var x := posmod(x0 + c, gen.width)
		var top := gen.surface_at(x)
		var column := PackedByteArray()
		column.resize(depth + FIT_H + 2)
		for i in column.size():
			var id := gen.block_at(x, top + i - FIT_H)
			column[i] = 1 if id > 0 and solid[id] == TileDef.Collision.SOLID else 0
		for i in range(FIT_H + 6, column.size()):  # a few tiles under the surface
			if column[i] == 1 and column[i - 1] == 0:
				floors += 1
				var band := mini(((i - FIT_H) / 50) * 50, 250)
				if not by_band.has(band):
					by_band[band] = [0, 0]
				by_band[band][0] += 1
				if _fits(gen, solid, x, top + i - FIT_H):
					fits += 1
					by_band[band][1] += 1
	print("cave_fit: seed %s, %d cave floor tiles, %.0f%% fit the Scholar (%dx%d)" % [
		args.get("seed", "42"), floors, 100.0 * fits / maxf(floors, 1), FIT_W, FIT_H])
	var bands := by_band.keys()
	bands.sort()
	for b: int in bands:
		print("  %3d to %3d below the surface: %5d floors, %.0f%% fit" % [b, b + 49, by_band[b][0], 100.0 * by_band[b][1] / maxf(by_band[b][0], 1)])
	quit()


## The Scholar fits standing on the floor tile at (x, y): a 3-wide, 8-tall box of open
## tiles above it, in any of the 3 positions that put a foot on this tile.
func _fits(gen: ForestGenerator, solid: PackedInt32Array, x: int, y: int) -> bool:
	for off in range(-FIT_W + 1, 1):
		var ok := true
		for dx in FIT_W:
			for dy in range(1, FIT_H + 1):
				var id := gen.block_at(posmod(x + off + dx, gen.width), y - dy)
				if id > 0 and solid[id] == TileDef.Collision.SOLID:
					ok = false
					break
			if not ok:
				break
		if ok:
			return true
	return false
