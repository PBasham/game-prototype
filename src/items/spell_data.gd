class_name SpellData
extends ItemData
## A spell (data/spells/<id>.tres). Spells are learned by the character, put into the
## equipped spellbook's slots, and cast with the book out (R), from the spell wheel
## (hold R), a hotbar shortcut, or a tome. The book and conduit multiply their strength
## (spell_power) and reach (spell_reach_bonus).
##
## How a spell works is `cast`:
##   TOOL        works on the world like a tool, with ItemData's fields: mining
##               (mining_damage) or chopping (axe_damage), as a beam while held (`beam`)
##               or once per cast. Left click: front layer; right click: back layer.
##   PROJECTILE  fires a projectile at the cursor that hurts what it hits (`damage`).
##   TOGGLE      a concentration spell: a click turns its effect on or off (`effect`).
##               Only one concentration spell is active at a time.
##
## Casting animation: the "spell" item type (book in the back hand, the front hand
## channels at the cursor). Its Channel motion (0.3 s) is the time between casts.

enum Cast { TOOL, PROJECTILE, TOGGLE }

@export var cast := Cast.TOOL
## Needs an equipped conduit of this type (empty = any or none).
@export var requires_conduit: StringName = &""

@export_group("Projectile")
## Damage dealt on a hit (times spell power).
@export var damage := 0.0
## Tiles per second.
@export var projectile_speed := 40.0
## Tiles it flies before fizzling.
@export var projectile_range := 20.0
@export var projectile_color := Color(1.0, 0.9, 0.4)

@export_group("Toggle (concentration)")
## What the spell does while it's on: &"fly" for now.
@export var effect: StringName = &""

@export_group("Mana (not used yet)")
## Mana per cast, and per second while a concentration spell is on. Mana doesn't exist
## yet: these are here so spells can be given costs when it does.
@export var mana_cost := 0.0
@export var mana_per_second := 0.0
@export_group("")


func is_spell() -> bool:
	return true
