class_name RecipeData
extends GameData
## A crafting recipe (data/recipes/<id>.tres). Each crafting station has its own list:
## a recipe belongs to one station (or to hand crafting) and shows in that station's
## window. Edit these freely; tools/make_recipes.gd writes the defaults.

## Where it's made: &"" = by hand (inventory panel), or a station kind (&"workbench",
## &"furnace", &"anvil"; ObjectDef.station).
@export var station: StringName = &""
## Lowest station tier that can make it.
@export var station_tier := 1
## Item id -> count used up.
@export var inputs: Dictionary[StringName, int] = {}
## Item ids that must be somewhere in your inventory but aren't used up (the Hand
## Hammer for the Workbench).
@export var requires: Array[StringName] = []
## Only shown (and craftable) while this spell is in the crafter's spellbook: copying a
## spell you have into a scroll ("Copy: Fly"). Empty = always.
@export var requires_book_spell: StringName = &""
## What it makes, and how many per craft.
@export var output: StringName = &""
@export var output_count := 1


func validate() -> PackedStringArray:
	var problems := super()
	if output == &"":
		problems.append("no output")
	if inputs.is_empty():
		problems.append("no inputs")
	return problems
