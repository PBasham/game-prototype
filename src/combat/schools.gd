class_name Schools
extends RefCounted
## Schools of magic (ItemData.School): names, colors, the stat each one's gear raises,
## and the mark payoff. A school weapon's hits mark an enemy; that school's spells hit
## a marked enemy harder. Pure magic builds get the same school power from gear.

## A spell of the mark's school does this much more to a marked enemy.
const MARK_PAYOFF := 1.25
## Seconds between a mark's damage ticks.
const MARK_TICK := 0.5

const NAMES: Array[String] = ["", "Storm", "Arcane", "Air", "Spirit", "Life"]
const COLORS: Array[Color] = [Color.WHITE, Color(0.55, 0.85, 1.0), Color(0.75, 0.55, 1.0),
	Color(0.8, 0.95, 0.9), Color(0.5, 1.0, 0.8), Color(0.6, 1.0, 0.5)]
## What a school's mark is called on an enemy.
const MARKS: Array[String] = ["", "Shocked", "Hexed", "Buffeted", "Haunted", "Rooted"]


static func school_name(school: int) -> String:
	return NAMES[clampi(school, 0, NAMES.size() - 1)]


static func color(school: int) -> Color:
	return COLORS[clampi(school, 0, COLORS.size() - 1)]


## The equipment stat that raises a school's damage (&"storm_damage"), or &"".
static func damage_stat(school: int) -> StringName:
	if school <= 0 or school >= NAMES.size():
		return &""
	return StringName(NAMES[school].to_lower() + "_damage")


## How much more a spell does to `target`: the mark payoff when it carries the spell's
## school's mark, else 1.
static func payoff(target: Object, spell: ItemData) -> float:
	if spell == null or spell.school == ItemData.School.NONE or target == null:
		return 1.0
	if target.has_method(&"is_marked") and target.call(&"is_marked", spell.school):
		return MARK_PAYOFF
	return 1.0
