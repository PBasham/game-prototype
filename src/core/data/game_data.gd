class_name GameData
extends Resource
## Base class for every content definition (items, tiles, recipes, spells, enemies...).
##
## Content lives as .tres files under res://data/<category>/ and is loaded into the
## Registry at startup. `id` must be unique within its category and must never change
## once players have saves, because saves reference content by id.

## Unique id within the category, e.g. &"copper_pickaxe". Never rename after release.
@export var id: StringName

## Name shown to the player.
@export var display_name: String

## Tooltip / description text.
@export_multiline var description: String


## Returns a list of problems with this definition. Empty means valid.
## Subclasses extend this with their own checks (call super first).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("%s has an empty id" % resource_path)
	if display_name.strip_edges().is_empty():
		problems.append("%s (%s) has no display_name" % [id, resource_path])
	return problems
