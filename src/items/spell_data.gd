class_name SpellData
extends ItemData
## A spell (data/spells/<id>.tres). Spells are learned by the character, put into the
## equipped spellbook's slots, and cast from the spell wheel (R) or a hotbar shortcut,
## or from a tome. The mining fields come from ItemData (beam, mining_damage, area,
## reach); the book and conduit multiply them (spell_power, spell_reach_bonus).
##
## Casting animation: the "spell" item type (book in the back hand, the front hand
## channels at the cursor).

## Needs an equipped conduit of this type (empty = any or none).
@export var requires_conduit: StringName = &""


func is_spell() -> bool:
	return true
