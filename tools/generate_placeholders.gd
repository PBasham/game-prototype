extends SceneTree
## Generates placeholder art so the game runs before real assets exist.
##
## Run from the project folder:
##   godot --headless --path . --script res://tools/generate_placeholders.gd
##
## Output: res://assets/tiles/placeholder_tiles.png (16x16 tiles, 8 per row).
## Deterministic: the same script always produces the same image.
## Real art replaces these files with the same names and layout (see assets/ASSETS.md).

const TILE := 16
const COLUMNS := 8
const OUT := "res://assets/tiles/placeholder_tiles.png"

const STONE := Color("7d7d7d")

## name, base color, style, accent color. Order = atlas order (row-major). Keep in sync with ASSETS.md.
const TILES := [
	["dirt", Color("8b5a2b"), "speckle", Color.TRANSPARENT],
	["grass", Color("8b5a2b"), "grass", Color("4caf50")],
	["stone", Color("7d7d7d"), "speckle", Color.TRANSPARENT],
	["sand", Color("d8c27a"), "speckle", Color.TRANSPARENT],
	["snow", Color("eef3f7"), "speckle", Color.TRANSPARENT],
	["ice", Color("9fd8f0"), "shine", Color.TRANSPARENT],
	["mud", Color("5b4636"), "speckle", Color.TRANSPARENT],
	["clay", Color("b5654a"), "speckle", Color.TRANSPARENT],
	["wood_planks", Color("a0703c"), "planks", Color.TRANSPARENT],
	["copper_ore", STONE, "ore", Color("d27d2d")],
	["iron_ore", STONE, "ore", Color("c8b8a8")],
	["silver_ore", STONE, "ore", Color("dfe6ee")],
	["gold_ore", STONE, "ore", Color("f2c94c")],
	["arcanite_ore", STONE, "ore", Color("9b59f6")],
	["dirt_wall", Color("4a3018"), "speckle", Color.TRANSPARENT],
	["stone_wall", Color("444444"), "speckle", Color.TRANSPARENT],
]


func _init() -> void:
	var rows := ceili(float(TILES.size()) / COLUMNS)
	var img := Image.create_empty(COLUMNS * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for i in TILES.size():
		var t: Array = TILES[i]
		_draw_tile(img, (i % COLUMNS) * TILE, (i / COLUMNS) * TILE, i, t[1], t[2], t[3])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := img.save_png(OUT)
	print("placeholder tiles: %d tiles -> %s (error %d)" % [TILES.size(), OUT, err])
	quit(0 if err == OK else 1)


func _draw_tile(img: Image, ox: int, oy: int, index: int, base: Color, style: String, accent: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + index
	for y in TILE:
		for x in TILE:
			var c := base
			# Bevel: light top/left edge, dark bottom/right edge, so tiles read as blocks.
			if x == 0 or y == 0:
				c = base.lightened(0.15)
			elif x == TILE - 1 or y == TILE - 1:
				c = base.darkened(0.25)
			img.set_pixel(ox + x, oy + y, c)

	match style:
		"speckle":
			for n in 10:
				var px := rng.randi_range(2, TILE - 3)
				var py := rng.randi_range(2, TILE - 3)
				img.set_pixel(ox + px, oy + py, base.darkened(0.18) if n % 2 == 0 else base.lightened(0.1))
		"grass":
			for x in TILE:
				var depth := 3 + (1 if rng.randf() < 0.4 else 0)
				for y in depth:
					img.set_pixel(ox + x, oy + y, accent.lightened(0.1) if y == 0 else accent)
		"shine":
			for d in 5:
				img.set_pixel(ox + 3 + d, oy + 9 - d, base.lightened(0.45))
				img.set_pixel(ox + 7 + d, oy + 12 - d, base.lightened(0.3))
		"planks":
			for x in range(1, TILE - 1):
				img.set_pixel(ox + x, oy + 5, base.darkened(0.3))
				img.set_pixel(ox + x, oy + 10, base.darkened(0.3))
			img.set_pixel(ox + 4, oy + 2, base.darkened(0.3))
			img.set_pixel(ox + 11, oy + 8, base.darkened(0.3))
			img.set_pixel(ox + 6, oy + 13, base.darkened(0.3))
		"ore":
			for n in 4:
				var cx := rng.randi_range(3, TILE - 5)
				var cy := rng.randi_range(3, TILE - 5)
				for dy in 2:
					for dx in 2:
						img.set_pixel(ox + cx + dx, oy + cy + dy, accent if dx + dy < 2 else accent.darkened(0.3))
