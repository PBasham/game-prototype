class_name BushData
extends GameData
## One kind of berry bush (data/bushes/). Wild bushes of every kind grow in the forest;
## `weight` sets how often each kind is picked. Picking a ripe one gives `fruit`.

## Saved in the world (with whether the bush is grown), so never change it once a
## world has bushes of this kind. 0 is the plain berry bush older worlds have.
@export var save_index := 0
## The item picked from it when ripe.
@export var fruit: StringName = &"berries"
## How often worldgen picks this kind, against the other kinds' weights.
@export var weight := 1.0
## Young (no fruit yet), full grown with fruit, and full grown picked bare.
@export var young_texture: Texture2D
@export var ripe_texture: Texture2D
@export var bare_texture: Texture2D


func validate() -> PackedStringArray:
	var problems := super()
	if save_index < 0:
		problems.append("%s: save_index must be 0 or more" % id)
	if young_texture == null or ripe_texture == null or bare_texture == null:
		problems.append("%s: needs young, ripe and bare textures" % id)
	if fruit == &"":
		problems.append("%s: has no fruit" % id)
	return problems
