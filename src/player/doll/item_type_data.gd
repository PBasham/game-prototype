class_name ItemTypeData
extends GameData
## An item type (sword, dagger, bow, crossbow, spell book...): how items of this type are
## held, their attack/use animations, and where they go when put away. Items point at a
## type and may override its animations. Files: data/item_types/<id>.tres.
##
## Attacks are a combo chain: clicking again within combo_window after one finishes
## plays the next (and holding the button keeps going). One attack = no combo.

enum Hand { FRONT, BACK }
enum StowStyle { BACK, HIP, HIDDEN }

## Which hand holds the item (a spell book sits in the back hand so the front can cast).
@export var held_in := Hand.FRONT
## Held, not attacking. Loops.
@export var hold: ItemMotion
## Attack / use chain.
@export var attacks: Array[ItemMotion] = []
## Seconds after an attack ends during which a click continues the combo.
@export var combo_window := 0.35
## Holding the button keeps attacking.
@export var repeat_while_held := true
@export var stow_style := StowStyle.BACK
## Two-handed items: GRIP arms hold the item's grip2.
@export var two_handed := false


func validate() -> PackedStringArray:
	var problems := super()
	if hold == null:
		problems.append("%s: no hold motion" % id)
	for m in attacks:
		if m == null or m.duration <= 0.0:
			problems.append("%s: an attack is missing or has no duration" % id)
	return problems
