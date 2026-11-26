class_name ForageData
extends GameData
## Something lying on the ground you pick up with right click or E (a forageable):
## sticks, rocks. Lives in data/forage/. The Forage node (ForageLayer) decides how
## often a floor tile has one; these weights decide which one, per kind of place.

## The item it gives, and how many.
@export var item: StringName
@export var count := 1
## Sprite lying on the ground (bottom center sits on the tile).
@export var texture: Texture2D
## Gives off light where it lies (0 = none): the Glowcap.
@export var light_radius := 0.0
@export var light_color := Color(0.5, 1.0, 0.95)

@export_group("Where it lies")
## Relative weights per kind of floor (0 = never there). On each kind of floor the
## weights of all forageables are compared, so 45 / 40 / 15 means 45% / 40% / 15%.
@export var surface_grass_weight := 0.0
## Bare dirt or stone on the surface (cliffs, dug ground).
@export var surface_ground_weight := 0.0
## Cave floors: grass, dirt or stone with air above, below the surface.
@export var cave_weight := 0.0


## Weight for a kind of floor (ChunkBuildJob.FLOOR_GRASS 0, FLOOR_GROUND 1, FLOOR_CAVE 2).
func weight(place: int) -> float:
	match place:
		0:
			return surface_grass_weight
		1:
			return surface_ground_weight
		2:
			return cave_weight
	return 0.0


func validate() -> PackedStringArray:
	var problems := super.validate()
	if item == &"":
		problems.append("%s: no item" % id)
	if texture == null:
		problems.append("%s: no texture" % id)
	return problems
