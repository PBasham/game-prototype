class_name AlchemyBench
extends RefCounted
## The Alchemist's Bench (Phase 67): brewing by hand. Its window (BenchWindow) is a
## tabletop; this is what's on it and its rules, kept apart so tests can drive it.
##
## - The bottle slot holds one bottle (empty or of water): it picks the recipe's size.
## - The bowl has BOWL_SPOTS spots, each a stack of one ingredient (ground or whole).
## - The mortar holds one ingredient stack; Grind grinds it, then it goes in the bowl.
## - Mix: if the bottle and bowl make an Alchemy Table recipe (RecipeData.bench_ground
##   saying which ingredients must be ground), you get its potion and learn the recipe if
##   it was new; anything else is used up and makes a Murky Mixture.
##
## Nothing leaves the inventory until Mix: what's on the table is only set aside
## (available() counts it out), so closing the window loses nothing.

const BOWL_SPOTS := 3
const MURKY := &"murky_mixture"

var vial: StringName = &""
## Each spot: {"id": StringName, "count": int, "ground": bool}, or empty.
var bowl: Array[Dictionary] = []
var mortar: Dictionary = {}


func _init() -> void:
	clear()


func clear() -> void:
	vial = &""
	bowl.clear()
	for i in BOWL_SPOTS:
		bowl.append({})
	mortar = {}


# --- what things are ----------------------------------------------------------------------

## The mixing recipes (the Alchemy Table's).
static func recipes() -> Array[RecipeData]:
	return Crafting.recipes_for(&"alchemy")


## A bottle for the vial spot: an empty bottle or a bottle of water.
static func is_vessel(id: StringName) -> bool:
	var it := ItemData.find(id)
	return it != null and it.bottle_shape != ItemData.BottleShape.NONE and it.heal_value == 0.0 \
		and it.mana_value == 0.0 and it.buff_seconds == 0.0 and id != MURKY


## Something that goes in the bowl or mortar: any recipe's non-bottle input.
static func is_ingredient(id: StringName) -> bool:
	for r in recipes():
		if r.inputs.has(id) and not is_vessel(id):
			return true
	return false


## Everything the ingredient list shows that you have: bottles, then ingredients.
static func shelf(inv: Inventory) -> Array[StringName]:
	var vessels: Array[StringName] = []
	var stuff: Array[StringName] = []
	for id in inv.ids:
		if id == &"" or id in vessels or id in stuff:
			continue
		if is_vessel(id):
			vessels.append(id)
		elif is_ingredient(id):
			stuff.append(id)
	return vessels + stuff


## Known from the start: the Potions tab; the rest once mixed here.
static func knows(c: CharacterData, r: RecipeData) -> bool:
	return r.tab == "Potions" or (c != null and c.brews.has(r.id))


# --- the table ----------------------------------------------------------------------------

## How many of `id` are set out on the table.
func placed(id: StringName) -> int:
	var n := 1 if vial == id else 0
	for s in bowl + [mortar]:
		if not s.is_empty() and s["id"] == id:
			n += int(s["count"])
	return n


func available(inv: Inventory, id: StringName) -> int:
	return inv.count_of(id) - placed(id)


## Puts a bottle on the vial spot (the one there goes back).
func set_vial(inv: Inventory, id: StringName) -> bool:
	if not is_vessel(id) or (vial != id and available(inv, id) <= 0):
		return false
	vial = id
	return true


## Adds one `id` to a bowl spot (an empty one, or one with the same thing as ground).
func add_to_bowl(inv: Inventory, spot: int, id: StringName, ground: bool = false) -> bool:
	if spot < 0 or spot >= BOWL_SPOTS or not is_ingredient(id) or available(inv, id) <= 0:
		return false
	var s := bowl[spot]
	if s.is_empty():
		bowl[spot] = {"id": id, "count": 1, "ground": ground}
	elif s["id"] == id and bool(s["ground"]) == ground:
		s["count"] = int(s["count"]) + 1
	else:
		return false
	return true


## The first spot `id` fits in (same thing, or empty), or -1.
func bowl_spot_for(id: StringName, ground: bool = false) -> int:
	for i in BOWL_SPOTS:
		if not bowl[i].is_empty() and bowl[i]["id"] == id and bool(bowl[i]["ground"]) == ground:
			return i
	for i in BOWL_SPOTS:
		if bowl[i].is_empty():
			return i
	return -1


## Takes one out of a bowl spot.
func take_from_bowl(spot: int) -> void:
	if spot < 0 or spot >= BOWL_SPOTS or bowl[spot].is_empty():
		return
	bowl[spot]["count"] = int(bowl[spot]["count"]) - 1
	if int(bowl[spot]["count"]) <= 0:
		bowl[spot] = {}


## Adds one `id` to the mortar (a different thing there goes back first). Adding more
## makes it whole again: grind after.
func add_to_mortar(inv: Inventory, id: StringName) -> bool:
	if not is_ingredient(id) or available(inv, id) <= 0:
		return false
	if mortar.is_empty() or mortar["id"] != id:
		mortar = {"id": id, "count": 1, "ground": false}
	else:
		mortar["count"] = int(mortar["count"]) + 1
		mortar["ground"] = false
	return true


func grind() -> bool:
	if mortar.is_empty() or bool(mortar["ground"]):
		return false
	mortar["ground"] = true
	return true


## Empties the mortar into the bowl (into `spot`, or the first that fits).
func mortar_to_bowl(spot: int = -1) -> bool:
	if mortar.is_empty():
		return false
	var id: StringName = mortar["id"]
	var ground := bool(mortar["ground"])
	if spot < 0:
		spot = bowl_spot_for(id, ground)
	if spot < 0 or spot >= BOWL_SPOTS:
		return false
	var s := bowl[spot]
	if s.is_empty():
		bowl[spot] = mortar.duplicate()
	elif s["id"] == id and bool(s["ground"]) == ground:
		s["count"] = int(s["count"]) + int(mortar["count"])
	else:
		return false
	mortar = {}
	return true


# --- mixing -------------------------------------------------------------------------------

## The recipe the table makes right now, or null.
func matching() -> RecipeData:
	if vial == &"":
		return null
	var have := {}
	for s in bowl:
		if s.is_empty():
			continue
		var key := "%s|%s" % [s["id"], bool(s["ground"])]
		have[key] = int(have.get(key, 0)) + int(s["count"])
	if have.is_empty():
		return null
	for r in recipes():
		if not r.inputs.has(vial) or r.inputs[vial] != 1:
			continue
		var want := {}
		for id: StringName in r.inputs:
			if id != vial:
				want["%s|%s" % [id, id in r.bench_ground]] = r.inputs[id]
		if want == have:
			return r
	return null


## What Mix would make, for the window's preview: the output item id when it matches a
## recipe you know, &"?" for a mix you don't know (it may work or go murky), &"" when
## there's nothing to mix.
func preview(c: CharacterData) -> StringName:
	if mix_problem() != "":
		return &""
	var r := matching()
	return r.output if r and knows(c, r) else &"?"


## Why Mix can't go yet ("" = it can).
func mix_problem() -> String:
	if vial == &"":
		return "Put a bottle in the bottle slot"
	for s in bowl:
		if not s.is_empty():
			return ""
	return "Put ingredients in the bowl"


## Mixes: uses up the bottle and the bowl. Returns {"item": what you got, "recipe": the
## recipe or null (a Murky Mixture), "new": true when it taught you the recipe}.
func mix(inv: Inventory, c: CharacterData) -> Dictionary:
	if mix_problem() != "":
		return {}
	var r := matching()
	inv.remove(vial, 1)
	for s in bowl:
		if not s.is_empty():
			inv.remove(s["id"], int(s["count"]))
	var out: StringName = r.output if r else MURKY
	var count := r.output_count if r else 1
	var fresh := r != null and not knows(c, r)
	if fresh and c:
		c.brews[r.id] = true
	vial = &""
	for i in BOWL_SPOTS:
		bowl[i] = {}
	var left := inv.add(out, count)
	return {"item": out, "count": count, "left": left, "recipe": r, "new": fresh}
