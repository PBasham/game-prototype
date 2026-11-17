class_name CharacterPalette
extends Resource
## The colors a character's art is drawn with, sorted into recolorable groups (skin,
## hair, tunic, pants, boots, trim...). CharacterLook says what each group becomes.
## Generated from the art by tools/make_character_palette.gd; edit freely.

## Group name -> the exact art colors in that group, darkest to lightest.
@export var groups: Dictionary[StringName, PackedColorArray] = {}


## The group's middle color: the reference a target color is matched to.
func mid_color(group: StringName) -> Color:
	var colors: PackedColorArray = groups.get(group, PackedColorArray())
	return colors[colors.size() / 2] if colors.size() > 0 else Color.WHITE
