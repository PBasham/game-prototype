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
## On the Alchemist's Bench (Phase 67): ingredients that must be ground in the mortar
## before they go in the bowl (the Alchemy Table ignores this).
@export var bench_ground: Array[StringName] = []
## Item ids that must be somewhere in your inventory but aren't used up (the Hand
## Hammer for the Workbench).
@export var requires: Array[StringName] = []
## Max mana pool the crafter needs (copying a spell into a scroll: a stronger mage for
## stronger spells). Nothing is used up by it. The Scrolls tab sets it (Crafting.scroll_recipes).
@export var requires_max_mana := 0.0
## A short note shown with the recipe ("Known spell: half cost"). Not saved.
var note := ""
## Teaches this spell instead of making an item: the Spell Weaving Table's Spells tab
## (Crafting.learn_recipes makes these; `output` is the spell, for its icon and name).
var teaches: StringName = &""
## Empower tab recipes (made in code): buying the next rank of this node on this spell.
var empower_node: StringName = &""
var empower_spell: StringName = &""
## What it makes, and how many per craft.
## Hidden until the character has had one of these items (empty = always known). A
## "New recipe" note shows the moment one turns up.
@export var unlock_items: Array[StringName] = []
@export var output: StringName = &""
@export var output_count := 1
## Made alongside the output, each time (boiling salt water also leaves Salt; Phase 81).
@export var also_makes: Dictionary[StringName, int] = {}


func validate() -> PackedStringArray:
	var problems := super()
	if output == &"":
		problems.append("no output")
	if inputs.is_empty():
		problems.append("no inputs")
	return problems
