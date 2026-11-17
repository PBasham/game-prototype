class_name CharacterLook
extends Resource
## What a character looks like: a target color per palette group and a hairstyle.
## Recoloring keeps the art's shading: each color in a group keeps its lightness and
## saturation relative to the group's middle color, moved onto the target.

## Group name -> target color for the group's middle shade. Missing = unchanged.
@export var colors: Dictionary[StringName, Color] = {}
## Hair sprite drawn on the head (top-left at the head's top-left plus hair_offset).
## Null = bald.
@export var hair: Texture2D
@export var hair_offset := Vector2(-1, -2)


## Builds the swap table for the palette-swap shader: row 0 = source colors,
## row 1 = what they become. Returns null if nothing changes.
func swap_texture(palette: CharacterPalette) -> ImageTexture:
	var src := PackedColorArray()
	var dst := PackedColorArray()
	for group: StringName in palette.groups:
		if not colors.has(group):
			continue
		var ref := palette.mid_color(group)
		var target: Color = colors[group]
		for c: Color in palette.groups[group]:
			src.append(c)
			dst.append(shade_onto(c, ref, target))
	if src.is_empty():
		return null
	var img := Image.create_empty(src.size(), 2, false, Image.FORMAT_RGBA8)
	for i in src.size():
		img.set_pixel(i, 0, src[i])
		img.set_pixel(i, 1, dst[i])
	return ImageTexture.create_from_image(img)


## `c` is one shade of a group whose middle shade is `ref`; returns the same shade of
## `target`.
static func shade_onto(c: Color, ref: Color, target: Color) -> Color:
	var h := fposmod(target.h + (c.h - ref.h), 1.0)
	var s := clampf(target.s * (c.s / maxf(ref.s, 0.001)), 0.0, 1.0)
	var v := clampf(target.v * (c.v / maxf(ref.v, 0.001)), 0.0, 1.0)
	return Color.from_hsv(h, s, v, c.a)
