class_name LightMap
extends Sprite2D
## Tile-level lighting over the loaded area, drawn as a smooth multiply overlay.
##
## Open sky (no block, no background wall) is fully lit. Light fades by `open_falloff`
## per tile through air and walls and by `solid_falloff` per tile through blocks, so
## sunlight soaks a few blocks into the ground and caves get dark. `ambient` keeps the
## darkest areas faintly visible. Recomputed when chunks load or a block changes.
## (Torches and other light sources come later.)

@export var ambient := 0.16
@export var open_falloff := 0.06
@export var solid_falloff := 0.1
## Minimum seconds between recomputes.
@export var min_interval := 0.12

var world: World
var _dirty := true
var _cooldown := 0.0
var _image: Image
var _texture: ImageTexture


func _ready() -> void:
	centered = false
	scale = Vector2(World.TILE, World.TILE)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 50
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = mat


func mark_dirty() -> void:
	_dirty = true


func _process(delta: float) -> void:
	_cooldown -= delta
	if _dirty and _cooldown <= 0.0:
		rebuild()


func rebuild() -> void:
	_dirty = false
	_cooldown = min_interval
	var rect := world.renderer.loaded_tile_rect()
	if rect.size.x <= 0:
		return
	var w := rect.size.x
	var h := rect.size.y
	var data := world.data
	var blocks := world.blocks
	var light := PackedFloat32Array()
	var cost := PackedFloat32Array()
	light.resize(w * h)
	cost.resize(w * h)
	for y in h:
		var ty := rect.position.y + y
		for x in w:
			var tx := rect.position.x + x
			var b := data.get_block(tx, ty)
			var solid := b == WorldData.OUT_OF_BOUNDS or (b > 0 and blocks.collision(b) == TileDef.Collision.SOLID)
			var i := y * w + x
			cost[i] = solid_falloff if solid else open_falloff
			if not solid and data.get_wall(tx, ty) == 0:
				light[i] = 1.0
	# Sweep passes (left/up, then right/down), twice: close to a full flood fill.
	for _round in 2:
		for y in h:
			for x in w:
				var i := y * w + x
				var v := light[i]
				if x > 0:
					v = maxf(v, light[i - 1] - cost[i])
				if y > 0:
					v = maxf(v, light[i - w] - cost[i])
				light[i] = v
		for y in range(h - 1, -1, -1):
			for x in range(w - 1, -1, -1):
				var i := y * w + x
				var v := light[i]
				if x < w - 1:
					v = maxf(v, light[i + 1] - cost[i])
				if y < h - 1:
					v = maxf(v, light[i + w] - cost[i])
				light[i] = v
	if _image == null or _image.get_width() != w or _image.get_height() != h:
		_image = Image.create_empty(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var l := clampf(light[y * w + x], 0.0, 1.0)
			l = l * l * (3.0 - 2.0 * l)
			l = ambient + (1.0 - ambient) * l
			_image.set_pixel(x, y, Color(l, l, l))
	if _texture == null or _texture.get_size() != Vector2(w, h):
		_texture = ImageTexture.create_from_image(_image)
		texture = _texture
	else:
		_texture.update(_image)
	position = Vector2(rect.position * World.TILE)
