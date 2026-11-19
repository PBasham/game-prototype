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
## Which tab of the station's window it's under, for stations with tabs (Hud.STATION_TABS:
## the Alchemy Table's "Potions", "Coatings", "Flasks"). Empty = the first tab.
@export var tab := ""
## Item id -> count used up.
@export var inputs: Dictionary[StringName, int] = {}
## Item ids that must be somewhere in your inventory but aren't used up (the Hand
## Hammer for the Workbench).
@export var requires: Array[StringName] = []
## Max mana pool the crafter needs (copying a spell into a scroll: a stronger mage for
## stronger spells). Nothing is used up by it. The Copy tab makes these.
@export var requires_max_mana := 0.0
## A short note shown with the recipe ("Known spell: half cost"). Not saved.
var note := ""
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
